namespace :ask_jared do
  desc "Import repository-evidenced candidate knowledge privately and optionally queue embeddings"
  task populate_candidate_knowledge: :environment do
    entries = AskJared::CandidateKnowledgeInventory.new.sync!
    entries.each do |entry|
      AskJared::GenerateEmbeddingJob.perform_later(entry.id) if ENV["ASK_JARED_QUEUE_EMBEDDINGS"] == "true"
    end
    puts "Imported or updated #{entries.length} private candidate knowledge entries."
    puts "Embedding jobs queued: #{ENV['ASK_JARED_QUEUE_EMBEDDINGS'] == 'true' ? entries.length : 0}."
  end

  desc "Finalize Jared-approved recruiter knowledge and generate production embeddings"
  task finalize_recruiter_knowledge: :environment do
    finalizer = AskJared::FinalizeRecruiterKnowledge.new
    entries = finalizer.call
    puts "Finalized #{entries.length} entries."
    puts "Preflight:"
    puts JSON.pretty_generate(finalizer.preflight_report)
    puts "Postflight:"
    puts JSON.pretty_generate(finalizer.validation_report)
  end

  desc "Run the public-corpus-only and public-corpus-plus-Rules evaluation arms"
  task evaluate_public_corpus: :environment do
    model = ENV.fetch("ASK_JARED_MODEL", AskJared::ModelConfig::CANONICAL_MODEL)
    checkpoint_path = ENV.fetch("ASK_JARED_EVALUATION_CHECKPOINT", Rails.root.join("docs/ask-jared/phase2/public-corpus-paired-#{model}.json").to_s)
    provider = AskJared::OpenAiProvider.new(model: model)
    evaluation = AskJared::PublicCorpusEvaluation.new(
      answerer: AskJared::PublicCorpusAnswerer.new(provider: provider),
      rules_answerer: AskJared::PublicCorpusAnswerer.new(provider: provider, rules: AskJared::PublicCorpusRules.default)
    )

    evaluation.run_pair(checkpoint_path: checkpoint_path, model: model, retry_failed: ENV["ASK_JARED_RETRY_FAILED"] == "true")
    puts "Paired public-corpus evaluation checkpoint: #{checkpoint_path}"
  end
end
