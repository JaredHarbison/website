module AskJared
  class TokenPoolDeliveryService
    LOCK_KEY = 7_418_202_027

    def initialize(token_service: TokenService.new)
      @token_service = token_service
    end

    def call(sheet_available_count:, target: 200)
      raise ArgumentError, "sheet_available_count is required" if sheet_available_count.blank?
      raise ArgumentError, "sheet_available_count must be non-negative" unless sheet_available_count.to_i >= 0
      raise ArgumentError, "target must be positive" unless target.to_i.positive?

      with_lock do
        # Raw values from an old DB-only refill cannot be recovered because
        # Rails never stores them. Revoke those orphaned records.
        AskToken.available_now.not_exported.update_all(status: "revoked")
        needed = [ target.to_i - sheet_available_count.to_i, 0 ].max
        delivered = needed.times.map { mint_for_export }
        { minted: delivered.length, available: sheet_available_count.to_i + delivered.length, tokens: delivered }
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
