module AskJared
  class KnowledgeEntry
    REVIEW_STATES = %w[candidate needs_review approved rejected private].freeze
    VISIBILITIES = %w[private public].freeze

    attr_accessor :id, :title, :body, :short_body, :entry_type,
                  :approval_status, :visibility, :confidence, :source_type,
                  :source_url, :public_url, :source_reference,
                  :source_fingerprint, :metadata, :reviewer_edits,
                  :reviewed_by, :reviewer_note, :approved_at

    def initialize(attributes = {})
      attributes.each { |key, value| public_send("#{key}=", value) if respond_to?("#{key}=") }
    end

    def approved_public?
      approval_status == "approved" && visibility == "public"
    end
  end
end
