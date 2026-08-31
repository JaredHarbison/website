module AskJared
  class ApprovedKnowledgeRetriever
    DEFAULT_LIMIT = 5

    def initialize(scope: ::KnowledgeEntry.recruiter_retrievable)
      @scope = scope
    end

    def call(question, limit: DEFAULT_LIMIT)
      terms = question.to_s.downcase.scan(/[a-z0-9]{3,}/).uniq
      return [] if terms.empty?

      @scope.to_a.filter_map do |entry|
        haystack = [ entry.title, entry.short_body, entry.body, Array(entry.metadata["tags"]) ].compact.join(" ").downcase
        score = terms.count { |term| haystack.include?(term) }
        [ entry, score ] if score.positive?
      end.sort_by { |entry, score| [ -score, entry.id ] }.first(limit).map(&:first)
    end
  end
end
