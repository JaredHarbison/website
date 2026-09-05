require "test_helper"

class AskJaredCandidateKnowledgeInventoryTest < ActiveSupport::TestCase
  setup { KnowledgeEntry.delete_all }

  test "imports evidenced case studies as private candidates with explicit review metadata" do
    entries = AskJared::CandidateKnowledgeInventory.new.sync!
    shopify = entries.find { |entry| entry.source_reference == "case-study:dogly-shopify-integration" }
    metric = entries.find { |entry| entry.source_reference == "metric:dogly-membership-subscription-growth" }

    assert_equal "candidate", shopify.approval_status
    assert_equal "private", shopify.visibility
    assert_includes shopify.metadata["proposed_recruiter_excerpts"], "The first month began with a limited rollout to a single product from a single brand."
    assert_equal [ "comparison_window", "denominator", "attribution_boundaries", "original_metric_query" ], metric.metadata["missing_methodology"]
    assert_includes metric.metadata["review_flags"], "metric_methodology_review_required"
    assert_equal 34, entries.length
    assert_equal "leadership_story", entries.find { |entry| entry.source_reference == "career:jcrew-store-director-columbus-circle" }.entry_type
    assert_includes entries.find { |entry| entry.source_reference == "career:jcrew-store-director-columbus-circle" }.metadata.dig("recruiter_evidence", "competencies"), "Large-team leadership"
    assert_includes entries.find { |entry| entry.source_reference == "story:dogly-agenda-product-direction" }.body, "Community or message-board"
    agenda = entries.find { |entry| entry.source_reference == "story:dogly-agenda-product-direction" }
    assert_equal [ "demonstrated" ], agenda.metadata.dig("recruiter_evidence", "claims").map { |claim| claim["kind"] }
    assert_equal true, entries.find { |entry| entry.source_reference == "case-study:fridge-no-more-bulk-ordering" }.metadata.dig("approval_readiness", "ready_for_jared_approval")
    assert_equal true, metric.metadata.dig("approval_readiness", "ready_for_jared_approval")
  end

  test "links Shopify acquisition, membership, and fulfillment without attributing the metric to fulfillment" do
    entries = AskJared::CandidateKnowledgeInventory.new.sync!
    story = entries.find { |entry| entry.source_reference == "story:dogly-shopify-membership-acquisition" }
    chain = story.metadata["evidence_chain"]

    assert_includes chain["chronology"].join(" "), "shipped in late 2025"
    assert_includes chain["chronology"].join(" "), "limited rollout in 2026"
    assert_equal "Unknown because the measurement date/window is not recorded.", chain["portion_present_at_measurement"]
    assert_includes chain["safe_attribution"], "do not present it as a causal Shopify or fulfillment result"
  end

  test "applies publication decisions as metadata without approving entries" do
    entries = AskJared::CandidateKnowledgeInventory.new.sync!
    fridge = entries.find { |entry| entry.source_reference == "case-study:fridge-no-more-bulk-ordering" }
    partner = entries.find { |entry| entry.source_reference == "case-study:dogly-partner-applications" }

    assert_empty fridge.metadata["publication_holds"]
    refute_includes partner.metadata["publication_holds"], "partner_application_internals"
    assert entries.all? { |entry| entry.approval_status == "candidate" && entry.visibility == "private" }
  end

  test "records no unanswered Jared context questions after human review" do
    needed = AskJared::CandidateKnowledgeInventory.new.sync!.filter_map do |entry|
      review = entry.metadata["human_review"]
      [ review["priority"], entry.source_reference, review["questions"].length ] if review["status"] == "HUMAN_CONTEXT_NEEDED"
    end

    assert_empty needed
  end

  test "records exact product-design ownership statements for concrete review" do
    entry = AskJared::CandidateKnowledgeInventory.new.sync!.find { |item| item.source_reference == "case-study:dogly-product-design" }

    assert_equal "content/case_studies/dogly-product-design.md", entry.metadata.dig("ownership_review", "case_study")
    assert_equal 3, entry.metadata.dig("ownership_review", "statements").length
    assert_empty entry.metadata["review_flags"]
    assert_equal "CONFIRMED_BY_JARED", entry.metadata.dig("ownership_review", "status")
  end

  test "finalizes all approved entries without changing provenance" do
    entries = AskJared::CandidateKnowledgeInventory.new.sync!
    fingerprints = entries.to_h { |entry| [ entry.source_reference, entry.source_fingerprint ] }

    finalized = AskJared::FinalizeRecruiterKnowledge.new.call(generate_embeddings: false)

    assert_equal 34, finalized.length
    assert finalized.all? { |entry| entry.approval_status == "approved" }
    finalized.each { |entry| assert_equal fingerprints.fetch(entry.source_reference), entry.source_fingerprint }
    assert_equal [], KnowledgeEntry.where.not(approval_status: "approved").where(visibility: "recruiter_visible").pluck(:source_reference)
  end

  test "resolves the Federation Briefing checkout when it is present locally" do
    entry = AskJared::CandidateKnowledgeInventory.new.sync!.find { |item| item.source_reference == "case-study:federation-briefing" }
    repository = entry.metadata["external_repository"]

    skip "The optional Federation Briefing checkout is not present in CI" unless repository["accessible_locally"]

    assert repository["accessible_locally"]
    assert_equal "0325b36", repository["checkout_commit"][0, 7]
    assert_equal "https://github.com/JaredHarbison/the-federation-briefing", repository["repository_url"]
  end

  test "curates URBN metric separately from archive-only prototype history" do
    entries = AskJared::CandidateKnowledgeInventory.new.records
    metric = entries.find { |entry| entry["anecdote_id"] == "career:urbn-senior-merchandiser" }
    archive = entries.find { |entry| entry["anecdote_id"] == "archive:urbn-senior-merchandiser-prototype-workshops" }

    assert_equal "primary_recruiter_evidence", metric.dig("metadata", "recruiter_evidence", "recruiter_utility")
    assert_includes metric["body"], "40%"
    refute_includes metric["body"], "prototype"
    assert_equal "archive_only", archive.dig("metadata", "recruiter_evidence", "recruiter_utility")
    assert_includes archive["body"], "prototype"
    refute_includes archive["body"], "40%"
  end

  test "adds only bounded recruiter relationships" do
    entries = AskJared::CandidateKnowledgeInventory.new.records
    typescript = entries.find { |entry| entry["anecdote_id"] == "fact:professional-typescript-boundary" }
    agenda = entries.find { |entry| entry["anecdote_id"] == "story:dogly-agenda-simplification" }

    assert_equal "story:stripe-learning-ramp", typescript.dig("metadata", "recruiter_evidence", "approved_relationships", 0, "target")
    assert_equal "supports_outcome", agenda.dig("metadata", "recruiter_evidence", "approved_relationships", 0, "type")
  end
end
