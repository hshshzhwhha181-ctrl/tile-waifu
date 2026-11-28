# P106 — Analytics Dashboards (DB-01…DB-10)

Implements the 10 analytics dashboards from `design/specs/MONETIZATION_PLAN.md` §7.3 on top of the §7.4 event schema (`game/core/analytics/` + `server/src/events.mjs`).

## Usage
```bash
# 1. Generate deterministic synthetic data (800 users, 31 days)
python tools/dashboards/gen_synthetic_events.py --out tmp/synth.ndjson

# 2. Build all 10 dashboards (JSON + HTML) from NDJSON or SQLite DB
python tools/dashboards/build_dashboards.py --input tmp/synth.ndjson --out-dir tmp/dashboards
# or directly in-memory synthetic run:
python tools/dashboards/build_dashboards.py --synthetic --out-dir tmp/dashboards

# 3. Run unit tests / selftest (includes strict DB-10 anonymization & k-anonymity audit)
python tools/dashboards/test_dashboards.py --selftest
```

## Privacy & Ethics Guarantees
- **No PII**: no birth dates, nicknames, emails, phone numbers, raw IPs, or raw account IDs.
- **No personalized discounts by spend profile**: rejected at both core schema (`TWAnalyticsSchema`) and server ingest (`server/src/events.mjs`).
- **DB-10 («Радар китов»)**: strictly anonymized (`anonymized: true`, `individual_ids_present: false`, `pii_present: false`, k-anonymity cell suppression `<5`, policy `support_and_thanks_only_no_targeted_discounts`).
