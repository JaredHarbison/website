module AskJared
  class CandidateContextPlanner
    VERSION = CandidateContext::VERSION

    def initialize(context: CandidateContext.new)
      @context = context
    end

    def call(question:, intent:, prior_evidence_ids: [])
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      records = @context.for(intent, question: question)
      sources = records.flat_map { |record| Array(record["source_references"]) }.uniq
      themes = records.select { |record| Array(record["affects"]).include?("interpretation") || Array(record["affects"]).include?("story_ranking") }.map { |record| record["purpose"] }.first(6)
      queries = [ question ]
      queries += records.filter_map { |record| record["guidance"] if Array(record["affects"]).include?("retrieval") }.first(3)
      AnswerPlan.new(
        architecture: VERSION, version: VERSION, intent: intent || "unclassified", target: target_for(intent, question),
        breadth: question.match?(/some|examples|strongest|qualities|kinds|what would/i) ? "broad" : "narrow",
        answer_shape: shape_for(intent, question), themes: themes, story_slots: story_slots_for(intent, question),
        preferred_sources: sources, boundary_relevance: boundary_for(intent, question), retrieval_queries: queries,
        avoid: records.filter_map { |record| record["guidance"] if record["category"] == "boundary_guidance" || record["category"] == "recruiter_intent" },
        referent_ids: Array(prior_evidence_ids), context_keys: @context.context_keys(records)
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
  end
end
