module AskJared
  class StructuredResponse
    STATUSES = %w[answer insufficient_information out_of_scope blocked].freeze
    MAX_ANSWER_LENGTH = 4_000
    MAX_EVIDENCE_IDS = 12
    MAX_SOURCE_URLS = 12

    def self.validate!(payload)
      raise ArgumentError, "model response must be a Hash" unless payload.is_a?(Hash)

      status = payload["status"] || payload[:status]
      answer = payload["answer"] || payload[:answer]
      evidence_ids = payload["evidence_ids"] || payload[:evidence_ids]
      source_urls = payload["source_urls"] || payload[:source_urls]
      claim_refs = payload.key?("claim_refs") ? payload["claim_refs"] : payload[:claim_refs]

      raise ArgumentError, "unsupported response status" unless STATUSES.include?(status)
      raise ArgumentError, "answer must be a String" unless answer.is_a?(String)
      raise ArgumentError, "answer is too long" if answer.length > MAX_ANSWER_LENGTH
      raise ArgumentError, "evidence_ids must be an Array" unless evidence_ids.is_a?(Array) && evidence_ids.length <= MAX_EVIDENCE_IDS && evidence_ids.all? { |id| id.is_a?(String) }
      raise ArgumentError, "source_urls must be an Array" unless source_urls.is_a?(Array) && source_urls.length <= MAX_SOURCE_URLS && source_urls.all? { |url| url.is_a?(String) && url.start_with?("https://") }
      if claim_refs
        raise ArgumentError, "claim_refs must be an Array" unless claim_refs.is_a?(Array) && claim_refs.length <= MAX_EVIDENCE_IDS && claim_refs.all? { |ref| ref.is_a?(String) }
      end

      response = { "status" => status, "answer" => answer, "evidence_ids" => evidence_ids, "source_urls" => source_urls }
      response["claim_refs"] = claim_refs if claim_refs
      response
    end
  end
end
