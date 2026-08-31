class AskToken < ApplicationRecord
  STATUSES = %w[available claimed submitted revoked expired].freeze

  belongs_to :opportunity, optional: true

  validates :token_digest, :token_prefix, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  scope :available_now, -> { where(status: "available").where("expires_at IS NULL OR expires_at > ?", Time.current) }
end
