require "test_helper"

class AskJaredPublicCorpusQuestionServiceTest < ActiveSupport::TestCase
  test "allows the site-writing path only in an explicit admin preview" do
    answerer = Class.new do
      attr_reader :questions
      def initialize = @questions = []
      def call(question:, decision:)
        questions << question
        @decision = decision
        { "status" => "answer", "answer" => "Published answer.", "evidence_ids" => [ "pages:about" ], "evaluation" => {} }
      end
    end.new
    service = AskJared::QuestionService.new(public_corpus_answerer: answerer)

    response = service.call(raw_token: nil, question: "What kind of engineer is Jared?", session_id: "public-corpus-preview", request_id: "public-corpus-preview", admin_preview: true, architecture: AskJared::QuestionService::PUBLIC_CORPUS_ARCHITECTURE, evaluation: true)

    assert_equal [ "What kind of engineer is Jared?" ], answerer.questions
    assert_equal "public-corpus-rules-v1", response.dig("evaluation", "architecture")
  end
end
