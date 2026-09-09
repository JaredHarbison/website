module AskJared
  AnswerPlan = Struct.new(:architecture, :version, :intent, :target, :breadth, :answer_shape,
                          :themes, :story_slots, :preferred_sources, :boundary_relevance,
                          :retrieval_queries, :avoid, :referent_ids, :context_keys, :dimensions,
                          :evidence_requirements, :scope_rules, :fallback_behavior, keyword_init: true) do
    def summary
      { "intent" => intent, "target" => target, "breadth" => breadth, "answer_shape" => answer_shape,
        "story_slots" => story_slots, "boundary_relevance" => boundary_relevance, "referent_ids" => referent_ids,
        "dimensions" => dimensions, "evidence_requirements" => evidence_requirements,
        "scope_rules" => scope_rules, "fallback_behavior" => fallback_behavior }
    end
  end
end
