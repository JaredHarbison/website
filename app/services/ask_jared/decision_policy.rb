module AskJared
  # The policy registry is the single contract between semantic question
  # resolution and answer planning. It contains no candidate facts and does
  # not inspect question wording: the resolver supplies the decision.
  class DecisionPolicy
    INTENTS = %w[
      characterization product ownership project_story contribution
      prioritization complexity failure soft_skills collaboration mentorship
      leadership stakeholder influence_without_authority role_fit candidacy
      risk organization frontend backend rails react typescript integration
      architecture testing security production impact ambiguity learning
      status scope career availability unclassified
    ].freeze

    SUBJECTS = %w[candidate project product technology decision behavior outcome role experience unknown].freeze
    OPERATIONS = %w[identify summarize explain compare select assess verify describe recommend follow_up].freeze
    DIMENSIONS = %w[
      technical_scope technical_depth product_judgment ownership contribution
      collaboration communication leadership mentorship decision_making tradeoffs
      prioritization ambiguity outcome impact learning adaptability team_context
      employer chronology shipped_status role_fit gap
    ].freeze
    SCOPES = %w[unrestricted dogly non_dogly other_employer personal unknown].freeze
    ANSWER_SHAPES = %w[direct profile story comparison compound gap follow_up insufficient].freeze
    EVIDENCE_REQUIREMENTS = %w[
      profile_fact project_identity direct_contribution ownership_boundary
      concrete_behavior outcome limitation employer_identity chronology status
      comparison_basis learning_trajectory
    ].freeze

    Contract = Data.define(:evidence_requirements, :scope_rules, :fallback_behavior, :source_ranking_hints)

    DEFAULT_CONTRACT = Contract.new(
      [ "directly_relevant_claims" ],
      [ "Preserve employer, project, chronology, ownership, and status." ],
      "Answer only the supported portion and identify the missing portion narrowly.",
      []
    ).freeze

    CONTRACTS = {
      "profile" => Contract.new(
        %w[canonical_profile_statement distinct_supporting_dimensions],
        [ "Prefer profile-level evidence before anecdotes.", "Use no more than one short example unless requested." ],
        "If no canonical profile evidence exists, return insufficient_information rather than substituting one anecdote.",
        [ "professional engineering identity full-stack Rails backend product engineering ownership", "engineering profile product judgment ambiguity production responsibility" ]
      ),
      "comparison" => Contract.new(
        %w[explicit_complexity_basis project_scope ownership],
        [ "Honor the employer and project scope in the question.", "Do not infer a superlative from retrieval rank." ],
        "If the evidence does not establish a defensible comparison or superlative, say that and provide the strongest supported candidate without calling it the most complex.",
        [ "Dogly project technical complexity architecture scope ownership tradeoffs", "Dogly technical debt scheduled system Shopify integration production complexity" ]
      ),
      "gap" => Contract.new(
        %w[learning_trajectory limitation],
        [ "Separate direct experience from adjacent foundation.", "Do not infer expertise from adjacent technologies or contexts." ],
        "State the direct boundary, relevant adjacent evidence, demonstrated learning, and the transfer limit.",
        [ "Jared learning unfamiliar technology adjacent foundation demonstrated adaptation" ]
      ),
      "follow_up" => Contract.new(
        [ "directly_relevant_claims" ],
        [ "Use prior evidence only for a clear referent.", "A new scope or operation resets the relevant constraints." ],
        "If the referent is unclear, answer only what the current question independently supports.",
        []
      ),
      "compound" => Contract.new(
        [ "one_supported_answer_for_each_intent_family" ],
        [ "Answer each distinct part separately.", "Do not merge evidence from different intent families into one claim.", "If one part is unsupported, identify only that gap and answer the supported part." ],
        "Answer supported parts independently and omit unsupported parts rather than substituting adjacent evidence.",
        []
      ),
      "direct" => DEFAULT_CONTRACT,
      "story" => DEFAULT_CONTRACT,
      "insufficient" => DEFAULT_CONTRACT
    }.freeze

    INTENT_OVERRIDES = {
      "scope" => Contract.new(
        %w[employer_or_project_identity direct_contribution],
        [ "Exclude Dogly evidence unless explicitly labeled as comparison context.", "Preserve employer or project identity." ],
        "If non-Dogly evidence is insufficient, state the gap instead of returning a Dogly example.",
        [ "J.Crew Anthropologie retail engineering experience projects outside Dogly", "independent product project outside Dogly Rails" ]
      ),
      "soft_skills" => Contract.new(
        %w[distinct_interpersonal_dimensions concrete_behavior],
        [ "Synthesize communication, collaboration, judgment, feedback, and mentorship only where evidenced.", "Do not present personality traits as facts without behavioral evidence." ],
        "Answer with the supported dimensions and omit any soft-skill category without a concrete example.",
        [ "communication collaboration stakeholder alignment feedback mentorship product judgment", "how Jared works with engineers stakeholders and developing people" ]
      )
    }.freeze

    def self.contract_for(intent:, answer_shape:, compound: false)
      return CONTRACTS.fetch("compound") if compound

      INTENT_OVERRIDES.fetch(intent.to_s) { CONTRACTS.fetch(answer_shape.to_s, DEFAULT_CONTRACT) }
    end

    def self.assert_complete!
      missing_shapes = ANSWER_SHAPES - CONTRACTS.keys
      raise "Ask Jared decision policy missing answer shapes: #{missing_shapes.join(', ')}" if missing_shapes.any?

      invalid_intents = INTENT_OVERRIDES.keys - INTENTS
      raise "Ask Jared decision policy has invalid intents: #{invalid_intents.join(', ')}" if invalid_intents.any?

      true
    end
  end
end
