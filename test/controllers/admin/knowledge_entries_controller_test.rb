require "test_helper"

class Admin::KnowledgeEntriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    KnowledgeEntry.delete_all
    AdminUser.delete_all
    @admin = AdminUser.create!(email: "jared@example.com", password: "a-secure-password")
    @entry = KnowledgeEntry.create!(
      title: "Candidate project",
      body: "Private evidence",
      entry_type: "project",
      source_type: "anecdote",
      source_reference: "ANECDOTE-1",
      source_fingerprint: "fingerprint-1"
    )
  end

  test "requires Jared authentication" do
    get "/admin"

    assert_response :redirect
    assert_redirected_to "/admin/session/sign_in"
  end

  test "Jared can review an entry" do
    sign_in @admin

    get "/admin/knowledge_entries"
    assert_response :success
    assert_select "h2", "Candidate project"

    patch "/admin/knowledge_entries/#{@entry.id}", params: {
      knowledge_entry: { approval_status: "approved", visibility: "recruiter_visible", reviewer_note: "Verified" }
    }

    assert_redirected_to "/admin/knowledge_entries"
    @entry.reload
    assert_equal "approved", @entry.approval_status
    assert_equal "recruiter_visible", @entry.visibility
    assert_equal "Verified", @entry.reviewer_note
    assert_equal "jared@example.com", @entry.reviewed_by
    assert_not_nil @entry.approved_at
  end

  test "admin review never exposes private token material" do
    sign_in @admin

    get "/admin"
    assert_response :success
    assert_no_match(/token_digest/, response.body)
  end
end
