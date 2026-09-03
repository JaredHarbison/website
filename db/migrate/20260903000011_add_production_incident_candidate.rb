require "digest"

class AddProductionIncidentCandidate < ActiveRecord::Migration[8.0]
  SOURCE_REFERENCE = "story:dogly-production-incident-2022"

  def up
    return if KnowledgeEntry.exists?(source_reference: SOURCE_REFERENCE)

    KnowledgeEntry.create!(
      title: "Dogly early production bot-traffic investigation",
      body: "Approximately in 2022, relatively early in Jared's Dogly engineering tenure, suspicious or bot-created user accounts became visible in Dogly's admin users index. Jared noticed the abnormal users, and that observation triggered an investigation into the scope of the bot activity and possible defenses. This predates the later period in which Dogly had substantially stronger application observability, so detection at the time was more manual.\n\nNot yet established for recruiter use: operational or user impact, email or resource consumption, attack mechanism, specific mitigations Jared implemented, how remediation was validated, and observed outcome.",
      short_body: "Private candidate: Jared noticed suspicious bot-created users in the Dogly admin index around 2022 and investigated. Remediation, impact, and outcome still require confirmation.",
      entry_type: "incident_story", approval_status: "needs_review", visibility: "private",
      confidence: "jared_confirmed_partial", source_type: "jared_confirmed",
      source_reference: SOURCE_REFERENCE,
      source_fingerprint: Digest::SHA256.hexdigest(SOURCE_REFERENCE),
      metadata: {
        "evidence_classification" => "confirmed_partial_fact",
        "actual_provenance" => "Jared-confirmed context supplied for the production-readiness pass",
        "review_flags" => [ "incident_story_incomplete", "do_not_publish_without_remediation_and_outcome" ],
        "missing_fields" => [ "impact", "attack_mechanism", "investigation_steps", "mitigations", "validation", "outcome" ],
        "recruiter_evidence" => { "relationship" => "Dogly production incident investigation", "limitations" => "Remediation and outcome are not established; keep private and ineligible for retrieval." }
      }
    )
  end

  def down
    KnowledgeEntry.where(source_reference: SOURCE_REFERENCE, source_type: "jared_confirmed").delete_all
  end
end
