namespace :ask_jared do
  desc "Refill the pre-minted Ask Jared token pool when inventory is low"
  task refill_token_pool: :environment do
    result = AskJared::RefillTokenPoolJob.perform_now
    puts "Ask Jared token pool: minted=#{result.fetch(:minted)} available=#{result.fetch(:available)}"
  end
end
