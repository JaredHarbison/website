require "test_helper"
require "yaml"

class AskJaredQuestionDecompositionContractTest < ActiveSupport::TestCase
  FIXTURE_PATH = Rails.root.join("test/fixtures/ask_jared_question_decomposition.yml")

  test "keeps the forty-question decomposition matrix broad and explicit" do
    cases = YAML.load_file(FIXTURE_PATH)

    assert_equal 40, cases.length
    assert_equal (1..40).map { |number| format("D%02d", number) }, cases.map { |item| item.fetch("id") }
    assert_includes cases.map { |item| item.fetch("category") }, "follow_up"
    assert_includes cases.map { |item| item.fetch("category") }, "scope"
    assert_includes cases.map { |item| item.fetch("category") }, "adversarial"
    assert_includes cases.map { |item| item.fetch("category") }, "metric"
    assert cases.all? { |item| item.fetch("question").present? && item.fetch("parts").between?(1, 4) }
  end
end
