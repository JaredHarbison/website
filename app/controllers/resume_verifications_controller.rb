require "digest"
require "securerandom"

class ResumeVerificationsController < ApplicationController
  VERIFICATION_WINDOW = 20.minutes
  REQUEST_LIMIT = 3

  def create
    token = active_token
    raise ActionController::BadRequest, "Recruiter access is required" unless token
    raise ActionController::BadRequest, "Résumé delivery is not available" unless ApprovedResume.delivery_ready?

    email = params[:email].to_s.strip.downcase.first(320)
    raise ActionController::BadRequest, "Enter a valid email address" unless email.match?(URI::MailTo::EMAIL_REGEXP)
    recent = ResumeVerification.where(ask_token: token, session_digest: session_digest).where("created_at >= ?", 1.hour.ago).count
    raise ActionController::TooManyRequests, "Please wait before requesting another verification email" if recent >= REQUEST_LIMIT

    raw = SecureRandom.urlsafe_base64(32)
    verification = ResumeVerification.create!(opportunity: token.opportunity, ask_token: token, token_digest: digest(raw), email: email, session_digest: session_digest, expires_at: VERIFICATION_WINDOW.from_now)
    record(token, "resume_verification_requested", verification_id: verification.id, email: email)
    ResumeMailer.verification(verification, raw).deliver_later
    redirect_to contact_path, flash: { resume_notice: "Check that email for a verification link. It expires in 20 minutes." }
  rescue ActiveRecord::RecordNotFound, ActionController::BadRequest, ActionController::TooManyRequests => error
    redirect_to contact_path, flash: { resume_error: error.message }
  end

  def show
    verification = ResumeVerification.find_by(token_digest: digest(params[:token].to_s))
    unless verification&.active?
      redirect_to contact_path, flash: { resume_error: "That verification link is no longer valid." }
      return
    end
    verification.update!(verified_at: Time.current)
    token = verification.ask_token
    record(token, "resume_email_verified", verification_id: verification.id, email: verification.email)
    if ApprovedResume.delivery_ready?
      ResumeMailer.resume(verification).deliver_later
      verification.update!(delivered_at: Time.current)
      record(token, "resume_requested", verification_id: verification.id, email: verification.email)
      record(token, "resume_delivery_succeeded", verification_id: verification.id, email: verification.email)
      redirect_to contact_path, flash: { resume_notice: "Jared's résumé is on its way." }
    else
      record(token, "resume_delivery_failed", verification_id: verification.id, delivery_status: "résumé delivery unavailable")
      redirect_to contact_path, flash: { resume_error: "Résumé delivery is not available yet." }
    end
  end

  private

  def active_token
    token = AskJared::TokenService.new.resolve(prospect_token)
    token if token && AskJared::TokenService.new.recruiter_accessible?(token)
  end

  def digest(value)
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("SHA256"), Rails.application.secret_key_base, value)
  end

  def session_digest
    AskJared::EngagementService.new.session_digest(session[:ask_jared_session_marker] ||= SecureRandom.hex(16))
  end

  def record(token, type, metadata)
    AskJared::EngagementService.new.record_for_token!(token: token, event_type: type, session_id: session[:ask_jared_session_marker] ||= SecureRandom.hex(16), metadata: metadata, event_key: "resume:#{type}:#{metadata[:verification_id] || metadata['verification_id']}:#{request.request_id}")
  end
end
