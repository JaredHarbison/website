module AskJared
  class EngagementExport
    EVENT_TYPES = %w[human_interaction question_submitted answer_returned].freeze

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
      events = opportunity.engagement_events.where(meaningful: true, event_type: EVENT_TYPES)
      sessions = events.where.not(session_digest: nil).distinct.count(:session_digest)
      networks = events.where.not(ip_digest: nil).distinct.count(:ip_digest)
      questions = events.where(event_type: "question_submitted").count
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
