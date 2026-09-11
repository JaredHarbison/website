require "test_helper"

class AskJaredPublicCorpusTest < ActiveSupport::TestCase
  Entry = Struct.new(:slug, :title, :body, :summary, :metadata, keyword_init: true)

  test "discovers every published article in the approved collections dynamically" do
    case_study = Entry.new(slug: "new-case-study", title: "New case study", body: "Case body", summary: "Case summary", metadata: { "title" => "New case study", "summary" => "Case summary", "status" => "published", "tags" => [ "Rails" ], "role" => "Engineer", "technologies" => [ "Rails" ] })
    first_article = Entry.new(slug: "first-article", title: "First article", body: "First body", summary: "First summary", metadata: { "title" => "First article", "summary" => "First summary", "status" => "published", "tags" => [ "Rails" ], "category" => "Architecture" })
    new_article = Entry.new(slug: "new-article", title: "New article", body: "New body", summary: "New summary", metadata: { "title" => "New article", "summary" => "New summary", "status" => "published", "tags" => [ "Rails" ], "category" => "Architecture" })
    about = Entry.new(slug: "about", title: "About", body: "About body", summary: "About summary", metadata: { "title" => "About", "summary" => "About summary", "status" => "published", "tags" => [ "Rails" ] })
    contact = Entry.new(slug: "contact", title: "Contact", body: "Contact body", summary: "Contact summary", metadata: {})
    corpus = AskJared::PublicCorpus.new(repositories: {
      "case_studies" => [ case_study ], "writing" => [ first_article, new_article ], "pages" => [ about, contact ]
    })

    assert_equal %w[case_studies:new-case-study writing:first-article writing:new-article pages:about], corpus.documents.map(&:id)
    assert_equal "/writing/new-article", corpus.find("writing:new-article").url
    refute corpus.find("pages:contact")
  end

  test "uses the live published repositories and excludes non-source pages" do
    corpus = AskJared::PublicCorpus.new

    assert_includes corpus.documents.map(&:id), "pages:about"
    refute_includes corpus.documents.map(&:id), "pages:contact"
    assert corpus.documents.any? { |document| document.collection == "case_studies" }
    assert corpus.documents.any? { |document| document.collection == "writing" }
    assert_empty corpus.metadata_errors
  end

  test "keeps nested source paths in the stable corpus ID" do
    nested = Entry.new(slug: "rails/webhooks", title: "Webhooks", body: "Body", summary: "Summary", metadata: { "title" => "Webhooks", "summary" => "Summary", "status" => "published", "tags" => [ "Rails" ], "category" => "Architecture" })
    about = Entry.new(slug: "about", title: "About", body: "About", summary: "About", metadata: { "title" => "About", "summary" => "About", "status" => "published", "tags" => [ "Rails" ] })
    corpus = AskJared::PublicCorpus.new(repositories: { "case_studies" => [], "writing" => [ nested ], "pages" => [ about ] })

    assert_equal "writing:rails/webhooks", corpus.find("writing:rails/webhooks").id
    assert_equal "/writing/rails/webhooks", corpus.find("writing:rails/webhooks").url
  end

  test "rejects a published source that is missing retrieval metadata" do
    incomplete = Entry.new(slug: "new-article", title: "New article", body: "Body", summary: "Summary", metadata: { "title" => "New article", "summary" => "Summary", "status" => "published", "tags" => [ "Rails" ] })
    about = Entry.new(slug: "about", title: "About", body: "About", summary: "About", metadata: { "title" => "About", "summary" => "About", "status" => "published", "tags" => [ "Rails" ] })
    corpus = AskJared::PublicCorpus.new(repositories: { "case_studies" => [], "writing" => [ incomplete ], "pages" => [ about ] })

    error = assert_raises(ArgumentError) { corpus.documents }
    assert_match(/writing:new-article is missing category/, error.message)
  end
end
