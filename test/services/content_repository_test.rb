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

  test "uses an optional shorter navigation title" do
    entry = ContentEntry.new(
      metadata: { "title" => "A Very Long Editorial Title", "navigation_title" => "Short Title" },
      slug: "long-title"
    )

    assert_equal "Short Title", entry.navigation_title
  end

  test "falls back to the full title in navigation" do
    entry = ContentEntry.new(metadata: { "title" => "Editorial Title" }, slug: "title")

    assert_equal "Editorial Title", entry.navigation_title
  end
end
