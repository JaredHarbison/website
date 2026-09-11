module AskJared
  # A dynamic view of recruiter-facing source material. New published case
  # studies and writing become available automatically; pages remain explicitly
  # allowlisted so Contact and other non-evidence pages cannot enter the corpus.
  class PublicCorpus
    Document = Data.define(:id, :title, :url, :collection, :body, :summary, :metadata) do
      def prompt_text
        <<~TEXT.strip
          SOURCE: #{id}
          TITLE: #{title}
          URL: #{url}
          SUMMARY: #{summary}

          #{body}
        TEXT
      end
    end

    COLLECTIONS = {
      "case_studies" => { model: CaseStudy, path: "/case-studies/%{slug}" },
      "writing" => { model: Article, path: "/writing/%{slug}" }
    }.freeze
    PAGE_ALLOWLIST = { "about" => "/about" }.freeze

    def initialize(repositories: nil)
      @repositories = repositories || default_repositories
    end

    def documents
      collection_documents + page_documents
    end

    def find(id)
      documents.find { |document| document.id == id.to_s }
    end

    private

    def default_repositories
      COLLECTIONS.transform_values { |config| ContentRepository.new(collection: config.fetch(:model) == CaseStudy ? "case_studies" : "writing", model: config.fetch(:model)) }
                 .merge("pages" => ContentRepository.new(collection: "pages", model: ContentEntry))
    end

    def collection_documents
      COLLECTIONS.flat_map do |collection, config|
        entries_for(collection).map do |entry|
          document(entry, collection: collection, url: format(config.fetch(:path), slug: entry.slug))
        end
      end
    end

    def page_documents
      entries_for("pages").filter_map do |entry|
        url = PAGE_ALLOWLIST[entry.slug]
        document(entry, collection: "pages", url: url) if url
      end
    end

    def entries_for(collection)
      repository = @repositories.fetch(collection)
      repository.respond_to?(:all) ? repository.all : Array(repository)
    end

    def document(entry, collection:, url:)
      Document.new(
        "#{collection}:#{entry.slug}", entry.title, url, collection,
        entry.body.to_s, entry.summary.to_s, entry.metadata || {}
      )
    end
  end
end
