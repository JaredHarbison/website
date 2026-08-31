class AddAccessScopeToAskTokens < ActiveRecord::Migration[8.0]
  def change
    add_column :ask_tokens, :access_scope, :string, null: false, default: "opportunity"
    add_index :ask_tokens, :access_scope
  end
end
