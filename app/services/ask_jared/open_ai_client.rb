require "json"
require "net/http"
require "uri"

module AskJared
  class OpenAiClient
    ENDPOINT = URI("https://api.openai.com/v1/chat/completions")
    REQUEST_TIMEOUT_SECONDS = 45

    def initialize(http: Net::HTTP)
      @http = http
    end

    def post(body, api_key:)
      headers = { "Authorization" => "Bearer #{api_key}", "Content-Type" => "application/json" }
      return @http.post(ENDPOINT, JSON.generate(body), headers) unless @http == Net::HTTP

      client = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
      client.use_ssl = true
      client.open_timeout = REQUEST_TIMEOUT_SECONDS
      client.read_timeout = REQUEST_TIMEOUT_SECONDS
      client.write_timeout = REQUEST_TIMEOUT_SECONDS if client.respond_to?(:write_timeout=)
      client.post(ENDPOINT.request_uri, JSON.generate(body), headers)
    end

    def telemetry(body, pricing: nil)
      usage = body["usage"]
      return {} unless usage.is_a?(Hash) && usage["prompt_tokens"] && usage["completion_tokens"]

      input_tokens = usage["prompt_tokens"].to_i
      output_tokens = usage["completion_tokens"].to_i
      cost_cents = pricing && ((input_tokens * pricing[:input_per_million_cents] + output_tokens * pricing[:output_per_million_cents]) / 1_000_000.0).round
      { "input_tokens" => input_tokens, "output_tokens" => output_tokens,
        "estimated_cost_cents" => cost_cents, "pricing_version" => pricing&.fetch(:version) }
    end
  end
end
