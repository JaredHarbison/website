class CreateKnowledgeEntries < ActiveRecord::Migration[8.0]
  def change
    enable_extension "pgcrypto"
    json_type = connection.adapter_name == "PostgreSQL" ? :jsonb : :json
    create_table :knowledge_entries do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.text :short_body
      t.string :entry_type, null: false
      t.string :approval_status, null: false, default: "candidate"
      t.string :visibility, null: false, default: "private"
      t.string :confidence
      t.string :source_type, null: false
      t.string :source_reference, null: false
      t.string :source_url
      t.string :public_url
      t.string :source_fingerprint, null: false
      t.public_send(json_type, :metadata, null: false, default: {})
      t.public_send(json_type, :reviewer_edits, null: false, default: {})
      t.string :reviewed_by
      t.text :reviewer_note
      t.datetime :approved_at
      t.timestamps
    end

    add_index :knowledge_entries, :source_reference, unique: true
    add_index :knowledge_entries, [ :approval_status, :visibility ]
    add_index :knowledge_entries, :source_fingerprint
  end
end
