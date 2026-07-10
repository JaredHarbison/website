class PagesController < ApplicationController
  before_action :require_public_sections!, except: :home

  def home
  end

  def about
    @page = page_repository.find!("about")
  end

  def contact
    @page = page_repository.find!("contact")
  end

  private

  def page_repository
    ContentRepository.new(collection: "pages", model: ContentEntry)
  end
end
