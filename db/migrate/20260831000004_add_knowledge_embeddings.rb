class AddKnowledgeEmbeddings < ActiveRecord::Migration[8.0]
  EMBEDDING_DIMENSIONS = 1_536

  def up
    if postgres?
      enable_extension "vector"
      execute "ALTER TABLE knowledge_entries ADD COLUMN embedding vector(#{EMBEDDING_DIMENSIONS})"
      execute "CREATE INDEX index_knowledge_entries_on_embedding ON knowledge_entries USING hnsw (embedding vector_cosine_ops)"
    else
      add_column :knowledge_entries, :embedding, :text
    end
    add_column :knowledge_entries, :embedding_model, :string
    add_column :knowledge_entries, :embedding_generated_at, :datetime
  end

  def down
    if postgres?
      remove_index :knowledge_entries, name: "index_knowledge_entries_on_embedding"
    end
    remove_columns :knowledge_entries, :embedding, :embedding_model, :embedding_generated_at
  end

  private

  def postgres?
    connection.adapter_name.to_s.downcase.include?("postgres")
  end
end
