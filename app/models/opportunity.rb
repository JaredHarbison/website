class Opportunity < ApplicationRecord
  APPLICATION_STATES = %w[pre_application ready submitted withdrawn closed].freeze

  has_one :ask_token, dependent: :nullify

  validates :external_id, :company, :role_title, presence: true
  validates :application_state, inclusion: { in: APPLICATION_STATES }
end
