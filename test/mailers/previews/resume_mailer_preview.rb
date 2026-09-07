require "ostruct"

class ResumeMailerPreview < ActionMailer::Preview
  def verification
    ResumeMailer.verification(OpenStruct.new(email: "recruiter@example.com"), "preview-token")
  end

  def resume
    previous = ENV["APPROVED_GENERIC_RESUME_PATH"]
    ENV["APPROVED_GENERIC_RESUME_PATH"] = "app/assets/images/jared-harbison-headshot.webp"
    delivery = ResumeMailer.resume(OpenStruct.new(email: "recruiter@example.com"))
    delivery.message
    delivery
  ensure
    ENV["APPROVED_GENERIC_RESUME_PATH"] = previous
  end
end
