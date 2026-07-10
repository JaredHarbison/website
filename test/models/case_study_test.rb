require "test_helper"

class CaseStudyTest < ActiveSupport::TestCase
  test "reports missing required sections" do
    case_study = CaseStudy.new(body: "## Overview\n\n## Problem\n")

    assert_includes case_study.missing_sections, "Context"
    assert_not_includes case_study.missing_sections, "Overview"
  end
end
