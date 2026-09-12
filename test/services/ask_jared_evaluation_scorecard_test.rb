require "test_helper"

class AskJaredEvaluationScorecardTest < ActiveSupport::TestCase
  test "tracks deterministic checks separately from reviewer judgment" do
    scorecard = AskJared::EvaluationScorecard.build(
      evaluation_case: { "answer_shape" => "direct", "required_evidence" => "technology_scope", "prohibited_claims" => [ "technology_extrapolation" ] },
      result: { "status" => "completed", "answer_status" => "answer", "answer" => "A concise sourced answer.", "evidence_ids" => [ "writing:rails" ], "validation" => "passed" }
    )

    assert_equal true, scorecard.dig("automatic", "availability")
    assert_equal true, scorecard.dig("automatic", "has_attributable_source")
    assert_equal false, scorecard.dig("automatic", "user_visible_validation_failure")
    assert_nil scorecard.dig("review", "grounding")
    assert_equal [ "technology_extrapolation" ], scorecard.dig("case_contract", "prohibited_claims")
  end
end
