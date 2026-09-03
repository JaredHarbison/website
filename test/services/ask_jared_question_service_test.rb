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

  class RepairProvider
    attr_reader :calls, :repair_calls

    def initialize(response:, repair_response:)
      @response = response
      @repair_response = repair_response
      @calls = 0
      @repair_calls = 0
    end

    def call(**)
      @calls += 1
      @response
    end

    def repair(**)
      @repair_calls += 1
      @repair_response
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

  test "resolves valid claim aliases and never delivers aliases or internal claim references" do
    entry = KnowledgeEntry.create!(title: "Approved fact", body: "A recruiter-safe fact.", metadata: { "recruiter_evidence" => { "claims" => [ { "text" => "The fact is supported.", "kind" => "demonstrated" } ] } }, entry_type: "fact", approval_status: "approved", visibility: "recruiter_visible", source_type: "public_site", source_reference: "story:alias", source_fingerprint: "alias")
    provider = FakeProvider.new({ "status" => "answer", "answer" => "The fact is supported. c1 story:alias#claim-0", "evidence_ids" => [ entry.id.to_s ], "source_urls" => [], "claim_refs" => [ "c1" ] })

    response = AskJared::QuestionService.new(token_service: @token_service, provider: provider).call(raw_token: @raw_token, question: "What is supported?", session_id: "alias-session", request_id: "alias-request")

    assert_equal "The fact is supported.", response["answer"]
    refute response.key?("claim_refs")
    refute_includes response["answer"], "c1"
    refute_includes response["answer"], "story:alias#claim-0"
  end

  test "derives evidence ownership from valid aliases when the model returns source references" do
    entry = KnowledgeEntry.create!(title: "Approved fact", body: "A recruiter-safe fact.", entry_type: "fact", approval_status: "approved", visibility: "recruiter_visible", source_type: "public_site", source_reference: "story:source-ref", source_fingerprint: "source-ref")
    provider = FakeProvider.new({ "status" => "answer", "answer" => "The fact is supported.", "evidence_ids" => [ "story:source-ref" ], "source_urls" => [], "claim_refs" => [ "c1" ] })

    response = AskJared::QuestionService.new(token_service: @token_service, provider: provider).call(raw_token: @raw_token, question: "What is supported?", session_id: "derived-evidence-session", request_id: "derived-evidence-request")

    assert_equal "answer", response["status"]
    assert_equal [ entry.id.to_s ], response["evidence_ids"]
    refute response.key?("claim_refs")
  end

  test "rejects entry IDs and aliases outside the supplied packet as claim references" do
    entry = KnowledgeEntry.create!(title: "Approved fact", body: "A recruiter-safe fact.", entry_type: "fact", approval_status: "approved", visibility: "recruiter_visible", source_type: "public_site", source_reference: "story:only", source_fingerprint: "only")
    provider = FakeProvider.new({ "status" => "answer", "answer" => "Supported.", "evidence_ids" => [ entry.id.to_s ], "source_urls" => [], "claim_refs" => [ entry.id.to_s ] })
    service = AskJared::QuestionService.new(token_service: @token_service, provider: provider)

    response = service.call(raw_token: @raw_token, question: "What is supported?", session_id: "bad-alias-session", request_id: "bad-alias-request")

    assert_equal "insufficient_information", response["status"]
  end

  test "removes unsupported predictive transfer claims while retaining factual evidence" do
    entry = KnowledgeEntry.create!(title: "Risk evidence", body: "A recruiter-safe fact.", metadata: { "recruiter_evidence" => { "claims" => [ { "text" => "Large-team experience is not established.", "kind" => "boundary" } ] } }, entry_type: "fact", approval_status: "approved", visibility: "recruiter_visible", source_type: "public_site", source_reference: "transfer-sanitized", source_fingerprint: "transfer-sanitized")
    provider = FakeProvider.new({ "status" => "answer", "answer" => "Large-team experience is not established, Additionally, This could impact his adaptability. His retail leadership is documented.", "evidence_ids" => [ entry.id.to_s ], "source_urls" => [] })
    service = AskJared::QuestionService.new(token_service: @token_service, provider: provider)

    response = service.call(raw_token: @raw_token, question: "What is the biggest hiring risk?", session_id: "session-1", request_id: "request-transfer-sanitize")

    assert_equal "Large-team experience is not established. His retail leadership is documented.", response["answer"]
  end

  test "repairs unsupported causal wording once using the same evidence packet" do
    first = KnowledgeEntry.create!(title: "First", body: "First evidence", entry_type: "project", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "repair-first", source_fingerprint: "repair-first")
    second = KnowledgeEntry.create!(title: "Second", body: "Second evidence", entry_type: "project", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "repair-second", source_fingerprint: "repair-second")
    provider = RepairProvider.new(
      response: { "status" => "answer", "answer" => "First led to second.", "evidence_ids" => [ first.id.to_s, second.id.to_s ], "source_urls" => [] },
      repair_response: { "status" => "answer", "answer" => "The evidence describes First and Second separately.", "evidence_ids" => [ first.id.to_s, second.id.to_s ], "source_urls" => [] }
    )
    service = AskJared::QuestionService.new(token_service: @token_service, provider: provider)

    response = service.call(raw_token: @raw_token, question: "Tell me about First and Second", session_id: "repair-session", request_id: "repair-request")

    assert_equal "The evidence describes First and Second separately.", response["answer"]
    assert_equal 1, provider.calls
    assert_equal 1, provider.repair_calls
  end

  test "repair receives and returns the same packet alias map" do
    entry = KnowledgeEntry.create!(title: "Approved fact", body: "The fact is supported.", entry_type: "fact", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "story:repair-alias", source_fingerprint: "repair-alias")
    provider = Class.new do
      attr_reader :contexts, :repair_response

      def initialize(entry)
        @entry = entry
        @contexts = []
        @repair_response = { "status" => "answer", "answer" => "The fact is supported.", "evidence_ids" => [ entry.id.to_s ], "source_urls" => [], "claim_refs" => [ "c1" ] }
      end

      def call(**)
        { "status" => "answer", "answer" => "The fact led to a result.", "evidence_ids" => [ @entry.id.to_s ], "source_urls" => [], "claim_refs" => [ "c1" ] }
      end

      def repair(context:, **)
        @contexts << context.formatted_context
        @repair_response
      end
    end.new(entry)
    service = AskJared::QuestionService.new(token_service: @token_service, provider: provider)

    response = service.call(raw_token: @raw_token, question: "What is supported?", session_id: "repair-alias-session", request_id: "repair-alias-request")

    assert_equal "answer", response["status"]
    assert_includes provider.contexts.first, "c1:"
    refute_includes provider.contexts.first, "story:repair-alias#claim-0"
  end

  test "fails closed when a repair introduces evidence or fails validation" do
    first = KnowledgeEntry.create!(title: "First", body: "First evidence", entry_type: "project", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "repair-fail-first", source_fingerprint: "repair-fail-first")
    second = KnowledgeEntry.create!(title: "Second", body: "Second evidence", entry_type: "project", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "repair-fail-second", source_fingerprint: "repair-fail-second")
    provider = RepairProvider.new(
      response: { "status" => "answer", "answer" => "First led to second.", "evidence_ids" => [ first.id.to_s, second.id.to_s ], "source_urls" => [] },
      repair_response: { "status" => "answer", "answer" => "First led to second.", "evidence_ids" => [ first.id.to_s, "999" ], "source_urls" => [] }
    )
    service = AskJared::QuestionService.new(token_service: @token_service, provider: provider)

    response = service.call(raw_token: @raw_token, question: "Tell me about First and Second", session_id: "repair-fail-session", request_id: "repair-fail-request")

    assert_equal "insufficient_information", response["status"]
    assert_equal 1, provider.repair_calls
  end

  test "uses a distinct primary evidence story for an another-example follow-up" do
    first = KnowledgeEntry.create!(title: "First story", body: "First", entry_type: "project", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "first", source_fingerprint: "first")
    second = KnowledgeEntry.create!(title: "Second story", body: "Second", entry_type: "project", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "second", source_fingerprint: "second")
    third = KnowledgeEntry.create!(title: "Third story", body: "Third", entry_type: "project", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "third", source_fingerprint: "third")
    retriever = Class.new do
      def initialize(entries) = @entries = entries
      def call(*) = @entries
    end.new([ first, second, third ])
    provider = Class.new do
      attr_reader :contexts
      def initialize = @contexts = []
      def call(question:, context:)
        @contexts << context
        { "status" => "answer", "answer" => "Grounded.", "evidence_ids" => [ context.first.id.to_s ], "source_urls" => [] }
      end
    end.new
    service = AskJared::QuestionService.new(token_service: @token_service, retriever: retriever, provider: provider)

    service.call(raw_token: @raw_token, question: "What demonstrates judgment?", session_id: "novel-session", request_id: "novel-1")
    service.call(raw_token: @raw_token, question: "Tell me about another example.", session_id: "novel-session", request_id: "novel-2")

    assert_equal [ first.id, second.id, third.id ], provider.contexts.first.map(&:id)
    assert_equal [ second.id, third.id ], provider.contexts.last.map(&:id)
  end

  test "does not choose a novel weak story over a qualified intent alternative" do
    metadata = ->(utility, strength) do
      { "recruiter_evidence" => {
        "recruiter_utility" => utility,
        "capability_map" => { "product judgment" => { "strength" => strength } }
      } }
    end
    first = KnowledgeEntry.create!(title: "First product story", body: "First product", metadata: metadata.call("primary_recruiter_evidence", "demonstrated"), entry_type: "product_story", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "qualified-first", source_fingerprint: "qualified-first")
    weak = KnowledgeEntry.create!(title: "Weak operations story", body: "Operations", metadata: metadata.call("secondary_recruiter_evidence", "supporting"), entry_type: "project", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "weak-product", source_fingerprint: "weak-product")
    strong = KnowledgeEntry.create!(title: "Strong alternate product story", body: "Alternate product", metadata: metadata.call("primary_recruiter_evidence", "demonstrated"), entry_type: "product_story", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "qualified-second", source_fingerprint: "qualified-second")
    retriever = Class.new do
      def initialize(entries) = @entries = entries
      def call(question, **)
        question.match?(/another/i) ? [ @entries.last ] : @entries
      end
      def classified_intent(question) = "product"
      def qualified_for_intent?(intent, entry)
        entry.metadata.dig("recruiter_evidence", "recruiter_utility") == "primary_recruiter_evidence"
      end
    end.new([ first, weak, strong ])
    provider = Class.new do
      attr_reader :contexts
      def initialize = @contexts = []
      def call(**args)
        @contexts << args.fetch(:context)
        { "status" => "answer", "answer" => "Grounded.", "evidence_ids" => [ args.fetch(:context).first.id.to_s ], "source_urls" => [] }
      end
    end.new
    service = AskJared::QuestionService.new(token_service: @token_service, retriever: retriever, provider: provider)

    service.call(raw_token: @raw_token, question: "What demonstrates product judgment?", session_id: "qualified-session", request_id: "qualified-1")
    service.call(raw_token: @raw_token, question: "Tell me about another example.", session_id: "qualified-session", request_id: "qualified-2")

    assert_equal [ strong.id ], provider.contexts.last.map(&:id)
    refute_includes provider.contexts.last.map(&:id), weak.id
  end

  test "passes the inherited intent into retrieval before qualifying another-example candidates" do
    first = KnowledgeEntry.create!(title: "Agenda product story", body: "Agenda", metadata: { "recruiter_evidence" => { "recruiter_utility" => "primary_recruiter_evidence", "capability_map" => { "product judgment" => { "strength" => "strong", "evidence_kind" => "demonstrated" } } } }, entry_type: "product_story", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "context-first", source_fingerprint: "context-first")
    weak = KnowledgeEntry.create!(title: "Operational example", body: "Operations", metadata: { "recruiter_evidence" => { "recruiter_utility" => "secondary_recruiter_evidence", "capability_map" => {} } }, entry_type: "project", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "context-weak", source_fingerprint: "context-weak")
    strong = KnowledgeEntry.create!(title: "Prioritization product story", body: "Prioritization", metadata: { "recruiter_evidence" => { "recruiter_utility" => "primary_recruiter_evidence", "capability_map" => { "product judgment" => { "strength" => "strong", "evidence_kind" => "demonstrated" } } } }, entry_type: "product_story", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "context-strong", source_fingerprint: "context-strong")
    retriever = Class.new do
      attr_reader :calls

      def initialize(first, weak, strong)
        @first = first
        @weak = weak
        @strong = strong
        @calls = []
      end

      def classified_intent(question)
        question.match?(/another/i) ? nil : "product"
      end

      def call(question, limit: 6, intent: nil)
        @calls << { question: question, intent: intent }
        question.match?(/another/i) ? [ @strong ] : [ @first ]
      end

      def qualified_for_intent?(intent, entry)
        intent == "product" && entry == @strong
      end
    end.new(first, weak, strong)
    provider = Class.new do
      attr_reader :contexts

      def initialize = @contexts = []
      def call(context:, **)
        @contexts << context
        { "status" => "answer", "answer" => "Grounded.", "evidence_ids" => [ context.first.id.to_s ], "source_urls" => [] }
      end
    end.new
    service = AskJared::QuestionService.new(token_service: @token_service, retriever: retriever, provider: provider)

    service.call(raw_token: @raw_token, question: "What demonstrates Jared's product judgment?", session_id: "context-session", request_id: "context-1")
    service.call(raw_token: @raw_token, question: "Tell me about another example.", session_id: "context-session", request_id: "context-2")

    assert_equal "product", retriever.calls.last[:intent]
    assert_equal [ strong.id ], provider.contexts.last.map(&:id)
    refute_includes provider.contexts.last.map(&:id), weak.id
  end

  test "pins tell-me-more to the active primary evidence story" do
    first = KnowledgeEntry.create!(title: "First story", body: "First", entry_type: "project", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "first", source_fingerprint: "first")
    second = KnowledgeEntry.create!(title: "Second story", body: "Second", entry_type: "project", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "second", source_fingerprint: "second")
    third = KnowledgeEntry.create!(title: "Third story", body: "Third", entry_type: "project", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "third", source_fingerprint: "third")
    retriever = Class.new do
      def initialize(entries) = @entries = entries
      def call(*) = @entries
    end.new([ first, second, third ])
    provider = Class.new do
      attr_reader :contexts
      def initialize = @contexts = []
      def call(question:, context:)
        @contexts << context
        { "status" => "answer", "answer" => "Grounded.", "evidence_ids" => [ context.first.id.to_s ], "source_urls" => [] }
      end
    end.new
    service = AskJared::QuestionService.new(token_service: @token_service, retriever: retriever, provider: provider)

    service.call(raw_token: @raw_token, question: "What demonstrates judgment?", session_id: "pin-session", request_id: "pin-1")
    service.call(raw_token: @raw_token, question: "Tell me about another example.", session_id: "pin-session", request_id: "pin-2")
    service.call(raw_token: @raw_token, question: "Tell me more about that.", session_id: "pin-session", request_id: "pin-3")
    service.call(raw_token: @raw_token, question: "Another example.", session_id: "pin-session", request_id: "pin-4")

    assert_equal [ second.id ], provider.contexts[-2].map(&:id)
    assert_equal [ third.id ], provider.contexts.last.map(&:id)
  end
end
