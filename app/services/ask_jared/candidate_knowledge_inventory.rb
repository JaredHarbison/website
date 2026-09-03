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
      entries = @repository.all.filter_map do |case_study|
        next unless CASE_STUDY_ENTRY_TYPES.key?(case_study.slug)

        record_for(case_study)
      end + [ shopify_membership_story_record, membership_metric_record, dogly_agenda_product_direction_record,
               *new_recruiter_evidence_records, *retail_career_records ]
      entries.map { |record| with_structured_recruiter_metadata(record) }
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
        "review_flags" => review_flags_for(case_study.slug),
        "recruiter_evidence" => recruiter_evidence_for(case_study.slug)
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
          },
          "recruiter_evidence" => {
            "relationship" => "Dogly product metric associated with the membership work",
            "limitations" => "The denominator, comparison window, eligible population, and attribution boundaries are unknown; later Stripe synchronization prevents reliable reconstruction.",
            "result" => "An internal pre/post subscription comparison associated with the membership work was reported as greater than 40%.",
            "safe_attribution" => "This is not a controlled causal measurement; do not attribute it to Shopify, fulfillment, or Jared's work alone."
          }
        },
        "source_evidence" => { "path" => "content/case_studies/dogly-membership.md", "claim" => "more than 40%", "provenance" => "internal pre/post comparison" }
      }
    end

    def dogly_agenda_product_direction_record
      recruiter_record(
        "story:dogly-agenda-product-direction",
        "Dogly Agenda product direction",
        "The Dogly founders were considering a Community or message-board direction. Jared argued for an Agenda/daily-plan experience after repeated user feedback that people wanted to know what to do with their dogs. He identified the misinformation, moderation, and legal burden of Community, as well as the availability of generic community alternatives. Agenda instead used vetted Dogly expert content across training, nutrition, and wellness to provide actionable guidance. Long-time users compared Community with Agenda and preferred Agenda. After launch, tag follows increased and Daily Agenda emails showed stronger open-rate behavior than the legacy approach; Jared continued monitoring engagement.",
        "Jared redirected a proposed Community direction toward an evidence-backed daily plan based on user need, explicit tradeoffs, user comparison, and post-launch engagement signals.",
        {
          "relationship" => "Dogly product strategy and daily guidance experience",
          "ownership" => {
            "leadership" => "product_direction_lead",
            "sole_authorship" => "not established",
            "people_management" => "not established",
            "personal_contributions" => "Identified the user problem, articulated the Community tradeoffs, argued for Agenda, and continued monitoring engagement after launch.",
            "collaborators" => "Dogly founders, long-time users, and Dogly experts"
          },
          "competencies" => "User research synthesis, product judgment, prioritization, tradeoff analysis, experimentation, customer understanding, engagement measurement",
          "claims" => [
            { "text" => "Jared redirected a proposed Community direction toward an evidence-backed daily plan based on user need, explicit tradeoffs, user comparison, and post-launch engagement signals.",
              "kind" => "demonstrated", "provenance" => "story:dogly-agenda-product-direction" }
          ],
          "product_learning" => "A focused, expert-backed action loop better matched the repeated user need than a generic community destination.",
          "result" => "Long-time users preferred Agenda in a Community-versus-Agenda comparison; tag follows increased and Daily Agenda emails showed stronger open-rate behavior than the legacy approach.",
          "limitations" => "The evidence does not provide the size of the preference study or numeric changes in follows or open rates.",
          "safe_attribution" => "This supports product judgment and measured learning, not a claim that Jared alone caused all engagement changes."
        },
        "content/case_studies/dogly-membership.md"
      )
    end

    def engineering_experience_boundaries_record
      recruiter_record(
        "fact:engineering-experience-boundaries",
        "Engineering experience boundaries",
        "Most of Jared's professional engineering experience has been in a very small or solo engineering environment at Dogly rather than a conventional large engineering organization. His approved engineering evidence demonstrates product-minded full-stack work, collaboration with founders and domain stakeholders, and work across mature product and operational systems. Depth varies by technology and should be assessed directly; JavaScript and React evidence should not be generalized into TypeScript expertise unless separate TypeScript evidence is available.",
        "Jared has substantial experience operating with autonomy in a small company, while conventional large engineering-team experience and technology-specific depth remain areas of less experience to validate.",
        {
          "relationship" => "Recruiter-safe engineering experience boundary",
          "competencies" => "Autonomous engineering, product-minded delivery, cross-functional collaboration, organizational adaptability",
          "limitations" => "Large engineering-team experience is not established; technology depth varies; direct TypeScript evidence is not established in the approved knowledge base.",
          "safe_attribution" => "Do not claim success on a large engineering team or TypeScript expertise from JavaScript/React experience alone.",
          "status" => "Boundary for candid hiring discussion"
        },
        "recruiter-confirmed context"
      )
    end

    def new_recruiter_evidence_records
      [
        recruiter_record("fact:large-engineering-organization-boundary", "Large engineering organization boundary",
          "Sustained professional engineering work inside a large conventional engineering organization is not established. Jared does have direct professional engineer-to-engineer collaboration at Dogly and extensive earlier experience leading layered, multi-stakeholder retail organizations. Those domains should remain distinct.",
          "Large conventional engineering-team experience is a boundary; adjacent collaboration and organizational-scale experience are demonstrated.",
          { "relationship" => "Engineering organizational-scale boundary", "competencies" => "organizational_scale, engineering_collaboration, stakeholder_alignment", "evidence_kind" => "boundary", "limitations" => "Sustained large engineering-organization experience is not established.", "safe_attribution" => "Do not equate retail organizational scale with engineering-team experience." }, "jared-confirmed-2026-09-02"),
        recruiter_record("fact:professional-typescript-boundary", "Professional TypeScript experience boundary",
          "Prolonged professional TypeScript experience is not established. Jared is studying TypeScript through coursework, targeted instructional and debugging exercises, and side-project practice.",
          "Professional TypeScript depth is not established; a current learning trajectory is documented.",
          { "relationship" => "Technology-specific experience boundary", "competencies" => "learning_new_technology", "evidence_kind" => "boundary", "limitations" => "Prolonged professional TypeScript experience is not established.", "safe_attribution" => "Do not infer TypeScript expertise from JavaScript or React evidence." }, "jared-confirmed-2026-09-02"),
        recruiter_record("fact:technology-depth-boundary", "Technology-specific depth boundary",
          "Jared's technology experience is uneven by technology and should be assessed directly. JavaScript and React experience do not establish TypeScript expertise.",
          "Technology depth varies and should be evaluated by technology rather than inferred globally.",
          { "relationship" => "Technology-specific experience boundary", "competencies" => "learning_new_technology", "evidence_kind" => "boundary", "limitations" => "Depth varies by technology; individual technology evidence must stand on its own." }, "jared-confirmed-2026-09-02"),
        recruiter_record("story:doglydaily-technical-debt-learning", "DoglyDaily technical debt and learning",
          "To implement the complicated initial DoglyDaily system quickly, Jared placed substantial logic in rake tasks and jobs expecting an immediate refactor. Priorities moved, so later changes were harder to reason about; scheduled execution had memory issues and observability was insufficient. He later separated jobs by type, extracted services and queries, kept models small, improved logging and observability, and added inspection of a user's expected progression. Performance improved significantly, but no defensible numeric metric exists.",
          "A technical-debt mistake led to a structural refactor and a clearer lesson about observability in scheduled systems.",
          { "relationship" => "DoglyDaily scheduled/background system", "competencies" => "failure_learning, production_reliability, debugging, technical_ownership", "result" => "Performance improved significantly; no numeric performance result is established.", "limitations" => "No defensible numeric performance metric exists.", "safe_attribution" => "Do not present the improvement as quantified." }, "jared-confirmed-2026-09-02"),
        recruiter_record("story:jcrew-dress-swim-decision", "J.Crew dress and swim decision",
          "When company direction replaced a dress wall with swim during peak dress season, the dress wall had produced approximately $10,000 the prior week and swim produced approximately $800 in its first week. Jared candidly raised the concern with the CEO, proposed restoring the dress wall and moving swim to secondary placement, and implemented that direction that evening after notifying his boss and Visual District Manager. The following week the dress wall produced approximately $12,000 and swim approximately $1,500. He would now explain the unusual chain of command more proactively.",
          "A candid commercial recommendation produced a strong reset, while Jared identifies a communication improvement to make today.",
          { "relationship" => "J.Crew commercial and executive decision", "competencies" => "executive_communication, technical_disagreement, stakeholder_alignment, measurable_impact", "result" => "Dress approximately $12,000; swim approximately $1,500 in secondary placement after the reset.", "limitations" => "The sales result does not prove the communication process was flawless.", "safe_attribution" => "Attribute the sales observations to the post-reset week, not to flawless communication." }, "jared-confirmed-2026-09-02"),
        recruiter_record("story:jcrew-crisis-leadership-feedback", "J.Crew crisis leadership feedback",
          "A trusted senior manager told Jared that during crises he could shift too quickly from guide and mentor into delegation and execution mode. Jared changed his approach: experienced managers now align on objective and timeline and own the approach, while greener managers receive more direction with decision involvement. He later used that approach when an experienced manager led a short-timeline training pilot successfully.",
          "Feedback changed Jared's crisis-management style toward calibrated autonomy.",
          { "relationship" => "J.Crew management feedback and delegation", "competencies" => "feedback_coachability, mentorship, people_development, leadership", "result" => "The manager led the team meeting and the team accomplished the training objective.", "safe_attribution" => "Jared supported the manager's development; do not claim sole causation." }, "jared-confirmed-2026-09-02"),
        recruiter_record("story:anthropologie-succession-mentorship", "Anthropologie succession and mentorship",
          "During the F Street Anthropologie opening, Jared hired and developed a comparatively green manager with strong People, Product, Process thinking and aesthetic vision. He partnered with her manager, provided exposure to higher-level meetings, and used a supportive guide posture. Her manager became ASM after roughly six months; the lower-level manager then moved into that role and developed her own replacement behind her.",
          "Jared used succession-oriented development to build readiness behind each promotion.",
          { "relationship" => "Anthropologie succession and manager development", "competencies" => "mentorship, people_development, organizational_scale, leadership", "result" => "The manager was promoted into the role after her supervisor advanced.", "safe_attribution" => "Do not claim Jared alone caused these people's success." }, "jared-confirmed-2026-09-02"),
        recruiter_record("story:dogly-pre-accelerator-prioritization", "Dogly pre-accelerator prioritization", "Before an accelerator, Jared prioritized dependency upgrades, then email notifications, expert profiles, and finally aesthetic redesign. He evaluated foundational risk, reuse, expected requirement stability, and throwaway-work risk. The aesthetic work began after discovery started, avoiding multiple aesthetic passes.", "Prioritized partly by expected requirement stability and half-life, not urgency alone.", { "relationship" => "Dogly roadmap prioritization", "competencies" => "prioritization, product_judgment, stakeholder_alignment", "result" => "Aesthetic work aligned with accelerator discovery and avoided multiple aesthetic passes." }, "jared-confirmed-2026-09-02"),
        recruiter_record("story:doglydaily-three-send-ux", "DoglyDaily three-send UX", "Users were confused by the same unfinished guide arriving three days in a row. Jared proposed differentiated imagery, explicit progression language, an Ignore action, and a final restart explanation. The treatment shipped Friday. Planned measurement is explicit resolution through completion or Ignore rather than passive automatic ignore; no outcome is established.", "A shipped UX treatment has a defined measurement plan, not an asserted result.", { "relationship" => "DoglyDaily progression UX", "competencies" => "product_judgment, ambiguity, measurable_impact", "claims" => [ { "text" => "The treatment shipped with a planned explicit-resolution measurement.", "kind" => "planned", "provenance" => "story:doglydaily-three-send-ux" } ], "limitations" => "No outcome claim is established." }, "jared-confirmed-2026-09-02"),
        recruiter_record("story:dogly-engineering-collaboration", "Dogly engineering collaboration", "Dogly began with a senior engineer, a frontend engineer/designer, and Jared focused on backend before becoming full-stack. Jared used code review and senior guidance, independently implemented an MVP React frontend with documentation and targeted help, and later reciprocated by retaining migrations and routing while the frontend engineer implemented bounded controller actions. Later work became highly autonomous; sustained larger-team engineering experience remains new context.", "Direct professional engineer-to-engineer collaboration is demonstrated alongside a genuine larger-team boundary.", { "relationship" => "Dogly engineer-to-engineer collaboration", "competencies" => "engineering_collaboration, learning_new_technology, technical_ownership", "limitations" => "Most later engineering work was highly autonomous; sustained larger-team engineering experience is not established.", "safe_attribution" => "Do not infer TypeScript expertise from the React example." }, "jared-confirmed-2026-09-02"),
        recruiter_record("story:stripe-learning-ramp", "Stripe learning and technical ramp", "Before Dogly's Stripe integration, Jared had not built a third-party integration and had implementation-level gaps around subscriptions, webhooks, concurrency, idempotency, and rate limiting. He researched the design, wrote an implementation plan, identified gaps, used Stripe documentation and technical material, and implemented the subscription integration. His roughly 15% time estimate is a self-estimate, not a hard metric.", "Structured research and primary documentation closed implementation gaps during a successful unfamiliar integration.", { "relationship" => "Dogly Stripe subscription integration", "competencies" => "learning_new_technology, technical_ownership, integration", "result" => "Jared successfully implemented the subscription integration.", "claims" => [ { "text" => "The learning ramp was roughly 15% by Jared's retrospective estimate.", "kind" => "self_estimate", "provenance" => "story:stripe-learning-ramp" } ] }, "jared-confirmed-2026-09-02"),
        recruiter_record("story:dogly-react-migration-disagreement", "Dogly full React migration disagreement", "Dogly's frontend engineer favored broader React use, including relatively static authentication pages. Jared pushed back because Rails already handled those flows securely, SEO was already limited partly by insufficient server-side rendering, the migration had downstream work, and revenue-generating roadmap work had priority. He documented the dependencies and time cost, while acknowledging the consistency benefit.", "A technical disagreement made opportunity cost visible without treating either framework as universally correct.", { "relationship" => "Dogly frontend architecture tradeoff", "competencies" => "technical_disagreement, prioritization, stakeholder_alignment, technical_ownership", "safe_attribution" => "Do not frame this as Rails-good or React-bad." }, "jared-confirmed-2026-09-02"),
        recruiter_record("story:dogly-agenda-simplification", "Daily Agenda simplification", "Daily Agenda launched with a compromise UX containing a hero, follows, Training, Nutrition, and Wellness sections. A tour moved engagement only minimally. Jared returned to the simplification hypothesis, removed the hero, moved follows before entry, surfaced purpose immediately, presented categories sequentially, and moved secondary functions behind buttons. Task completion increased 15%. A separate wrap-up later produced observed new follows without a quantified conversion metric.", "A measured 15% task-completion increase belongs to the simplification redesign, not the separate wrap-up feature.", { "relationship" => "Dogly Daily Agenda UX simplification", "competencies" => "product_judgment, measurable_impact, failure_learning, user_research", "result" => "Daily Agenda task completion increased 15% after the simplification redesign.", "safe_attribution" => "Do not attach the 15% result to the separate wrap-up/follow feature." }, "jared-confirmed-2026-09-02"),
        recruiter_record("story:dogly-agenda-completion-alignment", "Daily Agenda completion-metric alignment", "When a stakeholder rejected granular Agenda completion metrics, Jared recognized a possible misunderstanding of the proposal. He illustrated guide, task, topic, channel, and category levels so the team could evaluate the actual hierarchy. The team implemented the feature with guide-level completion as the default.", "Resolved a hidden stakeholder misunderstanding to improve decision quality.", { "relationship" => "Dogly stakeholder and peer decision alignment", "competencies" => "stakeholder_alignment, influence_without_authority, executive_communication, product_judgment", "result" => "The team implemented guide-level completion as the default.", "safe_attribution" => "This demonstrates decision-quality intervention, not merely advocacy for Jared's preferred feature." }, "jared-confirmed-2026-09-02")
      ]
    end

    def with_structured_recruiter_metadata(record)
      evidence = record.dig("metadata", "recruiter_evidence") || {}
      metadata = record["metadata"] || {}
      metadata["recruiter_evidence"] = evidence.merge(
        "recruiter_utility" => evidence["recruiter_utility"].presence || utility_for(record["anecdote_id"]),
        "claims" => Array(evidence["claims"]).presence || [ { "text" => record["short_body"].presence || record["body"], "kind" => evidence["evidence_kind"].presence || "demonstrated", "provenance" => record["anecdote_id"] } ],
        "capability_map" => Array(evidence["competencies"].to_s.split(/,\s*/)).index_with { |capability| { "strength" => "supporting", "evidence_kind" => "demonstrated", "domain" => evidence["relationship"], "role" => "supporting" } },
        "approved_relationships" => Array(evidence["approved_relationships"]).presence || approved_relationships_for(record["anecdote_id"])
      )
      metadata["recruiter_evidence"]["capability_map"].merge!(implicit_capabilities(record))
      record.merge("metadata" => metadata)
    end

    def implicit_capabilities(record)
      text = [ record["title"], record["body"], record.dig("metadata", "recruiter_evidence", "competencies") ].join(" ").downcase
      names = %w[rails react typescript production_reliability debugging security engineering_collaboration mentorship prioritization ambiguity technical_disagreement]
      names.filter_map do |name|
        next unless text.include?(name.tr("_", " "))

        [ name, { "strength" => "demonstrated", "evidence_kind" => "demonstrated", "domain" => record.dig("metadata", "recruiter_evidence", "relationship"), "role" => "supporting" } ]
      end.to_h
    end

    def utility_for(reference)
      return "archive_only" if reference.start_with?("archive:")
      return "primary_recruiter_evidence" if reference.start_with?("fact:") || reference.match?(/agenda|stripe|collaboration|prioritization|mentorship|disagreement/)

      "secondary_recruiter_evidence"
    end

    def approved_relationships_for(reference)
      {
        "fact:professional-typescript-boundary" => [ { "type" => "mitigated_by", "target" => "story:stripe-learning-ramp" }, { "type" => "trajectory", "target" => "fact:professional-typescript-boundary" } ],
        "fact:large-engineering-organization-boundary" => [ { "type" => "mitigated_by", "target" => "story:dogly-engineering-collaboration" }, { "type" => "transferable_foundation", "target" => "career:jcrew-store-director-columbus-circle" } ],
        "story:dogly-agenda-simplification" => [ { "type" => "supports_outcome", "target" => "story:dogly-agenda-simplification", "claim" => "15% task-completion increase" } ],
        "story:jcrew-crisis-leadership-feedback" => [ { "type" => "applied_in", "target" => "story:jcrew-crisis-leadership-feedback" } ],
        "story:doglydaily-three-send-ux" => [ { "type" => "planned_measurement", "target" => "story:doglydaily-three-send-ux" } ]
      }.fetch(reference, [])
    end

    def retail_career_records
      [
        recruiter_record(
          "career:jcrew-store-director-columbus-circle", "J.Crew + Madewell Store Director, Columbus Circle NYC (2016–2018)",
          "At J.Crew Group, Jared led a large store organization of approximately 120 employees and approximately 12 managers reporting to or supporting him. Through 2018, the store frequently achieved the #1 increase to sales plan and prior-year sales in the NYC region. He launched a full Madewell store inside a J.Crew store, the first concept of its kind within the umbrella brand. He created team satisfaction surveys and used the feedback operationally; the satisfaction score increased 20% in one year. He improved the sales trajectory through fitting-room service and higher units per transaction, and moved credit-card signup performance from approximately 30% below prior year in Q2 2016 to approximately 60% above prior year in Q3 2016.",
          "Large-store leadership, team feedback, concept launch, and measurable commercial and people outcomes.",
          { "relationship" => "J.Crew Group retail leadership", "ownership" => { "leadership" => "store_director", "people_management" => "directly led a large store organization; approximately 12 managers reported to or supported Jared", "sole_authorship" => "not established", "personal_contributions" => "Led operations, launched the embedded Madewell concept, used satisfaction feedback operationally, and improved service and signup processes" }, "competencies" => "Large-team leadership, management, coaching, stakeholder management, experimentation, customer understanding, operational leadership, measurable business outcomes", "result" => "Approximately 120 employees and approximately 12 managers; satisfaction score increased 20% in one year; credit-card signup performance moved from approximately 30% below prior year to approximately 60% above prior year in the next quarter.", "safe_attribution" => "These are retail leadership outcomes and do not imply engineering people management." }, "Jared-supplied career facts"
        ),
        recruiter_record(
          "career:jcrew-associate-store-manager-columbus-circle", "J.Crew Associate Store Manager, Columbus Circle NYC (2015–2016)",
          "Jared scheduled processes and employees at a 90%+ Dayforce HCM efficiency score, participated in assessment of SaaS products and provided feedback to providers, and increased stylist sales 25% through more consistent and effective client relationships.",
          "Operational systems adoption, SaaS evaluation, and coaching translated into measurable sales improvement.",
          { "relationship" => "J.Crew Group retail operations and management", "ownership" => { "leadership" => "associate_store_manager", "people_management" => "store management responsibility; engineering management not implied", "sole_authorship" => "not established", "personal_contributions" => "Improved scheduling/process efficiency, evaluated SaaS tools, and strengthened stylist-client practices" }, "competencies" => "Operational leadership, SaaS evaluation, product feedback, process improvement, coaching, customer understanding, measurable outcomes", "result" => "90%+ Dayforce HCM efficiency score and 25% increase in stylist sales.", "safe_attribution" => "The evidence supports retail operations and software adoption, not software product ownership." }, "Jared-supplied career facts"
        ),
        recruiter_record(
          "career:jcrew-store-director-pentagon-city", "J.Crew Store Director, Pentagon City (2014–2015)",
          "Jared improved variance to sales plan from -18% in Q3 2014 to +1% in Q4 2014, provided initial training for store directors across the DC/MD/VA market, recruited and developed an HR assistant manager into a market training role, and was asked to participate with the NYC home office in rewriting company-wide training materials.",
          "Turnaround leadership extended into regional training, talent development, and partnership with a central office—working across organizational levels.",
          { "relationship" => "J.Crew Group regional store leadership", "ownership" => { "leadership" => "store_director", "people_management" => "managed a store team; broader engineering management not implied", "sole_authorship" => "not established", "personal_contributions" => "Led turnaround, trained peers, developed a manager, and contributed to company-wide training materials" }, "competencies" => "Change management, coaching, mentorship, executive/director partnership, cross-functional collaboration, organizational complexity, operational leadership, measurable outcomes", "result" => "Variance to sales plan improved from -18% to +1% in one quarter.", "safe_attribution" => "This is evidence of retail and organizational leadership, not an engineering-team result." }, "Jared-supplied career facts"
        ),
        recruiter_record(
          "career:jcrew-store-director-f-street", "J.Crew Store Director, F Street Washington DC (2013–2014)",
          "Jared maintained the company's #1 visitor-to-customer conversion for a full year at greater than 25%, surpassed sales goals for three quarters reaching +15% versus prior year, ranked #1 for customer service in the Southeast region in Q3 2014, coached managers across the market during SaaS rollouts, provided regional manager training and follow-up plans, and was chosen for a leading operations role in store openings and relocations across the DC/MD/VA market.",
          "Market-level leadership combined customer conversion, training, software rollout, and complex opening/relocation execution.",
          { "relationship" => "J.Crew Group store-opening and regional operations leadership", "ownership" => { "leadership" => "store_director_and_market_operations_lead", "people_management" => "managed store and coached market managers; engineering management not implied", "sole_authorship" => "not established", "personal_contributions" => "Led conversion and service performance, coached managers through SaaS rollouts, and led opening/relocation operations" }, "competencies" => "Operational leadership, change management, SaaS rollout, coaching, communication, program execution, customer understanding, measurable outcomes", "result" => "Greater than 25% visitor-to-customer conversion for a full year and +15% versus prior year after three quarters of surpassed sales goals.", "safe_attribution" => "Retail market leadership should not be conflated with engineering management." }, "Jared-supplied career facts"
        ),
        recruiter_record(
          "career:urbn-general-manager-georgetown", "URBN General Manager, Urban Outfitters Georgetown (2012–2013)",
          "Jared managed a $12M flagship location, one of Urban Outfitters' five highest-volume stores. He hosted a company-wide quarterly visual prototype process involving store-opening-scale shipments and coordination, and implemented web-based communication tools for a large store team.",
          "Large-scale operations combined executive-facing coordination, prototyping, and adoption of communication tools.",
          { "relationship" => "URBN flagship retail operations", "ownership" => { "leadership" => "general_manager", "people_management" => "managed a large flagship store team", "sole_authorship" => "not established", "personal_contributions" => "Managed the flagship, coordinated the company-wide prototype process, and implemented team communication tools" }, "competencies" => "Large-organization operations, stakeholder management, project execution, communication, product/software adoption, operational leadership", "result" => "$12M flagship location; one of five highest-volume stores.", "safe_attribution" => "This demonstrates retail organizational scale, not engineering-team scale." }, "Jared-supplied career facts"
        ),
        recruiter_record(
          "career:urbn-store-manager-anthropologie", "URBN Store Manager, Anthropologie DC/MD (2009–2012)",
          "Jared mentored and developed six managers into store-manager-level positions, worked with local businesses, media, and nonprofits, ran a 300-customer store-opening event that generated $30,000 in two hours on a $1,500 budget, assisted the District Manager in guiding other store managers through large objectives, managed an experimental accessories boutique opening, and relocated a 15-year-old store while achieving record-breaking sales.",
          "Multi-stakeholder store leadership combined mentorship, experimentation, event execution, and change management.",
          { "relationship" => "URBN multi-store management and community partnership", "ownership" => { "leadership" => "store_manager", "people_management" => "developed six managers into store-manager-level roles", "sole_authorship" => "not established", "personal_contributions" => "Mentored managers, led openings and relocation, partnered externally, and executed a high-return launch event" }, "competencies" => "Coaching, mentorship, stakeholder management, cross-functional collaboration, experimentation, ambiguous objectives, program execution, measurable outcomes", "result" => "Six managers developed into store-manager-level positions; a $30,000 event ran in two hours on a $1,500 budget.", "safe_attribution" => "These are retail management and operating outcomes, not engineering management." }, "Jared-supplied career facts"
        ),
        recruiter_record(
          "career:urbn-people-operations-manager-anthropologie", "URBN People & Operations Manager, Anthropologie (2008–2009)",
          "Jared managed people and operational processes in a roughly $10M location, improved average loss-prevention audit scores by 8 points in a high-theft environment, and managed scheduling and processes against payroll targets.",
          "People operations and process control produced a measurable audit improvement while balancing labor constraints.",
          { "relationship" => "URBN people and operations leadership", "ownership" => { "leadership" => "people_and_operations_manager", "people_management" => "managed people processes; engineering management not implied", "sole_authorship" => "not established", "personal_contributions" => "Managed people operations, loss-prevention improvement, and payroll-aligned scheduling" }, "competencies" => "People operations, process improvement, operational controls, organizational complexity, measurable outcomes", "result" => "Roughly $10M location; average loss-prevention audit scores improved by 8 points.", "safe_attribution" => "The evidence supports operational and people-process leadership." }, "Jared-supplied career facts"
        ),
        recruiter_record(
          "career:urbn-senior-merchandiser", "URBN Senior Merchandiser, Urban Outfitters (2001–2008)",
          "Jared reduced men's merchandising store-opening time by approximately 40% across 12 openings. This result is specifically attached to the repeated opening-process work.",
          "Measured process improvement across repeated store openings.",
          { "relationship" => "URBN men's merchandising store-opening process", "ownership" => { "leadership" => "senior_merchandiser", "people_management" => "not established", "sole_authorship" => "not established", "personal_contributions" => "Improved the men's merchandising store-opening process" }, "competencies" => "process improvement, program execution, measurable impact", "result" => "Approximately 40% reduction in opening time across 12 openings.", "recruiter_utility" => "primary_recruiter_evidence", "safe_attribution" => "This metric belongs only to the men's merchandising store-opening process." }, "Jared-supplied career facts"
        ),
        recruiter_record(
          "archive:urbn-senior-merchandiser-prototype-workshops", "URBN prototype and workshop responsibilities",
          "Jared managed the men's Back-to-School visual prototype in San Francisco for three years, led district workshops that completed seasonal setups in approximately 50% of normal time, and prototyped new approaches including clothing and home-goods integration.",
          "Preserved historical prototype and workshop responsibilities without attaching them to the separate opening-time metric.",
          { "relationship" => "URBN merchandising prototypes and district workshops", "competencies" => "experimentation, facilitation, change management", "result" => "Seasonal setups were completed in approximately 50% of normal time during the workshops.", "recruiter_utility" => "archive_only", "safe_attribution" => "Do not associate these responsibilities with the separate 40% opening-process result." }, "Jared-supplied career facts"
        )
      ]
    end

    def recruiter_record(reference, title, body, short_body, recruiter_evidence, source_reference)
      {
        "anecdote_id" => reference,
        "title" => title,
        "body" => body,
        "short_body" => short_body,
        "entry_type" => reference.start_with?("career:") ? "leadership_story" : (reference.start_with?("fact:") ? "career_context" : "product_story"),
        "confidence" => "jared_confirmed_recruiter_safe",
        "source_url" => nil,
        "public_url" => nil,
        "metadata" => {
          "evidence_classification" => "jared_supplied_recruiter_safe_fact",
          "source_path" => source_reference,
          "source_kind" => "direct_statement_from_jared",
          "publication_holds" => [],
          "review_flags" => [],
          "human_review" => sufficient_review("Facts supplied directly by Jared and scoped for recruiter-safe use."),
          "approval_readiness" => { "ready_for_jared_approval" => true, "reason" => "Directly supplied recruiter-safe facts; retain explicit attribution and boundaries." },
          "recruiter_evidence" => recruiter_evidence
        },
        "source_evidence" => { "source" => source_reference, "reference" => reference, "body" => body }
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
          },
          "recruiter_evidence" => {
            "relationship" => "Dogly product story connecting an acquisition path to an existing membership journey",
            "ownership" => {
              "leadership" => "project_lead",
              "sole_authorship" => "not established",
              "people_management" => "not established",
              "personal_contributions" => "Product planning and engineering across the connected acquisition and membership experience",
              "collaborators" => "Dogly founders, domain experts, and users where the case studies describe close partnership"
            },
            "result" => "Qualifying partner purchases expanded acquisition into Dogly's existing visitor-to-user-to-member journey; partner-purchase conversion was approximately at the existing journey's rate.",
            "product_learning" => "Carefully selected partnerships could expand acquisition, while the larger remaining opportunity was improving DoglyDaily and Agenda use after acquisition and strengthening member value.",
            "limitations" => "The >40% figure is an internal pre/post comparison; its denominator, window, eligible population, and causal attribution are unavailable.",
            "safe_attribution" => "Do not claim Shopify caused or contributed to the >40% result; later fulfillment work was separate."
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

    def recruiter_evidence_for(slug)
      ownership = {
        "leadership" => "project_lead",
        "sole_authorship" => "not established",
        "people_management" => "not established"
      }
      evidence = {
        "dogly-product-design" => {
          "relationship" => "Dogly product design direction",
          "ownership" => ownership.merge(
            "personal_contributions" => "Primary responsibility for visual and interaction design direction; designed the 2026 multi-state homepage in Figma and implemented its Rails architecture, responsive components, and focused Stimulus interactions.",
            "collaborators" => "Dogly founders and domain owners contributed product direction, requirements, feedback, and constraints."
          ),
          "competencies" => "Product design, Figma, responsive Rails interfaces, Stimulus, translating customer feedback into product decisions"
        },
        "dogly-membership" => {
          "relationship" => "Dogly membership product experience",
          "ownership" => ownership.merge(
            "personal_contributions" => "Product planning and full-stack work across subscription state, content access, tagging, comments, notifications, daily guidance, Zoom workflows, reporting, and connecting product surfaces.",
            "collaborators" => "Dogly founders and Advocates"
          ),
          "competencies" => "Rails, PostgreSQL, Stripe, Zoom, product planning, lifecycle and member experience"
        },
        "dogly-shopify-integration" => {
          "relationship" => "Dogly external-platform integration",
          "ownership" => ownership.merge(
            "personal_contributions" => "Owned technical planning through implementation and production support for the acquisition path, plus design, implementation, and limited rollout of the fulfillment path.",
            "collaborators" => "Dogly founders"
          ),
          "competencies" => "Rails, PostgreSQL, Shopify Admin API, Spree Commerce, Active Job, webhooks, background jobs, catalog and inventory reconciliation",
          "result" => "A qualifying partner purchase could enter Dogly through signed webhooks and configured invitations; later fulfillment was a separate limited rollout.",
          "limitations" => "The repository does not establish revenue generated by the integration or a quantified acquisition lift.",
          "safe_attribution" => "Do not connect the integration causally to the >40% membership comparison."
        },
        "dogly-partner-applications" => {
          "relationship" => "Dogly partner onboarding inside a mature Rails marketplace",
          "ownership" => ownership.merge(
            "personal_contributions" => "Designed and implemented the Partner Pro onboarding flow, JSON-backed application session manager, and review workflow.",
            "collaborators" => "Partner and internal domain stakeholders where requirements and review rules were involved"
          ),
          "competencies" => "Rails, PostgreSQL, Stimulus, Haml, SCSS, resumable workflows, authorization, operational UX"
        },
        "fridge-no-more-bulk-ordering" => {
          "relationship" => "Dogly operational commerce workflow",
          "ownership" => ownership.merge(
            "personal_contributions" => "Designed and implemented the Rails workflow, data model, admin and partner interfaces, product selection, shipping calculations, order history, tracking, notes, and access controls.",
            "collaborators" => "Dogly founders and Fridge No More partnership stakeholders"
          ),
          "competencies" => "Rails, Spree Commerce, PostgreSQL, operational product design, access control",
          "result" => "The first retained order was $11,935.90 across 210 cases.",
          "limitations" => "This is a first retained order, not a quantified claim about overall sales growth."
        },
        "dogly-advocate-discovery" => {
          "relationship" => "Dogly advocate discovery product",
          "ownership" => ownership.merge(
            "personal_contributions" => "Designed and implemented the Rails query layer, controller integration, Haml page structure, Stimulus interactions, and focused matching and visibility tests.",
            "collaborators" => "Dogly users and content/domain stakeholders where taxonomy and visibility rules were involved"
          ),
          "competencies" => "Rails, PostgreSQL, Stimulus, taxonomy-backed search, accessibility, visibility rules",
          "result" => "Shipped Browse and Match modes for the public advocate directory.",
          "limitations" => "The repository does not establish conversion-quality improvement from matching."
        },
        "federation-briefing" => {
          "relationship" => "Independent project outside Dogly",
          "ownership" => ownership.merge(
            "personal_contributions" => "Designed and built the complete prototype: ingestion, reviewed snapshots, search, OpenAI integration, source selection, prompts, fallbacks, comparison interface, and tests."
          ),
          "competencies" => "Python, OpenAI API, Streamlit, scikit-learn, retrieval, evidence citation, failure handling",
          "result" => "A sourced AI briefing prototype that shows its work and falls back when evidence is insufficient.",
          "status" => "Prototype; shipped foundations are distinct from future work."
        },
        "karaoke-queue" => {
          "relationship" => "Independent project outside Dogly",
          "ownership" => ownership.merge(
            "personal_contributions" => "Designed and implemented the product model, Rails boundaries, queue and event behavior, responsive surfaces, YouTube integration, accessibility behavior, and focused tests."
          ),
          "competencies" => "Rails, PostgreSQL, Hotwire, Stimulus, YouTube Data API, accessibility, contextual authorization",
          "result" => "A shared, multi-role karaoke queue with performer, host, owner, and display contexts.",
          "status" => "Work in progress; shipped foundations and roadmap work are explicitly separated.",
          "limitations" => "The case study does not claim a measured business outcome."
        }
      }
      evidence.fetch(slug) { { "ownership" => ownership } }
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
    rescue Errno::ENOENT
      nil
    end
  end
end
