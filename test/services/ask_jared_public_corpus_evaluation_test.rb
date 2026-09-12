require "test_helper"
require "tmpdir"

class AskJaredPublicCorpusEvaluationTest < ActiveSupport::TestCase
  Document = AskJared::PublicCorpus::Document

  test "retrieves dynamically from published source metadata" do
    documents = [
      Document.new("writing:rails", "Rails reliability", "/writing/rails", "writing", "Webhook retries", "Reliability", { "tags" => [ "Rails", "Testing" ], "category" => "Architecture" }),
      Document.new("case_studies:design", "Product design", "/case-studies/design", "case_studies", "Design work", "Design", { "tags" => [ "Product Engineering" ], "technologies" => [ "React" ] })
    ]
    corpus = Struct.new(:documents).new(documents)

    selected = AskJared::PublicCorpusRetriever.new(corpus: corpus).call("What Rails reliability work has Jared done?", limit: 1)

    assert_equal [ "writing:rails" ], selected.map(&:id)
    trace = AskJared::PublicCorpusRetriever.new(corpus: corpus)
    trace.call("What Rails reliability work has Jared done?", limit: 1)
    assert_equal [ "writing:rails" ], trace.last_trace.fetch(:selected)
    assert_equal "public-corpus-lexical", trace.last_trace.fetch(:mode)
  end

  test "answers only from retrieved public documents" do
    document = Document.new("writing:rails", "Rails", "/writing/rails", "writing", "Published body", "Summary", { "tags" => [ "Rails" ], "category" => "Architecture" })
    provider = Class.new do
      attr_reader :request
      def structured_call(**request)
        @request = request
        { "result" => { "status" => "answer", "direct_answer" => "Published answer.", "supporting_example" => "", "qualification" => "", "source_ids" => [ "writing:rails", "private:never" ] }, "__telemetry" => { "input_tokens" => 12 } }
      end
    end.new
    answerer = AskJared::PublicCorpusAnswerer.new(provider: provider, retriever: Struct.new(:documents) { def call(*) = documents }.new([ document ]))

    response = answerer.call(question: "What has Jared written about Rails?")

    assert_equal [ "writing:rails" ], response["evidence_ids"]
    refute_includes provider.request.fetch(:user_content), "private:never"
    assert_nil JSON.parse(provider.request.fetch(:user_content)).fetch("decision")
    assert_equal 12, response.dig("evaluation", "input_tokens")
    assert_equal({}, response.dig("evaluation", "retrieval_trace"))
    assert_equal [ true ], response.dig("evaluation", "coverage").map { |part| part.fetch("covered") }
    assert_includes provider.request.fetch(:system_prompt), "candidate-level synthesis in 80–140 words"
    assert_includes provider.request.fetch(:system_prompt), "Source ordering must not"
    assert_includes provider.request.fetch(:system_prompt), "documented engineering-context behaviors"
    assert_includes provider.request.fetch(:system_prompt), "never as engineering-management experience"
    assert_includes provider.request.fetch(:system_prompt), "Never select a project as largest or most complex"
    assert_includes provider.request.fetch(:system_prompt), "direct boundary first"
  end

  test "retrieves separately for every structured question part" do
    document = Document.new("writing:scope", "Scope", "/writing/scope", "writing", "Published body", "Summary", {})
    retriever = Class.new do
      attr_reader :scopes
      def initialize(document) = (@document = document; @scopes = [])
      def call(_question, scope: nil)
        scopes << scope
        [ @document ]
      end
    end.new(document)
    provider = Class.new do
      def structured_call(**)
        { "result" => { "status" => "answer", "direct_answer" => "Grounded.", "supporting_example" => "", "qualification" => "", "source_ids" => [ "writing:scope" ] } }
      end
    end.new

    response = AskJared::PublicCorpusAnswerer.new(provider: provider, retriever: retriever).call(
      question: "What did Jared do outside Dogly and at Dogly?",
      decision: { "parts" => [ { "scope" => "non_dogly", "dimensions" => [ "ownership" ] }, { "scope" => "dogly", "dimensions" => [ "contribution" ] } ] }
    )

    assert_equal %w[non_dogly dogly], retriever.scopes
    assert_equal 2, response.dig("evaluation", "coverage").length
  end

  test "pins a clear follow-up to the prior public source" do
    prior = Document.new("case_studies:prior", "Prior", "/prior", "case_studies", "Prior body", "", {})
    other = Document.new("writing:other", "Other", "/other", "writing", "Other body", "", {})
    corpus = Struct.new(:documents) do
      def find(id) = documents.find { |document| document.id == id }
    end.new([ prior, other ])
    retriever = AskJared::PublicCorpusRetriever.new(corpus: corpus)
    provider = Class.new do
      def structured_call(**)
        { "result" => { "status" => "answer", "direct_answer" => "Prior detail.", "supporting_example" => "", "qualification" => "", "source_ids" => [ "case_studies:prior" ] } }
      end
    end.new

    response = AskJared::PublicCorpusAnswerer.new(provider: provider, retriever: retriever).call(
      question: "Tell me more.", decision: { "answer_shape" => "follow_up" }, prior_source_ids: [ "case_studies:prior" ]
    )

    assert_equal [ "case_studies:prior" ], response.fetch("evidence_ids")
    assert_equal "prior_referent", response.dig("evaluation", "coverage", 0, "scope")
  end

  test "runs the frozen evaluation fixture with the public-corpus architecture label" do
    calls = []
    answerer = Struct.new(:calls) do
      def call(question:)
        calls << question
        { "status" => "answer", "answer" => "Grounded.", "evidence_ids" => [ "writing:test" ] }
      end
    end.new(calls)
    Dir.mktmpdir do |directory|
      checkpoint = File.join(directory, "public-corpus.json")
      AskJared::PublicCorpusEvaluation.new(answerer: answerer).run(checkpoint_path: checkpoint, model: "test-model")
      results = JSON.parse(File.read(checkpoint)).fetch("results").values

      assert_equal 20, calls.length
      assert_equal [ "public-corpus-only" ], results.map { |result| result.fetch("architecture") }.uniq
    end
  end

  test "runs corpus-only and Rules arms against the same frozen battery" do
    baseline_calls = []
    rules_calls = []
    baseline = Struct.new(:calls) do
      def call(question:)
        calls << question
        { "status" => "answer", "answer" => "Corpus-only.", "evidence_ids" => [] }
      end
    end.new(baseline_calls)
    rules = Struct.new(:calls) do
      def call(question:)
        calls << question
        { "status" => "answer", "answer" => "Rules-qualified.", "evidence_ids" => [] }
      end
    end.new(rules_calls)

    Dir.mktmpdir do |directory|
      checkpoint = File.join(directory, "paired-public-corpus.json")
      AskJared::PublicCorpusEvaluation.new(answerer: baseline, rules_answerer: rules).run_pair(checkpoint_path: checkpoint, model: "test-model")
      results = JSON.parse(File.read(checkpoint)).fetch("results").values

      assert_equal 20, baseline_calls.length
      assert_equal baseline_calls, rules_calls
      assert_equal 40, results.length
      assert_equal %w[public-corpus-only public-corpus-plus-rules], results.map { |result| result.fetch("architecture") }.uniq.sort
    end
  end
end
