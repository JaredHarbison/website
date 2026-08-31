module Admin
  class ShareLinksController < BaseController
    def create
      _token, raw_token = AskJared::TokenService.new.mint_direct_share!
      link = "#{request.base_url}/ask?t=#{ERB::Util.url_encode(raw_token)}"
      redirect_to admin_root_path, notice: "Direct share link created.", flash: { direct_share_link: link }
    end
  end
end
