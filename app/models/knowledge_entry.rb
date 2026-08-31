class KnowledgeEntry < ApplicationRecord
  ENTRY_TYPES = %w[
    fact project engineering_story product_story metric capability tradeoff
    debugging_story leadership_story integration_story performance_story
    incident_story career_context interview_story
  ].freeze
  APPROVAL_STATUSES = %w[candidate needs_review approved rejected].freeze
  VISIBILITIES = %w[private internal recruiter_visible].freeze

  validates :title, :body, :entry_type, :source_type, :source_reference,
            :source_fingerprint, presence: true
  validates :entry_type, inclusion: { in: ENTRY_TYPES }
  validates :approval_status, inclusion: { in: APPROVAL_STATUSES }
  validates :visibility, inclusion: { in: VISIBILITIES }

  scope :recruiter_retrievable, -> { where(approval_status: "approved", visibility: "recruiter_visible") }
end
