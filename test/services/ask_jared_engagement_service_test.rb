require "test_helper"
require_relative "../../app/services/ask_jared/token_service"
require_relative "../../app/services/ask_jared/engagement_service"

class AskJaredEngagementServiceTest < ActiveSupport::TestCase
  setup do
    EngagementEvent.delete_all
    AskToken.delete_all
    Opportunity.delete_all
    @token_service = AskJared::TokenService.new(secret: "test-secret")
    _token, @raw_token = @token_service.mint!
  end

  test "records scanner/page activity as non-meaningful" do
    event = service.record!(raw_token: @raw_token, event_type: "page_view", session_id: "session-1", ip: "192.0.2.1")

    assert_not event.meaningful
    assert_not_equal "192.0.2.1", event.ip_digest
  end

  test "records human interaction as meaningful" do
    event = service.record!(raw_token: @raw_token, event_type: "question_submitted", session_id: "session-1", event_key: "request-1", metadata: { "question_category" => "architecture", "ignored" => "secret" })

    assert event.meaningful
    assert_equal({ "question_category" => "architecture" }, event.metadata)
  end

  test "classifies explicit QA opportunities authoritatively" do
    qa = @token_service.claim!(raw_token: @raw_token, external_id: "qa-opportunity", company: "Internal QA", role_title: "QA", tracker_source: "internal_qa")

    event = service.record!(raw_token: @raw_token, event_type: "question_submitted", session_id: "session-qa", event_key: "qa-request", metadata: { "activity_class" => "unclassified" })

    assert_equal qa, event.opportunity
    assert_equal "internal_qa", event.activity_class
    assert_equal [ event.id ], EngagementEvent.from_internal_qa.pluck(:id)
    assert_empty EngagementEvent.from_real_prospect.pluck(:id)
  end

  test "preserves manual activity classification for real share links" do
    manual = @token_service.claim!(raw_token: @raw_token, external_id: "manual-opportunity", company: "Manual Share", role_title: "Engineer", tracker_source: "manual")

    event = service.record!(raw_token: @raw_token, event_type: "question_submitted", session_id: "session-manual", event_key: "manual-request")

    assert_equal manual, event.opportunity
    assert_equal "manual_share", event.activity_class
  end

  test "duplicate event keys are idempotent" do
    first = service.record!(raw_token: @raw_token, event_type: "answer_returned", session_id: "session-1", event_key: "request-1")
    second = service.record!(raw_token: @raw_token, event_type: "answer_returned", session_id: "session-2", event_key: "request-1")

    assert_equal first.id, second.id
    assert_equal 1, EngagementEvent.count
  end

  private

  def service
    @service ||= AskJared::EngagementService.new(secret: "test-secret")
  end
end
