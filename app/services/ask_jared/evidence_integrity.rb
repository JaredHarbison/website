module AskJared
  class EvidenceIntegrity
    CAUSAL_LANGUAGE = /\b(caused|causes|led to|resulted in|produced|because of|drove)\b/i

    def self.validate_response!(answer:, evidence_ids:, entries:)
      referenced = entries.select { |entry| evidence_ids.include?(entry.id.to_s) }
      if referenced.length > 1 && answer.match?(CAUSAL_LANGUAGE)
        relationships = referenced.flat_map { |entry| Array(entry.metadata.dig("recruiter_evidence", "approved_relationships")) }
        raise ArgumentError, "causal language requires an approved causal relationship" unless relationships.any? { |relationship| relationship["type"] == "causes" }
      end

      referenced.each do |entry|
        evidence = entry.metadata.fetch("recruiter_evidence", {})
        if Array(evidence["claims"]).any? { |claim| claim["kind"] == "planned" } && answer.match?(/increased|improved|achieved|resulted in/i)
          raise ArgumentError, "planned evidence cannot be presented as achieved"
        end
      end
      true
    end
  end
end
