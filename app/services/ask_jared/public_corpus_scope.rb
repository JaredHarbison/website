require "yaml"

module AskJared
  class PublicCorpusScope
    PATH = Rails.root.join("config/ask_jared_public_corpus_scope.yml")
    DEFAULT = { "employer" => "unknown", "project_scope" => "unknown", "scope_confidence" => "unknown" }.freeze

    def initialize(path: PATH)
      @data = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
      raise ArgumentError, "Ask Jared public-corpus scope registry is invalid" unless @data.is_a?(Hash) && @data["version"].is_a?(Integer) && @data["sources"].is_a?(Hash)
    end

    def for(source_id)
      DEFAULT.merge(@data.fetch("sources").fetch(source_id.to_s, {}))
    end
  end
end
