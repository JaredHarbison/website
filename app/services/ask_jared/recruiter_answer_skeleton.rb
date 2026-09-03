module AskJared
  class RecruiterAnswerSkeleton
    ROLE_POLICIES = {
      "characterization" => { roles: %w[direct_fact], max: 1 },
      "candidacy" => { roles: %w[direct_fact action], max: 2 },
      "rails" => { roles: %w[direct_fact action], max: 2 },
      "react" => { sources: %w[story:dogly-engineering-collaboration story:dogly-react-migration-disagreement], max: 2 },
      "product" => { sources: %w[case-study:dogly-product-design story:dogly-agenda-product-direction story:dogly-pre-accelerator-prioritization], max: 2 },
      "organization" => { roles: %w[direct_fact boundary], max: 3 },
      "collaboration" => { sources: %w[story:dogly-engineering-collaboration], max: 1 },
      "risk" => { roles: %w[boundary trajectory direct_fact], max: 3 },
      "typescript" => { roles: %w[boundary trajectory], exclude_sources: %w[story:stripe-learning-ramp], max: 2 },
      "learning" => { sources: %w[story:stripe-learning-ramp], max: 1 },
      "failure" => { sources: %w[story:doglydaily-technical-debt-learning], max: 1 },
      "feedback" => { sources: %w[story:jcrew-crisis-leadership-feedback], max: 1 },
      "prioritization" => { sources: %w[story:dogly-pre-accelerator-prioritization], max: 1 },
      "disagreement" => { sources: %w[story:dogly-react-migration-disagreement], max: 1 },
      "mentorship" => { sources: %w[story:anthropologie-succession-mentorship], max: 1 },
      "ambiguity" => { sources: %w[story:doglydaily-three-send-ux], max: 1 },
      "impact" => { sources: %w[story:jcrew-dress-swim-decision story:dogly-agenda-simplification career:jcrew-associate-store-manager-columbus-circle], roles: %w[action metric], max: 2 },
      "stakeholder" => { sources: %w[story:jcrew-dress-swim-decision], max: 1 }
    }.freeze

    attr_reader :intent, :question, :roles, :relationships

    def initialize(packet:, intent:, question:)
      @packet = packet
      @intent = intent.to_s
      @question = question.to_s
      @roles = build_roles
      @relationships = packet.relationships
    end

    def role_ids
      roles.map { |role| role.fetch("id") }
    end

    def formatted_context
      JSON.pretty_generate({ intent: intent, question: question, roles: roles, relationships: relationships.map { |r| r.except("entry_id", "source_reference") } })
    end

    def resolve_role_refs!(refs)
      unknown = Array(refs).reject { |ref| role_ids.include?(ref) }
      raise EvidenceIntegrity::Violation, "skeleton role is outside the supplied packet" if unknown.any?

      Array(refs)
    end

    def evidence_ids_for(role_refs)
      roles.select { |role| role_refs.include?(role.fetch("id")) }.flat_map { |role| role.fetch("entry_ids") }.uniq
    end

    def claim_refs_for(role_refs)
      roles.select { |role| role_refs.include?(role.fetch("id")) }.flat_map { |role| role.fetch("claim_refs") }.uniq
    end

    private

    def build_roles
      packet_claims = selected_claims
      packet_claims.each_with_index.map do |claim, index|
        {
          "id" => "r#{index + 1}",
          "role" => claim.fetch("role", "direct_fact"),
          "text" => claim.fetch("text"),
          "claim_refs" => [ claim.fetch("alias") ],
          "entry_ids" => [ claim.fetch("entry_id") ],
          "provenance" => claim.fetch("provenance"),
          "kind" => claim.fetch("kind")
        }
      end
    end

    def selected_claims
      policy = ROLE_POLICIES[@intent]
      return @packet.claims.first(3) unless policy

      candidates = @packet.claims
      candidates = candidates.select { |claim| policy[:roles].include?(claim.fetch("role")) } if policy[:roles]
      candidates = candidates.select { |claim| policy[:sources].include?(claim.fetch("source_reference")) } if policy[:sources]
      candidates = candidates.reject { |claim| policy[:exclude_sources].include?(claim.fetch("source_reference")) } if policy[:exclude_sources]
      candidates = candidates.first(policy[:max])
      candidates.presence || (policy[:sources] ? [] : @packet.claims.first(policy[:max]))
    end
  end
end
