require "test_helper"

class AskJaredPublicCorpusScopeTest < ActiveSupport::TestCase
  Document = AskJared::PublicCorpus::Document

  test "keeps Dogly sources out of an outside-Dogly retrieval" do
    dogly = Document.new("case_studies:dogly", "Dogly", "/dogly", "case_studies", "Dogly integration", "", { "scope" => { "employer" => "Dogly" } })
    personal = Document.new("case_studies:personal", "Personal", "/personal", "case_studies", "Personal integration", "", { "scope" => { "employer" => "personal" } })
    retriever = AskJared::PublicCorpusRetriever.new(corpus: Struct.new(:documents).new([ dogly, personal ]))

    assert_equal [ "case_studies:personal" ], retriever.call("Tell me about integrations outside Dogly", scope: "non_dogly").map(&:id)
    assert_equal [ "case_studies:dogly" ], retriever.last_trace.fetch(:excluded).map { |item| item.fetch(:id) }
  end

  test "records Jared-confirmed personal scope for both personal projects" do
    scope = AskJared::PublicCorpusScope.new

    %w[case_studies:federation-briefing case_studies:karaoke-queue].each do |source_id|
      assert_equal "personal", scope.for(source_id).fetch("employer")
      assert_equal "confirmed", scope.for(source_id).fetch("scope_confidence")
    end
  end
end
