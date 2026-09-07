require "test_helper"
require "tmpdir"
require_relative "../../app/services/ask_jared/evaluation_runner"
require_relative "../../app/services/ask_jared/open_ai_provider"
require_relative "../../app/services/ask_jared/evidence_integrity"

class AskJaredEvaluationRunnerTest < ActiveSupport::TestCase
  def evaluation_case(id)
    { "id" => id, "question" => "Question #{id}" }
  end

  def with_runner(**options)
    Dir.mktmpdir do |directory|
      yield AskJared::EvaluationRunner.new(checkpoint_path: File.join(directory, "checkpoint.json"), **options), File.join(directory, "checkpoint.json")
    end
  end

  test "persists normal responses with identity and telemetry" do
    with_runner do |runner, path|
      runner.run(cases: [ evaluation_case("Q1") ], model: "gpt-5.6-terra", architecture: "candidate-context-v2") do |_item, model:, architecture:|
        { "status" => "answer", "answer" => "Grounded.", "evidence_ids" => [ "1" ], "evaluation" => { "model" => model, "architecture" => architecture, "validation" => "passed", "input_tokens" => 10, "output_tokens" => 4 } }
      end

      result = JSON.parse(File.read(path)).fetch("results").values.first
      assert_equal "completed", result["status"]
      assert_equal "gpt-5.6-terra", result["model"]
      assert_equal "candidate-context-v2", result["architecture"]
      assert_equal [ "1" ], result["evidence_ids"]
      assert_equal 10, result["input_tokens"]
    end
  end

  test "bounds retries, records timeout, and continues to the next case" do
    calls = 0
    with_runner(timeout_seconds: 0.01, retries: 1, retry_delay_seconds: 0, sleeper: ->(_seconds) { }) do |runner, path|
      runner.run(cases: [ evaluation_case("slow"), evaluation_case("next") ], model: "gpt-5.6-sol", architecture: "candidate-context-v2") do |item, **|
        calls += 1
        if item["id"] == "slow"
          sleep 0.05
        else
          { "status" => "insufficient_information", "answer" => "Not enough information.", "evidence_ids" => [] }
        end
      end

      results = JSON.parse(File.read(path)).fetch("results").values
      assert_equal 3, calls
      assert_includes results.map { |result| result["status"] }, "provider_timeout"
      assert_includes results.map { |result| result["status"] }, "completed"
    end
  end

  test "resumes valid checkpoints and does not mix model arms" do
    calls = 0
    with_runner do |runner, path|
      runner.run(cases: [ evaluation_case("Q1") ], model: "gpt-5.6-terra", architecture: "candidate-context-v2") do |*, **|
        calls += 1
        { "status" => "answer", "answer" => "Done.", "evidence_ids" => [], "evaluation" => { "model" => "gpt-5.6-terra" } }
      end
      runner.run(cases: [ evaluation_case("Q1") ], model: "gpt-5.6-terra", architecture: "candidate-context-v2") { calls += 1; raise "should be skipped" }
      runner.run(cases: [ evaluation_case("Q1") ], model: "gpt-5.6-sol", architecture: "candidate-context-v2") do
        calls += 1
        { "status" => "answer", "answer" => "Sol.", "evidence_ids" => [] }
      end

      assert_equal 2, calls
      results = JSON.parse(File.read(path)).fetch("results")
      assert_equal 2, results.length
      assert results.keys.any? { |key| key.include?("gpt-5.6-terra") }
      assert results.keys.any? { |key| key.include?("gpt-5.6-sol") }
    end
  end

  test "records provider and validation failures instead of hanging" do
    with_runner(retries: 0) do |runner, path|
      runner.run(cases: [ evaluation_case("provider"), evaluation_case("validation") ], model: "gpt-5.6-terra", architecture: "candidate-context-v2") do |item, **|
        raise AskJared::OpenAiProvider::ProviderError, "malformed response" if item["id"] == "provider"
        raise AskJared::EvidenceIntegrity::Violation, "unsupported claim"
      end

      statuses = JSON.parse(File.read(path)).fetch("results").values.map { |result| result["status"] }
      assert_equal [ "provider_error", "validation_error" ], statuses
    end
  end

  test "keeps completed checkpoints when a later case interrupts the process" do
    with_runner do |runner, path|
      assert_raises(Interrupt) do
        runner.run(cases: [ evaluation_case("done"), evaluation_case("interrupt") ], model: "gpt-5.6-terra", architecture: "candidate-context-v2") do |item, **|
          raise Interrupt if item["id"] == "interrupt"
          { "status" => "answer", "answer" => "Done.", "evidence_ids" => [] }
        end
      end

      assert_equal [ "done" ], JSON.parse(File.read(path)).fetch("results").values.map { |result| result["case_id"] }
    end
  end
end
