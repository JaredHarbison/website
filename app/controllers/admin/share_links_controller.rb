module Admin
  class ShareLinksController < BaseController
    def create
      _opportunity, _token, raw_token = AskJared::ManualShareService.new.create!(
        label: params[:label], purpose: params[:purpose], company: params[:company], expires_at: expiration_time
      )
      link = "#{request.base_url}/ask?t=#{ERB::Util.url_encode(raw_token)}"
      flash[:direct_share_link] = link
      redirect_to admin_root_path, notice: "Direct share link created."
    end

    def revoke
      opportunity = Opportunity.find_by!(id: params[:id], tracker_source: "manual")
      opportunity.ask_token&.update!(status: "revoked", revoked_at: Time.current)
      redirect_to admin_root_path, notice: "Manual share link revoked."
    end

    private

    def expiration_time
      return if params[:expires_on].blank?

      Time.zone.parse(params[:expires_on].to_s).end_of_day
    rescue ArgumentError
      raise ActionController::BadRequest, "Invalid expiration date"
    end
  end
end
