require "test_helper"

class AskJaredSubmissionServiceTest < ActiveSupport::TestCase
  setup do
    AskToken.delete_all
    Opportunity.delete_all
    @service = AskJared::TokenService.new(secret: Rails.application.secret_key_base)
    @token, @raw_token = @service.mint!
  end

  test "marks the claimed opportunity submitted" do
    opportunity = AskJared::SubmissionService.new.call(
      raw_token: @raw_token, external_id: "role-submit-1", company: "Acme", role_title: "Engineer"
    )

    assert_equal "submitted", opportunity.application_state
    assert_not_nil opportunity.submitted_at
    assert_equal "submitted", @token.reload.status
    assert_equal opportunity, @token.opportunity
  end

  test "retries are idempotent for the same token and opportunity" do
    service = AskJared::SubmissionService.new
    first = service.call(raw_token: @raw_token, external_id: "role-submit-1", company: "Acme", role_title: "Engineer")
    second = service.call(raw_token: @raw_token, external_id: "role-submit-1", company: "Acme", role_title: "Engineer")

    assert_equal first, second
    assert_equal 1, Opportunity.count
  end

  test "rejects a changed company or role for an existing external ID" do
    service = AskJared::SubmissionService.new
    service.call(raw_token: @raw_token, external_id: "role-submit-1", company: "Acme", role_title: "Engineer")

    assert_raises(AskJared::SubmissionService::SubmissionConflict) do
      service.call(raw_token: @raw_token, external_id: "role-submit-1", company: "Other", role_title: "Engineer")
    end
  end

  test "rejects binding a second token to an existing opportunity" do
    other_token, other_raw = @service.mint!
    service = AskJared::SubmissionService.new
    service.call(raw_token: @raw_token, external_id: "role-submit-1", company: "Acme", role_title: "Engineer")

    assert_raises(AskJared::SubmissionService::SubmissionConflict) do
      service.call(raw_token: other_raw, external_id: "role-submit-1", company: "Acme", role_title: "Engineer")
    end
    assert_equal "available", other_token.reload.status
  end

  test "does not bind a direct-share token to a job-search opportunity" do
    direct_token, direct_raw = @service.mint_direct_share!

    assert_raises(ActiveRecord::RecordNotFound) do
      AskJared::SubmissionService.new.call(
        raw_token: direct_raw, external_id: "role-submit-direct", company: "Acme", role_title: "Engineer"
      )
    end
    assert_nil direct_token.reload.opportunity
    assert_equal "claimed", direct_token.status
  end
end
