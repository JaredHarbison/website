module AskJared
  class TokenPool
    REFILL_LOCK_KEY = 7_418_202_026

    def initialize(token_service: TokenService.new, minimum: 100, target: 200, expires_at: nil)
      raise ArgumentError, "target must be at least minimum" if target < minimum

      @token_service = token_service
      @minimum = minimum
      @target = target
      @expires_at = expires_at
    end

    def refill!
      with_refill_lock do
        available = AskToken.available_now.count
        return { minted: 0, available: available } if available >= @minimum

        minted = @target - available
        minted.times { @token_service.mint!(expires_at: @expires_at) }
        { minted: minted, available: available + minted }
      end
    end

    private

    def with_refill_lock(&block)
      if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgres")
        AskToken.transaction do
          ActiveRecord::Base.connection.execute("SELECT pg_advisory_xact_lock(#{REFILL_LOCK_KEY})")
          yield
        end
      else
        self.class.local_lock.synchronize(&block)
      end
    end

    def self.local_lock
      @local_lock ||= Mutex.new
    end
  end
end
