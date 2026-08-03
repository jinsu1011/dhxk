const ALLOWED_CAMPUSES = ['판교캠퍼스', '광주캠퍼스', '울산캠퍼스'];
const SHEET_NAME = '등록';
const MAX_DAILY_REGISTRATIONS = 500;

function doPost(e) {
  try {
    const parsed = parseRegistrationRequest(e && e.postData);
    if (!parsed.ok) return jsonResponse(false, parsed.error);
    const {campus, classNumber, name, appVersion, consentVersion} = parsed.registration;

    const lock = LockService.getScriptLock();
    lock.waitLock(5000);
    try {
      const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
      let sheet = spreadsheet.getSheetByName(SHEET_NAME);
      if (!sheet) sheet = spreadsheet.insertSheet(SHEET_NAME);
      if (sheet.getLastRow() === 0) {
        sheet.appendRow(['등록시각', '캠퍼스', '반', '이름', '앱버전', '동의문버전']);
        sheet.setFrozenRows(1);
      }
      if (hasDuplicateRegistration(sheet, campus, classNumber, name)) {
        return jsonResponse(true, 'already_registered');
      }
      if (!consumeDailyRegistrationSlot(new Date())) {
        return jsonResponse(false, 'daily_limit');
      }
      sheet.appendRow([new Date(), campus, classNumber + '반', name, appVersion, consentVersion]);
    } finally {
      lock.releaseLock();
    }
    return jsonResponse(true, '');
  } catch (error) {
    console.error('Registration failed: ' + error.name);
    return jsonResponse(false, 'server_error');
  }
}

function parseRegistrationRequest(postData) {
  if (!postData || typeof postData.contents !== 'string' || !postData.contents) {
    return {ok: false, error: 'invalid_request'};
  }
  const contentType = String(postData.type || '').split(';', 1)[0].trim().toLowerCase();
  if (contentType !== 'application/json') return {ok: false, error: 'invalid_content_type'};
  if (postData.contents.length > 2048) return {ok: false, error: 'payload_too_large'};

  let body;
  try {
    body = JSON.parse(postData.contents);
  } catch (_) {
    return {ok: false, error: 'invalid_json'};
  }
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return {ok: false, error: 'invalid_request'};
  }
  const allowedKeys = ['campus', 'classNumber', 'name', 'appVersion', 'consentVersion'];
  const bodyKeys = Object.keys(body);
  if (bodyKeys.length !== allowedKeys.length || bodyKeys.some(key => !allowedKeys.includes(key))) {
    return {ok: false, error: 'invalid_request'};
  }
  if (typeof body.campus !== 'string' || !ALLOWED_CAMPUSES.includes(body.campus)) {
    return {ok: false, error: 'invalid_campus'};
  }
  if (!Number.isInteger(body.classNumber) || body.classNumber < 1 || body.classNumber > 10) {
    return {ok: false, error: 'invalid_class'};
  }
  if (typeof body.name !== 'string') return {ok: false, error: 'invalid_name'};
  const name = body.name.trim().replace(/\s+/g, ' ');
  if (!/^[가-힣A-Za-z ]{2,30}$/.test(name)) return {ok: false, error: 'invalid_name'};
  if (typeof body.appVersion !== 'string' || !/^[0-9A-Za-z.-]{1,30}$/.test(body.appVersion)) {
    return {ok: false, error: 'invalid_version'};
  }
  if (body.consentVersion !== '2026-07-30-v1') {
    return {ok: false, error: 'invalid_consent'};
  }
  return {
    ok: true,
    registration: {
      campus: body.campus,
      classNumber: body.classNumber,
      name: name,
      appVersion: body.appVersion,
      consentVersion: body.consentVersion
    }
  };
}

function registrationKey(campus, classNumber, name) {
  return [String(campus), String(classNumber) + '반', String(name)].join('\u0000');
}

function hasDuplicateRegistration(sheet, campus, classNumber, name) {
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return false;
  const rows = sheet.getRange(2, 2, lastRow - 1, 3).getDisplayValues();
  const expected = registrationKey(campus, classNumber, name);
  return rows.some(row => registrationKey(row[0], String(row[1]).replace(/반$/, ''), row[2]) === expected);
}

function nextDailyRegistrationCount(currentValue, limit) {
  const current = currentValue === null || currentValue === '' ? 0 : Number(currentValue);
  if (!Number.isInteger(current) || current < 0 || current >= limit) return null;
  return current + 1;
}

function consumeDailyRegistrationSlot(now) {
  const properties = PropertiesService.getScriptProperties();
  const dateKey = Utilities.formatDate(now, Session.getScriptTimeZone(), 'yyyyMMdd');
  const propertyKey = 'registration_count_' + dateKey;
  const next = nextDailyRegistrationCount(properties.getProperty(propertyKey), MAX_DAILY_REGISTRATIONS);
  if (next === null) return false;
  properties.setProperty(propertyKey, String(next));
  return true;
}

function jsonResponse(ok, error) {
  return ContentService.createTextOutput(JSON.stringify({ok: ok, error: error}))
    .setMimeType(ContentService.MimeType.JSON);
}
