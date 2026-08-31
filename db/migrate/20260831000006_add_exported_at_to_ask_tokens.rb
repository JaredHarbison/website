class AddExportedAtToAskTokens < ActiveRecord::Migration[8.0]
  def change
    add_column :ask_tokens, :exported_at, :datetime
    add_index :ask_tokens, [ :status, :exported_at ]
  end
end
