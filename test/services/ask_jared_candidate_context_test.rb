require "test_helper"
require "tempfile"

class AskJaredCandidateContextTest < ActiveSupport::TestCase
  FakeRetriever = Struct.new(:entries) do
    def classified_intent(_question) = "characterization"
    def call(_question, **_options) = entries
  end

  class PlanningProvider
    attr_reader :plans

    def initialize(entry)
      @entry = entry
      @plans = []
    end

    def call(question:, context:, plan:)
      @plans << plan
      { "status" => "answer", "answer" => "A supported answer.", "evidence_ids" => [ @entry.id.to_s ], "source_urls" => [] }
    end
  end

  setup do
    EngagementEvent.delete_all
    KnowledgeEntry.delete_all
    AskToken.delete_all
    Opportunity.delete_all
    @token_service = AskJared::TokenService.new(secret: Rails.application.secret_key_base)
    _token, @raw_token = @token_service.mint!
    @token_service.claim!(raw_token: @raw_token, external_id: "candidate-context-test", company: "Acme", role_title: "Engineer")
  end

  test "candidate context is planning data and cannot satisfy evidence validation" do
    packet = AskJared::SynthesisEvidencePacket.new(entries: [], intent: "characterization", question: "What kind of engineer is Jared?")

    assert_raises(AskJared::EvidenceIntegrity::Violation) do
      AskJared::EvidenceIntegrity.validate_response!(answer: "Jared is a product engineer.", evidence_ids: [], claim_refs: [ "private-context" ], packet: packet)
    end
  end

  test "missing approved evidence remains insufficient with candidate context enabled" do
    planner = AskJared::CandidateContextPlanner.new
    service = AskJared::QuestionService.new(token_service: @token_service, retriever: FakeRetriever.new([]), planner: planner)

    response = service.call(raw_token: @raw_token, architecture: "candidate-context-v1", question: "What kind of engineer is Jared?", session_id: "missing-context", request_id: "missing-context-request")

    assert_equal "insufficient_information", response["status"]
    refute response.to_json.include?("positioning.engineering_identity")
  end

  test "candidate context changes planning while final response exposes only approved evidence" do
    entry = KnowledgeEntry.create!(title: "Approved", body: "A supported answer.", entry_type: "fact", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "approved-context-test", source_fingerprint: "approved-context-test")
    provider = PlanningProvider.new(entry)
    service = AskJared::QuestionService.new(token_service: @token_service, retriever: FakeRetriever.new([ entry ]), provider: provider)

    response = service.call(raw_token: nil, architecture: "candidate-context-v1", admin_preview: true, question: "What kind of engineer is Jared?", session_id: "candidate-context", request_id: "candidate-context-request")

    assert_equal "answer", response["status"]
    assert_equal [ entry.id.to_s ], response["evidence_ids"]
    refute response.keys.any? { |key| key.to_s.match?(/context|plan|private/i) }
    assert_equal AskJared::CandidateContext::VERSION, provider.plans.first.version
  end

  test "records the architecture on recruiter answer events only when server-side experiment mode is enabled" do
    entry = KnowledgeEntry.create!(title: "Approved", body: "A supported answer.", entry_type: "fact", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "telemetry-context-test", source_fingerprint: "telemetry-context-test")
    provider = PlanningProvider.new(entry)
    service = AskJared::QuestionService.new(token_service: @token_service, retriever: FakeRetriever.new([ entry ]), provider: provider)
    previous = ENV["ASK_JARED_CANDIDATE_CONTEXT"]
    ENV["ASK_JARED_CANDIDATE_CONTEXT"] = "1"

    service.call(raw_token: @raw_token, architecture: "candidate-context-v1", question: "What kind of engineer is Jared?", session_id: "telemetry-context", request_id: "telemetry-context-request")

    event = EngagementEvent.find_by!(event_type: "answer_returned")
    assert_equal AskJared::CandidateContext::VERSION, event.metadata["architecture"]
    assert_equal AskJared::CandidateContext::VERSION, event.metadata["planner_version"]
    refute event.metadata.to_json.include?("Canonical professional characterization")
  ensure
    previous ? ENV["ASK_JARED_CANDIDATE_CONTEXT"] = previous : ENV.delete("ASK_JARED_CANDIDATE_CONTEXT")
  end

  test "previous evidence IDs enter the plan as referents without treating answer prose as context" do
    plan = AskJared::CandidateContextPlanner.new.call(question: "Tell me more about the first example.", intent: "product", prior_evidence_ids: [ "approved-entry-1" ])

    assert_equal [ "approved-entry-1" ], plan.referent_ids
    refute plan.to_h.values.any? { |value| value.to_s.include?("previous answer") }
  end

  test "planner failure falls back to the baseline provider contract" do
    entry = KnowledgeEntry.create!(title: "Approved", body: "A supported answer.", entry_type: "fact", approval_status: "approved", visibility: "recruiter_visible", source_type: "test", source_reference: "planner-fallback-test", source_fingerprint: "planner-fallback-test")
    planner = Object.new
    planner.define_singleton_method(:call) { |**| raise "planner unavailable" }
    provider = Class.new do
      attr_reader :received
      def call(question:, context:)
        @received = [ question, context ]
        { "status" => "answer", "answer" => "A supported answer.", "evidence_ids" => [ context.first.id.to_s ], "source_urls" => [] }
      end
    end.new
    service = AskJared::QuestionService.new(token_service: @token_service, retriever: FakeRetriever.new([ entry ]), provider: provider, planner: planner)

    response = service.call(raw_token: @raw_token, architecture: "candidate-context-v1", question: "What kind of engineer is Jared?", session_id: "planner-fallback", request_id: "planner-fallback-request")

    assert_equal "answer", response["status"]
    assert_equal entry.id.to_s, response["evidence_ids"].first
  end

  test "candidate context loader ignores draft and retired records" do
    file = Tempfile.new([ "candidate-context", ".yml" ])
    file.write(<<~YAML)
      version: candidate-context-v2
      records:
        - key: approved.context
          category: positioning
          approval_status: approved
          privacy_classification: private
          purpose: approved
          source_references: []
          affects: [interpretation]
          guidance: approved guidance
        - key: draft.context
          category: positioning
          approval_status: draft
          privacy_classification: private
          purpose: draft
          source_references: []
          affects: [interpretation]
          guidance: draft guidance
        - key: retired.context
          category: positioning
          approval_status: retired
          privacy_classification: private
          purpose: retired
          source_references: []
          affects: [interpretation]
          guidance: retired guidance
      YAML
    file.close

    records = AskJared::CandidateContext.new(path: file.path).records

    assert_equal [ "approved.context" ], records.map { |record| record["key"] }
  ensure
    file&.unlink
  end
end
