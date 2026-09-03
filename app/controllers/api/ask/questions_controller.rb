require "securerandom"

module Api
  module Ask
    class QuestionsController < ApplicationController
      protect_from_forgery with: :null_session
      skip_forgery_protection if: :trusted_request?
      rescue_from ActiveRecord::RecordNotFound, ArgumentError, with: :bad_request
      rescue_from AskJared::OpenAiProvider::ConfigurationError, AskJared::OpenAiProvider::ProviderError, with: :provider_unavailable
      rescue_from AskJared::UsageGuard::LimitExceeded, with: :rate_limited

      def create
        admin_preview = current_admin_user.present? && params[:admin_preview].to_s == "1"
        render json: question_service.call(
          raw_token: admin_preview ? nil : request.headers["X-Ask-Token"].presence || params[:t],
          admin_preview: admin_preview,
          question: params[:question],
          session_id: ask_session_id,
          ip: request.remote_ip,
          request_id: request.request_id
        )
      end

      private

      def trusted_request?
        return true if request.headers["X-Ask-Token"].present? || params[:t].present?

        admin_preview_request_with_valid_token?
      end

      def admin_preview_request_with_valid_token?
        return false unless current_admin_user.present? && params[:admin_preview].to_s == "1"
        return false unless request.origin == "null"

        valid_authenticity_token?(session, request_authenticity_token)
      end

      def request_authenticity_token
        request.headers["X-CSRF-Token"].presence || params[:authenticity_token]
      end

      def question_service
        @question_service ||= AskJared::QuestionService.new
      end

      def ask_session_id
        session[:ask_jared_session_marker] ||= SecureRandom.hex(16)
        request.session.id.to_s.presence || session[:ask_jared_session_marker]
      end

      def bad_request(error)
        render json: { status: "blocked", answer: error.message, evidence_ids: [], source_urls: [] }, status: :unprocessable_entity
      end

      def provider_unavailable(_error)
        render json: { status: "insufficient_information", answer: "The answer service is temporarily unavailable.", evidence_ids: [], source_urls: [] }, status: :service_unavailable
      end

      def rate_limited(error)
        render json: { status: "blocked", answer: error.message, evidence_ids: [], source_urls: [] }, status: :too_many_requests
      end
    end
  end
end
