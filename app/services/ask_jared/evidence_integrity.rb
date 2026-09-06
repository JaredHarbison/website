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
    INFERENTIAL_LANGUAGE = /\b(ensure[sd]?|enabl(?:e|ed|es|ing)|enhanc(?:e|ed|es|ing)|position(?:ed|s|ing)?|demonstrat(?:e|ed|es|ing)|show(?:s|ed|ing)?|indicat(?:e|ed|es|ing))\b/i
    DOMAIN_TERMS = %w[typescript react rails stripe].freeze
    UNSUPPORTED_RELATIONAL_CLAIMS = [
      [ /\b(?:not|without|lacking)\s+(?:being\s+)?the formal decision[- ]maker\b/i, ->(claims) { claims.any? { |claim| claim["text"].match?(/formal decision[- ]maker|formal authority|decision authority/i) } }, "formal authority claim is not supported" ],
      [ /\b(?:convinced|persuaded)\b/i, ->(claims) { claims.any? { |claim| claim["text"].match?(/convinced|persuaded/i) } }, "persuasion claim is not supported" ],
      [ /\bowned\s+(?:the\s+)?(?:whole|entire|full)\s+(?:product|platform|application)\b/i, ->(claims) { claims.any? { |claim| claim["text"].match?(/owned|ownership/i) && claim["text"].match?(/whole|entire|platform|application|product/i) } }, "platform-wide ownership claim is not supported" ],
      [ /\bmanaged\s+(?:engineers|developers|an engineering team|a team of engineers)\b/i, ->(claims) { claims.any? { |claim| claim["text"].match?(/managed|management/i) && claim["text"].match?(/engineer|developer|engineering team/i) } }, "engineering management claim is not supported" ],
      [ /\bprofessional\s+typescript\s+(?:experience|expertise|proficiency)\b|\b(?:typescript|ts)\s+(?:expert|proficient)\b/i, ->(claims) { claims.any? { |claim| claim["text"].match?(/typescript/i) && claim["text"].match?(/professional|experience|expert|proficien/i) && !claim["text"].match?(/not established|newer|learning|current/i) } }, "TypeScript depth claim is not supported" ],
      [ /\b(?:decided|chose|choose)\b[^.?!]{0,100}\b(?:not to build|instead of building|over building)\b/i, ->(claims) { claims.any? { |claim| claim["text"].match?(/decided|chose|choose/i) && claim["text"].match?(/not to build|instead of building|over building/i) } }, "not-built decision claim is not supported" ],
      [ /\b(?:shipped|released|deployed)\b/i, ->(claims) { claims.any? { |claim| claim["text"].match?(/shipped|released|deployed/i) && claim["kind"] != "planned" } }, "shipped-status claim is not supported" ]
    ].freeze

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
      validate_material_propositions!(answer, referenced_claims)
      relationships = if packet.respond_to?(:relationships)
        packet.relationships
      else
        referenced.flat_map { |entry| Array(entry.metadata.dig("recruiter_evidence", "approved_relationships")) }
      end
      if answer.match?(CAUSAL_LANGUAGE)
        raise Violation, "causal language requires an approved causal relationship" unless relationships.any? { |relationship| relationship["type"] == "causes" }
      end

      validate_sentences!(answer, referenced_claims, allowed_text, relationships: relationships) if claim_refs
      true
    end

    def self.validate_material_propositions!(answer, claims)
      UNSUPPORTED_RELATIONAL_CLAIMS.each do |pattern, support, message|
        raise Violation, message if answer.match?(pattern) && !support.call(claims)
      end
    end

    def self.validate_sentences!(answer, claims, allowed_text, relationships:)
      sentences = answer.split(/(?<=[.!?])\s+/).reject(&:blank?)
      sentences.each do |sentence|
        numbers = sentence.scan(/\$?\d+(?:\.\d+)?%?/)
        if numbers.any? { |number| !claims.any? { |claim| claim["text"].include?(number) } }
          raise Violation, "numeric claim is not present in its supporting claim"
        end

        if claims.any? { |claim| claim["kind"] == "planned" } && sentence.match?(/increased|improved|achieved|resulted in|measured result|successful outcome/i)
          raise Violation, "planned evidence cannot be presented as achieved"
        end
        if claims.any? { |claim| claim["kind"] == "self_estimate" } && sentence.match?(/\d|percent|%/) && !sentence.match?(/estimate|estimated|roughly|approximately|self-reported|retrospective/i)
          raise Violation, "self-estimate must remain qualified"
        end
        if sentence.match?(/self-estimat|estimate(?:d)? .*method|method .*estimate/i) && !claims.any? { |claim| claim["text"].match?(/self-estimat|estimate(?:d)? .*method|method .*estimate/i) }
          raise Violation, "self-estimate cannot be presented as a learning method"
        end
        if claims.any? { |claim| claim["kind"] == "boundary" } && sentence.match?(/has professional|is experienced|expert|proficient|demonstrated .*experience/i) && !sentence.match?(/not established|does not|no /i)
          raise Violation, "boundary claim cannot become demonstrated expertise"
        end

        mentioned_domains = DOMAIN_TERMS.select { |term| sentence.match?(/\b#{Regexp.escape(term)}\b/i) }
        mentioned_domains.each do |domain|
          next if claims.any? { |claim| claim["text"].match?(/\b#{Regexp.escape(domain)}\b/i) }

          if sentence.match?(/experience|expertise|skill|proficien|enhanc|learn/i) || numbers.any?
            raise Violation, "claim cannot be transferred into #{domain} experience"
          end
        end

        next unless sentence.match?(INFERENTIAL_LANGUAGE)
        next if relationships.any? { |relationship| relationship["type"].to_s == "causes" } && sentence.match?(CAUSAL_LANGUAGE)

        normalized_sentence = sentence.downcase.gsub(/[^a-z0-9%]+/, " ").split
        supported = claims.any? do |claim|
          claim_words = claim["text"].downcase.gsub(/[^a-z0-9%]+/, " ").split
          meaningful = normalized_sentence.reject { |word| word.length < 4 || %w[this that the with from into about evidence].include?(word) }
          meaningful.count { |word| claim_words.include?(word) } >= [ meaningful.length - 2, 3 ].max
        end
        raise Violation, "inferential language creates an unsupported proposition" unless supported
      end
    end
  end
end
