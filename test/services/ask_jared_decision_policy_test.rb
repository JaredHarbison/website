require "test_helper"

class AskJaredDecisionPolicyTest < ActiveSupport::TestCase
  test "has a complete contract for every supported answer shape" do
    assert AskJared::DecisionPolicy.assert_complete!
  end

  test "uses an explicit scope contract rather than question wording" do
    contract = AskJared::DecisionPolicy.contract_for(intent: "scope", answer_shape: "direct")

    assert_includes contract.scope_rules, "Exclude Dogly evidence unless explicitly labeled as comparison context."
    assert_equal [ "employer_or_project_identity", "direct_contribution" ], contract.evidence_requirements
  end

  test "compound decisions always preserve per-part answer behavior" do
    contract = AskJared::DecisionPolicy.contract_for(intent: "soft_skills", answer_shape: "profile", compound: true)

    assert_includes contract.evidence_requirements, "one_supported_answer_for_each_intent_family"
    assert_match(/supported parts independently/, contract.fallback_behavior)
  end
end
