require "openssl"

module AskJared
  class UsageGuard
    LimitExceeded = Class.new(StandardError)
    MAX_QUESTIONS_PER_TOKEN_PER_DAY = 20
    MAX_QUESTIONS_PER_SESSION_PER_HOUR = 4
    DEFAULT_DAILY_COST_CENTS = 500

    def initialize(now: Time.current, daily_cost_cents: ENV.fetch("ASK_JARED_DAILY_COST_CENTS", DEFAULT_DAILY_COST_CENTS).to_i)
      @now = now
      @daily_cost_cents = daily_cost_cents
    end

    def check!(token:, session_digest:)
      raise LimitExceeded, "token question limit reached" if AskUsageEvent.where(ask_token: token).where("occurred_at >= ?", @now - 1.day).count >= MAX_QUESTIONS_PER_TOKEN_PER_DAY
      raise LimitExceeded, "session question limit reached" if AskUsageEvent.where(session_digest: session_digest).where("occurred_at >= ?", @now - 1.hour).count >= MAX_QUESTIONS_PER_SESSION_PER_HOUR
      raise LimitExceeded, "daily answer budget reached" if AskUsageEvent.where("occurred_at >= ?", @now.beginning_of_day).sum(:estimated_cost_cents) >= @daily_cost_cents
    end

    def digest_session(session_id)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("SHA256"), Rails.application.secret_key_base, session_id.to_s)
    end

    def record!(token:, session_digest:, request_id:, status:, estimated_cost_cents: 0, input_tokens: nil, output_tokens: nil)
      AskUsageEvent.create_or_find_by!(request_id: request_id) do |event|
        event.opportunity = token.opportunity
        event.ask_token = token
        event.session_digest = session_digest
        event.status = status
        event.estimated_cost_cents = estimated_cost_cents
        event.input_tokens = input_tokens
        event.output_tokens = output_tokens
        event.occurred_at = @now
      end
    end
  end
end
