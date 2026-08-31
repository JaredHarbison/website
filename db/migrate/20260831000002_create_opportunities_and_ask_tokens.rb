class CreateOpportunitiesAndAskTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :opportunities do |t|
      t.string :external_id, null: false
      t.string :company, null: false
      t.string :role_title, null: false
      t.string :tracker_source
      t.string :application_state, null: false, default: "pre_application"
      t.datetime :submitted_at
      t.timestamps
    end
    add_index :opportunities, :external_id, unique: true

    create_table :ask_tokens do |t|
      t.references :opportunity, foreign_key: true
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.string :status, null: false, default: "available"
      t.string :claim_key
      t.datetime :claimed_at
      t.datetime :submitted_at
      t.datetime :expires_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :ask_tokens, :token_digest, unique: true
    add_index :ask_tokens, [ :status, :expires_at ]
    add_index :ask_tokens, [ :claim_key, :status ], unique: true, where: "claim_key IS NOT NULL AND status IN ('claimed', 'submitted')"
  end
end
