require "json"
require "net/http"
require "uri"

module AskJared
  class OpenAiEmbeddingProvider
    ENDPOINT = URI("https://api.openai.com/v1/embeddings")
    DEFAULT_MODEL = "text-embedding-3-small"

    def initialize(api_key: ENV["OPENAI_API_KEY"], model: ENV.fetch("ASK_JARED_EMBEDDING_MODEL", DEFAULT_MODEL), http: Net::HTTP)
      @api_key = api_key
      @model = model
      @http = http
    end

    def call(text)
      raise ConfigurationError, "OPENAI_API_KEY is not configured" if @api_key.blank?

      response = @http.post(
        ENDPOINT,
        JSON.generate({ model: @model, input: text.to_s }),
        { "Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json" }
      )
      raise ProviderError, "OpenAI embedding request failed" unless response.is_a?(Net::HTTPSuccess)

      vector = JSON.parse(response.body).dig("data", 0, "embedding")
      validate_vector!(vector)
    rescue JSON::ParserError, TypeError
      raise ProviderError, "OpenAI returned malformed embedding output"
    end

    class ConfigurationError < StandardError; end
    class ProviderError < StandardError; end

    private

    def validate_vector!(vector)
      raise ProviderError, "OpenAI returned an invalid embedding" unless vector.is_a?(Array) && vector.length == 1536 && vector.all? { |value| value.is_a?(Numeric) && value.finite? }

      vector.map(&:to_f)
    end
  end
end
