// Unit & HTTP integration tests for server/src/events.mjs (P106).
// Compatible with both `node --test server/src/events.test.mjs` and `node server/src/events.test.mjs`.

import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import {
  EV_VER,
  EVENTS_SCHEMA,
  EventsReceiver,
  createEventsServer,
  pseudonymizeUid,
  validateEvent,
} from './events.mjs';

const SECRET = 'test-ru-hmac-secret-0123456789abcdef';

function makeEvent(event, params, overrides = {}) {
  return {
    event,
    ts: 1764300000000,
    uid: 'raw_player_account_42',
    sess: 'sess_test_1',
    app_ver: '0.12.0',
    build: 'rustore',
    lang: 'ru',
    tier: 'standard',
    age_ok: true,
    conn: 'wifi',
    ev_ver: EV_VER,
    params,
    ...overrides,
  };
}

test('schema: validates all MP §7.4 events and rejects invalid/unknown events', () => {
  assert.ok(Object.keys(EVENTS_SCHEMA).length >= 45);
  const ok = validateEvent(makeEvent('purchase_ok', {
    sku_id: 'jade_pass_199',
    price_rub: 199,
    method: 'sbp',
    purchase_id: 'ord_001',
  }));
  assert.equal(ok.ok, true, JSON.stringify(ok.errors));

  const badName = validateEvent(makeEvent('UnknownEvent', {}));
  assert.equal(badName.ok, false);
  assert.ok(badName.errors.some((e) => e.startsWith('BAD_EVENT_NAME')));

  const badEnum = validateEvent(makeEvent('purchase_ok', {
    sku_id: 'jade_pass_199',
    price_rub: 199,
    method: 'cash',
    purchase_id: 'ord_002',
  }));
  assert.equal(badEnum.ok, false);
  assert.ok(badEnum.errors.some((e) => e.startsWith('BAD_ENUM')));
});

test('privacy & ethics: rejects PII, exact birth date, rank_up RUB, and spend-profile discounts', () => {
  const piiEmail = validateEvent(makeEvent('app_open', { src: 'organic', email: 'a@b.ru' }));
  assert.equal(piiEmail.ok, false);
  assert.ok(piiEmail.errors.includes('PII_FORBIDDEN:params.email'));

  const piiDate = validateEvent(makeEvent('age_gate_result', {
    ok: true,
    birth_year_bucket: '1994-03-11',
    tier_toggle: 'standard',
  }));
  assert.equal(piiDate.ok, false);
  assert.ok(piiDate.errors.includes('PII_EXACT_BIRTH_DATE:age_gate_result.birth_year_bucket'));

  const rankRub = validateEvent(makeEvent('rank_up', { from: 1, to: 2, spent_rub: 10000 }));
  assert.equal(rankRub.ok, false);
  assert.ok(rankRub.errors.includes('FORBIDDEN_PARAM:rank_up.spent_rub'));

  const disc = validateEvent(makeEvent('sku_view', {
    section: 'packs',
    sku_id: 'pack_990',
    price_rub: 990,
    wishes_equiv: 25,
    personal_discount: 15,
  }));
  assert.equal(disc.ok, false);
  assert.ok(disc.errors.includes('ETHICS_FORBIDDEN:params.personal_discount'));
});

test('receiver: HMAC pseudonymizes uid (raw uid never stored) and honors 152-FZ consent/erasure', () => {
  const db = new DatabaseSync(':memory:');
  const rx = new EventsReceiver({ db, hmacSecret: SECRET, region: 'RU' });
  const rawUid = 'raw_secret_account_999';
  const expectedHmac = pseudonymizeUid(rawUid, SECRET);
  assert.match(expectedHmac, /^u_[0-9a-f]{32}$/);
  assert.notEqual(expectedHmac, rawUid);

  const r1 = rx.ingestBatch([
    makeEvent('app_open', { src: 'organic' }, { uid: rawUid }),
    makeEvent('session_start', { src: 'organic' }, { uid: rawUid, ts: 1764300005000 }),
    makeEvent('app_open', { src: 'organic', nick: 'ShouldReject' }, { uid: rawUid }),
  ]);
  assert.equal(r1.accepted, 2);
  assert.equal(r1.rejected, 1);
  assert.equal(r1.region, 'RU');

  const stored = rx.exportEvents();
  assert.equal(stored.length, 2);
  for (const row of stored) {
    assert.equal(row.uid, expectedHmac);
    assert.ok(!JSON.stringify(row).includes(rawUid));
  }

  // Revoke consent with erasure (152-FZ)
  const cRes = rx.setConsent(rawUid, false, { erase: true });
  assert.equal(cRes.erased, 2);
  assert.equal(rx.exportEvents().length, 0);

  // Subsequent events for opted-out user are dropped
  const r2 = rx.ingestBatch([makeEvent('app_open', { src: 'organic' }, { uid: rawUid })]);
  assert.equal(r2.accepted, 0);
  assert.equal(r2.dropped_no_consent, 1);
  db.close();
});

test('HTTP server: POST /api/v1/events, /events/consent, GET /events/health', async () => {
  const db = new DatabaseSync(':memory:');
  const srv = await createEventsServer({ db, hmacSecret: SECRET, region: 'RU' });
  const base = `http://127.0.0.1:${srv.port}`;
  try {
    const h0 = await fetch(`${base}/api/v1/events/health`).then((r) => r.json());
    assert.equal(h0.ok, true);
    assert.equal(h0.region, 'RU');
    assert.equal(h0.pii_guard, true);
    assert.equal(h0.personalized_discounts_allowed, false);

    // Valid batch
    const resp = await fetch(`${base}/api/v1/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        consent: true,
        events: [
          makeEvent('ftue_step', { step: 'first_win', t_s: 38 }),
          makeEvent('wish_pull', {
            banner_id: 'first_guest', family: 'standard', idx: 1,
            k_before: 29, g_before: 0, c_before: 0,
            result: 'ssr', item_id: 'akari_silk', featured: true, candle: false,
            cost_cur: 'gems', cost_amt: 150, odds_hash: 'h1', seed_commit: 'c1',
          }),
        ],
      }),
    });
    assert.equal(resp.status, 200);
    const body = await resp.json();
    assert.equal(body.accepted, 2);
    assert.equal(body.rejected, 0);

    // Pure-PII batch returns 400
    const badResp = await fetch(`${base}/api/v1/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        events: [makeEvent('app_open', { src: 'x', email: 'leak@test.ru' })],
      }),
    });
    assert.equal(badResp.status, 400);

    // Consent endpoint
    const cResp = await fetch(`${base}/api/v1/events/consent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ uid: 'raw_player_account_42', analytics_consent: false, erase: true }),
    });
    assert.equal(cResp.status, 200);
    const cBody = await cResp.json();
    assert.equal(cBody.erased, 2);

    const h1 = await fetch(`${base}/api/v1/events/health`).then((r) => r.json());
    assert.equal(h1.stored_events, 0);
  } finally {
    await srv.close();
    db.close();
  }
});
