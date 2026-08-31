require "securerandom"

module AskJared
  class ManualShareService
    DEFAULT_COMPANY = "Direct share"

    def initialize(token_service: TokenService.new)
      @token_service = token_service
    end

    def create!(label:, purpose:, company: nil, expires_at: nil)
      label = label.to_s.strip
      purpose = purpose.to_s.strip
      raise ArgumentError, "label is required" if label.blank?
      raise ArgumentError, "purpose is required" if purpose.blank?

      token, raw_token = @token_service.mint!(expires_at: expires_at || TokenService::CLAIM_LIFETIME.from_now)
      opportunity = @token_service.claim!(
        raw_token: raw_token,
        external_id: "manual:#{SecureRandom.uuid}",
        company: company.presence || DEFAULT_COMPANY,
        role_title: label,
        tracker_source: "manual"
      )
      opportunity.update!(application_state: "pre_application", purpose: purpose)
      [ opportunity, token, raw_token ]
    end
  end
end
