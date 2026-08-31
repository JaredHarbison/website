class AddPurposeToOpportunities < ActiveRecord::Migration[8.0]
  def change
    add_column :opportunities, :purpose, :text
  end
end
