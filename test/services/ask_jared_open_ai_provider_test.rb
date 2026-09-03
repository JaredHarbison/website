require "test_helper"
require_relative "../../app/services/ask_jared/open_ai_provider"
require_relative "../../app/services/ask_jared/synthesis_evidence_packet"

class AskJaredOpenAiProviderTest < ActiveSupport::TestCase
  FakeHttp = Struct.new(:response) do
    def post(*)
      response
    end
  end

  CapturingHttp = Struct.new(:response, :request_body) do
    def post(_endpoint, body, _headers)
      self.request_body = JSON.parse(body)
      response
    end
  end

  def entry(id)
    KnowledgeEntry.new(id: id, title: "Project", body: "Approved evidence", short_body: nil)
  end

  def packet
    entries = [ 50, 51 ].map do |id|
      KnowledgeEntry.new(
        id: id, title: "Project #{id}", body: "Fallback body", short_body: nil,
        source_reference: "story:#{id}", entry_type: "project",
        metadata: { "recruiter_evidence" => { "claims" => [ { "text" => "Claim for #{id}.", "kind" => "demonstrated", "provenance" => "story:#{id}" } ] } }
      )
    end
    AskJared::SynthesisEvidencePacket.new(entries: entries, intent: "test")
  end

  test "bounded packet context preserves packet semantics and aliases" do
    bounded = packet.bounded(1)

    assert_instance_of AskJared::SynthesisEvidencePacket, bounded
    assert_equal [ 50 ], bounded.entries.map(&:id)
    assert_equal [ "c1" ], bounded.claim_aliases.keys
    assert_equal "story:50#claim-0", bounded.resolve_claim_aliases!([ "c1" ]).first
  end

  test "provider formatting receives aliases without raw entry IDs" do
    body = { choices: [ { message: { content: { status: "answer", answer: "Grounded.", evidence_ids: [], source_urls: [], claim_refs: [ "c1" ] }.to_json } } ] }.to_json
    http = CapturingHttp.new(Net::HTTPSuccess.allocate.tap { |response| response.define_singleton_method(:body) { body } })

    AskJared::OpenAiProvider.new(api_key: "test-key", http: http).call(question: "Question", context: packet)

    evidence_context = http.request_body.fetch("messages").last.fetch("content")
    assert_includes evidence_context, "c1: Claim for 50."
    assert_includes evidence_context, "c2: Claim for 51."
    refute_includes evidence_context, "[50]"
    refute_includes evidence_context, "[51]"
    refute_includes evidence_context, "entry_id"
  end

  test "sends bounded approved context and parses structured JSON" do
    body = { choices: [ { message: { content: { status: "answer", answer: "Grounded.", evidence_ids: [ "1" ], source_urls: [] }.to_json } } ] }.to_json
    provider = AskJared::OpenAiProvider.new(api_key: "test-key", http: FakeHttp.new(Net::HTTPSuccess.allocate.tap { |response| response.define_singleton_method(:body) { body } }))

    result = provider.call(question: "What did Jared build?", context: [ entry(1) ])

    assert_equal "answer", result["status"]
  end

  test "fails closed when no API key is configured" do
    provider = AskJared::OpenAiProvider.new(api_key: nil)

    assert_raises(AskJared::OpenAiProvider::ConfigurationError) { provider.call(question: "Question", context: [ entry(1) ]) }
  end

  test "requests the exact strict response schema and status semantics" do
    body = { choices: [ { message: { content: { status: "insufficient_information", answer: "Not enough evidence.", evidence_ids: [], source_urls: [] }.to_json } } ] }.to_json
    http = CapturingHttp.new(Net::HTTPSuccess.allocate.tap { |response| response.define_singleton_method(:body) { body } })

    AskJared::OpenAiProvider.new(api_key: "test-key", http: http).call(question: "Question", context: [ entry(1) ])

    schema = http.request_body.fetch("response_format").fetch("json_schema").fetch("schema")
    assert_equal AskJared::StructuredResponse::STATUSES, schema.fetch("properties").fetch("status").fetch("enum")
    assert_equal %w[status answer evidence_ids source_urls claim_refs], schema.fetch("required")
    assert_equal false, schema.fetch("additionalProperties")
    assert_includes http.request_body.fetch("messages").first.fetch("content"), "status=insufficient_information"
  end

  test "includes general grounding boundaries without question-specific rules" do
    body = { choices: [ { message: { content: { status: "answer", answer: "Grounded.", evidence_ids: [], source_urls: [] }.to_json } } ] }.to_json
    http = CapturingHttp.new(Net::HTTPSuccess.allocate.tap { |response| response.define_singleton_method(:body) { body } })

    AskJared::OpenAiProvider.new(api_key: "test-key", http: http).call(question: "Question", context: [ entry(1) ])

    instruction = http.request_body.fetch("messages").first.fetch("content")
    assert_includes instruction, "Never merge independent evidence into a causal, chronological, or unified claim"
    assert_includes instruction, "Never put internal evidence IDs in answer prose"
    assert_includes instruction, "Recommend role families only when the supplied evidence demonstrates the relevant work"
    assert_includes instruction, "missing experience is not evidence of inability"
    assert_includes instruction, "one excellent distinct example"
    assert_includes instruction, "Planned measurements remain planned"
    assert_includes instruction, "Every factual proposition in the answer must be supported"
    refute_includes instruction, "Shopify"
  end

  test "repair request keeps the original packet and reports the violation" do
    body = { choices: [ { message: { content: { status: "answer", answer: "Separate facts.", evidence_ids: [ "1" ], source_urls: [] }.to_json } } ] }.to_json
    http = CapturingHttp.new(Net::HTTPSuccess.allocate.tap { |response| response.define_singleton_method(:body) { body } })

    AskJared::OpenAiProvider.new(api_key: "test-key", http: http).repair(
      question: "What happened?", context: [ entry(1) ],
      response: { "status" => "answer", "answer" => "Unsupported.", "evidence_ids" => [ "1" ], "source_urls" => [] },
      violations: [ "causal language requires an approved causal relationship" ]
    )

    content = http.request_body.fetch("messages").last.fetch("content")
    assert_includes content, "Rewrite only enough to remove the unsupported relationship"
    assert_includes content, "Unsupported."
  end

  test "repair preserves bounded packet semantics and alias-formatted context" do
    body = { choices: [ { message: { content: { status: "answer", answer: "Separate facts.", evidence_ids: [], source_urls: [], claim_refs: [ "c1" ] }.to_json } } ] }.to_json
    http = CapturingHttp.new(Net::HTTPSuccess.allocate.tap { |response| response.define_singleton_method(:body) { body } })

    AskJared::OpenAiProvider.new(api_key: "test-key", http: http).repair(
      question: "What happened?", context: packet,
      response: { "status" => "answer", "answer" => "Unsupported.", "evidence_ids" => [], "source_urls" => [], "claim_refs" => [ "c1" ] },
      violations: [ "causal language requires an approved causal relationship" ]
    )

    evidence_context = http.request_body.fetch("messages").last.fetch("content")
    assert_includes evidence_context, "c1: Claim for 50."
    assert_includes evidence_context, "c2: Claim for 51."
    refute_includes evidence_context, "[50]"
    refute_includes evidence_context, "[51]"
  end
end
