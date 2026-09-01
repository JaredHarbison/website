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
      distance_sql = ::KnowledgeEntry.sanitize_sql_array([ "embedding <=> ?::vector", literal ])
      entries = @scope.where.not(embedding: nil).select("knowledge_entries.*, #{distance_sql} AS retrieval_distance").to_a

      entries.sort_by do |entry|
        distance = entry.attributes["retrieval_distance"].to_f
        [ distance - compatibility_boost(question, entry), entry.id ]
      end.first(limit)
    end

    def compatibility_boost(question, entry)
      text = question.to_s.downcase
      evidence = entry.metadata.fetch("recruiter_evidence", {})
      context = [ entry.title, entry.short_body, evidence["relationship"] ].compact.join(" ").downcase
      boost = title_or_entity_overlap(text, entry.title, evidence["relationship"])

      if text.match?(/outside dogly|outside the company|independent|personal project|built beyond dogly/)
        boost += 0.22 if evidence["relationship"].to_s.downcase.include?("independent project outside dogly")
      end

      if text.match?(/built|build|project|product|created|developed/) && !text.match?(/revenue|subscription|metric|increase|rate/)
        boost += 0.08 unless entry.entry_type == "metric"
        boost -= 0.08 if entry.entry_type == "metric"
      end

      if text.match?(/unproven|limited|unknown|not measured|without a proven outcome|didn.t have a proven outcome|can.t confidently|failure|limitation/)
        boost += 0.12 if evidence["limitations"].present? || evidence["status"].to_s.match?(/prototype|work in progress|outcome/i)
      end

      if text.match?(/personally|own|owned|led|lead|design.*engineer|ownership/)
        boost += 0.08 if evidence["ownership"].present?
      end

      boost + (context.include?("shopify") && text.include?("shopify") ? 0.08 : 0)
    end

    def title_or_entity_overlap(question, title, relationship)
      title_terms = [ title, relationship ].compact.join(" ").downcase.scan(/[a-z0-9]{4,}/).uniq
      question_terms = question.scan(/[a-z0-9]{4,}/).uniq
      (title_terms & question_terms).length * 0.04
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
