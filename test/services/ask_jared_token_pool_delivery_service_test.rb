require "test_helper"

class AskJaredTokenPoolDeliveryServiceTest < ActiveSupport::TestCase
  setup do
    AskToken.delete_all
    @token_service = AskJared::TokenService.new(secret: Rails.application.secret_key_base)
  end

  test "mints deliverable tokens below the sheet threshold" do
    result = AskJared::TokenPoolDeliveryService.new(token_service: @token_service).call(sheet_available_count: 1, target: 3)

    assert_equal 2, result[:minted]
    assert_equal 3, result[:available]
    assert_equal 2, result[:tokens].length
    result[:tokens].each do |exported|
      assert_equal exported[:inventory_id], AskToken.find(exported[:inventory_id]).id
      assert_equal "available", @token_service.resolve(exported[:token]).status
      assert_not_includes AskToken.find(exported[:inventory_id]).attributes.values, exported[:token]
      assert_not_nil AskToken.find(exported[:inventory_id]).exported_at
    end
  end

  test "does not mint when sheet inventory is at target" do
    result = AskJared::TokenPoolDeliveryService.new(token_service: @token_service).call(sheet_available_count: 3, target: 3)

    assert_equal({ minted: 0, available: 3, tokens: [] }, result)
    assert_empty AskToken.all
  end

  test "revokes unusable database-only inventory before delivering new tokens" do
    orphan, = @token_service.mint!

    result = AskJared::TokenPoolDeliveryService.new(token_service: @token_service).call(sheet_available_count: 0, target: 1)

    assert_equal "revoked", orphan.reload.status
    assert_equal 1, result[:minted]
    assert_equal 1, AskToken.where(status: "available").count
  end

  test "repeated refill with updated sheet count does not duplicate tokens" do
    service = AskJared::TokenPoolDeliveryService.new(token_service: @token_service)
    first = service.call(sheet_available_count: 0, target: 2)
    second = service.call(sheet_available_count: first[:available], target: 2)

    assert_equal 2, first[:tokens].length
    assert_equal 0, second[:minted]
    assert_equal 2, AskToken.count
  end
end
