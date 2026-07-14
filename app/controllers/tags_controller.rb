class TagsController < ApplicationController
  before_action :require_public_sections!

  rescue_from ContentRepository::EntryNotFound, with: :not_found

  def index
    @tags = catalog.all
  end

  def show
    @tag = catalog.find!(params[:slug])
  end

  private

  def catalog
    @catalog ||= TagCatalog.new
  end
end
