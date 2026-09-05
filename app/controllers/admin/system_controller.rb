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
      @observability = { "7 days" => observability_period(7.days.ago), "30 days" => observability_period(30.days.ago), "Lifetime" => observability_period(nil) }
      @resume_status = ApprovedResume.status
    end

    private

    def observability_period(since)
      answers = EngagementEvent.where(event_type: "answer_returned").where.not(activity_class: "internal_qa")
      answers = answers.where("occurred_at >= ?", since) if since
      metadata = answers.pluck(:metadata)
      usage = AskUsageEvent.where(status: "completed")
      usage = usage.where("occurred_at >= ?", since) if since
      errors = AskUsageEvent.where(status: "provider_error")
      errors = errors.where("occurred_at >= ?", since) if since
      {
        questions: metadata.length,
        substantive: metadata.count { |item| item["answer_status"] == "answer" },
        intentional: metadata.count { |item| %w[insufficient_information out_of_scope blocked].include?(item["answer_status"]) },
        provider_errors: errors.count,
        estimated_cost_cents: usage.sum(:estimated_cost_cents),
        input_tokens: metadata.sum { |item| item["input_tokens"].to_i },
        output_tokens: metadata.sum { |item| item["output_tokens"].to_i }
      }
    end
  end
end
