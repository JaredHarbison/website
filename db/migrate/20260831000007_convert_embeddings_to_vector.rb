class ConvertEmbeddingsToVector < ActiveRecord::Migration[8.0]
  DIMENSIONS = 1_536

  def up
    return unless connection.adapter_name.to_s.downcase.include?("postgres")

    enable_extension "vector"
    execute <<~SQL
      ALTER TABLE knowledge_entries
      ALTER COLUMN embedding TYPE vector(#{DIMENSIONS})
      USING NULLIF(embedding, '')::vector
    SQL
    execute "CREATE INDEX IF NOT EXISTS index_knowledge_entries_on_embedding ON knowledge_entries USING hnsw (embedding vector_cosine_ops)"
  end

  def down
    return unless connection.adapter_name.to_s.downcase.include?("postgres")

    remove_index :knowledge_entries, name: "index_knowledge_entries_on_embedding", if_exists: true
    execute "ALTER TABLE knowledge_entries ALTER COLUMN embedding TYPE text USING embedding::text"
  end
end
