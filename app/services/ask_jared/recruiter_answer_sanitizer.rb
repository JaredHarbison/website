module AskJared
  module RecruiterAnswerSanitizer
    module_function

    def clean(answer)
      answer.to_s
        .gsub(/\(?\s*Evidence\s*\[[^\]]+\]\s*\)?/i, "")
        .gsub(/\[\s*Evidence\s*#?\s*[A-Za-z0-9_-]+\s*\]/i, "")
        .gsub(/\*\*|__|`/, "")
        .gsub(/[ \t]{2,}/, " ")
        .gsub(/\s+([,.;:!?])/, '\\1')
        .strip
    end
  end
end
