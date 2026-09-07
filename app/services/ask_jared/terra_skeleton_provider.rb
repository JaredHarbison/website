require "json"
require "net/http"
require "uri"

module AskJared
  class TerraSkeletonProvider
    ENDPOINT = URI("https://api.openai.com/v1/chat/completions")
    MODEL = "gpt-5.6-sol"
    REQUEST_TIMEOUT_SECONDS = 45
    RESPONSE_SCHEMA = {
      type: "json_schema",
      json_schema: {
        name: "ask_jared_skeleton_response",
        strict: true,
        schema: {
          type: "object",
          properties: {
            status: { type: "string", enum: StructuredResponse::MODEL_STATUSES },
            segments: { type: "array", items: { type: "object", properties: { text: { type: "string" }, role_refs: { type: "array", items: { type: "string" } } }, required: %w[text role_refs], additionalProperties: false } }
          },
          required: %w[status segments],
          additionalProperties: false
        }
      }
    }.freeze

    def initialize(api_key: ENV["OPENAI_API_KEY"], model: ENV.fetch("ASK_JARED_SKELETON_MODEL", MODEL), http: Net::HTTP)
      @api_key = api_key
      @model = model
      @http = http
    end

    def call(question:, skeleton:)
      request(question: question, skeleton: skeleton, repair: nil)
    end

    def repair(question:, skeleton:, response:, violations:)
      request(question: question, skeleton: skeleton, repair: { response: response, violations: violations })
    end

    private

    def request(question:, skeleton:, repair:)
      raise OpenAiProvider::ConfigurationError, "OPENAI_API_KEY is not configured" if @api_key.blank?

      user = { question: question, approved_skeleton: JSON.parse(skeleton.formatted_context) }
      if repair
        user[:repair] = "Previous realization failed validation: #{repair[:violations].join('; ')}. Rewrite only the affected segments. Return role_refs for every segment and use no facts outside the skeleton. Previous response: #{repair[:response].to_json}"
      end
      body = { model: @model, max_completion_tokens: 1_000, response_format: RESPONSE_SCHEMA, messages: [ { role: "system", content: system_prompt }, { role: "user", content: JSON.generate(user) } ] }
      response = post(body)
      raise OpenAiProvider::ProviderError, "OpenAI request failed" unless response.is_a?(Net::HTTPSuccess)

      parsed = JSON.parse(response.body)
      JSON.parse(parsed.dig("choices", 0, "message", "content")).merge("__telemetry" => telemetry(parsed))
    rescue JSON::ParserError, KeyError, TypeError
      raise OpenAiProvider::ProviderError, "OpenAI returned malformed structured output"
    end

    def post(body)
      headers = { "Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json" }
      return @http.post(ENDPOINT, JSON.generate(body), headers) unless @http == Net::HTTP

      client = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
      client.use_ssl = true
      client.open_timeout = REQUEST_TIMEOUT_SECONDS
      client.read_timeout = REQUEST_TIMEOUT_SECONDS
      client.write_timeout = REQUEST_TIMEOUT_SECONDS if client.respond_to?(:write_timeout=)
      client.post(ENDPOINT.request_uri, JSON.generate(body), headers)
    end

    def telemetry(body)
      usage = body["usage"]
      return {} unless usage.is_a?(Hash) && usage["prompt_tokens"] && usage["completion_tokens"]
      { "input_tokens" => usage["prompt_tokens"].to_i, "output_tokens" => usage["completion_tokens"].to_i,
        "estimated_cost_cents" => nil, "pricing_version" => nil }
    end

    def system_prompt
      <<~PROMPT
        Realize the server-approved recruiter answer skeleton in 2–5 natural sentences.
        The server has already decided every factual proposition and permitted relationship.
        Use only the supplied role text. Do not add experience, accomplishments, metrics,
        causality, chronology, ownership, outcomes, motivations, abilities, or predictions.
        Preserve boundaries, attribution, planned state, self-estimate qualification, and
        technology domains. Bounded positioning is allowed only when explicitly supplied as
        a positioning or relationship role. Omit rather than infer. Each segment must identify
        every skeleton role it expresses in role_refs. Never put role IDs, claim aliases, or
        internal references in segment text. Use natural recruiter-facing language rather than
        internal evidence-policy words such as boundary or not established. For broad characterization,
        lead with a concise candidate-level characterization, then cover two to four distinct supported
        dimensions before brief examples; do not start with one anecdote or let one React disagreement
        dominate. For gap questions, use only explicit limitations, limited-depth claims, missing-context
        claims, or supported development areas; never turn an unrelated project into an area to probe.
        Return status and segments only.
      PROMPT
    end
  end
end
