require "openssl"

module AskJared
  class EngagementService
    MEANINGFUL_EVENTS = %w[human_interaction question_submitted answer_returned issue_reported contact_message_submitted resume_verification_requested resume_email_verified resume_requested resume_delivery_succeeded resume_delivery_failed].freeze

    def initialize(secret: Rails.application.secret_key_base)
      @secret = secret
    end

    def record!(raw_token:, event_type:, session_id:, ip: nil, user_agent_class: nil, event_key: nil, metadata: {})
      raise ArgumentError, "unsupported engagement event" unless EngagementEvent::EVENT_TYPES.include?(event_type)
      raise ArgumentError, "session_id is required" if session_id.blank?

      token = TokenService.new(secret: @secret).resolve(raw_token)
      raise ActiveRecord::RecordNotFound, "Ask token is invalid or unavailable" unless token

      key = event_key.presence || default_event_key(token, event_type, session_id)
      EngagementEvent.create_or_find_by!(event_key: key) do |event|
        event.opportunity = token.opportunity
        event.ask_token = token
        event.event_type = event_type
        event.session_digest = digest(session_id)
        event.ip_digest = digest(ip) if ip.present?
        event.user_agent_class = user_agent_class.to_s.first(80)
        event.activity_class = metadata[:activity_class].presence || metadata["activity_class"].presence || (token.opportunity&.tracker_source == "manual" ? "manual_share" : "unclassified")
        event.metadata = metadata.stringify_keys.slice(
          "source", "question_category", "primary_evidence_reference", "question_intent", "question", "answer",
          "answer_status", "evidence_ids", "skeleton_roles", "model", "validation", "issue_category", "feedback",
          "page", "turn", "browser", "device", "server_error", "contact", "name", "email", "message",
          "company", "role", "verification_id", "delivery_status", "latency_ms", "input_tokens", "output_tokens",
          "estimated_cost_cents", "pricing_version", "intent_path", "evidence_count", "answer_status", "answer_event_id", "issue_answer_event_id",
          "architecture", "planner_version", "planner_model", "context_keys", "plan_summary", "example_evidence_ids"
        )
        event.occurred_at = Time.current
        event.meaningful = MEANINGFUL_EVENTS.include?(event_type)
      end
    end

    def record_for_token!(token:, event_type:, session_id:, metadata: {}, event_key: nil)
      raise ArgumentError, "session_id is required" if session_id.blank?
      raise ArgumentError, "token is required" unless token

      key = event_key.presence || default_event_key(token, event_type, session_id)
      EngagementEvent.create_or_find_by!(event_key: key) do |event|
        event.opportunity = token.opportunity
        event.ask_token = token
        event.event_type = event_type
        event.session_digest = digest(session_id)
        event.metadata = metadata.stringify_keys.slice(
          "email", "verification_id", "delivery_status", "page", "source"
        )
        event.occurred_at = Time.current
        event.meaningful = MEANINGFUL_EVENTS.include?(event_type)
        event.activity_class = token.opportunity&.tracker_source == "manual" ? "manual_share" : "unclassified"
      end
    end

    def session_digest(session_id)
      digest(session_id)
    end

    private

    def default_event_key(token, event_type, session_id)
      digest([ token.id, event_type, session_id, Time.current.to_i / 300 ].join(":"))
    end

    def digest(value)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("SHA256"), @secret, value.to_s)
    end
  end
end
