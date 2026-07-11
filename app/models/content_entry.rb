class ContentEntry
  include ActiveModel::Model

  attr_accessor :body, :collection, :metadata, :slug

  def title
    metadata.fetch("title", slug.to_s.titleize)
  end

  def navigation_title
    metadata.fetch("navigation_title", title)
  end

  def summary
    metadata["summary"].to_s
  end

  def date
    value = metadata["date"]
    return value if value.is_a?(Date)

    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def status
    metadata.fetch("status", "draft")
  end

  def published?
    status == "published"
  end

  def [](key)
    metadata[key.to_s]
  end
end
