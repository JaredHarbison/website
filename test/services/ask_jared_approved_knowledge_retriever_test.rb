require "test_helper"
require_relative "../../app/services/ask_jared/approved_knowledge_retriever"

class AskJaredApprovedKnowledgeRetrieverTest < ActiveSupport::TestCase
  RankedEntry = Struct.new(:id, :title, :short_body, :entry_type, :metadata, :distance) do
    def attributes
      { "retrieval_distance" => distance }
    end
  end

  def retriever
    AskJared::ApprovedKnowledgeRetriever.new(scope: KnowledgeEntry.none, embedding_provider: Object.new)
  end

  def entry(id, title, entry_type:, evidence: {})
    KnowledgeEntry.new(id: id, title: title, short_body: title, entry_type: entry_type,
                       metadata: { "recruiter_evidence" => evidence })
  end

  def ranked_entry(id, title, entry_type:, distance:, evidence: {})
    RankedEntry.new(id, title, title, entry_type, { "recruiter_evidence" => evidence }, distance)
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

  test "classifies synthesis signals as broad but leaves named questions narrow" do
    assert retriever.send(:broad_query?, "What technologies and systems has Jared demonstrated?")
    assert retriever.send(:broad_query?, "Tell me about work that was unfinished or unmeasured")
    assert_not retriever.send(:broad_query?, "How much revenue did Shopify generate?")
    assert_not retriever.send(:broad_query?, "Has Jared dealt with concurrency or locking problems?")
  end

  test "diversifies broad candidates toward product learning and independent evidence" do
    product = ranked_entry(1, "Product learning", entry_type: "product_story", distance: 0.30, evidence: { "product_learning" => "The next improvement was member value." })
    operational = ranked_entry(2, "Operational work", entry_type: "incident_story", distance: 0.31, evidence: { "limitations" => "No measured outcome." })
    independent = ranked_entry(3, "Independent prototype", entry_type: "engineering_story", distance: 0.40, evidence: { "relationship" => "Independent project outside Dogly", "status" => "Prototype" })

    selected = retriever.send(:diversified_results, [ operational, product, independent ], 3, "What examples are unfinished or unmeasured?")

    assert_equal [ 1, 3, 2 ], selected.map(&:id)
  end

  test "does not force an irrelevant candidate past the relevance floor" do
    relevant = ranked_entry(1, "Relevant", entry_type: "engineering_story", distance: 0.30, evidence: { "limitations" => "No measured outcome." })
    irrelevant = ranked_entry(2, "Unrelated", entry_type: "project", distance: 0.90, evidence: { "relationship" => "Independent project outside Dogly" })

    selected = retriever.send(:diversified_results, [ relevant, irrelevant ], 2, "What work was unmeasured?")

    assert_equal [ 1 ], selected.map(&:id)
  end

  test "keeps broad selection capped and deterministic on ties" do
    entries = 6.times.map do |id|
      ranked_entry(id + 1, "Entry #{id + 1}", entry_type: "engineering_story", distance: 0.30)
    end

    selected = retriever.send(:diversified_results, entries, 5, "What examples demonstrate Jared's work?")

    assert_equal [ 1, 2, 3, 4, 5 ], selected.map(&:id)
    assert_equal 5, selected.length
  end
end
