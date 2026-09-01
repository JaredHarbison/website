class KnowledgeEntry < ApplicationRecord
  ENTRY_TYPES = %w[
    fact project engineering_story product_story metric capability tradeoff
    debugging_story leadership_story integration_story performance_story
    incident_story career_context interview_story
  ].freeze
  APPROVAL_STATUSES = %w[candidate needs_review approved rejected].freeze
  VISIBILITIES = %w[private internal recruiter_visible].freeze

  validates :title, :body, :entry_type, :source_type, :source_reference,
            :source_fingerprint, presence: true
  validates :entry_type, inclusion: { in: ENTRY_TYPES }
  validates :approval_status, inclusion: { in: APPROVAL_STATUSES }
  validates :visibility, inclusion: { in: VISIBILITIES }

  scope :recruiter_retrievable, -> { where(approval_status: "approved", visibility: "recruiter_visible") }

  def recruiter_context
    evidence = metadata.fetch("recruiter_evidence", {})
    [
      title,
      "Entry type: #{entry_type}",
      "Summary: #{short_body.presence || body}",
      labeled_context("Relationship", evidence["relationship"]),
      ownership_context(evidence["ownership"]),
      labeled_context("Personal contributions", evidence["personal_contributions"]),
      labeled_context("Collaborators", evidence["collaborators"]),
      labeled_context("Demonstrated competencies", evidence["competencies"]),
      labeled_context("Result", evidence["result"]),
      labeled_context("Product learning", evidence["product_learning"]),
      labeled_context("Evidence limitations", evidence["limitations"]),
      labeled_context("Safe attribution", evidence["safe_attribution"]),
      labeled_context("Status", evidence["status"])
    ].compact_blank.join("\n")
  end

  private

  def ownership_context(ownership)
    return if ownership.blank?

    values = [
      "leadership=#{ownership["leadership"]}",
      "sole_authorship=#{ownership["sole_authorship"]}",
      "people_management=#{ownership["people_management"]}"
    ].compact_blank.join(", ")
    [ "Ownership: #{values}", labeled_context("Personal contributions", ownership["personal_contributions"]), labeled_context("Collaborators", ownership["collaborators"]) ].compact_blank.join("; ")
  end

  def labeled_context(label, value)
    values = Array(value).compact_blank
    return if values.empty?

    "#{label}: #{values.join('; ')}"
  end
end
