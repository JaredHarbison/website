module AskJared
  class RefillTokenPoolJob < ApplicationJob
    queue_as :default

    def perform
      TokenPool.new(
        minimum: ENV.fetch("ASK_JARED_TOKEN_POOL_MINIMUM", 100).to_i,
        target: ENV.fetch("ASK_JARED_TOKEN_POOL_TARGET", 200).to_i
      ).refill!
    end
  end
end
