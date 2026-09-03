module AskJared
  class ApprovedKnowledgeRetriever
    attr_reader :last_trace
    DEFAULT_LIMIT = 6
    BROAD_CANDIDATE_LIMIT = 30
    BROAD_QUERY_PATTERNS = [
      /\bwhat kind of\b/,
      /\b(?:technologies|systems|roles|examples)\b/,
      /\bstrongest evidence\b/,
      /\b(?:breadth|characteri[sz]ation)\b/,
      /\b(?:unfinished|unmeasured|limitations?|unproven)\b/,
      /\b(?:learned|learning|improved next|should be improved)\b/,
      /\bcommercial\b/,
      /\b(?:risk|risks|gap|gaps|less experience|larger team|organizational levels|management)\b/,
      /\b(?:business result|business impact|measurable impact|measurable result)\b/,
      /\b(?:product judgment|product thinking|product direction)\b/
    ].freeze
    SPECIFIC_QUERY_PATTERNS = /\b(?:shopify|stripe|refunds?|concurrenc|locking|paperclip|activestorage)\b/

    def initialize(scope: ::KnowledgeEntry.recruiter_retrievable, embedding_provider: OpenAiEmbeddingProvider.new)
      @scope = scope
      @embedding_provider = embedding_provider
    end

    def call(question, limit: DEFAULT_LIMIT, intent: nil)
      return semantic_results(question, limit, intent: intent) if postgres_scope_with_embeddings?

      lexical_results(question, limit, intent: intent)
    rescue OpenAiEmbeddingProvider::ConfigurationError, OpenAiEmbeddingProvider::ProviderError
      lexical_results(question, limit, intent: intent)
    end

    def classified_intent(question)
      intent_for(question)
    end

    def qualified_for_intent?(intent_or_question, entry)
      intent = intent_or_question.to_s
      intent = intent_for(intent) unless intent_capabilities.key?(intent)
      return true unless intent

      mapping = entry.metadata.dig("recruiter_evidence", "capability_map") || {}
      return false if mapping.empty?
      aliases = intent_capabilities.fetch(intent, [])
      match = mapping.find do |capability, details|
        capability_text = capability.to_s.downcase.tr("_", " ")
        matches = capability_text.include?(intent) || aliases.any? { |name| capability_text.include?(name) }
        matches && details.is_a?(Hash)
      end
      return false unless match

      details = match.last
      utility = entry.metadata.dig("recruiter_evidence", "recruiter_utility")
      strength = details["strength"].to_s
      evidence_kind = details["evidence_kind"].to_s
      claim_kinds = Array(entry.metadata.dig("recruiter_evidence", "claims")).filter_map { |claim| claim["kind"]&.to_s }
      return false if claim_kinds.include?("boundary")
      return false unless evidence_kind.blank? || evidence_kind == "demonstrated"

      utility == "primary_recruiter_evidence" || %w[demonstrated strong primary].include?(strength)
    end

    private

    def semantic_results(question, limit, intent: nil)
      vector = @embedding_provider.call(question)
      literal = "[#{vector.join(',')}]"
      distance_sql = ::KnowledgeEntry.sanitize_sql_array([ "embedding <=> ?::vector", literal ])
      embedded_entries = @scope.where.not(embedding: nil).select("knowledge_entries.*, #{distance_sql} AS retrieval_distance").to_a
      unembedded_entries = @scope.where(embedding: nil).to_a
      @retrieval_distances = {}
      unembedded_entries.each do |entry|
        @retrieval_distances[entry.id] = lexical_distance(question, entry)
      end
      entries = (embedded_entries + unembedded_entries).reject { |entry| archive_only?(entry) }

      ranked_entries = entries.sort_by do |entry|
        distance = distance_for(entry)
        [ distance - compatibility_boost(question, entry, intent: intent), entry.id ]
      end

      @last_trace = {
        mode: "semantic",
        considered: entries.map { |entry| trace_entry(entry, distance_for(entry)) },
        ranked: ranked_entries.map { |entry| trace_entry(entry, adjusted_distance(entry, question, intent: intent)) }
      }

      selected = broad_query?(question) ? diversified_results(ranked_entries.first([ BROAD_CANDIDATE_LIMIT, limit ].max), limit, question, intent: intent) : ranked_entries.first(limit)
      @last_trace[:selected] = selected.map { |entry| entry.id }
      diversified_results(ranked_entries.first([ BROAD_CANDIDATE_LIMIT, limit ].max), limit, question, intent: intent)
    end

    def broad_query?(question)
      text = question.to_s.downcase
      return false if text.match?(SPECIFIC_QUERY_PATTERNS)

      BROAD_QUERY_PATTERNS.any? { |pattern| text.match?(pattern) }
    end

    def diversified_results(candidates, limit, question, intent: nil)
      selected = []
      remaining = candidates.dup
      relevance_floor = candidates.first && adjusted_distance(candidates.first, question, intent: intent) + 0.35

      while selected.length < limit && remaining.any?
        eligible = remaining.select do |entry|
          adjusted_distance(entry, question, intent: intent) <= relevance_floor
        end
        break if eligible.empty?

        next_entry = eligible.min_by do |entry|
          [
            adjusted_distance(entry, question, intent: intent) - diversity_bonus(entry, selected),
            entry.id
          ]
        end
        selected << next_entry
        remaining.delete(next_entry)
      end

      selected
    end

    def adjusted_distance(entry, question, intent: nil)
      distance_for(entry) - compatibility_boost(question, entry, intent: intent)
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

    def compatibility_boost(question, entry, intent: nil)
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

      if text.match?(/\b(?:larger|large|big|sizable)\s+(?:engineering\s+)?team|organizational levels|layered organization|management|managed large|team leadership/)
        boost += 0.16 if evidence["competencies"].to_s.match?(/large|team|management|organizational|leadership/i)
        boost += 0.10 if evidence.dig("ownership", "people_management").present?
      end

      if text.match?(/risk|gap|less experience|weakness|concern|boundary|limited|unknown/)
        boost += 0.18 if evidence["limitations"].present?
        boost += 0.10 if entry.entry_type == "career_context"
      end

      if text.match?(/measurable|metric|impact|business result|outcome|result/)
        boost += 0.12 if evidence["result"].present?
        boost += 0.06 if entry.entry_type == "metric"
      end

      if text.match?(/product judgment|product thinking|product direction|challenged|proposed direction|user problem|tradeoff/)
        boost += 0.18 if evidence["product_learning"].present?
        boost += 0.08 if entry.entry_type == "product_story"
      end

      boost + category_boost(question, entry) + metadata_intent_boost(question, entry, intent: intent)
    end

    def metadata_intent_boost(question, entry, intent: nil)
      intent ||= intent_for(question)
      return 0.0 unless intent

      evidence = entry.metadata.fetch("recruiter_evidence", {})
      mapping = evidence["capability_map"] || {}
      capabilities = mapping.any? ? mapping.keys : evidence["competencies"].to_s.split(/,\s*/)
      aliases = intent_capabilities.fetch(intent, [])
      direct = capabilities.count do |capability|
        text = capability.to_s.downcase.tr("_", " ")
        text.include?(intent) || aliases.any? { |name| text.include?(name) }
      end
      utility = entry.metadata.dig("recruiter_evidence", "recruiter_utility")
      direct * 4.0 + (utility == "primary_recruiter_evidence" ? 2.0 : 0.0)
    end

    def intent_for(question)
      text = question.to_s.downcase
      return "product" if text.match?(/\bproduct(?:\s|$)|product judgment|product thinking|product direction|prioriti|tradeoff|\buser\b|\bux\b|stakeholder misunderstanding/)
      return "debug" if text.match?(/debug|incident|failure|mistake|reliab|production/)
      return "learning" if text.match?(/learn|typescript|unfamiliar|ramp/)
      return "mentorship" if text.match?(/mentor|coach|feedback|people development|succession/)
      return "organization" if text.match?(/larger team|large team|organizational|management|scale/)
      return "collaboration" if text.match?(/collaborat|disagreement|worked with other engineers/)
      return "impact" if text.match?(/impact|metric|result|outcome/)
      nil
    end

    def intent_capabilities
      {
        "product" => %w[product judgment prioritization tradeoff user research ux stakeholder],
        "debug" => %w[debug failure reliability incident production],
        "learning" => %w[learning technology integration],
        "mentorship" => %w[mentorship coaching people development succession],
        "organization" => %w[organization management leadership scale],
        "collaboration" => %w[collaboration engineer code review cross functional reciprocal ownership],
        "impact" => %w[impact measurable outcome result]
      }
    end

    def archive_only?(entry)
      entry.metadata.dig("recruiter_evidence", "recruiter_utility") == "archive_only"
    end

    def category_boost(question, entry)
      text = question.to_s.downcase
      evidence = entry.metadata.fetch("recruiter_evidence", {})
      competencies = evidence["competencies"].to_s
      result = evidence["result"].to_s
      limitations = evidence["limitations"].to_s
      boost = 0.0

      if text.match?(/larger|large|sizable|organizational levels|layered organization|team leadership|managed large/)
        boost += 0.42 if competencies.match?(/large|team|management|organizational|leadership/i)
        boost += 0.30 if evidence.dig("ownership", "people_management").present?
        boost += 0.38 if limitations.match?(/large engineering.team|conventional large/i)
      end

      if text.match?(/risk|gap|less experience|weakness|concern|boundary|limited|unknown/)
        boost += 0.45 if limitations.present?
        boost += 0.35 if entry.entry_type == "career_context"
      end

      if text.match?(/measurable|metric|impact|business result|outcome|result/)
        boost += 0.25 if evidence["result"].present?
        boost += 0.15 if result.match?(/\d|%|\$/)
      end

      if text.match?(/product judgment|product thinking|product direction|challenged|proposed direction|user problem|tradeoff|validation|learning/)
        boost += 0.65 if evidence["product_learning"].present?
        boost += 0.20 if entry.entry_type == "product_story"
      end

      if text.match?(/typescript/) && text.match?(/experience|depth|professional|proficien|background|familiar/i)
        boost += 0.70 if limitations.match?(/typescript/i)
      end

      boost
    end

    def title_or_entity_overlap(question, title, relationship)
      title_terms = [ title, relationship ].compact.join(" ").downcase.scan(/[a-z0-9]{4,}/).uniq
      question_terms = question.scan(/[a-z0-9]{4,}/).uniq
      (title_terms & question_terms).length * 0.04
    end

    def lexical_results(question, limit, intent: nil)
      terms = question.to_s.downcase.scan(/[a-z0-9]{3,}/).uniq
      return [] if terms.empty?

      scored = @scope.to_a.reject { |entry| archive_only?(entry) }.filter_map do |entry|
        haystack = [ entry.title, entry.short_body, entry.body, metadata_text(entry.metadata) ].compact.join(" ").downcase
        score = terms.count { |term| haystack.include?(term) }
        score += lexical_intent_bonus(question, entry, intent: intent)
        score += metadata_intent_boost(question, entry, intent: intent)
        [ entry, score ] if score.positive?
      end.sort_by { |entry, score| [ -score, entry.id ] }
      selected = scored.first(limit).map(&:first)
      @last_trace = {
        mode: "lexical",
        considered: scored.map { |entry, score| trace_entry(entry, score) },
        ranked: scored.map { |entry, score| trace_entry(entry, score) },
        selected: selected.map(&:id)
      }
      selected
    end

    def lexical_distance(question, entry)
      score = lexical_score(question, entry)
      score.positive? ? [ 0.9 - (score * 0.08), 0.45 ].max : 0.95
    end

    def lexical_score(question, entry)
      terms = question.to_s.downcase.scan(/[a-z0-9]{3,}/).uniq
      return 0 if terms.empty?

      haystack = [ entry.title, entry.short_body, entry.body, metadata_text(entry.metadata) ].compact.join(" ").downcase
      terms.count { |term| haystack.include?(term) } + lexical_intent_bonus(question, entry)
    end

    def distance_for(entry)
      @retrieval_distances&.fetch(entry.id, nil) || entry.attributes["retrieval_distance"].to_f
    end

    def trace_entry(entry, score)
      evidence = entry.metadata.fetch("recruiter_evidence", {})
      { id: entry.id, source_reference: entry.respond_to?(:source_reference) ? entry.source_reference : nil,
        approval_status: entry.respond_to?(:approval_status) ? entry.approval_status : nil,
        visibility: entry.respond_to?(:visibility) ? entry.visibility : nil, entry_type: entry.entry_type,
        score: score, competencies: evidence["competencies"], limitations: evidence["limitations"],
        product_learning: evidence["product_learning"], result: evidence["result"] }
    end

    def lexical_intent_bonus(question, entry, intent: nil)
      text = question.to_s.downcase
      evidence = entry.metadata.fetch("recruiter_evidence", {})
      bonus = 0
      bonus += 5 if text.match?(/larger|large|sizable/) && evidence["competencies"].to_s.match?(/large|team|organizational|management/i)
      bonus += 3 if text.match?(/organizational levels|layered organization/) && evidence["competencies"].to_s.match?(/organizational|stakeholder|cross-functional/i)
      bonus += 4 if text.match?(/measurable|metric|impact|result|outcome/) && evidence["result"].present?
      bonus += 8 if text.match?(/measurable|metric|impact|result|outcome/) && entry.entry_type == "leadership_story" && evidence["result"].to_s.match?(/\d|%|\$/)
      if text.match?(/risk|gap|less experience|weakness|boundary/) && evidence["limitations"].present?
        bonus += 4
        bonus += 8 if entry.entry_type == "career_context"
      end
      bonus += 10 if text.match?(/typescript/) && evidence["limitations"].to_s.match?(/technology|typescript/i)
      bonus += 5 if text.match?(/product judgment|product thinking|product direction|challenged|proposed direction|user problem|tradeoff/) && evidence["product_learning"].present?
      bonus
    end

    def metadata_text(value)
      case value
      when Hash then value.values.map { |item| metadata_text(item) }.join(" ")
      when Array then value.map { |item| metadata_text(item) }.join(" ")
      else value.to_s
      end
    end

    def postgres_scope_with_embeddings?
      connection = @scope.klass.connection
      connection.adapter_name.downcase.include?("postgres") && @scope.where.not(embedding: nil).exists?
    end
  end
end
