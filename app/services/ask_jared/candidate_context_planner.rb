module AskJared
  class CandidateContextPlanner
    def initialize(context: CandidateContext.new)
      @context = context
    end

    def call(question:, intent:, prior_evidence_ids: [])
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      records = @context.for(intent, question: question)
      sources = records.flat_map { |record| Array(record["source_references"]) }.uniq
      themes = records.select { |record| Array(record["affects"]).include?("interpretation") || Array(record["affects"]).include?("story_ranking") }.map { |record| record["purpose"] }.first(6)
      contract = contract_for(intent, question)
      queries = [ question ] + Array(contract[:retrieval_queries])
      queries += records.filter_map { |record| record["guidance"] if Array(record["affects"]).include?("retrieval") }.first(3)
      AnswerPlan.new(
        architecture: @context.version, version: @context.version, intent: intent || "unclassified", target: target_for(intent, question),
        breadth: question.match?(/some|examples|strongest|qualities|kinds|what would/i) ? "broad" : "narrow",
        answer_shape: shape_for(intent, question), themes: themes, story_slots: story_slots_for(intent, question),
        preferred_sources: sources, boundary_relevance: boundary_for(intent, question), retrieval_queries: queries,
        avoid: records.filter_map { |record| record["guidance"] if record["category"] == "boundary_guidance" || record["category"] == "recruiter_intent" },
        referent_ids: Array(prior_evidence_ids), context_keys: @context.context_keys(records),
        dimensions: broad_characterization?(intent, question) ? broad_dimensions(records) : [],
        evidence_requirements: contract[:evidence_requirements], scope_rules: contract[:scope_rules],
        fallback_behavior: contract[:fallback_behavior]
      ).tap { |plan| plan.define_singleton_method(:planning_latency_ms) { ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round } }
    rescue StandardError
      raise
    end

    private

    def target_for(intent, question)
      return "follow-up referent" if question.match?(/first|second|that (?:decision|story)|tell me more|what happened afterward|another/i)
      { "characterization" => "professional identity and operating style", "product" => "product judgment and influence", "risk" => "material candidacy risk", "organization" => "engineering-team scale" }.fetch(intent.to_s, question.to_s.strip)
    end

    def shape_for(intent, question)
      return "separated distinct examples" if question.match?(/examples|some|another/i)
      return "narrow supported follow-up" if question.match?(/first|second|that|tell me more|why\??/i)
      return "characterization first + 2-4 dimensions + brief supporting examples + proportionate boundary" if broad_characterization?(intent, question)
      return "conclusion + relevant evidence + proportionate boundary" if %w[characterization candidacy risk organization typescript].include?(intent.to_s)
      "direct answer + strongest evidence"
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

    # These are deliberately structured planning rules rather than more prose in
    # the private corpus. They make the internal layer constrain retrieval and
    # synthesis even when the matching question has no exact intent label.
    def contract_for(intent, question)
      text = question.to_s.downcase
      if broad_characterization?(intent, question)
        return {
          evidence_requirements: %w[canonical_profile_statement distinct_supporting_dimensions],
          scope_rules: [ "Prefer profile-level evidence before anecdotes.", "Use no more than one short example unless requested." ],
          fallback_behavior: "If no canonical profile evidence exists, return insufficient_information rather than substituting one anecdote.",
          retrieval_queries: [ "professional engineering identity full-stack Rails backend product engineering ownership", "engineering profile product judgment ambiguity production responsibility" ]
        }
      end

      if text.match?(/most|complicated|complexest|hardest|largest.*project/)
        return {
          evidence_requirements: %w[explicit_complexity_basis project_scope ownership],
          scope_rules: [ "Honor the employer and project scope in the question.", "Do not infer a superlative from retrieval rank." ],
          fallback_behavior: "If the evidence does not establish a defensible comparison or superlative, say that and provide the strongest supported candidate without calling it the most complex.",
          retrieval_queries: [ "Dogly project technical complexity architecture scope ownership tradeoffs", "Dogly technical debt scheduled system Shopify integration production complexity" ]
        }
      end

      if text.match?(/outside dogly|before dogly|after dogly|other than dogly|non-dogly/)
        return {
          evidence_requirements: %w[employer_or_project_identity direct_contribution],
          scope_rules: [ "Exclude Dogly evidence unless explicitly labeled as comparison context.", "Preserve employer or project identity." ],
          fallback_behavior: "If non-Dogly evidence is insufficient, state the gap instead of returning a Dogly example.",
          retrieval_queries: [ "J.Crew Anthropologie retail engineering experience projects outside Dogly", "independent product project outside Dogly Rails" ]
        }
      end

      {
        evidence_requirements: [ "directly_relevant_claims" ],
        scope_rules: [ "Preserve employer, project, chronology, ownership, and status." ],
        fallback_behavior: "Answer only the supported portion and identify the missing portion narrowly.",
        retrieval_queries: []
      }
    end
  end
end
