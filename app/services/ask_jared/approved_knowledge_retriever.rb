module AskJared
  class ApprovedKnowledgeRetriever
    DEFAULT_LIMIT = 5

    def initialize(scope: ::KnowledgeEntry.recruiter_retrievable, embedding_provider: OpenAiEmbeddingProvider.new)
      @scope = scope
      @embedding_provider = embedding_provider
    end

    def call(question, limit: DEFAULT_LIMIT)
      return semantic_results(question, limit) if postgres_scope_with_embeddings?

      lexical_results(question, limit)
    rescue OpenAiEmbeddingProvider::ConfigurationError, OpenAiEmbeddingProvider::ProviderError
      lexical_results(question, limit)
    end

    private

    def semantic_results(question, limit)
      vector = @embedding_provider.call(question)
      literal = "[#{vector.join(',')}]"
      order_sql = ::KnowledgeEntry.sanitize_sql_array([ "embedding <=> ?::vector", literal ])
      @scope.where.not(embedding: nil).order(Arel.sql(order_sql)).limit(limit).to_a
    end

    def lexical_results(question, limit)
      terms = question.to_s.downcase.scan(/[a-z0-9]{3,}/).uniq
      return [] if terms.empty?

      @scope.to_a.filter_map do |entry|
        haystack = [ entry.title, entry.short_body, entry.body, Array(entry.metadata["tags"]) ].compact.join(" ").downcase
        score = terms.count { |term| haystack.include?(term) }
        [ entry, score ] if score.positive?
      end.sort_by { |entry, score| [ -score, entry.id ] }.first(limit).map(&:first)
    end

    def postgres_scope_with_embeddings?
      connection = @scope.klass.connection
      connection.adapter_name.downcase.include?("postgres") && @scope.where.not(embedding: nil).exists?
    end
  end
end
