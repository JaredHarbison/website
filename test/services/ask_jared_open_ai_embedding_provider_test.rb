require "test_helper"
require "net/http"

class AskJaredOpenAiEmbeddingProviderTest < ActiveSupport::TestCase
  FakeHttp = Struct.new(:response) do
    def post(*)
      response
    end
  end

  test "parses a 1536-dimension embedding" do
    body = { data: [ { embedding: Array.new(1536, 0.1) } ] }.to_json
    response = Net::HTTPSuccess.allocate
    response.define_singleton_method(:body) { body }
    provider = AskJared::OpenAiEmbeddingProvider.new(api_key: "test-key", http: FakeHttp.new(response))

    result = provider.call("Project evidence")

    assert_equal 1536, result.length
    assert_equal 0.1, result.first
  end

  test "fails closed for an invalid vector" do
    body = { data: [ { embedding: [ 0.1 ] } ] }.to_json
    response = Net::HTTPSuccess.allocate
    response.define_singleton_method(:body) { body }
    provider = AskJared::OpenAiEmbeddingProvider.new(api_key: "test-key", http: FakeHttp.new(response))

    assert_raises(AskJared::OpenAiEmbeddingProvider::ProviderError) { provider.call("Project evidence") }
  end
end
