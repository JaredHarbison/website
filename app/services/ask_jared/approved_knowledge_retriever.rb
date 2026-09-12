module AskJared
  class ApprovedKnowledgeRetriever
    DEFAULT_LIMIT = 6
    BOUNDARY_EXCLUDED_INTENTS = %w[
      characterization candidacy role_fit frontend backend integration architecture testing security ai_data
      leadership career rails react collaboration learning failure feedback prioritization disagreement mentorship
      ambiguity impact production stakeholder status soft_skills influence_without_authority
    ].freeze

    INTENT_SPECS = {
      "characterization" => { terms: [ "rails", "react", "full-stack", "engineering", "technical ownership", "product design" ], kinds: %w[demonstrated] },
      "candidacy" => { terms: [ "rails", "react", "engineering", "technical ownership", "product judgment", "measurable impact", "collaboration" ], kinds: %w[demonstrated] },
      "ownership" => { terms: [ "technical ownership", "integration", "end-to-end", "end to end" ], kinds: %w[demonstrated] },
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
      "status" => { terms: [], kinds: %w[planned demonstrated boundary] },
      "production" => { terms: [ "production reliability", "security", "incident response" ], kinds: %w[demonstrated] },
      "stakeholder" => { terms: [ "stakeholder alignment", "executive communication", "communication", "influence without authority" ], kinds: %w[demonstrated] },
      "soft_skills" => { terms: [ "stakeholder alignment", "engineering collaboration", "communication", "mentorship", "people development", "feedback coachability", "product judgment", "ambiguity" ], kinds: %w[demonstrated] },
      "influence_without_authority" => { terms: [ "influence without authority", "stakeholder alignment", "decision alignment" ], kinds: %w[demonstrated] },
      "complexity" => { terms: [ "technical ownership", "integration", "debugging", "architecture", "production reliability" ], kinds: %w[demonstrated] },
      "scope" => { terms: [], kinds: %w[demonstrated leadership_story engineering_story project integration_story] },
      "role_fit" => { terms: [ "engineering", "product judgment", "technical ownership", "collaboration" ], kinds: %w[demonstrated] },
      "frontend" => { terms: [ "react", "ux", "frontend engineering", "product design" ], kinds: %w[demonstrated] },
      "backend" => { terms: [ "rails", "backend engineering", "technical ownership", "database" ], kinds: %w[demonstrated] },
      "integration" => { terms: [ "integration", "technical ownership", "learning new technology" ], kinds: %w[demonstrated] },
      "architecture" => { terms: [ "architecture", "technical ownership", "tradeoff analysis", "production reliability" ], kinds: %w[demonstrated] },
      "testing" => { terms: [ "testing", "production reliability", "technical ownership" ], kinds: %w[demonstrated] },
      "security" => { terms: [ "security", "authentication", "technical ownership" ], kinds: %w[demonstrated] },
      "ai_data" => { terms: [ "retrieval", "evidence", "data" ], kinds: %w[demonstrated] },
      "leadership" => { terms: [ "leadership", "mentorship", "people development", "stakeholder alignment" ], kinds: %w[demonstrated] },
      "career" => { terms: [ "career", "trajectory", "engineering", "leadership" ], kinds: %w[demonstrated] },
      "availability" => { terms: [], kinds: %w[demonstrated] }
    }.freeze

    INTENT_SOURCE_BOOSTS = {
      "characterization" => {
        "fact:engineering-profile" => 14.0,
        "fact:engineering-scope-and-trajectory" => 11.0,
        "case-study:dogly-product-design" => 4.0,
        "story:dogly-engineering-collaboration" => 3.0,
        "story:dogly-react-migration-disagreement" => 2.0
      },
      "react" => { "story:dogly-engineering-collaboration" => 4.0, "story:dogly-react-migration-disagreement" => 3.0 },
      "mentorship" => { "story:anthropologie-succession-mentorship" => 5.0 },
      "ambiguity" => { "story:doglydaily-three-send-ux" => 5.0 },
      "disagreement" => { "story:dogly-react-migration-disagreement" => 5.0 },
      "stakeholder" => { "story:dogly-agenda-completion-alignment" => 6.0, "story:dogly-pre-accelerator-prioritization" => 4.0, "story:dogly-react-migration-disagreement" => 3.0 },
      "soft_skills" => { "fact:engineering-soft-skills-profile" => 14.0, "story:dogly-agenda-completion-alignment" => 7.0, "story:dogly-engineering-collaboration" => 6.0, "story:jcrew-crisis-leadership-feedback" => 5.0, "story:anthropologie-succession-mentorship" => 5.0, "fact:engineering-profile" => 4.0 },
      "impact" => { "story:jcrew-dress-swim-decision" => 5.0, "story:dogly-agenda-simplification" => 4.0, "career:jcrew-associate-store-manager-columbus-circle" => 3.0 },
      "complexity" => { "case-study:dogly-shopify-integration" => 5.0, "case-study:dogly-membership" => 4.0, "story:doglydaily-technical-debt-learning" => 4.0, "case-study:dogly-product-design" => 3.0 }
    }.freeze

    attr_reader :last_trace

    def initialize(scope: ::KnowledgeEntry.recruiter_retrievable, embedding_provider: OpenAiEmbeddingProvider.new)
      @scope = scope
      @embedding_provider = embedding_provider
      @intent_router = IntentRouter.new
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
      @intent_router.primary_intent(question)
    end

    def classified_intents(question)
      @intent_router.analyze(question).fetch(:candidates)
    end

    def classification(question)
      @intent_router.analyze(question)
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
      return scope_entry?(entry) if intent == "scope"
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

      if BOUNDARY_EXCLUDED_INTENTS.include?(intent)
        return false if claim_kinds.include?("boundary")
      end

      true
    end

    def claim_kinds_for(entry)
      Array(entry.metadata.dig("recruiter_evidence", "claims")).filter_map { |claim| claim["kind"]&.to_s }
    end

    def strict_intent?(intent)
      %w[risk typescript feedback disagreement ambiguity impact production scope complexity soft_skills availability].include?(intent)
    end

    def scope_entry?(entry)
      text = [ entry.source_reference, entry.title, entry.short_body, entry.body ].compact.join(" ")
      !text.match?(/\bdogly\b/i) && !archive_only?(entry) && claim_kinds_for(entry).any? { |kind| %w[demonstrated leadership_story engineering_story project integration_story].include?(kind) }
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
      rescue OpenAiEmbeddingProvider::ConfigurationError, OpenAiEmbeddingProvider::ProviderError, SocketError, ActiveRecord::StatementInvalid
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
      rescue OpenAiEmbeddingProvider::ConfigurationError, OpenAiEmbeddingProvider::ProviderError, SocketError, ActiveRecord::StatementInvalid
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
