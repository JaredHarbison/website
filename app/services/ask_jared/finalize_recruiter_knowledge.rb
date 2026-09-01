module AskJared
  class FinalizeRecruiterKnowledge
    APPROVED_REFERENCES = %w[
      case-study:dogly-product-design
      case-study:dogly-membership
      case-study:dogly-shopify-integration
      case-study:dogly-partner-applications
      case-study:fridge-no-more-bulk-ordering
      case-study:dogly-advocate-discovery
      case-study:federation-briefing
      case-study:karaoke-queue
      story:dogly-shopify-membership-acquisition
      metric:dogly-membership-subscription-growth
    ].freeze

    def initialize(store: ::KnowledgeEntry, inventory: CandidateKnowledgeInventory.new)
      @store = store
      @inventory = inventory
    end

    def call(generate_embeddings: true, reviewer: "Jared")
      @inventory.sync!(store: @store)
      entries = @store.where(source_reference: APPROVED_REFERENCES).to_a
      raise "Missing approved knowledge entries: #{(APPROVED_REFERENCES - entries.map(&:source_reference)).join(', ')}" unless entries.length == APPROVED_REFERENCES.length

      entries.each do |entry|
        entry.update!(approval_status: "approved", visibility: "recruiter_visible", approved_at: entry.approved_at || Time.current, reviewed_by: reviewer)
        GenerateEmbeddingJob.perform_now(entry.id) if generate_embeddings
      end

      entries
    end
  end
end
