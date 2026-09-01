require "test_helper"

class KnowledgeEntryTest < ActiveSupport::TestCase
  setup do
    KnowledgeEntry.delete_all
  end

  def entry(status:, visibility:)
    KnowledgeEntry.create!(
      title: "Entry",
      body: "Approved professional evidence.",
      entry_type: "project",
      approval_status: status,
      visibility: visibility,
      source_type: "public_site",
      source_reference: "entry-#{status}-#{visibility}",
      source_fingerprint: SecureRandom.hex(8)
    )
  end

  test "only approved recruiter-visible entries are retrievable" do
    visible = entry(status: "approved", visibility: "recruiter_visible")
    entry(status: "approved", visibility: "internal")
    entry(status: "candidate", visibility: "private")
    entry(status: "needs_review", visibility: "recruiter_visible")

    assert_equal [ visible ], KnowledgeEntry.recruiter_retrievable.to_a
  end

  test "accepts candidate and needs-review workflow states" do
    assert_predicate entry(status: "candidate", visibility: "private"), :valid?
    assert_predicate entry(status: "needs_review", visibility: "internal"), :valid?
  end

  test "projects leadership and collaboration without implying sole authorship or people management" do
    record = entry(status: "approved", visibility: "recruiter_visible")
    record.update!(title: "Project", short_body: "A concise project summary.", metadata: {
      "ownership" => { "leadership" => "project_lead", "sole_authorship" => "not established", "people_management" => "not established" },
      "personal_contributions" => "Designed and implemented the core workflow.",
      "collaborators" => "Founders and domain experts"
    }.merge("recruiter_evidence" => {
      "ownership" => { "leadership" => "project_lead", "sole_authorship" => "not established", "people_management" => "not established", "personal_contributions" => "Designed and implemented the core workflow.", "collaborators" => "Founders and domain experts" }
    }))

    context = record.recruiter_context

    assert_includes context, "leadership=project_lead"
    assert_includes context, "sole_authorship=not established"
    assert_includes context, "people_management=not established"
    assert_includes context, "Collaborators: Founders and domain experts"
    refute_includes context, "private"
  end

  test "includes bounded limitations, outside-project relationship, type, and safe attribution" do
    record = entry(status: "approved", visibility: "recruiter_visible")
    record.update!(entry_type: "project", short_body: "Built an evidence-aware prototype.", metadata: {
      "recruiter_evidence" => {
        "relationship" => "Independent project outside Dogly",
        "limitations" => "Outcome measurement is unavailable.",
        "safe_attribution" => "Do not claim a measured business result.",
        "status" => "Prototype; roadmap work is separate."
      },
      "private_source_material" => "must not appear"
    })

    context = record.recruiter_context

    assert_includes context, "Entry type: project"
    assert_includes context, "Relationship: Independent project outside Dogly"
    assert_includes context, "Evidence limitations: Outcome measurement is unavailable."
    assert_includes context, "Safe attribution: Do not claim a measured business result."
    assert_includes context, "Status: Prototype; roadmap work is separate."
    refute_includes context, "must not appear"
  end

  test "distinguishes project evidence from metric evidence in the projection" do
    project = entry(status: "approved", visibility: "recruiter_visible")
    metric = KnowledgeEntry.create!(title: "Metric", body: "Metric evidence.", short_body: "A bounded comparison.", entry_type: "metric",
                                    approval_status: "approved", visibility: "recruiter_visible", source_type: "code",
                                    source_reference: "metric-1", source_fingerprint: "fp-metric")

    assert_includes project.recruiter_context, "Entry type: project"
    assert_includes metric.recruiter_context, "Entry type: metric"
  end
end
