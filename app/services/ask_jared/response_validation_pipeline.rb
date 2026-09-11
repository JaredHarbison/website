module AskJared
  # Runs one validation pass and, when available, one bounded repair pass for
  # every answer realization path. Path-specific code may realize a response
  # differently, but evidence validation and failure semantics stay identical.
  class ResponseValidationPipeline
    Result = Data.define(:response, :failure_reason) do
      def valid?
        failure_reason.nil?
      end
    end

    REPAIR_ERRORS = [ ArgumentError, KeyError, TypeError, OpenAiProvider::ConfigurationError, OpenAiProvider::ProviderError ].freeze

    def call(response:, repair: nil, &validator)
      Result.new(validator.call(response), nil)
    rescue EvidenceIntegrity::Violation => initial_violation
      return Result.new(nil, initial_violation.violations.join("; ")) unless repair

      begin
        repaired = repair.call(response, initial_violation.violations)
        Result.new(validator.call(repaired), nil)
      rescue EvidenceIntegrity::Violation => repair_violation
        Result.new(nil, [ initial_violation.violations.join("; "), repair_violation.violations.join("; ") ].join("; "))
      rescue *REPAIR_ERRORS => error
        Result.new(nil, [ initial_violation.violations.join("; "), error.class.name ].join("; "))
      end
    rescue *REPAIR_ERRORS => error
      Result.new(nil, error.class.name)
    end
  end
end
