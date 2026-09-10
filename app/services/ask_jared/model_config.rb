module AskJared
  module ModelConfig
    CANONICAL_MODEL = ENV.fetch("ASK_JARED_MODEL", "gpt-5.6-sol").freeze
  end
end
