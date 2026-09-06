class CreateCandidateContextRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :candidate_context_records do |t|
      t.string :stable_key, null: false
      t.string :corpus_version, null: false
      t.string :category, null: false
      t.string :approval_status, null: false, default: "draft"
      t.string :privacy_classification, null: false, default: "private"
      t.text :purpose
      t.text :guidance, null: false
      t.json :source_references, null: false, default: []
      t.json :provenance, null: false, default: {}
      t.json :affects, null: false, default: []
      t.json :intent_tags, null: false, default: []
      t.json :relationships, null: false, default: {}
      t.integer :priority, null: false, default: 0
      t.datetime :retired_at
      t.timestamps
    end

    add_index :candidate_context_records, :stable_key, unique: true
    add_index :candidate_context_records, [ :corpus_version, :approval_status ]
  end
end
