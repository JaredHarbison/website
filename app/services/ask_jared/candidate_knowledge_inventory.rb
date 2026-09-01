require "open3"

module AskJared
  class CandidateKnowledgeInventory
    CASE_STUDY_ENTRY_TYPES = {
      "dogly-shopify-integration" => "integration_story",
      "dogly-membership" => "product_story",
      "dogly-partner-applications" => "project",
      "fridge-no-more-bulk-ordering" => "product_story",
      "dogly-advocate-discovery" => "project",
      "dogly-product-design" => "leadership_story",
      "federation-briefing" => "engineering_story",
      "karaoke-queue" => "project"
    }.freeze

    def initialize(repository: ContentRepository.new(collection: "case_studies", model: CaseStudy), federation_path: "/Users/jaredharbison/the-federation-briefing")
      @repository = repository
      @federation_path = federation_path
    end

    def records
      @repository.all.filter_map do |case_study|
        next unless CASE_STUDY_ENTRY_TYPES.key?(case_study.slug)

        record_for(case_study)
      end + [ membership_metric_record ]
    end

    def sync!(store: ::KnowledgeEntry)
      active_record_store = ActiveRecordStore.new(store)
      entries = AnecdoteImporter.new(store: active_record_store, source_type: "repository_evidence", entry_class: store).sync(records)
      entries.each(&:save!)
      entries
    end

    private

    attr_reader :federation_path

    class ActiveRecordStore
      def initialize(model)
        @model = model
      end

      def find_by_source_reference(reference)
        @model.find_by(source_reference: reference)
      end

      def new
        @model.new
      end

      def save(entry)
        entry.save!
        entry
      end
    end

    def record_for(case_study)
      metadata = {
        "evidence_classification" => "directly_evidenced_fact",
        "source_path" => "content/case_studies/#{case_study.slug}.md",
        "source_kind" => "published_case_study",
        "publication_holds" => publication_holds_for(case_study.slug),
        "proposed_recruiter_excerpts" => proposed_excerpts_for(case_study.slug),
        "technical_inferences" => technical_inferences_for(case_study.slug),
        "review_flags" => review_flags_for(case_study.slug)
      }
      metadata["external_repository"] = federation_repository_metadata if case_study.slug == "federation-briefing"
      metadata["ownership_review"] = product_design_ownership_review if case_study.slug == "dogly-product-design"

      {
        "anecdote_id" => "case-study:#{case_study.slug}",
        "title" => case_study.title,
        "body" => case_study.body,
        "short_body" => case_study.summary,
        "entry_type" => CASE_STUDY_ENTRY_TYPES.fetch(case_study.slug),
        "confidence" => "repository_evidenced",
        "source_url" => "/case-studies/#{case_study.slug}",
        "public_url" => nil,
        "metadata" => metadata,
        "source_evidence" => { "path" => "content/case_studies/#{case_study.slug}.md", "body" => case_study.body, "metadata" => case_study.metadata }
      }
    end

    def membership_metric_record
      {
        "anecdote_id" => "metric:dogly-membership-subscription-growth",
        "title" => "Dogly membership subscription comparison",
        "body" => "The published case study states that internal pre- and post-work subscription comparisons showed an increase of more than 40%. It also states that later Stripe synchronization created historical records in bulk, so the original business measurement should not be reconstructed from the current database snapshot.",
        "short_body" => "Published metric: more than 40% growth in internal subscription comparisons; methodology remains incomplete.",
        "entry_type" => "metric",
        "confidence" => "repository_evidenced",
        "source_url" => "/case-studies/dogly-membership",
        "public_url" => nil,
        "metadata" => {
          "evidence_classification" => "directly_evidenced_fact",
          "source_path" => "content/case_studies/dogly-membership.md",
          "actual_provenance" => "Internal pre- and post-work subscription comparisons, as described in the published case study.",
          "missing_methodology" => [ "comparison_window", "denominator", "attribution_boundaries", "original_metric_query" ],
          "review_flags" => [ "metric_methodology_review_required" ],
          "publication_holds" => [ "exact_commercial_figures" ],
          "proposed_recruiter_excerpts" => [],
          "technical_inferences" => []
        },
        "source_evidence" => { "path" => "content/case_studies/dogly-membership.md", "claim" => "more than 40%", "provenance" => "internal pre/post comparison" }
      }
    end

    def publication_holds_for(slug)
      holds = [ "named_partner_or_customer_identities" ]
      holds << "partner_application_internals" if slug == "dogly-partner-applications"
      holds << "exact_commercial_figures" if slug == "fridge-no-more-bulk-ordering"
      holds << "proposed_source_code_excerpts" if slug == "dogly-shopify-integration"
      holds
    end

    def proposed_excerpts_for(slug)
      return [] unless slug == "dogly-shopify-integration"

      [
        "The first stage shipped in late 2025 and brought eligible brand customers into Dogly through signed order webhooks and a configurable invitation sequence.",
        "The second stage was developed and tested through a limited rollout in 2026 for marketplace fulfillment and catalog/inventory reconciliation.",
        "The first month began with a limited rollout to a single product from a single brand."
      ]
    end

    def technical_inferences_for(slug)
      return [] unless slug == "dogly-shopify-integration"

      [ "The limited rollout appears to have been a deliberate risk-control boundary because the repository documents timeout, payment-timing, stock-location, variant-ownership, and merge-boundary failure modes." ]
    end

    def review_flags_for(slug)
      case slug
      when "dogly-membership" then [ "metric_methodology_review_required" ]
      when "dogly-product-design" then [ "individual_ownership_review_required" ]
      when "federation-briefing" then [ "external_repository_evidence_imported_from_local_checkout" ]
      else []
      end
    end

    def product_design_ownership_review
      {
        "case_study" => "content/case_studies/dogly-product-design.md",
        "statements" => [
          "Over six years at Dogly, I have led much of the product's aesthetic and interaction evolution while also engineering the systems underneath it.",
          "I led the product design direction and implemented many of the resulting surfaces across the Rails stack.",
          "I designed the homepage in Figma across desktop, tablet, and mobile, then built the supporting Rails architecture, responsive components, and focused Stimulus interactions."
        ],
        "review_question" => "Confirm which portions were Jared's individual ownership versus team, founder, or domain-owner contribution before recruiter visibility."
      }
    end

    def federation_repository_metadata
      {
        "repository_url" => "https://github.com/JaredHarbison/the-federation-briefing",
        "local_path" => federation_path,
        "accessible_locally" => File.directory?(federation_path),
        "checkout_commit" => federation_checkout_commit,
        "evidenced_files" => [ "README.md", "federation_briefing/core.py", "tests/test_core.py", "tests/test_ingest.py", "data/canonical_briefing.json" ],
        "direct_facts" => [ "seven-day snapshot ending July 20, 2026", "up to 25 public r/startrek discussions", "reviewed offline snapshot", "claim-level citations", "insufficient-evidence fallback" ]
      }
    end

    def federation_checkout_commit
      stdout, status = Open3.capture2("git", "-C", federation_path, "rev-parse", "HEAD")
      status.success? ? stdout.strip : nil
    end
  end
end
