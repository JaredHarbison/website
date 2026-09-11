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
          "answer" => { type: "string" },
          "source_ids" => { type: "array", items: { type: "string" }, maxItems: 6 }
        },
        required: %w[status answer source_ids], additionalProperties: false
      }
    }.freeze

    def initialize(provider:, retriever: PublicCorpusRetriever.new, rules: nil)
      @provider = provider
      @retriever = retriever
      @rules = rules
    end

    def call(question:)
      documents = @retriever.call(question)
      response = @provider.structured_call(
        system_prompt: system_prompt,
        user_content: JSON.generate(question: question, sources: documents.map { |document| { id: document.id, title: document.title, url: document.url, content: document.body } }),
        schema: SCHEMA,
        max_completion_tokens: 700
      )
      result = response.fetch("result")
      source_ids = Array(result["source_ids"]) & documents.map(&:id)
      {
        "status" => result["status"], "answer" => result["answer"].to_s,
        "evidence_ids" => source_ids, "source_urls" => documents.select { |document| source_ids.include?(document.id) }.map(&:url),
        "evaluation" => (response["__telemetry"] || {})
      }
    end

    private

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
        Return source_ids only from the supplied source IDs. Do not cite or discuss internal retrieval behavior.
      PROMPT
    end
  end
end
