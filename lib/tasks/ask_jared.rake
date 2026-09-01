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
end
