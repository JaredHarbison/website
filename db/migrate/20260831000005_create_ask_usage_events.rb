class CreateAskUsageEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :ask_usage_events do |t|
      t.references :opportunity, foreign_key: true
      t.references :ask_token, foreign_key: true
      t.string :request_id, null: false
      t.string :session_digest, null: false
      t.string :status, null: false
      t.integer :estimated_cost_cents, null: false, default: 0
      t.integer :input_tokens
      t.integer :output_tokens
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :ask_usage_events, :request_id, unique: true
    add_index :ask_usage_events, [ :ask_token_id, :occurred_at ]
    add_index :ask_usage_events, [ :session_digest, :occurred_at ]
  end
end
