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
end
