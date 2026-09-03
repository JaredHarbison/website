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
          lines << "- #{claim.fetch("alias")}: #{claim.fetch("text")} (#{claim.fetch("kind")}; provenance: #{claim.fetch("provenance")})"
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
        raw_claims = Array(entry.metadata.dig("recruiter_evidence", "claims"))
        raw_claims = [ { "text" => entry.short_body.presence || entry.body, "kind" => "demonstrated", "provenance" => source_reference } ] if raw_claims.empty?
        raw_claims.each_with_index.map do |claim, index|
          alias_index += 1
          {
            "ref" => "#{source_reference}#claim-#{index}",
            "alias" => "c#{alias_index}",
            "entry_id" => entry.id.to_s,
            "source_reference" => source_reference,
            "text" => claim.fetch("text").to_s,
            "kind" => claim.fetch("kind").to_s,
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
      matches = all_claims.select do |claim|
        text = claim.fetch("text").downcase
        terms.any? { |term| text.include?(term) }
      end
      matches.first(max_claims).presence || all_claims.first(max_claims)
    end

    def reindex_aliases(claims)
      claims.each_with_index.map { |claim, index| claim.merge("alias" => "c#{index + 1}") }
    end
  end
end
