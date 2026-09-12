require "json"

module AskJared
  # Evaluation-only answerer. Its inputs are published documents only; an
  # optional Rules registry constrains claims but supplies no candidate facts.
  # Private KnowledgeEntry records are intentionally absent in both arms.
  class PublicCorpusAnswerer
    SCHEMA = {
      name: "ask_jared_public_corpus_answer",
      schema: {
        type: "object",
        properties: {
          "status" => { type: "string", enum: %w[answer insufficient_information] },
          "direct_answer" => { type: "string" },
          "supporting_example" => { type: "string" },
          "qualification" => { type: "string" },
          "source_ids" => { type: "array", items: { type: "string" }, maxItems: 6 }
        },
        required: %w[status direct_answer supporting_example qualification source_ids], additionalProperties: false
      }
    }.freeze

    def initialize(provider:, retriever: PublicCorpusRetriever.new, rules: nil)
      @provider = provider
      @retriever = retriever
      @rules = rules
    end

    def call(question:, decision: nil, prior_source_ids: [])
      documents, coverage = retrieve_with_coverage(question: question, decision: decision, prior_source_ids: prior_source_ids)
      response = @provider.structured_call(
        system_prompt: system_prompt,
        user_content: JSON.generate(
          question: question,
          decision: decision,
          coverage: coverage,
          sources: documents.map { |document| { id: document.id, title: document.title, url: document.url, content: document.body } }
        ),
        schema: SCHEMA,
        max_completion_tokens: 700
      )
      result = response.fetch("result")
      source_ids = Array(result["source_ids"]) & documents.map(&:id)
      status, answer = verify_response(result: result, source_ids: source_ids)
      {
        "status" => status, "answer" => answer,
        "evidence_ids" => source_ids, "source_urls" => documents.select { |document| source_ids.include?(document.id) }.map(&:url),
        "evaluation" => (response["__telemetry"] || {}).merge("retrieval_trace" => retrieval_trace, "coverage" => coverage)
      }
    end

    private

    def retrieval_trace
      trace = @retriever.respond_to?(:last_trace) ? @retriever.last_trace : nil
      trace.is_a?(Hash) ? trace : {}
    end

    def requested_scope(decision)
      parts = Array(decision&.fetch("parts", []))
      scopes = parts.filter_map { |part| part["scope"] if %w[dogly non_dogly other_employer personal].include?(part["scope"]) }.uniq
      scopes.one? ? scopes.first : nil
    end

    def retrieve_with_coverage(question:, decision:, prior_source_ids:)
      if follow_up?(decision) && prior_source_ids.any?
        documents = Array(prior_source_ids).filter_map { |source_id| @retriever.find(source_id) }.first(6)
        return [ documents, [ { "part" => 1, "scope" => "prior_referent", "dimensions" => [], "evidence_requirements" => [], "source_ids" => documents.map(&:id), "covered" => documents.any? } ] ]
      end

      parts = Array(decision&.fetch("parts", []))
      parts = [ {} ] if parts.empty?
      documents = []
      coverage = parts.each_with_index.map do |part, index|
        scope = part["scope"] if %w[dogly non_dogly other_employer personal].include?(part["scope"])
        selected = @retriever.call(question, scope: scope)
        documents.concat(selected)
        {
          "part" => index + 1, "scope" => scope || "unrestricted",
          "dimensions" => Array(part["dimensions"]), "evidence_requirements" => Array(part["evidence_requirements"]),
          "source_ids" => selected.map(&:id), "covered" => selected.any?
        }
      end
      [ documents.uniq(&:id).first(6), coverage ]
    end

    def follow_up?(decision)
      decision&.fetch("answer_shape", nil) == "follow_up"
    end

    # Keep the model focused on answer roles and make the final wording
    # deterministic. The legacy fallback keeps fixture-based callers usable
    # while the production schema requires the structured fields.
    def render_answer(result)
      sections = if result.key?("direct_answer")
        [ result["direct_answer"], result["supporting_example"], result["qualification"] ]
      else
        [ result["answer"] ]
      end
      RecruiterAnswerSanitizer.clean(sections.filter_map { |section| section.to_s.strip.presence }.join(" "))
    end

    # A model may only make a public-corpus answer when it points back to at
    # least one supplied document. This is deliberately a useful recruiter
    # fallback rather than an exposed validation error.
    def verify_response(result:, source_ids:)
      answer = render_answer(result)
      return [ "insufficient_information", "The published site does not provide enough detail to answer that reliably." ] if result["status"] == "answer" && source_ids.empty?

      [ result["status"], answer ]
    end

    def system_prompt
      rules = @rules ? "\nRules:\n- #{@rules.instructions.join("\n- ")}" : ""
      <<~PROMPT + rules
        Answer the recruiter question using only the supplied published source documents.
        Do not infer ownership, expertise, rankings, causality, metrics, chronology, or personal preference.
        If the sources do not support the requested claim, use insufficient_information and say only what is missing.
        For broad candidate-characterization questions, lead with a candidate-level synthesis in 80–140 words:
        identity, differentiator, scope or trajectory, and at most one concise example. Source ordering must not
        choose the lead. Include a boundary only when it materially qualifies the answer.
        For soft-skills questions, lead with documented engineering-context behaviors such as collaboration,
        stakeholder clarification, tradeoff communication, feedback, or mentorship. A retail example may only
        appear as a clearly labeled supporting example and never as engineering-management experience.
        For project-comparison questions, identify the documented project scope, systems, ownership,
        collaboration, outcome, and limitation. Never select a project as largest or most complex merely
        because it was retrieved first or contains a matching technology; offer a qualified representative
        example when no comparison basis exists.
        For capability or gap questions, state the direct boundary first, then only relevant adjacent
        foundation and demonstrated learning or adaptation, followed by an explicit transfer limit.
        For compound questions, the coverage list identifies which question parts have retrieved public support.
        When at least one part is covered, return status=answer: answer the supported portion directly and use
        qualification only to name the specific unsupported portion. Do not replace a useful partial answer with
        a blanket insufficiency, and do not manufacture the missing fact. Use insufficient_information only when
        no requested portion has public support.
        Return a compact answer frame: direct_answer answers the question in one or two sentences;
        supporting_example is one short, distinct relevant example or an empty string; qualification is a
        material limitation or scope clarification or an empty string. Do not repeat the lead across fields,
        narrate a full case study for a narrow question, use headings or bullets, or mention planning, evidence,
        retrieval, sources, or internal process. Return source_ids only from the supplied source IDs.
      PROMPT
    end
  end
end
