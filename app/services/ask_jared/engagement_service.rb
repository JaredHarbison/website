require "openssl"

module AskJared
  class EngagementService
    MEANINGFUL_EVENTS = %w[human_interaction question_submitted answer_returned issue_reported].freeze

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
        event.metadata = metadata.slice(
          "source", "question_category", "primary_evidence_reference", "question_intent", "question", "answer",
          "answer_status", "evidence_ids", "skeleton_roles", "model", "validation", "issue_category", "feedback",
          "page", "turn", "browser", "device", "server_error", "contact"
        )
        event.occurred_at = Time.current
        event.meaningful = MEANINGFUL_EVENTS.include?(event_type)
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
