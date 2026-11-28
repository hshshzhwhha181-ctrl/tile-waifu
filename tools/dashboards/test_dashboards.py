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

        # DB-02 Revenue (net subtracts refunds before applying NET_MARGIN)
        db02 = dbs["DB-02"]
        self.assertGreater(db02["gross_rub"], 10000.0)
        self.assertAlmostEqual(
            db02["net_rub"],
            round(max(0.0, db02["gross_rub"] - db02["refund_rub"]) * 0.72, 2),
            places=2,
        )
        self.assertGreater(db02["arppu_rub"], 100.0)
        self.assertGreater(len(db02["by_sku_rub"]), 2)

        # DB-03 Gacha health (real chi-square goodness-of-fit against pity-conditioned expectations)
        db03 = dbs["DB-03"]
        self.assertGreaterEqual(len(db03["banners"]), 1)
        for bid, b in db03["banners"].items():
            self.assertGreater(b["pulls"], 50, f"banner {bid} should have pulls")
            self.assertTrue(b["chi2_ok"], f"banner {bid} chi2={b['chi2_stat']} exceeded critical {b['chi2_critical_99']}")
            self.assertLessEqual(b["chi2_stat"], b["chi2_critical_99"])
            self.assertGreaterEqual(b["chi2_p_value"], 0.01)
            self.assertTrue(b["odds_consistent"])
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
        # Enforce k-anonymity rule across all concentration slices based on payer cohort size
        n_payers = self.report["dashboards"]["DB-02"]["payers"]
        for field, frac in (
            ("top_1_pct_payers", 0.01),
            ("top_5_pct_payers", 0.05),
            ("top_10_pct_payers", 0.10),
            ("top_25_pct_payers", 0.25),
        ):
            val = db10["concentration_pct"][field]
            if int(-(-n_payers * frac // 1)) < 5:
                self.assertEqual(val, "<5_suppressed", f"{field} with n_payers={n_payers} must be suppressed")
            else:
                self.assertIsInstance(val, float)
                self.assertGreater(val, 0.0)
        # In the 800-user sample (~40 payers), top 1% and top 5% must be suppressed
        self.assertEqual(db10["concentration_pct"]["top_1_pct_payers"], "<5_suppressed")
        self.assertEqual(db10["concentration_pct"]["top_5_pct_payers"], "<5_suppressed")

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
                  event_id TEXT NOT NULL,
                  source TEXT NOT NULL DEFAULT 'client',
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
            for idx, e in enumerate(sample):
                conn.execute(
                    "INSERT INTO analytics_events (event_id, source, event_name, ts_ms, day_utc, uid_hmac, sess, app_ver, build, lang, tier, age_ok, conn, ev_ver, params_json, ingested_at) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    (f"ev_{idx}", e.get("source", "client"), e["event"], e["ts"], "2025-11-01", e["uid"], e["sess"], e["app_ver"], e["build"], e["lang"], e["tier"], 1 if e["age_ok"] else 0, e["conn"], e["ev_ver"], json.dumps(e["params"]), 1761955200),
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

    def test_06_major3_revenue_dedup_server_source_and_refund_subtraction(self) -> None:
        base_env = {
            "sess": "s1", "app_ver": "0.12.0", "build": "rustore", "lang": "ru",
            "tier": "standard", "age_ok": True, "conn": "wifi", "ev_ver": 1,
        }
        evs = [
            {**base_env, "event": "app_open", "ts": 1761955200000, "uid": "u_aaaa1111bbbb2222", "params": {"src": "organic"}},
            # Legitimate server-verified purchase_ok
            {**base_env, "event": "purchase_ok", "source": "server", "ts": 1761955210000, "uid": "u_aaaa1111bbbb2222",
             "params": {"sku_id": "pack_1000", "price_rub": 1000, "method": "sbp", "purchase_id": "ord_1", "category": "moon_pack"}},
            # Replay of same purchase_id -> MUST be deduplicated
            {**base_env, "event": "purchase_ok", "source": "server", "ts": 1761955215000, "uid": "u_aaaa1111bbbb2222",
             "params": {"sku_id": "pack_1000", "price_rub": 1000, "method": "sbp", "purchase_id": "ord_1", "category": "moon_pack"}},
            # Forged client-sourced purchase_ok -> MUST be ignored in revenue
            {**base_env, "event": "purchase_ok", "source": "client", "ts": 1761955220000, "uid": "u_aaaa1111bbbb2222",
             "params": {"sku_id": "pack_fake", "price_rub": 99999, "method": "sbp", "purchase_id": "ord_fake", "category": "moon_pack"}},
            # Malformed price_rub='abc' -> MUST NOT crash
            {**base_env, "event": "purchase_ok", "source": "server", "ts": 1761955225000, "uid": "u_aaaa1111bbbb2222",
             "params": {"sku_id": "pack_bad", "price_rub": "abc", "method": "sbp", "purchase_id": "ord_bad", "category": "moon_pack"}},
            # Server-verified refund of 200 RUB -> MUST reduce net_rub
            {**base_env, "event": "purchase_refund", "source": "server", "ts": 1761955230000, "uid": "u_aaaa1111bbbb2222",
             "params": {"sku_id": "pack_1000", "amount": 200, "debt_after": 0, "days_since": 1}},
        ]
        rep = compute_dashboards(evs)
        db02 = rep["dashboards"]["DB-02"]
        db06 = rep["dashboards"]["DB-06"]
        self.assertEqual(db02["gross_rub"], 1000.0, "replayed and client-forged purchases must not inflate gross_rub")
        self.assertEqual(db02["refund_rub"], 200.0)
        self.assertEqual(db02["net_rub"], round((1000.0 - 200.0) * 0.72, 2), "purchase_refund must be subtracted before NET_MARGIN")
        self.assertLess(db02["net_rub"], round(db02["gross_rub"] * 0.72, 2))
        self.assertGreaterEqual(db06["unverified_client_purchases_ignored"], 1)
        self.assertGreaterEqual(db06["duplicate_purchases_ignored"], 1)

    def test_07_minor3_db10_concentration_and_churn_pct_k_anonymity(self) -> None:
        base_env = {
            "sess": "s1", "app_ver": "0.12.0", "build": "rustore", "lang": "ru",
            "tier": "standard", "age_ok": True, "conn": "wifi", "ev_ver": 1,
        }
        day_ms = 86_400_000
        t0 = 1761955200000
        evs = []
        # 20 payers: top 1% = 1 (<5), top 5% = 1 (<5), top 10% = 2 (<5), top 25% = 5 (>=5)
        for i in range(20):
            uid = f"u_{i:032x}"
            price = 10000 if i < 2 else 500  # 2 whales (<5), 18 minnows
            evs.append({**base_env, "event": "app_open", "ts": t0, "uid": uid, "params": {"src": "organic"}})
            evs.append({**base_env, "event": "purchase_ok", "source": "server", "ts": t0 + 1000, "uid": uid,
                        "params": {"sku_id": "s1", "price_rub": price, "method": "sbp", "purchase_id": f"p_{i}", "category": "moon_pack"}})
            # First 10 users reach rank 1; only 2 of them (<5) become inactive >= 7d
            if i < 10:
                evs.append({**base_env, "event": "rank_up", "ts": t0 + 2000, "uid": uid, "params": {"from": 0, "to": 1}})
                if i >= 2:
                    evs.append({**base_env, "event": "session_start", "ts": t0 + 10 * day_ms, "uid": uid, "params": {"src": "organic"}})
            else:
                evs.append({**base_env, "event": "session_start", "ts": t0 + 10 * day_ms, "uid": uid, "params": {"src": "organic"}})

        rep = compute_dashboards(evs)
        db10 = rep["dashboards"]["DB-10"]
        conc = db10["concentration_pct"]
        self.assertEqual(conc["top_1_pct_payers"], "<5_suppressed")
        self.assertEqual(conc["top_5_pct_payers"], "<5_suppressed")
        self.assertEqual(conc["top_10_pct_payers"], "<5_suppressed")
        self.assertIsInstance(conc["top_25_pct_payers"], float)
        self.assertEqual(conc["whale_plus_kraken_share"], "<5_suppressed")

        r1 = db10["circle_rank_cohorts"]["rank_1"]
        self.assertEqual(r1["cohort_size"], 10)
        self.assertEqual(r1["churn_risk_count"], "<5_suppressed")
        self.assertEqual(r1["churn_risk_pct"], "<5_suppressed", "churn_risk_pct must be suppressed when churn_risk_count is suppressed")

    def test_08_minor3_non_tautological_chi2_odds_and_ad_cap(self) -> None:
        base_env = {
            "sess": "s1", "app_ver": "0.12.0", "build": "rustore", "lang": "ru",
            "tier": "standard", "age_ok": True, "conn": "wifi", "ev_ver": 1,
        }
        t0 = 1761955200000
        # 1. Rigged banner (1000 pulls: 200 SSR instead of ~22.5 -> massive chi2 failure) + mixed odds hashes + ad cap breach (4 rewards/day)
        evs = [{**base_env, "event": "app_open", "ts": t0, "uid": "u_00000000000000000000000000000001", "params": {"src": "organic"}}]
        for i in range(1000):
            res = "ssr" if i < 200 else ("s" if i < 280 else "gift")
            evs.append({
                **base_env, "event": "wish_pull", "ts": t0 + 1000 + i * 10,
                "uid": "u_00000000000000000000000000000001",
                "params": {
                    "banner_id": "rigged_banner", "family": "standard", "idx": i + 1,
                    "k_before": 0, "g_before": 0, "c_before": 0, "result": res,
                    "item_id": "x", "featured": res == "ssr", "candle": False,
                    "cost_cur": "gems", "cost_amt": 150, "odds_hash": "h1", "seed_commit": f"c_{i}",
                },
            })
        # Mixed odds_hash banner
        for i, oh in enumerate(("h1", "h2")):
            evs.append({
                **base_env, "event": "wish_pull", "ts": t0 + 20000 + i * 10,
                "uid": "u_00000000000000000000000000000001",
                "params": {
                    "banner_id": "mixed_hash_banner", "family": "standard", "idx": i + 1,
                    "k_before": 0, "g_before": 0, "c_before": 0, "result": "gift",
                    "item_id": "x", "featured": False, "candle": False,
                    "cost_cur": "gems", "cost_amt": 150, "odds_hash": oh, "seed_commit": f"m_{i}",
                },
            })
        # 4 ad_reward events in one day -> violates 3/day cap
        for i in range(4):
            evs.append({
                **base_env, "event": "ad_reward", "ts": t0 + 30000 + i * 1000,
                "uid": "u_00000000000000000000000000000001",
                "params": {"placement": "daily_bonus", "ecpm_bucket": "200_250"},
            })

        rep = compute_dashboards(evs)
        rigged = rep["dashboards"]["DB-03"]["banners"]["rigged_banner"]
        self.assertGreater(rigged["chi2_stat"], rigged["chi2_critical_99"])
        self.assertLess(rigged["chi2_p_value"], 0.01)
        self.assertFalse(rigged["chi2_ok"], "rigged banner must fail chi2_ok")
        self.assertFalse(rigged["odds_consistent"], "rigged banner must fail odds_consistent")

        mixed = rep["dashboards"]["DB-03"]["banners"]["mixed_hash_banner"]
        self.assertFalse(mixed["odds_consistent"], "mixed odds_hash must fail odds_consistent")

        db09 = rep["dashboards"]["DB-09"]
        self.assertFalse(db09["daily_cap_respected"], "4 rewards/user/day must trip daily_cap_respected=False")
        self.assertEqual(db09["cap_violation_user_days"], 1)
        self.assertEqual(db09["cap_excess_rewards"], 1)


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
