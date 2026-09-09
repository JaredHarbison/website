require "test_helper"

class AskControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    EngagementEvent.delete_all
    AskToken.delete_all
    Opportunity.delete_all
    @token_service = AskJared::TokenService.new(secret: Rails.application.secret_key_base)
    token, @raw_token = @token_service.mint!
    @opportunity = @token_service.claim!(
      raw_token: @raw_token,
      external_id: "role-ask-1",
      company: "Acme",
      role_title: "Product Engineer"
    )
    assert_equal @opportunity, token.reload.opportunity
  end

  test "denies access without a valid claimed token" do
    get "/ask"

    assert_response :not_found
  end

  test "renders the recruiter experience for a claimed token" do
    get "/ask", params: { t: @raw_token }

    assert_response :success
    assert_select "h1", "Ask About Jared"
    assert_select "textarea[name='question']"
    assert_equal 1, EngagementEvent.where(event_type: "token_resolved").count
    assert_equal 1, EngagementEvent.where(event_type: "page_view").count
  end

  test "does not expose an available pool token" do
    _token, available_raw = @token_service.mint!

    get "/ask", params: { t: available_raw }

    assert_response :not_found
  end

  test "allows the authenticated admin to preview Ask Jared without a token" do
    admin = AdminUser.create!(email: "owner@example.com", password: "a-secure-password")
    sign_in admin

    get "/ask"

    assert_response :success
    assert_select "p", /owner session/
    assert_select "input[name='admin_preview'][value='1']"
    assert_select "input[name='architecture'][value='candidate-context-v2']"
    assert_select "[data-ask-unlimited='true']"
    assert_select "input[name='t'][value=?]", session[:ask_jared_admin_qa_token]
    assert_equal "internal_qa", AskToken.find_by(token_digest: AskJared::TokenService.new.digest(session[:ask_jared_admin_qa_token])).opportunity.tracker_source
    assert_select "input[name='authenticity_token']"
    assert_equal 0, EngagementEvent.count
  end

  test "removes a public token from the URL for an authenticated admin" do
    admin = AdminUser.create!(email: "owner@example.com", password: "a-secure-password")
    sign_in admin

    get "/ask", params: { t: @raw_token }

    assert_response :see_other
    assert_equal "/ask", URI(response.headers.fetch("Location")).request_uri
  end

  test "does not initialize an admin preview with the QA question limit" do
    admin = AdminUser.create!(email: "owner@example.com", password: "a-secure-password")
    sign_in admin
    get "/ask"
    qa_token = css_select("input[name='t']").first["value"]
    qa_opportunity = AskJared::TokenService.new.resolve(qa_token).opportunity
    4.times do |index|
      EngagementEvent.create!(
        opportunity: qa_opportunity,
        ask_token: qa_opportunity.ask_token,
        event_type: "question_submitted",
        event_key: "admin-limit-#{index}",
        session_digest: AskJared::EngagementService.new.session_digest(session.id.to_s),
        occurred_at: Time.current,
        meaningful: true,
        activity_class: "internal_qa"
      )
    end

    get "/ask"

    assert_select "[data-ask-question-count='0']"
  end

  test "renders the Ask About Jared state-transition contract" do
    get "/ask", params: { t: @raw_token }

    assert_response :success
    assert_select "[data-ask-controller][data-ask-endpoint='/api/ask/questions']"
    assert_select "[data-ask-controller][data-ask-question-count='0']"
    assert_select "[data-ask-controller][data-ask-unlimited='false']"
    assert_select "form[data-ask-form][action='/api/ask/questions']"
    assert_select "textarea[data-ask-question]"
    assert_select "button[data-ask-submit]", "Ask About Jared"
    assert_select "script[src*='ask']"
    refute_includes response.body, "evidence_ids"
  end

  test "Ask About Jared frontend owns safe asynchronous state transitions" do
    script = Rails.root.join("app/assets/javascripts/ask.js").read

    assert_includes script, "event.preventDefault()"
    assert_includes script, "fetch(endpoint"
    assert_includes script, "var formData = new FormData(form)"
    assert_includes script, "body: formData"
    assert_includes script, "response.json()"
    assert_includes script, "Finding evidence…"
    assert_includes script, "Ask another question"
    assert_includes script, "data-ask-history"
    assert_includes script, "var maxQuestions = unlimited ? Number.POSITIVE_INFINITY : 4;"
    assert_includes script, "turns.length >= maxQuestions"
    assert_includes script, "completedQuestionCount"
    assert_includes script, "appendTerminalHandoff"
    assert_includes script, "finishConversation"
    assert_includes script, "if (turn.answerEventId) addButton"
    assert_includes script, "We couldn’t send that report. Please try again."
    refute_includes script, "innerHTML"
    assert_includes Rails.root.join("app/assets/stylesheets/application.css").read, ".ask-form[hidden] { display: none; }"
  end

  test "the fourth response terminalizes regardless of visible response status" do
    script = Rails.root.join("app/assets/javascripts/ask.js").read

    assert_includes script, "if (turns.length >= maxQuestions) {"
    assert_includes script, "appendTerminalHandoff();"
    assert_includes script, "finishConversation();"
  end

  test "renders a manual direct-share token through the normal opportunity lifecycle" do
    opportunity, _token, raw = AskJared::ManualShareService.new.create!(label: "Portfolio review", purpose: "General introduction")

    get "/ask", params: { t: raw }

    assert_response :success
    assert_equal "manual", opportunity.reload.tracker_source
    assert_equal "pre_application", opportunity.application_state
  end

  test "carries a valid prospect token from the homepage into Ask" do
    get "/", params: { t: @raw_token }
    assert_response :success

    get "/ask"
    assert_response :success
    assert_select "input[name='t'][value=?]", @raw_token
  end
end
