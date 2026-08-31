module AskJared
  class EmbeddingService
    MODEL = ENV.fetch("ASK_JARED_EMBEDDING_MODEL", OpenAiEmbeddingProvider::DEFAULT_MODEL)

    def initialize(provider: OpenAiEmbeddingProvider.new)
      @provider = provider
    end

    def generate!(entry)
      vector = @provider.call(entry.recruiter_context)
      entry.update!(embedding: vector, embedding_model: MODEL, embedding_generated_at: Time.current)
      entry
    end
  end
end
