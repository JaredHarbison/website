require "test_helper"

class Admin::AnalyticsIsolationControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @previous_analytics_boundary = ENV[AskJared::AnalyticsBoundary::ENV_KEY]
    ENV[AskJared::AnalyticsBoundary::ENV_KEY] = 1.hour.ago.iso8601
    EngagementEvent.delete_all
    AskToken.delete_all
    Opportunity.delete_all
    AdminUser.delete_all
    @admin = AdminUser.create!(email: "jared@example.com", password: "a-secure-password")
    @real = Opportunity.create!(external_id: "real-prospect", company: "Real Company", role_title: "Engineer", tracker_source: "manual")
    @qa = Opportunity.create!(external_id: "internal-qa", company: "Internal QA", role_title: "QA", tracker_source: "internal_qa")
    create_event(@real, "question_submitted", "real-question", { "question" => "Real question" })
    create_event(@real, "answer_returned", "real-answer", { "answer" => "Real answer" })
    create_event(@real, "issue_reported", "real-issue", { "issue_category" => "Technical issue", "feedback" => "Real issue" })
    create_event(@qa, "question_submitted", "qa-question", { "question" => "QA question" })
    create_event(@qa, "answer_returned", "qa-answer", { "answer" => "QA answer" })
    create_event(@qa, "issue_reported", "qa-issue", { "issue_category" => "Technical issue", "feedback" => "QA issue" })
  end

  teardown do
    ENV[AskJared::AnalyticsBoundary::ENV_KEY] = @previous_analytics_boundary
  end

  test "dashboard headline counts exclude QA activity" do
    sign_in @admin

    get "/admin"

    assert_response :success
    assert_select ".admin-summary-card__value", text: "1", count: 4
    assert_includes response.body, "Internal / QA"
  end

  test "prospect and QA activity are deliberately separated" do
    sign_in @admin

    get "/admin/opportunities"
    assert_response :success
    assert_includes response.body, "real-prospect"
    refute_includes response.body, "internal-qa"

    get "/admin/opportunities", params: { activity_class: "internal_qa" }
    assert_response :success
    assert_includes response.body, "internal-qa"
    refute_includes response.body, "real-prospect"

    get "/admin/issues"
    assert_response :success
    assert_includes response.body, "Real issue"
    refute_includes response.body, "QA issue"

    get "/admin/issues", params: { activity_class: "internal_qa" }
    assert_response :success
    assert_includes response.body, "QA issue"
    refute_includes response.body, "Real issue"
  end

  test "pre-launch non-QA activity is excluded from default analytics" do
    ENV[AskJared::AnalyticsBoundary::ENV_KEY] = 1.minute.from_now.iso8601

    sign_in @admin
    get "/admin"

    assert_select ".admin-summary-card__value", text: "0", count: 4
    get "/admin/issues"
    assert_includes response.body, "No issues match this filter"
  end

  private

  def create_event(opportunity, event_type, event_key, metadata)
    EngagementEvent.create!(
      opportunity: opportunity,
      event_type: event_type,
      event_key: event_key,
      session_digest: "session-#{opportunity.external_id}",
      activity_class: opportunity.tracker_source == "internal_qa" ? "internal_qa" : "manual_share",
      metadata: metadata,
      occurred_at: Time.current,
      meaningful: true
    )
  end
end
