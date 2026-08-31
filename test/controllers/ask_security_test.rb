require "test_helper"

class AskSecurityTest < ActionDispatch::IntegrationTest
  setup do
    AskToken.delete_all
    Opportunity.delete_all
    service = AskJared::TokenService.new(secret: Rails.application.secret_key_base)
    @token, @raw_token = service.mint!
    service.claim!(raw_token: @raw_token, external_id: "security-role", company: "Acme", role_title: "Engineer")
  end

  test "tokenized Ask pages are private, non-cacheable, and do not leak referrers" do
    get "/ask", params: { t: @raw_token }

    assert_response :success
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_equal "noindex, nofollow, noarchive", response.headers["X-Robots-Tag"]
    assert_equal "no-cache", response.headers["Cache-Control"]
    assert_select "meta[name='robots'][content='noindex, nofollow, noarchive']"
    assert_select "input[name='t'][value=?]", @raw_token
  end
end
