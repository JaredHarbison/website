module AskJared
  # Retrieval for offline corpus evaluation. Ranking is deliberately source
  # based and dynamic; it does not reuse the production knowledge-entry router.
  class PublicCorpusRetriever
    def initialize(corpus: PublicCorpus.new)
      @corpus = corpus
    end

    def call(question, limit: 6)
      terms = question.to_s.downcase.scan(/[a-z0-9]{3,}/).uniq
      @corpus.documents.sort_by do |document|
        text = [ document.title, document.summary, Array(document.metadata["tags"]), document.metadata["category"], document.metadata["technologies"], document.body ].flatten.compact.join(" ").downcase
        title_text = [ document.title, document.summary, Array(document.metadata["tags"]), document.metadata["category"] ].flatten.compact.join(" ").downcase
        [ -terms.count { |term| title_text.include?(term) } * 4 - terms.count { |term| text.include?(term) }, document.id ]
      end.first(limit)
    end
  end
end
