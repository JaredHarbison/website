require "test_helper"

class ApiAskIssuesControllerTest < ActionDispatch::IntegrationTest
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
    assert_equal "answer exchange is invalid or unavailable", response.parsed_body.fetch("message")
  end
end
