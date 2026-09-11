require "yaml"

module AskJared
  class PublicCorpusRules
    PATH = Rails.root.join("config/ask_jared_public_corpus_rules.yml")
    RULE_ID = /\A[a-z][a-z0-9_]*\z/

    attr_reader :version, :rules

    def self.default
      @default ||= new
    end

    def self.version = default.version
    def self.instructions = default.instructions
    def self.data = default.data

    def initialize(path: PATH)
      @data = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
      validate!
      @version = @data.fetch("version")
      @rules = @data.fetch("rules").map(&:freeze).freeze
    end

    def instructions
      rules.map { |rule| rule.fetch("instruction") }
    end

    def data
      @data
    end

    private

    def validate!
      raise ArgumentError, "Ask Jared public-corpus Rules must be a mapping" unless @data.is_a?(Hash)
      raise ArgumentError, "Ask Jared public-corpus Rules version must be a positive integer" unless @data["version"].is_a?(Integer) && @data["version"].positive?
      raise ArgumentError, "Ask Jared public-corpus Rules must contain a non-empty rules list" unless @data["rules"].is_a?(Array) && @data["rules"].any?

      ids = @data["rules"].map do |rule|
        raise ArgumentError, "Ask Jared public-corpus Rule must be a mapping" unless rule.is_a?(Hash)

        id = rule["id"]
        instruction = rule["instruction"]
        raise ArgumentError, "Ask Jared public-corpus Rule has an invalid id" unless id.is_a?(String) && RULE_ID.match?(id)
        raise ArgumentError, "Ask Jared public-corpus Rule #{id} needs a concise instruction" unless instruction.is_a?(String) && instruction.strip.present? && instruction.length <= 280

        id
      end
      raise ArgumentError, "Ask Jared public-corpus Rules contain duplicate ids" unless ids.uniq.length == ids.length
    end
  end
end
