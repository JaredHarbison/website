require "test_helper"
require_relative "../../app/services/ask_jared/token_service"
require_relative "../../app/services/ask_jared/token_pool"

class AskJaredTokenServiceTest < ActiveSupport::TestCase
  setup do
    AskToken.delete_all
    Opportunity.delete_all
    @service = AskJared::TokenService.new(secret: "test-secret")
  end

  test "stores only a digest and resolves a minted token" do
    record, raw = @service.mint!

    assert_not_equal raw, record.token_digest
    assert_equal record, @service.resolve(raw)
    assert_nil @service.resolve("not-a-token")
  end

  test "claims a token idempotently for an external opportunity" do
    record, raw = @service.mint!
    first = @service.claim!(raw_token: raw, external_id: "role-1", company: "Acme", role_title: "Engineer")
    second = @service.claim!(raw_token: raw, external_id: "role-1", company: "Acme", role_title: "Engineer")

    assert_equal first, second
    assert_equal record.reload.opportunity, first
    assert_equal "claimed", record.status
    assert_in_delta 90.days.from_now.to_i, record.expires_at.to_i, 2
  end

  test "does not allow a claimed token to move to another opportunity" do
    _record, raw = @service.mint!
    @service.claim!(raw_token: raw, external_id: "role-1", company: "Acme", role_title: "Engineer")

    assert_raises(AskJared::TokenService::TokenAlreadyClaimed) do
      @service.claim!(raw_token: raw, external_id: "role-2", company: "Other", role_title: "Engineer")
    end
  end

  test "rejects expired tokens" do
    _record, raw = @service.mint!(expires_at: 1.minute.ago)

    assert_nil @service.resolve(raw)
  end

  test "refills only when below the minimum threshold" do
    pool = AskJared::TokenPool.new(token_service: @service, minimum: 2, target: 4)

    assert_equal({ minted: 4, available: 4 }, pool.refill!)
    assert_equal({ minted: 0, available: 4 }, pool.refill!)
  end
end
