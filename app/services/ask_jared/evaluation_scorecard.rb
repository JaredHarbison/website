module AskJared
  # Separates deterministic run checks from reviewer judgment. A source ID is
  # not proof that every sentence is grounded, so the latter is deliberately
  # left for the scored review rather than fabricated as an automatic pass.
  class EvaluationScorecard
    REVIEW_DIMENSIONS = %w[grounding relevance directness completeness scope_correctness boundary_quality naturalness].freeze

    def self.build(evaluation_case:, result:)
      answer = result["answer"].to_s
      completed = result["status"] == "completed"
      answer_status = result["answer_status"].to_s
      evidence_ids = Array(result["evidence_ids"])
      {
        "automatic" => {
          "availability" => completed && %w[answer insufficient_information].include?(answer_status),
          "has_attributable_source" => answer_status != "answer" || evidence_ids.any?,
          "concise" => answer.split.length <= 180,
          "user_visible_validation_failure" => answer_status == "validation_failure" || result["validation"] == "failed"
        },
        "review" => REVIEW_DIMENSIONS.index_with { nil },
        "case_contract" => evaluation_case.slice("answer_shape", "required_evidence", "prohibited_claims")
      }
    end
  end
end
