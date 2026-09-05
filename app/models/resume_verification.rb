class ResumeVerification < ApplicationRecord
  belongs_to :opportunity, optional: true
  belongs_to :ask_token, optional: true

  validates :token_digest, :email, :session_digest, :expires_at, presence: true

  def active?
    verified_at.blank? && expires_at.future?
  end
end
