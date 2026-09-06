class CandidateContextRecord < ApplicationRecord
  APPROVAL_STATUSES = %w[draft approved retired].freeze
  CATEGORIES = %w[positioning capability_relationship story_map career_context boundary_context recruiter_intent voice role_fit interview_signals aspiration].freeze
  PRIVACY_CLASSIFICATIONS = %w[private].freeze

  validates :stable_key, :corpus_version, :category, :guidance, :privacy_classification, presence: true
  validates :approval_status, inclusion: { in: APPROVAL_STATUSES }
  validates :category, inclusion: { in: CATEGORIES }
  validates :privacy_classification, inclusion: { in: PRIVACY_CLASSIFICATIONS }

  scope :approved_for_planning, -> { where(approval_status: "approved", privacy_classification: "private") }
end
