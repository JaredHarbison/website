module Admin
  class SystemController < BaseController
    def index
      @knowledge_counts = KnowledgeEntry.group(:approval_status, :visibility).count
      @recruiter_count = KnowledgeEntry.recruiter_retrievable.count
      @missing_embeddings = KnowledgeEntry.recruiter_retrievable.where(embedding: nil).count
      @stale_embeddings = KnowledgeEntry.recruiter_retrievable.where.not(embedding_model: AskJared::EmbeddingService::MODEL).count
      @issue_email_configured = ENV["JARED_ISSUE_EMAIL"].present?
      @recognized_model = "gpt-5.6-terra"
      @fallback_model = ENV["ASK_JARED_MODEL"].presence || "configured fallback"
      @recent_failures = EngagementEvent.where(event_type: "answer_returned").where("occurred_at >= ?", 30.days.ago).pluck(:metadata).count { |metadata| metadata["answer_status"] != "answer" }
      @recent_answers = EngagementEvent.where(event_type: "answer_returned").where("occurred_at >= ?", 30.days.ago).count
    end
  end
end
