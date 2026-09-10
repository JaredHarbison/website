module AskJared
  module RecruiterAnswerSanitizer
    require "cgi"

    module_function

    def clean(answer)
      CGI.unescapeHTML(answer.to_s)
        .gsub(/Professional TypeScript depth is not established/i, "TypeScript is newer territory for Jared")
        .gsub(/\b(?:is|are) not established\b/i, "is newer territory")
        .gsub(/(?:Jared[’']s\s+)?technology depth varies(?: by technology)?,?\s*(?:and is best considered specifically individually rather than inferred broadly|so it should be evaluated technology by technology|and should be evaluated by technology rather than assumed to be uniform|rather than assumed to be uniform)/i, "His experience is deeper in some technologies than others, so each one is best considered on its own")
        .gsub(/Experience on large conventional engineering teams is also a gap,?\s*while adjacent collaboration and organizational-scale experience are demonstrated/i, "He has not spent much of his engineering career in a large conventional engineering organization, though he has collaboration and organizational experience from other settings")
        .gsub(/\bshould be evaluated\b/i, "is best considered specifically")
        .gsub(/\bshould evaluate\b/i, "can consider")
        .gsub(/\bshould be assessed\b/i, "is best considered")
        .gsub(/\bevidence does not establish\b/i, "the available information does not show")
        .gsub(/\bevidence shows\b/i, "the documented work shows")
        .gsub(/\bapproved evidence\b|\brecruiter evidence\b/i, "documented experience")
        .gsub(/\badjacent evidence\b/i, "related experience")
        .gsub(/\bcapability map\b/i, "skills summary")
        .gsub(/\bboundary\b/i, "limitation")
        .gsub(/\b(?:are|is) demonstrated\b/i, "are documented")
        .gsub(/\bdemonstrated\b/i, "documented")
        .gsub(/\bevidence does not (?:establish|show)\b/i, "the available information does not establish")
        .gsub(/Professional TypeScript depth is not established,?\s*though (?:a current learning trajectory is documented|he has a documented current learning trajectory)/i, "TypeScript is newer territory for Jared, and he is actively learning it")
        .gsub(/(?:Experience on large conventional engineering teams is also a gap),?\s*while adjacent collaboration and organizational-scale experience are demonstrated/i, "He has not spent much of his engineering career in a large conventional engineering organization, though he has collaboration and organizational experience from other settings")
        .gsub(/\bThis could impact [^.?!]*[.?!]/i, "")
        .gsub(/\bwhich may limit [^.?!]*[.?!]/i, "")
        .gsub(/\bwhich may not translate directly to [^.?!]*[.?!]/i, "")
        .gsub(/,\s+Additionally\b/i, ". Additionally")
        .gsub(/\.\s+Additionally,\s+/i, ". ")
        .gsub(/\(?\s*Evidence\s*\[[^\]]+\]\s*\)?/i, "")
        .gsub(/\[\s*Evidence\s*#?\s*[A-Za-z0-9_-]+\s*\]/i, "")
        .gsub(/\(?\s*Evidence\s*(?:ID\s*)?[:#]\s*[A-Za-z0-9_-]+\s*\)?/i, "")
        .gsub(/\b[A-Za-z0-9_.:-]+#claim-\d+\b/, "")
        .gsub(/\bc\d+\b/, "")
        .gsub(/^\s*\#{1,6}\s+/m, "")
        .gsub(/^\s*[-*+]\s+/m, "")
        .gsub(/\[([^\]]+)\]\((?:https?:\/\/)?[^)]+\)/, '\\1')
        .gsub(/\*\*|__|`/, "")
        .gsub(/\\([[:punct:]])/, '\\1')
        # Sol occasionally repeats a short word during realization. Remove
        # adjacent duplicates without rewriting separated emphasis.
        .gsub(/\b([[:alpha:]][[:alpha:]'-]*)\s+\1\b/i, '\\1')
        .gsub(/[ \t]{2,}/, " ")
        .gsub(/\s+([,.;:!?])/, '\\1')
        .strip
    end
  end
end
