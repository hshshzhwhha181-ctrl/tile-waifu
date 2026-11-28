// Tile Waifu P106 — First-party Russian analytics event receiver (MONETIZATION_PLAN.md §7.4).
// Zero npm dependencies: node:crypto + node:sqlite + node:http.
// Privacy (152-FZ):
//   - Server-side HMAC-SHA256 pseudonymization of `uid` (raw uid is never persisted).
//   - Hard rejection of PII keys (birth_date, nick, email, phone, IP, raw device IDs) and email literals.
//   - Hard rejection of spend-profile personalized discount / dynamic pricing fields.
//   - Separate consent toggle endpoint with opt-out and data erasure by pseudonymized uid.

import { createHash, createHmac, timingSafeEqual } from 'node:crypto';
import { createServer } from 'node:http';
import { ApiError, CORS_HEADERS, RateLimiter, clientIp, readJson, sendError, sendJson } from './util.mjs';

export const EV_VER = 1;
export const MAX_BATCH_SIZE = 200;
export const MAX_STR_LEN = 256;
export const MAX_ENVELOPE_STR_LEN = 128;
export const MAX_PARAMS_JSON_BYTES = 8192;
export const MAX_SCAN_DEPTH = 6;
export const MIN_TS_MS = Date.UTC(2020, 0, 1);
export const MAX_TS_MS = Date.UTC(2100, 0, 1);
export const DEFAULT_RETENTION_DAYS = 365;
export const DEFAULT_MAX_FUTURE_SKEW_MS = 10 * 60 * 1000;
export const DAY_MS = 86_400_000;

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
export const SERVER_ONLY_EVENTS = new Set(['purchase_ok', 'purchase_refund']);

export const FORBIDDEN_PII_KEYS = new Set([
  'birth_date', 'birthdate', 'dob', 'birthday', 'birth_day',
  'email', 'e_mail', 'email_address', 'emailaddress',
  'nick', 'nickname', 'username', 'full_name', 'fullname', 'real_name', 'realname',
  'phone', 'phone_number', 'phonenumber', 'ip', 'ip_address', 'ipaddress',
  'device_id', 'deviceid', 'imei', 'idfa', 'gaid', 'advertising_id', 'advertisingid',
  'passport', 'card_number', 'cardnumber',
]);

export const FORBIDDEN_ETHICS_KEYS = new Set([
  'personal_discount', 'personalized_discount', 'spend_profile_discount', 'spend_profile_offer',
  'whale_discount', 'whale_offer', 'whale_nudge',
  'dynamic_price', 'dynamic_price_rub', 'targeted_price_rub', 'nudge_tier', 'p2w_bonus',
]);

const normalizeKey = (k) => String(k).toLowerCase().replace(/[^a-z0-9]/g, '');
const FORBIDDEN_PII_NORM = new Set([...FORBIDDEN_PII_KEYS].map(normalizeKey));
const FORBIDDEN_ETHICS_NORM = new Set([...FORBIDDEN_ETHICS_KEYS].map(normalizeKey));

export const EVENTS_SCHEMA = Object.freeze({
  app_open: { req: ['src'], types: { src: 'str', dur_s: 'num>=0' } },
  session_start: { req: ['src'], types: { src: 'str', dur_s: 'num>=0' } },
  session_end: { req: ['dur_s'], types: { dur_s: 'num>=0', src: 'str' } },
  age_gate_result: { req: ['ok', 'birth_year_bucket', 'tier_toggle'], types: { ok: 'bool', birth_year_bucket: 'str', tier_toggle: 'str' } },
  account_link: { req: ['provider'], enums: { provider: ALLOWED_PROVIDERS }, types: { provider: 'str' } },
  ftue_step: { req: ['step', 't_s'], types: { step: 'str', t_s: 'num>=0' } },
  level_end: { req: ['mode', 'level', 'win', 'dur_s', 'pairs'], types: { mode: 'str', level: 'num>=0', win: 'bool', dur_s: 'num>=0', pairs: 'num>=0' } },
  wish_banner_view: { req: ['banner_id', 'family', 'k', 'g', 'c'], types: { banner_id: 'str', family: 'str', k: 'num>=0', g: 'num>=0', c: 'num>=0' } },
  odds_open: { req: ['banner_id', 'odds_hash'], types: { banner_id: 'str', odds_hash: 'str' } },
  history_open: { req: ['banner_id', 'odds_hash'], types: { banner_id: 'str', odds_hash: 'str' } },
  preview_open: { req: ['skin_id', 'from'], types: { skin_id: 'str', from: 'str' } },
  wish_confirm_open: { req: ['banner_id', 'n', 'cost', 'pay_from', 'limit_left'], enums: { pay_from: ALLOWED_PAY_FROM }, types: { banner_id: 'str', n: 'num>=0', cost: 'num>=0', pay_from: 'str', limit_left: 'num>=0' } },
  wish_pull: {
    req: [
      'banner_id', 'family', 'idx', 'k_before', 'g_before', 'c_before',
      'result', 'item_id', 'featured', 'candle', 'cost_cur', 'cost_amt', 'odds_hash', 'seed_commit',
    ],
    enums: { result: ALLOWED_WISH_RESULTS },
    types: {
      banner_id: 'str', family: 'str', idx: 'num>=0', k_before: 'num>=0', g_before: 'num>=0', c_before: 'num>=0',
      result: 'str', item_id: 'str', featured: 'bool', candle: 'bool', cost_cur: 'str', cost_amt: 'num>=0',
      odds_hash: 'str', seed_commit: 'str',
    },
  },
  wish_series_end: { req: ['n', 'ssr_count', 'spent_rub_equiv'], types: { n: 'num>=0', ssr_count: 'num>=0', spent_rub_equiv: 'num>=0' } },
  store_open: { req: ['section'], types: { section: 'str', sku_id: 'str', price_rub: 'num>=0', wishes_equiv: 'num>=0' } },
  sku_view: { req: ['section', 'sku_id', 'price_rub', 'wishes_equiv'], types: { section: 'str', sku_id: 'str', price_rub: 'num>=0', wishes_equiv: 'num>=0' } },
  purchase_start: { req: ['sku_id', 'price_rub', 'method', 'purchase_id'], enums: { method: ALLOWED_PAY_METHODS }, types: { sku_id: 'str', price_rub: 'num>=0', method: 'str', purchase_id: 'str', err: 'str' } },
  purchase_ok: { req: ['sku_id', 'price_rub', 'method', 'purchase_id'], enums: { method: ALLOWED_PAY_METHODS }, types: { sku_id: 'str', price_rub: 'num>=0', method: 'str', purchase_id: 'str', n: 'num>=0', category: 'str', err: 'str' } },
  purchase_fail: { req: ['sku_id', 'price_rub', 'method', 'purchase_id', 'err'], enums: { method: ALLOWED_PAY_METHODS }, types: { sku_id: 'str', price_rub: 'num>=0', method: 'str', purchase_id: 'str', err: 'str' } },
  purchase_cancel: { req: ['sku_id', 'price_rub', 'method', 'purchase_id'], enums: { method: ALLOWED_PAY_METHODS }, types: { sku_id: 'str', price_rub: 'num>=0', method: 'str', purchase_id: 'str', err: 'str' } },
  purchase_pending: { req: ['sku_id', 'price_rub', 'method', 'purchase_id'], enums: { method: ALLOWED_PAY_METHODS }, types: { sku_id: 'str', price_rub: 'num>=0', method: 'str', purchase_id: 'str', err: 'str' } },
  purchase_refund: { req: ['sku_id', 'amount', 'debt_after', 'days_since'], types: { sku_id: 'str', amount: 'num>=0', debt_after: 'num>=0', days_since: 'num>=0', purchase_id: 'str' } },
  moon_balance_audit: { req: ['ok', 'delta'], types: { ok: 'bool', delta: 'num' } },
  limit_choice_shown: { req: ['type'], types: { type: 'str', value: 'num>=0', prev: 'num>=0' } },
  limit_set: { req: ['value', 'prev', 'type'], types: { value: 'num>=0', prev: 'num>=0', type: 'str' } },
  limit_hit: { req: ['value', 'type'], types: { value: 'num>=0', type: 'str', prev: 'num>=0' } },
  pause_set: { req: ['value', 'type'], types: { value: 'num>=0', type: 'str', prev: 'num>=0' } },
  cooldown_prompt: { req: ['type'], types: { type: 'str', value: 'num>=0', prev: 'num>=0' } },
  cooldown_accept: { req: ['type'], types: { type: 'str', value: 'num>=0', prev: 'num>=0' } },
  rank_up: { req: ['from', 'to'], forbid: ['rub', 'price_rub', 'spent_rub', 'spend_rub', 'amount_rub'], types: { from: 'num>=0', to: 'num>=0' } },
  pass_view: { req: ['season'], types: { season: 'str', line: 'str', step: 'num>=0' } },
  pass_buy: { req: ['season', 'line'], enums: { line: ALLOWED_PASS_LINES }, types: { season: 'str', line: 'str', step: 'num>=0' } },
  pass_step_claim: { req: ['season', 'line', 'step'], enums: { line: ALLOWED_PASS_LINES }, types: { season: 'str', line: 'str', step: 'num>=0' } },
  fund_buy: { req: ['fund_id'], types: { fund_id: 'str', milestone: 'num>=0' } },
  fund_claim: { req: ['fund_id', 'milestone'], types: { fund_id: 'str', milestone: 'num>=0' } },
  skin_equip: { req: ['skin_id', 'tier', 'hud_level'], types: { skin_id: 'str', tier: 'str', hud_level: 'num>=0', star: 'num>=0', variant: 'str' } },
  skin_dye: { req: ['skin_id', 'tier'], types: { skin_id: 'str', tier: 'str', hud_level: 'num>=0', star: 'num>=0', variant: 'str' } },
  star_up: { req: ['skin_id', 'star'], types: { skin_id: 'str', star: 'num>=0', tier: 'str', hud_level: 'num>=0', variant: 'str' } },
  ult_play: { req: ['skin_id', 'variant'], enums: { variant: ALLOWED_ULT_VARIANTS }, types: { skin_id: 'str', variant: 'str', tier: 'str', hud_level: 'num>=0', star: 'num>=0' } },
  direct_sale_open: { req: ['skin_id', 'day'], types: { skin_id: 'str', day: 'num>=0' } },
  bond_level_up: { req: ['hero', 'lv'], types: { hero: 'str', lv: 'num>=0' } },
  ad_offer: { req: ['placement'], types: { placement: 'str', ecpm_bucket: 'str' } },
  ad_watch: { req: ['placement'], types: { placement: 'str', ecpm_bucket: 'str' } },
  ad_reward: { req: ['placement', 'ecpm_bucket'], types: { placement: 'str', ecpm_bucket: 'str' } },
  ad_complaint: { req: ['placement'], types: { placement: 'str', ecpm_bucket: 'str', reason: 'str' } },
  event_shop_buy: { req: ['event_id', 'cur', 'amt'], types: { event_id: 'str', cur: 'str', amt: 'num>=0' } },
  event_points: { req: ['event_id', 'cur', 'amt'], types: { event_id: 'str', cur: 'str', amt: 'num>=0' } },
  econ_snapshot: { req: ['gems', 'tickets', 'moon', 'petals', 'coins'], types: { gems: 'str', tickets: 'str', moon: 'str', petals: 'str', coins: 'str' } },
  crash: { req: ['stack_hash'], types: { stack_hash: 'str' } },
  anr: { req: ['stack_hash'], types: { stack_hash: 'str' } },
});

const SNAKE_RE = /^[a-z][a-z0-9_]*$/;
const EXACT_DATE_RE = /^(?:\d{4}[-/.]\d{2}[-/.]\d{2}|\d{2}[-/.]\d{2}[-/.]\d{4})$/;
const EMAIL_VALUE_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const EVENTS_SQL = `
CREATE TABLE IF NOT EXISTS analytics_events (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id    TEXT    NOT NULL,
  source      TEXT    NOT NULL DEFAULT 'client',
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
CREATE UNIQUE INDEX IF NOT EXISTS idx_ev_dedup ON analytics_events(uid_hmac, event_id);
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

function scanForbidden(node, prefix, errors, depth = 0) {
  if (depth > MAX_SCAN_DEPTH) {
    errors.push(`NESTING_TOO_DEEP:${prefix || 'root'}`);
    return;
  }
  if (Array.isArray(node)) {
    for (let i = 0; i < node.length; i++) {
      const item = node[i];
      const full = `${prefix}[${i}]`;
      if (item && typeof item === 'object') {
        scanForbidden(item, full, errors, depth + 1);
      } else if (typeof item === 'string') {
        if (item.length > MAX_STR_LEN) errors.push(`PARAM_TOO_LONG:${full}`);
        if (EMAIL_VALUE_RE.test(item.trim())) errors.push(`PII_EMAIL_VALUE:${full}`);
      }
    }
    return;
  }
  for (const [rawKey, val] of Object.entries(node)) {
    const k = String(rawKey).toLowerCase();
    const kNorm = normalizeKey(rawKey);
    const full = prefix ? `${prefix}.${k}` : k;
    if (FORBIDDEN_PII_KEYS.has(k) || FORBIDDEN_PII_NORM.has(kNorm)) {
      errors.push(`PII_FORBIDDEN:${full}`);
    } else if (FORBIDDEN_ETHICS_KEYS.has(k) || FORBIDDEN_ETHICS_NORM.has(kNorm)) {
      errors.push(`ETHICS_FORBIDDEN:${full}`);
    }
    if (val && typeof val === 'object') {
      scanForbidden(val, full, errors, depth + 1);
    } else if (typeof val === 'string') {
      if (prefix && val.length > MAX_STR_LEN) {
        errors.push(`PARAM_TOO_LONG:${full}`);
      }
      if (k !== 'stack_hash' && EMAIL_VALUE_RE.test(val.trim())) {
        errors.push(`PII_EMAIL_VALUE:${full}`);
      }
    }
  }
}

function checkParamType(val, expected) {
  if (expected === 'str') return typeof val === 'string' && val.length <= MAX_STR_LEN;
  if (expected === 'bool') return typeof val === 'boolean';
  if (expected === 'num') return typeof val === 'number' && Number.isFinite(val);
  if (expected === 'num>=0') return typeof val === 'number' && Number.isFinite(val) && val >= 0;
  return true;
}

export function validateEvent(ev, opts = {}) {
  const errors = [];
  if (!ev || typeof ev !== 'object' || Array.isArray(ev)) {
    return { ok: false, errors: ['NOT_OBJECT'] };
  }
  scanForbidden(ev, '', errors);

  for (const k of ENVELOPE_REQUIRED) {
    if (!Object.hasOwn(ev, k)) errors.push(`MISSING_ENVELOPE:${k}`);
  }

  const name = typeof ev.event === 'string' ? ev.event : '';
  if (!SNAKE_RE.test(name)) {
    errors.push(`BAD_EVENT_NAME:${name}`);
  } else if (!Object.hasOwn(EVENTS_SCHEMA, name)) {
    errors.push(`UNKNOWN_EVENT:${name}`);
  }

  if (Object.hasOwn(ev, 'ts')) {
    if (typeof ev.ts !== 'number' || !Number.isFinite(ev.ts) || ev.ts < MIN_TS_MS || ev.ts > MAX_TS_MS) {
      errors.push('BAD_TS');
    } else if (typeof opts.nowMs === 'number' && Number.isFinite(opts.nowMs)) {
      const maxFutureSkewMs = opts.maxFutureSkewMs ?? DEFAULT_MAX_FUTURE_SKEW_MS;
      const retentionDays = opts.retentionDays ?? DEFAULT_RETENTION_DAYS;
      if (ev.ts > opts.nowMs + maxFutureSkewMs) {
        errors.push('BAD_TS_SKEW');
      } else if (retentionDays > 0 && ev.ts < opts.nowMs - retentionDays * DAY_MS) {
        errors.push('BAD_TS_EXPIRED');
      }
    }
  }
  if (Object.hasOwn(ev, 'ev_ver') && ev.ev_ver !== EV_VER) {
    errors.push(`BAD_EV_VER:${ev.ev_ver}`);
  }
  if (Object.hasOwn(ev, 'uid') && (typeof ev.uid !== 'string' || ev.uid.trim() === '' || ev.uid.length > MAX_ENVELOPE_STR_LEN)) {
    errors.push('EMPTY_UID');
  }
  if (Object.hasOwn(ev, 'sess') && (typeof ev.sess !== 'string' || ev.sess.trim() === '' || ev.sess.length > MAX_ENVELOPE_STR_LEN)) {
    errors.push('EMPTY_SESS');
  }
  if (Object.hasOwn(ev, 'app_ver') && (typeof ev.app_ver !== 'string' || ev.app_ver.length > MAX_ENVELOPE_STR_LEN)) {
    errors.push('BAD_APP_VER');
  }
  if (Object.hasOwn(ev, 'lang') && (typeof ev.lang !== 'string' || ev.lang.length > 32)) {
    errors.push('BAD_LANG');
  }
  if (Object.hasOwn(ev, 'tier') && !ALLOWED_TIERS.has(String(ev.tier))) {
    errors.push(`BAD_TIER:${ev.tier}`);
  }
  if (Object.hasOwn(ev, 'conn') && !ALLOWED_CONNS.has(String(ev.conn))) {
    errors.push(`BAD_CONN:${ev.conn}`);
  }
  if (Object.hasOwn(ev, 'build') && !ALLOWED_BUILDS.has(String(ev.build))) {
    errors.push(`BAD_BUILD:${ev.build}`);
  }
  if (Object.hasOwn(ev, 'age_ok') && typeof ev.age_ok !== 'boolean') {
    errors.push('BAD_AGE_OK');
  }
  if (Object.hasOwn(ev, 'event_id') && (typeof ev.event_id !== 'string' || ev.event_id.trim() === '' || ev.event_id.length > MAX_ENVELOPE_STR_LEN)) {
    errors.push('BAD_EVENT_ID');
  }

  const params = Object.hasOwn(ev, 'params') ? ev.params : {};
  if (!params || typeof params !== 'object' || Array.isArray(params)) {
    errors.push('BAD_PARAMS_TYPE');
    return { ok: false, errors };
  }
  try {
    const serialized = JSON.stringify(params);
    if (Buffer.byteLength(serialized, 'utf8') > MAX_PARAMS_JSON_BYTES) {
      errors.push('PARAMS_TOO_LARGE');
    }
  } catch {
    errors.push('BAD_PARAMS_JSON');
  }

  const spec = Object.hasOwn(EVENTS_SCHEMA, name) ? EVENTS_SCHEMA[name] : null;
  if (spec) {
    for (const rk of spec.req || []) {
      if (!Object.hasOwn(params, rk)) errors.push(`MISSING_PARAM:${name}.${rk}`);
    }
    if (spec.types) {
      for (const [tk, expectedType] of Object.entries(spec.types)) {
        if (Object.hasOwn(params, tk) && !checkParamType(params[tk], expectedType)) {
          errors.push(`BAD_PARAM_TYPE:${name}.${tk}`);
        }
      }
    }
    if (spec.enums) {
      for (const [ek, allowed] of Object.entries(spec.enums)) {
        if (Object.hasOwn(params, ek) && !allowed.has(String(params[ek]))) {
          errors.push(`BAD_ENUM:${name}.${ek}=${params[ek]}`);
        }
      }
    }
    for (const fk of spec.forbid || []) {
      if (Object.hasOwn(params, fk)) errors.push(`FORBIDDEN_PARAM:${name}.${fk}`);
    }
    if (name === 'age_gate_result' && Object.hasOwn(params, 'birth_year_bucket')) {
      if (EXACT_DATE_RE.test(String(params.birth_year_bucket).trim())) {
        errors.push('PII_EXACT_BIRTH_DATE:age_gate_result.birth_year_bucket');
      }
    }
  }

  return { ok: errors.length === 0, errors };
}

function canonicalJson(val) {
  if (val === null || typeof val !== 'object') return JSON.stringify(val);
  if (Array.isArray(val)) return '[' + val.map(canonicalJson).join(',') + ']';
  const keys = Object.keys(val).sort();
  return '{' + keys.map((k) => JSON.stringify(k) + ':' + canonicalJson(val[k])).join(',') + '}';
}

function safeTokenEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || !a || !b) return false;
  const ba = Buffer.from(a, 'utf8');
  const bb = Buffer.from(b, 'utf8');
  return ba.length === bb.length && timingSafeEqual(ba, bb);
}

export class EventsReceiver {
  constructor({
    db,
    hmacSecret,
    region = 'RU',
    rateLimitPerMin = 600,
    authenticate = null,
    users = null,
    serverIngestToken = null,
    retentionDays = DEFAULT_RETENTION_DAYS,
    maxFutureSkewMs = DEFAULT_MAX_FUTURE_SKEW_MS,
  } = {}) {
    if (!db) throw new Error('EventsReceiver requires a sqlite db');
    const resolvedSecret = hmacSecret ?? process.env.ANALYTICS_HMAC_SECRET ?? '';
    if (typeof resolvedSecret !== 'string' || resolvedSecret.length < 16) {
      throw new Error('ANALYTICS_HMAC_SECRET must be configured (string of at least 16 chars)');
    }
    this.db = db;
    this.hmacSecret = resolvedSecret;
    this.region = region;
    this.serverIngestToken = serverIngestToken ?? process.env.ANALYTICS_SERVER_INGEST_TOKEN ?? null;
    this.retentionDays = Math.max(1, Number(retentionDays) || DEFAULT_RETENTION_DAYS);
    this.maxFutureSkewMs = Math.max(0, Number(maxFutureSkewMs ?? DEFAULT_MAX_FUTURE_SKEW_MS));
    this.limiter = new RateLimiter(rateLimitPerMin, 60000);
    if (typeof authenticate === 'function') {
      this._authenticate = authenticate;
    } else if (users && typeof users.byToken === 'function') {
      this._authenticate = (req) => {
        const h = String(req.headers.authorization || '');
        const m = /^Bearer\s+(\S+)$/i.exec(h);
        if (!m) return null;
        const u = users.byToken(m[1]);
        return u ? String(u.id) : null;
      };
    } else {
      this._authenticate = () => null;
    }
    initEventsSchema(db);
    this.q = {
      insertEvent: db.prepare(`
        INSERT OR IGNORE INTO analytics_events
          (event_id, source, event_name, ts_ms, day_utc, uid_hmac, sess, app_ver, build, lang, tier, age_ok, conn, ev_ver, params_json, ingested_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `),
      upsertConsent: db.prepare(`
        INSERT INTO analytics_consent (uid_hmac, analytics_consent, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(uid_hmac) DO UPDATE SET analytics_consent = excluded.analytics_consent, updated_at = excluded.updated_at
      `),
      getConsent: db.prepare('SELECT analytics_consent FROM analytics_consent WHERE uid_hmac = ?'),
      eraseUser: db.prepare('DELETE FROM analytics_events WHERE uid_hmac = ?'),
      pruneExpired: db.prepare('DELETE FROM analytics_events WHERE ts_ms < ?'),
      countEvents: db.prepare('SELECT COUNT(*) AS n FROM analytics_events'),
      selectAll: db.prepare(`
        SELECT event_id, source, event_name, ts_ms, day_utc, uid_hmac, sess, app_ver, build, lang, tier, age_ok, conn, ev_ver, params_json
        FROM analytics_events ORDER BY ts_ms ASC, id ASC
      `),
    };
  }

  pruneExpired(nowSec = Math.floor(Date.now() / 1000)) {
    const cutoffMs = nowSec * 1000 - this.retentionDays * DAY_MS;
    const info = this.q.pruneExpired.run(cutoffMs);
    return Number(info.changes || 0);
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
    return { ok: true, analytics_consent: Boolean(granted), erased, region: this.region };
  }

  ingestServerBatch(events, opts = {}) {
    return this.ingestBatch(events, { ...opts, consent: true, trustedServer: true });
  }

  ingestBatch(events, { consent = false, nowSec = Math.floor(Date.now() / 1000), trustedServer = false } = {}) {
    if (!consent) {
      return {
        ok: true,
        accepted: 0,
        rejected: 0,
        deduplicated: 0,
        dropped_no_consent: Array.isArray(events) ? events.length : 0,
        errors: [],
        region: this.region,
      };
    }
    if (!Array.isArray(events)) {
      throw new ApiError(400, 'bad_batch', 'events must be an array');
    }
    if (events.length > MAX_BATCH_SIZE) {
      throw new ApiError(413, 'batch_too_large', `max ${MAX_BATCH_SIZE} events per batch`);
    }

    let accepted = 0;
    let rejected = 0;
    let deduplicated = 0;
    let droppedNoConsent = 0;
    const errors = [];
    const source = trustedServer ? 'server' : 'client';

    const nowMs = nowSec * 1000;
    this.db.exec('BEGIN IMMEDIATE');
    try {
      for (let i = 0; i < events.length; i++) {
        const ev = events[i];
        const v = validateEvent(ev, {
          nowMs,
          retentionDays: this.retentionDays,
          maxFutureSkewMs: this.maxFutureSkewMs,
        });
        if (!v.ok) {
          rejected++;
          errors.push({ index: i, event: ev?.event ?? '', errors: v.errors });
          continue;
        }
        if (!trustedServer && SERVER_ONLY_EVENTS.has(ev.event)) {
          rejected++;
          errors.push({ index: i, event: ev.event, errors: [`SERVER_ONLY_EVENT:${ev.event}`] });
          continue;
        }
        const uidHmac = pseudonymizeUid(ev.uid, this.hmacSecret);
        // Strict 152-FZ opt-in: require explicit analytics_consent = 1 row (fail closed)
        const consentRow = this.q.getConsent.get(uidHmac);
        if (!consentRow || Number(consentRow.analytics_consent) !== 1) {
          droppedNoConsent++;
          continue;
        }
        const tsMs = Math.trunc(ev.ts);
        let dayUtc;
        try {
          dayUtc = new Date(tsMs).toISOString().slice(0, 10);
        } catch {
          rejected++;
          errors.push({ index: i, event: ev.event, errors: ['BAD_TS'] });
          continue;
        }
        const paramsObj = ev.params ?? {};
        const paramsJson = JSON.stringify(paramsObj);
        let eventId;
        if (ev.event === 'purchase_ok' && typeof paramsObj.purchase_id === 'string' && paramsObj.purchase_id.trim()) {
          eventId = `purchase_ok:${paramsObj.purchase_id.trim()}`;
        } else if (typeof ev.event_id === 'string' && ev.event_id.trim()) {
          eventId = ev.event_id.trim();
        } else {
          eventId = `fp_${createHash('sha256').update(`${ev.event}\0${tsMs}\0${ev.sess}\0${canonicalJson(paramsObj)}`).digest('hex').slice(0, 32)}`;
        }
        const info = this.q.insertEvent.run(
          eventId,
          source,
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
          paramsJson,
          nowSec,
        );
        if (Number(info.changes || 0) === 0) {
          deduplicated++;
        } else {
          accepted++;
        }
      }
      this.db.exec('COMMIT');
    } catch (err) {
      try { this.db.exec('ROLLBACK'); } catch { /* ignore */ }
      throw err;
    }

    return {
      ok: true,
      accepted,
      rejected,
      deduplicated,
      dropped_no_consent: droppedNoConsent,
      errors,
      region: this.region,
    };
  }

  exportEvents() {
    return this.q.selectAll.all().map((row) => ({
      event_id: row.event_id,
      source: row.source,
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
      const auth = this._authenticate(req);
      const authUid = auth && typeof auth === 'object' ? String(auth.uid ?? auth.id ?? '') : String(auth ?? '');
      if (!authUid) {
        throw new ApiError(401, 'unauthorized', 'Authentication required for analytics consent');
      }
      const b = await readJson(req);
      if (b.uid !== undefined && String(b.uid) !== authUid) {
        throw new ApiError(403, 'forbidden', 'Cannot modify analytics consent for another user');
      }
      const resObj = this.setConsent(authUid, Boolean(b.analytics_consent), { erase: Boolean(b.erase) });
      sendJson(res, 200, resObj);
      return true;
    }

    if (route === 'POST /api/v1/events') {
      const b = await readJson(req);
      const consent = b.consent === true;
      const list = Array.isArray(b.events) ? b.events : (b.event ? [b] : null);
      if (!list) {
        throw new ApiError(400, 'bad_payload', 'Expected { events: [...] } or a single event object');
      }
      const srvTokHeader = String(req.headers['x-server-ingest-token'] || '');
      const trustedServer = Boolean(this.serverIngestToken && safeTokenEqual(srvTokHeader, this.serverIngestToken));
      const result = this.ingestBatch(list, { consent, trustedServer });
      const status = result.accepted === 0 && result.rejected > 0 ? 400 : 200;
      sendJson(res, status, result);
      return true;
    }
    return false;
  }
}

/** Standalone lightweight HTTP server factory for tests or isolated RU telemetry deployment. */
export async function createEventsServer({
  db,
  hmacSecret,
  region = 'RU',
  port = 0,
  host = '127.0.0.1',
  rateLimitPerMin = 600,
  authenticate = null,
  users = null,
  serverIngestToken = null,
  retentionDays = DEFAULT_RETENTION_DAYS,
  maxFutureSkewMs = DEFAULT_MAX_FUTURE_SKEW_MS,
} = {}) {
  const receiver = new EventsReceiver({
    db,
    hmacSecret,
    region,
    rateLimitPerMin,
    authenticate,
    users,
    serverIngestToken,
    retentionDays,
    maxFutureSkewMs,
  });
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
