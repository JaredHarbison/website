module AskJared
  # An immutable, validated interpretation of one question. It is advisory for
  # answer selection, but never authorizes a factual claim.
  class QuestionDecision
    ATTRIBUTES = %i[primary candidates parts answer_shape compound unsupported_subrequests confidence planning_required planning_reasons resolution_mode].freeze
    attr_reader(*ATTRIBUTES)

    def self.from_resolution(resolution)
      data = resolution.respond_to?(:deep_symbolize_keys) ? resolution.deep_symbolize_keys : {}
      new(**ATTRIBUTES.to_h { |attribute| [ attribute, data[attribute] ] })
    end

    def initialize(primary:, candidates:, parts:, answer_shape:, compound:, unsupported_subrequests: [], confidence:, planning_required:, planning_reasons:, resolution_mode:)
      @primary = DecisionPolicy::INTENTS.include?(primary.to_s) ? primary.to_s : "unclassified"
      @candidates = Array(candidates).map(&:to_s).select { |value| DecisionPolicy::INTENTS.include?(value) }.uniq
      @candidates = [ @primary ] if @candidates.empty?
      @parts = Array(parts).first(4).map { |part| normalize_part(part) }
      @parts = [ normalize_part({}) ] if @parts.empty?
      @answer_shape = DecisionPolicy::ANSWER_SHAPES.include?(answer_shape.to_s) ? answer_shape.to_s : "insufficient"
      @compound = compound == true
      @unsupported_subrequests = Array(unsupported_subrequests).first(4).filter_map do |subrequest|
        value = subrequest.respond_to?(:deep_symbolize_keys) ? subrequest.deep_symbolize_keys : {}
        subject = value[:subject].to_s
        reason = value[:reason].to_s
        next unless DecisionPolicy::SUBJECTS.include?(subject) && %w[missing_evidence unsupported_quantification out_of_scope].include?(reason)

        { "subject" => subject, "reason" => reason }
      end
      @confidence = confidence.to_f.clamp(0.0, 1.0)
      @planning_required = planning_required == true
      @planning_reasons = Array(planning_reasons).map(&:to_s).uniq
      @resolution_mode = resolution_mode.to_s.presence || "unavailable"
    end

    def recognized?
      primary != "unclassified"
    end

    def compound?
      compound
    end

    def to_h
      {
        "primary" => primary, "candidates" => candidates, "parts" => parts,
        "answer_shape" => answer_shape, "compound" => compound, "unsupported_subrequests" => unsupported_subrequests, "confidence" => confidence,
        "planning_required" => planning_required, "planning_reasons" => planning_reasons,
        "resolution_mode" => resolution_mode
      }
    end

    private

    def normalize_part(part)
      value = part.respond_to?(:deep_symbolize_keys) ? part.deep_symbolize_keys : {}
      {
        "subject" => DecisionPolicy::SUBJECTS.include?(value[:subject].to_s) ? value[:subject].to_s : "unknown",
        "operation" => DecisionPolicy::OPERATIONS.include?(value[:operation].to_s) ? value[:operation].to_s : "describe",
        "dimensions" => Array(value[:dimensions]).map(&:to_s).select { |item| DecisionPolicy::DIMENSIONS.include?(item) }.uniq,
        "scope" => DecisionPolicy::SCOPES.include?(value[:scope].to_s) ? value[:scope].to_s : "unknown",
        "evidence_requirements" => Array(value[:evidence_requirements]).map(&:to_s).select { |item| DecisionPolicy::EVIDENCE_REQUIREMENTS.include?(item) }.uniq
      }
    end
  end
end
