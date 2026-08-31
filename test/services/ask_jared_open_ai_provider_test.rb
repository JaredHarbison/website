require "test_helper"
require_relative "../../app/services/ask_jared/open_ai_provider"

class AskJaredOpenAiProviderTest < ActiveSupport::TestCase
  FakeHttp = Struct.new(:response) do
    def post(*)
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
end
