/**
 * Ask Jared submission sync for an installable onEdit trigger.
 *
 * Required Script Properties (never put these in cells):
 *   ASK_JARED_API_URL   e.g. https://jaredharbison.com
 *   ASK_JARED_SYNC_KEY  Rails JOB_SEARCH_SYNC_TOKEN
 *   ASK_JARED_TOKEN_POOL_SHEET  exact protected token-pool tab name
 *   ASK_JARED_POOL_API_KEY  Rails JOB_SEARCH_TOKEN_POOL_TOKEN
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

// Install as a time-driven trigger (for example, every 30 minutes). The raw
// values returned by Rails are written directly to the protected pool sheet.
function askJaredRefillTokenPool() {
  var properties = PropertiesService.getScriptProperties();
  var sheet = SpreadsheetApp.getActive().getSheetByName(properties.getProperty('ASK_JARED_TOKEN_POOL_SHEET'));
  if (!sheet) throw new Error('Token-pool sheet is not configured');
  var lock = LockService.getDocumentLock();
  lock.waitLock(10000);
  try {
    var columns = askJaredColumnMap_(sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0]);
    var available = askJaredCountPool_(sheet, columns);
    var response = UrlFetchApp.fetch(properties.getProperty('ASK_JARED_API_URL').replace(/\/$/, '') + '/api/job_search/token_pool/refill', {
      method: 'post', contentType: 'application/json', muteHttpExceptions: true,
      headers: { 'X-Job-Search-Pool-Key': properties.getProperty('ASK_JARED_POOL_API_KEY') },
      payload: JSON.stringify({ sheet_available_count: available })
    });
    if (response.getResponseCode() < 200 || response.getResponseCode() >= 300) throw new Error('Token pool refill HTTP ' + response.getResponseCode());
    JSON.parse(response.getContentText()).tokens.forEach(function(token) {
      sheet.appendRow([token.inventory_id, token.token, token.state, '', new Date()]);
    });
  } finally {
    lock.releaseLock();
  }
}

// Called by the role-population workflow after it has written the stable
// external ID to the role row. The document lock makes primary/secondary
// assignment atomic and repeated calls for one ID reuse the same token.
function askJaredClaimToken(externalId, targetSheetName, targetRow) {
  var properties = PropertiesService.getScriptProperties();
  var workbook = SpreadsheetApp.getActive();
  var pool = workbook.getSheetByName(properties.getProperty('ASK_JARED_TOKEN_POOL_SHEET'));
  var target = workbook.getSheetByName(targetSheetName);
  if (!pool || !target) throw new Error('Token-pool or target sheet is not configured');
  var lock = LockService.getDocumentLock();
  lock.waitLock(10000);
  try {
    var rows = pool.getDataRange().getValues();
    var headers = askJaredColumnMap_(rows[0]);
    var selected = 0;
    for (var i = 1; i < rows.length; i++) {
      if (String(rows[i][headers.claimId - 1] || '') === externalId) { selected = i + 1; break; }
      if (!selected && String(rows[i][headers.state - 1] || '').toUpperCase() === 'AVAILABLE') selected = i + 1;
    }
    if (!selected) throw new Error('No AVAILABLE Ask token in pool');
    pool.getRange(selected, headers.state).setValue('CLAIMED');
    pool.getRange(selected, headers.claimId).setValue(externalId);
    var token = pool.getRange(selected, headers.rawToken).getValue();
    var targetHeaders = askJaredColumnMap_(target.getRange(1, 1, 1, target.getLastColumn()).getValues()[0]);
    if (targetHeaders.rawToken) target.getRange(targetRow, targetHeaders.rawToken).setValue(token);
    if (targetHeaders.askLink) target.getRange(targetRow, targetHeaders.askLink).setValue(properties.getProperty('ASK_JARED_API_URL').replace(/\/$/, '') + '/ask?t=' + encodeURIComponent(token));
    return token;
  } finally {
    lock.releaseLock();
  }
}

function askJaredCountPool_(sheet, columns) {
  if (!columns.state || sheet.getLastRow() < 2) return 0;
  return sheet.getRange(2, columns.state, sheet.getLastRow() - 1, 1).getValues().filter(function(row) {
    return String(row[0]).toUpperCase() === 'AVAILABLE';
  }).length;
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
    claimId: find('Claimed External ID', 'External Tracker ID', 'Tracker/Application ID', 'Application ID'),
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
