require "test_helper"

class AskControllerTest < ActionDispatch::IntegrationTest
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
    assert_select "h1", "Ask Jared"
    assert_select "textarea[name='question']"
    assert_equal 1, EngagementEvent.where(event_type: "token_resolved").count
    assert_equal 1, EngagementEvent.where(event_type: "page_view").count
  end

  test "does not expose an available pool token" do
    _token, available_raw = @token_service.mint!

    get "/ask", params: { t: available_raw }

    assert_response :not_found
  end
end
