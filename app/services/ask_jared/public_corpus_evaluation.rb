require "yaml"

module AskJared
  class PublicCorpusEvaluation
    FIXTURE_PATH = Rails.root.join("test/fixtures/ask_jared_public_corpus_evaluation.yml")

    def initialize(answerer:, rules_answerer: nil, runner: nil)
      @answerer = answerer
      @rules_answerer = rules_answerer
      @runner = runner
    end

    def run(checkpoint_path:, model: ModelConfig::CANONICAL_MODEL)
      runner = @runner || EvaluationRunner.new(checkpoint_path: checkpoint_path)
      runner.run(cases: YAML.load_file(FIXTURE_PATH), model: model, architecture: "public-corpus-only") do |evaluation_case, **|
        @answerer.call(question: evaluation_case.fetch("question"))
      end
    end

    # Both arms share the frozen cases, selected model, and checkpoint. The
    # architecture label keeps resumable results distinct.
    def run_pair(checkpoint_path:, model: ModelConfig::CANONICAL_MODEL)
      raise ArgumentError, "rules_answerer is required for a paired Rules evaluation" unless @rules_answerer

      runner = @runner || EvaluationRunner.new(checkpoint_path: checkpoint_path)
      cases = YAML.load_file(FIXTURE_PATH)
      run_arm(runner: runner, cases: cases, model: model, architecture: "public-corpus-only", answerer: @answerer)
      run_arm(runner: runner, cases: cases, model: model, architecture: "public-corpus-plus-rules", answerer: @rules_answerer)
    end

    private

    def run_arm(runner:, cases:, model:, architecture:, answerer:)
      runner.run(cases: cases, model: model, architecture: architecture) do |evaluation_case, **|
        answerer.call(question: evaluation_case.fetch("question"))
      end
    end
  end
end
