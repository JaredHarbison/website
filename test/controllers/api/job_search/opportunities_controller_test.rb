require "test_helper"

class Api::JobSearch::OpportunitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    AskToken.delete_all
    Opportunity.delete_all
    @previous_key = ENV["JOB_SEARCH_SYNC_TOKEN"]
    ENV["JOB_SEARCH_SYNC_TOKEN"] = "test-sync-key"
    @token_service = AskJared::TokenService.new(secret: Rails.application.secret_key_base)
    @token, @raw_token = @token_service.mint!
  end

  teardown do
    ENV["JOB_SEARCH_SYNC_TOKEN"] = @previous_key
  end

  test "rejects requests without the scoped machine credential" do
    post "/api/job_search/opportunities/submit", params: { raw_token: @raw_token }

    assert_response :unauthorized
    assert_empty Opportunity.all
  end

  test "submits an opportunity and returns the usable AskLink" do
    post "/api/job_search/opportunities/submit",
         params: { raw_token: @raw_token, external_id: "role-api-1", company: "Acme", role_title: "Engineer" },
         headers: { "X-Job-Search-Key" => "test-sync-key", "Idempotency-Key" => "role-api-1:2026-08-31" }

    assert_response :success
    assert_equal "submitted", response.parsed_body.fetch("status")
    assert_includes response.parsed_body.fetch("ask_link"), "/?t="
    assert_includes response.parsed_body.fetch("ask_link"), "t=#{ERB::Util.url_encode(@raw_token)}"
    assert_equal "submitted", @token.reload.status
  end

  test "repeated submission is harmless" do
    headers = { "X-Job-Search-Key" => "test-sync-key", "Idempotency-Key" => "role-api-1:2026-08-31" }
    params = { raw_token: @raw_token, external_id: "role-api-1", company: "Acme", role_title: "Engineer" }
    post "/api/job_search/opportunities/submit", params: params, headers: headers
    post "/api/job_search/opportunities/submit", params: params, headers: headers

    assert_response :success
    assert_equal 1, Opportunity.count
  end
end
