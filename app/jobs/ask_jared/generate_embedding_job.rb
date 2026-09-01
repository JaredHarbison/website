module AskJared
  class GenerateEmbeddingJob < ApplicationJob
    queue_as :default

    def perform(knowledge_entry_id)
      entry = ::KnowledgeEntry.find(knowledge_entry_id)
      EmbeddingService.new.generate!(entry)
    end
  end
end
