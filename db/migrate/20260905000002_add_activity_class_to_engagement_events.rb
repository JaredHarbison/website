class AddActivityClassToEngagementEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :engagement_events, :activity_class, :string, null: false, default: "unclassified"
    add_index :engagement_events, :activity_class
  end
end
