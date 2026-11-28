#!/usr/bin/env python3
"""Unit tests for tools/qa/check_pending_gate.py (P96 Date X & T19 rc 134 policy)."""
from __future__ import annotations

import datetime as dt
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import check_pending_gate as cpg  # noqa: E402


class TestPendingGate(unittest.TestCase):
    def test_parses_date_x_from_thresholds(self) -> None:
        d = cpg.parse_pending_deadline(cpg.DEFAULT_THRESHOLDS)
        self.assertEqual(d, dt.date(2026, 12, 12))

    def test_pending_warns_before_date_x_and_fails_on_or_after(self) -> None:
        with tempfile.TemporaryDirectory(prefix="tw_pg_") as tmp:
            log = Path(tmp) / "golden.log"
            log.write_text("GOLDEN PENDING home/mc_base/720x1280/idle.png\n", encoding="utf-8")
            before = cpg.evaluate_pending_gate([log], cpg.DEFAULT_THRESHOLDS, today=dt.date(2026, 12, 11))
            self.assertTrue(before["ok"])
            self.assertEqual(before["status"], "WARN")
            self.assertEqual(before["pending_count"], 1)

            on_day = cpg.evaluate_pending_gate([log], cpg.DEFAULT_THRESHOLDS, today=dt.date(2026, 12, 12))
            self.assertFalse(on_day["ok"])
            self.assertEqual(on_day["status"], "FAIL")

            strict_before = cpg.evaluate_pending_gate([log], cpg.DEFAULT_THRESHOLDS, today=dt.date(2026, 12, 1), strict=True)
            self.assertFalse(strict_before["ok"])
            self.assertEqual(strict_before["status"], "FAIL")

    def test_zero_pending_passes_even_after_date_x(self) -> None:
        with tempfile.TemporaryDirectory(prefix="tw_pg_") as tmp:
            log = Path(tmp) / "soak.log"
            log.write_text("TWSKINSOAK PIXEL_CHECK PASS\nTWSKINSOAK_SELFTEST 2400/2400 OK pending=0\n", encoding="utf-8")
            res = cpg.evaluate_pending_gate([log], cpg.DEFAULT_THRESHOLDS, today=dt.date(2027, 1, 1))
            self.assertTrue(res["ok"])
            self.assertEqual(res["status"], "OK")
            self.assertEqual(res["pending_count"], 0)


class TestRc134Policy(unittest.TestCase):
    def test_rc134_passes_after_green_marker_without_script_error(self) -> None:
        out = "info line\nTWSKINSOAK_SELFTEST 2400/2400 OK pending=0\nmalloc_consolidate(): invalid chunk size\n"
        res = cpg.evaluate_rc134_policy(out, "TWSKINSOAK_SELFTEST", 134)
        self.assertTrue(res["ok"], msg=res)
        res_neg6 = cpg.evaluate_rc134_policy(out, "TWSKINSOAK_SELFTEST", -6)
        self.assertTrue(res_neg6["ok"], msg=res_neg6)

    def test_rc134_fails_if_script_error_after_marker(self) -> None:
        out = "TWSKINSOAK_SELFTEST 2400/2400 OK pending=0\nSCRIPT ERROR: Trying to call freed object\n"
        res = cpg.evaluate_rc134_policy(out, "TWSKINSOAK_SELFTEST", 134)
        self.assertFalse(res["ok"])
        self.assertIn("SCRIPT ERROR", res["reason"])

    def test_rc134_fails_without_green_marker(self) -> None:
        out = "TWSKINSOAK_SELFTEST 2399/2400 FAILED pending=0\n"
        res = cpg.evaluate_rc134_policy(out, "TWSKINSOAK_SELFTEST", 134)
        self.assertFalse(res["ok"])

    def test_rc134_fails_when_marker_missing(self) -> None:
        out = "aborted early before marker\n"
        res = cpg.evaluate_rc134_policy(out, "TWSKINSOAK_SELFTEST", 134)
        self.assertFalse(res["ok"])

    def test_sigsegv_139_never_tolerated(self) -> None:
        out = "TWSKINSOAK_SELFTEST 2400/2400 OK pending=0\n"
        res = cpg.evaluate_rc134_policy(out, "TWSKINSOAK_SELFTEST", 139)
        self.assertFalse(res["ok"])
        self.assertIn("139", res["reason"])


if __name__ == "__main__":
    unittest.main()
