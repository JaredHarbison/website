require "test_helper"

class AskJaredAnalyticsBoundaryTest < ActiveSupport::TestCase
  setup do
    EngagementEvent.delete_all
    Opportunity.delete_all
    @previous = ENV[AskJared::AnalyticsBoundary::ENV_KEY]
  end

  teardown do
    ENV[AskJared::AnalyticsBoundary::ENV_KEY] = @previous
  end

  test "requires both the launch boundary and non-QA opportunity" do
    ENV[AskJared::AnalyticsBoundary::ENV_KEY] = 1.hour.ago.iso8601
    old = opportunity("old", tracker_source: "manual")
    qa = opportunity("qa", tracker_source: "internal_qa")
    live = opportunity("live", tracker_source: "manual")
    create_event(old, "old", 2.hours.ago)
    create_event(qa, "qa", 1.minute.ago)
    create_event(live, "live", 1.minute.ago)

    assert_equal [ live.id ], EngagementEvent.from_live_recruiter.pluck(:opportunity_id)
    assert_equal [ old.id, live.id ], EngagementEvent.from_real_prospect.order(:opportunity_id).pluck(:opportunity_id)
  end

  test "unset boundary excludes all activity rather than treating history as live" do
    ENV.delete(AskJared::AnalyticsBoundary::ENV_KEY)
    live = opportunity("historical", tracker_source: nil)
    create_event(live, "historical", Time.current)

    assert_empty EngagementEvent.from_live_recruiter
  end

  private

  def opportunity(id, tracker_source:)
    Opportunity.create!(external_id: id, company: id, role_title: "QA", tracker_source: tracker_source)
  end

  def create_event(opportunity, key, occurred_at)
    EngagementEvent.create!(opportunity: opportunity, event_type: "question_submitted", event_key: key, session_digest: key, activity_class: AskJared::ActivityClassification.for(opportunity), occurred_at: occurred_at, meaningful: true)
  end
end
