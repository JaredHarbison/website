class AskController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def show
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["X-Robots-Tag"] = "noindex, nofollow, noarchive"
    expires_now
    @token = token_service.resolve(params[:t])
    raise ActiveRecord::RecordNotFound unless token_service.recruiter_accessible?(@token)

    record_event("token_resolved")
    record_event("page_view")
  end

  private

  def token_service
    @token_service ||= AskJared::TokenService.new
  end

  def record_event(event_type)
    AskJared::EngagementService.new.record!(
      raw_token: params[:t],
      event_type: event_type,
      session_id: request.session.id.to_s.presence || request.request_id,
      ip: request.remote_ip,
      user_agent_class: request.user_agent.to_s.match?(/bot|crawler|spider/i) ? "scanner" : "browser",
      event_key: "#{request.request_id}:#{event_type}"
    )
  end
end
