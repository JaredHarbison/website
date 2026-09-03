module AskJared
  class SynthesisEvidencePacket
    attr_reader :entries, :claims, :relationships, :intent

    def initialize(entries:, intent:)
      @entries = Array(entries)
      @intent = intent
      @claims = build_claims
      @relationships = build_relationships
    end

    def empty?
      entries.empty?
    end

    def first(*args)
      entries.first(*args)
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
        lines = [ "[#{entry_id}] #{entry.title}" ]
        lines << "Source: #{entry.source_reference}"
        lines << "Entry type: #{entry.entry_type}"
        lines << "Allowed claims:"
        entry_claims.each do |claim|
          lines << "- #{claim.fetch("alias")}: #{claim.fetch("text")} (#{claim.fetch("kind")}; provenance: #{claim.fetch("provenance")})"
        end
        lines << "Approved relationships: #{relationships.select { |relationship| relationship.fetch("entry_id") == entry_id }.to_json}" if relationships.any? { |relationship| relationship.fetch("entry_id") == entry_id }
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
  end
end
