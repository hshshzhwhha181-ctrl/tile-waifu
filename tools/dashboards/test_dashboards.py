#!/usr/bin/env python3
"""Unit tests & selftest for P106 dashboards (DB-01..DB-10) and DB-10 strict anonymization."""
from __future__ import annotations

import json
import re
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from gen_synthetic_events import generate_events  # noqa: E402
from build_dashboards import compute_dashboards, load_events_sqlite, render_html  # noqa: E402

UID_PATTERN = re.compile(r"\bu_[0-9a-f]{8,}\b")
EMAIL_PATTERN = re.compile(r"[^\s@]+@[^\s@]+\.[^\s@]+")
FORBIDDEN_DB10_KEYS = {
    "uid", "uid_hmac", "user_id", "users_list", "player_ids", "nick", "nickname",
    "email", "phone", "birth_date", "personal_discount", "whale_offer", "dynamic_price",
}


def _walk_json(obj, path=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            p = f"{path}.{k}" if path else str(k)
            yield (p, k, v)
            yield from _walk_json(v, p)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from _walk_json(v, f"{path}[{i}]")


class TestDashboardsP106(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.events = generate_events(n_users=800, days=31, seed=20261128)
        cls.report = compute_dashboards(cls.events)
        cls.html = render_html(cls.report)

    def test_01_all_ten_dashboards_live(self) -> None:
        dbs = self.report["dashboards"]
        expected = [f"DB-{i:02d}" for i in range(1, 11)]
        self.assertEqual(sorted(dbs.keys()), expected)
        self.assertGreater(self.report["events_processed"], 5000)

        # DB-01 Funnel
        db01 = dbs["DB-01"]
        self.assertEqual(db01["installs"], 800)
        self.assertGreater(db01["steps"]["ftue_first_win"]["pct_of_installs"], 70.0)
        self.assertGreater(db01["steps"]["first_purchase"]["users"], 15)
        self.assertGreater(len(db01["by_source"]), 2)

        # DB-02 Revenue
        db02 = dbs["DB-02"]
        self.assertGreater(db02["gross_rub"], 10000.0)
        self.assertAlmostEqual(db02["net_rub"], round(db02["gross_rub"] * 0.72, 2), places=2)
        self.assertGreater(db02["arppu_rub"], 100.0)
        self.assertGreater(len(db02["by_sku_rub"]), 2)

        # DB-03 Gacha health
        db03 = dbs["DB-03"]
        self.assertGreaterEqual(len(db03["banners"]), 1)
        for bid, b in db03["banners"].items():
            self.assertGreater(b["pulls"], 50, f"banner {bid} should have pulls")
            self.assertTrue(b["odds_consistent"])
            self.assertGreaterEqual(b["chi2_stat"], 0.0)
        self.assertGreater(db03["mean_pulls_to_featured"], 20.0)

        # DB-04 Economy
        db04 = dbs["DB-04"]
        self.assertIn("gems", db04["sinks_by_currency"])
        self.assertIn("gems", db04["snapshot_buckets"])

        # DB-05 Retention
        db05 = dbs["DB-05"]
        self.assertGreater(db05["retention"]["D1"]["pct"], 15.0)
        self.assertGreater(db05["retention"]["D7"]["pct"], 5.0)
        self.assertGreater(db05["dau_mau_stickiness_pct"], 0.0)

        # DB-06 Payment Ops
        db06 = dbs["DB-06"]
        self.assertGreater(db06["attempts"], 20)
        self.assertGreater(db06["ok"], 15)
        self.assertIn("sbp", db06["methods"])

        # DB-07 LiveOps
        db07 = dbs["DB-07"]
        self.assertGreater(db07["banner_viewers"], 100)
        self.assertGreater(db07["preview_10s_viewers"], 50)

        # DB-08 Compliance
        db08 = dbs["DB-08"]
        self.assertEqual(db08["age_gate_total"], 800)
        self.assertGreater(db08["limit_set_users"], 10)
        self.assertGreater(db08["age_gate_fail_count"], 0)

        # DB-09 Ads
        db09 = dbs["DB-09"]
        self.assertGreater(db09["rewards"], 100)
        self.assertTrue(db09["daily_cap_respected"])
        self.assertLessEqual(db09["max_rewards_per_user_day"], 3)

    def test_02_db10_strict_anonymization_and_policy(self) -> None:
        db10 = self.report["dashboards"]["DB-10"]
        self.assertTrue(db10["anonymized"])
        self.assertFalse(db10["individual_ids_present"])
        self.assertFalse(db10["pii_present"])
        self.assertEqual(db10["policy"], "support_and_thanks_only_no_targeted_discounts")
        self.assertGreater(db10["concentration_pct"]["top_10_pct_payers"], 0.0)

        # Recursive audit: ZERO uids, ZERO emails, ZERO forbidden keys anywhere in DB-10
        for path, k, v in _walk_json(db10):
            self.assertNotIn(str(k).lower(), FORBIDDEN_DB10_KEYS, f"Forbidden key in DB-10 at {path}")
            if isinstance(v, str):
                self.assertIsNone(UID_PATTERN.search(v), f"Leaked uid in DB-10 at {path}: {v}")
                self.assertIsNone(EMAIL_PATTERN.search(v), f"Leaked email in DB-10 at {path}: {v}")

        # Raw serialized DB-10 string check
        raw = json.dumps(db10, ensure_ascii=False)
        self.assertIsNone(UID_PATTERN.search(raw))
        self.assertNotIn("personal_discount", raw)

        # HTML section for DB-10 also contains ZERO uids
        m = re.search(r'<section[^>]*id="DB-10"[^>]*>(.*?)</section>', self.html, re.S)
        self.assertIsNotNone(m, "DB-10 section missing in rendered HTML")
        self.assertIsNone(UID_PATTERN.search(m.group(1)))

    def test_03_db10_k_anonymity_suppression(self) -> None:
        # Minimal stream with only 2 rank_up users -> must be suppressed (<5_suppressed)
        tiny = [
            {"event": "app_open", "ts": 1761955200000, "uid": "u_aaaa1111bbbb2222", "sess": "s1", "app_ver": "0.12.0", "build": "rustore", "lang": "ru", "tier": "standard", "age_ok": True, "conn": "wifi", "ev_ver": 1, "params": {"src": "organic"}},
            {"event": "purchase_ok", "ts": 1761955210000, "uid": "u_aaaa1111bbbb2222", "sess": "s1", "app_ver": "0.12.0", "build": "rustore", "lang": "ru", "tier": "standard", "age_ok": True, "conn": "wifi", "ev_ver": 1, "params": {"sku_id": "pack_9990", "price_rub": 9990, "method": "sbp", "purchase_id": "p1", "category": "moon_pack"}},
            {"event": "rank_up", "ts": 1761955220000, "uid": "u_aaaa1111bbbb2222", "sess": "s1", "app_ver": "0.12.0", "build": "rustore", "lang": "ru", "tier": "standard", "age_ok": True, "conn": "wifi", "ev_ver": 1, "params": {"from": 0, "to": 3}},
        ]
        rep = compute_dashboards(tiny)
        db10 = rep["dashboards"]["DB-10"]
        self.assertEqual(db10["circle_rank_cohorts"]["rank_3_plus"]["cohort_size_band"], "<5_suppressed")
        self.assertIsNone(UID_PATTERN.search(json.dumps(db10)))

    def test_04_sqlite_roundtrip_compatibility(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            db_path = Path(td) / "events.db"
            conn = sqlite3.connect(str(db_path))
            conn.executescript("""
                CREATE TABLE analytics_events (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  event_name TEXT NOT NULL,
                  ts_ms INTEGER NOT NULL,
                  day_utc TEXT NOT NULL,
                  uid_hmac TEXT NOT NULL,
                  sess TEXT NOT NULL,
                  app_ver TEXT NOT NULL,
                  build TEXT NOT NULL,
                  lang TEXT NOT NULL,
                  tier TEXT NOT NULL,
                  age_ok INTEGER NOT NULL,
                  conn TEXT NOT NULL,
                  ev_ver INTEGER NOT NULL,
                  params_json TEXT NOT NULL,
                  ingested_at INTEGER NOT NULL
                );
            """)
            sample = self.events[:400]
            for e in sample:
                conn.execute(
                    "INSERT INTO analytics_events (event_name, ts_ms, day_utc, uid_hmac, sess, app_ver, build, lang, tier, age_ok, conn, ev_ver, params_json, ingested_at) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    (e["event"], e["ts"], "2025-11-01", e["uid"], e["sess"], e["app_ver"], e["build"], e["lang"], e["tier"], 1 if e["age_ok"] else 0, e["conn"], e["ev_ver"], json.dumps(e["params"]), 1761955200),
                )
            conn.commit()
            conn.close()

            loaded = load_events_sqlite(db_path)
            self.assertEqual(len(loaded), len(sample))
            rep = compute_dashboards(loaded)
            self.assertEqual(len(rep["dashboards"]), 10)
            self.assertTrue(rep["dashboards"]["DB-10"]["anonymized"])

    def test_05_html_contains_all_ten_cards(self) -> None:
        for i in range(1, 11):
            self.assertIn(f'id="DB-{i:02d}"', self.html)


def main() -> int:
    if "--selftest" in sys.argv:
        sys.argv.remove("--selftest")
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(TestDashboardsP106)
        runner = unittest.TextTestRunner(verbosity=2)
        res = runner.run(suite)
        ok = res.testsRun - len(res.failures) - len(res.errors)
        status = "PASS" if res.wasSuccessful() else "FAIL"
        print(f"DASHBOARDS_SELFTEST {ok}/{res.testsRun} {status}")
        return 0 if res.wasSuccessful() else 1
    unittest.main()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
