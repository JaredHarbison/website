module AskJared
  class SynthesisEvidencePacket
    attr_reader :entries, :claims, :relationships, :intent, :question, :max_claims

    def initialize(entries:, intent:, question: nil, max_claims: nil)
      @entries = Array(entries)
      @intent = intent
      @question = question.to_s
      @max_claims = max_claims
      @claims = reindex_aliases(select_claims(build_claims, max_claims))
      @relationships = build_relationships
    end

    def empty?
      entries.empty?
    end

    def first(*args)
      entries.first(*args)
    end

    def bounded(limit)
      self.class.new(entries: entries.first(limit), intent: intent, question: question, max_claims: max_claims)
    end

    def map(...)
      entries.map(...)
    end

    def select(...)
      entries.select(...)
    end

    def each(...)
      entries.each(...)
    end

    def evidence_ids
      entries.map { |entry| entry.id.to_s }
    end

    def source_urls
      entries.filter_map(&:public_url).select { |url| url.start_with?("https://") }.uniq
    end

    def claim_references
      claims.map { |claim| claim.fetch("ref") }
    end

    def claim_aliases
      claims.to_h { |claim| [ claim.fetch("alias"), claim.fetch("ref") ] }
    end

    def resolve_claim_aliases!(aliases)
      unknown = Array(aliases).reject { |alias_name| claim_aliases.key?(alias_name) }
      raise EvidenceIntegrity::Violation, "claim reference is outside the supplied packet" if unknown.any?

      Array(aliases).map { |alias_name| claim_aliases.fetch(alias_name) }
    end

    def formatted_context
      claims.group_by { |claim| claim.fetch("entry_id") }.map do |entry_id, entry_claims|
        entry = entries.find { |candidate| candidate.id.to_s == entry_id }
        lines = [ entry.title ]
        lines << "Source: #{entry.source_reference}"
        lines << "Entry type: #{entry.entry_type}"
        lines << "Allowed claims:"
        entry_claims.each do |claim|
          role = claim["role"].presence || "fact"
          lines << "- #{claim.fetch("alias")}: #{claim.fetch("text")} (role: #{role}; #{claim.fetch("kind")}; provenance: #{claim.fetch("provenance")})"
        end
        entry_relationships = relationships.select { |relationship| relationship.fetch("entry_id") == entry_id }.map { |relationship| relationship.except("entry_id", "source_reference") }
        lines << "Approved relationships: #{entry_relationships.to_json}" if entry_relationships.any?
        lines.join("\n")
      end.join("\n\n")
    end

    private

    def build_claims
      alias_index = 0
      entries.flat_map do |entry|
        source_reference = entry.source_reference.to_s
        raw_claims = Array(entry.metadata.dig("recruiter_evidence", "claims")) + normalized_claims_for(entry)
        raw_claims = [ { "text" => entry.short_body.presence || entry.body, "kind" => "demonstrated", "provenance" => source_reference } ] if raw_claims.empty?
        raw_claims.each_with_index.map do |claim, index|
          alias_index += 1
          {
            "ref" => "#{source_reference}##{claim["ref_suffix"].presence || "claim-#{index}"}",
            "alias" => "c#{alias_index}",
            "entry_id" => entry.id.to_s,
            "source_reference" => source_reference,
            "text" => claim.fetch("text").to_s,
            "kind" => claim.fetch("kind").to_s,
            "role" => claim.fetch("role", inferred_role(entry, claim)).to_s,
            "provenance" => claim.fetch("provenance", source_reference).to_s
          }
        end
      end
    end

    def build_relationships
      entries.flat_map do |entry|
        Array(entry.metadata.dig("recruiter_evidence", "approved_relationships")).map do |relationship|
          relationship.merge("entry_id" => entry.id.to_s, "source_reference" => entry.source_reference.to_s)
        end
      end
    end

    def select_claims(all_claims, max_claims)
      return all_claims if max_claims.nil? || all_claims.length <= max_claims
      return all_claims.first(max_claims) if question.blank?

      terms = question.downcase.scan(/[a-z][a-z0-9%+-]{2,}/).uniq
      matches = all_claims.sort_by do |claim|
        text = claim.fetch("text").downcase
        score = terms.sum { |term| text.include?(term) ? 1 : 0 }
        role_boost = intent_role_boost(claim["role"])
        [ -(score + role_boost), all_claims.index(claim) ]
      end.select { |claim| terms.any? { |term| claim.fetch("text").downcase.include?(term) } }
      matches.first(max_claims).presence || all_claims.first(max_claims)
    end

    def intent_role_boost(role)
      case intent
      when "impact" then role.to_s == "metric" ? 4 : 0
      when "learning" then role.to_s == "process" ? 4 : 0
      when "react" then role.to_s == "direct_fact" ? 4 : 0
      when "ambiguity" then %w[context action planned_state].include?(role.to_s) ? 3 : 0
      else 0
      end
    end

    def inferred_role(entry, claim)
      return "boundary" if claim.fetch("kind").to_s == "boundary"
      return "qualified_metric" if claim.fetch("kind").to_s == "self_estimate"
      return "planned_state" if claim.fetch("kind").to_s == "planned"

      case entry.source_reference.to_s
      when "story:dogly-engineering-collaboration" then "direct_fact"
      when "story:stripe-learning-ramp" then "process"
      when "story:doglydaily-three-send-ux" then "context"
      when "story:doglydaily-technical-debt-learning" then "mistake"
      when "story:jcrew-crisis-leadership-feedback" then "feedback"
      when "story:dogly-pre-accelerator-prioritization" then "context"
      when "story:dogly-react-migration-disagreement" then "action"
      when "story:anthropologie-succession-mentorship" then "action"
      else "direct_fact"
      end
    end

    def normalized_claims_for(entry)
      source = entry.source_reference.to_s
      return [] unless NormalizedRecruiterEvidence::SOURCES.key?(source)

      NormalizedRecruiterEvidence.claims_for(entry).map.with_index do |claim, index|
        claim.merge("provenance" => source, "ref_suffix" => "normalized-#{index}")
      end
    end

    module NormalizedRecruiterEvidence
      SOURCES = %w[
        story:dogly-engineering-collaboration story:stripe-learning-ramp story:doglydaily-three-send-ux
        story:doglydaily-technical-debt-learning story:jcrew-crisis-leadership-feedback story:dogly-pre-accelerator-prioritization
        story:dogly-react-migration-disagreement story:anthropologie-succession-mentorship story:jcrew-dress-swim-decision
        story:dogly-agenda-simplification career:jcrew-store-director-columbus-circle
        career:jcrew-associate-store-manager-columbus-circle
      ].index_with(true).freeze

      module_function

      def claims_for(entry)
        evidence = entry.metadata.fetch("recruiter_evidence", {})
        source = entry.source_reference.to_s
        claims = []
        if %w[story:dogly-engineering-collaboration story:stripe-learning-ramp story:doglydaily-three-send-ux story:doglydaily-technical-debt-learning story:jcrew-crisis-leadership-feedback story:dogly-pre-accelerator-prioritization story:dogly-react-migration-disagreement story:anthropologie-succession-mentorship story:jcrew-dress-swim-decision story:dogly-agenda-simplification career:jcrew-store-director-columbus-circle career:jcrew-associate-store-manager-columbus-circle].include?(source)
          claims << { "text" => entry.body.to_s, "kind" => source == "story:doglydaily-three-send-ux" ? "planned" : "demonstrated", "role" => %w[story:jcrew-dress-swim-decision career:jcrew-store-director-columbus-circle career:jcrew-associate-store-manager-columbus-circle].include?(source) ? "action" : role_for(source) }
        end
        if evidence["result"].present? && %w[story:jcrew-dress-swim-decision story:dogly-agenda-simplification career:jcrew-store-director-columbus-circle career:jcrew-associate-store-manager-columbus-circle].include?(source)
          claims << { "text" => evidence["result"].to_s, "kind" => "demonstrated", "role" => "metric" }
        end
        claims
      end

      def role_for(source)
        {
          "story:dogly-engineering-collaboration" => "direct_fact",
          "story:stripe-learning-ramp" => "process",
          "story:doglydaily-three-send-ux" => "context",
          "story:doglydaily-technical-debt-learning" => "mistake",
          "story:jcrew-crisis-leadership-feedback" => "feedback",
          "story:dogly-pre-accelerator-prioritization" => "context",
          "story:dogly-react-migration-disagreement" => "action",
          "story:anthropologie-succession-mentorship" => "action"
        }.fetch(source, "direct_fact")
      end
    end

    def reindex_aliases(claims)
      claims.each_with_index.map { |claim, index| claim.merge("alias" => "c#{index + 1}") }
    end
  end
end
