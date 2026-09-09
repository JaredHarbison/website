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
    ensure_admin_qa_access! if @admin_preview
    @admin_raw_token = session[:ask_jared_admin_qa_token] if @admin_preview
    if @admin_preview && params[:t].present?
      session.delete(:ask_jared_prospect_token)
      return redirect_to ask_path(architecture: params[:architecture].presence), status: :see_other
    end
    @token = token_service.resolve(@admin_raw_token || prospect_raw_token)
    @qa_preview = @token&.opportunity&.tracker_source == "internal_qa"
    @ask_question_count = if @admin_preview
      0
    elsif @token&.opportunity
      @token.opportunity.engagement_events.where(
        session_digest: AskJared::EngagementService.new.session_digest(request.session.id.to_s),
        event_type: "question_submitted"
      ).count
    else
      0
    end
    # Owner and internal QA sessions always exercise the canonical planner.
    # Historical architecture variants remain available only in archived
    # evaluation artifacts, never through the live preview surface.
    @preview_architecture = AskJared::CandidateContext::VERSION
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

  def ensure_admin_qa_access!
    token = token_service.resolve(session[:ask_jared_admin_qa_token])
    return if token_service.recruiter_accessible?(token) && token.opportunity.tracker_source == "internal_qa"

    _opportunity, _token, raw_token = AskJared::InternalQaShareService.new.create!(
      label: "Admin Ask Jared preview",
      purpose: "Owner testing and QA"
    )
    session[:ask_jared_admin_qa_token] = raw_token
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
