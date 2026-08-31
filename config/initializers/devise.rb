Devise.setup do |config|
  config.mailer_sender = "please-change-me@example.com"
  config.parent_controller = "ActionController::Base"
  config.case_insensitive_keys = [ :email ]
  config.strip_whitespace_keys = [ :email ]
  config.password_length = 12..128
  config.stretches = Rails.env.test? ? 1 : 12
end
