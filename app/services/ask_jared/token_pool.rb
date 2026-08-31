module AskJared
  class TokenPool
    def initialize(token_service: TokenService.new, minimum: 100, target: 200, expires_at: nil)
      raise ArgumentError, "target must be at least minimum" if target < minimum

      @token_service = token_service
      @minimum = minimum
      @target = target
      @expires_at = expires_at
    end

    def refill!
      available = AskToken.available_now.count
      return { minted: 0, available: available } if available >= @minimum

      minted = @target - available
      minted.times { @token_service.mint!(expires_at: @expires_at) }
      { minted: minted, available: available + minted }
    end
  end
end
