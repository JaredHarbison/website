require "test_helper"

class AskJaredIssueReportServiceTest < ActiveSupport::TestCase
  setup do
    EngagementEvent.delete_all
    AskToken.delete_all
    Opportunity.delete_all
    _token, @raw_token = AskJared::TokenService.new.mint!
    AskJared::TokenService.new.claim!(raw_token: @raw_token, external_id: "issue-role", company: "Acme", role_title: "Engineer")
  end

  test "persists the report with the matching server-side answer context" do
    session_id = "issue-session"
    AskJared::EngagementService.new.record!(
      raw_token: @raw_token, event_type: "answer_returned", session_id: session_id,
      event_key: "answer-1", metadata: {
        "question" => "How does Jared learn unfamiliar technology?", "answer" => "He researches first.",
        "question_intent" => "learning", "evidence_ids" => [ "story:stripe-learning-ramp" ],
        "skeleton_roles" => [ "primary_fact" ], "model" => "gpt-5.6-terra", "validation" => { "status" => "pass" }, "turn" => 1
      }
    )

    event = AskJared::IssueReportService.new.call(
      raw_token: @raw_token, session_id: session_id, question: "How does Jared learn unfamiliar technology?",
      answer: "He researches first.", answer_status: "answer", category: "Confusing answer",
      feedback: "Please explain the process.", contact: "prospect@example.com", page: "/api/ask/issues",
      ip: "192.0.2.1", user_agent: "Mozilla/5.0"
    )

    assert_equal "issue_reported", event.event_type
    assert_equal "learning", event.metadata["question_intent"]
    assert_equal [ "story:stripe-learning-ramp" ], event.metadata["evidence_ids"]
    assert_equal "gpt-5.6-terra", event.metadata["model"]
    assert_equal "prospect@example.com", event.metadata["contact"]
  end

  test "rejects an invalid category and blank feedback" do
    assert_raises(ArgumentError) do
      AskJared::IssueReportService.new.call(
        raw_token: @raw_token, session_id: "issue-session", question: "Q", answer: "A", answer_status: "answer",
        category: "Nope", feedback: "", contact: "", page: "/ask", ip: nil, user_agent: ""
      )
    end
    assert_equal 0, EngagementEvent.count
  end
  test "renders an owner notification without exposing the raw token" do
    event = EngagementEvent.create!(
      opportunity: Opportunity.first, ask_token: AskToken.first, event_type: "issue_reported",
      event_key: "mail-1", session_digest: "session", occurred_at: Time.current,
      meaningful: true, metadata: { "issue_category" => "Incorrect fact", "question" => "Q", "answer" => "A", "feedback" => "F" }
    )
    previous = ENV["JARED_ISSUE_EMAIL"]
    ENV["JARED_ISSUE_EMAIL"] = "jared@example.com"

    mail = AskJaredMailer.issue_report(event, Opportunity.first, "prospect@example.com")

    assert_equal [ "jared@example.com" ], mail.to
    assert_includes mail.body.to_s, "Incorrect fact"
    refute_includes mail.body.to_s, @raw_token
  ensure
    ENV["JARED_ISSUE_EMAIL"] = previous
  end

  test "keeps the persisted report successful when notification enqueue fails" do
    previous = ENV["JARED_ISSUE_EMAIL"]
    ENV["JARED_ISSUE_EMAIL"] = "jared@example.com"
    mailer = Object.new
    def mailer.deliver_later
      raise IOError, "mail transport unavailable"
    end
    original_issue_report = AskJaredMailer.method(:issue_report)
    AskJaredMailer.define_singleton_method(:issue_report) { |_event, _opportunity, _contact| mailer }
    event = AskJared::IssueReportService.new.call(
      raw_token: @raw_token, session_id: "issue-session", question: "Q", answer: "A", answer_status: "answer",
      category: "Technical issue", feedback: "Something went wrong.", contact: "", page: "/ask", ip: nil, user_agent: ""
    )

    assert event.persisted?
    assert_equal "issue_reported", event.event_type
  ensure
    AskJaredMailer.define_singleton_method(:issue_report, original_issue_report) if original_issue_report
    ENV["JARED_ISSUE_EMAIL"] = previous
  end
end
