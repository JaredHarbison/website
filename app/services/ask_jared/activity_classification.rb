module AskJared
  module ActivityClassification
    QA_TRACKER_SOURCES = %w[qa internal_qa].freeze

    module_function

    def internal_qa?(opportunity)
      opportunity && QA_TRACKER_SOURCES.include?(opportunity.tracker_source.to_s)
    end

    def for(opportunity, requested = nil)
      return "internal_qa" if internal_qa?(opportunity)
      return requested.to_s if %w[manual_share unclassified].include?(requested.to_s)
      return "manual_share" if opportunity&.tracker_source == "manual"

      "unclassified"
    end
  end
end
