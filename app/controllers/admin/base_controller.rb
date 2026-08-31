module Admin
  class BaseController < ApplicationController
    before_action :authenticate_admin_user!

    private

    def admin_not_found
      raise ActionController::RoutingError, "Not Found"
    end
  end
end
