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
      if continuation?(question) && prior_primary.last
        entries = @retriever.call(question, limit: 12).select { |entry| entry.source_reference == prior_primary.last }
      else
        entries = @retriever.call(question).reject { |entry| another_example?(question) && prior_primary.include?(entry.source_reference) }
      end
      entries = @retriever.call(question, limit: 12).reject { |entry| prior_primary.include?(entry.source_reference) } if entries.empty? && prior_primary.any?
      evidence_ids = entries.map { |entry| entry.id.to_s }
      source_urls = entries.filter_map(&:public_url).select { |url| url.start_with?("https://") }.uniq
      response = entries.empty? ? insufficient_response : @provider.call(question: question.to_s.strip, context: entries)
      response = StructuredResponse.validate!(response)
      response["answer"] = RecruiterAnswerSanitizer.clean(response["answer"])
      response["evidence_ids"] = response["evidence_ids"] & evidence_ids
      response["source_urls"] = response["source_urls"] & source_urls
      EvidenceIntegrity.validate_response!(answer: response["answer"], evidence_ids: response["evidence_ids"], entries: entries)

      unless admin_preview
        @engagement_service.record!(raw_token: raw_token, event_type: "question_submitted", session_id: session_id, ip: ip, event_key: "#{request_id}:question")
        primary_entry = entries.find { |entry| response["evidence_ids"].include?(entry.id.to_s) } || entries.first
        @engagement_service.record!(raw_token: raw_token, event_type: "answer_returned", session_id: session_id, ip: ip, event_key: "#{request_id}:answer", metadata: { "primary_evidence_reference" => primary_entry&.source_reference })
        @usage_guard.record!(token: token, session_digest: session_digest, request_id: request_id, status: "completed", estimated_cost_cents: entries.empty? ? 0 : 1)
      end
      response
    end

    private

    def validate_question!(question)
      value = question.to_s.strip
      raise ArgumentError, "question is required" if value.length < MIN_QUESTION_LENGTH
      raise ArgumentError, "question is too long" if value.length > MAX_QUESTION_LENGTH
      raise ArgumentError, "question is not meaningful" if value.match?(GARBAGE_PATTERN)
    end

    def insufficient_response
      { "status" => "insufficient_information", "answer" => "I don't have enough approved information to answer that confidently.", "evidence_ids" => [], "source_urls" => [] }
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

    class NullProvider
      def call(**)
        { "status" => "insufficient_information", "answer" => "The answer service is not configured yet.", "evidence_ids" => [], "source_urls" => [] }
      end
    end
  end
end
