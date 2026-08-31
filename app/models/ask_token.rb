class AskToken < ApplicationRecord
  STATUSES = %w[available claimed submitted revoked expired].freeze
  ACCESS_SCOPES = %w[opportunity direct_share].freeze

  belongs_to :opportunity, optional: true

  validates :token_digest, :token_prefix, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :access_scope, inclusion: { in: ACCESS_SCOPES }

  scope :available_now, -> { where(status: "available").where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :not_exported, -> { where(exported_at: nil) }
end
