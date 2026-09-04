module AskJared
  class IssueReportService
    CATEGORIES = [ "Incorrect fact", "Confusing answer", "Missing context", "Technical issue", "Other" ].freeze

    def initialize(token_service: TokenService.new, engagement_service: EngagementService.new)
      @token_service = token_service
      @engagement_service = engagement_service
    end

    def call(raw_token:, session_id:, question:, answer:, answer_status:, category:, feedback:, contact:, page:, ip:, user_agent:)
      token = @token_service.resolve(raw_token)
      raise ActiveRecord::RecordNotFound, "Ask token is invalid or unavailable" unless @token_service.recruiter_accessible?(token)
      raise ArgumentError, "issue category is invalid" unless CATEGORIES.include?(category.to_s)
      raise ArgumentError, "feedback is required" if feedback.to_s.strip.blank?

      answer_context = latest_answer_context(token, session_id, question, answer)

      event = @engagement_service.record!(
        raw_token: raw_token, event_type: "issue_reported", session_id: session_id, ip: ip,
        user_agent_class: user_agent.to_s.match?(/mobile|tablet/i) ? "mobile" : "desktop",
        event_key: "#{SecureRandom.uuid}:issue",
        metadata: {
          "question" => question.to_s.first(600), "answer" => answer.to_s.first(10_000),
          "answer_status" => answer_status.to_s, "issue_category" => category.to_s,
          "feedback" => feedback.to_s.first(2_000), "page" => page.to_s.first(200),
          "browser" => user_agent.to_s.first(200), "device" => user_agent.to_s.match?(/mobile|tablet/i) ? "mobile" : "desktop",
          "contact" => contact.to_s.first(200)
        }.merge(answer_context)
      )
      enqueue_notification(event, token.opportunity, contact.to_s.first(200)) if ENV["JARED_ISSUE_EMAIL"].present?
      event
    end

    private

    def latest_answer_context(token, session_id, question, answer)
      digest = @engagement_service.session_digest(session_id)
      event = token.opportunity.engagement_events
        .where(ask_token: token, session_digest: digest, event_type: "answer_returned")
        .order(occurred_at: :desc).find do |candidate|
          candidate.metadata["question"].to_s == question.to_s && candidate.metadata["answer"].to_s == answer.to_s
        end
      return {} unless event

      event.metadata.slice("question_intent", "evidence_ids", "skeleton_roles", "model", "validation", "turn")
    end

    def enqueue_notification(event, opportunity, contact)
      AskJaredMailer.issue_report(event, opportunity, contact).deliver_later
    rescue StandardError => error
      Rails.logger.error("Ask Jared issue notification failed for event #{event.id}: #{error.class}: #{error.message}")
    end
  end
end
