module AskJared
  class RecruiterAnswerSkeleton
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
      packet_claims = @packet.claims
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
  end
end
