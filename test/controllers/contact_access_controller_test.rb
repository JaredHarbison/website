require "test_helper"

class ContactAccessControllerTest < ActionDispatch::IntegrationTest
  setup do
    EngagementEvent.delete_all
    ResumeVerification.delete_all
    AskToken.delete_all
    Opportunity.delete_all
    service = AskJared::TokenService.new
    _token, @raw_token = service.mint!
    service.claim!(raw_token: @raw_token, external_id: "contact-role", company: "Acme", role_title: "Engineer")
  end

  test "contact stays simple without token access" do
    get contact_path

    assert_response :success
    assert_select ".contact-recruiter-panel", 0
  end

  test "valid prospect access can send a message without changing prior activity identity" do
    get root_path, params: { t: @raw_token }
    post contact_message_path, params: { name: "Recruiter", email: "recruiter@example.com", message: "Let's talk." }

    assert_redirected_to contact_path
    event = EngagementEvent.find_by!(event_type: "contact_message_submitted")
    assert_equal "recruiter@example.com", event.metadata["email"]
    assert_equal "Let's talk.", event.metadata["message"]
    assert_nil event.metadata["token"]
    assert_nil event.metadata["token_digest"]
  end

  test "resume request requires active token and records a verification request" do
    get root_path, params: { t: @raw_token }
    post resume_verification_path, params: { email: "recruiter@example.com" }

    assert_redirected_to contact_path
    verification = ResumeVerification.order(:created_at).last
    assert verification.active?
    assert_equal 1, EngagementEvent.where(event_type: "resume_verification_requested").count
  end

  test "the fifth Ask question is blocked for one prospect browser session" do
    4.times do
      post "/api/ask/questions", params: { question: "What kind of engineer is Jared?" }, headers: { "X-Ask-Token" => @raw_token }
      assert_response :success
    end

    post "/api/ask/questions", params: { question: "What kind of engineer is Jared?" }, headers: { "X-Ask-Token" => @raw_token }
    assert_response :too_many_requests
    assert_equal "blocked", response.parsed_body["status"]
  end
end
