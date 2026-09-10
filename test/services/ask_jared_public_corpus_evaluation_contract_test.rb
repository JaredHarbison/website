require "test_helper"

class AskJaredPublicCorpusEvaluationContractTest < ActiveSupport::TestCase
  FIXTURE_PATH = Rails.root.join("test/fixtures/ask_jared_public_corpus_evaluation.yml")

  test "contains the frozen twenty-question evaluation contract" do
    cases = YAML.load_file(FIXTURE_PATH)

    assert_equal 20, cases.length
    assert_equal (1..20).map { |number| format("P%02d", number) }, cases.map { |item| item.fetch("id") }
    cases.each do |item|
      assert item.fetch("question").present?
      assert item.fetch("answer_shape").present?
      assert item.fetch("required_evidence").present?
      assert item.fetch("prohibited_claims").is_a?(Array)
      refute_empty item.fetch("prohibited_claims")
    end
  end

  test "documents evaluation labels separately from production routing vocabulary" do
    source = FIXTURE_PATH.read

    assert_includes source, "not production intent-routing vocabulary"
  end
end
