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
  end

  test "records exact product-design ownership statements for concrete review" do
    entry = AskJared::CandidateKnowledgeInventory.new.sync!.find { |item| item.source_reference == "case-study:dogly-product-design" }

    assert_equal "content/case_studies/dogly-product-design.md", entry.metadata.dig("ownership_review", "case_study")
    assert_equal 3, entry.metadata.dig("ownership_review", "statements").length
    assert_includes entry.metadata["review_flags"], "individual_ownership_review_required"
  end

  test "resolves the Federation Briefing checkout when it is present locally" do
    entry = AskJared::CandidateKnowledgeInventory.new.sync!.find { |item| item.source_reference == "case-study:federation-briefing" }
    repository = entry.metadata["external_repository"]

    assert repository["accessible_locally"]
    assert_equal "0325b36", repository["checkout_commit"][0, 7]
    assert_equal "https://github.com/JaredHarbison/the-federation-briefing", repository["repository_url"]
  end
end
