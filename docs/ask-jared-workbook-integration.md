# Ask Jared workbook integration

The job-search workbooks remain the source of truth for application workflow
fields. Rails/Postgres remains the source of truth for tokens, access, and
recruiter engagement. The shared ledger coordinates primary and secondary
ChatGPT sessions; it is not an HTTP execution engine.

## Required fields

The live workbook uses fixed columns and must not move existing fields:

| Column | Header |
| --- | --- |
| B | Company |
| C | Job Link |
| L | Applied |
| S | Ask ID |
| T | AskLink |
| U | Ask Claim State |
| V | Ask Sync State |
| W | Ask Sync Message |
| X | Ask Engagement |

The relevant tabs are exactly `Rapid Tracker`, `Target Tracker`, and
`Recruiter Tracker`. The script does not alter B:R, existing formulas, or
ignored/rejected behavior. The role-population queue uses the deterministic
Ask ID `rapid:<row-number>`, `target:<row-number>`, or
`recruiter:<row-number>`. Primary/secondary write that value to S and
`PENDING` to U. A one-minute processor claims a token and writes T/U; a row
is not application-ready until T contains AskLink.

For reference, the logical fields are:

| Field | Purpose |
| --- | --- |
| External Tracker ID (Tracker/Application ID/Application ID) | Stable role/application identifier; unique per role |
| Company | Opportunity company |
| Role Title (Role) | Opportunity role |
| Ask Token | Never add this field to a tracker; raw values remain only in the protected pool |
| AskLink (Ask Link) | URL returned by Rails and used in application materials |
| Application State (Status/State) | The manual Applied or Submitted transition |
| Submission Date (Submitted At/Applied Date) | Jared's submission timestamp |
| Source Tracker (Tracker Source) | Rapid, Target, or Recruiter/Recruited |
| Ask Sync State (Rails Sync State) | Script-managed SYNCED or ERROR state |
| Ask Sync Message (Rails Sync Message) | Short operational result/error |

The Applied field is a date, not an Application State field. `8/88/88` and
`9/99/99` are sentinel values for the existing ignored-role workflow and never
submit to Rails. A claimed, unsubmitted pool token is returned to AVAILABLE for
these sentinels; SYNCED or ERROR rows fail safe and are not released.

## Protected token-pool tab

Create a protected tab named by `ASK_JARED_TOKEN_POOL_SHEET` with these headers:

| Header | Meaning |
| --- | --- |
| Inventory ID | Rails token record ID; non-secret inventory reference |
| Ask Token | Raw bearer token; protect the tab and do not copy it into the ledger |
| State | `AVAILABLE`, `CLAIMED`, or `SUBMITTED/CONSUMED` |
| Claimed External ID | Stable tracker/application ID, blank while available |
| Exported At | Operational timestamp |

The pool tab should be protected from ordinary edits and visible only to the
job-search automation/Jared. The raw token is delivered once by the authenticated
Rails refill response and is not stored in Rails after mint/export. The Apps
Script timed function counts `AVAILABLE` rows, calls the token-pool endpoint,
and appends newly returned values under the document lock.

Rails rejects pool targets above 500 regardless of the caller's requested value.
Exported tokens that remain `AVAILABLE` for more than 30 days are revoked during
the next authenticated pool refill. Claimed and submitted tokens are never
affected by that cleanup. A stale token left in the sheet therefore cannot
unlock Ask Jared or be submitted successfully.

The queue processor holds `LockService.getDocumentLock()`, reuses an existing
CLAIMED row for the same Ask ID, otherwise changes exactly one AVAILABLE row to
CLAIMED, and writes only the AskLink to the tracker. The raw token is never
written to another tracker column. Primary and secondary sessions coordinate by
ordinary sheet writes, so they do not need authenticated HTTP.

## Installable Apps Script setup

1. Open the shared workbook and choose **Extensions → Apps Script**.
2. Add `integrations/google_apps_script/ask_jared_submission_sync.gs`.
3. Set Script Properties in **Project Settings → Script Properties**:
   - `ASK_JARED_API_URL`: the Rails website origin, without a trailing slash.
   - `ASK_JARED_SYNC_KEY`: the value of Heroku `JOB_SEARCH_SYNC_TOKEN`.
   - `ASK_JARED_POOL_API_KEY`: the different value of Heroku
     `JOB_SEARCH_TOKEN_POOL_TOKEN`.
   - `ASK_JARED_TOKEN_POOL_SHEET`: exact protected token-pool tab name.
   - `ASK_JARED_SHEET_NAMES`: exact comma-separated tracker tab names.
   - optionally `ASK_JARED_HEADER_ROW` and `ASK_JARED_APPLIED_VALUES`.
4. Create a trigger for `askJaredInstallableOnEdit`, event source **From
   spreadsheet**, event type **On edit**. Do not use a simple `onEdit` trigger;
   the authenticated HTTP request requires an installable trigger.
5. Create a time-driven trigger for `askJaredProcessPendingClaims` at the
   shortest available interval (recommended every minute). This is required
   because Google Sheets API writes do not fire onEdit.
6. Create a daily time-driven trigger for `askJaredRefillTokenPool`. This
   replaces the old DB-only Heroku Scheduler refill;
   no scheduler may mint tokens without delivering their raw values to this
   protected tab.
7. On a test row with a valid AskLink, enter a legitimate calendar date in L.
   Confirm Rails receives one submission and sync state becomes `SYNCED`.
8. Repeat the same edit or rerun the request. The stable external ID and Rails
   uniqueness constraints make the operation safe to retry.

The script stores no API secret in cells. It uses a document lock to reduce
duplicate concurrent edits and writes a bounded error message back to the row
without preventing Jared from continuing the application workflow.

## Rails endpoint contract

```text
POST /api/job_search/opportunities/submit
X-Job-Search-Key: <script property>
Idempotency-Key: <stable external ID plus submission timestamp>
Content-Type: application/json
```

The JSON body contains `raw_token`, `external_id`, `company`, `role_title`,
`tracker_source`, and `submitted_at`. Rails validates the scoped credential,
associates the pre-minted token, marks the opportunity submitted, and returns
`status`, `external_id`, and `ask_link`. It does not grant admin access, approve
knowledge, expose production data, or generate recruiter answers.

## Engagement read sync

Rails exposes a separate, read-only synchronization endpoint for a scheduled
ledger/workbook job:

```text
GET /api/job_search/opportunities/engagements?since=<ISO-8601>
X-Job-Search-Read-Key: <JOB_SEARCH_READ_SYNC_TOKEN>
```

The response contains only application state, token state, timestamps, counts
of meaningful anonymous sessions/questions, a probabilistic possible-share flag
and confidence, a simple follow-up-candidate flag, and aggregate Ask usage
cost. Page loads alone and scanner-like events are excluded from meaningful
counts. Session/IP digests, raw questions, source text, credentials, and KB
internals are never returned. The sync job may run every 15–30 minutes and
should write only these summaries back to the shared ledger.

## Jared follow-up actions

- Confirm the exact workbook IDs, tab names, header row, and applied-state values
  for Rapid Tracker, Target Tracker, Recruiter/Recruited Tracker, and the
  shared Action Ledger.
- Add the required fields or approve exact existing-column aliases.
- Install the script and trigger only after `JOB_SEARCH_SYNC_TOKEN` is set in
  Heroku and the website has been deployed.
- Perform the test with a non-production/test opportunity first.
- Configure the separate `JOB_SEARCH_READ_SYNC_TOKEN` only for the future
  Rails-to-ledger engagement sync; do not reuse the submission credential.
- Have ChatGPT Work implement the scheduled read-sync job using the endpoint
  above, preserving the last successful `since` timestamp and writing errors to
  the ledger without overwriting the last known good summary.
