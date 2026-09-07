module Api
  module Ask
    class IssuesController < ApplicationController
      protect_from_forgery with: :null_session
      skip_forgery_protection if: :trusted_request?

      def create
        event = AskJared::IssueReportService.new.call(
          raw_token: request.headers["X-Ask-Token"].presence || params[:t],
          session_id: ask_session_id, answer_event_id: params[:answer_event_id], question: params[:question], answer: params[:answer],
          answer_status: params[:answer_status], category: params[:category], feedback: params[:feedback],
          contact: params[:contact], page: request.path, ip: request.remote_ip, user_agent: request.user_agent
        )
        render json: { status: "ok", report_id: event.id }
      rescue ActiveRecord::RecordNotFound, ArgumentError => error
        Rails.logger.info("Ask Jared issue report rejected: #{error.class}: #{error.message}")
        render json: { status: "error", message: "We couldn’t send that report. Please try again." }, status: :unprocessable_entity
      end

      private

      def trusted_request?
        request.headers["X-Ask-Token"].present? || params[:t].present?
      end

      def ask_session_id
        session[:ask_jared_session_marker] ||= SecureRandom.hex(16)
        request.session.id.to_s.presence || session[:ask_jared_session_marker]
      end
    end
  end
end
