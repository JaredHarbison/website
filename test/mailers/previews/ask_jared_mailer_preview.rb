require "ostruct"

class AskJaredMailerPreview < ActionMailer::Preview
  def issue_report
    event = OpenStruct.new(
      metadata: {
        "issue_category" => "Confusing answer", "answer_status" => "answer",
        "feedback" => "The answer was hard to follow.", "question" => "What did Jared own?",
        "answer" => "He owned the integration workflow.", "question_intent" => "ownership",
        "model" => "gpt-5.6-sol", "latency_ms" => 1200, "evidence_count" => 2,
        "evidence_ids" => [ "50", "51" ], "validation" => "passed"
      }, occurred_at: Time.current, session_digest: "preview-session"
    )
    opportunity = OpenStruct.new(company: "Example Co", role_title: "Staff Engineer")
    AskJaredMailer.issue_report(event, opportunity, "taylor@example.com")
  end
end
