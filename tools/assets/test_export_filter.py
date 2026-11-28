#!/usr/bin/env python3
"""Subprocess & CLI exit-code tests for tools/assets/export_filter.py (P92 / T3 & T12)."""
from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE / "export_filter.py"
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import export_filter as ef  # noqa: E402


def _run_cli(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True,
        text=True,
        check=False,
    )


class TestExportFilterCLI(unittest.TestCase):
    def test_01_selftest_exits_zero(self) -> None:
        r = _run_cli("--selftest")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("EXPORT_FILTER SELFTEST 14/14 PASS", r.stdout)

    def test_02_check_apk_skins_dl_returns_red(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            apk = Path(td) / "bad_skins_dl.apk"
            pck = ef._build_synthetic_pck({
                "res://skins_dl/akari_ssr/1.0/manifest.json": b"{}",
                f"res://{ef.PACK_PUB_REL}": ef.SAMPLE_VALID_PUB_PEM,
            })
            with zipfile.ZipFile(apk, "w") as zf:
                zf.writestr("assets/main.pck", pck)
            r = _run_cli("--check-apk", str(apk))
            self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
            self.assertIn("T3_SKINS_DL_IN_ARCHIVE", r.stdout)

    def test_03_check_apk_missing_pub_key_returns_red(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            apk = Path(td) / "missing_pub.apk"
            pck = ef._build_synthetic_pck({"res://skins_base/hana_base/manifest.json": b"{}"})
            with zipfile.ZipFile(apk, "w") as zf:
                zf.writestr("assets/main.pck", pck)
            r = _run_cli("--check-apk", str(apk))
            self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
            self.assertIn("T12_MISSING_PUB_KEY", r.stdout)

    def test_04_check_apk_clean_returns_green(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            apk = Path(td) / "clean.apk"
            pck = ef._build_synthetic_pck({
                "res://skins_base/hana_base/manifest.json": b"{}",
                f"res://{ef.PACK_PUB_REL}": ef.SAMPLE_VALID_PUB_PEM,
            })
            with zipfile.ZipFile(apk, "w") as zf:
                zf.writestr("assets/main.pck", pck)
            r = _run_cli("--check-apk", str(apk))
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn("EXPORT_FILTER APK_CHECK: PASS", r.stdout)

    def test_05_check_pub_key_and_apply_on_temp_game(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            g = Path(td) / "game"
            (g / "scripts").mkdir(parents=True)
            (g / "scripts" / "main.gd").write_text("extends Node\n", encoding="utf-8")
            (g / "export_presets.cfg").write_text(
                ef._sample_presets_cfg(include_pub=False, exclude_skins_dl=False),
                encoding="utf-8",
            )
            # Missing pub key -> RED
            r_miss = _run_cli("--game", str(g), "--check-pub-key")
            self.assertEqual(r_miss.returncode, 1, r_miss.stdout)
            self.assertIn("T12_MISSING_PUB_KEY", r_miss.stdout)

            # Broken presets -> RED
            r_bad_cfg = _run_cli("--game", str(g), "--check")
            self.assertEqual(r_bad_cfg.returncode, 1, r_bad_cfg.stdout)

            # Provision valid key + run --apply -> both GREEN
            pub = g / ef.PACK_PUB_REL
            pub.parent.mkdir(parents=True, exist_ok=True)
            pub.write_bytes(ef.SAMPLE_VALID_PUB_PEM)
            r_apply = _run_cli("--game", str(g), "--apply")
            self.assertEqual(r_apply.returncode, 0, r_apply.stdout + r_apply.stderr)

            r_ok_pub = _run_cli("--game", str(g), "--check-pub-key")
            self.assertEqual(r_ok_pub.returncode, 0, r_ok_pub.stdout)
            r_ok_cfg = _run_cli("--game", str(g), "--check")
            self.assertEqual(r_ok_cfg.returncode, 0, r_ok_cfg.stdout)
            self.assertIn("EXPORT_FILTER CHECK: PASS", r_ok_cfg.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
