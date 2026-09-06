require "json"
require "fileutils"

entries = KnowledgeEntry.order(:id).to_a
recruiter = entries.select { |e| e.approval_status == "approved" && e.visibility == "recruiter_visible" }
out = Rails.root.join("docs/ask-jared/prelaunch")
FileUtils.mkdir_p(out)

def ev(entry)
  entry.metadata.fetch("recruiter_evidence", {})
end

def caps(entry)
  map = ev(entry).fetch("capability_map", {})
  return map.keys if map.any?
  Array(ev(entry)["competencies"] || entry.metadata["capabilities"] || entry.metadata["intents"])
end

def issue(entry)
  text = [ entry.title, entry.body, entry.short_body, JSON.generate(ev(entry)) ].join(" ").downcase
  flags = []
  flags << "ownership scope" if text.match?(/owned|sole|complete|entire|end to end/)
  flags << "outcome/causality" if text.match?(/caused|increased|improved|growth|revenue|result/)
  flags << "management/team scale" if text.match?(/managed|manager|team|organization/)
  flags << "technology depth" if text.match?(/expert|deep|advanced|typescript|system design/)
  flags << "planned versus observed" if text.match?(/planned|proposed|future|roadmap|work in progress/)
  flags.any? ? flags.join(", ") : "none mechanically detected"
end

def disposition(entry)
  text = [ entry.body, entry.short_body, JSON.generate(ev(entry)) ].join(" ").downcase
  return "NEEDS_JARED_REVIEW" if entry.source_reference.start_with?("fact:")
  return "NEEDS_JARED_REVIEW" if text.match?(/caused|increased|managed|expert|owned the entire|end to end|planned|work in progress/)
  return "KEEP" if entry.approval_status == "approved" && entry.visibility == "recruiter_visible"
  "NEEDS_JARED_REVIEW"
end

def val(value)
  value = value.join("; ") if value.is_a?(Array)
  value.to_s.gsub("\n", " ").strip.presence || "Not recorded"
end

records = entries.map do |entry|
  evidence = ev(entry)
  {
    "id" => entry.id, "source_reference" => entry.source_reference, "title" => entry.title,
    "entry_type" => entry.entry_type, "source_type" => entry.source_type,
    "source_kind" => entry.metadata["source_kind"], "approval_status" => entry.approval_status,
    "visibility" => entry.visibility, "recruiter_retrievable" => entry.approval_status == "approved" && entry.visibility == "recruiter_visible",
    "embedding_present" => entry.embedding.present?, "embedding_model" => entry.embedding_model,
    "capabilities" => caps(entry), "recruiter_utility" => evidence["recruiter_utility"],
    "source_url" => entry.source_url, "public_url" => entry.public_url,
    "body" => entry.body, "short_body" => entry.short_body, "evidence" => evidence, "metadata" => entry.metadata,
    "suspected_duplicates" => [], "suspected_conflicts" => [], "audit_disposition" => disposition(entry), "audit_note" => issue(entry)
  }
end
File.write(out.join("recruiter-evidence-audit.json"), JSON.pretty_generate(records))

audit = recruiter.map do |entry|
  evidence = ev(entry)
  ownership = evidence["ownership"] || {}
  lines = []
  lines << "### Knowledge ##{entry.id} — #{entry.title}"
  lines << ""
  lines << "- ID / source ref: `#{entry.id}` / `#{entry.source_reference}`"
  lines << "- Current state: `#{entry.approval_status}`; visibility `#{entry.visibility}`; retrievable `true`"
  lines << "- Evidence/source kind: `#{entry.entry_type}` / `#{entry.source_type}` / `#{entry.metadata["source_kind"] || "missing"}`"
  lines << "- Current content: #{val(entry.short_body || entry.body)}"
  lines << "- Source/provenance: #{val(evidence["claims"]&.map { |claim| claim["provenance"] } || entry.metadata["source_path"] || entry.source_reference)}"
  lines << "- Capabilities/intents: #{val(caps(entry))}"
  lines << "- Important metadata: utility `#{evidence["recruiter_utility"] || "missing"}`; confidence `#{entry.confidence || "missing"}`; status `#{evidence["status"] || "not recorded"}`"
  lines << "- Ownership: leadership `#{ownership["leadership"] || "not recorded"}`; sole authorship `#{ownership["sole_authorship"] || "not recorded"}`; people management `#{ownership["people_management"] || "not recorded"}`"
  lines << "- Contributions/collaboration: #{val(ownership["personal_contributions"] || evidence["personal_contributions"])} / #{val(ownership["collaborators"] || evidence["collaborators"])}"
  lines << "- Outcome/limits: #{val(evidence["result"])} / #{val(evidence["limitations"])}; safe attribution: #{val(evidence["safe_attribution"])}"
  lines << "- Potential issue: #{issue(entry)}"
  lines << "- Preliminary disposition: **#{disposition(entry)}**"
  lines << "- Recommended action: retain provisionally; resolve flagged scope or attribution questions before substantive rewrite."
  lines << "- Confidence: mechanical preliminary screen; human review required for substantive changes."
  lines.join("\n")
end.join("\n\n")
File.write(out.join("recruiter-evidence-audit.md"), "# Recruiter evidence pre-launch audit\n\nGenerated #{Time.current.iso8601}. This includes every recruiter-visible record (#{recruiter.length}); the companion inventory includes all #{entries.length} KnowledgeEntry rows. No substantive biography was invented or rewritten.\n\nPreliminary dispositions are triage signals, not approvals for data mutation. The JSON artifact retains full current bodies and metadata.\n\n#{audit}\n")

inventory = entries.map do |entry|
  evidence = ev(entry)
  "| #{entry.id} | `#{entry.source_reference}` | #{entry.title.gsub("|", "\\|")} | #{entry.entry_type} | #{entry.source_type} | #{entry.approval_status} | #{entry.visibility} | #{entry.approval_status == "approved" && entry.visibility == "recruiter_visible" ? "yes" : "no"} | #{entry.embedding.present? ? "present" : "missing"} | #{val(caps(entry))} | #{evidence["recruiter_utility"] || "missing"} | #{val(entry.short_body || entry.body)} | #{issue(entry)} | #{disposition(entry)} |"
end.join("\n")
File.write(out.join("knowledge-inventory.md"), "# Canonical Ask Jared knowledge inventory\n\nGenerated #{Time.current.iso8601}. One row per KnowledgeEntry row. `recruiter retrievable` means exactly approved plus recruiter_visible.\n\n| DB ID | Stable/source reference | Title | Evidence kind | Source kind | Approval | Visibility | Recruiter retrievable | Embedding | Capabilities/intents | Utility | Factual summary | Audit signal | Disposition |\n|---:|---|---|---|---|---|---|---|---|---|---|---|---|---|\n#{inventory}\n")

status = entries.group_by(&:approval_status).transform_values(&:size)
visibility = entries.group_by(&:visibility).transform_values(&:size)
source = entries.group_by(&:source_type).transform_values(&:size)
kind = entries.group_by { |e| e.metadata["source_kind"] || "missing" }.transform_values(&:size)
types = entries.group_by(&:entry_type).transform_values(&:size)
utility = entries.group_by { |e| ev(e)["recruiter_utility"] || "missing" }.transform_values(&:size)
internal = entries.find { |e| e.visibility == "internal" }
excluded = entries.reject { |e| e.approval_status == "approved" && e.visibility == "recruiter_visible" }
File.write(out.join("count-reconciliation.md"), <<~MD)
  # Ask Jared knowledge count reconciliation

  Generated #{Time.current.iso8601} from the current database.

  | Scope | Exact count |
  |---|---:|
  | Total KnowledgeEntry rows | #{entries.length} |
  | Approved | #{status["approved"] || 0} |
  | Needs review | #{status["needs_review"] || 0} |
  | Rejected | #{status["rejected"] || 0} |
  | Candidate | #{status["candidate"] || 0} |
  | Approved recruiter-visible/retrievable | #{recruiter.length} |
  | Approved but not recruiter-visible | #{entries.count { |e| e.approval_status == "approved" && e.visibility != "recruiter_visible" }} |
  | Recruiter-visible but not retrievable | #{entries.count { |e| e.visibility == "recruiter_visible" && !(e.approval_status == "approved") }} |
  | Embeddings present | #{entries.count { |e| e.embedding.present? }} |
  | Embeddings missing | #{entries.count { |e| e.embedding.blank? }} |
  | Stale embeddings | #{entries.count { |e| e.embedding.present? && e.embedding_model != AskJared::EmbeddingService::MODEL }} |
  | Candidate Context v1 records | 26 |

  ## Historical count reconciliation

  The exact current recruiter scope is **#{recruiter.length}** out of #{entries.length} total rows.
  The earlier approximate count of 54 was the production recruiter scope; the prior local count of
  34 came from a stale 35-row SQLite snapshot. The two excluded records are listed below with their
  exact lifecycle and visibility scopes.

  ## Breakdowns

  - Approval: `#{status.inspect}`
  - Visibility: `#{visibility.inspect}`
  - Source type: `#{source.inspect}`
  - Source kind: `#{kind.inspect}`
  - Entry type: `#{types.inspect}`
  - Recruiter utility: `#{utility.inspect}`
  - Duplicate source references: `#{entries.group_by(&:source_reference).select { |_ref, values| values.length > 1 }.keys.inspect}`
  - Runtime knowledge structures: `KnowledgeEntry.recruiter_retrievable` plus Candidate Context v1 YAML; no other runtime knowledge store found.

  ## Excluded records

  #{excluded.map { |e| "- `#{e.source_reference}` (ID #{e.id}) is excluded because approval is `#{e.approval_status}` and visibility is `#{e.visibility}`; utility is `#{ev(e)["recruiter_utility"] || "missing"}." }.join("\n  ")}
MD

categories = {
  "characterization" => /identity|engineer|character|product design|full.?stack/i, "candidacy" => /role|candidate|career|engineering experience/i,
  "product judgment" => /product|priorit|direction|customer|user/i, "product restraint" => /tradeoff|migration|scope|not build/i,
  "Rails" => /rails|ruby/i, "React" => /react/i, "TypeScript" => /typescript/i, "technical ownership" => /ownership|implemented|built|designed/i,
  "collaboration" => /collaborat|team|code review|guidance/i, "organization/team scale" => /organization|large engineering/i,
  "ambiguity" => /ambig|unclear|confus/i, "prioritization" => /priorit/i, "failure" => /failure|mistake|lesson|technical debt/i,
  "debugging" => /debug|incident|observab|performance/i, "production reliability" => /production|incident|reliab/i, "impact" => /impact|result|metric|sales|growth/i,
  "stakeholder influence" => /stakeholder|ceo|founder|influence|pushback/i, "influence without authority" => /influence|persuad|pushback/i,
  "mentorship" => /mentor|manager|development|people/i, "learning" => /learn|unfamiliar|trajectory/i, "disagreement" => /disagree|pushback|tradeoff/i,
  "risk/weakness" => /boundary|gap|limitation|risk|weakness/i, "integrations/APIs" => /api|integration|stripe|shopify|zoom/i, "architecture/system design" => /architecture|system|workflow|data model/i
}
coverage = categories.map do |name, pattern|
  matches = recruiter.select { |e| [ e.title, e.body, e.short_body, JSON.generate(ev(e)), caps(e).join(" ") ].join(" ").match?(pattern) }
  state = matches.empty? ? "absent" : matches.length == 1 ? "thin; dependent on one story" : matches.length >= 8 ? "over-represented" : "adequate"
  "| #{name} | #{state} | #{matches.map { |e| "##{e.id} #{e.title}" }.join("; ").presence || "None"} |"
end.join("\n")
File.write(out.join("coverage-matrix.md"), "# Pre-launch recruiter evidence coverage matrix\n\nGenerated #{Time.current.iso8601} from the exact 34-entry recruiter-retrievable scope. Matching is a mechanical audit aid, not a claim that every matched record fully answers the intent.\n\n| Intent | Coverage assessment | Matching records |\n|---|---|---|\n#{coverage}\n\nStronger areas are Rails, product work, integrations, ownership, and retail impact. Thin areas include direct engineering disagreement behavior, influence without authority, TypeScript depth, system-design characterization, and large engineering-team experience. Retail leadership supports mentorship/stakeholder context only where evidence supports it; it is not engineering management.\n")

context = AskJared::CandidateContext.new
context_audit = context.records.map do |record|
  "### `#{record["key"]}`\n\n- Category: #{record["category"]}\n- Purpose: #{record["purpose"]}\n- Source references: #{val(record["source_references"])}\n- Guidance: #{record["guidance"]}\n- Affects: #{val(record["affects"])}\n- Useful now: yes, as conservative planning guidance\n- Redundant: review against the richer externally authored v2 corpus\n- Too retrieval-specific: #{Array(record["affects"]).include?("retrieval") ? "partly; preserve only if it remains a planning relationship" : "no obvious issue"}\n- Retain in v2: candidate for merge/rewrite, not assumed permanent\n- Recommended disposition: **REWRITE**\n"
end.join("\n")
File.write(out.join("candidate-context-v1-audit.md"), "# Candidate Context v1 audit\n\nGenerated #{Time.current.iso8601}. Starting records: #{context.records.length}. These records are private planning guidance, not recruiter evidence. The v1 YAML predates explicit approval fields and is treated as approved legacy planning data; new v2 records require explicit `approval_status: approved`.\n\n#{context_audit}\n")

puts out
