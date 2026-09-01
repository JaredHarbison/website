require "test_helper"
require_relative "../../app/services/ask_jared/knowledge_entry"

class AskJaredKnowledgeEvaluationTest < ActiveSupport::TestCase
  Scope = Struct.new(:entries) { def to_a = entries }

  INTENT_CASES = {
    "What evidence suggests Jared could succeed on a larger engineering team?" => "career:jcrew-store-director-columbus-circle",
    "Has Jared ever managed large teams?" => "career:jcrew-store-director-columbus-circle",
    "What experience does Jared have working across organizational levels?" => "career:jcrew-store-director-pentagon-city",
    "What's the biggest hiring risk with Jared?" => "fact:engineering-experience-boundaries",
    "Where does Jared have less experience?" => "fact:engineering-experience-boundaries",
    "Give me one example of measurable impact." => "career:jcrew-store-director-columbus-circle",
    "Has Jared produced measurable business results?" => "career:urbn-senior-merchandiser",
    "What demonstrates Jared's product judgment?" => "story:dogly-agenda-product-direction",
    "Tell me about a time Jared challenged a proposed product direction." => "story:dogly-agenda-product-direction",
    "How experienced is Jared with TypeScript?" => "fact:engineering-experience-boundaries"
  }.freeze

  setup do
    KnowledgeEntry.delete_all
    AskJared::CandidateKnowledgeInventory.new.sync!
    AskJared::FinalizeRecruiterKnowledge.new.call(generate_embeddings: false)
  end

  test "semantic-intent equivalents retrieve recruiter-safe evidence" do
    entries = AskJared::CandidateKnowledgeInventory.new.records.each_with_index.map do |record, index|
      AskJared::KnowledgeEntry.new(record.merge("id" => index + 1, "source_reference" => record.fetch("anecdote_id")))
    end
    retriever = AskJared::ApprovedKnowledgeRetriever.new(scope: Scope.new(entries), embedding_provider: Object.new)

    INTENT_CASES.each do |question, reference|
      results = retriever.send(:lexical_results, question, 6)

      assert_includes results.map(&:source_reference), reference, question
    end
  end

  test "boundary evidence preserves the engineering and retail distinction" do
    records = AskJared::CandidateKnowledgeInventory.new.records.map { |record| AskJared::KnowledgeEntry.new(record.merge("source_reference" => record.fetch("anecdote_id"))) }
    boundary = records.find { |entry| entry.source_reference == "fact:engineering-experience-boundaries" }
    retail = records.find { |entry| entry.source_reference == "career:jcrew-store-director-columbus-circle" }

    assert_includes boundary.metadata.dig("recruiter_evidence", "limitations"), "Large engineering-team experience is not established"
    assert_includes boundary.metadata.dig("recruiter_evidence", "limitations"), "TypeScript"
    assert_includes retail.metadata.dig("recruiter_evidence", "safe_attribution"), "engineering people management"
  end

  test "production-shaped retrieval trace shows approved candidates and synthesis context" do
    captured = []
    provider = Object.new
    provider.define_singleton_method(:call) do |question:, context:|
      captured << [ question, context.map(&:source_reference) ]
      { "status" => "answer", "answer" => "Grounded.", "evidence_ids" => context.map { |entry| entry.id.to_s }, "source_urls" => [] }
    end
    retriever = AskJared::ApprovedKnowledgeRetriever.new
    service = AskJared::QuestionService.new(retriever: retriever, provider: provider)

    [
      [ "What evidence suggests Jared could succeed on a larger engineering team?", %w[fact:engineering-experience-boundaries career:jcrew-store-director-columbus-circle] ],
      [ "What are the biggest gaps or risks I should consider before hiring Jared?", [ "fact:engineering-experience-boundaries" ] ],
      [ "What demonstrates Jared's product judgment?", [ "story:dogly-agenda-product-direction" ] ],
      [ "How experienced is Jared with TypeScript?", [ "fact:engineering-experience-boundaries" ] ]
    ].each do |question, expected_references|
      entries = retriever.call(question)
      trace = retriever.last_trace
      expected_references.each do |reference|
        entry = KnowledgeEntry.find_by!(source_reference: reference)
        assert_equal "approved", entry.approval_status
        assert_equal "recruiter_visible", entry.visibility
        assert_includes trace[:considered].map { |item| item[:source_reference] }, reference
        assert_includes entries.map(&:source_reference), reference, question
      end
      service.call(raw_token: nil, question: question, session_id: "qa-session", request_id: "qa-#{question.hash}", admin_preview: true)
      assert_equal entries.map(&:source_reference), captured.last[1]
    end
  end
end
