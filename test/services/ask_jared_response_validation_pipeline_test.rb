require "test_helper"

class AskJaredResponseValidationPipelineTest < ActiveSupport::TestCase
  test "uses one bounded repair pass after an evidence violation" do
    calls = []
    result = AskJared::ResponseValidationPipeline.new.call(
      response: { "attempt" => 1 },
      repair: ->(response, violations) { calls << [ response, violations ]; { "attempt" => 2 } }
    ) do |response|
      raise AskJared::EvidenceIntegrity::Violation, "unsupported claim" if response.fetch("attempt") == 1

      { "status" => "answer" }
    end

    assert result.valid?
    assert_equal({ "status" => "answer" }, result.response)
    assert_equal [ [ { "attempt" => 1 }, [ "unsupported claim" ] ] ], calls
  end

  test "reports both validation failures without a second repair" do
    result = AskJared::ResponseValidationPipeline.new.call(
      response: { "attempt" => 1 }, repair: ->(*) { { "attempt" => 2 } }
    ) { raise AskJared::EvidenceIntegrity::Violation, "still unsupported" }

    refute result.valid?
    assert_equal "still unsupported; still unsupported", result.failure_reason
  end
end
