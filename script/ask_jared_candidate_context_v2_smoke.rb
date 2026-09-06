require "json"
require "securerandom"

QUESTIONS = [
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

def run_question(question, architecture, index, raw_token: nil, admin_preview: true)
  AskJared::QuestionService.new.call(
    raw_token: raw_token, question: question, session_id: "candidate-context-v2-smoke-#{architecture}",
    request_id: "candidate-context-v2-smoke-#{architecture}-#{index}", admin_preview: admin_preview,
    architecture: architecture, evaluation: true
  )
end

def internal_qa_token(architecture)
  token_service = AskJared::TokenService.new
  _token, raw = token_service.mint!(expires_at: 1.day.from_now)
  token_service.claim!(raw_token: raw, external_id: "internal-qa:smoke-#{architecture}-#{SecureRandom.hex(8)}", company: "Internal QA", role_title: architecture, tracker_source: "internal_qa")
  raw
end

def follow_up_chain(architecture)
  raw_token = internal_qa_token(architecture)
  session_id = "candidate-context-v2-smoke-chain-#{architecture}"
  service = AskJared::QuestionService.new
  first = service.call(raw_token: raw_token, question: QUESTIONS.fetch(3), session_id: session_id, request_id: "candidate-context-v2-chain-#{architecture}-4", admin_preview: false, architecture: architecture, evaluation: true)
  second = service.call(raw_token: raw_token, question: QUESTIONS.fetch(4), session_id: session_id, request_id: "candidate-context-v2-chain-#{architecture}-5", admin_preview: false, architecture: architecture, evaluation: true)
  [ first, second ]
end

chains = %w[baseline-v1 candidate-context-v2].to_h { |architecture| [ architecture, follow_up_chain(architecture) ] }

rows = QUESTIONS.each_with_index.map do |question, index|
  baseline = index.between?(3, 4) ? chains.fetch("baseline-v1").fetch(index - 3) : run_question(question, "baseline-v1", index)
  v2 = index.between?(3, 4) ? chains.fetch("candidate-context-v2").fetch(index - 3) : run_question(question, "candidate-context-v2", index)
  { "id" => index + 1, "question" => question, "baseline" => baseline, "candidate_context_v2" => v2 }
rescue StandardError => error
  { "id" => index + 1, "question" => question, "status" => "runner_error", "error" => error.message }
end

path = Rails.root.join("docs/ask-jared/prelaunch/context-v2-smoke-live.json")
File.write(path, JSON.pretty_generate({ "generated_at" => Time.current.iso8601, "architecture_versions" => [ "baseline-v1", "candidate-context-v2" ], "rows" => rows }))
puts path
