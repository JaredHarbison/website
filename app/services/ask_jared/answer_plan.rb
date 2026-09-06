module AskJared
  AnswerPlan = Struct.new(:architecture, :version, :intent, :target, :breadth, :answer_shape,
                          :themes, :story_slots, :preferred_sources, :boundary_relevance,
                          :retrieval_queries, :avoid, :referent_ids, :context_keys, keyword_init: true) do
    def summary
      { "intent" => intent, "target" => target, "breadth" => breadth, "answer_shape" => answer_shape,
        "story_slots" => story_slots, "boundary_relevance" => boundary_relevance, "referent_ids" => referent_ids }
    end
  end
end
