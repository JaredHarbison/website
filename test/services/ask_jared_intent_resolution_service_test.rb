require "test_helper"

class AskJaredIntentResolutionServiceTest < ActiveSupport::TestCase
  Context = Struct.new(:records)

  test "resolves project pride and contribution as a compound contract" do
    provider = Class.new do
      def structured_call(**)
        {
          "result" => {
            "primary_intent" => "project_story",
            "intent_candidates" => %w[project_story contribution],
            "question_parts" => [
              { "subject" => "project", "operation" => "select", "dimensions" => [ "product_judgment" ], "scope" => "unrestricted", "evidence_requirements" => [ "project_identity" ] },
              { "subject" => "role", "operation" => "describe", "dimensions" => [ "contribution", "ownership" ], "scope" => "unrestricted", "evidence_requirements" => [ "direct_contribution", "ownership_boundary" ] }
            ],
            "answer_shape" => "compound", "compound" => true, "confidence" => 0.96
          },
          "__telemetry" => { "input_tokens" => 10, "output_tokens" => 20 }
        }
      end
    end.new

    result = AskJared::IntentResolutionService.new(
      provider: provider,
      context: Context.new([])
    ).call(question: "Tell me about a product he's proud of and what role did he play in it?")

    assert_equal "project_story", result["primary"]
    assert_equal %w[project_story contribution], result["candidates"]
    assert result["compound"]
    assert_includes result["planning_reasons"], "compound_question"
    assert_equal "model", result["resolution_mode"] if result["resolution_mode"]
  end

  test "fails closed to an explicit unclassified contract when provider is unavailable" do
    result = AskJared::IntentResolutionService.new(provider: Object.new, context: Context.new([])).call(question: "What did he build?")

    assert_equal "unclassified", result["primary"]
    assert_equal [ "unclassified" ], result["candidates"]
    assert_equal [ "intent_resolution_unavailable" ], result["planning_reasons"]
  end
end
