require "yaml"

module AskJared
  class CandidateContext
    VERSION = "candidate-context-v1"
    VERSION_V2 = "candidate-context-v2"
    PATH = Rails.root.join("config/ask_jared_candidate_context.yml")
    PATH_V2 = Rails.root.join("config/ask_jared_candidate_context_v2.yml")

    def initialize(path: nil, version: VERSION, store: ::CandidateContextRecord)
      @version = version
      @records = if version == VERSION_V2 && path.nil?
        store.approved_for_planning.order(priority: :desc, stable_key: :asc).map { |record| database_record(record) }
      else
        document = YAML.safe_load(File.read(path || (version == VERSION_V2 ? PATH_V2 : PATH)), permitted_classes: [], aliases: false)
        document.fetch("records").map(&:stringify_keys).select { |record| approved?(record) }
      end.freeze
    end

    attr_reader :version

    def active?
      ENV.fetch("ASK_JARED_CANDIDATE_CONTEXT", "0") == "1"
    end

    def records
      @records
    end

    def for(intent, question:)
      return v2_for(intent, question: question) if @version == VERSION_V2

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

    def database_record(record)
      {
        "key" => record.stable_key, "category" => record.category, "purpose" => record.purpose,
        "guidance" => record.guidance, "source_references" => record.source_references,
        "affects" => record.affects, "intents" => record.intent_tags, "priority" => record.priority
      }
    end

    def v2_for(intent, question:)
      intent = intent.to_s
      terms = question.to_s.downcase.split(/\W+/).reject { |term| term.length < 4 }
      records.select do |record|
        tags = Array(record["intents"]).map(&:to_s)
        tags.include?("all") || tags.include?(intent) || terms.any? { |term| record["key"].to_s.downcase.include?(term) || record["guidance"].to_s.downcase.include?(term) }
      end.sort_by { |record| [ -record.fetch("priority", 0).to_i, record.fetch("key") ] }.first(14)
    end

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
