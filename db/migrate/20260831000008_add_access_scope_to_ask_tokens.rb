# Retained as a no-op so checkouts that briefly contained the superseded
# direct-share scope migration have a continuous migration history. Manual
# links use the existing Opportunity/AskToken lifecycle and need no new token
# scope or parallel authorization path.
class AddAccessScopeToAskTokens < ActiveRecord::Migration[8.0]
  def change
  end
end
