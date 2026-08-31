require "test_helper"

class Api::JobSearch::EngagementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_key = ENV["JOB_SEARCH_READ_SYNC_TOKEN"]
    ENV["JOB_SEARCH_READ_SYNC_TOKEN"] = "test-read-key"
  end

  teardown do
    ENV["JOB_SEARCH_READ_SYNC_TOKEN"] = @previous_key
  end

  test "requires the separate read credential" do
    get "/api/job_search/opportunities/engagements"

    assert_response :unauthorized
  end

  test "returns safe aggregate engagement summaries" do
    Opportunity.create!(external_id: "role-read-1", company: "Acme", role_title: "Engineer")

    get "/api/job_search/opportunities/engagements", headers: { "X-Job-Search-Read-Key" => "test-read-key" }

    assert_response :success
    assert_equal "ok", response.parsed_body.fetch("status")
    assert_equal "role-read-1", response.parsed_body.fetch("opportunities").first.fetch("external_id")
    refute response.body.include?("session_digest")
    refute response.body.include?("ip_digest")
  end
end
