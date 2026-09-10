module AskJared
  class IntentRouter
    Match = Struct.new(:intent, :score, :pattern, keyword_init: true)

    # This is a question-family router, not a factual classifier. It may decide
    # what kind of answer is needed, but it cannot authorize a claim.
    PATTERNS = [
      [ "scope", /\b(?:outside|before|after|other than|non-)\s*(?:dogly|dogly's)/i, 120 ],
      [ "complexity", /\b(?:most|complexest|hardest|largest)\b.*\b(?:project|system|work|build)/i, 120 ],
      [ "soft_skills", /\b(?:soft skills?|interpersonal skills?|people skills?|human skills?)\b/i, 115 ],
      [ "role_fit", /\b(?:fit|match|suited|suitable|right for|role fit|would .* thrive)\b/i, 105 ],
      [ "candidacy", /\b(?:why (?:should|would) .*interview|why hire|case for Jared|recommend Jared|why Jared)\b/i, 110 ],
      [ "risk", /\b(?:risk|risks|gap|gaps|weakness|concern|less experience|where .* struggle)\b/i, 110 ],
      [ "organization", /\b(?:larger|large) engineering team|organizational scale|organizational levels|layered (?:team|organization)|managed large/i, 105 ],
      [ "typescript", /\btypescript\b/i, 120 ],
      [ "rails", /\brails\b/i, 120 ],
      [ "react", /\breact\b/i, 120 ],
      [ "frontend", /\b(?:front[- ]end|frontend|UI|user interface|browser)\b/i, 105 ],
      [ "backend", /\b(?:back[- ]end|backend|server[- ]side|database|data model)\b/i, 105 ],
      [ "integration", /\b(?:integrat(?:ion|e|ed)|APIs?|webhooks?|third[- ]party service)\b/i, 105 ],
      [ "architecture", /\b(?:architecture|system design|design a system|scal(?:e|ability)|technical design)\b/i, 105 ],
      [ "testing", /\b(?:testing|test strategy|quality assurance|QA|automated tests)\b/i, 105 ],
      [ "security", /\b(?:security|authentication|authorization|privacy|threat model)\b/i, 105 ],
      [ "ai_data", /\b(?:AI|machine learning|ML|retrieval|embeddings|data science)\b/i, 105 ],
      [ "production", /\bproduction (?:incident|problem|issue)|incident response|production reliability|on[- ]call/i, 110 ],
      [ "feedback", /\bfeedback|respond to criticism|received criticism|coachab(?:le|ility)/i, 100 ],
      [ "disagreement", /\btechnical disagreement|\bdisagreement with\b|\bhandle(?:d)? .*disagreement|technical conflict|disagreed|push(?:ed)? back|conflict over/i, 105 ],
      [ "prioritization", /\bpriorit(?:y|ize|izing|ization)|competing work|tradeoff|what did .* choose/i, 100 ],
      [ "ambiguity", /\bambigu(?:ity|ous)|unclear requirements|uncertainty|unclear problem/i, 100 ],
      [ "impact", /\bmeasurable (?:(?:business|product)(?: or (?:business|product))? )?impact|measurable result|business result|quantified outcome|metrics?/i, 100 ],
      [ "status", /\b(?:prototype|prototyped|planned|plan(?:ned)?|shipped|implemented|in production|roadmap)/i, 95 ],
      [ "stakeholder", /\bstakeholder|executive communication|communicate with .*stakeholder|cross[- ]functional/i, 95 ],
      [ "influence_without_authority", /\bwithout formal authority|formal decision[- ]maker|lack(?:ed)? formal authority|persuad(?:e|ed|ing)|convinc(?:e|ed|ing).*authority/i, 105 ],
      [ "mentorship", /\bmentor|mentorship|people development|succession|develop(?:ed|ing) people/i, 100 ],
      [ "leadership", /\blead(?:er|ership|ing)|manage(?:r|ment)|team direction|delegat(?:e|ion)/i, 90 ],
      [ "collaboration", /\bcollaborat|worked with engineers|engineer-to-engineer|teamwork|works with a team/i, 85 ],
      [ "learning", /\blearn(?:ing|ed)|unfamiliar technology|technical ramp|adapt(?:able|ability)|how quickly/i, 90 ],
      [ "failure", /\bfailure|mistake|technical debt|what went wrong|lesson learned/i, 95 ],
      [ "product", /\bproduct judgment|product thinking|product direction|product decision|user problem|\bux\b|customer needs/i, 90 ],
      [ "characterization", /\bwhat kind of engineer|engineering profile|engineer is Jared|describe Jared|what stands out|strongest qualities|biggest strengths/i, 90 ],
      [ "ownership", /\bwhat has .* owned|\bowned .* end[- ]to[- ]end|\btechnical ownership\b|responsib(?:le|ility)/i, 90 ],
      [ "career", /\b(?:career|background|trajectory|journey|experience overall|next environment|looking for)\b/i, 110 ],
      [ "availability", /\bavailability|start date|when can .* start|location|remote|work authorization|salary|compensation/i, 130 ]
    ].freeze

    def analyze(question)
      text = question.to_s.strip
      matches = PATTERNS.filter_map do |intent, pattern, weight|
        next unless text.match?(pattern)

        Match.new(intent: intent, score: weight + specificity_bonus(pattern), pattern: pattern.source)
      end
      grouped = matches.group_by(&:intent).values.map { |intent_matches| intent_matches.max_by(&:score) }.sort_by { |match| -match.score }
      complexity = structural_complexity(text, grouped: grouped)
      score_gap = grouped.first && grouped.second ? grouped.first.score - grouped.second.score : nil
      planning_reasons = []
      planning_reasons << "multiple_intent_families" if grouped.length > 1 && score_gap.to_i < 25
      planning_reasons << "compound_question" if complexity[:compound]
      planning_reasons << "comparison_or_superlative" if complexity[:comparison]
      planning_reasons << "broad_category" if complexity[:broad]
      planning_reasons << "unknown_intent" if grouped.empty?
      planning_reasons << "long_question" if complexity[:long]

      {
        primary: grouped.first&.intent,
        candidates: grouped.map(&:intent),
        matches: grouped.map { |match| { intent: match.intent, score: match.score } },
        planning_required: planning_reasons.any?, planning_reasons: planning_reasons,
        complexity: complexity
      }
    end

    def primary_intent(question)
      analyze(question).fetch(:primary)
    end

    private

    def specificity_bonus(pattern)
      pattern.source.length > 45 ? 8 : 0
    end

    def structural_complexity(text, grouped: [])
      words = text.split.size
      conjunction = text.match?(/\b(?:and|also|as well as|plus|along with)\b/i)
      {
        # A conjunction inside one answer family is usually a request for a
        # richer answer, not independently answerable compound questions. Only
        # split it when the router found multiple families (or multiple '?').
        compound: text.count("?") > 1 || (conjunction && grouped.length > 1),
        conjunction: conjunction,
        comparison: text.match?(/\b(?:most|hardest|largest|best|worst|strongest|weakest|compare|difference|versus|vs\.?|better)\b/i),
        broad: text.match?(/\b(?:what are|what kind|how would you describe|tell me about|overview|overall|in general)\b/i),
        long: words > 30
      }
    end
  end
end
