require "test_helper"

class AskJaredRecruiterAnswerSkeletonTest < ActiveSupport::TestCase
  setup do
    KnowledgeEntry.delete_all
  end

  test "selects only intent-compatible minimum roles" do
    collaboration = entry("story:dogly-engineering-collaboration", "Direct engineer collaboration.", "direct_fact")
    stripe = entry("story:stripe-learning-ramp", "Learning ramp was roughly 15%.", "qualified_metric", "self_estimate")
    disagreement = entry("story:dogly-react-migration-disagreement", "React migration tradeoff.", "action")
    boundary = entry("fact:professional-typescript-boundary", "Professional TypeScript depth is not established.", "boundary", "boundary")
    packet = AskJared::SynthesisEvidencePacket.new(entries: [ collaboration, stripe, disagreement, boundary ], intent: "typescript", question: "How experienced is Jared with TypeScript?")

    skeleton = AskJared::RecruiterAnswerSkeleton.new(packet: packet, intent: "typescript", question: "How experienced is Jared with TypeScript?")

    assert_equal %w[boundary], skeleton.roles.map { |role| role.fetch("role") }
    refute_includes skeleton.formatted_context, stripe.id.to_s
  end

  test "uses the richer disagreement story rather than a generic adjacent claim" do
    generic = entry("story:generic", "Generic collaboration.", "direct_fact")
    disagreement = entry("story:dogly-react-migration-disagreement", "React migration context, reasoning, tradeoff, and result.", "action")
    packet = AskJared::SynthesisEvidencePacket.new(entries: [ generic, disagreement ], intent: "disagreement", question: "Tell me about a technical disagreement.")

    skeleton = AskJared::RecruiterAnswerSkeleton.new(packet: packet, intent: "disagreement", question: "Tell me about a technical disagreement.")

    assert_equal [ disagreement.id.to_s ], skeleton.evidence_ids_for(skeleton.role_ids)
  end

  test "selects approved stakeholder decision stories for stakeholder questions" do
    generic = entry("story:generic", "Generic collaboration.", "direct_fact")
    stakeholder = entry("story:dogly-agenda-completion-alignment", "Translated a stakeholder disagreement about completion metrics.", "action")
    packet = AskJared::SynthesisEvidencePacket.new(entries: [ generic, stakeholder ], intent: "stakeholder", question: "How does Jared collaborate with product stakeholders?")

    skeleton = AskJared::RecruiterAnswerSkeleton.new(packet: packet, intent: "stakeholder", question: "How does Jared collaborate with product stakeholders?")

    assert_equal [ stakeholder.id.to_s ], skeleton.evidence_ids_for(skeleton.role_ids)
  end

  test "broad characterization selects multiple dimensions before a single anecdote" do
    partner = entry("case-study:dogly-partner-applications", "Designed a resumable Rails application workflow.", "direct_fact")
    product = entry("case-study:dogly-product-design", "Built a coherent product language across several product surfaces.", "direct_fact")
    collaboration = entry("story:dogly-engineering-collaboration", "Moved from backend work into full-stack work and collaborated with engineers.", "direct_fact")
    react = entry("story:dogly-react-migration-disagreement", "Pushed back on broader React use for authentication pages.", "action")
    packet = AskJared::SynthesisEvidencePacket.new(entries: [ react, partner, product, collaboration ], intent: "characterization", question: "What kind of engineer is Jared?")

    skeleton = AskJared::RecruiterAnswerSkeleton.new(packet: packet, intent: "characterization", question: "What kind of engineer is Jared?")
    sources = skeleton.evidence_ids_for(skeleton.role_ids).map { |id| KnowledgeEntry.find(id).source_reference }

    assert_operator sources.uniq.length, :>=, 3
    assert_operator sources.count { |source| source.include?("react-migration") }, :<=, 1
    assert_equal partner.id.to_s, skeleton.evidence_ids_for(skeleton.role_ids).first
  end

  private

  def entry(source_reference, text, role, kind = "demonstrated")
    KnowledgeEntry.create!(
      title: source_reference,
      body: text,
      metadata: { "recruiter_evidence" => { "claims" => [ { "text" => text, "role" => role, "kind" => kind } ] } },
      entry_type: "project",
      approval_status: "approved",
      visibility: "recruiter_visible",
      source_type: "test",
      source_reference: source_reference,
      source_fingerprint: source_reference
    )
  end
end
