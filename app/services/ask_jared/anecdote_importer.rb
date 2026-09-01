require "digest"
require "json"

module AskJared
  class AnecdoteImporter
    SHEET_COLUMNS = %w[
      anecdote_id source_project situation what_i_did technical_detail product_result
      metric_evidence competencies best_role_types jd_signals resume_visible source_link
      confidence safe_claims
    ].freeze
    IMPORT_FIELDS = %i[title body short_body entry_type confidence source_url public_url metadata].freeze

    def self.record_from_sheet_row(row)
      values = row.to_h.transform_keys(&:to_s)
      source = values.fetch("source_project").to_s.strip
      situation = values.fetch("situation").to_s.strip
      action = values.fetch("what_i_did").to_s.strip
      technical = values.fetch("technical_detail").to_s.strip
      result = values.fetch("product_result").to_s.strip
      evidence = values.fetch("metric_evidence").to_s.strip
      safe_claims = values.fetch("safe_claims").to_s.strip
      narrative = [
        [ "Situation", situation ], [ "Action", action ], [ "Technical detail", technical ],
        [ "Result", result ], [ "Evidence", evidence ]
      ].filter_map { |label, value| "#{label}: #{value}" if value.present? }.join("\n")

      {
        "anecdote_id" => values.fetch("anecdote_id").to_s.strip,
        "title" => source.presence || values.fetch("anecdote_id").to_s.strip,
        "body" => narrative,
        "short_body" => [ situation, action, result ].compact_blank.join(" ").truncate(500),
        "entry_type" => entry_type_for(values),
        "confidence" => values.fetch("confidence").to_s.strip,
        "source_url" => values.fetch("source_link").to_s.strip.presence,
        "public_url" => nil,
        "metadata" => values.slice(
          "anecdote_id", "source_project", "situation", "what_i_did", "technical_detail",
          "product_result", "metric_evidence", "competencies", "best_role_types", "jd_signals",
          "resume_visible", "source_link", "confidence", "safe_claims"
        ),
        "source_evidence" => values
      }
    end

    def initialize(store:, source_type: "anecdote", entry_class: nil)
      @store = store
      @source_type = source_type
      @entry_class = entry_class
    end

    def sync(records)
      records.map { |record| sync_one(record) }
    end

    def sync_sheet_rows(rows)
      sync(rows.map { |row| self.class.record_from_sheet_row(row) })
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
      entry = (@entry_class || KnowledgeEntry).new
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
      entry.metadata = (entry.metadata || {}).merge(record["metadata"] || record[:metadata] || {}).merge("anecdote_id" => source_reference)
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

    def self.entry_type_for(values)
      text = [ values["source_project"], values["what_i_did"], values["technical_detail"], values["jd_signals"] ].join(" ").downcase
      return "performance_story" if text.match?(/performance|latency|pagination|speed|seo/)
      return "integration_story" if text.match?(/integration|api|shopify|stripe|recharge|webhook/)
      return "debugging_story" if text.match?(/debug|incident|failure|bug|reliability|security/)
      return "product_story" if text.match?(/product|customer|revenue|onboarding|recommendation/)

      "engineering_story"
    end
  end
end
