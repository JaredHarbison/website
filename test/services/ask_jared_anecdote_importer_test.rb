require "test_helper"
require_relative "../../app/services/ask_jared/knowledge_entry"
require_relative "../../app/services/ask_jared/anecdote_importer"

class AskJaredAnecdoteImporterTest < ActiveSupport::TestCase
  class MemoryStore
    attr_reader :entries

    def initialize
      @entries = []
    end

    def find_by_source_reference(reference)
      entries.find { |entry| entry.source_reference == reference }
    end

    def save(entry)
      entry.id ||= "entry-#{entries.length + 1}"
      entries << entry
      entry
    end
  end

  def setup
    @store = MemoryStore.new
    @importer = AskJared::AnecdoteImporter.new(store: @store)
  end

  def anecdote(id = "A-001", evidence: "Interview note", title: "A story")
    {
      "anecdote_id" => id,
      "title" => title,
      "body" => evidence,
      "source_evidence" => { "transcript" => evidence, "version" => 1 }
    }
  end

  test "imports records as private candidates" do
    entries = @importer.sync([ anecdote ])

    assert_equal 1, entries.length
    assert_equal "A-001", entries.first.source_reference
    assert_equal "candidate", entries.first.approval_status
    assert_equal "private", entries.first.visibility
    assert_equal "anecdote", entries.first.source_type
  end

  test "can import the complete 49-record-shaped baseline without duplicates" do
    records = 1.upto(49).map { |number| anecdote("A-%03d" % number) }

    @importer.sync(records)
    @importer.sync(records)

    assert_equal 49, @store.entries.length
    assert @store.entries.all? { |entry| entry.approval_status == "candidate" && entry.visibility == "private" }
  end

  test "repeated synchronization is idempotent" do
    @importer.sync([ anecdote ])
    @importer.sync([ anecdote ])

    assert_equal 1, @store.entries.length
  end

  test "preserves reviewer edits and decisions when evidence is unchanged" do
    entry = @importer.sync([ anecdote ]).first
    entry.approval_status = "approved"
    entry.visibility = "public"
    entry.reviewer_edits = { "body" => "Edited for public wording" }
    entry.reviewer_note = "Reviewed"

    refreshed = @importer.sync([ anecdote(title: "Updated title") ]).first

    assert_equal "approved", refreshed.approval_status
    assert_equal "public", refreshed.visibility
    assert_equal({ "body" => "Edited for public wording" }, refreshed.reviewer_edits)
    assert_equal "Reviewed", refreshed.reviewer_note
  end

  test "moves approved entries to needs_review when source evidence changes" do
    entry = @importer.sync([ anecdote ]).first
    entry.approval_status = "approved"
    entry.visibility = "public"
    original_fingerprint = entry.source_fingerprint

    refreshed = @importer.sync([ anecdote(evidence: "Changed interview note") ]).first

    assert_equal "needs_review", refreshed.approval_status
    assert_equal "public", refreshed.visibility
    refute_equal original_fingerprint, refreshed.source_fingerprint
  end

  test "fingerprints source evidence independent of hash key order" do
    first = anecdote
    second = anecdote
    second["source_evidence"] = { "version" => 1, "transcript" => "Interview note" }

    @importer.sync([ first ])
    entry = @importer.sync([ second ]).first

    assert_equal "candidate", entry.approval_status
    assert_equal 1, @store.entries.length
  end

  test "maps a sheet row into structured recruiter-safe evidence" do
    entry = @importer.sync_sheet_rows([
      {
        anecdote_id: "DOG-01", source_project: "Dogly SEO", situation: "SEO was weak",
        what_i_did: "Modernized the site", technical_detail: "Added metadata",
        product_result: "Improved search visibility", metric_evidence: "Scores rose from 15% to 85%",
        competencies: "SEO; modernization", best_role_types: "Product engineer",
        jd_signals: "SEO; performance", resume_visible: "Yes", source_link: "CV evidence",
        confidence: "High", safe_claims: "Do not imply traffic impact"
      }
    ]).first

    assert_equal "DOG-01", entry.source_reference
    assert_equal "performance_story", entry.entry_type
    assert_includes entry.body, "Situation: SEO was weak"
    assert_includes entry.body, "Evidence: Scores rose from 15% to 85%"
    assert_equal "Do not imply traffic impact", entry.metadata["safe_claims"]
    assert_equal "candidate", entry.approval_status
    assert_equal "private", entry.visibility
  end
end
