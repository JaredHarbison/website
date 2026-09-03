module AskJared
  class EngagementExport
    EVENT_TYPES = %w[page_view human_interaction question_submitted answer_returned issue_reported].freeze

    def initialize(scope: Opportunity.all)
      @scope = scope
    end

    def call(since: nil)
      opportunities = @scope.includes(:ask_token)
      opportunities = opportunities.where("opportunities.updated_at >= ?", since) if since
      opportunities.find_each.map { |opportunity| summarize(opportunity) }
    end

    private

    def summarize(opportunity)
      events = opportunity.engagement_events.where(meaningful: true, event_type: EVENT_TYPES - [ "page_view" ])
      page_views = opportunity.engagement_events.where(event_type: "page_view")
      sessions = events.where.not(session_digest: nil).distinct.count(:session_digest)
      networks = events.where.not(ip_digest: nil).distinct.count(:ip_digest)
      questions = events.where(event_type: "question_submitted").count
      issues = events.where(event_type: "issue_reported").count
      question_events = events.where(event_type: "question_submitted").order(:occurred_at)
      latest_question = question_events.last&.metadata&.fetch("question", nil)
      latest_answer = events.where(event_type: "answer_returned").order(:occurred_at).last&.metadata || {}
      first_at = events.minimum(:occurred_at)
      last_at = events.maximum(:occurred_at)

      {
        external_id: opportunity.external_id,
        company: opportunity.company,
        role_title: opportunity.role_title,
        purpose: opportunity.purpose,
        source: opportunity.tracker_source.presence || "application",
        application_conversion_eligible: opportunity.tracker_source != "manual",
        application_state: opportunity.application_state,
        submitted_at: opportunity.submitted_at,
        token_state: opportunity.ask_token&.status,
        first_meaningful_engagement_at: first_at,
        last_meaningful_engagement_at: last_at,
        meaningful_session_count: sessions,
        meaningful_question_count: questions,
        page_view_count: page_views.count,
        most_recent_question: latest_question,
        most_recent_answer_status: latest_answer["answer_status"],
        issue_report_count: issues,
        possible_internal_share: sessions > 1 || networks > 1,
        internal_share_confidence: share_confidence(sessions, networks, questions),
        follow_up_candidate: follow_up_candidate?(opportunity, questions, last_at),
        usage_cost_cents: opportunity.ask_usage_events.sum(:estimated_cost_cents)
      }
    end

    def share_confidence(sessions, networks, questions)
      return "none" if sessions.zero?
      return "medium" if questions >= 2 && (sessions > 1 || networks > 1)

      "low"
    end

    def follow_up_candidate?(opportunity, questions, last_at)
      opportunity.application_state == "submitted" && questions >= 2 && last_at.present? && last_at < 7.days.ago
    end
  end
end
