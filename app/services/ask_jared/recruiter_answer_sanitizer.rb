module AskJared
  module RecruiterAnswerSanitizer
    require "cgi"

    module_function

    def clean(answer)
      CGI.unescapeHTML(answer.to_s)
        .gsub(/\(?\s*Evidence\s*\[[^\]]+\]\s*\)?/i, "")
        .gsub(/\[\s*Evidence\s*#?\s*[A-Za-z0-9_-]+\s*\]/i, "")
        .gsub(/\(?\s*Evidence\s*(?:ID\s*)?[:#]\s*[A-Za-z0-9_-]+\s*\)?/i, "")
        .gsub(/^\s*\#{1,6}\s+/m, "")
        .gsub(/^\s*[-*+]\s+/m, "")
        .gsub(/\[([^\]]+)\]\((?:https?:\/\/)?[^)]+\)/, '\\1')
        .gsub(/\*\*|__|`/, "")
        .gsub(/\\([[:punct:]])/, '\\1')
        .gsub(/[ \t]{2,}/, " ")
        .gsub(/\s+([,.;:!?])/, '\\1')
        .strip
    end
  end
end
