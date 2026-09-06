require "yaml"

module AskJared
  class CandidateContext
    VERSION = "candidate-context-v1"
    PATH = Rails.root.join("config/ask_jared_candidate_context.yml")

    def initialize(path: PATH)
      document = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
      @records = document.fetch("records").map(&:stringify_keys).select { |record| approved?(record) }.freeze
    end

    def active?
      ENV.fetch("ASK_JARED_CANDIDATE_CONTEXT", "0") == "1"
    end

    def records
      @records
    end

    def for(intent, question:)
      keys = [ "intent.#{intent}", "voice.recruiter_natural", "voice.breadth", "continuity.follow_up" ]
      keys += [ "boundary.large_engineering_team" ] if intent == "organization"
      keys += [ "boundary.typescript" ] if intent == "typescript"
      keys += [ "story.#{story_key_for(intent)}" ] if story_key_for(intent)
      keys += [ "positioning.engineering_identity", "positioning.product_engineer", "positioning.backend_rails_foundation", "positioning.full_stack_trajectory" ] if %w[characterization candidacy].include?(intent.to_s)
      keys += [ "boundary.large_engineering_team", "boundary.typescript" ] if question.match?(/gap|weakness|risk|worry/i)
      records.select { |record| keys.include?(record["key"]) }.uniq { |record| record["key"] }
    end

    def context_keys(records)
      Array(records).map { |record| record.fetch("key") }
    end

    private

    # v1 predates the explicit approval field. Its version-controlled records are treated as
    # approved legacy planning data; v2 records must carry approval_status: approved.
    def approved?(record)
      record.fetch("approval_status", "approved") == "approved" && record.fetch("privacy_classification", "private") == "private"
    end

    def story_key_for(intent)
      {
        "product" => "product_judgment_primary", "characterization" => "product_judgment_primary",
        "candidacy" => "technical_ownership_primary", "ambiguity" => "ambiguity_primary",
        "disagreement" => "disagreement_primary", "collaboration" => "collaboration_primary",
        "impact" => "impact_primary", "production" => "production_primary",
        "failure" => "failure_primary", "mentorship" => "mentorship_primary",
        "prioritization" => "prioritization_primary", "stakeholder" => "product_judgment_primary"
      }[intent]
    end
  end
end
