require "test_helper"
require_relative "../../app/services/ask_jared/structured_response"

class AskJaredStructuredResponseTest < ActiveSupport::TestCase
  BASE = {
    "status" => "answer",
    "answer" => "Jared builds product-oriented Rails systems.",
    "evidence_ids" => [ "entry-1" ],
    "source_urls" => [ "https://www.jaredharbison.com/case-studies/karaoke-queue" ]
  }.freeze

  test "accepts the allowed response contract" do
    assert_equal BASE, AskJared::StructuredResponse.validate!(BASE)
  end

  test "rejects unsupported statuses" do
    error = assert_raises(ArgumentError) { AskJared::StructuredResponse.validate!(BASE.merge("status" => "unrestricted")) }

    assert_equal "unsupported response status", error.message
  end

  test "rejects unbounded or malformed model output" do
    assert_raises(ArgumentError) { AskJared::StructuredResponse.validate!(BASE.merge("answer" => "x" * 4_001)) }
    assert_raises(ArgumentError) { AskJared::StructuredResponse.validate!(BASE.merge("evidence_ids" => "entry-1")) }
    assert_raises(ArgumentError) { AskJared::StructuredResponse.validate!(BASE.merge("source_urls" => [ nil ])) }
    assert_raises(ArgumentError) { AskJared::StructuredResponse.validate!(BASE.merge("source_urls" => [ "http://example.test" ])) }
  end
end
