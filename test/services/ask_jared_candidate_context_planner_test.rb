require "test_helper"

class AskJaredCandidateContextPlannerTest < ActiveSupport::TestCase
  test "loads guidance for every selected intent family" do
    context = Class.new do
      attr_reader :requested

      def initialize
        @requested = []
      end

      def version = "candidate-context-v2"

      def for(intent, question:)
        @requested << intent
        [ { "key" => "#{intent}-contract", "purpose" => intent.to_s, "guidance" => "#{intent} guidance", "source_references" => [], "affects" => [ "retrieval" ], "intents" => [ intent ], "priority" => 10 } ]
      end

      def context_keys(records) = records.map { |record| record.fetch("key") }
    end.new

    plan = AskJared::CandidateContextPlanner.new(context: context).call(
      question: "How does Jared collaborate and handle disagreement?",
      intent: "collaboration",
      intent_candidates: %w[collaboration disagreement],
      planning_required: true,
      planning_reasons: %w[multiple_intent_families compound_question]
    )

    assert_equal %w[collaboration disagreement], context.requested
    assert_equal %w[collaboration-contract disagreement-contract], plan.context_keys
    assert_includes plan.evidence_requirements, "one_supported_answer_for_each_intent_family"
  end

  test "gets the scope contract from the decision policy" do
    context = Class.new do
      def version = "candidate-context-v2"
      def for(*) = []
      def context_keys(*) = []
    end.new

    plan = AskJared::CandidateContextPlanner.new(context: context).call(
      question: "What has Jared built outside Dogly?",
      intent: "scope",
      resolution: { "answer_shape" => "direct" }
    )

    assert_includes plan.scope_rules, "Exclude Dogly evidence unless explicitly labeled as comparison context."
    assert_includes plan.retrieval_queries, "independent product project outside Dogly Rails"
  end
end
