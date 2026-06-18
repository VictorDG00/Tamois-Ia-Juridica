module ApplicationHelper
  MARKDOWN_ALLOWED_TAGS = %w[
    p br strong em h1 h2 h3 h4 h5 h6 ul ol li code pre blockquote
    table thead tbody tr th td s del hr a span
  ].freeze
  MARKDOWN_ALLOWED_ATTRS = { "a" => %w[href title], "code" => %w[class] }.freeze

  def markdown(text)
    return "".html_safe if text.blank?
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true, safe_links_only: true)
    md = Redcarpet::Markdown.new(
      renderer,
      autolink: true, tables: true, fenced_code_blocks: true,
      strikethrough: true, no_intra_emphasis: true
    )
    sanitize(md.render(text), tags: MARKDOWN_ALLOWED_TAGS, attributes: MARKDOWN_ALLOWED_ATTRS)
  end
end
