require "digest"
require "json"

module AskJared
  class AnecdoteImporter
    IMPORT_FIELDS = %i[title body short_body entry_type confidence source_url public_url metadata].freeze

    def initialize(store:, source_type: "anecdote")
      @store = store
      @source_type = source_type
    end

    def sync(records)
      records.map { |record| sync_one(record) }
    end

    private

    attr_reader :store, :source_type

    def sync_one(record)
      source_reference = record.fetch("anecdote_id") { record.fetch(:anecdote_id) }.to_s
      source_evidence = record.fetch("source_evidence") { record.fetch(:source_evidence) }
      fingerprint = fingerprint_for(source_evidence)
      existing = store.find_by_source_reference(source_reference)

      return create_entry(record, source_reference, fingerprint) unless existing

      changed = existing.source_fingerprint != fingerprint
      update_import_fields(existing, record, source_reference, fingerprint)
      existing.approval_status = "needs_review" if changed && existing.approval_status == "approved"
      existing
    end

    def create_entry(record, source_reference, fingerprint)
      entry = KnowledgeEntry.new
      update_import_fields(entry, record, source_reference, fingerprint)
      entry.approval_status = "candidate"
      entry.visibility = "private"
      store.save(entry)
      entry
    end

    def update_import_fields(entry, record, source_reference, fingerprint)
      IMPORT_FIELDS.each do |field|
        entry.public_send("#{field}=", record[field.to_s] || record[field]) if record.key?(field.to_s) || record.key?(field)
      end
      entry.source_type = source_type
      entry.source_reference = source_reference
      entry.source_fingerprint = fingerprint
      entry.metadata = (entry.metadata || {}).merge("anecdote_id" => source_reference)
    end

    def fingerprint_for(value)
      canonical = JSON.generate(canonicalize(value))
      Digest::SHA256.hexdigest(canonical)
    end

    def canonicalize(value)
      case value
      when Hash
        value.keys.map(&:to_s).sort.to_h { |key| [ key, canonicalize(value[key] || value[key.to_sym]) ] }
      when Array then value.map { |item| canonicalize(item) }
      else value
      end
    end
  end
end
