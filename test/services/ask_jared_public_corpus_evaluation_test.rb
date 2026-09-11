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
  end

  test "answers only from retrieved public documents" do
    document = Document.new("writing:rails", "Rails", "/writing/rails", "writing", "Published body", "Summary", { "tags" => [ "Rails" ], "category" => "Architecture" })
    provider = Class.new do
      attr_reader :request
      def structured_call(**request)
        @request = request
        { "result" => { "status" => "answer", "answer" => "Published answer.", "source_ids" => [ "writing:rails", "private:never" ] }, "__telemetry" => { "input_tokens" => 12 } }
      end
    end.new
    answerer = AskJared::PublicCorpusAnswerer.new(provider: provider, retriever: Struct.new(:documents) { def call(*) = documents }.new([ document ]))

    response = answerer.call(question: "What has Jared written about Rails?")

    assert_equal [ "writing:rails" ], response["evidence_ids"]
    refute_includes provider.request.fetch(:user_content), "private:never"
    assert_equal 12, response.dig("evaluation", "input_tokens")
    assert_includes provider.request.fetch(:system_prompt), "candidate-level synthesis in 80–140 words"
    assert_includes provider.request.fetch(:system_prompt), "Source ordering must not"
    assert_includes provider.request.fetch(:system_prompt), "documented engineering-context behaviors"
    assert_includes provider.request.fetch(:system_prompt), "never as engineering-management experience"
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
