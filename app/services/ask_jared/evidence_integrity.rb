module AskJared
  class EvidenceIntegrity
    Violation = Class.new(ArgumentError) do
      attr_reader :violations

      def initialize(*violations)
        @violations = violations
        super(violations.join("; "))
      end
    end

    CAUSAL_LANGUAGE = /\b(caused|causes|led to|resulted in|produced|because of|drove)\b/i

    def self.validate_response!(answer:, evidence_ids:, entries:)
      referenced = entries.select { |entry| evidence_ids.include?(entry.id.to_s) }
      if referenced.length > 1 && answer.match?(CAUSAL_LANGUAGE)
        relationships = referenced.flat_map { |entry| Array(entry.metadata.dig("recruiter_evidence", "approved_relationships")) }
        raise Violation, "causal language requires an approved causal relationship" unless relationships.any? { |relationship| relationship["type"] == "causes" }
      end

      referenced.each do |entry|
        evidence = entry.metadata.fetch("recruiter_evidence", {})
        if Array(evidence["claims"]).any? { |claim| claim["kind"] == "planned" } && answer.match?(/increased|improved|achieved|resulted in/i)
          raise Violation, "planned evidence cannot be presented as achieved"
        end
      end
      true
    end
  end
end
