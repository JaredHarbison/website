require "test_helper"
require "ostruct"

class MailerTest < ActionMailer::TestCase
  test "resume verification is a multipart email with a site-themed CTA" do
    verification = OpenStruct.new(email: "recruiter@example.com")
    mail = ResumeMailer.verification(verification, "preview-token")

    assert_equal [ "recruiter@example.com" ], mail.to
    assert_equal "Verify your résumé request", mail.subject
    assert mail.html_part
    assert mail.text_part
    assert_includes mail.html_part.body.to_s, "Verify email address"
    assert_includes mail.html_part.body.to_s, "#86d99a"
    assert_includes mail.text_part.body.to_s, "preview-token"
  end

  test "resume delivery is multipart and includes the approved attachment" do
    verification = OpenStruct.new(email: "recruiter@example.com")
    previous = ENV["APPROVED_GENERIC_RESUME_PATH"]
    ENV["APPROVED_GENERIC_RESUME_PATH"] = "tmp/pdfs/jared-resume.png"
    mail = ResumeMailer.resume(verification)

    assert_equal [ "recruiter@example.com" ], mail.to
    assert mail.html_part
    assert mail.text_part
    assert_equal [ "jared-resume.png" ], mail.attachments.map(&:filename)
    assert_includes mail.html_part.body.to_s, "Your résumé is attached"
  ensure
    ENV["APPROVED_GENERIC_RESUME_PATH"] = previous
  end

  test "contact mail preserves reply-to and escapes user content" do
    event = OpenStruct.new(metadata: { "name" => "A <B", "email" => "person@example.com", "message" => "<script>alert(1)</script>" })
    opportunity = OpenStruct.new(company: "Example Co", role_title: "Engineer")
    previous = ENV["JARED_ISSUE_EMAIL"]
    ENV["JARED_ISSUE_EMAIL"] = "jared@example.com"
    mail = ContactMailer.prospect_message(event, opportunity)

    assert_equal [ ENV.fetch("MAILER_FROM", "ask-jared@localhost") ], mail.from
    assert_equal [ "person@example.com" ], mail.reply_to
    assert mail.html_part
    assert mail.text_part
    assert_includes mail.html_part.body.to_s, "&lt;script&gt;"
    refute_includes mail.html_part.body.to_s, "<script>alert"
  ensure
    ENV["JARED_ISSUE_EMAIL"] = previous
  end

  test "issue reports preserve diagnostics and admin action" do
    event = OpenStruct.new(
      metadata: { "issue_category" => "Incorrect fact", "answer_status" => "answer", "feedback" => "Please check this.", "question" => "Q", "answer" => "A", "question_intent" => "ownership", "model" => "gpt-5.6-sol", "evidence_ids" => [ "50" ], "validation" => "passed" },
      occurred_at: Time.current, session_digest: "session"
    )
    opportunity = OpenStruct.new(company: "Example Co", role_title: "Engineer", to_param: "1")
    previous = ENV["JARED_ISSUE_EMAIL"]
    ENV["JARED_ISSUE_EMAIL"] = "jared@example.com"

    mail = AskJaredMailer.issue_report(event, opportunity, "person@example.com")

    assert_equal [ "jared@example.com" ], mail.to
    assert_includes mail.html_part.body.to_s, "View in Admin"
    assert_includes mail.text_part.body.to_s, "gpt-5.6-sol"
  ensure
    ENV["JARED_ISSUE_EMAIL"] = previous
  end
end
