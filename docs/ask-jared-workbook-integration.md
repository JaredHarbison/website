# Ask Jared workbook integration

The job-search workbooks remain the source of truth for application workflow
fields. Rails/Postgres remains the source of truth for tokens, access, and
recruiter engagement. The shared ledger coordinates primary and secondary
ChatGPT sessions; it is not an HTTP execution engine.

## Required fields

Each relevant tracker tab needs a header row with these fields (the script
accepts the alternate names shown in parentheses):

| Field | Purpose |
| --- | --- |
| External Tracker ID (Tracker/Application ID/Application ID) | Stable role/application identifier; unique per role |
| Company | Opportunity company |
| Role Title (Role) | Opportunity role |
| Ask Token (Ask Token/Bearer Token) | Pre-minted token claimed for this role |
| AskLink (Ask Link) | URL returned by Rails and used in application materials |
| Application State (Status/State) | The manual Applied or Submitted transition |
| Submission Date (Submitted At/Applied Date) | Jared's submission timestamp |
| Source Tracker (Tracker Source) | Rapid, Target, or Recruiter/Recruited |
| Ask Sync State (Rails Sync State) | Script-managed SYNCED or ERROR state |
| Ask Sync Message (Rails Sync Message) | Short operational result/error |

Exact sheet names and any workbook-specific header aliases must be confirmed
before installation. The script ignores tabs not listed in the optional
`ASK_JARED_SHEET_NAMES` property and ignores edits outside the state column.

## Installable Apps Script setup

1. Open the shared workbook and choose **Extensions → Apps Script**.
2. Add `integrations/google_apps_script/ask_jared_submission_sync.gs`.
3. Set Script Properties in **Project Settings → Script Properties**:
   - `ASK_JARED_API_URL`: the Rails website origin, without a trailing slash.
   - `ASK_JARED_SYNC_KEY`: the value of Heroku `JOB_SEARCH_SYNC_TOKEN`.
   - `ASK_JARED_SHEET_NAMES`: exact comma-separated tracker tab names.
   - optionally `ASK_JARED_HEADER_ROW` and `ASK_JARED_APPLIED_VALUES`.
4. Create a trigger for `askJaredInstallableOnEdit`, event source **From
   spreadsheet**, event type **On edit**. Do not use a simple `onEdit` trigger;
   the authenticated HTTP request requires an installable trigger.
5. On a test row with a valid claimed token, change only the application state
   to `Applied`. Confirm Rails receives one submission, AskLink is written, and
   sync state becomes `SYNCED`.
6. Repeat the same edit or rerun the request. The stable external ID and Rails
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

## Jared follow-up actions

- Confirm the exact workbook IDs, tab names, header row, and applied-state values
  for Rapid Tracker, Target Tracker, Recruiter/Recruited Tracker, and the
  shared Action Ledger.
- Add the required fields or approve exact existing-column aliases.
- Install the script and trigger only after `JOB_SEARCH_SYNC_TOKEN` is set in
  Heroku and the website has been deployed.
- Perform the test with a non-production/test opportunity first.
