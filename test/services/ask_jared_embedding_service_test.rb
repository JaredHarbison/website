require "test_helper"

class AskJaredEmbeddingServiceTest < ActiveSupport::TestCase
  FakeProvider = Struct.new(:vector) do
    def call(_text)
      vector
    end
  end

  setup do
    KnowledgeEntry.delete_all
    @entry = KnowledgeEntry.create!(title: "Project", body: "Approved evidence", entry_type: "project",
                                    source_type: "code", source_reference: "project-1", source_fingerprint: "fp-1")
  end

  test "stores the vector and generation metadata" do
    vector = Array.new(1536, 0.25)
    AskJared::EmbeddingService.new(provider: FakeProvider.new(vector)).generate!(@entry)

    @entry.reload
    stored_vector = @entry.embedding.is_a?(String) ? JSON.parse(@entry.embedding) : @entry.embedding
    assert_equal vector, stored_vector
    assert_equal AskJared::EmbeddingService::MODEL, @entry.embedding_model
    assert_not_nil @entry.embedding_generated_at
  end
end
