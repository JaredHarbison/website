require "json"

module AskJared
  class IntentResolutionService
    INTENTS = DecisionPolicy::INTENTS
    SUBJECTS = DecisionPolicy::SUBJECTS
    OPERATIONS = DecisionPolicy::OPERATIONS
    DIMENSIONS = DecisionPolicy::DIMENSIONS
    SCOPES = DecisionPolicy::SCOPES
    ANSWER_SHAPES = DecisionPolicy::ANSWER_SHAPES
    EVIDENCE_REQUIREMENTS = DecisionPolicy::EVIDENCE_REQUIREMENTS

    SCHEMA = {
      name: "ask_jared_intent_resolution",
      schema: {
        type: "object",
        properties: {
          "primary_intent" => { type: "string", enum: INTENTS },
          "intent_candidates" => { type: "array", items: { type: "string", enum: INTENTS }, minItems: 1, maxItems: 4 },
          "question_parts" => { type: "array", minItems: 1, maxItems: 4, items: {
            type: "object",
            properties: {
              "subject" => { type: "string", enum: SUBJECTS },
              "operation" => { type: "string", enum: OPERATIONS },
              "dimensions" => { type: "array", items: { type: "string", enum: DIMENSIONS }, maxItems: 6 },
              "scope" => { type: "string", enum: SCOPES },
              "evidence_requirements" => { type: "array", items: { type: "string", enum: EVIDENCE_REQUIREMENTS }, maxItems: 6 }
            },
            required: %w[subject operation dimensions scope evidence_requirements],
            additionalProperties: false
          } },
          "answer_shape" => { type: "string", enum: ANSWER_SHAPES },
          "compound" => { type: "boolean" },
          "unsupported_subrequests" => { type: "array", maxItems: 4, items: {
            type: "object", properties: {
              "subject" => { type: "string", enum: SUBJECTS },
              "reason" => { type: "string", enum: %w[missing_evidence unsupported_quantification out_of_scope] }
            }, required: %w[subject reason], additionalProperties: false
          } },
          "confidence" => { type: "number", minimum: 0, maximum: 1 }
        },
        required: %w[primary_intent intent_candidates question_parts answer_shape compound unsupported_subrequests confidence],
        additionalProperties: false
      }
    }.freeze

    def initialize(provider:, context: CandidateContext.new)
      @provider = provider
      @context = context
    end

    def call(question:, prior_context: {})
      return fallback unless @provider.respond_to?(:structured_call)

      response = @provider.structured_call(
        system_prompt: system_prompt,
        user_content: JSON.generate({
          question: question.to_s.strip,
          prior_context: prior_context.slice("question", "intent", "evidence_ids", "example_evidence_ids"),
          ontology: ontology
        }),
        schema: SCHEMA
      )
      normalize(response.fetch("result")).merge("telemetry" => response["__telemetry"] || {})
    rescue OpenAiProvider::ConfigurationError, OpenAiProvider::ProviderError, KeyError, TypeError, JSON::ParserError => error
      Rails.logger.warn("Ask Jared intent resolution unavailable: #{error.class}: #{error.message}")
      fallback
    end

    private

    def ontology
      @context.records.first(32).map do |record|
        { "key" => record["key"], "purpose" => record["purpose"], "intents" => record["intents"], "guidance" => record["guidance"] }
      end
    end

    def normalize(result)
      primary = result.fetch("primary_intent").to_s
      candidates = Array(result.fetch("intent_candidates")).map(&:to_s).select { |intent| INTENTS.include?(intent) }.uniq
      candidates = [ primary ] if candidates.empty? && INTENTS.include?(primary)
      parts = Array(result.fetch("question_parts")).map do |part|
        {
          "subject" => SUBJECTS.include?(part["subject"].to_s) ? part["subject"].to_s : "unknown",
          "operation" => OPERATIONS.include?(part["operation"].to_s) ? part["operation"].to_s : "describe",
          "dimensions" => Array(part["dimensions"]).select { |value| DIMENSIONS.include?(value.to_s) },
          "scope" => SCOPES.include?(part["scope"].to_s) ? part["scope"].to_s : "unknown",
          "evidence_requirements" => Array(part["evidence_requirements"]).select { |value| EVIDENCE_REQUIREMENTS.include?(value.to_s) }
        }
      end
      {
        "primary" => INTENTS.include?(primary) ? primary : "unclassified",
        "candidates" => candidates.presence || [ "unclassified" ],
        "parts" => parts.presence || [ { "subject" => "unknown", "operation" => "describe", "dimensions" => [], "scope" => "unknown", "evidence_requirements" => [] } ],
        "answer_shape" => ANSWER_SHAPES.include?(result["answer_shape"].to_s) ? result["answer_shape"].to_s : "insufficient",
        "compound" => result["compound"] == true,
        "unsupported_subrequests" => Array(result["unsupported_subrequests"]),
        "confidence" => result["confidence"].to_f.clamp(0.0, 1.0),
        "planning_required" => true,
        "planning_reasons" => [ "model_intent_resolution" ] + (result["compound"] == true ? [ "compound_question" ] : [])
      }
    end

    def fallback
      {
        "primary" => "unclassified", "candidates" => [ "unclassified" ],
        "parts" => [ { "subject" => "unknown", "operation" => "describe", "dimensions" => [], "scope" => "unknown", "evidence_requirements" => [] } ],
        "answer_shape" => "insufficient", "compound" => false, "unsupported_subrequests" => [], "confidence" => 0.0,
        "planning_required" => false, "planning_reasons" => [ "intent_resolution_unavailable" ], "telemetry" => {}
      }
    end

    def system_prompt
      <<~PROMPT
        Resolve the recruiter question into a semantic answer contract. Do not answer the question and do not invent facts.
        Use only the allowed ontology values in the schema. Read the private guidance as interpretation policy, not recruiter evidence.
        Identify every independently answerable part. A question asking for a project and the candidate's role is compound.
        Treat words such as proud, best project, representative work, built, contributed, and personally responsible as signals for
        project_story, contribution, or ownership. Treat recruiter phrasing semantically rather than matching exact vocabulary.
        Preserve explicit employer, project, chronology, technology, and shipped-status constraints. Use unclassified only when no
        allowed family fits. Choose answer_shape=compound when parts require separate evidence or operations.
      PROMPT
    end
  end
end
