module AskJared
  class TokenPoolDeliveryService
    LOCK_KEY = 7_418_202_027
    MAX_TARGET = 500
    EXPORTED_UNCLAIMED_TTL = 30.days

    def initialize(token_service: TokenService.new)
      @token_service = token_service
    end

    def call(sheet_available_count:, target: 200)
      sheet_count = Integer(sheet_available_count)
      requested_target = Integer(target)
      raise ArgumentError, "sheet_available_count must be non-negative" if sheet_count.negative?
      raise ArgumentError, "target must be positive" unless requested_target.positive?
      raise ArgumentError, "target exceeds maximum of #{MAX_TARGET}" if requested_target > MAX_TARGET

      with_lock do
        # Raw values from an old DB-only refill cannot be recovered because
        # Rails never stores them. Revoke those orphaned records.
        AskToken.available_now.not_exported.update_all(status: "revoked")
        AskToken.where(status: "available").where.not(exported_at: nil)
                .where("exported_at < ?", EXPORTED_UNCLAIMED_TTL.ago)
                .update_all(status: "revoked", revoked_at: Time.current, updated_at: Time.current)
        needed = [ requested_target - sheet_count, 0 ].max
        delivered = needed.times.map { mint_for_export }
        { minted: delivered.length, available: sheet_count + delivered.length, tokens: delivered }
      end
    end

    private

    def mint_for_export
      token, raw = @token_service.mint!
      token.update!(exported_at: Time.current)
      { inventory_id: token.id, token: raw, state: "AVAILABLE" }
    end

    def with_lock
      if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgres")
        AskToken.transaction do
          ActiveRecord::Base.connection.execute("SELECT pg_advisory_xact_lock(#{LOCK_KEY})")
          yield
        end
      else
        TokenPool.local_lock.synchronize { yield }
      end
    end
  end
end
