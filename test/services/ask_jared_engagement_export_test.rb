require "test_helper"

class AskJaredEngagementExportTest < ActiveSupport::TestCase
  setup do
    EngagementEvent.delete_all
    AskUsageEvent.delete_all
    AskToken.delete_all
    Opportunity.delete_all
    @opportunity = Opportunity.create!(external_id: "role-export-1", company: "Acme", role_title: "Engineer", application_state: "submitted", submitted_at: 8.days.ago)
    @token = AskToken.create!(token_digest: "digest-export", token_prefix: "export-1", status: "submitted", opportunity: @opportunity)
  end

  test "exports aggregate meaningful engagement without privacy-sensitive identifiers" do
    create_event("question_submitted", "session-a", "network-a", 9.days.ago)
    create_event("question_submitted", "session-b", "network-b", 8.days.ago)
    create_event("page_view", "scanner", "network-c", 7.days.ago)
    AskUsageEvent.create!(opportunity: @opportunity, ask_token: @token, request_id: "request-export-1", session_digest: "session-a", status: "completed", estimated_cost_cents: 3, occurred_at: 8.days.ago)

    summary = AskJared::EngagementExport.new.call.first

    assert_equal 2, summary[:meaningful_session_count]
    assert_equal 2, summary[:meaningful_question_count]
    assert_equal true, summary[:possible_internal_share]
    assert_equal "medium", summary[:internal_share_confidence]
    assert_equal true, summary[:follow_up_candidate]
    assert_equal 3, summary[:usage_cost_cents]
    refute summary.keys.any? { |key| key.to_s.include?("digest") }
  end

  private

  def create_event(type, session, network, occurred_at)
    EngagementEvent.create!(opportunity: @opportunity, ask_token: @token, event_type: type,
                             event_key: "#{type}-#{session}", session_digest: session,
                             ip_digest: network, occurred_at: occurred_at, meaningful: true)
  end
end
