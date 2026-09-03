class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :remember_prospect_context
  after_action :record_prospect_page_view

  helper_method :public_sections_enabled?, :prospect_token

  private

  def public_sections_enabled?
    ActiveModel::Type::Boolean.new.cast(
      ENV.fetch("PUBLIC_SECTIONS_ENABLED", true)
    )
  end

  def prospect_token
    session[:ask_jared_prospect_token]
  end

  def remember_prospect_context
    return if params[:t].blank?

    token = AskJared::TokenService.new.resolve(params[:t])
    session[:ask_jared_prospect_token] = params[:t] if token && AskJared::TokenService.new.recruiter_accessible?(token)
  end

  def record_prospect_page_view
    return unless request.get? && prospect_token.present?
    return if controller_path.start_with?("admin/", "api/") || controller_name == "ask"

    AskJared::EngagementService.new.record!(
      raw_token: prospect_token, event_type: "page_view",
      session_id: request.session.id.to_s.presence || request.request_id,
      ip: request.remote_ip,
      user_agent_class: request.user_agent.to_s.match?(/bot|crawler|spider/i) ? "scanner" : "browser",
      event_key: "#{request.request_id}:page_view",
      metadata: { "page" => request.path }
    )
  rescue ActiveRecord::RecordNotFound, ArgumentError
    session.delete(:ask_jared_prospect_token)
  end

  def require_public_sections!
    not_found unless public_sections_enabled?
  end

  def not_found
    raise ActionController::RoutingError, "Not Found"
  end
end
