require "test_helper"
require_relative "../../app/services/ask_jared/synthesis_evidence_packet"

class AskJaredEvidenceIntegrityTest < ActiveSupport::TestCase
  def packet(claims:, relationships: [])
    entry = KnowledgeEntry.new(
      id: 1, title: "Evidence", body: "Evidence", short_body: "Evidence", entry_type: "project",
      source_reference: "story:test",
      metadata: { "recruiter_evidence" => { "claims" => claims, "approved_relationships" => relationships } }
    )
    AskJared::SynthesisEvidencePacket.new(entries: [ entry ], intent: "test")
  end

  test "accepts a response whose claim reference is in the packet" do
    current = packet(claims: [ { "text" => "The task increased 15%.", "kind" => "demonstrated", "provenance" => "story:test" } ])

    assert AskJared::EvidenceIntegrity.validate_response!(
      answer: "The task increased 15%.", evidence_ids: [ "1" ], claim_refs: [ "story:test#claim-0" ], packet: current
    )
  end

  test "resolves packet-local aliases to exact internal claim references" do
    current = packet(claims: [
      { "text" => "First claim.", "kind" => "demonstrated", "provenance" => "story:test" },
      { "text" => "Second claim.", "kind" => "demonstrated", "provenance" => "story:test" }
    ])

    assert_equal({ "c1" => "story:test#claim-0", "c2" => "story:test#claim-1" }, current.claim_aliases)
    assert_equal [ "story:test#claim-0", "story:test#claim-1" ], current.resolve_claim_aliases!([ "c1", "c2" ])
  end

  test "rejects an unknown alias and an alias outside the supplied packet" do
    current = packet(claims: [ { "text" => "Only claim.", "kind" => "demonstrated", "provenance" => "story:test" } ])

    assert_raises(AskJared::EvidenceIntegrity::Violation) { current.resolve_claim_aliases!([ "c2" ]) }
    assert_raises(AskJared::EvidenceIntegrity::Violation) { current.resolve_claim_aliases!([ "story:other#claim-0" ]) }
  end

  test "rejects claim references and numeric facts outside the packet" do
    current = packet(claims: [ { "text" => "The task improved.", "kind" => "demonstrated", "provenance" => "story:test" } ])

    assert_raises(AskJared::EvidenceIntegrity::Violation) do
      AskJared::EvidenceIntegrity.validate_response!(answer: "The task improved 40%.", evidence_ids: [ "1" ], claim_refs: [ "story:other#claim-0" ], packet: current)
    end
  end

  test "rejects achieved wording for planned claims" do
    current = packet(claims: [ { "text" => "Measurement is planned.", "kind" => "planned", "provenance" => "story:test" } ])

    assert_raises(AskJared::EvidenceIntegrity::Violation) do
      AskJared::EvidenceIntegrity.validate_response!(answer: "The measurement improved.", evidence_ids: [ "1" ], claim_refs: [ "story:test#claim-0" ], packet: current)
    end
  end

  test "requires qualification for self-estimates and preserves boundaries" do
    estimate = packet(claims: [ { "text" => "The ramp was roughly 15% by Jared's estimate.", "kind" => "self_estimate", "provenance" => "story:test" } ])
    boundary = packet(claims: [ { "text" => "Professional TypeScript experience is not established.", "kind" => "boundary", "provenance" => "story:test" } ])

    assert_raises(AskJared::EvidenceIntegrity::Violation) do
      AskJared::EvidenceIntegrity.validate_response!(answer: "The ramp took 15%.", evidence_ids: [ "1" ], claim_refs: [ "story:test#claim-0" ], packet: estimate)
    end
    assert_raises(AskJared::EvidenceIntegrity::Violation) do
      AskJared::EvidenceIntegrity.validate_response!(answer: "Jared has professional TypeScript experience.", evidence_ids: [ "1" ], claim_refs: [ "story:test#claim-0" ], packet: boundary)
    end
  end

  test "requires an approved causal relationship for causal language" do
    current = packet(claims: [ { "text" => "The work and result are documented separately.", "kind" => "demonstrated", "provenance" => "story:test" } ])

    assert_raises(AskJared::EvidenceIntegrity::Violation) do
      AskJared::EvidenceIntegrity.validate_response!(answer: "The work led to the result.", evidence_ids: [ "1" ], claim_refs: [ "story:test#claim-0" ], packet: current)
    end
  end
end
