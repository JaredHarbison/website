require "json"
require "net/http"
require "uri"

module AskJared
  class TerraSkeletonProvider
    ENDPOINT = URI("https://api.openai.com/v1/chat/completions")
    MODEL = "gpt-5.6-terra"
    RESPONSE_SCHEMA = {
      type: "json_schema",
      json_schema: {
        name: "ask_jared_skeleton_response",
        strict: true,
        schema: {
          type: "object",
          properties: {
            status: { type: "string", enum: StructuredResponse::STATUSES },
            segments: { type: "array", items: { type: "object", properties: { text: { type: "string" }, role_refs: { type: "array", items: { type: "string" } } }, required: %w[text role_refs], additionalProperties: false } }
          },
          required: %w[status segments],
          additionalProperties: false
        }
      }
    }.freeze

    def initialize(api_key: ENV["OPENAI_API_KEY"], http: Net::HTTP)
      @api_key = api_key
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
      body = { model: MODEL, max_completion_tokens: 500, response_format: RESPONSE_SCHEMA, messages: [ { role: "system", content: system_prompt }, { role: "user", content: JSON.generate(user) } ] }
      response = @http.post(ENDPOINT, JSON.generate(body), { "Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json" })
      raise OpenAiProvider::ProviderError, "OpenAI request failed" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).dig("choices", 0, "message", "content").then { |content| JSON.parse(content) }
    rescue JSON::ParserError, KeyError, TypeError
      raise OpenAiProvider::ProviderError, "OpenAI returned malformed structured output"
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
        internal references in segment text. Return status and segments only.
      PROMPT
    end
  end
end
