class ContactMailer < ApplicationMailer
  def prospect_message(event, opportunity)
    @event = event
    @opportunity = opportunity
    mail(to: ENV.fetch("JARED_ISSUE_EMAIL"), reply_to: event.metadata["email"], subject: "Portfolio message · #{opportunity&.company}")
  end
end
