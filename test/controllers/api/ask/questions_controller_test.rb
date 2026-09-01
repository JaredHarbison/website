require "test_helper"

class ApiAskQuestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    EngagementEvent.delete_all
    AskToken.delete_all
    Opportunity.delete_all
    token_service = AskJared::TokenService.new
    _token, @raw_token = token_service.mint!
    token_service.claim!(raw_token: @raw_token, external_id: "role-api-1", company: "Acme", role_title: "Engineer")
  end

  test "requires a valid claimed token" do
    post "/api/ask/questions", params: { question: "What kind of engineer is Jared?" }

    assert_response :unprocessable_entity
    assert_equal "blocked", response.parsed_body["status"]
  end

  test "returns a structured response for a valid token" do
    post "/api/ask/questions", params: { question: "What kind of engineer is Jared?" }, headers: { "X-Ask-Token" => @raw_token }

    assert_response :success
    assert_equal "insufficient_information", response.parsed_body["status"]
    assert_kind_of Array, response.parsed_body["evidence_ids"]
  end

  test "accepts the recruiter form when the browser sends a null origin" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    post "/api/ask/questions",
      params: { t: @raw_token, question: "What kind of engineer is Jared?" },
      headers: { "Origin" => "null" }

    assert_response :success
    assert_equal "insufficient_information", response.parsed_body["status"]
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
