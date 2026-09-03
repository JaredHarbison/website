class EngagementEvent < ApplicationRecord
  EVENT_TYPES = %w[token_resolved page_view human_interaction question_submitted answer_returned issue_reported].freeze

  belongs_to :opportunity, optional: true
  belongs_to :ask_token, optional: true

  validates :event_type, :event_key, :session_digest, :occurred_at, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }

  scope :meaningful_events, -> { where(meaningful: true) }
end
