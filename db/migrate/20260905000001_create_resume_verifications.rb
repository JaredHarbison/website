class CreateResumeVerifications < ActiveRecord::Migration[8.0]
  def change
    create_table :resume_verifications do |t|
      t.references :opportunity, foreign_key: true
      t.references :ask_token, foreign_key: true
      t.string :token_digest, null: false
      t.string :email, null: false
      t.string :session_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :verified_at
      t.datetime :delivered_at
      t.timestamps
    end

    add_index :resume_verifications, :token_digest, unique: true
    add_index :resume_verifications, [ :ask_token_id, :created_at ]
  end
end
