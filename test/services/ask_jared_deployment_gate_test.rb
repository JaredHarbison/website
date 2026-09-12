require "test_helper"

class AskJaredDeploymentGateTest < ActiveSupport::TestCase
  test "passes only completed, attributed results with telemetry and no visible validation failure" do
    result = { "status" => "completed", "reported_model" => "gpt-5.6-sol", "scorecard" => { "automatic" => { "has_attributable_source" => true, "user_visible_validation_failure" => false } } }

    assert AskJared::DeploymentGate.evaluate([ result ]).fetch("passed")
  end

  test "blocks an unattributed answer and an incomplete result" do
    result = { "status" => "provider_error", "reported_model" => nil, "scorecard" => { "automatic" => { "has_attributable_source" => false, "user_visible_validation_failure" => true } } }

    gate = AskJared::DeploymentGate.evaluate([ result ])
    refute gate.fetch("passed")
    assert_includes gate.fetch("failures"), "incomplete evaluation"
    assert_includes gate.fetch("failures"), "unattributed answer"
  end
end
