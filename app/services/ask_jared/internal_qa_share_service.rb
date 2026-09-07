module AskJared
  class InternalQaShareService
    def initialize(token_service: TokenService.new)
      @token_service = token_service
    end

    def create!(label:, purpose:, company: nil, expires_at: nil)
      ManualShareService.new(token_service: @token_service).create!(
        label: label, purpose: purpose, company: company, expires_at: expires_at, tracker_source: "internal_qa"
      )
    end
  end
end
