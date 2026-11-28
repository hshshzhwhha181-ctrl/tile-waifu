# FIX ROUND 1 — Server, Analytics & Modal Soak (`claude/ext-fix-server-soak`)

Scope: `design/ext/FIX_ROUND1.md` section `## server-ci-data` — Server, Analytics & Modal Soak slice (4 Confirmed MAJOR + 1 MINOR):
- Confirmed MAJOR #1 (`server/src/events.mjs`, `server/src/util.mjs`, `server/src/events.test.mjs`)
- Confirmed MAJOR #2 (`server/src/events.mjs`, `game/core/analytics/analytics_schema.gd`, `game/tests/analytics/analytics_selftest.gd`, `tools/dashboards/build_dashboards.py`)
- Confirmed MAJOR #3 (`server/src/events.mjs`, `game/core/analytics/analytics_buffer.gd`, `tools/dashboards/build_dashboards.py`, `tools/dashboards/gen_synthetic_events.py`, `tools/dashboards/test_dashboards.py`)
- Confirmed MAJOR #6 (`game/shell/tests/modal_soak.gd`)
- MINOR #3 (`tools/dashboards/build_dashboards.py`, `tools/dashboards/gen_synthetic_events.py`, `tools/dashboards/test_dashboards.py`)

Untouched (owned by `fix-g3-ci-data` / registries): `.github/workflows/qa-render.yml`, `docker/qa-render/`, `tools/assets/export_filter.py`, `tools/design_lint.py`, `tools/tw_test.py`, `game/project.godot`, `game/export_presets.cfg`, `game/assets/`, `.github/workflows/qa.yml`, `design/ext/reports/STATUS.md`.

---

## 1. Confirmed MAJOR #1 — Hardcoded HMAC Fallback, Unauthenticated Consent/Oracle & Spoofed `X-Forwarded-For`

### Root Cause
- `EventsReceiver` fell back silently to committed literal `'dev-ru-analytics-hmac-secret-change-me'` when `ANALYTICS_HMAC_SECRET` was unset.
- `POST /api/v1/events/consent` accepted arbitrary `{uid, analytics_consent, erase}` with no authentication, returned `uid_hmac` (raw-uid-to-pseudonym oracle), and inserted unbounded rows per unique `uid`.
- `util.mjs:clientIp()` trusted `X-Forwarded-For` by default (`TRUST_PROXY !== '0'`), letting spoofed headers bypass `RateLimiter`, whose map grew up to 50k without hard cap eviction.

### Fix
- Removed the hardcoded fallback secret completely in `server/src/events.mjs`; constructor now fails closed (`throw Error`) unless `hmacSecret` or `process.env.ANALYTICS_HMAC_SECRET` (>= 16 chars) is explicitly configured.
- Replaced hardcoded test secret in `server/src/events.test.mjs` with per-run ephemeral `randomBytes(32).toString('hex')` (zero hardcoded secrets anywhere).
- Required authentication on `POST /api/v1/events/consent` via `authenticate(req)` or `users` Bearer token lookup (fails closed with `401 unauthorized` if unauthenticated, `403 forbidden` if `b.uid` mismatches authenticated user); removed `uid_hmac` from the response.
- Changed `util.mjs:clientIp()` to fail closed (`process.env.TRUST_PROXY === '1'`) so spoofed `X-Forwarded-For` is ignored unless explicitly behind a trusted proxy, and bounded `RateLimiter` map size with deterministic eviction (`maxEntries = 10000`).

### RED → GREEN Evidence
Command: `node --test server/src/events.test.mjs`

**BEFORE (RED):**
```text
✖ MAJOR #1: fails closed without ANALYTICS_HMAC_SECRET and has no hardcoded secret fallback (2.1296ms)
  AssertionError [ERR_ASSERTION]: hardcoded fallback secret must be removed
✖ MAJOR #1: consent endpoint requires auth, blocks cross-user wipe, hides uid_hmac oracle, ignores spoofed X-Forwarded-For (20.0614ms)
  AssertionError [ERR_ASSERTION]: Expected values to be strictly equal: 200 !== 401
ℹ tests 6 | ℹ pass 4 | ℹ fail 2
```

**AFTER (GREEN):**
```text
✔ MAJOR #1: fails closed without ANALYTICS_HMAC_SECRET and has no hardcoded secret fallback (2.4387ms)
✔ MAJOR #1: consent endpoint requires auth, blocks cross-user wipe, hides uid_hmac oracle, ignores spoofed X-Forwarded-For (58.9179ms)
ℹ tests 6 | ℹ pass 6 | ℹ fail 0
```

---

## 2. Confirmed MAJOR #2 — `ts=1e16` Batch Poisoning, Prototype Keys, Array/Normalized PII, Param Types/Lengths & Retention

### Root Cause
- `ts = 1e16` passed `validateEvent` (`> 0`), then threw `RangeError: Invalid time value` in `new Date(tsMs).toISOString()`, rolling back up to 199 valid sibling events in the batch and returning HTTP 500.
- `name in EVENTS_SCHEMA` walked `Object.prototype`, accepting `constructor` as a valid event name.
- `scanForbidden` skipped `Array` elements and matched exact lowercase keys only, missing `E-Mail`, `deviceid`, `Email_Address`, and emails nested inside arrays.
- Required params were never checked for type or length (`price_rub='abc'` crashed `build_dashboards.py`, 100 kB `purchase_id` was accepted), and there were no `ts` skew or retention limits.

### Fix
- Bounded `ts` to `[2020-01-01, 2100-01-01]` plus clock-skew (`DEFAULT_MAX_FUTURE_SKEW_MS = 10 min`) and retention window (`DEFAULT_RETENTION_DAYS = 365`) in `validateEvent`, with per-event safe date conversion inside `ingestBatch` so one bad event never rolls back valid siblings.
- Switched all schema/envelope/param lookups to `Object.hasOwn(...)`.
- Made `scanForbidden` recurse into `Array`s and check separator-stripped normalized keys (`normalizeKey`) against normalized PII/ethics sets (`E-Mail`, `deviceid`, `Email_Address`, etc.), plus depth (`MAX_SCAN_DEPTH = 6`) and byte/string limits (`MAX_STR_LEN = 256`, `MAX_PARAMS_JSON_BYTES = 8192`).
- Added per-event `types` validation (`str`, `bool`, `num`, `num>=0`) across all 49 events in `EVENTS_SCHEMA`, added `EventsReceiver.pruneExpired(nowSec)` for retention cleanup, and mirrored array/normalized PII, `ts` range, and numeric param checks in `game/core/analytics/analytics_schema.gd`.
- Hardened `tools/dashboards/build_dashboards.py` with safe numeric parsing (`_safe_float`, `_safe_int`) so malformed records never crash dashboard generation.

### RED → GREEN Evidence
Server command: `node --test server/src/events.test.mjs`

**BEFORE (RED):**
```text
✖ MAJOR #2: ts=1e16 does not poison batch, prototype names rejected, array/normalized PII caught, param types/lengths & retention enforced (1.207ms)
  RangeError: Invalid time value
      at Date.toISOString (<anonymous>)
      at EventsReceiver.ingestBatch (server/src/events.mjs:339:39)
ℹ tests 7 | ℹ pass 6 | ℹ fail 1
```

**AFTER (GREEN):**
```text
✔ MAJOR #2: ts=1e16 does not poison batch, prototype names rejected, array/normalized PII caught, param types/lengths & retention enforced (2.6667ms)
ℹ tests 7 | ℹ pass 7 | ℹ fail 0
```

Godot client command (via `godot_lock.ps1`): `python tools/tw_test.py -s analytics`

**BEFORE (RED):**
```text
analytics   FAIL    24/30          8.5s
```

**AFTER (GREEN):**
```text
analytics   PASS    30/30         10.0s
```

---

## 3. Confirmed MAJOR #3 — Opt-In Consent Fail-Closed, `event_id` Replay Dedup, Server-Authoritative Revenue & Refund Subtraction

### Root Cause
- Server stored events for any `uid` with no `analytics_consent` row and defaulted body `consent` to `true` (opt-out / fail-open instead of 152-FZ opt-in).
- No `event_id` or unique dedup index existed, allowing batch replays to duplicate every row.
- Any unauthenticated client could POST forged `purchase_ok` events into `analytics_events`, inflating `build_dashboards.py` revenue/ARPPU/DB-10; `build_dashboards.py` neither deduplicated `purchase_id` nor subtracted `purchase_refund` from `net_rub`.

### Fix
- Made server ingestion strictly opt-in (`fail closed`): `ingestBatch` defaults `consent = false`, HTTP `POST /api/v1/events` requires `b.consent === true`, and every event requires an explicit `analytics_consent = 1` row for `uid_hmac`.
- Added `event_id` and `source` (`client` | `server`) columns to `analytics_events` with `UNIQUE INDEX idx_ev_dedup ON analytics_events(uid_hmac, event_id)` + `INSERT OR IGNORE` (reporting `deduplicated` count). Explicit `event_id` (emitted deterministically by `TWAnalyticsBuffer.build_event`) or canonical payload SHA-256 fingerprint prevents replays; `purchase_ok` also deduplicates by `purchase_id`.
- Rejected `SERVER_ONLY_EVENTS` (`purchase_ok`, `purchase_refund`) on client `POST /api/v1/events` with `400 SERVER_ONLY_EVENT:*`; accepted them only via `ingestServerBatch()` or constant-time-verified `X-Server-Ingest-Token` (tagged `source = 'server'`).
- Updated `tools/dashboards/build_dashboards.py` to accept only `source == "server"` for `purchase_ok` / `purchase_refund` (tracking `unverified_client_purchases_ignored`, `duplicate_purchases_ignored`, `malformed_purchases_ignored` in DB-06), deduplicate by `purchase_id`, and subtract `refund_rub` before `NET_MARGIN`: `net_rub = round(max(0.0, gross_rub - refund_rub) * 0.72, 2)`. Updated `gen_synthetic_events.py` to tag server billing events with `source = "server"`.

### RED → GREEN Evidence
Server command: `node --test server/src/events.test.mjs`

**BEFORE (RED):**
```text
✖ MAJOR #3: server consent is strict opt-in (fail closed), replays dedup by event_id, client purchase_ok rejected (7.9931ms)
  AssertionError [ERR_ASSERTION]: user without consent row must not have events stored: 1 !== 0
ℹ tests 8 | ℹ pass 7 | ℹ fail 1
```

Dashboards command: `python tools/dashboards/test_dashboards.py --selftest`

**BEFORE (RED):**
```text
ERROR: test_06_major3_revenue_dedup_server_source_and_refund_subtraction
  File "tools/dashboards/build_dashboards.py", line 251, in compute_dashboards
    price = float(p.get("price_rub", 0.0))
ValueError: could not convert string to float: 'abc'
DASHBOARDS_SELFTEST 5/6 FAIL
```

**AFTER (GREEN):**
```text
✔ MAJOR #3: server consent is strict opt-in (fail closed), replays dedup by event_id, client purchase_ok rejected (88.8618ms)
ℹ tests 8 | ℹ pass 8 | ℹ fail 0
DASHBOARDS_SELFTEST 6/6 PASS
```

---

## 4. MINOR #3 — DB-10 Anonymity Gaps & Non-Tautological Dashboard Tests

### Root Cause
- DB-10 `top_1_pct_payers`, `top_5_pct_payers`, `top_10_pct_payers`, `top_25_pct_payers` and `whale_plus_kraken_share` lacked k-anonymity minimum cohort enforcement (`K_ANON_MIN = 5`), publishing a single payer's exact revenue share (e.g., `34.48%` for 20 payers).
- When `churn_risk_count` was suppressed (`<5_suppressed`), `churn_risk_pct` was still emitted, allowing exact count recovery.
- `test_dashboards.py` tests were tautological (`net_rub == gross * 0.72`, `chi2_stat >= 0` with no critical threshold, `odds_consistent` ignoring chi2, no ad-cap breach test).

### Fix
- Applied k-anonymity suppression (`"<5_suppressed"`) to every DB-10 `concentration_pct` slice whenever the slice represents `< K_ANON_MIN` payers (or `n_payers < K_ANON_MIN`) and to `whale_plus_kraken_share` when `whale + kraken < K_ANON_MIN`.
- Suppressed `churn_risk_pct` to `"<5_suppressed"` whenever `churn_risk_count` is suppressed.
- Upgraded DB-03 chi-square audit to compute exact pity-conditioned expected counts per `wish_pull` (`k_before`, aligned with `data/shop.json` / MP §3 rates: `0.015` base, soft pity `60/+0.05`, hard pity `80` / `30` for `first_guest`), exact `chi2_p_value = exp(-chi2 / 2)` for `df=2`, `chi2_critical_99 = 9.210`, `chi2_ok`, and tied `odds_consistent` to both single `odds_hash` and `chi2_ok`.
- Added `cap_violation_user_days` and `cap_excess_rewards` in DB-09 and added non-tautological negative tests (`test_07`, `test_08`) covering small-cohort suppression, churn_risk_pct suppression, rigged gacha chi-square rejection, mixed `odds_hash` rejection, and >3/day ad-cap violation.

### RED → GREEN Evidence
Command: `python tools/dashboards/test_dashboards.py --selftest`

**BEFORE (RED):**
```text
FAIL: test_07_minor3_db10_concentration_and_churn_pct_k_anonymity
  AssertionError: 34.48 != '<5_suppressed'
ERROR: test_08_minor3_non_tautological_chi2_odds_and_ad_cap
  KeyError: 'chi2_critical_99'
DASHBOARDS_SELFTEST 6/8 FAIL
```

**AFTER (GREEN):**
```text
Ran 8 tests in 0.462s
OK
DASHBOARDS_SELFTEST 8/8 PASS
```

---

## 5. Confirmed MAJOR #6 — `modal_soak.gd` Real Screens, Real `main.gd` 0.12.1 Regression & Asserted Coverage

### Root Cause
- `_create_harness` registered all 62 catalog entries with `TWNavFakeScreen`, never instantiating real v11 screens (`TWLegalScreen`, `TWMatchScreen`) or real screen-opened modals.
- `_test_regression_0121` simulated the legacy whitelist sweep inline instead of calling real `res://scripts/main.gd:go()`.
- `_test_random_soak` allowed up to 5 unvisited screens (`visited.size() >= all_ids.size() - 5`) instead of asserting 100% catalog coverage.

### Fix
- Updated `_create_harness` in `game/shell/tests/modal_soak.gd` to run `screens.scan()` first and provide real `TWState`, `TWClock`, `TWBus`, and `ModalStack` (`ctx.provide("modals", stack)`), so real `TWLegalScreen` and `TWMatchScreen` are registered with their real scripts (only unmigrated planned slots fall back to `TWNavFakeScreen`).
- Added `_test_real_v11_screens_and_modals`: mounts real `TWLegalScreen` -> opens real `TWLegalDocModal` -> verifies `go("home")` and `NOTIFICATION_WM_GO_BACK_REQUEST` sweep cleanly with 0 STOP leaks; mounts real `TWMatchScreen` -> clears a real 2-pair board -> verifies real `TWResultModal` opens on `ModalStack` and `go("home")` sweeps it cleanly with 0 STOP leaks.
- Replaced the fake inline 0.12.1 regression in `_test_regression_0121` with `RealLegacyMain extends "res://scripts/main.gd"`: boots real legacy `home`, calls REAL `main.gd:go("levels", ...)` to verify tagged popups are swept while an untagged STOP wrapper leaks (genuine RED on legacy `main.gd`), verifies real `settings()` popup + real `go("home")` clearing, and mounts/closes all 46/46 real legacy screens (including periodic real `Common.confirm()` popups) with 0 leaked STOP blockers.
- Added coverage-guided shuffled deck in `_test_random_soak` and strict 100% coverage assertion (`visited.size() == all_ids.size()`). Kept `lint_modal_only_via_stack.py` at 0 shell violations.

### RED → GREEN Evidence
Command (via `godot_lock.ps1`): `python tools/tw_test.py -s modal_soak --fast`

**BEFORE (RED):**
```text
FAIL real v11 screens: legal and match registered with real scripts (not FAKE_SCREEN) legal=res://shell/nav/nav_fake_screen.gd match=res://shell/nav/nav_fake_screen.gd
MODAL_SOAK_SELFTEST 25/26 (screens=62 shard=1/1 ops=1200 time=8.35s)
```

**AFTER (GREEN):**
```text
PASS 0.12.1 regression (real main.gd): booted real legacy home screen
PASS 0.12.1 regression (real main.gd go()): tagged popup swept, untagged wrapper STOP leaked (RED on legacy)
PASS real legacy main.gd: real settings() popup opens STOP (25) and real go('home') clears it (0 STOP)
PASS real legacy main.gd: mounted and closed 46/46 real legacy screens with 0 leaked STOP blockers
PASS real v11 screen: 'legal' mounts real TWLegalScreen
PASS real v11 modal: TWLegalScreen.open_doc('offer', true) opens real TWLegalDocModal on ModalStack
PASS real v11 modal: go('home') sweeps real TWLegalDocModal with 0 STOP leaks
PASS real v11 modal: Android back closes TWLegalDocModal then leaves TWLegalScreen
PASS real v11 screen: 'match' mounts real TWMatchScreen
PASS real v11 modal: clearing real TWMatchScreen board opens real TWResultModal on ModalStack
PASS real v11 modal: go('home') sweeps real TWResultModal with 0 STOP leaks
PASS real v11 screens: legal and match registered with real scripts (not FAKE_SCREEN)
PASS random soak: 100% screen coverage (62/62 screens visited)
PASS stability: 2 full 61-screen x modal sweeps leak 0 nodes (delta=0)
MODAL_SOAK_SELFTEST 36/36 (screens=62 shard=1/1 ops=1200 time=40.03s)
```

---

## 6. Verification Summary

All suites ran in FULL mode after final edits (Godot serialized via `godot_lock.ps1`):

| Suite / Command | Result | Details |
| --- | --- | --- |
| `node --test server/src/events.test.mjs` | **8/8 PASS** | Schema, privacy/ethics, HMAC/152-FZ, HTTP server, MAJOR #1/#2/#3 |
| `node server/e2e_test.mjs` (`server_e2e`) | **60/60 PASS** | `E2E_OK` (REST + WebSocket PvP + SQLite WAL) |
| `python tools/dashboards/test_dashboards.py --selftest` (`dashboards`) | **8/8 PASS** | `DASHBOARDS_SELFTEST 8/8 PASS` (DB-01..10, MAJOR #3 + MINOR #3) |
| `tw_test.py -s analytics` | **30/30 PASS** | `ANALYTICS_SELFTEST 30/30` (13.3s) |
| `tw_test.py -s modal_soak` (full, 2400 ops) | **36/36 PASS** | `MODAL_SOAK_SELFTEST 36/36` (50.2s; 46/46 real legacy + 2 real v11 + 62/62 coverage) |
| `tw_test.py -s twnav` | **132/132 PASS** | `TWNAV_SELFTEST 132/132` (16.4s) |
| `tw_test.py -s twmodal` | **83/83 PASS** | `TWMODAL_SELFTEST 83/83` (16.3s) |
| `python tools/lint_modal_only_via_stack.py --selftest --check` | **14/14 PASS** | `shell 0 violations; 0 ratchet breaches` |
| `python tools/lint_core_purity.py --selftest --check` | **13/13 PASS** | `baseline 546, +0 new` |
| `python tools/lint_screen_has_spec.py --selftest --check` | **7/7 PASS** | `0 violations` |
| `python tools/lint_asset_id_only.py --selftest --check` | **13/13 PASS** | `shell 0 violations; 0 ratchet breaches` |

Zero hardcoded secrets in source or tests (`grep` verified); `.import` files reverted clean (`git checkout -- ':(glob)**/*.import'`).

---

## Нужна регистрация

Because shared registry and CI files are outside this branch's boundaries, the integrator should wire the following in the integration/merge step:
1. **`.github/workflows/qa.yml`**: Add `modal_soak` (and `analytics`, `dashboards`) to the headless QA workflow suites, plus `node --test server/src/events.test.mjs` alongside `server_e2e`.
2. **`server/server.mjs` / `.env.example`**: When mounting `EventsReceiver` into the main HTTP server entrypoint, pass `{ db, users, hmacSecret: process.env.ANALYTICS_HMAC_SECRET, serverIngestToken: process.env.ANALYTICS_SERVER_INGEST_TOKEN }` and document `ANALYTICS_HMAC_SECRET` (required, >=16 chars) and `ANALYTICS_SERVER_INGEST_TOKEN` in `server/.env.example`.
3. **`tools/baseline.json`**: Update baseline counts for `analytics` (30/30), `modal_soak` (36/36), and `dashboards` (8/8).
