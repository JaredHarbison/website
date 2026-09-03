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
end
