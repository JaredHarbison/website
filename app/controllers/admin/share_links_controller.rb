module Admin
  class ShareLinksController < BaseController
    def create
      qa_link = params[:link_type].to_s == "internal_qa"
      service = qa_link ? AskJared::InternalQaShareService.new : AskJared::ManualShareService.new
      _opportunity, _token, raw_token = service.create!(
        label: params[:label], purpose: params[:purpose], company: params[:company], expires_at: expiration_time
      )
      link = "#{request.base_url}/?t=#{ERB::Util.url_encode(raw_token)}"
      flash[:direct_share_link] = link
      redirect_to safe_return_path, notice: qa_link ? "Internal / QA link created." : "Direct share link created."
    end

    def revoke
      opportunity = Opportunity.find_by!(id: params[:id], tracker_source: "manual")
      opportunity.ask_token&.update!(status: "revoked", revoked_at: Time.current)
      redirect_to safe_return_path, notice: "Manual share link revoked."
    end

    private

    def expiration_time
      return if params[:expires_on].blank?

      Time.zone.parse(params[:expires_on].to_s).end_of_day
    rescue ArgumentError
      raise ActionController::BadRequest, "Invalid expiration date"
    end

    def safe_return_path
      candidate = params[:return_to].to_s
      candidate.start_with?("/admin/") ? candidate : admin_root_path
    end
  end
end
