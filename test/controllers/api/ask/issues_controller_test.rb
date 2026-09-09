require "test_helper"

class ApiAskIssuesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    EngagementEvent.delete_all
    AskToken.delete_all
    Opportunity.delete_all
    _token, @raw_token = AskJared::TokenService.new.mint!
    AskJared::TokenService.new.claim!(raw_token: @raw_token, external_id: "issue-api", company: "Acme", role_title: "Engineer")
  end

  test "reports the exact insufficient response while preserving the browser session" do
    post "/api/ask/questions", params: { t: @raw_token, question: "What kind of engineer is Jared?" }

    assert_response :success
    answer_event_id = response.parsed_body.fetch("answer_event_id")
    assert_equal "insufficient_information", response.parsed_body.fetch("status")

    post "/api/ask/issues", params: {
      t: @raw_token, answer_event_id: answer_event_id, category: "Technical issue", feedback: "The response was unexpectedly empty.", contact: ""
    }

    assert_response :success
    issue = EngagementEvent.find(response.parsed_body.fetch("report_id"))
    assert_equal answer_event_id.to_i, issue.metadata.fetch("answer_event_id").to_i
    assert_equal "insufficient_information", issue.metadata.fetch("answer_status")
  end

  test "rejects an answer event from another authorized token" do
    post "/api/ask/questions", params: { t: @raw_token, question: "What kind of engineer is Jared?" }
    answer_event_id = response.parsed_body.fetch("answer_event_id")

    _other_token, other_raw = AskJared::TokenService.new.mint!
    AskJared::TokenService.new.claim!(raw_token: other_raw, external_id: "other-issue-api", company: "Other", role_title: "Engineer")
    post "/api/ask/issues", params: { t: other_raw, answer_event_id: answer_event_id, category: "Technical issue", feedback: "Tampered", contact: "" }

    assert_response :unprocessable_entity
    assert_equal "We couldn’t send that report. Please try again.", response.parsed_body.fetch("message")
  end

  test "allows an authenticated admin to report an issue against the QA preview" do
    admin = AdminUser.create!(email: "owner@example.com", password: "password123456")
    sign_in admin
    get "/ask"
    csrf_token = css_select("input[name='authenticity_token']").first["value"]
    qa_token = css_select("input[name='t']").first["value"]

    post "/api/ask/questions",
      params: { admin_preview: "1", t: qa_token, authenticity_token: csrf_token, question: "What kind of engineer is Jared?" },
      headers: { "Origin" => "null" }
    answer_event_id = response.parsed_body.fetch("answer_event_id")

    post "/api/ask/issues", params: {
      t: qa_token, authenticity_token: csrf_token, answer_event_id: answer_event_id,
      category: "Technical issue", feedback: "The owner preview needs a closer look.", contact: ""
    }

    assert_response :success
    issue = EngagementEvent.find(response.parsed_body.fetch("report_id"))
    assert_equal "internal_qa", issue.activity_class
    assert_equal "internal_qa", issue.opportunity.tracker_source
  end
end
