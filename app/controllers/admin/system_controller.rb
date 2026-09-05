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
      answer_events = EngagementEvent.where(event_type: "answer_returned").where("occurred_at >= ?", 30.days.ago).where.not(activity_class: "internal_qa")
      statuses = answer_events.pluck(:metadata).group_by { |metadata| metadata["answer_status"].presence || "unknown" }.transform_values(&:count)
      @successful_answers = statuses.fetch("answer", 0)
      @intentional_responses = statuses.values_at("insufficient_information", "out_of_scope", "blocked").compact.sum
      @recent_failures = AskUsageEvent.where(status: "provider_error").where("occurred_at >= ?", 30.days.ago).count
      @recent_answers = answer_events.count
      @model_counts = answer_events.pluck(:metadata).group_by { |metadata| metadata["model"].presence || "Not recorded" }.transform_values(&:count)
      @resume_status = ApprovedResume.status
    end
  end
end
