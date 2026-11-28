// Tile Waifu P106 — First-party Russian analytics event receiver (MONETIZATION_PLAN.md §7.4).
// Zero npm dependencies: node:crypto + node:sqlite + node:http.
// Privacy (152-FZ):
//   - Server-side HMAC-SHA256 pseudonymization of `uid` (raw uid is never persisted).
//   - Hard rejection of PII keys (birth_date, nick, email, phone, IP, raw device IDs) and email literals.
//   - Hard rejection of spend-profile personalized discount / dynamic pricing fields.
//   - Separate consent toggle endpoint with opt-out and data erasure by pseudonymized uid.

import { createHmac } from 'node:crypto';
import { createServer } from 'node:http';
import { ApiError, CORS_HEADERS, RateLimiter, clientIp, readJson, sendError, sendJson } from './util.mjs';

export const EV_VER = 1;
export const MAX_BATCH_SIZE = 200;

export const ENVELOPE_REQUIRED = Object.freeze([
  'event', 'ts', 'uid', 'sess', 'app_ver', 'build', 'lang', 'tier', 'age_ok', 'conn', 'ev_ver',
]);

export const ALLOWED_TIERS = new Set(['neutral', 'standard', 'full']);
export const ALLOWED_CONNS = new Set(['wifi', 'mobile', 'offline']);
export const ALLOWED_BUILDS = new Set(['rustore', 'dev', 'staging']);
export const ALLOWED_PROVIDERS = new Set(['vk', 'yandex', 'email']);
export const ALLOWED_PAY_FROM = new Set(['ticket', 'gems', 'moon']);
export const ALLOWED_WISH_RESULTS = new Set(['gift', 's', 'ssr']);
export const ALLOWED_PAY_METHODS = new Set(['sbp', 'card', 'sberpay']);
export const ALLOWED_PASS_LINES = new Set(['free', 'prem', 'lux']);
export const ALLOWED_ULT_VARIANTS = new Set(['short', 'full', 'director']);

export const FORBIDDEN_PII_KEYS = new Set([
  'birth_date', 'birthdate', 'dob', 'birthday', 'birth_day',
  'email', 'e_mail', 'nick', 'nickname', 'username', 'full_name', 'real_name',
  'phone', 'phone_number', 'ip', 'ip_address',
  'device_id', 'imei', 'idfa', 'gaid', 'advertising_id', 'passport', 'card_number',
]);

export const FORBIDDEN_ETHICS_KEYS = new Set([
  'personal_discount', 'personalized_discount', 'spend_profile_discount', 'spend_profile_offer',
  'whale_discount', 'whale_offer', 'whale_nudge',
  'dynamic_price', 'dynamic_price_rub', 'targeted_price_rub', 'nudge_tier', 'p2w_bonus',
]);

export const EVENTS_SCHEMA = Object.freeze({
  app_open: { req: ['src'] },
  session_start: { req: ['src'] },
  session_end: { req: ['dur_s'] },
  age_gate_result: { req: ['ok', 'birth_year_bucket', 'tier_toggle'] },
  account_link: { req: ['provider'], enums: { provider: ALLOWED_PROVIDERS } },
  ftue_step: { req: ['step', 't_s'] },
  level_end: { req: ['mode', 'level', 'win', 'dur_s', 'pairs'] },
  wish_banner_view: { req: ['banner_id', 'family', 'k', 'g', 'c'] },
  odds_open: { req: ['banner_id', 'odds_hash'] },
  history_open: { req: ['banner_id', 'odds_hash'] },
  preview_open: { req: ['skin_id', 'from'] },
  wish_confirm_open: { req: ['banner_id', 'n', 'cost', 'pay_from', 'limit_left'], enums: { pay_from: ALLOWED_PAY_FROM } },
  wish_pull: {
    req: [
      'banner_id', 'family', 'idx', 'k_before', 'g_before', 'c_before',
      'result', 'item_id', 'featured', 'candle', 'cost_cur', 'cost_amt', 'odds_hash', 'seed_commit',
    ],
    enums: { result: ALLOWED_WISH_RESULTS },
  },
  wish_series_end: { req: ['n', 'ssr_count', 'spent_rub_equiv'] },
  store_open: { req: ['section'] },
  sku_view: { req: ['section', 'sku_id', 'price_rub', 'wishes_equiv'] },
  purchase_start: { req: ['sku_id', 'price_rub', 'method', 'purchase_id'], enums: { method: ALLOWED_PAY_METHODS } },
  purchase_ok: { req: ['sku_id', 'price_rub', 'method', 'purchase_id'], enums: { method: ALLOWED_PAY_METHODS } },
  purchase_fail: { req: ['sku_id', 'price_rub', 'method', 'purchase_id', 'err'], enums: { method: ALLOWED_PAY_METHODS } },
  purchase_cancel: { req: ['sku_id', 'price_rub', 'method', 'purchase_id'], enums: { method: ALLOWED_PAY_METHODS } },
  purchase_pending: { req: ['sku_id', 'price_rub', 'method', 'purchase_id'], enums: { method: ALLOWED_PAY_METHODS } },
  purchase_refund: { req: ['sku_id', 'amount', 'debt_after', 'days_since'] },
  moon_balance_audit: { req: ['ok', 'delta'] },
  limit_choice_shown: { req: ['type'] },
  limit_set: { req: ['value', 'prev', 'type'] },
  limit_hit: { req: ['value', 'type'] },
  pause_set: { req: ['value', 'type'] },
  cooldown_prompt: { req: ['type'] },
  cooldown_accept: { req: ['type'] },
  rank_up: { req: ['from', 'to'], forbid: ['rub', 'price_rub', 'spent_rub', 'spend_rub', 'amount_rub'] },
  pass_view: { req: ['season'] },
  pass_buy: { req: ['season', 'line'], enums: { line: ALLOWED_PASS_LINES } },
  pass_step_claim: { req: ['season', 'line', 'step'], enums: { line: ALLOWED_PASS_LINES } },
  fund_buy: { req: ['fund_id'] },
  fund_claim: { req: ['fund_id', 'milestone'] },
  skin_equip: { req: ['skin_id', 'tier', 'hud_level'] },
  skin_dye: { req: ['skin_id', 'tier'] },
  star_up: { req: ['skin_id', 'star'] },
  ult_play: { req: ['skin_id', 'variant'], enums: { variant: ALLOWED_ULT_VARIANTS } },
  direct_sale_open: { req: ['skin_id', 'day'] },
  bond_level_up: { req: ['hero', 'lv'] },
  ad_offer: { req: ['placement'] },
  ad_watch: { req: ['placement'] },
  ad_reward: { req: ['placement', 'ecpm_bucket'] },
  ad_complaint: { req: ['placement'] },
  event_shop_buy: { req: ['event_id', 'cur', 'amt'] },
  event_points: { req: ['event_id', 'cur', 'amt'] },
  econ_snapshot: { req: ['gems', 'tickets', 'moon', 'petals', 'coins'] },
  crash: { req: ['stack_hash'] },
  anr: { req: ['stack_hash'] },
});

const SNAKE_RE = /^[a-z][a-z0-9_]*$/;
const EXACT_DATE_RE = /^(?:\d{4}[-/.]\d{2}[-/.]\d{2}|\d{2}[-/.]\d{2}[-/.]\d{4})$/;
const EMAIL_VALUE_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const EVENTS_SQL = `
CREATE TABLE IF NOT EXISTS analytics_events (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  event_name  TEXT    NOT NULL,
  ts_ms       INTEGER NOT NULL,
  day_utc     TEXT    NOT NULL,
  uid_hmac    TEXT    NOT NULL,
  sess        TEXT    NOT NULL,
  app_ver     TEXT    NOT NULL,
  build       TEXT    NOT NULL,
  lang        TEXT    NOT NULL,
  tier        TEXT    NOT NULL,
  age_ok      INTEGER NOT NULL,
  conn        TEXT    NOT NULL,
  ev_ver      INTEGER NOT NULL,
  params_json TEXT    NOT NULL,
  ingested_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ev_name_ts ON analytics_events(event_name, ts_ms);
CREATE INDEX IF NOT EXISTS idx_ev_uid_ts  ON analytics_events(uid_hmac, ts_ms);
CREATE INDEX IF NOT EXISTS idx_ev_day     ON analytics_events(day_utc);

CREATE TABLE IF NOT EXISTS analytics_consent (
  uid_hmac          TEXT    PRIMARY KEY,
  analytics_consent INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL
);
`;

export function initEventsSchema(db) {
  db.exec(EVENTS_SQL);
}

/** Deterministic server-side HMAC pseudonymization (MP §7.4). */
export function pseudonymizeUid(rawUid, hmacSecret) {
  if (!hmacSecret || typeof hmacSecret !== 'string' || hmacSecret.length < 16) {
    throw new Error('ANALYTICS_HMAC_SECRET must be a string of at least 16 chars');
  }
  const digest = createHmac('sha256', hmacSecret).update(String(rawUid)).digest('hex').slice(0, 32);
  return `u_${digest}`;
}

function scanForbidden(obj, prefix, errors) {
  for (const [rawKey, val] of Object.entries(obj)) {
    const k = String(rawKey).toLowerCase();
    const full = prefix ? `${prefix}.${k}` : k;
    if (FORBIDDEN_PII_KEYS.has(k)) {
      errors.push(`PII_FORBIDDEN:${full}`);
    } else if (FORBIDDEN_ETHICS_KEYS.has(k)) {
      errors.push(`ETHICS_FORBIDDEN:${full}`);
    }
    if (val && typeof val === 'object' && !Array.isArray(val)) {
      scanForbidden(val, full, errors);
    } else if (typeof val === 'string' && k !== 'stack_hash' && EMAIL_VALUE_RE.test(val.trim())) {
      errors.push(`PII_EMAIL_VALUE:${full}`);
    }
  }
}

export function validateEvent(ev) {
  const errors = [];
  if (!ev || typeof ev !== 'object' || Array.isArray(ev)) {
    return { ok: false, errors: ['NOT_OBJECT'] };
  }
  scanForbidden(ev, '', errors);

  for (const k of ENVELOPE_REQUIRED) {
    if (!(k in ev)) errors.push(`MISSING_ENVELOPE:${k}`);
  }

  const name = typeof ev.event === 'string' ? ev.event : '';
  if (!SNAKE_RE.test(name)) {
    errors.push(`BAD_EVENT_NAME:${name}`);
  } else if (!(name in EVENTS_SCHEMA)) {
    errors.push(`UNKNOWN_EVENT:${name}`);
  }

  if ('ts' in ev && (typeof ev.ts !== 'number' || !Number.isFinite(ev.ts) || ev.ts <= 0)) {
    errors.push('BAD_TS');
  }
  if ('ev_ver' in ev && ev.ev_ver !== EV_VER) {
    errors.push(`BAD_EV_VER:${ev.ev_ver}`);
  }
  if ('uid' in ev && (typeof ev.uid !== 'string' || ev.uid.trim() === '')) {
    errors.push('EMPTY_UID');
  }
  if ('sess' in ev && (typeof ev.sess !== 'string' || ev.sess.trim() === '')) {
    errors.push('EMPTY_SESS');
  }
  if ('tier' in ev && !ALLOWED_TIERS.has(String(ev.tier))) {
    errors.push(`BAD_TIER:${ev.tier}`);
  }
  if ('conn' in ev && !ALLOWED_CONNS.has(String(ev.conn))) {
    errors.push(`BAD_CONN:${ev.conn}`);
  }
  if ('build' in ev && !ALLOWED_BUILDS.has(String(ev.build))) {
    errors.push(`BAD_BUILD:${ev.build}`);
  }
  if ('age_ok' in ev && typeof ev.age_ok !== 'boolean') {
    errors.push('BAD_AGE_OK');
  }

  const params = ev.params ?? {};
  if (!params || typeof params !== 'object' || Array.isArray(params)) {
    errors.push('BAD_PARAMS_TYPE');
    return { ok: false, errors };
  }

  const spec = EVENTS_SCHEMA[name];
  if (spec) {
    for (const rk of spec.req || []) {
      if (!(rk in params)) errors.push(`MISSING_PARAM:${name}.${rk}`);
    }
    if (spec.enums) {
      for (const [ek, allowed] of Object.entries(spec.enums)) {
        if (ek in params && !allowed.has(String(params[ek]))) {
          errors.push(`BAD_ENUM:${name}.${ek}=${params[ek]}`);
        }
      }
    }
    for (const fk of spec.forbid || []) {
      if (fk in params) errors.push(`FORBIDDEN_PARAM:${name}.${fk}`);
    }
    if (name === 'age_gate_result' && 'birth_year_bucket' in params) {
      if (EXACT_DATE_RE.test(String(params.birth_year_bucket).trim())) {
        errors.push('PII_EXACT_BIRTH_DATE:age_gate_result.birth_year_bucket');
      }
    }
  }

  return { ok: errors.length === 0, errors };
}

export class EventsReceiver {
  constructor({ db, hmacSecret, region = 'RU', rateLimitPerMin = 600 } = {}) {
    if (!db) throw new Error('EventsReceiver requires a sqlite db');
    this.db = db;
    this.hmacSecret = hmacSecret || process.env.ANALYTICS_HMAC_SECRET || 'dev-ru-analytics-hmac-secret-change-me';
    this.region = region;
    this.limiter = new RateLimiter(rateLimitPerMin, 60000);
    initEventsSchema(db);
    this.q = {
      insertEvent: db.prepare(`
        INSERT INTO analytics_events
          (event_name, ts_ms, day_utc, uid_hmac, sess, app_ver, build, lang, tier, age_ok, conn, ev_ver, params_json, ingested_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `),
      upsertConsent: db.prepare(`
        INSERT INTO analytics_consent (uid_hmac, analytics_consent, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(uid_hmac) DO UPDATE SET analytics_consent = excluded.analytics_consent, updated_at = excluded.updated_at
      `),
      getConsent: db.prepare('SELECT analytics_consent FROM analytics_consent WHERE uid_hmac = ?'),
      eraseUser: db.prepare('DELETE FROM analytics_events WHERE uid_hmac = ?'),
      countEvents: db.prepare('SELECT COUNT(*) AS n FROM analytics_events'),
      selectAll: db.prepare(`
        SELECT event_name, ts_ms, day_utc, uid_hmac, sess, app_ver, build, lang, tier, age_ok, conn, ev_ver, params_json
        FROM analytics_events ORDER BY ts_ms ASC, id ASC
      `),
    };
  }

  setConsent(rawUid, granted, { erase = false, nowSec = Math.floor(Date.now() / 1000) } = {}) {
    if (!rawUid || typeof rawUid !== 'string') {
      throw new ApiError(400, 'bad_uid', 'uid is required');
    }
    const uidHmac = pseudonymizeUid(rawUid, this.hmacSecret);
    this.q.upsertConsent.run(uidHmac, granted ? 1 : 0, nowSec);
    let erased = 0;
    if (!granted && erase) {
      const info = this.q.eraseUser.run(uidHmac);
      erased = Number(info.changes || 0);
    }
    return { ok: true, uid_hmac: uidHmac, analytics_consent: Boolean(granted), erased, region: this.region };
  }

  ingestBatch(events, { consent = true, nowSec = Math.floor(Date.now() / 1000) } = {}) {
    if (!consent) {
      return { ok: true, accepted: 0, rejected: 0, dropped_no_consent: Array.isArray(events) ? events.length : 0, errors: [], region: this.region };
    }
    if (!Array.isArray(events)) {
      throw new ApiError(400, 'bad_batch', 'events must be an array');
    }
    if (events.length > MAX_BATCH_SIZE) {
      throw new ApiError(413, 'batch_too_large', `max ${MAX_BATCH_SIZE} events per batch`);
    }

    let accepted = 0;
    let rejected = 0;
    let droppedNoConsent = 0;
    const errors = [];

    this.db.exec('BEGIN IMMEDIATE');
    try {
      for (let i = 0; i < events.length; i++) {
        const ev = events[i];
        const v = validateEvent(ev);
        if (!v.ok) {
          rejected++;
          errors.push({ index: i, event: ev?.event ?? '', errors: v.errors });
          continue;
        }
        const uidHmac = pseudonymizeUid(ev.uid, this.hmacSecret);
        const consentRow = this.q.getConsent.get(uidHmac);
        if (consentRow && Number(consentRow.analytics_consent) === 0) {
          droppedNoConsent++;
          continue;
        }
        const tsMs = Math.trunc(ev.ts);
        const dayUtc = new Date(tsMs).toISOString().slice(0, 10);
        this.q.insertEvent.run(
          ev.event,
          tsMs,
          dayUtc,
          uidHmac,
          String(ev.sess),
          String(ev.app_ver),
          String(ev.build),
          String(ev.lang),
          String(ev.tier),
          ev.age_ok ? 1 : 0,
          String(ev.conn),
          EV_VER,
          JSON.stringify(ev.params ?? {}),
          nowSec,
        );
        accepted++;
      }
      this.db.exec('COMMIT');
    } catch (err) {
      try { this.db.exec('ROLLBACK'); } catch { /* ignore */ }
      throw err;
    }

    return { ok: true, accepted, rejected, dropped_no_consent: droppedNoConsent, errors, region: this.region };
  }

  exportEvents() {
    return this.q.selectAll.all().map((row) => ({
      event: row.event_name,
      ts: Number(row.ts_ms),
      day: row.day_utc,
      uid: row.uid_hmac,
      sess: row.sess,
      app_ver: row.app_ver,
      build: row.build,
      lang: row.lang,
      tier: row.tier,
      age_ok: Boolean(row.age_ok),
      conn: row.conn,
      ev_ver: Number(row.ev_ver),
      params: JSON.parse(row.params_json),
    }));
  }

  exportNdjson() {
    return this.exportEvents().map((e) => JSON.stringify(e)).join('\n') + '\n';
  }

  health() {
    const row = this.q.countEvents.get();
    return {
      ok: true,
      region: this.region,
      schema_ver: EV_VER,
      event_types: Object.keys(EVENTS_SCHEMA).length,
      stored_events: Number(row?.n ?? 0),
      pii_guard: true,
      personalized_discounts_allowed: false,
    };
  }

  /** HTTP route handler (returns true if route matched). */
  async handle(req, res, url) {
    const route = `${req.method} ${url.pathname}`;
    if (route !== 'POST /api/v1/events' && route !== 'POST /api/v1/events/consent' && route !== 'GET /api/v1/events/health') {
      return false;
    }
    const ip = clientIp(req);
    if (!this.limiter.hit(ip)) {
      throw new ApiError(429, 'rate_limited', 'Too many analytics requests');
    }

    if (route === 'GET /api/v1/events/health') {
      sendJson(res, 200, this.health());
      return true;
    }

    if (route === 'POST /api/v1/events/consent') {
      const b = await readJson(req);
      const resObj = this.setConsent(b.uid, Boolean(b.analytics_consent), { erase: Boolean(b.erase) });
      sendJson(res, 200, resObj);
      return true;
    }

    if (route === 'POST /api/v1/events') {
      const b = await readJson(req);
      const consent = b.consent !== undefined ? Boolean(b.consent) : true;
      const list = Array.isArray(b.events) ? b.events : (b.event ? [b] : null);
      if (!list) {
        throw new ApiError(400, 'bad_payload', 'Expected { events: [...] } or a single event object');
      }
      const result = this.ingestBatch(list, { consent });
      const status = result.accepted === 0 && result.rejected > 0 ? 400 : 200;
      sendJson(res, status, result);
      return true;
    }
    return false;
  }
}

/** Standalone lightweight HTTP server factory for tests or isolated RU telemetry deployment. */
export async function createEventsServer({ db, hmacSecret, region = 'RU', port = 0, host = '127.0.0.1', rateLimitPerMin = 600 } = {}) {
  const receiver = new EventsReceiver({ db, hmacSecret, region, rateLimitPerMin });
  const server = createServer(async (req, res) => {
    let url;
    try { url = new URL(req.url, 'http://x'); } catch { return sendJson(res, 400, { ok: false, error: 'bad_url' }); }
    if (req.method === 'OPTIONS') { res.writeHead(204, CORS_HEADERS); return res.end(); }
    try {
      const handled = await receiver.handle(req, res, url);
      if (!handled) sendJson(res, 404, { ok: false, error: 'not_found' });
    } catch (err) {
      sendError(res, err);
    }
  });
  await new Promise((ok, fail) => {
    server.once('error', fail);
    server.listen(port, host, () => { server.off('error', fail); ok(); });
  });
  const realPort = server.address().port;
  return {
    port: realPort,
    receiver,
    server,
    close() {
      return new Promise((ok) => {
        server.close(() => ok());
        server.closeAllConnections?.();
      });
    },
  };
}
