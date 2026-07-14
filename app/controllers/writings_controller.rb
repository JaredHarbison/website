class WritingsController < ApplicationController
  before_action :require_public_sections!

  rescue_from ContentRepository::EntryNotFound, with: :not_found

  def index
    @articles = repository.all
  end

  def show
    @article = repository.find!(params[:slug])
  end

  private

  def repository
    ContentRepository.new(collection: "writing", model: Article)
  end
end
