module AskJared
  class CandidateContextPlanner
    def initialize(context: CandidateContext.new)
      @context = context
    end

    def call(question:, intent:, prior_evidence_ids: [], intent_candidates: nil, planning_required: false, planning_reasons: [], resolution: {})
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      # A compound question is allowed to carry more than one answer family.
      # Load guidance for every selected family, then deduplicate by stable key;
      # using only the primary family silently drops contracts for the secondary
      # part of the question.
      candidate_intents = Array(intent_candidates).presence || [ intent ]
      records = candidate_intents.flat_map { |candidate| @context.for(candidate, question: question) }
                                  .uniq { |record| record.fetch("key") }
                                  .sort_by { |record| [ -record.fetch("priority", 0).to_i, record.fetch("key") ] }
                                  .first(18)
      sources = records.flat_map { |record| Array(record["source_references"]) }.uniq
      themes = records.select { |record| Array(record["affects"]).include?("interpretation") || Array(record["affects"]).include?("story_ranking") }.map { |record| record["purpose"] }.first(6)
      contract = DecisionPolicy.contract_for(
        intent: intent,
        answer_shape: resolution[:answer_shape] || resolution["answer_shape"] || answer_shape_for(intent, question),
        compound: planning_reasons.include?("compound_question") || planning_reasons.include?("multiple_intent_families")
      )
      queries = [ question ] + contract.source_ranking_hints + model_retrieval_queries(question, resolution)
      queries += records.filter_map { |record| record["guidance"] if Array(record["affects"]).include?("retrieval") }.first(3)
      AnswerPlan.new(
        architecture: @context.version, version: @context.version, intent: intent || "unclassified", target: target_for(intent, question),
        breadth: question.match?(/some|examples|strongest|qualities|kinds|what would/i) ? "broad" : "narrow",
        answer_shape: resolution[:answer_shape] || resolution["answer_shape"] || answer_shape_for(intent, question), themes: themes, story_slots: story_slots_for(intent, question),
        preferred_sources: sources, boundary_relevance: boundary_for(intent, question), retrieval_queries: queries,
        avoid: records.filter_map { |record| record["guidance"] if record["category"] == "boundary_guidance" || record["category"] == "recruiter_intent" },
        referent_ids: Array(prior_evidence_ids), context_keys: @context.context_keys(records),
        dimensions: broad_characterization?(intent, question) ? broad_dimensions(records) : [],
        evidence_requirements: contract.evidence_requirements, scope_rules: contract.scope_rules,
        fallback_behavior: contract.fallback_behavior, intent_candidates: Array(intent_candidates).presence || [ intent ].compact,
        planning_required: planning_required, planning_reasons: planning_reasons,
        question_parts: Array(resolution[:parts] || resolution["parts"]),
        confidence: resolution[:confidence] || resolution["confidence"],
        resolution_mode: resolution[:resolution_mode] || resolution["resolution_mode"]
      ).tap { |plan| plan.define_singleton_method(:planning_latency_ms) { ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round } }
    rescue StandardError
      raise
    end

    private

    def model_retrieval_queries(question, resolution)
      parts = Array(resolution[:parts] || resolution["parts"])
      dimensions = parts.flat_map { |part| Array(part["dimensions"] || part[:dimensions]) }.map(&:to_s).uniq
      subjects = parts.map { |part| part["subject"] || part[:subject] }.compact.map(&:to_s)
      queries = []
      queries << "Jared product project built shipped proud role contribution ownership" if subjects.any? { |subject| %w[project product].include?(subject) }
      queries << "Jared direct contribution technical ownership role on project" if dimensions.any? { |dimension| %w[ownership contribution role_fit].include?(dimension) }
      queries << "Jared recruiter evidence #{dimensions.join(' ')}" if queries.empty? && dimensions.any?
      queries
    end

    def target_for(intent, question)
      return "follow-up referent" if question.match?(/first|second|that (?:decision|story)|tell me more|what happened afterward|another/i)
      { "characterization" => "professional identity and operating style", "product" => "product judgment and influence", "risk" => "material candidacy risk", "organization" => "engineering-team scale" }.fetch(intent.to_s, question.to_s.strip)
    end

    def answer_shape_for(intent, question)
      return "follow_up" if question.match?(/first|second|that|tell me more|why\??/i)
      return "profile" if broad_characterization?(intent, question)
      return "comparison" if intent.to_s == "complexity"
      return "gap" if %w[risk typescript].include?(intent.to_s)
      "direct"
    end

    def story_slots_for(intent, question)
      return 2 if question.match?(/examples|some|another/i)
      %w[product characterization candidacy impact].include?(intent.to_s) ? 2 : 1
    end

    def boundary_for(intent, question)
      return "primary" if intent.to_s == "risk" || question.match?(/weakness|gap|worry|large engineering team|typescript/i)
      "secondary"
    end

    def broad_characterization?(intent, question)
      intent.to_s == "characterization" && question.match?(/what kind of engineer|how would you describe|what stands out|engineering profile|strongest qualities|biggest strengths/i)
    end

    def broad_dimensions(records)
      guidance = records.map { |record| record["guidance"].to_s.downcase }
      dimensions = []
      dimensions << "product-oriented full-stack identity" if guidance.any? { |text| text.match?(/product-oriented|full-stack|engineering identity/) }
      dimensions << "Rails/backend foundation" if guidance.any? { |text| text.match?(/rails\/backend|backend.*rails|technical foundation/) }
      dimensions << "autonomous ownership and ambiguity" if guidance.any? { |text| text.match?(/autonomous|ambiguity|responsibility/) }
      dimensions << "product and stakeholder judgment" if guidance.any? { |text| text.match?(/product judgment|stakeholder|tradeoff/) }
      dimensions.first(4)
    end
  end
end
