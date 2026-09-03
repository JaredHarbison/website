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
