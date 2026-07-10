require "test_helper"

class MarkdownRendererTest < ActiveSupport::TestCase
  test "filters raw HTML while preserving Markdown" do
    html = MarkdownRenderer.render("**Safe** <script>alert('nope')</script>")

    assert_includes html, "<strong>Safe</strong>"
    assert_not_includes html, "<script>"
  end

  test "adds safe relationship attributes to links" do
    html = MarkdownRenderer.render("[Example](https://example.com)")

    assert_includes html, 'rel="noopener noreferrer"'
  end
end
