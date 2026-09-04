require "digest"

class CompleteProductionIncidentCandidate < ActiveRecord::Migration[8.0]
  SOURCE_REFERENCE = "story:dogly-production-incident-2022"

  CLAIMS = [
    { "ref_suffix" => "detection", "text" => "Suspicious or bot-created users appeared in Dogly's admin user index and triggered Jared's investigation.", "kind" => "demonstrated", "role" => "detection" },
    { "ref_suffix" => "traffic-behavior", "text" => "Jared's investigation showed automated traffic hitting pages throughout the site at very high frequency and attempting multiple forms, including account creation and legacy partner onboarding.", "kind" => "demonstrated", "role" => "behavior" },
    { "ref_suffix" => "possible-sitemap-mechanism", "text" => "Jared recalls that the bots may have been traversing pages exposed through the sitemap, but that mechanism was not conclusively established.", "kind" => "demonstrated", "role" => "boundary" },
    { "ref_suffix" => "scraping-boundary", "text" => "Jared suspects scraping may also have occurred, but does not know that it did.", "kind" => "demonstrated", "role" => "boundary" },
    { "ref_suffix" => "impact", "text" => "The activity created database pollution, exhausted an email-volume limit, consumed application resources, and created operational overhead.", "kind" => "demonstrated", "role" => "impact" },
    { "ref_suffix" => "quantification-boundary", "text" => "Jared does not remember reliable traffic, request, account, or affected-record counts; no quantitative scale beyond very high frequency is established.", "kind" => "demonstrated", "role" => "boundary" },
    { "ref_suffix" => "initial-investigation", "text" => "After noticing the suspicious users, Jared inspected application logs and database records.", "kind" => "demonstrated", "role" => "investigation" },
    { "ref_suffix" => "scope-investigation", "text" => "Because this occurred before Dogly's later observability improvements, much of Jared's investigation relied directly on logs, admin interfaces, and database queries to determine scope and patterns.", "kind" => "demonstrated", "role" => "investigation" },
    { "ref_suffix" => "security-triage", "text" => "Jared reviewed admin surfaces to ensure they remained appropriately secured and queried the database for records resembling suspicious patterns in User and legacy partner-application objects.", "kind" => "demonstrated", "role" => "security_triage" },
    { "ref_suffix" => "security-boundary", "text" => "There is no confirmed evidence in Jared's recollection that the bots compromised privileged access or sensitive data; this absence of evidence does not prove that no compromise occurred.", "kind" => "demonstrated", "role" => "boundary" },
    { "ref_suffix" => "research", "text" => "Jared researched Rails-specific mitigations using documentation, engineering blog posts, and Stack Overflow before implementing defenses; this was pre-generative-AI research.", "kind" => "demonstrated", "role" => "process" },
    { "ref_suffix" => "mitigation", "text" => "Jared implemented layered bot defenses including throttling, rate limiting, blacklist and whitelist controls, and honeypots.", "kind" => "demonstrated", "role" => "mitigation" },
    { "ref_suffix" => "validation", "text" => "Jared monitored application logs, the admin user index, and legacy partner-onboarding submissions to evaluate behavior after mitigation.", "kind" => "demonstrated", "role" => "validation" },
    { "ref_suffix" => "observed-outcome", "text" => "Following the intervention, the immediate bot activity Jared had been observing stopped.", "kind" => "demonstrated", "role" => "outcome" },
    { "ref_suffix" => "long-term-maintenance", "text" => "Dogly's bot defenses subsequently required periodic strengthening as automated traffic patterns changed.", "kind" => "demonstrated", "role" => "maintenance" },
    { "ref_suffix" => "adaptation-boundary", "text" => "Jared believes bot adaptation explains at least some of the need for later restrictions, but that attribution is his interpretation rather than an empirically established causal relationship.", "kind" => "demonstrated", "role" => "boundary" },
    { "ref_suffix" => "observability-context", "text" => "The incident occurred relatively early in Jared's Dogly tenure, approximately 2022, before the stronger application observability he implemented later, so detection and investigation relied more heavily on manual review.", "kind" => "demonstrated", "role" => "context" }
  ].freeze

  CAPABILITY_MAP = {
    "incident response" => { "strength" => "demonstrated", "evidence_kind" => "demonstrated", "domain" => "Dogly production bot-traffic incident", "role" => "primary" },
    "production ownership" => { "strength" => "demonstrated", "evidence_kind" => "demonstrated", "domain" => "Dogly application operations", "role" => "supporting" },
    "debugging/investigation" => { "strength" => "demonstrated", "evidence_kind" => "demonstrated", "domain" => "logs, admin interfaces, and database investigation", "role" => "supporting" },
    "security judgment" => { "strength" => "demonstrated", "evidence_kind" => "demonstrated", "domain" => "application security triage", "role" => "supporting" },
    "learning new technology" => { "strength" => "demonstrated", "evidence_kind" => "demonstrated", "domain" => "Rails-specific unfamiliar-problem research", "role" => "supporting" },
    "Rails/backend engineering" => { "strength" => "demonstrated", "evidence_kind" => "demonstrated", "domain" => "Rails application mitigations", "role" => "supporting" },
    "operational judgment" => { "strength" => "demonstrated", "evidence_kind" => "demonstrated", "domain" => "production impact and validation", "role" => "supporting" }
  }.freeze

  def up
    entry = KnowledgeEntry.find_by!(source_reference: SOURCE_REFERENCE)
    body = "Early in Jared's Dogly engineering tenure, approximately in 2022, he noticed suspicious user accounts appearing in the application's admin user index. Investigation showed automated traffic hitting pages throughout the site at very high frequency and attempting interactions across multiple forms, including account creation and legacy partner-onboarding forms.\n\nJared investigated through application logs, admin interfaces, and database queries, researched Rails-specific mitigations through documentation, engineering blog posts, and Stack Overflow, and reviewed admin surfaces and related records as security triage. He implemented throttling, rate limiting, blacklist/whitelist controls, and honeypots. He evaluated the intervention through continued log monitoring, the admin user index, and targeted legacy submissions. Following the intervention, the immediate bot activity he had been observing stopped.\n\nThe evidence does not establish sitemap traversal, scraping, privileged-access or sensitive-data compromise, quantitative traffic or record counts, or conclusive causal attribution for any individual defense. Later defenses required periodic strengthening as automated traffic patterns changed; Jared's belief that bots adapted is an interpretation, not an empirically established causal relationship."
    metadata = {
      "evidence_classification" => "jared_confirmed_recruiter_safe_fact",
      "actual_provenance" => "Jared-confirmed production-incident account supplied for knowledge enrichment",
      "source_kind" => "direct_statement_from_jared",
      "source_path" => "Jared-confirmed production incident, approximately 2022",
      "recruiter_evidence" => {
        "recruiter_utility" => "primary_recruiter_evidence",
        "relationship" => "Dogly production bot-traffic incident investigation and response",
        "claims" => CLAIMS,
        "capability_map" => CAPABILITY_MAP,
        "approved_relationships" => [
          { "type" => "chronology", "target" => SOURCE_REFERENCE, "claim" => "detection → investigation → mitigation → subsequent observation" },
          { "type" => "observed_after", "target" => SOURCE_REFERENCE, "claim" => "The immediate observed bot activity stopped following the intervention; stronger causal attribution is not established." },
          { "type" => "bounded_interpretation", "target" => SOURCE_REFERENCE, "claim" => "Possible sitemap traversal, scraping, compromise, and later bot adaptation remain explicitly uncertain or interpretive as stated in the claims." }
        ],
        "result" => "Following the intervention, the immediate bot activity Jared had been observing stopped.",
        "limitations" => "Do not present sitemap traversal or scraping as established; do not claim privileged-access or sensitive-data compromise or proof of no compromise; do not invent counts; do not attribute cessation conclusively to an individual defense or treat later bot adaptation as established causality.",
        "safe_attribution" => "The chronology and observed post-intervention cessation are supported. The evidence does not establish which defense caused cessation or prove that all bot traffic stopped.",
        "status" => "Complete recruiter-safe incident account; preserve explicit uncertainty and observational boundaries"
      },
      "review_flags" => [],
      "missing_fields" => [],
      "human_review" => { "status" => "CONFIRMED_BY_JARED", "questions" => [] }
    }
    entry.update!(body: body, short_body: "Around 2022, Jared investigated high-frequency automated traffic at Dogly, implemented layered bot defenses, and observed the immediate activity stop; scale, compromise, and individual-defense causality remain bounded.", confidence: "jared_confirmed_recruiter_safe", source_type: "jared_confirmed", source_fingerprint: Digest::SHA256.hexdigest(body), metadata: metadata, approval_status: "needs_review", visibility: "private", approved_at: nil, reviewed_by: nil)
  end

  def down
    entry = KnowledgeEntry.find_by(source_reference: SOURCE_REFERENCE)
    return unless entry

    entry.update!(approval_status: "needs_review", visibility: "private", approved_at: nil, reviewed_by: nil)
  end
end
