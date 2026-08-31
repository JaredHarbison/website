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
end
