require "test_helper"

class AskJaredIntentRouterTest < ActiveSupport::TestCase
  setup { @router = AskJared::IntentRouter.new }

  test "routes common recruiter umbrella questions" do
    assert_equal "soft_skills", @router.primary_intent("What are Jared's interpersonal skills?")
    assert_equal "role_fit", @router.primary_intent("How would Jared fit a product engineering role?")
    assert_equal "architecture", @router.primary_intent("How does Jared approach system design?")
    assert_equal "integration", @router.primary_intent("What experience does Jared have with APIs?")
    assert_equal "career", @router.primary_intent("How would you describe Jared's engineering trajectory?")
  end

  test "retains multiple candidates and marks compound questions for planning" do
    result = @router.analyze("How does Jared collaborate and handle technical disagreement?")

    assert_includes result[:candidates], "collaboration"
    assert_includes result[:candidates], "disagreement"
    assert result[:planning_required]
    assert_includes result[:planning_reasons], "compound_question"
  end

  test "marks unknown questions for planning rather than pretending to know the intent" do
    result = @router.analyze("What should a recruiter understand about Jared?")

    assert_nil result[:primary]
    assert result[:planning_required]
    assert_includes result[:planning_reasons], "unknown_intent"
  end
end
