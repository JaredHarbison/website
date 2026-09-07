class EngagementEvent < ApplicationRecord
  ACTIVITY_CLASSES = %w[prospect manual_share internal_qa unclassified].freeze
  EVENT_TYPES = %w[token_resolved page_view human_interaction question_submitted answer_returned issue_reported contact_message_submitted resume_verification_requested resume_email_verified resume_requested resume_delivery_succeeded resume_delivery_failed].freeze

  belongs_to :opportunity, optional: true
  belongs_to :ask_token, optional: true

  validates :event_type, :event_key, :session_digest, :occurred_at, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :activity_class, inclusion: { in: ACTIVITY_CLASSES }

  scope :meaningful_events, -> { where(meaningful: true) }
  scope :from_internal_qa, -> { joins(:opportunity).where(opportunities: { tracker_source: AskJared::ActivityClassification::QA_TRACKER_SOURCES }) }
  scope :from_real_prospect, -> { where.not(opportunity_id: Opportunity.where(tracker_source: AskJared::ActivityClassification::QA_TRACKER_SOURCES).select(:id)) }
  scope :from_live_recruiter, -> { from_real_prospect.where("engagement_events.occurred_at >= ?", AskJared::AnalyticsBoundary.live_at) }
end
