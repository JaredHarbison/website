class AskUsageEvent < ApplicationRecord
  STATUSES = %w[completed provider_error rejected].freeze

  belongs_to :opportunity, optional: true
  belongs_to :ask_token, optional: true

  validates :request_id, :session_digest, :status, :occurred_at, presence: true
  validates :status, inclusion: { in: STATUSES }
end
