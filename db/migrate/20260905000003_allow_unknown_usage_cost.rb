class AllowUnknownUsageCost < ActiveRecord::Migration[8.0]
  def change
    change_column_default :ask_usage_events, :estimated_cost_cents, from: 0, to: nil
    change_column_null :ask_usage_events, :estimated_cost_cents, true
  end
end
