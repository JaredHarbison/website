require "test_helper"
require_relative "../../app/services/ask_jared/open_ai_provider"

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
    assert_equal %w[status answer evidence_ids source_urls], schema.fetch("required")
    assert_equal false, schema.fetch("additionalProperties")
    assert_includes http.request_body.fetch("messages").first.fetch("content"), "status=insufficient_information"
  end
end
