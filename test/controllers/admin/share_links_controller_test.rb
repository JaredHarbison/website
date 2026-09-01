require "test_helper"

class Admin::ShareLinksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    AdminUser.delete_all
    AskToken.delete_all
    @admin = AdminUser.create!(email: "owner@example.com", password: "a-secure-password")
  end

  test "owner can create a direct-share link" do
    sign_in @admin

    assert_difference("Opportunity.where(tracker_source: 'manual').count", 1) do
      post "/admin/share_links", params: { label: "Portfolio review", purpose: "General engineering introduction" }
    end

    assert_redirected_to "/admin"
    assert_match(%r{/ask\?t=}, flash[:direct_share_link])

    follow_redirect!

    assert_select ".admin-generated-link code", %r{/ask\?t=}
  end

  test "anonymous users cannot create a direct-share link" do
    post "/admin/share_links"

    assert_response :redirect
    assert_empty Opportunity.where(tracker_source: "manual")
  end

  test "owner can revoke a manual link without affecting application links" do
    opportunity, = AskJared::ManualShareService.new.create!(label: "Portfolio review", purpose: "General introduction")
    application_opportunity = Opportunity.create!(external_id: "application-1", company: "Acme", role_title: "Engineer")
    sign_in @admin

    delete "/admin/share_links/#{opportunity.id}"

    assert_redirected_to "/admin"
    assert_equal "revoked", opportunity.ask_token.reload.status
    assert_nil application_opportunity.reload.ask_token
  end
end
