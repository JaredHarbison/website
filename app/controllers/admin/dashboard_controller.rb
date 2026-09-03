module Admin
  class DashboardController < BaseController
    def index
      @knowledge_counts = KnowledgeEntry.group(:approval_status).count
      @recent_entries = KnowledgeEntry.order(updated_at: :desc).limit(10)
      @direct_share_link = flash[:direct_share_link]
      flash.delete(:direct_share_link)
      @manual_opportunities = Opportunity.where(tracker_source: "manual").includes(:ask_token).order(created_at: :desc)
      @prospect_access_count = Opportunity.joins(:ask_token).count
      @active_access_count = AskToken.where(status: %w[available claimed submitted]).count
      @recent_activity = EngagementEvent.where(event_type: AskJared::EngagementExport::EVENT_TYPES).includes(:opportunity).order(occurred_at: :desc).limit(8)
      @issue_count = EngagementEvent.where(event_type: "issue_reported").count
      @open_issue_count = EngagementEvent.where(event_type: "issue_reported").pluck(:metadata).count { |metadata| (metadata["issue_status"].presence || "new") != "resolved" }
      @recruiter_visible_count = KnowledgeEntry.recruiter_retrievable.count
      @missing_embeddings_count = KnowledgeEntry.recruiter_retrievable.where(embedding: nil).count
      @mail_configured = ENV["JARED_ISSUE_EMAIL"].present?
    end
  end
end
