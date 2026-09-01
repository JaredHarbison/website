require "test_helper"
require_relative "../../app/services/ask_jared/approved_knowledge_retriever"

class AskJaredApprovedKnowledgeRetrieverTest < ActiveSupport::TestCase
  def retriever
    AskJared::ApprovedKnowledgeRetriever.new(scope: KnowledgeEntry.none, embedding_provider: Object.new)
  end

  def entry(id, title, entry_type:, evidence: {})
    KnowledgeEntry.new(id: id, title: title, short_body: title, entry_type: entry_type,
                       metadata: { "recruiter_evidence" => evidence })
  end

  test "independent-project intent prefers established independent projects" do
    question = "What has Jared built outside the company?"
    independent = entry(1, "Independent Briefing", entry_type: "engineering_story", evidence: { "relationship" => "Independent project outside Dogly" })
    dogly = entry(2, "Dogly Project", entry_type: "project", evidence: { "relationship" => "Dogly product" })

    assert_operator retriever.send(:compatibility_boost, question, independent), :>, retriever.send(:compatibility_boost, question, dogly)
  end

  test "built-with-limited-outcome intent prefers limited project evidence over a metric" do
    question = "What did Jared build that had an unproven outcome?"
    project = entry(1, "Prototype", entry_type: "project", evidence: { "limitations" => "Outcome measurement is unavailable.", "status" => "Prototype" })
    metric = entry(2, "Subscription comparison", entry_type: "metric", evidence: { "limitations" => "Methodology is unknown." })

    assert_operator retriever.send(:compatibility_boost, question, project), :>, retriever.send(:compatibility_boost, question, metric)
  end

  test "named single-story intent prefers the named story without blocking comparisons" do
    retriever_instance = retriever
    shopify = entry(1, "Dogly Shopify Integration", entry_type: "integration_story", evidence: { "relationship" => "Dogly external-platform integration" })
    fridge = entry(2, "Fridge No More Bulk Ordering", entry_type: "product_story", evidence: { "relationship" => "Dogly operational commerce workflow" })

    assert_operator retriever_instance.send(:compatibility_boost, "How much revenue did Shopify generate?", shopify), :>, retriever_instance.send(:compatibility_boost, "How much revenue did Shopify generate?", fridge)
    assert_operator retriever_instance.send(:compatibility_boost, "Compare Shopify and Fridge No More", shopify), :>, 0
    assert_operator retriever_instance.send(:compatibility_boost, "Compare Shopify and Fridge No More", fridge), :>, 0
  end
end
