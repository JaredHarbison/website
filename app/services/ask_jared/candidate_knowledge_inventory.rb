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
      end + [ shopify_membership_story_record, membership_metric_record ]
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
      metadata["evidence_chain"] = shopify_membership_evidence_chain if %w[dogly-shopify-integration dogly-membership].include?(case_study.slug)
      metadata["human_review"] = human_review_for(case_study.slug)
      metadata["approval_readiness"] = approval_readiness_for(case_study.slug)

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
        "body" => "The bounded recruiter-safe claim is that the membership case study reported more than 40% growth in an internal pre/post subscription comparison associated with the membership work. No historical artifact establishes the denominator, comparison window, eligible population, or causal attribution, and later Stripe synchronization created historical records in bulk. Do not present this as a controlled causal measurement, a quantified Shopify acquisition lift, or a result of later fulfillment work.",
        "short_body" => "Bounded metric: an internal pre/post subscription comparison associated with the membership work was reported as greater than 40%; it is not a controlled causal measurement.",
        "entry_type" => "metric",
        "confidence" => "repository_evidenced",
        "source_url" => "/case-studies/dogly-membership",
        "public_url" => nil,
        "metadata" => {
          "evidence_classification" => "directly_evidenced_fact",
          "source_path" => "content/case_studies/dogly-membership.md",
          "actual_provenance" => "Internal pre- and post-work subscription comparisons, as described in the published case study.",
          "missing_methodology" => [ "comparison_window", "denominator", "attribution_boundaries", "original_metric_query" ],
          "evidence_chain" => shopify_membership_evidence_chain,
          "history_commits" => shopify_membership_evidence_chain["history_commits"],
          "supporting_files" => shopify_membership_evidence_chain["supporting_files"],
          "review_flags" => [ "metric_methodology_review_required" ],
          "publication_holds" => [ "named_partner_or_customer_identities" ],
          "proposed_recruiter_excerpts" => [],
          "technical_inferences" => [],
          "human_review" => sufficient_review("Jared confirmed no additional historical metric artifact is known; retain only the bounded internal pre/post comparison language."),
          "approval_readiness" => approval_readiness_for("dogly-membership-metric"),
          "human_context" => { "status" => "NO_ADDITIONAL_ARTIFACT_KNOWN", "note" => "Jared confirmed no additional historical metric artifact is known." },
          "safe_publication" => {
            "required_qualification" => "State that the figure came from an internal pre/post subscription comparison associated with the membership work.",
            "disallowed_claims" => [ "controlled causal measurement", "Shopify independently caused the result", "quantified acquisition lift", "later fulfillment caused the result" ]
          }
        },
        "source_evidence" => { "path" => "content/case_studies/dogly-membership.md", "claim" => "more than 40%", "provenance" => "internal pre/post comparison" }
      }
    end

    def shopify_membership_story_record
      {
        "anecdote_id" => "story:dogly-shopify-membership-acquisition",
        "title" => "Dogly acquisition and guided membership journey",
        "body" => "Dogly's existing visitor-to-user-to-member journey was extended with a new acquisition path: a qualifying purchase on a participating partner's Shopify store could bring someone into Dogly through signed order webhooks and configured invitations. Membership was positioned around unlocking the full functionality of Agenda and DoglyDaily. Partner-purchase users converted to membership at approximately the same rate as users entering through the existing visitor-to-user journey, suggesting the larger opportunity was improving DoglyDaily so members could make better use of Agenda and strengthening the post-acquisition member-value experience. The membership case study separately reports more than 40% in an internal pre/post subscription comparison; that is not a controlled causal Shopify result. Fulfillment was a separate limited 2026 rollout, and later work must not be attributed to that metric.",
        "short_body" => "Shopify expanded acquisition into Dogly's existing journey; partner-purchase conversion was approximately at the existing journey's rate, shifting the opportunity toward DoglyDaily and post-acquisition member value.",
        "entry_type" => "product_story",
        "confidence" => "repository_evidenced",
        "source_url" => "/case-studies/dogly-membership",
        "public_url" => nil,
        "metadata" => {
          "evidence_classification" => "directly_evidenced_fact",
          "source_paths" => [ "content/case_studies/dogly-membership.md", "content/case_studies/dogly-shopify-integration.md", "docs/ask-jared-architecture.md" ],
          "evidence_chain" => shopify_membership_evidence_chain,
          "human_review" => human_review_for("dogly-shopify-membership-acquisition"),
          "approval_readiness" => approval_readiness_for("dogly-shopify-membership-acquisition"),
          "human_context" => shopify_membership_human_context,
          "publication_holds" => [ "named_partner_or_customer_identities" ],
          "review_flags" => [],
          "proposed_recruiter_excerpts" => [],
          "technical_inferences" => [],
          "safe_publication" => {
            "required_qualification" => "Describe Shopify as an expanded acquisition source into Dogly's existing visitor-to-user-to-member journey; describe the >40% figure only as an internal pre/post comparison associated with the membership work.",
            "disallowed_claims" => [ "Shopify was the membership experience", "Shopify independently caused the >40% result", "quantified acquisition lift", "later fulfillment caused the membership metric", "unnecessary proprietary source-code publication" ]
          }
        },
        "source_evidence" => { "paths" => [ "content/case_studies/dogly-membership.md", "content/case_studies/dogly-shopify-integration.md" ], "claim" => "coherent acquisition and membership evidence chain" }
      }
    end

    def shopify_membership_evidence_chain
      {
        "chronology" => [
          "Membership case study: over several phases, Dogly added discovery, conversation, lifecycle email, daily plans, subscriptions, and live groups.",
          "Shopify acquisition: shipped in late 2025 for qualifying purchases from participating brand stores, with signed order webhooks and configured invitations.",
          "Shopify fulfillment: developed and tested through a limited rollout in 2026 for marketplace order transmission and catalog/inventory reconciliation.",
          "Membership metric: the published case study reports an internal pre/post subscription comparison greater than 40%, but gives no measurement date."
        ],
        "eligible_population_before" => "The prior membership experience was directory-led; the repository does not provide a numeric eligible population.",
        "eligible_population_after" => "The post-work experience included members, non-members, dog-scoped guidance, and customers entering through qualifying configured Shopify purchases; exact population definitions and counts are not evidenced.",
        "metric_subject" => "Subscription levels in internal comparisons associated in the case study with the membership-engagement work.",
        "fulfillment_relationship" => "No direct evidence connects the later fulfillment rollout to the membership comparison.",
        "portion_present_at_measurement" => "Unknown because the measurement date/window is not recorded.",
        "safe_attribution" => "State the >40% figure as an internal comparison reported alongside the membership work; do not present it as a causal Shopify or fulfillment result.",
        "unknown_methodology" => [ "measurement_timing", "comparison_window", "denominator", "attribution_boundaries", "original_metric_query", "historical_population_after_later_stripe_sync" ],
        "relative_to_metric" => "The repository dates the acquisition path to late 2025 and the fulfillment work to a limited 2026 rollout, but does not date the internal comparison measurement; it cannot establish which rollout portion existed when the metric was measured.",
        "historical_artifacts" => "No original metric query, export, or dated measurement artifact was found in the repository or available local artifacts.",
        "historical_state_caveat" => "Later Stripe synchronization created historical records in bulk, so the original comparison cannot be reconstructed reliably from the current database snapshot.",
        "history_commits" => {
          "membership" => [ "f34f725 feat(content): add membership and planning stories", "2872a25 docs(case-study): polish portfolio narratives", "e8d7bbc refine case studies and anonymize karaoke assets" ],
          "shopify" => [ "b842e4e feat(content): add Shopify integration portfolio series", "f433c61 docs(case-study): clarify Shopify rollout boundaries", "b24864f docs(case-studies): Clarify Shopify integration outcomes and add suggestions" ]
        },
        "supporting_files" => [ "docs/ask-jared-architecture.md", "test/services/content_repository_test.rb", "test/services/ask_jared_anecdote_importer_test.rb" ]
      }
    end

    def shopify_membership_human_context
      {
        "status" => "CONFIRMED_BY_JARED",
        "direct_facts" => [
          "A qualifying purchase on a participating partner's Shopify store was an acquisition path into Dogly's already-established visitor-to-user-to-member journey.",
          "Membership was positioned around unlocking the full functionality of Agenda and DoglyDaily.",
          "Partner-purchase users converted to membership at approximately the same rate as users entering through Dogly's existing visitor-to-user journey.",
          "The larger remaining opportunity was improving DoglyDaily so users could make better use of Agenda and strengthening the post-acquisition/member-value experience, rather than treating the partner acquisition source as the primary conversion problem."
        ],
        "bounded_claim" => "Do not describe Shopify itself as the membership experience or claim a quantified acquisition lift. The repository-supported count of more than 1,000 Shopify-associated user records retains its existing provenance."
      }
    end

    def publication_holds_for(slug)
      holds = [ "named_partner_or_customer_identities" ] unless slug == "fridge-no-more-bulk-ordering"
      holds ||= []
      holds << "proposed_source_code_excerpts" if slug == "dogly-shopify-integration"
      holds
    end

    def human_review_for(slug)
      packets = {
        "dogly-shopify-integration" => sufficient_review("Repository evidence supports the acquisition/fulfillment chronology, bounded first-month scope, operational tradeoffs, and implementation ownership. Remaining excerpt/name permissions are publication review, not missing recruiter context."),
        "dogly-membership" => sufficient_review("Repository evidence supports the product progression, audience distinctions, constraints, implementation, tradeoffs, and bounded metric language. The metric's missing methodology is tracked separately."),
        "dogly-partner-applications" => sufficient_review("Repository evidence supports the problem, staged flow, constraints, implementation, failure handling, and stated ownership well enough for a recruiter-facing answer."),
        "fridge-no-more-bulk-ordering" => sufficient_review("Repository evidence supports the partner context, narrow first release, two-week initial workflow, commercial outcome, design tradeoffs, and later operational limitation."),
        "dogly-advocate-discovery" => sufficient_review("Repository evidence supports the user problem, taxonomy-backed approach, visibility constraints, shipped behavior, and explicit absence of conversion-quality measurement."),
        "dogly-product-design" => sufficient_review("Jared confirmed he was the primary person responsible for visual and interaction design direction in close partnership with the founders, and confirmed the 2026 multi-state homepage was his Figma design and implementation work."),
        "federation-briefing" => sufficient_review("The linked repository is locally accessible at the exact GitHub URL and provides implementation, tests, reviewed artifacts, constraints, and failure behavior."),
        "karaoke-queue" => sufficient_review("Repository case-study evidence clearly distinguishes shipped foundations from roadmap work and covers product boundaries, tradeoffs, ownership, and learning."),
        "dogly-shopify-membership-acquisition" => sufficient_review("Jared confirmed the Shopify path's acquisition intent, the established Dogly visitor-to-user-to-member journey, the Agenda/DoglyDaily membership value proposition, approximate conversion-rate parity, and the resulting post-acquisition product learning.")
      }
      packets.fetch(slug) { sufficient_review("No additional Jared-only context was found that would materially improve the current recruiter answer.") }
    end

    def approval_readiness_for(slug)
      ready = %w[
        dogly-membership dogly-product-design fridge-no-more-bulk-ordering dogly-partner-applications
        dogly-advocate-discovery
        federation-briefing karaoke-queue dogly-shopify-integration dogly-shopify-membership-acquisition dogly-membership-metric
      ].include?(slug)
      {
        "ready_for_jared_approval" => ready,
        "reason" => ready ? "Repository evidence and Jared's explicit context support a bounded recruiter answer; source-code excerpts are not required for factual recruiter Q&A." : "Requires the recorded publication, ownership, attribution, or metric-methodology review before approval."
      }
    end

    def sufficient_review(reason)
      { "status" => "HUMAN_CONTEXT_SUFFICIENT", "priority" => nil, "questions" => [], "basis" => reason }
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
      when "dogly-product-design" then []
      when "federation-briefing" then [ "external_repository_evidence_imported_from_local_checkout" ]
      else []
      end
    end

    def product_design_ownership_review
      {
        "case_study" => "content/case_studies/dogly-product-design.md",
        "status" => "CONFIRMED_BY_JARED",
        "confirmed_context" => "Jared was the primary person responsible for Dogly's visual and interaction design direction, working in close partnership with the founders. Over time he learned their preferences well enough to anticipate the visual and product decisions they would want to see. The 2026 multi-state homepage was his Figma design and implementation work.",
        "statements" => [
          "Over six years at Dogly, I have led much of the product's aesthetic and interaction evolution while also engineering the systems underneath it.",
          "I led the product design direction and implemented many of the resulting surfaces across the Rails stack.",
          "I designed the homepage in Figma across desktop, tablet, and mobile, then built the supporting Rails architecture, responsive components, and focused Stimulus interactions."
        ],
        "review_question" => nil
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
