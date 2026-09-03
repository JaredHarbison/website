module ApplicationHelper
  def navigation_case_studies
    @navigation_case_studies ||= ContentRepository.new(
      collection: "case_studies",
      model: CaseStudy
    ).all
  end

  def navigation_articles
    @navigation_articles ||= ContentRepository.new(
      collection: "writing",
      model: Article
    ).all
  end

  def navigation_section_open?(controller_name)
    controller.controller_name == controller_name
  end

  def navigation_link_to(label, path, **options)
    options[:aria] = { current: "page" } if current_page?(path)
    link_to label, path, **options
  end

  def admin_pagination(page:, has_previous:, has_next:, params: {})
    render "admin/pagination", page: page, has_previous: has_previous, has_next: has_next, query: params
  end
end
