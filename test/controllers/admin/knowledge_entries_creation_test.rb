require "test_helper"

class Admin::KnowledgeEntriesCreationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    AdminUser.delete_all
    KnowledgeEntry.delete_all
    @admin = AdminUser.create!(email: "jared@example.com", password: "a-secure-password")
  end

  test "manual knowledge creation enters the private candidate lifecycle" do
    sign_in @admin

    assert_difference("KnowledgeEntry.count", 1) do
      post "/admin/knowledge_entries", params: {
        knowledge_entry: {
          title: "A reviewed candidate",
          body: "Factual material for Jared to review.",
          short_body: "Candidate summary.",
          entry_type: "fact",
          source_reference: "manual-review-1"
        }
      }
    end

    assert_redirected_to "/admin/knowledge_entries"
    entry = KnowledgeEntry.order(:created_at).last
    assert_equal "candidate", entry.approval_status
    assert_equal "private", entry.visibility
    assert_equal "admin_manual", entry.source_type
    assert_equal [], entry.metadata.dig("recruiter_evidence", "claims")
    assert_equal "REQUIRES_JARED_FACTUAL_REVIEW", entry.metadata.dig("human_review", "status")
    assert_nil entry.embedding
  end
end
