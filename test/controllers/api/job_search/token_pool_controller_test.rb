require "test_helper"

class Api::JobSearch::TokenPoolControllerTest < ActionDispatch::IntegrationTest
  setup do
    AskToken.delete_all
    @previous_key = ENV["JOB_SEARCH_TOKEN_POOL_TOKEN"]
    ENV["JOB_SEARCH_TOKEN_POOL_TOKEN"] = "test-pool-key"
  end

  teardown do
    ENV["JOB_SEARCH_TOKEN_POOL_TOKEN"] = @previous_key
  end

  test "rejects an unauthorized pool refill" do
    post "/api/job_search/token_pool/refill", params: { sheet_available_count: 0, target: 1 }

    assert_response :unauthorized
  end

  test "returns raw values only through the authorized delivery response" do
    post "/api/job_search/token_pool/refill", params: { sheet_available_count: 0, target: 2 },
         headers: { "X-Job-Search-Pool-Key" => "test-pool-key" }

    assert_response :success
    body = response.parsed_body
    assert_equal 2, body.fetch("tokens").length
    body.fetch("tokens").each do |exported|
      record = AskToken.find(exported.fetch("inventory_id"))
      assert_equal "available", record.status
      assert_not_includes record.attributes.values, exported.fetch("token")
    end
  end
end
