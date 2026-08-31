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
end
