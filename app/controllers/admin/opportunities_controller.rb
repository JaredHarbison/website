module Admin
  class OpportunitiesController < BaseController
    def index
      @opportunities = AskJared::EngagementExport.new.call
    end

    def show
      opportunity = Opportunity.find(params[:id])
      @summary = AskJared::EngagementExport.new(scope: Opportunity.where(id: opportunity.id)).call.first
      admin_not_found unless @summary
    rescue ActiveRecord::RecordNotFound
      admin_not_found
    end
  end
end
