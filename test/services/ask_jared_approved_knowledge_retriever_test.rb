require "test_helper"
require_relative "../../app/services/ask_jared/approved_knowledge_retriever"

class AskJaredApprovedKnowledgeRetrieverTest < ActiveSupport::TestCase
  Scope = Struct.new(:entries) { def to_a = entries }
  UnavailableEmbedding = Class.new do
    def call(*)
      raise AskJared::OpenAiEmbeddingProvider::ConfigurationError
    end
  end

  def entry(id, title, capabilities:, utility: "primary_recruiter_evidence", claim_kind: "demonstrated")
    KnowledgeEntry.new(
      id: id, title: title, short_body: title, body: title, entry_type: "project",
      source_reference: title.downcase.tr(" ", "-"),
      metadata: { "recruiter_evidence" => {
        "recruiter_utility" => utility,
        "claims" => [ { "text" => title, "kind" => claim_kind } ],
        "capability_map" => capabilities.index_with { |capability| { "strength" => "demonstrated", "evidence_kind" => "demonstrated", "role" => "primary" } }
      } }
    )
  end

  test "classifies recruiter paraphrases into deliberate intents" do
    retriever = AskJared::ApprovedKnowledgeRetriever.new(scope: Scope.new([]), embedding_provider: UnavailableEmbedding.new)

    {
      "What sort of engineer is Jared?" => "characterization",
      "Why would you interview Jared?" => "candidacy",
      "Tell me about his Rails background" => "rails",
      "What has he done with React?" => "react",
      "Could he work on a larger engineering team?" => "organization",
      "What are the hiring gaps?" => "risk",
      "Does he have professional TypeScript experience?" => "typescript",
      "How does he approach unfamiliar technology?" => "learning",
      "Tell me about a failure" => "failure",
      "How did he respond to feedback?" => "feedback",
      "How did he prioritize competing work?" => "prioritization",
      "Tell me about a technical conflict" => "disagreement",
      "What shows mentorship?" => "mentorship",
      "How did he handle ambiguity?" => "ambiguity",
      "What measurable impact did he have?" => "impact",
      "Has he handled a production incident?" => "production",
      "How does he communicate with stakeholders?" => "stakeholder"
    }.each { |question, intent| assert_equal intent, retriever.classified_intent(question), question }
  end

  test "ranks within the qualified product pool without a relevance floor" do
    entries = [
      entry(1, "Agenda", capabilities: [ "product judgment" ]),
      entry(2, "Prioritization", capabilities: [ "product judgment", "prioritization" ]),
      entry(3, "Simplification", capabilities: [ "product judgment" ]),
      entry(4, "Completion alignment", capabilities: [ "product judgment" ]),
      entry(5, "Operations", capabilities: [ "technical ownership" ])
    ]
    retriever = AskJared::ApprovedKnowledgeRetriever.new(scope: Scope.new(entries), embedding_provider: UnavailableEmbedding.new)

    results = retriever.call("Tell me about another example.", intent: "product", limit: 4)

    assert_equal 2, results.first.id
    assert_equal [ 1, 2, 3, 4 ], results.map(&:id).sort
    assert_equal "lexical-qualified", retriever.last_trace[:mode]
    assert_equal results.map(&:id), retriever.last_trace[:selected]
  end

  test "keeps boundaries out of ordinary capability pools while retaining them for risks" do
    demonstrated = entry(1, "React work", capabilities: [ "react" ])
    boundary = entry(2, "TypeScript boundary", capabilities: [ "typescript" ], claim_kind: "boundary")
    scope = Scope.new([ demonstrated, boundary ])
    retriever = AskJared::ApprovedKnowledgeRetriever.new(scope: scope, embedding_provider: UnavailableEmbedding.new)

    assert_equal [ demonstrated.id ], retriever.call("What is Jared's React experience?", intent: "react").map(&:id)
    assert_equal [ boundary.id ], retriever.call("What is the hiring risk?", intent: "risk").map(&:id)
  end

  test "excludes archive-only evidence from fallback retrieval" do
    active = entry(1, "Active Rails project", capabilities: [ "rails" ])
    archive = entry(2, "Archived Rails project", capabilities: [ "rails" ], utility: "archive_only")
    retriever = AskJared::ApprovedKnowledgeRetriever.new(scope: Scope.new([ active, archive ]), embedding_provider: UnavailableEmbedding.new)

    assert_equal [ active.id ], retriever.call("A question without a recognized intent").map(&:id)
  end
end
