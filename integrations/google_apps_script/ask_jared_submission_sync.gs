/**
 * Ask Jared workbook integration.
 *
 * Tracker contract (1-based columns): B Company, C Job Link/role, L Applied,
 * S Ask ID, T AskLink, U Ask Claim State, V Ask Sync State, W Ask Sync Message.
 * The raw bearer token is kept only in the protected Ask Token Pool tab; the
 * AskLink necessarily contains it as the recruiter-facing bearer URL.
 *
 * Required Script Properties (never put these in cells):
 *   ASK_JARED_API_URL
 *   ASK_JARED_SYNC_KEY
 *   ASK_JARED_TOKEN_POOL_SHEET
 *   ASK_JARED_POOL_API_KEY
 *   ASK_JARED_SHEET_NAMES
 */
var ASK_JARED_DEFAULT_TRACKER_SHEETS = ['Rapid Tracker', 'Target Tracker', 'Recruiter Tracker'];
var ASK_JARED_POOL_HEADERS = ['Inventory ID', 'Ask Token', 'State', 'Claimed Ask ID', 'Exported At'];
var ASK_JARED_COMPANY_COL = 2;
var ASK_JARED_ROLE_COL = 3;
var ASK_JARED_APPLIED_COL = 12;
var ASK_JARED_ASK_ID_COL = 19;
var ASK_JARED_ASK_LINK_COL = 20;
var ASK_JARED_CLAIM_STATE_COL = 21;
var ASK_JARED_SYNC_STATE_COL = 22;
var ASK_JARED_SYNC_MESSAGE_COL = 23;
var ASK_JARED_EXPORTED_UNCLAIMED_TTL_DAYS = 30;

function askJaredInstallableOnEdit(e) {
  if (!e || !e.range) return;
  var range = e.range;
  var sheet = range.getSheet();
  if (askJaredTrackerSheetNames_().indexOf(sheet.getName()) === -1) return;
  if (range.getRow() <= 1 || range.getColumn() > ASK_JARED_APPLIED_COL || range.getLastColumn() < ASK_JARED_APPLIED_COL) return;

  var lock = LockService.getDocumentLock();
  if (!lock.tryLock(5000)) return;
  try {
    for (var row = Math.max(2, range.getRow()); row <= range.getLastRow(); row++) {
      askJaredProcessAppliedRow_(sheet, row);
    }
  } finally {
    lock.releaseLock();
  }
}

// Google Sheets API writes do not fire onEdit. This short-interval processor
// completes the role-population queue without requiring ChatGPT to call HTTP.
function askJaredProcessPendingClaims() {
  var workbook = SpreadsheetApp.getActive();
  var lock = LockService.getDocumentLock();
  lock.waitLock(10000);
  try {
    var pool = askJaredPoolSheet_(workbook);
    askJaredReconcileOrphanedClaims_(pool, workbook);
    askJaredTrackerSheetNames_().forEach(function(sheetName) {
      var sheet = workbook.getSheetByName(sheetName);
      if (!sheet || sheet.getLastRow() < 2) return;
      var pendingRows = sheet.getRange(2, ASK_JARED_CLAIM_STATE_COL, sheet.getLastRow() - 1, 1).getValues();
      pendingRows.forEach(function(claimValues, offset) {
        var row = offset + 2;
        var claimState = String(claimValues[0] || '').trim().toUpperCase();
        if (claimState !== 'PENDING') return;
        var values = sheet.getRange(row, ASK_JARED_COMPANY_COL, 1, 2).getValues()[0];
        var identity = sheet.getRange(row, ASK_JARED_ASK_ID_COL, 1, 3).getValues()[0];
        var company = String(values[0] || '').trim();
        var role = String(values[1] || '').trim();
        var askId = String(identity[0] || '').trim();
        var askLink = String(identity[1] || '').trim();
        if (!company || !role || !askId || askLink) return;
        try {
          var token = askJaredClaimPoolToken_(pool, askId);
          var link = askJaredApiUrl_() + '/ask?t=' + encodeURIComponent(token);
          sheet.getRange(row, ASK_JARED_ASK_LINK_COL).setValue(link);
          sheet.getRange(row, ASK_JARED_CLAIM_STATE_COL).setValue('CLAIMED');
          askJaredWriteMessage_(sheet, row, 'Token claimed');
        } catch (error) {
          if (error.message === 'No AVAILABLE Ask token in pool') {
            askJaredWriteMessage_(sheet, row, 'Waiting for Ask token inventory');
          } else {
            sheet.getRange(row, ASK_JARED_CLAIM_STATE_COL).setValue('ERROR');
            askJaredWriteMessage_(sheet, row, 'Claim failed: ' + error.message);
          }
        }
      });
    });
  } finally {
    lock.releaseLock();
  }
}

// A role can be removed from an active tracker after it claimed a token. Keep
// that Sheet-side inventory usable, but only reconcile claims when every
// configured tracker is readable and the Ask ID is absent from all of them.
// A synced/submitted row remains in the active tracker and is therefore never
// released by this pass. Rails remains authoritative for submitted tokens.
function askJaredReconcileOrphanedClaims_(pool, workbook) {
  var activeAskIds = {};
  var trackerSheets = askJaredTrackerSheetNames_().map(function(sheetName) {
    return workbook.getSheetByName(sheetName);
  });
  if (trackerSheets.some(function(sheet) { return !sheet; })) return;

  trackerSheets.forEach(function(sheet) {
    if (sheet.getLastRow() < 2) return;
    var rows = sheet.getRange(2, ASK_JARED_ASK_ID_COL, sheet.getLastRow() - 1, 4).getValues();
    rows.forEach(function(values) {
      var askId = String(values[0] || '').trim();
      if (askId) activeAskIds[askId] = true;
    });
  });

  askJaredPoolRows_(pool).forEach(function(item) {
    if (item.state !== 'CLAIMED' || !item.claimedAskId || activeAskIds[item.claimedAskId]) return;
    pool.getRange(item.row, 3, 1, 2).setValues([['AVAILABLE', '']]);
  });
}

// Install daily. Rails returns raw tokens only in this authenticated response;
// they are written immediately to the protected internal pool tab.
function askJaredRefillTokenPool() {
  var workbook = SpreadsheetApp.getActive();
  var pool = askJaredPoolSheet_(workbook);
  var lock = LockService.getDocumentLock();
  lock.waitLock(10000);
  try {
    var poolRows = askJaredReconcileStaleAvailableRows_(pool);
    var availableRows = poolRows.filter(function(row) { return row.state === 'AVAILABLE'; });
    var available = availableRows.length;
    var claimedInventoryIds = poolRows.filter(function(row) { return row.state === 'CLAIMED'; }).map(function(row) { return row.inventoryId; });
    var response = UrlFetchApp.fetch(askJaredApiUrl_() + '/api/job_search/token_pool/refill', {
      method: 'post', contentType: 'application/json', muteHttpExceptions: true,
      headers: { 'X-Job-Search-Pool-Key': askJaredRequiredProperty_('ASK_JARED_POOL_API_KEY') },
      payload: JSON.stringify({ sheet_available_count: available, claimed_inventory_ids: claimedInventoryIds })
    });
    if (response.getResponseCode() < 200 || response.getResponseCode() >= 300) throw new Error('Token pool refill HTTP ' + response.getResponseCode());
    var tokens = JSON.parse(response.getContentText() || '{}').tokens || [];
    tokens.forEach(function(token) {
      pool.appendRow([token.inventory_id, token.token, token.state, '', new Date()]);
    });
  } finally {
    lock.releaseLock();
  }
}

// Legacy/manual helper retained for authorized Apps Script use. It never writes
// a raw token to a tracker row; the queue processor is preferred.
function askJaredClaimToken(externalId, targetSheetName, targetRow) {
  var workbook = SpreadsheetApp.getActive();
  var lock = LockService.getDocumentLock();
  lock.waitLock(10000);
  try {
    var target = workbook.getSheetByName(targetSheetName);
    var pool = askJaredPoolSheet_(workbook);
    if (!target) throw new Error('Target sheet is not configured');
    var token = askJaredClaimPoolToken_(pool, externalId);
    target.getRange(targetRow, ASK_JARED_ASK_LINK_COL).setValue(askJaredApiUrl_() + '/ask?t=' + encodeURIComponent(token));
    target.getRange(targetRow, ASK_JARED_CLAIM_STATE_COL).setValue('CLAIMED');
    return token;
  } finally {
    lock.releaseLock();
  }
}

function askJaredProcessAppliedRow_(sheet, row) {
  var appliedCell = sheet.getRange(row, ASK_JARED_APPLIED_COL);
  var display = String(appliedCell.getDisplayValue() || '').trim();
  var askId = String(sheet.getRange(row, ASK_JARED_ASK_ID_COL).getDisplayValue() || '').trim();
  if (askJaredIsSentinel_(display)) {
    askJaredReleaseClaimForSentinel_(sheet, row, askId);
    return;
  }
  if (!askJaredIsCalendarDate_(appliedCell.getValue(), display)) return;
  askJaredSubmitRow_(sheet, row, display, askId);
}

function askJaredSubmitRow_(sheet, row, submittedDisplay, askId) {
  var values = sheet.getRange(row, 1, 1, ASK_JARED_SYNC_MESSAGE_COL).getValues()[0];
  var syncState = String(values[ASK_JARED_SYNC_STATE_COL - 1] || '').trim().toUpperCase();
  if (syncState === 'SYNCED') return;
  var company = String(values[ASK_JARED_COMPANY_COL - 1] || '').trim();
  var role = String(values[ASK_JARED_ROLE_COL - 1] || '').trim();
  var askLink = String(values[ASK_JARED_ASK_LINK_COL - 1] || '').trim();
  var rawToken = askJaredTokenFromLink_(askLink);
  if (!askId || !company || !role || !rawToken) {
    askJaredWriteSync_(sheet, row, 'ERROR', 'Missing Ask ID, company, role, or AskLink');
    return;
  }
  var payload = {
    raw_token: rawToken, external_id: askId, company: company, role_title: role,
    tracker_source: sheet.getName(), submitted_at: askJaredDateForPayload_(sheet.getRange(row, ASK_JARED_APPLIED_COL).getValue(), submittedDisplay)
  };
  try {
    var response = UrlFetchApp.fetch(askJaredApiUrl_() + '/api/job_search/opportunities/submit', {
      method: 'post', contentType: 'application/json', muteHttpExceptions: true,
      headers: { 'X-Job-Search-Key': askJaredRequiredProperty_('ASK_JARED_SYNC_KEY'), 'Idempotency-Key': askId + ':' + payload.submitted_at },
      payload: JSON.stringify(payload)
    });
    var body = JSON.parse(response.getContentText() || '{}');
    if (response.getResponseCode() >= 200 && response.getResponseCode() < 300) {
      try {
        askJaredMarkPoolTokenSubmitted_(rawToken, askId);
      } catch (poolError) {
        // Rails accepted the submission. Never leave the Sheet-side row
        // AVAILABLE after that point; keep the tracker recoverable so a later
        // retry can reconcile the pool state without recycling the token.
        askJaredWriteSync_(sheet, row, 'ERROR', 'Rails accepted; pool state update required');
        return;
      }
      if (body.ask_link) sheet.getRange(row, ASK_JARED_ASK_LINK_COL).setValue(body.ask_link);
      askJaredWriteSync_(sheet, row, 'SYNCED', 'Submitted to Rails');
    } else {
      askJaredWriteSync_(sheet, row, 'ERROR', 'Rails returned HTTP ' + response.getResponseCode() + ': ' + (body.message || 'unknown error'));
    }
  } catch (error) {
    askJaredWriteSync_(sheet, row, 'ERROR', error.message);
  }
}

function askJaredMarkPoolTokenSubmitted_(rawToken, askId) {
  var pool = askJaredPoolSheet_(SpreadsheetApp.getActive());
  var match = askJaredPoolRows_(pool).filter(function(item) {
    return item.state === 'CLAIMED' && item.token === rawToken && item.claimedAskId === askId;
  })[0];
  if (!match) throw new Error('Claimed pool token not found');
  pool.getRange(match.row, 3).setValue('SUBMITTED');
}

function askJaredReleaseClaimForSentinel_(sheet, row, askId) {
  var syncState = String(sheet.getRange(row, ASK_JARED_SYNC_STATE_COL).getDisplayValue() || '').trim().toUpperCase();
  if (syncState === 'SYNCED' || syncState === 'ERROR') return; // fail safe
  var linkCell = sheet.getRange(row, ASK_JARED_ASK_LINK_COL);
  var token = askJaredTokenFromLink_(String(linkCell.getDisplayValue() || '').trim());
  if (!askId || !token) return;
  var pool = askJaredPoolSheet_(SpreadsheetApp.getActive());
  var rows = askJaredPoolRows_(pool);
  rows.forEach(function(item) {
    if (item.token === token && item.state === 'CLAIMED' && item.claimedAskId === askId) {
      pool.getRange(item.row, 3, 1, 2).setValues([['AVAILABLE', '']]);
      linkCell.clearContent();
      sheet.getRange(row, ASK_JARED_CLAIM_STATE_COL).clearContent();
      askJaredWriteMessage_(sheet, row, 'Ask token released for ignored role');
    }
  });
}

function askJaredClaimPoolToken_(pool, askId) {
  var rows = askJaredPoolRows_(pool);
  var existing = rows.filter(function(row) { return row.claimedAskId === askId && row.state === 'CLAIMED'; })[0];
  if (existing) return existing.token;
  var available = rows.filter(function(row) { return row.state === 'AVAILABLE'; })[0];
  if (!available) throw new Error('No AVAILABLE Ask token in pool');
  pool.getRange(available.row, 3, 1, 2).setValues([['CLAIMED', askId]]);
  return available.token;
}

function askJaredPoolRows_(pool) {
  if (pool.getLastRow() < 2) return [];
  return pool.getRange(2, 1, pool.getLastRow() - 1, 5).getValues().map(function(row, index) {
    return { row: index + 2, inventoryId: String(row[0] || '').trim(), token: String(row[1] || '').trim(), state: String(row[2] || '').trim().toUpperCase(), claimedAskId: String(row[3] || '').trim() };
  });
}

function askJaredReconcileStaleAvailableRows_(pool) {
  var cutoff = new Date(Date.now() - ASK_JARED_EXPORTED_UNCLAIMED_TTL_DAYS * 24 * 60 * 60 * 1000);
  var rows = askJaredPoolRows_(pool);
  rows.forEach(function(item) {
    var exportedAt = pool.getRange(item.row, 5).getValue();
    if (item.state === 'AVAILABLE' && Object.prototype.toString.call(exportedAt) === '[object Date]' && exportedAt < cutoff) {
      pool.getRange(item.row, 3).setValue('REVOKED');
      item.state = 'REVOKED';
    }
  });
  return rows;
}

function askJaredPoolSheet_(workbook) {
  var name = PropertiesService.getScriptProperties().getProperty('ASK_JARED_TOKEN_POOL_SHEET') || 'Ask Token Pool';
  var sheet = workbook.getSheetByName(name);
  if (!sheet) throw new Error('Token-pool sheet is not configured');
  return sheet;
}

function askJaredTrackerSheetNames_() {
  var configured = PropertiesService.getScriptProperties().getProperty('ASK_JARED_SHEET_NAMES');
  return (configured ? configured.split(',') : ASK_JARED_DEFAULT_TRACKER_SHEETS).map(function(name) { return name.trim(); }).filter(String);
}

function askJaredApiUrl_() { return askJaredRequiredProperty_('ASK_JARED_API_URL').replace(/\/$/, ''); }
function askJaredRequiredProperty_(name) {
  var value = PropertiesService.getScriptProperties().getProperty(name);
  if (!value) throw new Error('Missing Script Properties configuration: ' + name);
  return value;
}
function askJaredWriteSync_(sheet, row, state, message) {
  sheet.getRange(row, ASK_JARED_SYNC_STATE_COL).setValue(state);
  askJaredWriteMessage_(sheet, row, message);
}
function askJaredWriteMessage_(sheet, row, message) { sheet.getRange(row, ASK_JARED_SYNC_MESSAGE_COL).setValue(String(message || '').substring(0, 500)); }
function askJaredIsSentinel_(display) { return display === '8/88/88' || display === '9/99/99'; }
function askJaredIsCalendarDate_(value, display) { return !askJaredIsSentinel_(display) && Object.prototype.toString.call(value) === '[object Date]' && !isNaN(value.getTime()); }
function askJaredDateForPayload_(value, display) { return Object.prototype.toString.call(value) === '[object Date]' ? value.toISOString() : display; }
function askJaredTokenFromLink_(link) { var match = String(link || '').match(/[?&]t=([^&]+)/); return match ? decodeURIComponent(match[1]) : ''; }
