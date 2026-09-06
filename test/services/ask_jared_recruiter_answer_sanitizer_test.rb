require "test_helper"
require_relative "../../app/services/ask_jared/recruiter_answer_sanitizer"

class AskJaredRecruiterAnswerSanitizerTest < ActiveSupport::TestCase
  test "translates internal boundary language into recruiter-facing language" do
    answer = AskJared::RecruiterAnswerSanitizer.clean(
      "Professional TypeScript depth is not established. Technology depth varies and should be evaluated by technology. Experience on large conventional engineering teams is also a gap, while adjacent collaboration and organizational-scale experience are demonstrated."
    )

    [ "not established", "should be evaluated", "demonstrated", "boundary", "approved evidence" ].each do |phrase|
      refute_includes answer.downcase, phrase
    end
    assert_includes answer, "TypeScript is newer territory"
  end
end
