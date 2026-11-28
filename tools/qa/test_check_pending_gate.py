#!/usr/bin/env python3
"""Unit tests for tools/qa/check_pending_gate.py (P96 Date X & T19 rc 134 policy)."""
from __future__ import annotations

import datetime as dt
import re
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[1]
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

    def test_skin_swap_soak_pending_lines_and_dir_logs_fail_after_date_x(self) -> None:
        sample_soak = "\n".join([
            "TWSKINSOAK PIXEL_CHECK PASS",
            "TWSKINSOAK PENDING TWSkinHost state machine IDLE/PREPARING/STAGED/COMMITTING/ROLLBACK",
            "TWSKINSOAK PENDING TWPalette.resolve/mix parity against real TWPalette golden table",
            "TWSKINSOAK PENDING TWSkin.apply rejects locked tokens itself (gap G-01); AT-S23",
            "TWSKINSOAK PENDING texture memory returns to baseline after 50 swaps (AT-S30)",
            "TWSKINSOAK PENDING pack mount of .pck on a RELEASE Android build (AT-S14)",
            "TWSKINSOAK PENDING slot-loss matrix (AT-S03)",
            "TWSKINSOAK_SELFTEST 2400/2400 OK pending=6",
        ]) + "\n"
        with tempfile.TemporaryDirectory(prefix="tw_pg_") as tmp:
            root = Path(tmp)
            soak_log = root / "skin_swap_soak.log"
            soak_log.write_text(sample_soak, encoding="utf-8")
            suite_dir = root / "logs"
            suite_dir.mkdir()
            (suite_dir / "twboardview.log").write_text("TWBOARDVIEW OK\n", encoding="utf-8")
            (suite_dir / "responsive.log").write_text("GOLDEN PENDING responsive/720x1280.png\n", encoding="utf-8")

            res = cpg.evaluate_pending_gate(
                [soak_log, suite_dir],
                cpg.DEFAULT_THRESHOLDS,
                today=dt.date(2026, 12, 12),
            )
            self.assertFalse(res["ok"])
            self.assertEqual(res["status"], "FAIL")
            self.assertEqual(res["pending_count"], 7, msg=res)


class TestQaRenderWiringAndPinning(unittest.TestCase):
    def test_workflow_passes_raw_soak_and_render_logs_without_lossy_grep(self) -> None:
        wf = (REPO_ROOT / ".github" / "workflows" / "qa-render.yml").read_text(encoding="utf-8")
        # Must NOT filter soak log through grep -E "PIXEL_CHECK|GOLDEN" (drops TWSKINSOAK PENDING lines)
        self.assertNotIn("golden_scan.log", wf)
        self.assertNotRegex(wf, r'grep\s+-E\s+"PIXEL_CHECK\|GOLDEN"')
        # Must pass both raw skin_swap_soak.log and render-suites logs directory to check_pending_gate.py
        gate_idx = wf.find("Enforce golden PENDING -> FAIL gate")
        self.assertNotEqual(gate_idx, -1)
        gate_block = wf[gate_idx:]
        self.assertIn("qa-render-out/skin_swap_soak.log", gate_block)
        self.assertIn("qa-render-out/logs", gate_block)

    def test_workflow_has_permissions_sha_pinned_actions_and_scoped_cache(self) -> None:
        wf = (REPO_ROOT / ".github" / "workflows" / "qa-render.yml").read_text(encoding="utf-8")
        self.assertRegex(wf, r"(?m)^permissions:\s*\n\s+contents:\s*read\b")
        uses_lines = re.findall(r"(?m)^\s*-?\s*uses:\s*([^\s#]+)", wf)
        self.assertGreaterEqual(len(uses_lines), 5)
        for u in uses_lines:
            self.assertRegex(
                u,
                r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40}$",
                msg=f"Action must be pinned to a 40-char commit SHA, got: {u}",
            )
        # Must not use overly broad cross-Dockerfile cache restore key
        self.assertNotRegex(wf, r"(?m)^\s*restore-keys:\s*godot-render-import-\s*$")

    def test_dockerfile_pins_base_digest_apt_versions_and_fail_closed_godot_sha(self) -> None:
        df = (REPO_ROOT / "docker" / "qa-render" / "Dockerfile").read_text(encoding="utf-8")
        # Base image pinned by digest
        self.assertRegex(df, r"(?m)^FROM\s+ubuntu:24\.04@sha256:[0-9a-f]{64}\s*$")
        # Godot SHA-256 pinned to official 4.5.1 digest and checked unconditionally (fail closed)
        self.assertIn(
            'ARG GODOT_SHA256="02ec53d1cc7dbb9cc6355393c61b9ab43d1244751a124f10248a4802830788cd"',
            df,
        )
        self.assertNotRegex(df, r'if\s+\[\s*-n\s+"\$\{GODOT_SHA256\}"\s*\]')
        self.assertIn("sha256sum -c -", df)
        # Ubuntu snapshot pinned + critical rendering apt packages version-pinned via ARGs
        self.assertRegex(df, r"(?m)^ARG\s+APT_SNAPSHOT=\d{8}T\d{6}Z\s*$")
        self.assertIn("snapshot.ubuntu.com", df)
        for pkg_pin in (
            "libgl1-mesa-dri=${MESA_PKG_VERSION}",
            "libglx-mesa0=${MESA_PKG_VERSION}",
            "libegl-mesa0=${MESA_PKG_VERSION}",
            "libllvm${LLVM_VERSION}=${LLVM_PKG_VERSION}",
            "xvfb=${XVFB_PKG_VERSION}",
            "fontconfig=${FONTCONFIG_PKG_VERSION}",
            "fonts-dejavu-core=${FONTS_DEJAVU_PKG_VERSION}",
            "fonts-noto-core=${FONTS_NOTO_PKG_VERSION}",
        ):
            self.assertIn(pkg_pin, df, msg=f"Dockerfile missing pinned package: {pkg_pin}")
        # Ensure MESA_PKG_VERSION ARG is non-empty
        self.assertRegex(df, r'(?m)^ARG\s+MESA_PKG_VERSION="[^"]+"')


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
