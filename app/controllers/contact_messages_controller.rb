class ContactMessagesController < ApplicationController
  def create
    token = active_token
    raise ActionController::BadRequest, "Recruiter access is required" unless token

    name = params[:name].to_s.strip.first(160)
    email = params[:email].to_s.strip.first(320)
    message = params[:message].to_s.strip.first(4000)
    raise ActionController::BadRequest, "Name, email, and message are required" if name.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP) || message.blank?

    event = AskJared::EngagementService.new.record!(
      raw_token: prospect_token, event_type: "contact_message_submitted", session_id: ask_session_id,
      ip: request.remote_ip, event_key: "contact:#{request.request_id}", metadata: {
        "name" => name, "email" => email, "message" => message, "company" => token.opportunity&.company,
        "role" => token.opportunity&.role_title, "page" => request.path
      }
    )
    ContactMailer.prospect_message(event, token.opportunity).deliver_later if ENV["JARED_ISSUE_EMAIL"].present?
    redirect_to contact_path, notice: "Your message is on its way to Jared."
  rescue ActiveRecord::RecordNotFound, ActionController::BadRequest => error
    redirect_to contact_path, alert: error.message
  end

  private

  def active_token
    token = AskJared::TokenService.new.resolve(prospect_token)
    token if token && AskJared::TokenService.new.recruiter_accessible?(token)
  end

  def ask_session_id
    session[:ask_jared_session_marker] ||= SecureRandom.hex(16)
    request.session.id.to_s.presence || session[:ask_jared_session_marker]
  end
end
