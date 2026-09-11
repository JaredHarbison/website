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
    REQUIRED_METADATA = %w[title summary status tags].freeze
    COLLECTION_REQUIRED_METADATA = {
      "case_studies" => %w[role technologies],
      "writing" => %w[category]
    }.freeze

    def initialize(repositories: nil)
      @repositories = repositories || default_repositories
    end

    def documents
      sources = collection_documents + page_documents
      validate!(sources)
      sources
    end

    def find(id)
      documents.find { |document| document.id == id.to_s }
    end

    def metadata_errors(documents = self.documents)
      documents.flat_map do |document|
        required = REQUIRED_METADATA + COLLECTION_REQUIRED_METADATA.fetch(document.collection, [])
        required.filter_map do |field|
          value = document.metadata[field]
          "#{document.id} is missing #{field}" if value.blank? || (value.respond_to?(:empty?) && value.empty?)
        end
      end
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

    def validate!(sources)
      errors = metadata_errors(sources)
      raise ArgumentError, "Ask Jared public-corpus metadata contract failed: #{errors.join('; ')}" if errors.any?
    end
  end
end
