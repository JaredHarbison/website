require "test_helper"

class Admin::OpportunitiesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    Opportunity.delete_all
    AdminUser.delete_all
    @admin = AdminUser.create!(email: "jared@example.com", password: "a-secure-password")
    @opportunity = Opportunity.create!(external_id: "role-admin-1", company: "Acme", role_title: "Engineer")
  end

  test "requires Jared authentication" do
    get "/admin/opportunities"

    assert_response :redirect
  end

  test "shows aggregate recruiter intelligence" do
    sign_in @admin

    get "/admin/opportunities"

    assert_response :success
    assert_select "h2", "Acme · Engineer"
    assert_no_match(/session_digest|ip_digest|token_digest/, response.body)
  end

  test "shows an opportunity detail page" do
    sign_in @admin

    get "/admin/opportunities/#{@opportunity.id}"

    assert_response :success
    assert_select "h1", "Acme · Engineer"
  end
end
