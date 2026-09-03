require "test_helper"

class Admin::OperationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    AdminUser.delete_all
    EngagementEvent.delete_all
    @admin = AdminUser.create!(email: "jared@example.com", password: "a-secure-password")
    @opportunity = Opportunity.create!(external_id: "ops-role", company: "Acme", role_title: "Engineer")
    @token = AskToken.create!(token_digest: "ops-digest", token_prefix: "ops", status: "claimed", opportunity: @opportunity)
  end

  test "admin overview links operational areas" do
    sign_in @admin
    get "/admin"

    assert_response :success
    assert_select "a", text: "Feedback / issues"
    assert_select "a", text: "System"
    assert_includes response.body, "Prospect access"

    get "/admin/system"
    assert_response :success
    assert_includes response.body, "gpt-5.6-terra"
  end

  test "admin issue list and detail preserve diagnostics privately" do
    event = EngagementEvent.create!(
      opportunity: @opportunity, ask_token: @token, event_type: "issue_reported", event_key: "ops-issue",
      session_digest: "private-session", occurred_at: Time.current, meaningful: true,
      metadata: { "issue_category" => "Confusing answer", "feedback" => "More context", "question" => "Q", "answer" => "A", "question_intent" => "learning", "evidence_ids" => [ "story:test" ] }
    )
    sign_in @admin

    get "/admin/issues"
    assert_response :success
    assert_includes response.body, "Confusing answer"
    get "/admin/issues/#{event.id}"
    assert_response :success
    assert_includes response.body, "story:test"
    assert_no_match(/token_digest|private-session/, response.body)
  end

  test "admin can update issue status" do
    event = EngagementEvent.create!(opportunity: @opportunity, ask_token: @token, event_type: "issue_reported", event_key: "ops-status", session_digest: "status-session", occurred_at: Time.current, meaningful: true, metadata: {})
    sign_in @admin

    patch "/admin/issues/#{event.id}", params: { engagement_event: { issue_status: "reviewed" } }

    assert_redirected_to "/admin/issues/#{event.id}"
    assert_equal "reviewed", event.reload.metadata["issue_status"]
  end
end
