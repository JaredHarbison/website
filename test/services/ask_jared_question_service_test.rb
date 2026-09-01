require "test_helper"
require_relative "../../app/services/ask_jared/recruiter_answer_sanitizer"

class AskJaredQuestionServiceTest < ActiveSupport::TestCase
  FakeProvider = Struct.new(:response) do
    def call(**)
      response
    end
  end

  class FailingProvider
    def call(**)
      raise "provider should not be called"
    end
  end

  setup do
    EngagementEvent.delete_all
    KnowledgeEntry.delete_all
    AskToken.delete_all
    Opportunity.delete_all
    @token_service = AskJared::TokenService.new(secret: Rails.application.secret_key_base)
    _token, @raw_token = @token_service.mint!
    @token_service.claim!(raw_token: @raw_token, external_id: "role-question-1", company: "Acme", role_title: "Engineer")
  end

  test "retrieves approved recruiter-visible evidence and filters model references" do
    entry = KnowledgeEntry.create!(title: "Rails integration", body: "Built idempotent Shopify webhooks.", public_url: "https://example.test/shopify", entry_type: "project", approval_status: "approved", visibility: "recruiter_visible", source_type: "public_site", source_reference: "shopify", source_fingerprint: "abc")
    KnowledgeEntry.create!(title: "Private Rails detail", body: "Do not expose this.", entry_type: "project", approval_status: "approved", visibility: "internal", source_type: "anecdote", source_reference: "private", source_fingerprint: "def")
    provider = FakeProvider.new({ "status" => "answer", "answer" => "Supported.", "evidence_ids" => [ entry.id.to_s, "private" ], "source_urls" => [ entry.public_url, "https://unapproved.test" ] })
    service = AskJared::QuestionService.new(token_service: @token_service, provider: provider)

    response = service.call(raw_token: @raw_token, question: "Tell me about Rails integration", session_id: "session-1", request_id: "request-1")

    assert_equal [ entry.id.to_s ], response["evidence_ids"]
    assert_equal [ entry.public_url ], response["source_urls"]
    assert_equal %w[question_submitted answer_returned], EngagementEvent.order(:id).pluck(:event_type)
  end

  test "returns insufficient information without calling a provider when no approved evidence matches" do
    provider = FailingProvider.new
    service = AskJared::QuestionService.new(token_service: @token_service, provider: provider)

    response = service.call(raw_token: @raw_token, question: "What about distributed systems?", session_id: "session-1", request_id: "request-2")

    assert_equal "insufficient_information", response["status"]
    assert_equal 1, EngagementEvent.where(event_type: "question_submitted").count
  end

  test "rejects garbage before retrieval or a model request" do
    service = AskJared::QuestionService.new(token_service: @token_service)

    assert_raises(ArgumentError) { service.call(raw_token: @raw_token, question: "x" * 21, session_id: "session-1", request_id: "request-3") }
  end

  test "allows an owner preview without token usage or engagement records" do
    entry = KnowledgeEntry.create!(title: "Approved fact", body: "A recruiter-safe fact.", entry_type: "fact", approval_status: "approved", visibility: "recruiter_visible", source_type: "public_site", source_reference: "owner-preview", source_fingerprint: "preview")
    provider = FakeProvider.new({ "status" => "answer", "answer" => "Supported.", "evidence_ids" => [ entry.id.to_s ], "source_urls" => [] })
    service = AskJared::QuestionService.new(token_service: @token_service, provider: provider)

    response = service.call(raw_token: nil, question: "What is approved?", session_id: "owner-session", request_id: "owner-request", admin_preview: true)

    assert_equal "answer", response["status"]
    assert_empty EngagementEvent.all
    assert_empty AskUsageEvent.all
  end

  test "sanitizes model markdown and internal evidence references before recruiter delivery" do
    entry = KnowledgeEntry.create!(title: "Approved fact", body: "A recruiter-safe fact.", entry_type: "fact", approval_status: "approved", visibility: "recruiter_visible", source_type: "public_site", source_reference: "sanitized", source_fingerprint: "sanitized")
    provider = FakeProvider.new({ "status" => "answer", "answer" => "**Onboarding UX** improved. (Evidence [17]) &#x20; 1\\.", "evidence_ids" => [ entry.id.to_s ], "source_urls" => [] })
    service = AskJared::QuestionService.new(token_service: @token_service, provider: provider)

    response = service.call(raw_token: @raw_token, question: "What is approved?", session_id: "session-1", request_id: "request-sanitize")

    assert_equal "Onboarding UX improved. 1.", response["answer"]
    refute_includes response["answer"], "17"
    refute_includes response["answer"], "**"
  end
end
