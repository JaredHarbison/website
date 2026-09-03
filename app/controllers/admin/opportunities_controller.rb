module Admin
  class OpportunitiesController < BaseController
    def index
      @opportunities = AskJared::EngagementExport.new.call
    end

    def show
      opportunity = Opportunity.find(params[:id])
      @summary = AskJared::EngagementExport.new(scope: Opportunity.where(id: opportunity.id)).call.first
      @events = opportunity.engagement_events
        .where(event_type: AskJared::EngagementExport::EVENT_TYPES)
        .order(occurred_at: :asc)
      admin_not_found unless @summary
    rescue ActiveRecord::RecordNotFound
      admin_not_found
    end
  end
end
