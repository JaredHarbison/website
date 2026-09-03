module AskJared
  class QuestionService
    MAX_QUESTION_LENGTH = 600
    MIN_QUESTION_LENGTH = 3
    GARBAGE_PATTERN = /\A(.)\1{20,}\z/

    def initialize(token_service: TokenService.new, retriever: ApprovedKnowledgeRetriever.new, provider: OpenAiProvider.new, engagement_service: EngagementService.new, usage_guard: UsageGuard.new)
      @token_service = token_service
      @retriever = retriever
      @provider = provider
      @engagement_service = engagement_service
      @usage_guard = usage_guard
    end

    def call(raw_token:, question:, session_id:, ip: nil, request_id:, admin_preview: false)
      token = @token_service.resolve(raw_token)
      unless admin_preview
        raise ActiveRecord::RecordNotFound, "Ask token is invalid or unavailable" unless @token_service.recruiter_accessible?(token)
      end
      validate_question!(question)
      session_digest = @usage_guard.digest_session(session_id)
      @usage_guard.check!(token: token, session_digest: session_digest) unless admin_preview

      prior_primary = prior_primary_evidence(session_digest)
      active_intent = @retriever.respond_to?(:classified_intent) ? (@retriever.classified_intent(question) || prior_question_intent(session_digest)) : nil
      if continuation?(question) && prior_primary.last
        entries = retrieve(question, limit: 12, intent: active_intent).select { |entry| entry.source_reference == prior_primary.last }
      else
        entries = retrieve(question, intent: active_intent).reject { |entry| another_example?(question) && prior_primary.include?(entry.source_reference) }
      end
      entries = retrieve(question, limit: 12, intent: active_intent).reject { |entry| prior_primary.include?(entry.source_reference) } if entries.empty? && prior_primary.any? && !another_example?(question) && !continuation?(question)
      packet = SynthesisEvidencePacket.new(entries: entries, intent: active_intent, question: question.to_s.strip, max_claims: 3)
      response = packet.empty? ? insufficient_response(another_example: another_example?(question)) : @provider.call(question: question.to_s.strip, context: packet)
      response = validate_response(response, question: question.to_s.strip, packet: packet)
      response.delete("claim_refs")

      unless admin_preview
        @engagement_service.record!(raw_token: raw_token, event_type: "question_submitted", session_id: session_id, ip: ip, event_key: "#{request_id}:question")
        primary_entry = entries.find { |entry| response["evidence_ids"].include?(entry.id.to_s) } || entries.first
        @engagement_service.record!(raw_token: raw_token, event_type: "answer_returned", session_id: session_id, ip: ip, event_key: "#{request_id}:answer", metadata: { "primary_evidence_reference" => primary_entry&.source_reference, "question_intent" => active_intent })
        @usage_guard.record!(token: token, session_digest: session_digest, request_id: request_id, status: "completed", estimated_cost_cents: entries.empty? ? 0 : 1)
      end
      response
    end

    private

    def retrieve(question, limit: nil, intent: nil)
      options = {}
      options[:limit] = limit if limit
      options[:intent] = intent if intent && @retriever.respond_to?(:classified_intent)
      @retriever.call(question, **options)
    end

    def validate_response(response, question:, packet:)
      response = normalize_response(response, packet: packet)
      resolved = resolve_claim_refs(response, packet: packet)
      EvidenceIntegrity.validate_response!(answer: resolved["answer"], evidence_ids: resolved["evidence_ids"], claim_refs: resolved["claim_refs"], packet: packet)
      resolved
    rescue AskJared::EvidenceIntegrity::Violation => violation
      return insufficient_response unless @provider.respond_to?(:repair)

      begin
        repaired = @provider.repair(question: question, context: packet, response: response, violations: violation.violations)
        repaired = normalize_response(repaired, packet: packet)
        resolved = resolve_claim_refs(repaired, packet: packet)
        EvidenceIntegrity.validate_response!(answer: resolved["answer"], evidence_ids: resolved["evidence_ids"], claim_refs: resolved["claim_refs"], packet: packet)
        resolved
      rescue AskJared::EvidenceIntegrity::Violation, ArgumentError, KeyError, TypeError, AskJared::OpenAiProvider::ConfigurationError, AskJared::OpenAiProvider::ProviderError
        insufficient_response
      end
    rescue ArgumentError, KeyError, TypeError, AskJared::OpenAiProvider::ConfigurationError, AskJared::OpenAiProvider::ProviderError
      insufficient_response
    end

    def normalize_response(response, packet:)
      response = StructuredResponse.validate!(response)
      response["answer"] = RecruiterAnswerSanitizer.clean(response["answer"])
      response["evidence_ids"] = response["evidence_ids"] & packet.evidence_ids
      response["source_urls"] = response["source_urls"] & packet.source_urls
      response
    end

    def resolve_claim_refs(response, packet:)
      return response unless response.key?("claim_refs")

      claim_refs = packet.resolve_claim_aliases!(response.fetch("claim_refs"))
      claim_entry_ids = packet.claims.select { |claim| claim_refs.include?(claim.fetch("ref")) }.map { |claim| claim.fetch("entry_id") }
      response.merge("claim_refs" => claim_refs, "evidence_ids" => (response.fetch("evidence_ids") | claim_entry_ids))
    end

    def validate_question!(question)
      value = question.to_s.strip
      raise ArgumentError, "question is required" if value.length < MIN_QUESTION_LENGTH
      raise ArgumentError, "question is too long" if value.length > MAX_QUESTION_LENGTH
      raise ArgumentError, "question is not meaningful" if value.match?(GARBAGE_PATTERN)
    end

    def insufficient_response(another_example: false)
      answer = if another_example
        "The strongest remaining evidence is closely related to the example already discussed rather than a genuinely distinct strong case."
      else
        "I don't have enough approved information to answer that confidently."
      end
      { "status" => "insufficient_information", "answer" => answer, "evidence_ids" => [], "source_urls" => [] }
    end

    def another_example?(question)
      question.to_s.match?(/\banother (?:example|time)\b|\bwhat else\b|\bgive me another\b/i)
    end

    def continuation?(question)
      question.to_s.match?(/\btell me more\b|\bwhat happened afterward\b|\bwhat did (?:he|jared) learn\b|\bwhat is the risk there\b/i)
    end

    def prior_primary_evidence(session_digest)
      EngagementEvent.where(session_digest: session_digest, event_type: "answer_returned").order(:occurred_at).pluck(:metadata).filter_map { |metadata| metadata["primary_evidence_reference"] }.compact
    end

    def prior_question_intent(session_digest)
      EngagementEvent.where(session_digest: session_digest, event_type: "answer_returned").order(:occurred_at).pluck(:metadata).filter_map { |metadata| metadata["question_intent"] }.compact.last
    end

    class NullProvider
      def call(**)
        { "status" => "insufficient_information", "answer" => "The answer service is not configured yet.", "evidence_ids" => [], "source_urls" => [] }
      end
    end
  end
end
