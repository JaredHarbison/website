class CaseStudy < ContentEntry
  REQUIRED_SECTIONS = [
    "Overview",
    "Problem",
    "Context",
    "Constraints",
    "My Role",
    "Approach",
    "Technical Implementation",
    "Tradeoffs",
    "Outcome",
    "What I'd Improve Today"
  ].freeze

  def missing_sections
    REQUIRED_SECTIONS.reject { |section| body.match?(/^##\s+#{Regexp.escape(section)}\s*$/i) }
  end
end
