/**
 * Ask Jared submission sync for an installable onEdit trigger.
 *
 * Required Script Properties (never put these in cells):
 *   ASK_JARED_API_URL   e.g. https://jaredharbison.com
 *   ASK_JARED_SYNC_KEY  Rails JOB_SEARCH_SYNC_TOKEN
 *
 * Optional Script Properties:
 *   ASK_JARED_SHEET_NAMES  comma-separated exact tab names
 *   ASK_JARED_HEADER_ROW   defaults to 1
 *   ASK_JARED_APPLIED_VALUES comma-separated values, defaults to Applied,Submitted
 */
function askJaredInstallableOnEdit(e) {
  if (!e || !e.range) return;

  var range = e.range;
  var sheet = range.getSheet();
  var properties = PropertiesService.getScriptProperties();
  var sheetNames = (properties.getProperty('ASK_JARED_SHEET_NAMES') || '')
    .split(',').map(function(name) { return name.trim(); }).filter(String);
  if (sheetNames.length && sheetNames.indexOf(sheet.getName()) === -1) return;

  var headerRow = Number(properties.getProperty('ASK_JARED_HEADER_ROW') || 1);
  if (range.getRow() <= headerRow || range.getLastRow() < range.getRow()) return;

  var headers = sheet.getRange(headerRow, 1, 1, sheet.getLastColumn()).getValues()[0];
  var columns = askJaredColumnMap_(headers);
  if (!columns.state || !columns.externalId || !columns.company || !columns.roleTitle || !columns.rawToken) return;
  if (range.getColumn() > columns.state || range.getLastColumn() < columns.state) return;

  var state = String(sheet.getRange(range.getRow(), columns.state).getDisplayValue()).trim();
  var appliedValues = (properties.getProperty('ASK_JARED_APPLIED_VALUES') || 'Applied,Submitted')
    .split(',').map(function(value) { return value.trim().toLowerCase(); });
  if (appliedValues.indexOf(state.toLowerCase()) === -1) return;

  var lock = LockService.getDocumentLock();
  if (!lock.tryLock(5000)) return;
  try {
    askJaredSubmitRow_(sheet, range.getRow(), columns, properties);
  } finally {
    lock.releaseLock();
  }
}

function askJaredColumnMap_(headers) {
  var normalized = headers.map(function(header) { return String(header).trim().toLowerCase(); });
  function find() {
    for (var i = 0; i < arguments.length; i++) {
      var index = normalized.indexOf(arguments[i].toLowerCase());
      if (index !== -1) return index + 1;
    }
    return 0;
  }
  return {
    externalId: find('External Tracker ID', 'Tracker/Application ID', 'Application ID'),
    company: find('Company'),
    roleTitle: find('Role Title', 'Role'),
    rawToken: find('Ask Token', 'Ask Token/Bearer Token'),
    askLink: find('AskLink', 'Ask Link'),
    sourceTracker: find('Source Tracker', 'Tracker Source'),
    state: find('Application State', 'Status', 'State'),
    submittedAt: find('Submission Date', 'Submitted At', 'Applied Date'),
    syncState: find('Ask Sync State', 'Rails Sync State'),
    syncMessage: find('Ask Sync Message', 'Rails Sync Message')
  };
}

function askJaredSubmitRow_(sheet, row, columns, properties) {
  var values = sheet.getRange(row, 1, 1, sheet.getLastColumn()).getValues()[0];
  function value(column) { return column ? values[column - 1] : ''; }
  var externalId = String(value(columns.externalId)).trim();
  var rawToken = String(value(columns.rawToken)).trim();
  if (!externalId || !rawToken) {
    askJaredWriteSync_(sheet, row, columns, 'ERROR', 'Missing external tracker ID or Ask token');
    return;
  }

  var submittedAt = columns.submittedAt ? value(columns.submittedAt) : new Date();
  var payload = {
    raw_token: rawToken,
    external_id: externalId,
    company: String(value(columns.company)).trim(),
    role_title: String(value(columns.roleTitle)).trim(),
    tracker_source: columns.sourceTracker ? String(value(columns.sourceTracker)).trim() : sheet.getName(),
    submitted_at: submittedAt instanceof Date ? submittedAt.toISOString() : String(submittedAt)
  };
  var apiUrl = properties.getProperty('ASK_JARED_API_URL');
  var syncKey = properties.getProperty('ASK_JARED_SYNC_KEY');
  if (!apiUrl || !syncKey) {
    askJaredWriteSync_(sheet, row, columns, 'ERROR', 'Missing Script Properties configuration');
    return;
  }

  try {
    var response = UrlFetchApp.fetch(apiUrl.replace(/\/$/, '') + '/api/job_search/opportunities/submit', {
      method: 'post',
      contentType: 'application/json',
      headers: {
        'X-Job-Search-Key': syncKey,
        'Idempotency-Key': externalId + ':' + payload.submitted_at
      },
      payload: JSON.stringify(payload),
      muteHttpExceptions: true
    });
    var code = response.getResponseCode();
    var body = JSON.parse(response.getContentText() || '{}');
    if (code >= 200 && code < 300) {
      if (columns.askLink && body.ask_link) sheet.getRange(row, columns.askLink).setValue(body.ask_link);
      askJaredWriteSync_(sheet, row, columns, 'SYNCED', 'Submitted to Rails');
    } else {
      askJaredWriteSync_(sheet, row, columns, 'ERROR', 'Rails returned HTTP ' + code + ': ' + (body.message || 'unknown error'));
    }
  } catch (error) {
    askJaredWriteSync_(sheet, row, columns, 'ERROR', String(error));
  }
}

function askJaredWriteSync_(sheet, row, columns, state, message) {
  if (columns.syncState) sheet.getRange(row, columns.syncState).setValue(state);
  if (columns.syncMessage) sheet.getRange(row, columns.syncMessage).setValue(message.substring(0, 500));
}
