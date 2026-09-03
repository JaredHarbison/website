class AskController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def show
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["X-Robots-Tag"] = "noindex, nofollow, noarchive"
    expires_now
    @admin_preview = current_admin_user.present?
    if params[:static].present?
      @ask_unavailable = true
      return render :show
    end
    @token = token_service.resolve(prospect_raw_token) unless @admin_preview
    unless @admin_preview || token_service.recruiter_accessible?(@token)
      @ask_unavailable = true
      return render :show, status: :not_found
    end

    record_event("token_resolved") unless @admin_preview
    record_event("page_view") unless @admin_preview
  end

  private

  def token_service
    @token_service ||= AskJared::TokenService.new
  end

  def record_event(event_type)
    AskJared::EngagementService.new.record!(
      raw_token: prospect_raw_token,
      event_type: event_type,
      session_id: request.session.id.to_s.presence || request.request_id,
      ip: request.remote_ip,
      user_agent_class: request.user_agent.to_s.match?(/bot|crawler|spider/i) ? "scanner" : "browser",
      event_key: "#{request.request_id}:#{event_type}"
    )
  end

  def prospect_raw_token
    params[:t].presence || session[:ask_jared_prospect_token]
  end
end
