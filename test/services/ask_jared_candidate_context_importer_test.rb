require "test_helper"
require "tempfile"

class AskJaredCandidateContextImporterTest < ActiveSupport::TestCase
  setup { CandidateContextRecord.delete_all }

  test "imports by stable id idempotently and only approved private records are planning eligible" do
    file = Tempfile.new([ "candidate-context-v2", ".yml" ])
    file.write(<<~YAML)
      version: candidate-context-v2
      records:
        - id: positioning.test
          category: positioning
          approval_status: approved
          privacy_classification: private
          purpose: "A test planning cue."
          guidance: "Seek approved evidence."
          source_references: ["case-study:test"]
          provenance: { type: test }
          affects: [interpretation]
          intent_tags: [characterization]
          relationships: {}
          priority: 10
        - id: draft.test
          category: positioning
          approval_status: draft
          privacy_classification: private
          purpose: "Not active."
          guidance: "Never use."
          source_references: []
          provenance: { type: test }
          affects: [interpretation]
          intent_tags: []
          relationships: {}
      YAML
    file.close

    importer = AskJared::CandidateContextImporter.new
    importer.import(path: file.path)
    importer.import(path: file.path)

    assert_equal 2, CandidateContextRecord.count
    assert_equal 1, CandidateContextRecord.approved_for_planning.count
    assert_equal "positioning.test", CandidateContextRecord.approved_for_planning.first.stable_key
  ensure
    file&.unlink
  end

  test "retirement is a lifecycle state and does not delete the record" do
    record = CandidateContextRecord.create!(stable_key: "retired.test", corpus_version: "candidate-context-v2", category: "positioning", approval_status: "retired", privacy_classification: "private", guidance: "Retired", retired_at: Time.current)

    assert CandidateContextRecord.exists?(record.id)
    assert_empty CandidateContextRecord.approved_for_planning.where(id: record.id)
  end
end
