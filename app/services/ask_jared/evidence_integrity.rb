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

    def self.validate_response!(answer:, evidence_ids:, packet: nil, entries: nil, claim_refs: nil)
      entries ||= packet
      referenced = entries.select { |entry| evidence_ids.include?(entry.id.to_s) }
      claims = packet.respond_to?(:claims) ? packet.claims : []
      allowed_claim_refs = claims.map { |claim| claim.fetch("ref") }
      if claim_refs
        raise Violation, "claim reference is outside the supplied packet" unless claim_refs.all? { |ref| allowed_claim_refs.include?(ref) }
        raise Violation, "answer evidence must identify supporting claims" if evidence_ids.any? && claim_refs.empty?
        claim_entry_ids = claims.select { |claim| claim_refs.include?(claim["ref"]) }.map { |claim| claim["entry_id"] }
        raise Violation, "claim reference does not support cited evidence" unless claim_entry_ids.all? { |entry_id| evidence_ids.include?(entry_id) }
      end

      referenced_claims = claims.select { |claim| claim_refs&.include?(claim["ref"]) }
      allowed_text = referenced_claims.map { |claim| claim["text"] }.join(" ")
      if answer.match?(CAUSAL_LANGUAGE)
        relationships = if packet.respond_to?(:relationships)
          packet.relationships
        else
          referenced.flat_map { |entry| Array(entry.metadata.dig("recruiter_evidence", "approved_relationships")) }
        end
        raise Violation, "causal language requires an approved causal relationship" unless relationships.any? { |relationship| relationship["type"] == "causes" }
      end

      if claim_refs && answer.scan(/\$?\d+(?:\.\d+)?%?/).any? { |number| !allowed_text.include?(number) }
        raise Violation, "numeric claim is not present in an allowed claim"
      end

      referenced_claims.each do |claim|
        if claim["kind"] == "planned" && answer.match?(/increased|improved|achieved|resulted in|measured result/i)
          raise Violation, "planned evidence cannot be presented as achieved"
        end
        if claim["kind"] == "self_estimate" && answer.match?(/\d|percent|%/) && !answer.match?(/estimate|estimated|roughly|approximately|self-reported|retrospective/i)
          raise Violation, "self-estimate must remain qualified"
        end
        if claim["kind"] == "boundary" && answer.match?(/has professional|is experienced|expert|proficient|demonstrated .*experience/i) && !answer.match?(/not established|does not|no /i)
          raise Violation, "boundary claim cannot become demonstrated expertise"
        end
      end
      true
    end
  end
end
