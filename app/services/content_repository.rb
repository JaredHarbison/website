class ContentRepository
  EntryNotFound = Class.new(StandardError)

  FRONT_MATTER_PATTERN = /\A---\s*\n(?<front_matter>.*?)\n---\s*\n(?<body>.*)\z/m

  def initialize(collection:, model:)
    @collection = collection
    @model = model
  end

  def all
    entries = paths.map { |path| build_entry(path) }.select(&:published?)

    return entries.sort_by { |entry| [ entry.order || Float::INFINITY, entry.title.downcase ] } if entries.any?(&:order)

    entries.sort_by { |entry| [ entry.date || Date.new(1970, 1, 1), entry.title ] }.reverse
  end

  def find!(slug)
    all.find { |entry| entry.slug == slug.to_s } || raise(EntryNotFound, slug)
  end

  private

  attr_reader :collection, :model

  def paths
    Rails.root.join("content", collection).glob("*.md")
  end

  def build_entry(path)
    metadata, body = parse(path.read)

    model.new(
      body: body,
      collection: collection,
      metadata: metadata,
      slug: path.basename(".md").to_s
    )
  end

  def parse(markdown)
    match = markdown.match(FRONT_MATTER_PATTERN)
    return [ {}, markdown ] unless match

    metadata = YAML.safe_load(
      match[:front_matter],
      permitted_classes: [ Date, Time ],
      aliases: false
    ) || {}

    [ metadata.transform_keys(&:to_s), match[:body] ]
  end
end
