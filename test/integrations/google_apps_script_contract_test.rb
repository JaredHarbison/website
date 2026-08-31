require "test_helper"

class GoogleAppsScriptContractTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("integrations/google_apps_script/ask_jared_submission_sync.gs")

  setup do
    @script = File.read(SCRIPT)
  end

  test "uses live tracker tabs and fixed Ask columns" do
    assert_includes @script, "['Rapid Tracker', 'Target Tracker', 'Recruiter Tracker']"
    assert_includes @script, "ASK_JARED_ASK_ID_COL = 19"
    assert_includes @script, "ASK_JARED_ASK_LINK_COL = 20"
    assert_includes @script, "ASK_JARED_CLAIM_STATE_COL = 21"
    assert_includes @script, "ASK_JARED_SYNC_STATE_COL = 22"
    assert_includes @script, "ASK_JARED_SYNC_MESSAGE_COL = 23"
  end

  test "defines queue processor, deterministic IDs, and lock-protected claims" do
    assert_includes @script, "function askJaredProcessPendingClaims()"
    assert_includes @script, "LockService.getDocumentLock()"
    assert_includes @script, "claimState !== 'PENDING'"
    assert_includes @script, "askJaredClaimPoolToken_"
    assert_includes @script, "No AVAILABLE Ask token in pool"
    assert_includes @script, "Waiting for Ask token inventory"
    assert_includes @script, "claimState !== 'PENDING'"
  end

  test "reconciles stale pool rows and sends bounded claimed inventory metadata" do
    assert_includes @script, "ASK_JARED_EXPORTED_UNCLAIMED_TTL_DAYS = 30"
    assert_includes @script, "askJaredReconcileStaleAvailableRows_"
    assert_includes @script, "claimed_inventory_ids: claimedInventoryIds"
    assert_includes @script, "item.state === 'AVAILABLE'"
    assert_includes @script, "item.state = 'REVOKED'"
  end

  test "uses explicit sentinel handling and never reads a tracker Ask Token column" do
    assert_includes @script, "display === '8/88/88' || display === '9/99/99'"
    assert_includes @script, "function askJaredReleaseClaimForSentinel_"
    assert_includes @script, "syncState === 'SYNCED' || syncState === 'ERROR'"
    refute_includes @script, "rawToken: find"
    refute_includes @script, "targetHeaders.rawToken"
  end

  test "keeps pool and submission credentials separate" do
    assert_includes @script, "ASK_JARED_POOL_API_KEY"
    assert_includes @script, "ASK_JARED_SYNC_KEY"
    assert_includes @script, "X-Job-Search-Pool-Key"
    assert_includes @script, "X-Job-Search-Key"
  end
end
