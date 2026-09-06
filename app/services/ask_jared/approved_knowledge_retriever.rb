module AskJared
  class ApprovedKnowledgeRetriever
    DEFAULT_LIMIT = 6

    INTENT_SPECS = {
      "characterization" => { terms: [ "rails", "react", "full-stack", "engineering", "technical ownership", "product design" ], kinds: %w[demonstrated] },
      "candidacy" => { terms: [ "rails", "react", "engineering", "technical ownership", "product judgment", "measurable impact", "collaboration" ], kinds: %w[demonstrated] },
      "rails" => { terms: [ /\Arails\z/ ], kinds: %w[demonstrated] },
      "react" => { terms: [ /\Areact\z/ ], kinds: %w[demonstrated] },
      "product" => { terms: [ "product judgment", "prioritization", "tradeoff analysis", "user research", "user research synthesis", "ux" ], kinds: %w[demonstrated] },
      "organization" => { terms: [ "engineering collaboration", "organizational scale", "large-team leadership", "management", "leadership", "organizational complexity", "large-organization" ], kinds: %w[demonstrated boundary] },
      "collaboration" => { terms: [ "engineering collaboration", "code review", "cross-functional collaboration", "reciprocal ownership" ], kinds: %w[demonstrated] },
      "risk" => { terms: [], kinds: %w[boundary] },
      "typescript" => { terms: [ /\Atypescript\z/, "learning new technology" ], kinds: %w[boundary demonstrated trajectory] },
      "learning" => { terms: [ "learning new technology", "integration" ], kinds: %w[demonstrated] },
      "failure" => { terms: [ "failure learning", "debugging" ], kinds: %w[demonstrated] },
      "feedback" => { terms: [ "feedback coachability" ], kinds: %w[demonstrated] },
      "prioritization" => { terms: [ /\Aprioritization\z/ ], kinds: %w[demonstrated] },
      "disagreement" => { terms: [ "technical disagreement" ], kinds: %w[demonstrated] },
      "mentorship" => { terms: [ "mentorship", "people development" ], kinds: %w[demonstrated] },
      "ambiguity" => { terms: [ "ambiguity", "ambiguous objectives" ], kinds: %w[demonstrated] },
      "impact" => { terms: [ "measurable impact", "measurable outcomes", "measurable business outcomes" ], kinds: %w[demonstrated] },
      "production" => { terms: [ "production reliability", "security", "incident response" ], kinds: %w[demonstrated] },
      "stakeholder" => { terms: [ "stakeholder alignment", "executive communication", "communication", "influence without authority" ], kinds: %w[demonstrated] }
    }.freeze

    INTENT_PATTERNS = [
      [ "typescript", /\btypescript\b/i ],
      [ "rails", /\brails\b/i ],
      [ "react", /\breact\b/i ],
      [ "production", /\bproduction (?:incident|problem|issue)|incident response|production reliability/i ],
      [ "risk", /\brisk|risks|gap|gaps|weakness|concern|less experience/i ],
      [ "organization", /\blarger engineering team|large engineering team|organizational scale|organizational levels|layered (?:team|organization)|managed large/i ],
      [ "feedback", /\bfeedback|respond to criticism|received criticism/i ],
      [ "disagreement", /\btechnical disagreement|technical conflict|disagreed|push(?:ed)? back|conflict over/i ],
      [ "prioritization", /\bpriorit(?:y|ize|izing|ization)|competing work|tradeoff/i ],
      [ "ambiguity", /\bambigu(?:ity|ous)|unclear requirements|uncertainty/i ],
      [ "impact", /\bmeasurable (?:(?:business|product)(?: or (?:business|product))? )?impact|measurable result|business result|quantified outcome/i ],
      [ "stakeholder", /\bstakeholder|executive communication|communicate with .*stakeholder/i ],
      [ "mentorship", /\bmentor|mentorship|people development|succession/i ],
      [ "failure", /\bfailure|mistake|technical debt|production problem/i ],
      [ "collaboration", /\bcollaborat|worked with engineers|engineer-to-engineer/i ],
      [ "learning", /\blearn(?:ing|ed)|unfamiliar technology|technical ramp/i ],
      [ "product", /\bproduct judgment|product thinking|product direction|product decision|user problem|\bux\b/i ],
      [ "characterization", /\bwhat kind of engineer|engineering profile|engineer is Jared/i ],
      [ "candidacy", /\bwhy (?:should|would) .*interview|why hire|case for Jared|recommend Jared/i ],
      [ "characterization", /\bstrongest qualities|biggest strengths|what stands out|especially good at/i ]
    ].freeze

    INTENT_SOURCE_BOOSTS = {
      "characterization" => { "case-study:dogly-product-design" => 4.0, "story:dogly-engineering-collaboration" => 3.0, "story:dogly-react-migration-disagreement" => 2.0 },
      "react" => { "story:dogly-engineering-collaboration" => 4.0, "story:dogly-react-migration-disagreement" => 3.0 },
      "mentorship" => { "story:anthropologie-succession-mentorship" => 5.0 },
      "ambiguity" => { "story:doglydaily-three-send-ux" => 5.0 },
      "disagreement" => { "story:dogly-react-migration-disagreement" => 5.0 },
      "stakeholder" => { "story:jcrew-dress-swim-decision" => 5.0 },
      "impact" => { "story:jcrew-dress-swim-decision" => 5.0, "story:dogly-agenda-simplification" => 4.0, "career:jcrew-associate-store-manager-columbus-circle" => 3.0 }
    }.freeze

    attr_reader :last_trace

    def initialize(scope: ::KnowledgeEntry.recruiter_retrievable, embedding_provider: OpenAiEmbeddingProvider.new)
      @scope = scope
      @embedding_provider = embedding_provider
    end

    def call(question, limit: DEFAULT_LIMIT, intent: nil)
      intent ||= classified_intent(question)
      pool = intent && qualified_pool(intent)
      if pool&.any?
        rank(pool, question, limit, intent)
      elsif intent && strict_intent?(intent)
        @last_trace = { mode: "insufficient-qualified", intent: intent, considered: [], ranked: [], selected: [] }
        []
      else
        global_rank(question, limit)
      end
    end

    def classified_intent(question)
      text = question.to_s
      INTENT_PATTERNS.find { |_intent, pattern| text.match?(pattern) }&.first
    end

    def qualified_for_intent?(intent, entry)
      qualified_entry?(intent.to_s, entry)
    end

    private

    def qualified_pool(intent)
      @scope.to_a.reject { |entry| archive_only?(entry) }.select { |entry| qualified_entry?(intent, entry) }
    end

    def qualified_entry?(intent, entry)
      spec = INTENT_SPECS[intent]
      return false unless spec

      evidence = entry.metadata.fetch("recruiter_evidence", {})
      claim_kinds = claim_kinds_for(entry)
      return claim_kinds.include?("boundary") if intent == "risk"
      return false if intent == "production" && entry.entry_type != "incident_story" && !evidence["relationship"].to_s.match?(/production incident|incident response/i)
      mappings = evidence.fetch("capability_map", {}).filter_map do |capability, details|
        next unless details.is_a?(Hash) && capability_match?(capability, spec[:terms])

        [ capability, details ]
      end
      return false if mappings.empty?

      kind_allowed = mappings.any? { |_capability, details| spec[:kinds].include?(details["evidence_kind"].to_s) } ||
        claim_kinds.any? { |kind| spec[:kinds].include?(kind) }
      return false unless kind_allowed
      return false if intent == "impact" && (claim_kinds.include?("planned") || !evidence["result"].to_s.match?(/\d|%|\$/))

      if %w[characterization candidacy rails react collaboration learning failure feedback prioritization disagreement mentorship ambiguity impact production stakeholder].include?(intent)
        return false if claim_kinds.include?("boundary")
      end

      true
    end

    def claim_kinds_for(entry)
      Array(entry.metadata.dig("recruiter_evidence", "claims")).filter_map { |claim| claim["kind"]&.to_s }
    end

    def strict_intent?(intent)
      %w[risk typescript feedback disagreement ambiguity impact production].include?(intent)
    end

    def capability_match?(capability, terms)
      normalized = capability.to_s.downcase.tr("_", " ")
      terms.any? do |term|
        next normalized.match?(term) if term.is_a?(Regexp)

        normalized == term.to_s.downcase.tr("_", " ") || normalized.start_with?("#{term.to_s.downcase.tr("_", " ")} ")
      end
    end

    def rank(entries, question, limit, intent)
      begin
        ranked = semantic_rank(entries, question, intent)
        mode = "semantic-qualified"
      rescue OpenAiEmbeddingProvider::ConfigurationError, OpenAiEmbeddingProvider::ProviderError
        ranked = lexical_rank(entries, question, intent)
        mode = "lexical-qualified"
      end
      selected = ranked.first(limit)
      record_trace(mode, entries, ranked, selected, intent)
      selected
    end

    def global_rank(question, limit)
      entries = @scope.to_a.reject { |entry| archive_only?(entry) }
      begin
        ranked = semantic_rank(entries, question, nil)
        mode = "semantic-fallback"
      rescue OpenAiEmbeddingProvider::ConfigurationError, OpenAiEmbeddingProvider::ProviderError
        ranked = lexical_rank(entries, question, nil)
        mode = "lexical-fallback"
      end
      selected = ranked.first(limit)
      record_trace(mode, entries, ranked, selected, nil)
      selected
    end

    def semantic_rank(entries, question, intent)
      vector = @embedding_provider.call(question)
      literal = "[#{vector.join(',')}]"
      distance_sql = ::KnowledgeEntry.sanitize_sql_array([ "embedding <=> ?::vector", literal ])
      embedded = @scope.where(id: entries.map(&:id)).where.not(embedding: nil).select("knowledge_entries.*, #{distance_sql} AS retrieval_distance").to_a
      distances = embedded.to_h { |entry| [ entry.id, entry.attributes["retrieval_distance"].to_f ] }
      entries.sort_by { |entry| [ distances.fetch(entry.id, 0.95) - quality_boost(entry, intent), entry.id ] }
    end

    def lexical_rank(entries, question, intent)
      terms = question.to_s.downcase.scan(/[a-z0-9]{3,}/).uniq
      entries.sort_by do |entry|
        haystack = [ entry.title, entry.short_body, entry.body ].compact.join(" ").downcase
        [ -terms.count { |term| haystack.include?(term) }, -quality_boost(entry, intent), entry.id ]
      end
    end

    def quality_boost(entry, intent)
      evidence = entry.metadata.fetch("recruiter_evidence", {})
      mapping = evidence.fetch("capability_map", {})
      spec = intent && INTENT_SPECS[intent]
      direct = spec ? mapping.sum do |capability, details|
        capability_match?(capability, spec[:terms]) ? strength_value(details["strength"]) : 0
      end : 0
      utility = evidence["recruiter_utility"] == "primary_recruiter_evidence" ? 1.0 : 0.0
      direct + utility + INTENT_SOURCE_BOOSTS.fetch(intent.to_s, {}).fetch(entry.source_reference.to_s, 0.0)
    end

    def strength_value(strength)
      { "primary" => 3.0, "strong" => 3.0, "demonstrated" => 2.0, "supporting" => 1.0 }.fetch(strength.to_s, 0.0)
    end

    def record_trace(mode, considered, ranked, selected, intent)
      @last_trace = {
        mode: mode,
        intent: intent,
        considered: considered.map { |entry| trace_entry(entry) },
        ranked: ranked.map { |entry| trace_entry(entry) },
        selected: selected.map(&:id)
      }
    end

    def trace_entry(entry)
      evidence = entry.metadata.fetch("recruiter_evidence", {})
      { id: entry.id, source_reference: entry.source_reference, entry_type: entry.entry_type,
        recruiter_utility: evidence["recruiter_utility"], capability_map: evidence["capability_map"], claims: evidence["claims"] }
    end

    def archive_only?(entry)
      entry.metadata.dig("recruiter_evidence", "recruiter_utility") == "archive_only"
    end

    def metadata_text(value)
      case value
      when Hash then value.values.map { |item| metadata_text(item) }.join(" ")
      when Array then value.map { |item| metadata_text(item) }.join(" ")
      else value.to_s
      end
    end
  end
end
