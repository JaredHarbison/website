class AskJaredMailer < ApplicationMailer
  def issue_report(event, opportunity, contact)
    @event = event
    @opportunity = opportunity
    @contact = contact
    @admin_link = Rails.application.routes.url_helpers.admin_opportunity_url(
      opportunity, host: ENV.fetch("APP_HOST", "localhost")
    )
    mail(to: ENV.fetch("JARED_ISSUE_EMAIL"), subject: "Ask Jared issue report · #{@event.metadata['issue_category']}")
  end
end
