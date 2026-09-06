require "test_helper"

class ApiAskQuestionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

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

  test "persists the browser session used for continuation state" do
    post "/api/ask/questions", params: { question: "What kind of engineer is Jared?" }, headers: { "X-Ask-Token" => @raw_token }

    assert_response :success
    assert response.headers["Set-Cookie"].present?
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

  test "accepts the admin preview form with a valid token and null origin" do
    admin = AdminUser.create!(email: "owner@example.com", password: "password123456")
    sign_in admin
    get "/ask"
    csrf_token = css_select("input[name='authenticity_token']").first["value"]
    assert csrf_token.present?
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    post "/api/ask/questions",
      params: {
        admin_preview: "1",
        authenticity_token: csrf_token,
        question: "What kind of engineer is Jared?"
      },
      headers: { "Origin" => "null" }

    assert_response :success
    assert_equal "insufficient_information", response.parsed_body["status"]
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "does not accept an admin preview form with an invalid token and null origin" do
    admin = AdminUser.create!(email: "owner@example.com", password: "password123456")
    sign_in admin
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    post "/api/ask/questions",
      params: {
        admin_preview: "1",
        authenticity_token: "invalid",
        question: "What kind of engineer is Jared?"
      },
      headers: { "Origin" => "null" }

    assert_response :unprocessable_entity
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "enforces the four-question conversation cap server-side" do
    4.times do |index|
      post "/api/ask/questions", params: { question: "Question #{index + 1}" }, headers: { "X-Ask-Token" => @raw_token }
      assert_response :success
    end

    post "/api/ask/questions", params: { question: "Question five" }, headers: { "X-Ask-Token" => @raw_token }

    assert_response :too_many_requests
    assert_equal "blocked", response.parsed_body["status"]
    assert_equal 4, EngagementEvent.where(event_type: "question_submitted").count
  end

  test "ignores candidate architecture selection from an unauthenticated public request" do
    post "/api/ask/questions", params: { question: "What kind of engineer is Jared?", architecture: "candidate-context-v1" }, headers: { "X-Ask-Token" => @raw_token }

    assert_response :success
    event = EngagementEvent.where(event_type: "answer_returned").order(:id).last
    assert_equal "baseline-v1", event.metadata["architecture"]
    assert_nil event.metadata["planner_version"]
  end
end
