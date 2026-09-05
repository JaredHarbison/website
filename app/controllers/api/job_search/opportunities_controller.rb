module Api
  module JobSearch
    class OpportunitiesController < ApplicationController
      protect_from_forgery with: :null_session
      before_action :authenticate_sync_request!
      rescue_from ActiveRecord::RecordNotFound, ArgumentError, with: :bad_request
      rescue_from AskJared::TokenService::TokenAlreadyClaimed, with: :conflict
      rescue_from AskJared::SubmissionService::SubmissionConflict, with: :conflict

      def submit
        raise ArgumentError, "Idempotency-Key is required" if request.headers["Idempotency-Key"].blank?

        submission = submission_params
        opportunity = AskJared::SubmissionService.new.call(**submission)
        render json: { status: "submitted", external_id: opportunity.external_id,
                       ask_link: ask_link_for(submission.fetch(:raw_token)) }
      end

      private

      def submission_params
        params.permit(:raw_token, :external_id, :company, :role_title, :tracker_source, :submitted_at).to_h.symbolize_keys
      end

      def authenticate_sync_request!
        configured = ENV["JOB_SEARCH_SYNC_TOKEN"].to_s
        supplied = request.headers["X-Job-Search-Key"].to_s
        authorized = configured.present? && supplied.present? && ActiveSupport::SecurityUtils.secure_compare(supplied, configured)
        return if authorized

        render json: { status: "blocked", message: "Unauthorized" }, status: :unauthorized
      end

      def ask_link_for(raw_token)
        return if raw_token.blank?

        "#{request.base_url}/?t=#{ERB::Util.url_encode(raw_token)}"
      end

      def bad_request(error)
        render json: { status: "error", message: error.message }, status: :unprocessable_entity
      end

      def conflict(error)
        render json: { status: "conflict", message: error.message }, status: :conflict
      end
    end
  end
end
