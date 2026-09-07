module AskJared
  module AnalyticsBoundary
    ENV_KEY = "ASK_JARED_ANALYTICS_LIVE_AT".freeze
    UNSET_LIVE_AT = Time.utc(9999, 12, 31, 23, 59, 59).freeze

    module_function

    def live_at
      value = ENV[ENV_KEY].to_s.strip
      return UNSET_LIVE_AT if value.blank?

      Time.iso8601(value)
    rescue ArgumentError
      raise ArgumentError, "#{ENV_KEY} must be an ISO-8601 timestamp"
    end
  end
end
