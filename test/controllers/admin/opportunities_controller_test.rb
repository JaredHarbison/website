require "test_helper"

class Admin::OpportunitiesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @previous_analytics_boundary = ENV[AskJared::AnalyticsBoundary::ENV_KEY]
    ENV[AskJared::AnalyticsBoundary::ENV_KEY] = 1.hour.ago.iso8601
    Opportunity.delete_all
    AdminUser.delete_all
    @admin = AdminUser.create!(email: "jared@example.com", password: "a-secure-password")
    @opportunity = Opportunity.create!(external_id: "role-admin-1", company: "Acme", role_title: "Engineer")
    EngagementEvent.create!(opportunity: @opportunity, event_type: "question_submitted", event_key: "admin-question", session_digest: "admin-session", activity_class: "unclassified", occurred_at: 1.minute.ago, meaningful: true)
  end

  teardown do
    ENV[AskJared::AnalyticsBoundary::ENV_KEY] = @previous_analytics_boundary
  end

  test "requires Jared authentication" do
    get "/admin/opportunities"

    assert_response :redirect
  end

  test "shows aggregate recruiter intelligence" do
    sign_in @admin

    get "/admin/opportunities"

    assert_response :success
    assert_select "a.admin-table__primary", "Acme · Engineer"
    assert_no_match(/session_digest|ip_digest|token_digest/, response.body)
  end

  test "shows an opportunity detail page" do
    sign_in @admin

    get "/admin/opportunities/#{@opportunity.id}"

    assert_response :success
    assert_select "h1", "Acme · Engineer"
  end

  test "access-link search exposes a clearable query form" do
    sign_in @admin

    get "/admin/access-links", params: { q: "Acme" }

    assert_response :success
    assert_select "form[data-access-links-search] input[data-access-links-query][value=?]", "Acme"
  end
end
