module AskJared
  class QuestionService
    MAX_QUESTION_LENGTH = 600
    MIN_QUESTION_LENGTH = 3
    GARBAGE_PATTERN = /\A(.)\1{20,}\z/

    def initialize(token_service: TokenService.new, retriever: ApprovedKnowledgeRetriever.new, provider: OpenAiProvider.new, engagement_service: EngagementService.new, usage_guard: UsageGuard.new)
      @token_service = token_service
      @retriever = retriever
      @provider = provider
      @engagement_service = engagement_service
      @usage_guard = usage_guard
    end

    def call(raw_token:, question:, session_id:, ip: nil, request_id:, admin_preview: false)
      token = @token_service.resolve(raw_token)
      unless admin_preview
        raise ActiveRecord::RecordNotFound, "Ask token is invalid or unavailable" unless @token_service.recruiter_accessible?(token)
      end
      validate_question!(question)
      session_digest = @usage_guard.digest_session(session_id)
      @usage_guard.check!(token: token, session_digest: session_digest) unless admin_preview

      entries = @retriever.call(question)
      evidence_ids = entries.map { |entry| entry.id.to_s }
      source_urls = entries.filter_map(&:public_url).select { |url| url.start_with?("https://") }.uniq
      response = entries.empty? ? insufficient_response : @provider.call(question: question.to_s.strip, context: entries)
      response = StructuredResponse.validate!(response)
      response["evidence_ids"] = response["evidence_ids"] & evidence_ids
      response["source_urls"] = response["source_urls"] & source_urls

      unless admin_preview
        @engagement_service.record!(raw_token: raw_token, event_type: "question_submitted", session_id: session_id, ip: ip, event_key: "#{request_id}:question")
        @engagement_service.record!(raw_token: raw_token, event_type: "answer_returned", session_id: session_id, ip: ip, event_key: "#{request_id}:answer")
        @usage_guard.record!(token: token, session_digest: session_digest, request_id: request_id, status: "completed", estimated_cost_cents: entries.empty? ? 0 : 1)
      end
      response
    end

    private

    def validate_question!(question)
      value = question.to_s.strip
      raise ArgumentError, "question is required" if value.length < MIN_QUESTION_LENGTH
      raise ArgumentError, "question is too long" if value.length > MAX_QUESTION_LENGTH
      raise ArgumentError, "question is not meaningful" if value.match?(GARBAGE_PATTERN)
    end

    def insufficient_response
      { "status" => "insufficient_information", "answer" => "I don't have enough approved information to answer that confidently.", "evidence_ids" => [], "source_urls" => [] }
    end

    class NullProvider
      def call(**)
        { "status" => "insufficient_information", "answer" => "The Ask Jared answer service is not configured yet.", "evidence_ids" => [], "source_urls" => [] }
      end
    end
  end
end
