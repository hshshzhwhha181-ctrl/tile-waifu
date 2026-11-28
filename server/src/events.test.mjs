// Unit & HTTP integration tests for server/src/events.mjs (P106).
// Compatible with both `node --test server/src/events.test.mjs` and `node server/src/events.test.mjs`.

import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import {
  EV_VER,
  EVENTS_SCHEMA,
  EventsReceiver,
  createEventsServer,
  pseudonymizeUid,
  validateEvent,
} from './events.mjs';
import { RateLimiter } from './util.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
// Ephemeral per-run secret — zero hardcoded secrets in tests
const SECRET = randomBytes(32).toString('hex');

function makeEvent(event, params, overrides = {}) {
  return {
    event,
    ts: Date.now() - 1000,
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

  // Opt-in consent must be granted first (152-FZ)
  rx.setConsent(rawUid, true);

  const r1 = rx.ingestBatch([
    makeEvent('app_open', { src: 'organic' }, { uid: rawUid }),
    makeEvent('session_start', { src: 'organic' }, { uid: rawUid, ts: Date.now() - 500 }),
    makeEvent('app_open', { src: 'organic', nick: 'ShouldReject' }, { uid: rawUid }),
  ], { consent: true });
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
  const r2 = rx.ingestBatch([makeEvent('app_open', { src: 'organic' }, { uid: rawUid })], { consent: true });
  assert.equal(r2.accepted, 0);
  assert.equal(r2.dropped_no_consent, 1);
  db.close();
});

test('HTTP server: POST /api/v1/events, /events/consent, GET /events/health', async () => {
  const db = new DatabaseSync(':memory:');
  const playerToken = randomBytes(16).toString('hex');
  const srv = await createEventsServer({
    db,
    hmacSecret: SECRET,
    region: 'RU',
    authenticate: (req) => (req.headers.authorization === `Bearer ${playerToken}` ? 'raw_player_account_42' : null),
  });
  const base = `http://127.0.0.1:${srv.port}`;
  try {
    const h0 = await fetch(`${base}/api/v1/events/health`).then((r) => r.json());
    assert.equal(h0.ok, true);
    assert.equal(h0.region, 'RU');
    assert.equal(h0.pii_guard, true);
    assert.equal(h0.personalized_discounts_allowed, false);

    // Grant opt-in consent first (authenticated)
    const gResp = await fetch(`${base}/api/v1/events/consent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${playerToken}` },
      body: JSON.stringify({ uid: 'raw_player_account_42', analytics_consent: true }),
    });
    assert.equal(gResp.status, 200);

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
        consent: true,
        events: [makeEvent('app_open', { src: 'x', email: 'leak@test.ru' })],
      }),
    });
    assert.equal(badResp.status, 400);

    // Consent endpoint (authenticated)
    const cResp = await fetch(`${base}/api/v1/events/consent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${playerToken}` },
      body: JSON.stringify({ uid: 'raw_player_account_42', analytics_consent: false, erase: true }),
    });
    assert.equal(cResp.status, 200);
    const cBody = await cResp.json();
    assert.equal(cBody.erased, 2);
    assert.equal('uid_hmac' in cBody, false);

    const h1 = await fetch(`${base}/api/v1/events/health`).then((r) => r.json());
    assert.equal(h1.stored_events, 0);
  } finally {
    await srv.close();
    db.close();
  }
});

test('MAJOR #1: fails closed without ANALYTICS_HMAC_SECRET and has no hardcoded secret fallback', () => {
  const src = readFileSync(join(HERE, 'events.mjs'), 'utf8');
  assert.ok(!src.includes('dev-ru-analytics-hmac-secret-change-me'), 'hardcoded fallback secret must be removed');

  const prev = process.env.ANALYTICS_HMAC_SECRET;
  delete process.env.ANALYTICS_HMAC_SECRET;
  const db = new DatabaseSync(':memory:');
  try {
    assert.throws(() => new EventsReceiver({ db }), /ANALYTICS_HMAC_SECRET/i);
    assert.throws(() => new EventsReceiver({ db, hmacSecret: 'too-short' }), /ANALYTICS_HMAC_SECRET/i);
    // Setting ephemeral env var succeeds
    process.env.ANALYTICS_HMAC_SECRET = randomBytes(32).toString('hex');
    const rx = new EventsReceiver({ db });
    assert.ok(rx);
  } finally {
    if (prev !== undefined) process.env.ANALYTICS_HMAC_SECRET = prev;
    else delete process.env.ANALYTICS_HMAC_SECRET;
    db.close();
  }
});

test('MAJOR #1: consent endpoint requires auth, blocks cross-user wipe, hides uid_hmac oracle, ignores spoofed X-Forwarded-For', async () => {
  const db = new DatabaseSync(':memory:');
  const tokenMap = new Map([
    [randomBytes(16).toString('hex'), 'user_alice'],
    [randomBytes(16).toString('hex'), 'user_bob'],
  ]);
  const [[aliceToken], [bobToken]] = [...tokenMap.entries()];
  const authenticate = (req) => {
    const m = /^Bearer\s+(\S+)$/i.exec(String(req.headers.authorization || ''));
    return m ? (tokenMap.get(m[1]) || null) : null;
  };

  const prevTrust = process.env.TRUST_PROXY;
  delete process.env.TRUST_PROXY;
  const srv = await createEventsServer({
    db,
    hmacSecret: SECRET,
    region: 'RU',
    rateLimitPerMin: 5,
    authenticate,
  });
  const base = `http://127.0.0.1:${srv.port}`;
  try {
    // 1. Unauthenticated consent POST must be rejected with 401 and insert 0 rows
    const unauth = await fetch(`${base}/api/v1/events/consent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ uid: 'user_alice', analytics_consent: false, erase: true }),
    });
    assert.equal(unauth.status, 401);
    const rowsAfterUnauth = db.prepare('SELECT COUNT(*) AS n FROM analytics_consent').get().n;
    assert.equal(Number(rowsAfterUnauth), 0);

    // 2. Cross-user consent POST (Bob trying to wipe Alice) must be rejected with 403
    const cross = await fetch(`${base}/api/v1/events/consent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${bobToken}` },
      body: JSON.stringify({ uid: 'user_alice', analytics_consent: false, erase: true }),
    });
    assert.equal(cross.status, 403);

    // 3. Authenticated consent POST succeeds and does NOT leak uid_hmac oracle
    const okResp = await fetch(`${base}/api/v1/events/consent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${aliceToken}` },
      body: JSON.stringify({ analytics_consent: true }),
    });
    assert.equal(okResp.status, 200);
    const okBody = await okResp.json();
    assert.equal(okBody.ok, true);
    assert.equal(okBody.analytics_consent, true);
    assert.equal('uid_hmac' in okBody, false, 'response must not expose uid_hmac oracle');

    // 4. Spoofed X-Forwarded-For headers must NOT bypass per-IP rate limiting (limit=5, 3 already used)
    const statuses = [];
    for (let i = 0; i < 4; i++) {
      const r = await fetch(`${base}/api/v1/events/health`, {
        headers: { 'X-Forwarded-For': `203.0.113.${i + 10}` },
      });
      statuses.push(r.status);
    }
    assert.ok(statuses.includes(429), `expected 429 despite spoofed X-Forwarded-For, got ${JSON.stringify(statuses)}`);

    // 5. RateLimiter map size is strictly bounded
    const lim = new RateLimiter(10, 60000, 50);
    for (let i = 0; i < 200; i++) lim.hit(`ip_${i}`);
    assert.ok(lim.map.size <= 50, `RateLimiter map exceeded cap: ${lim.map.size}`);
  } finally {
    if (prevTrust !== undefined) process.env.TRUST_PROXY = prevTrust;
    else delete process.env.TRUST_PROXY;
    await srv.close();
    db.close();
  }
});

test('MAJOR #2: ts=1e16 does not poison batch, prototype names rejected, array/normalized PII caught, param types/lengths & retention enforced', () => {
  const nowSec = Math.floor(1764300000000 / 1000);
  const nowMs = nowSec * 1000;

  // (a) ts=1e16 must not poison valid siblings in the same batch
  const db = new DatabaseSync(':memory:');
  const rx = new EventsReceiver({ db, hmacSecret: SECRET, region: 'RU', retentionDays: 30 });
  rx.setConsent('raw_player_account_42', true);
  const rBatch = rx.ingestBatch([
    makeEvent('app_open', { src: 'organic' }, { ts: nowMs - 2000 }),
    makeEvent('app_open', { src: 'organic' }, { ts: 1e16 }),
    makeEvent('session_start', { src: 'organic' }, { ts: nowMs - 1000 }),
  ], { consent: true, nowSec });
  assert.equal(rBatch.accepted, 2, 'valid events must not be rolled back by ts=1e16 sibling');
  assert.equal(rBatch.rejected, 1);
  assert.equal(rx.exportEvents().length, 2);

  // (b) Prototype property names like constructor/valueOf must be rejected via Object.hasOwn
  const protoRes = validateEvent(makeEvent('constructor', { x: 1 }), { nowMs });
  assert.equal(protoRes.ok, false);
  assert.ok(protoRes.errors.includes('UNKNOWN_EVENT:constructor'), JSON.stringify(protoRes.errors));

  // (c) scanForbidden must descend into Arrays and catch normalized PII keys
  const arrObj = validateEvent(makeEvent('app_open', { src: 'organic', list: [{ email: 'a@b.ru' }] }), { nowMs });
  assert.equal(arrObj.ok, false, 'email key inside array object must be rejected');
  const arrStr = validateEvent(makeEvent('app_open', { src: 'organic', nested: ['x@y.com'] }), { nowMs });
  assert.equal(arrStr.ok, false, 'email literal inside array must be rejected');
  const normPii = validateEvent(makeEvent('app_open', {
    src: 'organic',
    'E-Mail': 'not-an-email',
    deviceid: 'dev123',
    Email_Address: 'none',
  }), { nowMs });
  assert.equal(normPii.ok, false, 'normalized PII keys E-Mail/deviceid/Email_Address must be rejected');
  assert.ok(normPii.errors.filter((e) => e.startsWith('PII_FORBIDDEN:')).length >= 3, JSON.stringify(normPii.errors));

  // (d) Param type and length checks
  const badPrice = validateEvent(makeEvent('purchase_ok', {
    sku_id: 'jade_pass_199', price_rub: 'abc', method: 'sbp', purchase_id: 'ord_bad_price',
  }), { nowMs });
  assert.equal(badPrice.ok, false, 'non-numeric price_rub must be rejected');

  const hugePid = validateEvent(makeEvent('purchase_ok', {
    sku_id: 'jade_pass_199', price_rub: 199, method: 'sbp', purchase_id: 'x'.repeat(100_000),
  }), { nowMs });
  assert.equal(hugePid.ok, false, '100 kB purchase_id must be rejected');

  // (e) ts skew (future > 10 min) and retention (older than 30 days)
  const futureEv = validateEvent(makeEvent('app_open', { src: 'organic' }, { ts: nowMs + 3600_000 }), { nowMs });
  assert.equal(futureEv.ok, false, 'far-future ts must be rejected');
  const oldEv = validateEvent(makeEvent('app_open', { src: 'organic' }, { ts: nowMs - 40 * 86400_000 }), { nowMs, retentionDays: 30 });
  assert.equal(oldEv.ok, false, 'ts older than retentionDays must be rejected');

  // Retention pruning deletes aged rows
  const pruned = rx.pruneExpired(nowSec + 35 * 86400);
  assert.equal(pruned, 2, 'pruneExpired should delete rows older than retentionDays');
  assert.equal(rx.exportEvents().length, 0);
  db.close();
});

test('MAJOR #3: server consent is strict opt-in (fail closed), replays dedup by event_id, client purchase_ok rejected', async () => {
  const db = new DatabaseSync(':memory:');
  const serverToken = randomBytes(24).toString('hex');
  const playerToken = randomBytes(16).toString('hex');
  const uid = 'optin_player_77';
  const srv = await createEventsServer({
    db,
    hmacSecret: SECRET,
    region: 'RU',
    serverIngestToken: serverToken,
    authenticate: (req) => (req.headers.authorization === `Bearer ${playerToken}` ? uid : null),
  });
  const base = `http://127.0.0.1:${srv.port}`;
  try {
    // 1. User has NO consent row yet -> events MUST be dropped (fail-closed opt-in)
    const rNoRow = await fetch(`${base}/api/v1/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        consent: true,
        events: [makeEvent('app_open', { src: 'organic' }, { uid, event_id: 'ev_1' })],
      }),
    }).then((r) => r.json());
    assert.equal(rNoRow.accepted, 0, 'user without consent row must not have events stored');
    assert.equal(rNoRow.dropped_no_consent, 1);

    // 2. Grant consent via authenticated endpoint
    const grantResp = await fetch(`${base}/api/v1/events/consent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${playerToken}` },
      body: JSON.stringify({ analytics_consent: true }),
    });
    assert.equal(grantResp.status, 200);

    // 3. Omitting `consent` in POST /api/v1/events body MUST default to false (fail closed)
    const rOmit = await fetch(`${base}/api/v1/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        events: [makeEvent('app_open', { src: 'organic' }, { uid, event_id: 'ev_omit' })],
      }),
    }).then((r) => r.json());
    assert.equal(rOmit.accepted, 0, 'omitted consent flag must default to false');
    assert.equal(rOmit.dropped_no_consent, 1);

    // 4. Replay dedup by event_id across batches
    const ev1 = makeEvent('app_open', { src: 'organic' }, { uid, event_id: 'ev_dedup_01' });
    const first = await fetch(`${base}/api/v1/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ consent: true, events: [ev1] }),
    }).then((r) => r.json());
    assert.equal(first.accepted, 1);

    const replay = await fetch(`${base}/api/v1/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ consent: true, events: [ev1] }),
    }).then((r) => r.json());
    assert.equal(replay.accepted, 0, 'replayed event_id must be deduplicated');
    assert.equal(replay.deduplicated, 1);

    // 5. Client-submitted purchase_ok MUST be rejected (unforgeable revenue)
    const forgedPurchase = makeEvent('purchase_ok', {
      sku_id: 'pack_9990', price_rub: 999999, method: 'sbp', purchase_id: 'forged_1',
    }, { uid, event_id: 'ev_forged_1' });
    const clientPurch = await fetch(`${base}/api/v1/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ consent: true, events: [forgedPurchase] }),
    });
    assert.equal(clientPurch.status, 400, 'client purchase_ok must be rejected with 400');
    const cpBody = await clientPurch.json();
    assert.equal(cpBody.accepted, 0);
    assert.equal(cpBody.rejected, 1);

    // 6. Server-authenticated purchase_ok IS accepted, tagged source='server', and deduped
    const realPurchase = makeEvent('purchase_ok', {
      sku_id: 'jade_pass_199', price_rub: 199, method: 'sbp', purchase_id: 'srv_ord_01',
    }, { uid, event_id: 'ev_srv_1' });
    const srvPurch = await fetch(`${base}/api/v1/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Server-Ingest-Token': serverToken },
      body: JSON.stringify({ consent: true, events: [realPurchase] }),
    });
    assert.equal(srvPurch.status, 200);
    const spBody = await srvPurch.json();
    assert.equal(spBody.accepted, 1);

    const exported = srv.receiver.exportEvents();
    const pRow = exported.find((e) => e.event === 'purchase_ok');
    assert.ok(pRow);
    assert.equal(pRow.source, 'server');
  } finally {
    await srv.close();
    db.close();
  }
});
