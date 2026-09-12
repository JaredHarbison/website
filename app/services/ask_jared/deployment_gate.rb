module AskJared
  class DeploymentGate
    CRITICAL_PROHIBITIONS = %w[wrong_employer_attribution invented_metric scope_violation].freeze

    def self.evaluate(results)
      rows = Array(results).select { |result| result.is_a?(Hash) }
      failures = []
      failures << "no evaluation results" if rows.empty?
      failures << "incomplete evaluation" if rows.any? { |row| row["status"] != "completed" }
      failures << "missing model telemetry" if rows.any? { |row| row["reported_model"].blank? }
      failures << "user-visible validation failure" if rows.any? { |row| row.dig("scorecard", "automatic", "user_visible_validation_failure") }
      failures << "unattributed answer" if rows.any? { |row| row.dig("scorecard", "automatic", "has_attributable_source") == false }
      { "passed" => failures.empty?, "failures" => failures, "result_count" => rows.length }
    end
  end
end
