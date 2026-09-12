module AskJared
  # Retrieval for offline corpus evaluation. Ranking is deliberately source
  # based and dynamic; it does not reuse the production knowledge-entry router.
  class PublicCorpusRetriever
    attr_reader :last_trace
    def initialize(corpus: PublicCorpus.new)
      @corpus = corpus
    end

    def call(question, limit: 6, scope: nil)
      terms = question.to_s.downcase.scan(/[a-z0-9]{3,}/).uniq
      documents = @corpus.documents
      eligible, excluded = documents.partition { |document| scope_allows?(document, scope) }
      ranked = eligible.map do |document|
        text = [ document.title, document.summary, Array(document.metadata["tags"]), document.metadata["category"], document.metadata["technologies"], document.body ].flatten.compact.join(" ").downcase
        title_text = [ document.title, document.summary, Array(document.metadata["tags"]), document.metadata["category"] ].flatten.compact.join(" ").downcase
        title_matches = terms.count { |term| title_text.include?(term) }
        body_matches = terms.count { |term| text.include?(term) }
        [ document, (title_matches * 4) + body_matches, title_matches, body_matches ]
      end.sort_by { |document, score, _title_matches, _body_matches| [ -score, document.id ] }
      selected = ranked.first(limit)
      @last_trace = {
        mode: "public-corpus-lexical", question_terms: terms, scope: scope,
        excluded: excluded.map { |document| { id: document.id, scope: document.metadata["scope"] } },
        considered: ranked.map { |document, score, title_matches, body_matches| trace(document, score, title_matches, body_matches) },
        selected: selected.map { |document, _score, _title_matches, _body_matches| document.id }
      }
      selected.map(&:first)
    end

    private

    def trace(document, score, title_matches, body_matches)
      { id: document.id, url: document.url, collection: document.collection, score: score,
        title_matches: title_matches, body_matches: body_matches }
    end

    def scope_allows?(document, scope)
      employer = document.metadata.dig("scope", "employer")
      case scope.to_s
      when "dogly" then employer == "Dogly"
      when "non_dogly", "other_employer", "personal" then employer != "Dogly" && employer != "unknown"
      else true
      end
    end
  end
end
