require "test_helper"

class TagCatalogTest < ActiveSupport::TestCase
  test "groups case studies and writing under shared tags" do
    rails = TagCatalog.new.find!("rails")

    assert_equal "Rails", rails.name
    assert_predicate rails.case_studies, :any?
    assert_predicate rails.articles, :any?
    assert_equal rails.case_studies.size + rails.articles.size, rails.count
  end

  test "raises for an unknown tag" do
    assert_raises(ContentRepository::EntryNotFound) do
      TagCatalog.new.find!("missing")
    end
  end
end
