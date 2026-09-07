Devise.setup do |config|
  config.mailer_sender = ENV.fetch("MAILER_FROM", "ask-jared@localhost")
  config.parent_controller = "ApplicationController"
  config.case_insensitive_keys = [ :email ]
  config.strip_whitespace_keys = [ :email ]
  config.password_length = 12..128
  config.stretches = Rails.env.test? ? 1 : 12
end
