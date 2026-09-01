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
    assert_select "input[name='authenticity_token']"
    assert_equal 0, EngagementEvent.count
  end

  test "renders the Ask About Jared state-transition contract" do
    get "/ask", params: { t: @raw_token }

    assert_response :success
    assert_select "[data-ask-controller][data-ask-endpoint='/api/ask/questions']"
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
    assert_includes script, "response.json()"
    assert_includes script, "Finding evidence…"
    assert_includes script, "Ask another question"
    assert_includes script, "replaceChildren(form)"
    assert_includes script, "text.textContent = answer"
    refute_includes script, "innerHTML"
  end

  test "renders a manual direct-share token through the normal opportunity lifecycle" do
    opportunity, _token, raw = AskJared::ManualShareService.new.create!(label: "Portfolio review", purpose: "General introduction")

    get "/ask", params: { t: raw }

    assert_response :success
    assert_equal "manual", opportunity.reload.tracker_source
    assert_equal "pre_application", opportunity.application_state
  end
end
