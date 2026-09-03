require "test_helper"
require_relative "../../app/services/ask_jared/terra_skeleton_provider"
require_relative "../../app/services/ask_jared/recruiter_answer_skeleton"

class AskJaredTerraSkeletonProviderTest < ActiveSupport::TestCase
  Http = Struct.new(:response, :request_body) do
    def post(_endpoint, body, _headers)
      self.request_body = JSON.parse(body)
      response
    end
  end

  def entry
    KnowledgeEntry.new(
      id: 50, title: "Collaboration", body: "Direct collaboration.", source_reference: "story:collaboration", entry_type: "project",
      metadata: { "recruiter_evidence" => { "claims" => [ { "text" => "Direct engineer collaboration is demonstrated.", "kind" => "demonstrated" } ] } }
    )
  end

  test "Terra uses completion contract and returns role-linked segments" do
    body = { choices: [ { message: { content: { status: "answer", segments: [ { text: "Direct engineer collaboration is demonstrated.", role_refs: [ "r1" ] } ] }.to_json } } ] }.to_json
    http = Http.new(Net::HTTPSuccess.allocate.tap { |response| response.define_singleton_method(:body) { body } })
    packet = AskJared::SynthesisEvidencePacket.new(entries: [ entry ], intent: "collaboration", question: "How has Jared collaborated?", max_claims: 3)
    skeleton = AskJared::RecruiterAnswerSkeleton.new(packet: packet, intent: "collaboration", question: "How has Jared collaborated?")

    response = AskJared::TerraSkeletonProvider.new(api_key: "test-key", http: http).call(question: "How has Jared collaborated?", skeleton: skeleton)

    assert_equal "answer", response["status"]
    assert_equal [ "r1" ], response["segments"].first["role_refs"]
    assert_equal "gpt-5.6-terra", http.request_body.fetch("model")
    assert_equal 500, http.request_body.fetch("max_completion_tokens")
    refute http.request_body.key?("temperature")
  end

  test "role refs outside the skeleton are rejected" do
    packet = AskJared::SynthesisEvidencePacket.new(entries: [ entry ], intent: "collaboration")
    skeleton = AskJared::RecruiterAnswerSkeleton.new(packet: packet, intent: "collaboration", question: "How has Jared collaborated?")

    assert_raises(AskJared::EvidenceIntegrity::Violation) { skeleton.resolve_role_refs!([ "r2" ]) }
  end
end
