class CreateEngagementEvents < ActiveRecord::Migration[8.0]
  def change
    json_type = connection.adapter_name == "PostgreSQL" ? :jsonb : :json

    create_table :engagement_events do |t|
      t.references :opportunity, foreign_key: true
      t.references :ask_token, foreign_key: true
      t.string :event_type, null: false
      t.string :event_key, null: false
      t.string :session_digest, null: false
      t.string :ip_digest
      t.string :user_agent_class
      t.public_send(json_type, :metadata, null: false, default: {})
      t.datetime :occurred_at, null: false
      t.boolean :meaningful, null: false, default: false
      t.timestamps
    end

    add_index :engagement_events, :event_key, unique: true
    add_index :engagement_events, [ :opportunity_id, :occurred_at ]
    add_index :engagement_events, [ :event_type, :meaningful ]
  end
end
