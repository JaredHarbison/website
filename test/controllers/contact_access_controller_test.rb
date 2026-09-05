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

    assert_redirected_to contact_path(anchor: "contact-message")
    event = EngagementEvent.find_by!(event_type: "contact_message_submitted")
    assert_equal "recruiter@example.com", event.metadata["email"]
    assert_equal "Let's talk.", event.metadata["message"]
    assert_nil event.metadata["token"]
    assert_nil event.metadata["token_digest"]
  end

  test "resume request is unavailable until an approved delivery capability exists" do
    get root_path, params: { t: @raw_token }
    post resume_verification_path, params: { email: "recruiter@example.com" }

    assert_redirected_to contact_path
    assert_includes flash[:resume_error], "not available"
    assert_nil ResumeVerification.order(:created_at).last
    assert_equal 0, EngagementEvent.where(event_type: "resume_verification_requested").count
  end

  test "an old verification link fails safely without the original browser session" do
    token = AskToken.joins(:opportunity).first
    raw = "verification-token"
    digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("SHA256"), Rails.application.secret_key_base, raw)
    verification = ResumeVerification.create!(opportunity: token.opportunity, ask_token: token, token_digest: digest, email: "recruiter@example.com", session_digest: "old-session", expires_at: 10.minutes.from_now)

    get resume_verification_confirmation_path(raw)

    assert_redirected_to contact_path
    assert_equal Time.current.to_i, verification.reload.verified_at.to_i
    assert_equal 1, EngagementEvent.where(event_type: "resume_email_verified").count
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
