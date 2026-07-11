class TagCatalog
  Tag = Data.define(:name, :slug, :case_studies, :articles) do
    def count
      case_studies.size + articles.size
    end
  end

  def all
    grouped_entries.map do |slug, group|
      Tag.new(
        name: group[:name],
        slug: slug,
        case_studies: group[:case_studies],
        articles: group[:articles]
      )
    end.sort_by { |tag| tag.name.downcase }
  end

  def find!(slug)
    all.find { |tag| tag.slug == slug.to_s } || raise(ContentRepository::EntryNotFound, slug)
  end

  private

  def grouped_entries
    {}.tap do |groups|
      add_entries(groups, case_studies, :case_studies)
      add_entries(groups, articles, :articles)
    end
  end

  def add_entries(groups, entries, collection)
    entries.each do |entry|
      entry.tags.each do |name|
        slug = name.parameterize
        group = groups[slug] ||= { name: name, case_studies: [], articles: [] }
        group[collection] << entry
      end
    end
  end

  def case_studies
    ContentRepository.new(collection: "case_studies", model: CaseStudy).all
  end

  def articles
    ContentRepository.new(collection: "writing", model: Article).all
  end
end
