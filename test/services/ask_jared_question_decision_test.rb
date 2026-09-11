require "test_helper"

class AskJaredQuestionDecisionTest < ActiveSupport::TestCase
  test "normalizes a model result into the persisted decision contract" do
    decision = AskJared::QuestionDecision.from_resolution(
      primary: "scope", candidates: [ "scope", "not-real" ], answer_shape: "direct", compound: false,
      unsupported_subrequests: [ { subject: "technology", reason: "unsupported_quantification" } ], confidence: 1.4, planning_required: true, planning_reasons: [ "model_intent_resolution" ], resolution_mode: "model",
      parts: [ { subject: "project", operation: "describe", dimensions: [ "employer", "not-real" ], scope: "non_dogly", evidence_requirements: [ "employer_identity" ] } ]
    )

    assert decision.recognized?
    assert_equal [ "scope" ], decision.candidates
    assert_equal 1.0, decision.confidence
    assert_equal [ "employer" ], decision.parts.first.fetch("dimensions")
    assert_equal [ { "subject" => "technology", "reason" => "unsupported_quantification" } ], decision.unsupported_subrequests
    assert_equal "model", decision.to_h.fetch("resolution_mode")
  end

  test "fails closed to an unclassified decision" do
    decision = AskJared::QuestionDecision.from_resolution({})

    refute decision.recognized?
    assert_equal "insufficient", decision.answer_shape
    assert_equal "unknown", decision.parts.first.fetch("scope")
  end
end
