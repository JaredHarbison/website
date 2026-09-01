module AskJared
  class ApprovedKnowledgeRetriever
    DEFAULT_LIMIT = 5
    BROAD_CANDIDATE_LIMIT = 24
    BROAD_QUERY_PATTERNS = [
      /\bwhat kind of\b/,
      /\b(?:technologies|systems|roles|examples)\b/,
      /\bstrongest evidence\b/,
      /\b(?:breadth|characteri[sz]ation)\b/,
      /\b(?:unfinished|unmeasured|limitations?|unproven)\b/,
      /\b(?:learned|learning|improved next|should be improved)\b/
    ].freeze

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

      ranked_entries = entries.sort_by do |entry|
        distance = entry.attributes["retrieval_distance"].to_f
        [ distance - compatibility_boost(question, entry), entry.id ]
      end

      return ranked_entries.first(limit) unless broad_query?(question)

      diversified_results(ranked_entries.first([ BROAD_CANDIDATE_LIMIT, limit ].max), limit, question)
    end

    def broad_query?(question)
      text = question.to_s.downcase
      BROAD_QUERY_PATTERNS.any? { |pattern| text.match?(pattern) }
    end

    def diversified_results(candidates, limit, question)
      selected = []
      remaining = candidates.dup
      relevance_floor = candidates.first && adjusted_distance(candidates.first, question) + 0.35

      while selected.length < limit && remaining.any?
        eligible = remaining.select do |entry|
          adjusted_distance(entry, question) <= relevance_floor
        end
        break if eligible.empty?

        next_entry = eligible.min_by do |entry|
          [
            adjusted_distance(entry, question) - diversity_bonus(entry, selected),
            entry.id
          ]
        end
        selected << next_entry
        remaining.delete(next_entry)
      end

      selected
    end

    def adjusted_distance(entry, question)
      entry.attributes["retrieval_distance"].to_f - compatibility_boost(question, entry)
    end

    def diversity_bonus(entry, selected)
      evidence = entry.metadata.fetch("recruiter_evidence", {})
      bonus = 0.0
      bonus += 0.08 unless selected.any? { |item| item.entry_type == entry.entry_type }
      bonus += 0.16 if independent_project?(entry) && selected.none? { |item| independent_project?(item) }
      bonus += 0.16 if evidence["product_learning"].present? && selected.none? { |item| item.metadata.dig("recruiter_evidence", "product_learning").present? }
      bonus += 0.04 if evidence["result"].present? && selected.none? { |item| item.metadata.dig("recruiter_evidence", "result").present? }
      bonus += 0.04 if evidence["limitations"].present? && selected.none? { |item| item.metadata.dig("recruiter_evidence", "limitations").present? }
      bonus
    end

    def independent_project?(entry)
      entry.metadata.dig("recruiter_evidence", "relationship").to_s.downcase.include?("independent project outside dogly")
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
