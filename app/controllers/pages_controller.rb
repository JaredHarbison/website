class PagesController < ApplicationController
  before_action :require_public_sections!, except: :home

  rescue_from ContentRepository::EntryNotFound, with: :not_found

  def home
  end

  def about
    @page = page_repository.find!("about")
  end

  def contact
    @page = page_repository.find!("contact")
    @prospect_access = prospect_opportunity
    @resume_available = ApprovedResume.delivery_ready?
  end

  private

  def prospect_opportunity
    return unless prospect_token.present?

    token = AskJared::TokenService.new.resolve(prospect_token)
    token if token && AskJared::TokenService.new.recruiter_accessible?(token)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def page_repository
    ContentRepository.new(collection: "pages", model: ContentEntry)
  end
end
