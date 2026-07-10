class MarkdownRenderer
  RENDERER_OPTIONS = {
    filter_html: true,
    hard_wrap: false,
    link_attributes: { rel: "noopener noreferrer" }
  }.freeze

  MARKDOWN_OPTIONS = {
    autolink: true,
    fenced_code_blocks: true,
    footnotes: true,
    no_intra_emphasis: true,
    space_after_headers: true,
    strikethrough: true,
    tables: true
  }.freeze

  def self.render(markdown)
    new.render(markdown)
  end

  def initialize
    @renderer = Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(RENDERER_OPTIONS),
      MARKDOWN_OPTIONS
    )
  end

  def render(markdown)
    @renderer.render(markdown.to_s).html_safe
  end
end
