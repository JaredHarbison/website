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
    entries = AskJared::FinalizeRecruiterKnowledge.new.call
    retrievable = KnowledgeEntry.recruiter_retrievable
    missing_embeddings = retrievable.where(embedding: nil).pluck(:source_reference)
    private_leaks = KnowledgeEntry.where.not(id: retrievable.select(:id)).where(visibility: "recruiter_visible").pluck(:source_reference)
    raise "Recruiter-visible entries missing embeddings: #{missing_embeddings.join(', ')}" if missing_embeddings.any?
    raise "Unapproved recruiter-visible entries: #{private_leaks.join(', ')}" if private_leaks.any?

    counts = KnowledgeEntry.group(:approval_status, :visibility).count
    puts "Finalized #{entries.length} entries with #{retrievable.count} recruiter embeddings."
    puts "Counts: #{counts.inspect}"
  end
end
