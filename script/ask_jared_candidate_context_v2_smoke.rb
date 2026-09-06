require "json"

questions = [
  "What kind of engineer is Jared?",
  "What are Jared's strongest qualities as an engineer?",
  "What is a weakness or gap in Jared's experience that a hiring manager should know about?",
  "What are some examples of product decisions Jared has influenced, not just engineering work he's implemented?",
  "Tell me more about the first example. What did Jared have to convince people of?",
  "What has Jared owned end to end?",
  "How much professional TypeScript experience does Jared have?",
  "Tell me about a time Jared disagreed with a technical direction.",
  "Tell me about something Jared decided not to build.",
  "How has Jared influenced a decision when he wasn't the formal decision-maker?"
].freeze

def run_question(question, architecture, index)
  AskJared::QuestionService.new.call(
    raw_token: nil, question: question, session_id: "candidate-context-v2-smoke-#{architecture}",
    request_id: "candidate-context-v2-smoke-#{architecture}-#{index}", admin_preview: true,
    architecture: architecture, evaluation: true
  )
end

rows = questions.each_with_index.map do |question, index|
  { "id" => index + 1, "question" => question, "baseline" => run_question(question, "baseline-v1", index), "candidate_context_v2" => run_question(question, "candidate-context-v2", index) }
rescue StandardError => error
  { "id" => index + 1, "question" => question, "status" => "runner_error", "error" => error.message }
end

path = Rails.root.join("docs/ask-jared/prelaunch/context-v2-smoke-live.json")
File.write(path, JSON.pretty_generate({ "generated_at" => Time.current.iso8601, "architecture_versions" => [ "baseline-v1", "candidate-context-v2" ], "rows" => rows }))
puts path
