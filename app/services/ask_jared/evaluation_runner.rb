require "json"
require "timeout"
require "fileutils"

module AskJared
  class EvaluationRunner
    DEFAULT_TIMEOUT_SECONDS = 45
    DEFAULT_RETRIES = 1
    DEFAULT_RETRY_DELAY_SECONDS = 1

    def initialize(checkpoint_path:, timeout_seconds: DEFAULT_TIMEOUT_SECONDS, retries: DEFAULT_RETRIES, retry_delay_seconds: DEFAULT_RETRY_DELAY_SECONDS, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, sleeper: ->(seconds) { sleep(seconds) })
      @checkpoint_path = checkpoint_path.to_s
      @timeout_seconds = timeout_seconds
      @retries = retries
      @retry_delay_seconds = retry_delay_seconds
      @clock = clock
      @sleeper = sleeper
    end

    def run(cases:, model:, architecture:, &operation)
      raise ArgumentError, "operation is required" unless operation

      checkpoint = load_checkpoint
      results = checkpoint.fetch("results", {})
      cases.each_with_index do |evaluation_case, index|
        key = key_for(model: model, architecture: architecture, evaluation_case: evaluation_case)
        existing = results[key]
        if resumable?(existing, model: model, architecture: architecture)
          progress(index: index, total: cases.length, key: key, status: "resumed")
          next
        end

        progress(index: index, total: cases.length, key: key, status: "started")
        result = execute(evaluation_case, model: model, architecture: architecture, &operation)
        results[key] = result.merge(
          "case_id" => evaluation_case.fetch("id"),
          "model" => model,
          "architecture" => architecture,
          "recorded_at" => Time.current.iso8601
        )
        checkpoint["results"] = results
        checkpoint["updated_at"] = Time.current.iso8601
        flush_checkpoint(checkpoint)
        progress(index: index, total: cases.length, key: key, status: result.fetch("status"))
      end
      checkpoint
    end

    private

    def execute(evaluation_case, model:, architecture:)
      attempts = 0
      started = @clock.call
      loop do
        attempts += 1
        begin
          response = nil
          Timeout.timeout(@timeout_seconds) do
            response = yield(evaluation_case, model: model, architecture: architecture)
          end
          return {
            "status" => "completed",
            "answer_status" => response["status"],
            "answer" => response["answer"],
            "evidence_ids" => Array(response["evidence_ids"]),
            "validation" => response.dig("evaluation", "validation") || response["validation"] || "passed",
            "reported_model" => response.dig("evaluation", "model") || response["model"],
            "input_tokens" => response.dig("evaluation", "input_tokens"),
            "output_tokens" => response.dig("evaluation", "output_tokens"),
            "estimated_cost_cents" => response.dig("evaluation", "estimated_cost_cents"),
            "latency_ms" => ((@clock.call - started) * 1000).round,
            "attempts" => attempts
          }
        rescue Timeout::Error => error
          return terminal_failure("provider_timeout", error, attempts, started, model) if attempts > @retries
        rescue StandardError => error
          status = if defined?(AskJared::OpenAiProvider::ProviderError) && error.is_a?(AskJared::OpenAiProvider::ProviderError)
            "provider_error"
          elsif defined?(AskJared::EvidenceIntegrity::Violation) && error.is_a?(AskJared::EvidenceIntegrity::Violation)
            "validation_error"
          else
            "evaluation_error"
          end
          return terminal_failure(status, error, attempts, started, model) if attempts > @retries
        end
        @sleeper.call(@retry_delay_seconds * attempts)
      end
    end

    def terminal_failure(status, error, attempts, started, model)
      {
        "status" => status,
        "error_class" => error.class.name,
        "error_message" => error.message.to_s.gsub(/Bearer\s+\S+/i, "Bearer [redacted]").first(500),
        "validation" => "not_run",
        "reported_model" => model,
        "latency_ms" => ((@clock.call - started) * 1000).round,
        "attempts" => attempts
      }
    end

    def key_for(model:, architecture:, evaluation_case:)
      "#{architecture}:#{model}:#{evaluation_case.fetch("id")}"
    end

    def resumable?(result, model:, architecture:)
      result.is_a?(Hash) && result["model"] == model && result["architecture"] == architecture && (result["status"].to_s != "completed" || result["reported_model"].to_s == model) && result["status"].to_s.in?(%w[completed provider_timeout provider_error structured_response_error validation_error])
    end

    def load_checkpoint
      return { "version" => 1, "results" => {} } unless File.file?(@checkpoint_path)

      JSON.parse(File.read(@checkpoint_path))
    rescue JSON::ParserError
      { "version" => 1, "results" => {} }
    end

    def flush_checkpoint(checkpoint)
      directory = File.dirname(@checkpoint_path)
      FileUtils.mkdir_p(directory)
      temporary = "#{@checkpoint_path}.tmp"
      File.write(temporary, JSON.pretty_generate(checkpoint))
      File.rename(temporary, @checkpoint_path)
    end

    def progress(index:, total:, key:, status:)
      $stdout.puts(JSON.generate({ "progress" => "#{index + 1}/#{total}", "case" => key, "status" => status }))
      $stdout.flush
    end
  end
end
