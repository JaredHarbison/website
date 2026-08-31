require "test_helper"

class AskJaredUsageGuardTest < ActiveSupport::TestCase
  setup do
    AskUsageEvent.delete_all
    AskToken.delete_all
    Opportunity.delete_all
    service = AskJared::TokenService.new
    @token_record, @raw_token = service.mint!
    service.claim!(raw_token: @raw_token, external_id: "role-usage", company: "Acme", role_title: "Engineer")
    @guard = AskJared::UsageGuard.new(now: Time.current, daily_cost_cents: 2)
  end

  test "allows usage under token, session, and daily limits" do
    assert_nil @guard.check!(token: @token_record.reload, session_digest: "session-1")
  end

  test "enforces the daily cost ceiling" do
    2.times do |number|
      @guard.record!(token: @token_record.reload, session_digest: "session-#{number}", request_id: "request-#{number}", status: "completed", estimated_cost_cents: 1)
    end

    assert_raises(AskJared::UsageGuard::LimitExceeded) { @guard.check!(token: @token_record.reload, session_digest: "new-session") }
  end

  test "records usage idempotently by request id" do
    first = @guard.record!(token: @token_record.reload, session_digest: "session-1", request_id: "same-request", status: "completed", estimated_cost_cents: 1)
    second = @guard.record!(token: @token_record.reload, session_digest: "session-1", request_id: "same-request", status: "completed", estimated_cost_cents: 1)

    assert_equal first.id, second.id
    assert_equal 1, AskUsageEvent.count
  end
end
