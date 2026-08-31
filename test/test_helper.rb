ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # SQLite is used for local/test persistence; one worker avoids write-lock
    # contention. CI can override this when using a concurrent Postgres DB.
    parallelize(workers: ENV.fetch("TEST_WORKERS", 1).to_i)

    # Add more helper methods to be used by all tests here...
  end
end
