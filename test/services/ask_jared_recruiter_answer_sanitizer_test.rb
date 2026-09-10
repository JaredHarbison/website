require "test_helper"
require_relative "../../app/services/ask_jared/recruiter_answer_sanitizer"

class AskJaredRecruiterAnswerSanitizerTest < ActiveSupport::TestCase
  test "removes adjacent duplicated words from model prose" do
    assert_equal "TypeScript is best considered specifically by technology.",
                 AskJared::RecruiterAnswerSanitizer.clean("TypeScript is best considered specifically specifically by technology.")
  end

  test "translates internal boundary language into recruiter-facing language" do
    answer = AskJared::RecruiterAnswerSanitizer.clean(
      "Professional TypeScript depth is not established. Technology depth varies and should be evaluated by technology. A hiring manager should evaluate depth by technology rather than infer it globally. Experience on large conventional engineering teams is also a gap, while adjacent collaboration and organizational-scale experience are demonstrated."
    )

    [ "not established", "should be evaluated", "should evaluate", "demonstrated", "boundary", "approved evidence" ].each do |phrase|
      refute_includes answer.downcase, phrase
    end
    assert_includes answer, "TypeScript is newer territory"
  end
end
