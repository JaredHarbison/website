module Api
  module JobSearch
    class EngagementsController < ApplicationController
      before_action :authenticate_read_request!

      def index
        since = Time.zone.parse(params[:since].to_s) if params[:since].present?
        render json: { status: "ok", generated_at: Time.current,
                       opportunities: AskJared::EngagementExport.new.call(since: since) }
      rescue ArgumentError
        render json: { status: "error", message: "Invalid since timestamp" }, status: :unprocessable_entity
      end

      private

      def authenticate_read_request!
        configured = ENV["JOB_SEARCH_READ_SYNC_TOKEN"].to_s
        supplied = request.headers["X-Job-Search-Read-Key"].to_s
        authorized = configured.present? && supplied.present? && ActiveSupport::SecurityUtils.secure_compare(supplied, configured)
        return if authorized

        render json: { status: "blocked", message: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
