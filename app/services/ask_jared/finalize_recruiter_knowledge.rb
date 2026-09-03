require "set"

module AskJared
  class FinalizeRecruiterKnowledge
    def initialize(store: ::KnowledgeEntry, inventory: CandidateKnowledgeInventory.new)
      @store = store
      @inventory = inventory
    end

    attr_reader :preflight_report

    def call(generate_embeddings: true, reviewer: "Jared")
      @inventory.sync!(store: @store)
      retire_legacy_boundary!
      entries = intended_entries
      report = validation_report(entries)
      @preflight_report = report
      raise "Knowledge inventory validation failed: #{report[:missing_inventory].inspect}" if report[:missing_inventory].any?

      entries.each do |entry|
        active = entry.metadata.dig("recruiter_evidence", "recruiter_utility") != "archive_only"
        entry.update!(approval_status: "approved", visibility: active ? "recruiter_visible" : "internal", approved_at: active ? (entry.approved_at || Time.current) : nil, reviewed_by: reviewer)
        GenerateEmbeddingJob.perform_now(entry.id) if generate_embeddings
      end

      report = validation_report(intended_entries)
      raise "Recruiter knowledge finalization failed: #{report.inspect}" if report[:missing_approval].any? || report[:missing_visibility].any? || (generate_embeddings && report[:missing_embeddings].any?) || report[:stale_embeddings].any? || report[:unexpected_states].any?

      entries
    end

    def validation_report(entries = intended_entries)
      current_model = AskJared::EmbeddingService::MODEL
      counts = @store.group(:approval_status, :visibility).count
      recruiter = @store.recruiter_retrievable
      {
        inventory_count: entries.length,
        missing_inventory: inventory_references - entries.map(&:source_reference),
        counts: counts,
        missing_approval: entries.reject { |entry| entry.approval_status == "approved" }.map(&:source_reference),
        missing_visibility: entries.select { |entry| entry.metadata.dig("recruiter_evidence", "recruiter_utility") != "archive_only" }.reject { |entry| entry.visibility == "recruiter_visible" }.map(&:source_reference),
        missing_embeddings: recruiter.where(embedding: nil).pluck(:source_reference),
        stale_embeddings: recruiter.where.not(embedding: nil).where.not(embedding_model: current_model).pluck(:source_reference),
        unexpected_states: entries.select { |entry| entry.metadata.dig("recruiter_evidence", "recruiter_utility") != "archive_only" }.reject { |entry| entry.approval_status == "approved" && entry.visibility == "recruiter_visible" }.map { |entry| [ entry.source_reference, entry.approval_status, entry.visibility ] }
      }
    end

    private

    def inventory_references
      @inventory.records.map { |record| record.fetch("anecdote_id") }.to_set
    end

    def intended_entries
      @store.where(source_reference: inventory_references.to_a).to_a +
        @store.where("source_reference LIKE ?", "consolidated:%").to_a
    end

    def retire_legacy_boundary!
      @store.where(source_reference: "fact:engineering-experience-boundaries").update_all(approval_status: "rejected", visibility: "private", approved_at: nil)
    end
  end
end
