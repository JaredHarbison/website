require "yaml"

module AskJared
  class PublicCorpusEvaluation
    FIXTURE_PATH = Rails.root.join("test/fixtures/ask_jared_public_corpus_evaluation.yml")

    def initialize(answerer:, runner: nil)
      @answerer = answerer
      @runner = runner
    end

    def run(checkpoint_path:, model: ModelConfig::CANONICAL_MODEL)
      runner = @runner || EvaluationRunner.new(checkpoint_path: checkpoint_path)
      runner.run(cases: YAML.load_file(FIXTURE_PATH), model: model, architecture: "public-corpus-only") do |evaluation_case, **|
        @answerer.call(question: evaluation_case.fetch("question"))
      end
    end
  end
end
