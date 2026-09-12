require "test_helper"
require "tempfile"

class AskJaredPublicCorpusRulesTest < ActiveSupport::TestCase
  test "loads the versioned compact Rules registry" do
    rules = AskJared::PublicCorpusRules.new

    assert_equal 1, rules.version
    assert_equal 7, rules.rules.length
    assert_equal rules.rules.length, rules.rules.map { |rule| rule.fetch("id") }.uniq.length
    assert rules.instructions.all? { |instruction| instruction.length <= 280 }
  end

  test "covers every durable claim boundary from the evaluation contract" do
    instructions = AskJared::PublicCorpusRules.instructions.join(" ")

    %w[lifecycle comparison ownership attribution technology domain presentation].each do |id|
      assert_includes AskJared::PublicCorpusRules.data.fetch("rules").map { |rule| rule.fetch("id") }, id
    end
    assert_includes instructions, "pride"
    assert_includes instructions, "metric provenance"
    assert_includes instructions, "unsupported premises"
  end

  test "rejects malformed or duplicate rules" do
    Tempfile.create([ "ask-jared-rules", ".yml" ]) do |file|
      file.write <<~YAML
        version: 1
        rules:
          - id: duplicate
            instruction: First rule.
          - id: duplicate
            instruction: Second rule.
      YAML
      file.flush

      error = assert_raises(ArgumentError) { AskJared::PublicCorpusRules.new(path: file.path) }
      assert_includes error.message, "duplicate ids"
    end
  end

  test "adds each boundary to the Rules arm prompt without factual material" do
    provider = Class.new do
      attr_reader :request
      def structured_call(**request)
        @request = request
        { "result" => { "status" => "insufficient_information", "direct_answer" => "The supplied writing does not establish that.", "supporting_example" => "", "qualification" => "", "source_ids" => [] } }
      end
    end.new
    answerer = AskJared::PublicCorpusAnswerer.new(provider: provider, retriever: ->(*) { [] }, rules: AskJared::PublicCorpusRules.new)

    answerer.call(question: "What is Jared's proudest product?")

    AskJared::PublicCorpusRules.instructions.each { |instruction| assert_includes provider.request.fetch(:system_prompt), instruction }
    refute_includes provider.request.fetch(:system_prompt), "Dogly"
    refute_includes provider.request.fetch(:system_prompt), "Jared has"
  end
end
