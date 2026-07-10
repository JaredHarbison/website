require "test_helper"

class ContentRepositoryTest < ActiveSupport::TestCase
  test "loads published markdown entries from a collection" do
    entries = ContentRepository.new(collection: "pages", model: ContentEntry).all

    assert_equal [ "contact", "about" ], entries.map(&:slug)
    assert entries.all?(&:published?)
  end

  test "raises when an entry cannot be found" do
    repository = ContentRepository.new(collection: "pages", model: ContentEntry)

    assert_raises(ContentRepository::EntryNotFound) do
      repository.find!("missing")
    end
  end
end
