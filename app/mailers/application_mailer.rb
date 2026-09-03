class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "ask-jared@localhost")
  layout "mailer"
end
