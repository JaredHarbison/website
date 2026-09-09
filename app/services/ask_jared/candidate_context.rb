require "yaml"

module AskJared
  class CandidateContext
    VERSION = "candidate-context-v2"
    PATH = Rails.root.join("config/ask_jared_candidate_context_v2.yml")

    def initialize(path: nil, store: ::CandidateContextRecord)
      @version = VERSION
      @records = if path.nil?
        store.approved_for_planning.order(priority: :desc, stable_key: :asc).map { |record| database_record(record) }
      else
        document = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
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
      intent = intent.to_s
      terms = question.to_s.downcase.split(/\W+/).reject { |term| term.length < 4 }
      records.select do |record|
        tags = Array(record["intents"]).map(&:to_s)
        tags.include?("all") || tags.include?(intent) || terms.any? { |term| record["key"].to_s.downcase.include?(term) || record["guidance"].to_s.downcase.include?(term) }
      end.sort_by { |record| [ -record.fetch("priority", 0).to_i, record.fetch("key") ] }.first(14)
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

    def approved?(record)
      record.fetch("approval_status", "approved") == "approved" && record.fetch("privacy_classification", "private") == "private"
    end
  end
end
