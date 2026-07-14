class CaseStudiesController < ApplicationController
  before_action :require_public_sections!

  rescue_from ContentRepository::EntryNotFound, with: :not_found

  def index
    @case_studies = repository.all
  end

  def show
    @case_study = repository.find!(params[:slug])
  end

  private

  def repository
    ContentRepository.new(collection: "case_studies", model: CaseStudy)
  end
end
