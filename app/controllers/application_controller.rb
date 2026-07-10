class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def public_sections_enabled?
    ActiveModel::Type::Boolean.new.cast(
      ENV.fetch("PUBLIC_SECTIONS_ENABLED", Rails.env.development?)
    )
  end

  def require_public_sections!
    not_found unless public_sections_enabled?
  end

  def not_found
    raise ActionController::RoutingError, "Not Found"
  end
end
