module AskJared
  class SubmissionService
    SubmissionConflict = Class.new(StandardError)
    def initialize(token_service: TokenService.new)
      @token_service = token_service
    end

    def call(raw_token:, external_id:, company:, role_title:, tracker_source: nil, submitted_at: nil)
      raise ArgumentError, "external_id is required" if external_id.blank?
      raise ArgumentError, "company is required" if company.blank?
      raise ArgumentError, "role_title is required" if role_title.blank?

      Opportunity.transaction do
        opportunity = Opportunity.create_or_find_by!(external_id: external_id) do |record|
          record.company = company
          record.role_title = role_title
          record.tracker_source = tracker_source
          record.application_state = "ready"
        end
        token = @token_service.resolve(raw_token)
        raise ActiveRecord::RecordNotFound, "Ask token is invalid or unavailable" unless token
        raise ActiveRecord::RecordNotFound, "Manual share links cannot submit applications" if token.opportunity&.tracker_source == "manual"
        if opportunity.company != company || opportunity.role_title != role_title
          raise SubmissionConflict, "External opportunity details do not match the existing record"
        end
        if opportunity.ask_token && opportunity.ask_token.id != token.id
          raise SubmissionConflict, "External opportunity is already bound to another Ask token"
        end

        token.with_lock do
          if token.opportunity_id && token.opportunity_id != opportunity.id
            raise TokenService::TokenAlreadyClaimed, "Ask token is already claimed"
          end

          token.update!(opportunity: opportunity, claim_key: external_id, status: "submitted",
                        claimed_at: token.claimed_at || Time.current,
                        expires_at: token.expires_at || TokenService::CLAIM_LIFETIME.from_now)
        end
        opportunity.update!(application_state: "submitted", submitted_at: submitted_at.presence || opportunity.submitted_at || Time.current)
        opportunity
      end
    end
  end
end
