require "test_helper"

class CaseStudyTest < ActiveSupport::TestCase
  test "reports missing required sections" do
    case_study = CaseStudy.new(body: "## Overview\n\n## Problem\n")

    assert_includes case_study.missing_sections, "Context"
    assert_not_includes case_study.missing_sections, "Overview"
  end

  test "the published Karaoke Queue case study has the standard structure" do
    case_study = ContentRepository.new(collection: "case_studies", model: CaseStudy).find!("karaoke-queue")

    assert_empty case_study.missing_sections
  end
end
