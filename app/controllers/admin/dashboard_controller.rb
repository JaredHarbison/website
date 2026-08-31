module Admin
  class DashboardController < BaseController
    def index
      @knowledge_counts = KnowledgeEntry.group(:approval_status).count
      @recent_entries = KnowledgeEntry.order(updated_at: :desc).limit(10)
      @direct_share_link = flash.delete(:direct_share_link)
      @manual_opportunities = Opportunity.where(tracker_source: "manual").includes(:ask_token).order(created_at: :desc)
    end
  end
end
