const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('Backend/GoogleAppsScript/Code.gs', 'utf8');
const context = vm.createContext({});
vm.runInContext(`${source}
globalThis.parseForTest = parseRegistrationRequest;
globalThis.registrationKeyForTest = registrationKey;
globalThis.hasDuplicateForTest = hasDuplicateRegistration;
globalThis.nextDailyCountForTest = nextDailyRegistrationCount;`, context);

const validRegistration = {
  campus: '판교캠퍼스',
  classNumber: 3,
  name: ' 김  진수 ',
  appVersion: '0.3.0',
  consentVersion: '2026-07-30-v1'
};

function parse(body, type = 'application/json; charset=utf-8') {
  return context.parseForTest({type, contents: JSON.stringify(body)});
}

assert.equal(parse(validRegistration).ok, true);
assert.equal(parse(validRegistration).registration.name, '김 진수');
assert.equal(parse(validRegistration, 'text/plain').error, 'invalid_content_type');
assert.equal(context.parseForTest({type: 'application/json', contents: '{'}).error, 'invalid_json');
assert.equal(context.parseForTest({type: 'application/json', contents: 'x'.repeat(2049)}).error, 'payload_too_large');
assert.equal(parse({...validRegistration, campus: ['판교캠퍼스']}).error, 'invalid_campus');
assert.equal(parse({...validRegistration, classNumber: '3'}).error, 'invalid_class');
assert.equal(parse({...validRegistration, name: '=IMPORTXML'}).error, 'invalid_name');
assert.equal(parse({...validRegistration, appVersion: '=1+1'}).error, 'invalid_version');
assert.equal(parse({...validRegistration, consentVersion: 'old'}).error, 'invalid_consent');
assert.equal(parse({...validRegistration, unexpected: true}).error, 'invalid_request');
assert.equal(context.registrationKeyForTest('판교캠퍼스', 9, '김진수'), '판교캠퍼스\u00009반\u0000김진수');
const duplicateSheet = {
  getLastRow: () => 2,
  getRange: () => ({getDisplayValues: () => [['판교캠퍼스', '9반', '김진수']]})
};
assert.equal(context.hasDuplicateForTest(duplicateSheet, '판교캠퍼스', 9, '김진수'), true);
assert.equal(context.hasDuplicateForTest(duplicateSheet, '광주캠퍼스', 9, '김진수'), false);
assert.equal(context.nextDailyCountForTest(null, 500), 1);
assert.equal(context.nextDailyCountForTest('499', 500), 500);
assert.equal(context.nextDailyCountForTest('500', 500), null);
assert.equal(context.nextDailyCountForTest('broken', 500), null);

console.log('RESULT: 18/18 backend registration checks passed');
