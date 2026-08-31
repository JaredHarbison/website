module Api
  module JobSearch
    class TokenPoolController < ApplicationController
      protect_from_forgery with: :null_session
      before_action :authenticate_pool_request!
      rescue_from ArgumentError, with: :bad_request

      def refill
        result = AskJared::TokenPoolDeliveryService.new.call(
          sheet_available_count: params[:sheet_available_count],
          claimed_inventory_ids: params.fetch(:claimed_inventory_ids, []),
          target: params.fetch(:target, ENV.fetch("ASK_JARED_TOKEN_POOL_TARGET", 200))
        )
        render json: result
      end

      private

      def authenticate_pool_request!
        configured = ENV["JOB_SEARCH_TOKEN_POOL_TOKEN"].to_s
        supplied = request.headers["X-Job-Search-Pool-Key"].to_s
        authorized = configured.present? && supplied.present? && ActiveSupport::SecurityUtils.secure_compare(supplied, configured)
        return if authorized

        render json: { status: "blocked", message: "Unauthorized" }, status: :unauthorized
      end

      def bad_request(error)
        render json: { status: "error", message: error.message }, status: :unprocessable_entity
      end
    end
  end
end
