module Admin
  class OpportunitiesController < BaseController
    def index
      all = AskJared::EngagementExport.new.call
      @page = [ params.fetch(:page, 1).to_i, 1 ].max
      @opportunity_count = all.length
      @opportunities = all.slice((@page - 1) * 20, 20) || []
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
