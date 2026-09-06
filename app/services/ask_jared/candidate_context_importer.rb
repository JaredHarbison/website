require "yaml"

module AskJared
  class CandidateContextImporter
    REQUIRED_KEYS = %w[id category approval_status privacy_classification guidance].freeze

    def initialize(store: ::CandidateContextRecord)
      @store = store
    end

    def import(path:, corpus_version: nil)
      document = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false).stringify_keys
      version = corpus_version || document.fetch("version")
      records = document.fetch("records").map { |record| normalize(record.stringify_keys, version) }
      validate_records!(records)

      records.each do |record|
        existing = @store.find_or_initialize_by(stable_key: record.fetch(:stable_key))
        existing.assign_attributes(record)
        existing.save!
      end
      records
    end

    private

    def normalize(record, version)
      {
        stable_key: record.fetch("id"), corpus_version: version, category: record.fetch("category"),
        approval_status: record.fetch("approval_status"), privacy_classification: record.fetch("privacy_classification"),
        purpose: record["purpose"], guidance: record.fetch("guidance"),
        source_references: Array(record["source_references"]), provenance: record["provenance"] || {},
        affects: Array(record["affects"]), intent_tags: Array(record["intent_tags"] || record["intents"]),
        relationships: record["relationships"] || {}, priority: record.fetch("priority", 0),
        retired_at: record.fetch("approval_status") == "retired" ? Time.current : nil
      }
    end

    def validate_records!(records)
      records.each do |record|
        missing = REQUIRED_KEYS.reject { |key| record[key == "id" ? :stable_key : key.to_sym].present? }
        raise ArgumentError, "Candidate Context record missing #{missing.join(", ")}" if missing.any?
      end
      keys = records.map { |record| record.fetch(:stable_key) }
      raise ArgumentError, "Candidate Context record IDs must be unique" unless keys.uniq.length == keys.length
    end
  end
end
