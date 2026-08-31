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

    assert_difference("AskToken.where(access_scope: 'direct_share').count", 1) do
      post "/admin/share_links"
    end

    assert_redirected_to "/admin"
    assert_match(%r{/ask\?t=}, flash[:direct_share_link])
  end

  test "anonymous users cannot create a direct-share link" do
    post "/admin/share_links"

    assert_response :redirect
    assert_empty AskToken.where(access_scope: "direct_share")
  end
end
