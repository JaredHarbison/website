module AskJared
  class QuestionService
    MAX_CONVERSATION_QUESTIONS = 4
    ConversationLimitExceeded = Class.new(StandardError)
    MAX_QUESTION_LENGTH = 600
    MIN_QUESTION_LENGTH = 3
    GARBAGE_PATTERN = /\A(.)\1{20,}\z/

    RECOGNIZED_INTENTS = ApprovedKnowledgeRetriever::INTENT_SPECS.keys.freeze

    def initialize(token_service: TokenService.new, retriever: ApprovedKnowledgeRetriever.new, provider: OpenAiProvider.new, skeleton_provider: nil, engagement_service: EngagementService.new, usage_guard: UsageGuard.new, planner: CandidateContextPlanner.new)
      @token_service = token_service
      @retriever = retriever
      @provider = provider
      @skeleton_provider = skeleton_provider || TerraSkeletonProvider.new
      @skeleton_enabled = provider.is_a?(OpenAiProvider) || skeleton_provider.present?
      @engagement_service = engagement_service
      @usage_guard = usage_guard
      @planner = planner
      @v2_planner = CandidateContextPlanner.new(context: CandidateContext.new(version: CandidateContext::VERSION_V2))
    end

    def call(raw_token:, question:, session_id:, ip: nil, request_id:, admin_preview: false, architecture: nil, evaluation: false)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      token = @token_service.resolve(raw_token)
      unless admin_preview
        raise ActiveRecord::RecordNotFound, "Ask token is invalid or unavailable" unless @token_service.recruiter_accessible?(token)
      end
      validate_question!(question)
      session_digest = @usage_guard.digest_session(session_id)
      unless admin_preview
        question_count = EngagementEvent.where(session_digest: session_digest, event_type: "question_submitted").count
        raise ConversationLimitExceeded, "This conversation has reached its four-question limit" if question_count >= MAX_CONVERSATION_QUESTIONS
      end
      @usage_guard.check!(token: token, session_digest: session_digest) unless admin_preview

      prior_primary = prior_primary_evidence(session_digest)
      prior_context = prior_answer_context(session_digest)
      prior_intent = prior_question_intent(session_digest)
      classified_intent = @retriever.respond_to?(:classified_intent) ? @retriever.classified_intent(question) : nil
      active_intent = continuation?(question) ? (prior_intent || classified_intent) : (classified_intent || prior_intent)
      qa_preview = token&.opportunity&.tracker_source == "internal_qa"
      plan, architecture_used = planning(question: question, intent: active_intent, prior_evidence: prior_context["evidence_ids"], requested: architecture, admin_preview: admin_preview || qa_preview)
      if continuation?(question) && prior_context.any?
        referent_ids = referent_entry_ids(question, prior_context)
        entries = retrieve_with_plan(question, intent: active_intent, plan: plan).select { |entry| referent_ids.include?(entry.id) || referent_ids.include?(entry.source_reference) }
        if entries.empty? && referent_ids.any?
          numeric_ids = referent_ids.select { |referent| referent.to_s.match?(/\A\d+\z/) }
          entries = ::KnowledgeEntry.recruiter_retrievable.where(id: numeric_ids).to_a
          entries = ::KnowledgeEntry.recruiter_retrievable.where(source_reference: referent_ids).to_a if entries.empty?
        end
      else
        entries = retrieve_with_plan(question, intent: active_intent, plan: plan).reject { |entry| another_example?(question) && prior_primary.include?(entry.source_reference) }
        entries = entries.first(1) if another_example?(question) && skeleton_path?(active_intent)
      end
      entries = retrieve(question, limit: 12, intent: active_intent).reject { |entry| prior_primary.include?(entry.source_reference) } if entries.empty? && prior_primary.any? && !another_example?(question) && !continuation?(question)
      packet = SynthesisEvidencePacket.new(
        entries: entries,
        intent: active_intent,
        question: question.to_s.strip,
        max_claims: skeleton_path?(active_intent) ? nil : 3
      )
      telemetry = {}
      response = if packet.empty?
        insufficient_response(another_example: another_example?(question))
      elsif skeleton_path?(active_intent)
        begin
          @skeleton_provider.call(question: question.to_s.strip, skeleton: RecruiterAnswerSkeleton.new(packet: packet, intent: active_intent, question: question.to_s.strip))
        rescue OpenAiProvider::ConfigurationError, OpenAiProvider::ProviderError
          insufficient_response
        end
      else
        begin
          if plan
            @provider.call(question: question.to_s.strip, context: packet, plan: plan)
          else
            @provider.call(question: question.to_s.strip, context: packet)
          end
        rescue OpenAiProvider::ConfigurationError, OpenAiProvider::ProviderError
          insufficient_response
        end
      end
      telemetry = response.delete("__telemetry") || {} if response.is_a?(Hash)
      response = if skeleton_path?(active_intent) && !packet.empty?
        validate_skeleton_response(response, question: question.to_s.strip, packet: packet)
      else
        validate_response(response, question: question.to_s.strip, packet: packet)
      end
      unless admin_preview
        @engagement_service.record!(raw_token: raw_token, event_type: "question_submitted", session_id: session_id, ip: ip, event_key: "#{request_id}:question", metadata: { "question" => question.to_s, "turn" => EngagementEvent.where(session_digest: session_digest, event_type: "question_submitted").count + 1 })
        primary_entry = primary_entry_for(entries, response: response, packet: packet)
        answer_event = @engagement_service.record!(raw_token: raw_token, event_type: "answer_returned", session_id: session_id, ip: ip, event_key: "#{request_id}:answer", metadata: {
          "primary_evidence_reference" => primary_entry&.source_reference, "question_intent" => active_intent,
          "question" => question.to_s, "answer" => response["answer"], "answer_status" => response["status"],
          "evidence_ids" => response["evidence_ids"], "skeleton_roles" => response["claim_refs"],
          "model" => model_for(skeleton_path?(active_intent)), "latency_ms" => ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round,
          "intent_path" => classified_intent.present? ? "recognized" : "fallback", "evidence_count" => response["evidence_ids"].to_a.length,
          "architecture" => architecture_used, "planner_version" => plan&.version, "planner_model" => "deterministic",
          "context_keys" => plan&.context_keys, "plan_summary" => plan&.summary,
          "example_evidence_ids" => example_evidence_groups(response: response, packet: packet),
          "turn" => EngagementEvent.where(session_digest: session_digest, event_type: "answer_returned").count + 1,
          "validation" => "passed", "input_tokens" => telemetry["input_tokens"], "output_tokens" => telemetry["output_tokens"],
          "estimated_cost_cents" => telemetry["estimated_cost_cents"], "pricing_version" => telemetry["pricing_version"]
        })
        response["answer_event_id"] = answer_event.id
        @usage_guard.record!(token: token, session_digest: session_digest, request_id: request_id, status: response["status"] == "answer" ? "completed" : "rejected", estimated_cost_cents: telemetry["estimated_cost_cents"], input_tokens: telemetry["input_tokens"], output_tokens: telemetry["output_tokens"])
      end
      response.delete("claim_refs")
      response["evaluation"] = { "architecture" => architecture_used, "planner_version" => plan&.version,
                                  "model" => model_for(skeleton_path?(active_intent)), "validation" => "passed",
                                  "input_tokens" => telemetry["input_tokens"], "output_tokens" => telemetry["output_tokens"],
                                  "estimated_cost_cents" => telemetry["estimated_cost_cents"], "pricing_version" => telemetry["pricing_version"] } if admin_preview && evaluation
      response
    end

    private

    def retrieve(question, limit: nil, intent: nil)
      options = {}
      options[:limit] = limit if limit
      options[:intent] = intent if intent && @retriever.respond_to?(:classified_intent)
      @retriever.call(question, **options)
    end

    def retrieve_with_plan(question, intent:, plan:)
      return retrieve(question, intent: intent) unless plan

      queries = plan.retrieval_queries.first(4)
      results = queries.flat_map { |query| retrieve(query, limit: 12, intent: intent) }
      unique = results.uniq { |entry| entry.id }
      preferred = unique.select { |entry| plan.preferred_sources.include?(entry.source_reference.to_s) }
      (preferred + unique.reject { |entry| preferred.include?(entry) }).first(12)
    end

    def planning(question:, intent:, prior_evidence:, requested:, admin_preview:)
      enabled = [ CandidateContext::VERSION, CandidateContext::VERSION_V2 ].include?(requested.to_s) && (admin_preview || ENV.fetch("ASK_JARED_CANDIDATE_CONTEXT", "0") == "1")
      return [ nil, "baseline-v1" ] unless enabled

      planner = requested.to_s == CandidateContext::VERSION_V2 ? @v2_planner : @planner
      [ planner.call(question: question.to_s.strip, intent: intent, prior_evidence_ids: prior_evidence), requested.to_s ]
    rescue StandardError
      [ nil, "baseline-v1-planner-fallback" ]
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

    def validate_skeleton_response(response, question:, packet:)
      skeleton = RecruiterAnswerSkeleton.new(packet: packet, intent: packet.intent, question: question)
      normalized = response.is_a?(Hash) ? response : {}
      status = normalized["status"]
      segments = normalized["segments"]
      raise EvidenceIntegrity::Violation, "skeleton response is malformed" unless StructuredResponse::STATUSES.include?(status) && segments.is_a?(Array)
      return insufficient_response if status == "insufficient_information"

      raise EvidenceIntegrity::Violation, "skeleton response must contain segments" if segments.empty?
      segments.each do |segment|
        raise EvidenceIntegrity::Violation, "skeleton segment is malformed" unless segment.is_a?(Hash) && segment["text"].is_a?(String) && segment["role_refs"].is_a?(Array) && segment["role_refs"].any?
        raise EvidenceIntegrity::Violation, "skeleton segment exposes internal references" if segment["text"].match?(/\bc\d+\b|\br\d+\b|#claim-/i)
        skeleton.resolve_role_refs!(segment["role_refs"])
      end

      role_refs = segments.flat_map { |segment| segment["role_refs"] }.uniq
      separator = multiple_examples?(question) ? "\n\n" : " "
      answer = RecruiterAnswerSanitizer.clean(segments.map { |segment| segment["text"] }.join(separator))
      raise EvidenceIntegrity::Violation, "skeleton realization is empty" if answer.blank?

      {
        "status" => "answer",
        "answer" => answer,
        "evidence_ids" => skeleton.evidence_ids_for(role_refs),
        "source_urls" => packet.source_urls,
        "claim_refs" => skeleton.claim_refs_for(role_refs)
      }
    rescue EvidenceIntegrity::Violation => violation
      return insufficient_response unless @skeleton_provider.respond_to?(:repair)

      begin
        repaired = @skeleton_provider.repair(
          question: question,
          skeleton: RecruiterAnswerSkeleton.new(packet: packet, intent: packet.intent, question: question),
          response: response,
          violations: violation.violations
        )
        validate_skeleton_response_once(repaired, packet: packet, question: question)
      rescue EvidenceIntegrity::Violation, ArgumentError, KeyError, TypeError, OpenAiProvider::ConfigurationError, OpenAiProvider::ProviderError
        insufficient_response
      end
    end

    def validate_skeleton_response_once(response, packet:, question:)
      skeleton = RecruiterAnswerSkeleton.new(packet: packet, intent: packet.intent, question: question)
      raise EvidenceIntegrity::Violation, "skeleton response is malformed" unless response["status"] == "answer" && response["segments"].is_a?(Array) && response["segments"].any?
      response["segments"].each do |segment|
        raise EvidenceIntegrity::Violation, "skeleton segment is malformed" unless segment["text"].is_a?(String) && segment["role_refs"].is_a?(Array) && segment["role_refs"].any?
        raise EvidenceIntegrity::Violation, "skeleton segment exposes internal references" if segment["text"].match?(/\bc\d+\b|\br\d+\b|#claim-/i)
        skeleton.resolve_role_refs!(segment["role_refs"])
      end
      refs = response["segments"].flat_map { |segment| segment["role_refs"] }.uniq
      { "status" => "answer", "answer" => RecruiterAnswerSanitizer.clean(response["segments"].map { |segment| segment["text"] }.join(" ")), "evidence_ids" => skeleton.evidence_ids_for(refs), "source_urls" => packet.source_urls, "claim_refs" => skeleton.claim_refs_for(refs) }
    end

    def normalize_response(response, packet:)
      response = StructuredResponse.validate!(response)
      response["answer"] = RecruiterAnswerSanitizer.clean(response["answer"])
      response["evidence_ids"] = response["evidence_ids"] & packet.evidence_ids
      response["source_urls"] = response["source_urls"] & packet.source_urls
      response
    end

    def recognized_intent?(intent)
      RECOGNIZED_INTENTS.include?(intent.to_s)
    end

    def skeleton_path?(intent)
      @skeleton_enabled && recognized_intent?(intent) && @skeleton_provider.respond_to?(:call)
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
        "I couldn’t find a genuinely distinct example in the information I can share here."
      else
        "I don’t have enough information to answer that confidently."
      end
      { "status" => "insufficient_information", "answer" => answer, "evidence_ids" => [], "source_urls" => [] }
    end

    def another_example?(question)
      question.to_s.match?(/\banother\b.*\b(?:example|time)\b|\bwhat else\b|\bgive me another\b/i)
    end

    def continuation?(question)
      question.to_s.match?(/\btell me more\b|\bwhat happened afterward\b|\bwhat did (?:he|jared) learn\b|\bwhat is the risk there\b|\bwhat did .* convince\b|\bwhy did he do that\b/i)
    end

    def prior_primary_evidence(session_digest)
      EngagementEvent.where(session_digest: session_digest, event_type: "answer_returned").order(:occurred_at).pluck(:metadata).filter_map { |metadata| metadata["primary_evidence_reference"] }.compact
    end

    def prior_question_intent(session_digest)
      EngagementEvent.where(session_digest: session_digest, event_type: "answer_returned").order(:occurred_at).pluck(:metadata).filter_map { |metadata| metadata["question_intent"] }.compact.last
    end

    def prior_answer_context(session_digest)
      EngagementEvent.where(session_digest: session_digest, event_type: "answer_returned").order(:occurred_at).last(1).filter_map do |event|
        { "evidence_ids" => Array(event.metadata["evidence_ids"] || event.metadata["primary_evidence_reference"]).compact,
          "example_evidence_ids" => Array(event.metadata["example_evidence_ids"]).presence }
      end.first || {}
    end

    def referent_entry_ids(question, context)
      groups = Array(context["example_evidence_ids"]).presence || Array(context["evidence_ids"]).map { |id| [ id ] }
      return Array(groups.first).compact if question.match?(/\bfirst\b/i)
      return Array(groups.second || groups.first).compact if question.match?(/\bsecond\b/i)
      Array(groups.flatten).compact
    end

    def example_evidence_groups(response:, packet:)
      ids = Array(response["evidence_ids"]).map(&:to_s)
      return [] if ids.empty?

      refs = Array(response["claim_refs"])
      ordered = refs.filter_map do |ref|
        claim = packet.claims.find { |candidate| candidate["ref"] == ref }
        claim && claim["entry_id"].to_s
      end
      ordered = ids if ordered.empty?
      ordered.uniq.map { |id| [ id ] }
    end

    def multiple_examples?(question)
      question.match?(/\b(?:some|examples|multiple|several|various)\b/i)
    end

    def primary_entry_for(entries, response:, packet:)
      if response["claim_refs"].is_a?(Array)
        primary_claim = packet.claims.find { |claim| response["claim_refs"].include?(claim.fetch("ref")) }
        return entries.find { |entry| entry.id.to_s == primary_claim["entry_id"] } if primary_claim
      end

      entries.find { |entry| response["evidence_ids"].include?(entry.id.to_s) } || entries.first
    end

    def model_for(skeleton)
      return "gpt-5.6-terra" if skeleton
      ENV.fetch("ASK_JARED_MODEL", OpenAiProvider::DEFAULT_MODEL)
    end

    class NullProvider
      def call(**)
        { "status" => "insufficient_information", "answer" => "The answer service is not configured yet.", "evidence_ids" => [], "source_urls" => [] }
      end
    end
  end
end
