module Api
  module Ask
    class QuestionsController < ApplicationController
      protect_from_forgery with: :null_session
      skip_forgery_protection if: :bearer_authenticated_request?
      rescue_from ActiveRecord::RecordNotFound, ArgumentError, with: :bad_request
      rescue_from AskJared::OpenAiProvider::ConfigurationError, AskJared::OpenAiProvider::ProviderError, with: :provider_unavailable
      rescue_from AskJared::UsageGuard::LimitExceeded, with: :rate_limited

      def create
        admin_preview = current_admin_user.present? && params[:admin_preview].to_s == "1"
        render json: question_service.call(
          raw_token: admin_preview ? nil : request.headers["X-Ask-Token"].presence || params[:t],
          admin_preview: admin_preview,
          question: params[:question],
          session_id: request.session.id.to_s.presence || request.request_id,
          ip: request.remote_ip,
          request_id: request.request_id
        )
      end

      private

      def bearer_authenticated_request?
        request.headers["X-Ask-Token"].present? || params[:t].present?
      end

      def question_service
        @question_service ||= AskJared::QuestionService.new
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
