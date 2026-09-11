require "json"

module AskJared
  # Evaluation-only answerer. Its inputs are published documents only; Rules
  # and private KnowledgeEntry records are intentionally absent in this arm.
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

    def initialize(provider:, retriever: PublicCorpusRetriever.new)
      @provider = provider
      @retriever = retriever
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
      <<~PROMPT
        Answer the recruiter question using only the supplied published source documents.
        Do not infer ownership, expertise, rankings, causality, metrics, chronology, or personal preference.
        If the sources do not support the requested claim, use insufficient_information and say only what is missing.
        Return source_ids only from the supplied source IDs. Do not cite or discuss internal retrieval behavior.
      PROMPT
    end
  end
end
