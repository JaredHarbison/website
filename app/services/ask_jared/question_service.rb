module AskJared
  class QuestionService
    MAX_CONVERSATION_QUESTIONS = 4
    ConversationLimitExceeded = Class.new(StandardError)
    MAX_QUESTION_LENGTH = 600
    MIN_QUESTION_LENGTH = 3
    GARBAGE_PATTERN = /\A(.)\1{20,}\z/
    PUBLIC_DEFAULT_ARCHITECTURE = CandidateContext::VERSION

    RECOGNIZED_INTENTS = ApprovedKnowledgeRetriever::INTENT_SPECS.keys.freeze

    def initialize(token_service: TokenService.new, retriever: ApprovedKnowledgeRetriever.new, provider: OpenAiProvider.new, skeleton_provider: nil, engagement_service: EngagementService.new, usage_guard: UsageGuard.new, planner: nil, intent_resolver: nil)
      @token_service = token_service
      @retriever = retriever
      @provider = provider
      @skeleton_provider = skeleton_provider || TerraSkeletonProvider.new
      @skeleton_enabled = provider.is_a?(OpenAiProvider) || skeleton_provider.present?
      @engagement_service = engagement_service
      @usage_guard = usage_guard
      @v2_planner = planner || CandidateContextPlanner.new(context: CandidateContext.new)
      @intent_resolver = intent_resolver || IntentResolutionService.new(provider: provider)
    end

    def call(raw_token:, question:, session_id:, ip: nil, request_id:, admin_preview: false, architecture: nil, evaluation: false)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @validation_failure_reason = nil
      token = @token_service.resolve(raw_token)
      unless admin_preview
        raise ActiveRecord::RecordNotFound, "Ask token is invalid or unavailable" unless @token_service.recruiter_accessible?(token)
      end
      validate_question!(question)
      session_digest = @usage_guard.digest_session(session_id)
      qa_preview = token&.opportunity&.tracker_source == "internal_qa"
      unless admin_preview || qa_preview
        question_count = EngagementEvent.where(session_digest: session_digest, event_type: "question_submitted").count
        raise ConversationLimitExceeded, "This conversation has reached its four-question limit" if question_count >= MAX_CONVERSATION_QUESTIONS
      end
      @usage_guard.check!(token: token, session_digest: session_digest) unless admin_preview || qa_preview

      prior_primary = prior_primary_evidence(session_digest)
      prior_context = prior_answer_context(session_digest)
      prior_intent = prior_question_intent(session_digest)
      classification = resolve_intent(question: question, prior_context: prior_context)
      classified_intent = classification[:primary].to_s == "unclassified" ? nil : classification[:primary]
      intent_candidates = Array(classification[:candidates]).reject { |candidate| candidate.to_s == "unclassified" }.presence || [ classified_intent ].compact
      # A new question must establish its own intent. Prior intent is only
      # useful after the user has clearly continued the preceding exchange.
      active_intent = continuation?(question) ? (prior_intent || classified_intent) : classified_intent
      plan, architecture_used = planning(question: question, intent: active_intent, intent_candidates: intent_candidates, classification: classification, prior_evidence: prior_context["evidence_ids"], requested: architecture, admin_preview: admin_preview || qa_preview)
      skeleton_route = skeleton_path?(active_intent, plan: plan)
      if referent_follow_up?(question) && prior_context.any?
        referent_ids = referent_entry_ids(question, prior_context)
        referent_keys = referent_ids.map(&:to_s)
        numeric_ids = referent_ids.select { |referent| referent.to_s.match?(/\A\d+\z/) }
        entries = ::KnowledgeEntry.recruiter_retrievable.where(id: numeric_ids).to_a if numeric_ids.any?
        entries = ::KnowledgeEntry.recruiter_retrievable.where(source_reference: referent_ids).to_a if entries.empty? && referent_ids.any?
        if entries.empty?
          entries = retrieve_with_plan(question, intent: active_intent, plan: plan).select { |entry| referent_keys.include?(entry.id.to_s) || referent_keys.include?(entry.source_reference.to_s) }
        end
      else
        entries = retrieve_with_plan(question, intent: active_intent, plan: plan)
        entries = entries.reject { |entry| prior_primary.include?(entry.source_reference) } if another_example?(question)
        entries = entries.first(1) if another_example?(question) && skeleton_route
      end
      # A planned retrieval may be empty during a transient scope/provider/database
      # hiccup even though the direct, deterministic retriever can still find the
      # same approved evidence. Preserve fail-closed behavior after both paths fail.
      entries = retrieve(question, limit: 12, intent: active_intent) if entries.empty? && !another_example?(question) && !referent_follow_up?(question)
      entries = entries.select { |entry| weakness_evidence?(entry) } if active_intent.to_s == "risk"
      packet = SynthesisEvidencePacket.new(
        entries: entries,
        intent: active_intent,
        question: question.to_s.strip,
        max_claims: skeleton_route ? nil : 3
      )
      force_insufficient = active_intent.to_s == "influence_without_authority" && !supported_influence_without_authority?(packet)
      force_insufficient ||= question.to_s.match?(/convinc|persuad/i) && !packet.claims.any? { |claim| claim["text"].match?(/convinc|persuad|influenc|advocat/i) }
      telemetry = {}
      response = if packet.empty?
        insufficient_response(another_example: another_example?(question))
      elsif skeleton_route
        skeleton = RecruiterAnswerSkeleton.new(packet: packet, intent: active_intent, question: question.to_s.strip)
        if skeleton.roles.empty?
          insufficient_response
        else
          begin
            @skeleton_provider.call(question: question.to_s.strip, skeleton: skeleton)
          rescue OpenAiProvider::ConfigurationError, OpenAiProvider::ProviderError
            system_error_response
          end
        end
      else
        begin
          if plan
            @provider.call(question: question.to_s.strip, context: packet, plan: plan)
          else
            @provider.call(question: question.to_s.strip, context: packet)
          end
        rescue OpenAiProvider::ConfigurationError, OpenAiProvider::ProviderError
          system_error_response
        end
      end
      telemetry = response.delete("__telemetry") || {} if response.is_a?(Hash)
      response = if %w[system_error validation_failure].include?(response["status"])
        response
      elsif skeleton_route && !packet.empty?
        validate_skeleton_response(response, question: question.to_s.strip, packet: packet)
      else
        validate_response(response, question: question.to_s.strip, packet: packet)
      end
      response = insufficient_response if force_insufficient
      if token.present?
        @engagement_service.record!(raw_token: raw_token, event_type: "question_submitted", session_id: session_id, ip: ip, event_key: "#{request_id}:question", metadata: { "question" => question.to_s, "turn" => EngagementEvent.where(session_digest: session_digest, event_type: "question_submitted").count + 1 })
        primary_entry = primary_entry_for(entries, response: response, packet: packet)
        answer_event = @engagement_service.record!(raw_token: raw_token, event_type: "answer_returned", session_id: session_id, ip: ip, event_key: "#{request_id}:answer", metadata: {
          "primary_evidence_reference" => primary_entry&.source_reference, "question_intent" => active_intent,
          "question" => question.to_s, "answer" => response["answer"], "answer_status" => response["status"],
          "evidence_ids" => response["evidence_ids"], "skeleton_roles" => response["claim_refs"],
          "model" => model_for(skeleton_route), "latency_ms" => ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round,
          "intent_path" => classified_intent.present? ? "recognized" : "fallback", "evidence_count" => response["evidence_ids"].to_a.length,
          "architecture" => architecture_used, "planner_version" => plan&.version, "planner_model" => "deterministic",
          "intent_resolution" => classification[:resolution_mode], "intent_resolution_model" => ModelConfig::CANONICAL_MODEL,
          "context_keys" => plan&.context_keys, "plan_summary" => plan&.summary,
          "example_evidence_ids" => example_evidence_groups(response: response, packet: packet),
          "turn" => EngagementEvent.where(session_digest: session_digest, event_type: "answer_returned").count + 1,
          "validation" => validation_state(response), "failure_class" => failure_class(response),
          "validation_error" => @validation_failure_reason,
          "retrieval_mode" => retrieval_trace[:mode], "retrieval_selected_count" => retrieval_trace[:selected].to_a.length,
          "retrieval_considered_count" => retrieval_trace[:considered].to_a.length,
          "input_tokens" => telemetry["input_tokens"], "output_tokens" => telemetry["output_tokens"],
          "estimated_cost_cents" => telemetry["estimated_cost_cents"], "pricing_version" => telemetry["pricing_version"]
        })
        response["answer_event_id"] = answer_event.id
        @usage_guard.record!(token: token, session_digest: session_digest, request_id: request_id, status: response["status"] == "answer" ? "completed" : "rejected", estimated_cost_cents: telemetry["estimated_cost_cents"], input_tokens: telemetry["input_tokens"], output_tokens: telemetry["output_tokens"])
      end
      response.delete("claim_refs")
      response["evaluation"] = { "architecture" => architecture_used, "planner_version" => plan&.version,
                                  "model" => model_for(skeleton_route), "validation" => validation_state(response),
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
      candidates = Array(plan.intent_candidates).presence || [ intent ]
      results = queries.flat_map { |query| candidates.first(3).flat_map { |candidate| retrieve(query, limit: 12, intent: candidate) } }
      unique = results.uniq { |entry| entry.id }
      preferred = unique.select { |entry| plan.preferred_sources.include?(entry.source_reference.to_s) }
      (preferred + unique.reject { |entry| preferred.include?(entry) }).first(12)
    end

    def planning(question:, intent:, intent_candidates:, classification:, prior_evidence:, requested:, admin_preview:)
      # Candidate Context v2 is canonical for public, admin-preview, and QA
      # traffic. The old baseline and v1 planner were evaluation variants and
      # must not silently re-enter production when a planner errors.
      effective_architecture = PUBLIC_DEFAULT_ARCHITECTURE
      [ @v2_planner.call(question: question.to_s.strip, intent: intent, intent_candidates: intent_candidates,
                         planning_required: !!classification[:planning_required],
                         planning_reasons: Array(classification[:planning_reasons]), prior_evidence_ids: prior_evidence,
                         resolution: classification), effective_architecture ]
    rescue StandardError => error
      Rails.logger.error("Ask Jared candidate-context-v2 planning failed: #{error.class}: #{error.message}")
      # Keep the canonical architecture and use the provider's evidence-only
      # contract if planning is unavailable. Never downgrade to legacy v1.
      [ nil, PUBLIC_DEFAULT_ARCHITECTURE ]
    end

    def resolve_intent(question:, prior_context:)
      if @provider.respond_to?(:structured_call)
        resolution = @intent_resolver.call(question: question, prior_context: prior_context)
        resolution = resolution.deep_symbolize_keys
        resolution[:resolution_mode] = "model"
        resolution
      else
        # Test doubles and non-OpenAI providers retain the legacy seam so unit
        # tests can exercise retrieval independently. Production providers use
        # the model-first resolver above and never consult regex routing.
        result = @retriever.respond_to?(:classification) ? @retriever.classification(question) : {}
        result = result.deep_symbolize_keys
        result[:primary] ||= @retriever.classified_intent(question) if @retriever.respond_to?(:classified_intent)
        result[:candidates] ||= [ result[:primary] ].compact
        result[:resolution_mode] = "test-double"
        result
      end
    end

    def validate_response(response, question:, packet:)
      response = normalize_response(response, packet: packet)
      resolved = resolve_claim_refs(response, packet: packet)
      EvidenceIntegrity.validate_response!(answer: resolved["answer"], evidence_ids: resolved["evidence_ids"], claim_refs: resolved["claim_refs"], packet: packet, question: question, intent: packet.intent)
      resolved
    rescue AskJared::EvidenceIntegrity::Violation => violation
      @validation_failure_reason = violation.violations.join("; ")
      return validation_failure_response unless @provider.respond_to?(:repair)

      begin
        repaired = @provider.repair(question: question, context: packet, response: response, violations: violation.violations)
        repaired = normalize_response(repaired, packet: packet)
        resolved = resolve_claim_refs(repaired, packet: packet)
        EvidenceIntegrity.validate_response!(answer: resolved["answer"], evidence_ids: resolved["evidence_ids"], claim_refs: resolved["claim_refs"], packet: packet, question: question, intent: packet.intent)
        resolved
      rescue AskJared::EvidenceIntegrity::Violation => repair_violation
        @validation_failure_reason = [ @validation_failure_reason, repair_violation.violations.join("; ") ].compact.join("; ")
        validation_failure_response
      rescue ArgumentError, KeyError, TypeError, AskJared::OpenAiProvider::ConfigurationError, AskJared::OpenAiProvider::ProviderError => error
        @validation_failure_reason = [ @validation_failure_reason, error.class.name ].compact.join("; ")
        validation_failure_response
      end
    rescue ArgumentError, KeyError, TypeError, AskJared::OpenAiProvider::ConfigurationError, AskJared::OpenAiProvider::ProviderError => error
      @validation_failure_reason = error.class.name
      validation_failure_response
    end

    def validate_skeleton_response(response, question:, packet:)
      skeleton = RecruiterAnswerSkeleton.new(packet: packet, intent: packet.intent, question: question)
      normalized = response.is_a?(Hash) ? response : {}
      status = normalized["status"]
      segments = normalized["segments"]
      raise EvidenceIntegrity::Violation, "skeleton response is malformed" unless StructuredResponse::MODEL_STATUSES.include?(status) && segments.is_a?(Array)
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
      resolved_claim_refs = packet.resolve_claim_aliases!(skeleton.claim_refs_for(role_refs))
      EvidenceIntegrity.validate_response!(answer: answer, evidence_ids: skeleton.evidence_ids_for(role_refs), claim_refs: resolved_claim_refs, packet: packet, question: question, intent: packet.intent, strict_sentence: false)

      {
        "status" => "answer",
        "answer" => answer,
        "evidence_ids" => skeleton.evidence_ids_for(role_refs),
        "source_urls" => packet.source_urls,
        "claim_refs" => resolved_claim_refs
      }
    rescue EvidenceIntegrity::Violation => violation
      @validation_failure_reason = violation.violations.join("; ")
      return validation_failure_response unless @skeleton_provider.respond_to?(:repair)

      begin
        repaired = @skeleton_provider.repair(
          question: question,
          skeleton: RecruiterAnswerSkeleton.new(packet: packet, intent: packet.intent, question: question),
          response: response,
          violations: violation.violations
        )
        validate_skeleton_response_once(repaired, packet: packet, question: question)
      rescue EvidenceIntegrity::Violation => repair_violation
        @validation_failure_reason = [ @validation_failure_reason, repair_violation.violations.join("; ") ].compact.join("; ")
        validation_failure_response
      rescue ArgumentError, KeyError, TypeError, OpenAiProvider::ConfigurationError, OpenAiProvider::ProviderError => error
        @validation_failure_reason = [ @validation_failure_reason, error.class.name ].compact.join("; ")
        validation_failure_response
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
      answer = RecruiterAnswerSanitizer.clean(response["segments"].map { |segment| segment["text"] }.join(" "))
      claim_refs = packet.resolve_claim_aliases!(skeleton.claim_refs_for(refs))
      EvidenceIntegrity.validate_response!(answer: answer, evidence_ids: skeleton.evidence_ids_for(refs), claim_refs: claim_refs, packet: packet, question: question, intent: packet.intent, strict_sentence: false)
      { "status" => "answer", "answer" => answer, "evidence_ids" => skeleton.evidence_ids_for(refs), "source_urls" => packet.source_urls, "claim_refs" => claim_refs }
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

    def skeleton_path?(intent, plan: nil)
      compound_reasons = %w[compound_question multiple_intent_families]
      @skeleton_enabled && recognized_intent?(intent) && @skeleton_provider.respond_to?(:call) && !Array(plan&.planning_reasons).any? { |reason| compound_reasons.include?(reason) }
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

    def validation_failure_response
      { "status" => "validation_failure", "answer" => "I couldn’t provide a reliable answer from the available information. Please try again or report this response.", "evidence_ids" => [], "source_urls" => [] }
    end

    def system_error_response
      { "status" => "system_error", "answer" => "The answer service is temporarily unavailable. Please try again or report this response.", "evidence_ids" => [], "source_urls" => [] }
    end

    def validation_state(response)
      response["status"] == "validation_failure" ? "failed" : (response["status"] == "system_error" ? "not_run" : "passed")
    end

    def failure_class(response)
      return "provider_error" if response["status"] == "system_error"
      "validation_failure" if response["status"] == "validation_failure"
    end

    def retrieval_trace
      trace = @retriever.respond_to?(:last_trace) ? @retriever.last_trace : nil
      trace.is_a?(Hash) ? trace : {}
    end

    def another_example?(question)
      question.to_s.match?(/\banother\b.*\b(?:example|time)\b|\bwhat else\b|\bgive me another\b/i)
    end

    def continuation?(question)
      question.to_s.match?(/\btell me more\b|\bwhat happened afterward\b|\bwhat did (?:he|jared) learn\b|\bwhat is the risk there\b|\bwhat did .* convince\b|\bwhy did he do that\b|\bwhat did .* have to convince\b/i) || another_example?(question)
    end

    def referent_follow_up?(question)
      continuation?(question) && !another_example?(question)
    end

    def supported_influence_without_authority?(packet)
      claims = packet.claims
      influence = claims.any? { |claim| claim["text"].match?(/influenc|recommend|propos|priorit|push(?:ed)? back|decision alignment/i) }
      authority = claims.any? { |claim| claim["text"].match?(/without formal authority|not the formal|no formal|formal decision|decision authority/i) }
      influence && authority
    end

    def weakness_evidence?(entry)
      evidence = entry.metadata.fetch("recruiter_evidence", {})
      claims = Array(evidence["claims"])
      return true if evidence["evidence_kind"].to_s == "boundary"
      claims.any? do |claim|
        next false unless %w[boundary trajectory].include?(claim["kind"].to_s)

        claim["text"].to_s.match?(/experience|depth|team|organization|technology|context|exposure|authority|management|develop|professional .*not|not established|limited/i)
      end
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

    def model_for(_skeleton)
      ModelConfig::CANONICAL_MODEL
    end

    class NullProvider
      def call(**)
        { "status" => "insufficient_information", "answer" => "The answer service is not configured yet.", "evidence_ids" => [], "source_urls" => [] }
      end
    end
  end
end
