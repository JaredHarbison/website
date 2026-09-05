class ResumeMailer < ApplicationMailer
  def verification(verification, raw_token)
    @verification_url = Rails.application.routes.url_helpers.resume_verification_confirmation_url(raw_token, host: ENV.fetch("APP_HOST", "localhost"))
    mail(to: verification.email, subject: "Verify your résumé request")
  end

  def resume(verification)
    attachments[ApprovedResume.filename] = File.binread(ApprovedResume.path)
    mail(to: verification.email, subject: "Jared Harbison's résumé")
  end
end
