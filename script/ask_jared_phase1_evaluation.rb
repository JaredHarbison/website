require "yaml"
require "securerandom"
require "fileutils"

battery = YAML.safe_load(File.read(Rails.root.join("test/fixtures/ask_jared_recruiter_evaluation.yml")), permitted_classes: [], aliases: false)
output_dir = Rails.root.join("docs/ask-jared/phase1")
FileUtils.mkdir_p(output_dir)
evaluation_filename = ENV.fetch("PHASE1_EVALUATION_FILENAME", "evaluation.md")

def run_case(question, architecture, index)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  result = AskJared::QuestionService.new.call(
    raw_token: nil, question: question, session_id: "phase1-#{architecture}-#{index}", request_id: "phase1-#{architecture}-#{index}-#{SecureRandom.hex(4)}",
    admin_preview: true, architecture: architecture
  )
  result.merge("latency_ms" => ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round)
rescue StandardError => error
  { "status" => "runner_error", "answer" => error.message, "evidence_ids" => [], "source_urls" => [], "latency_ms" => nil }
end

def run_conversation(questions, architecture)
  token_service = AskJared::TokenService.new
  previous = ENV["ASK_JARED_CANDIDATE_CONTEXT"]
  architecture == "candidate-context-v1" ? ENV["ASK_JARED_CANDIDATE_CONTEXT"] = "1" : ENV.delete("ASK_JARED_CANDIDATE_CONTEXT")
  results = []
  ActiveRecord::Base.transaction do
    _token, raw = token_service.mint!
    token_service.claim!(raw_token: raw, external_id: "phase1-sequence-#{SecureRandom.hex(6)}", company: "Phase 1 QA", role_title: "Evaluation")
    service = AskJared::QuestionService.new
    questions.each_with_index do |question, index|
      results << run_case_with_token(service, raw, question, architecture, "sequence-#{index}")
    end
    raise ActiveRecord::Rollback
  end
  results
ensure
  previous ? ENV["ASK_JARED_CANDIDATE_CONTEXT"] = previous : ENV.delete("ASK_JARED_CANDIDATE_CONTEXT")
end

def run_case_with_token(service, raw_token, question, architecture, index)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  service.call(raw_token: raw_token, question: question, session_id: "phase1-sequence-#{architecture}", request_id: "phase1-sequence-#{architecture}-#{index}").merge("latency_ms" => ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round)
rescue StandardError => error
  { "status" => "runner_error", "answer" => error.message, "evidence_ids" => [], "source_urls" => [], "latency_ms" => nil }
end

def markdown_answer(result)
  answer = result["answer"].to_s.gsub("\n", " ")
  "#{result["status"]}: #{answer} (evidence=#{Array(result["evidence_ids"]).join(", ").presence || "none"}; latency=#{result["latency_ms"] || "n/a"}ms)"
end

rows = battery.map.with_index do |item, index|
  baseline = run_case(item.fetch("question"), "baseline-v1", index)
  experiment = run_case(item.fetch("question"), "candidate-context-v1", index)
  { item: item, baseline: baseline, experiment: experiment }
end

stability_ids = %w[Q01 Q04 Q07 Q16 Q25 Q26 Q28 Q34]
stability = stability_ids.map do |id|
  item = battery.find { |candidate| candidate.fetch("id") == id }
  runs = (1..3).map do |run|
    { run: run, baseline: run_case(item.fetch("question"), "baseline-v1", "stability-#{id}-#{run}"), experiment: run_case(item.fetch("question"), "candidate-context-v1", "stability-#{id}-#{run}") }
  end
  { item: item, runs: runs }
end

sequence_questions = [
  "What kind of engineer is Jared?",
  "What are some examples of product decisions Jared has influenced, not just engineering work he's implemented?",
  "Tell me more about the first example. What did Jared have to convince people of?",
  "What is a weakness or gap in Jared's experience that a hiring manager should know about?"
]
sequences = { "baseline-v1" => run_conversation(sequence_questions, "baseline-v1"), "candidate-context-v1" => run_conversation(sequence_questions, "candidate-context-v1") }

File.write(output_dir.join(evaluation_filename), <<~MARKDOWN)
  # Ask Jared Phase 1 evaluation

  Generated #{Time.current.iso8601}. This is a frozen-battery capture; answers below are unedited service outputs.

  Provider configured: #{ENV["OPENAI_API_KEY"].present?}. Candidate Context is never included in this artifact.

  ## Scoring key

  Each substantive answer is intended for 0–2 human scoring on grounding, directness, candidate understanding, emphasis/prioritization, recruiter language, boundary quality, and readability. `N/A` is allowed. Because this environment has no provider key, the current capture records service status rather than inventing substantive scores.

  ## Before / after

  | ID | Category | Prompt | Baseline | Experiment | Scores / note |
  |---|---|---|---|---|---|
  #{rows.map { |row| item = row[:item]; "| #{item["id"]} | #{item["category"]} | #{item["question"].gsub("|", "\\|")} | #{markdown_answer(row[:baseline])} | #{markdown_answer(row[:experiment])} | Human review required |" }.join("\n")}

  ## Stability subset

  Required stability prompts: #{stability_ids.join(", ")}; three runs per path were requested. Run-by-run outputs are retained below.

  #{stability.map { |entry| "### #{entry[:item]["id"]} — #{entry[:item]["question"]}\n\n" + entry[:runs].map { |run| "- Run #{run[:run]} — baseline: #{markdown_answer(run[:baseline])}; experiment: #{markdown_answer(run[:experiment])}" }.join("\n") }.join("\n\n")}

  ## Exact four-question conversational sequences

  #{sequences.map { |architecture, results| "### #{architecture}\n\n" + results.each_with_index.map { |result, index| "#{index + 1}. #{markdown_answer(result)}" }.join("\n") }.join("\n\n")}

  ## Capture interpretation

  #{if ENV["OPENAI_API_KEY"].present? then "Provider-backed outputs were captured. Human scoring and promotion review remain required." else "BLOCKED: OPENAI_API_KEY is not configured in this workspace. The service-equivalent baseline and experimental calls were exercised and returned their unavailable/insufficient states; no substantive quality claim is made." end}
MARKDOWN

retriever = AskJared::ApprovedKnowledgeRetriever.new
intent_rows = %w[characterization candidacy product rails react typescript collaboration organization ambiguity prioritization failure impact stakeholder mentorship production learning disagreement risk]
coverage = intent_rows.map do |intent|
  entries = retriever.send(:qualified_pool, intent)
  boundaries = KnowledgeEntry.recruiter_retrievable.to_a.select { |entry| Array(entry.metadata.dig("recruiter_evidence", "claims")).any? { |claim| claim["kind"] == "boundary" } }
  refs = entries.map(&:source_reference)
  "| #{intent} | #{entries.length} | #{refs.first(3).join(", ").presence || "None"} | #{refs.drop(3).first(3).join(", ").presence || "None"} | #{boundaries.map(&:source_reference).first(3).join(", ").presence || "None"} | #{entries.length <= 1 ? "Thin / single-story dependence" : "Review for repetition"} |"
end
File.write(output_dir.join("coverage-matrix.md"), <<~MARKDOWN)
  # Approved recruiter corpus coverage matrix

  Generated #{Time.current.iso8601} from the current recruiter-visible approved KnowledgeEntry scope (#{KnowledgeEntry.recruiter_retrievable.count} entries). Primary/secondary labels are inferred from current retriever qualification and recruiter utility metadata; this is a QA diagnostic, not Candidate Context.

  | Intent | Eligible entries | Primary candidates | Secondary candidates | Boundary evidence | Coverage note |
  |---|---:|---|---|---|---|
  #{coverage.join("\n")}

  ## Corpus observations

  - The current corpus is strongest where the retriever has dedicated structured evidence: product direction, boundaries, engineering collaboration, and selected technical stories.
  - Thin intents should be treated as corpus-coverage questions before adding more planning guidance; a planner cannot create missing approved facts.
  - Repetition risk is concentrated in broad characterization/candidacy and impact questions because a small number of Dogly/product and retail outcome stories carry several capabilities.
  - No entries were created or rewritten by this report.
MARKDOWN

context = AskJared::CandidateContext.new
inventory = context.records.map do |record|
  "| #{record["key"]} | #{record["category"]} | #{record["purpose"]} | #{Array(record["source_references"]).join(", ")} | #{Array(record["affects"]).join(", ")} | yes |"
end
File.write(output_dir.join("candidate-context-inventory.md"), <<~MARKDOWN)
  # Candidate Context v1 inventory

  This reviewed, code-backed planning inventory has #{context.records.length} active concepts. It is private application context, is not a KnowledgeEntry, is not embedded, and cannot be cited.

  | Stable key | Category | Purpose | Derived source references | Affects | Active v1 |
  |---|---|---|---|---|---|
  #{inventory.join("\n")}
MARKDOWN

puts output_dir.join(evaluation_filename)
