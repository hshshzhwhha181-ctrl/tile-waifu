#!/usr/bin/env python3
"""Unit tests for tools/design_lint.py (P93 / W17 MD <-> JSON CI linter)."""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
import design_lint as dl  # noqa: E402

REL_FILES = [
    "data/skins.json",
    "data/shop.json",
    "design/specs/ult_catalogue.json",
    "design/specs/MONETIZATION_PLAN.md",
    "design/specs/SKIN_HUD_SYSTEM.md",
    "design/specs/BATTLE_ULT_SPEC.md",
    "design/specs/ULT_CATALOGUE.md",
    "design/specs/LIVEOPS_CALENDAR.md",
]


def make_sandbox() -> tempfile.TemporaryDirectory[str]:
    td = tempfile.TemporaryDirectory(prefix="tw_test_dl_")
    dst = Path(td.name)
    for rel in REL_FILES:
        target = dst / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(REPO_ROOT / rel, target)
    return td


class TestDesignLint(unittest.TestCase):
    def test_clean_repo_passes_and_returns_zero(self) -> None:
        rep = dl.run_lint(REPO_ROOT)
        self.assertTrue(rep.ok, msg=f"Unexpected errors: {rep.errors}")
        self.assertGreaterEqual(rep.passed, 50)
        rc = dl.main(["--root", str(REPO_ROOT), "--check"])
        self.assertEqual(rc, 0)

    def test_builtin_selftest_passes(self) -> None:
        ok, total, fails = dl.run_selftest(REPO_ROOT)
        self.assertEqual(ok, total, msg=f"Selftest failures: {fails}")
        self.assertGreaterEqual(total, 9)

    def test_cli_json_output_and_nonzero_on_mismatch(self) -> None:
        with make_sandbox() as tmp:
            root = Path(tmp)
            p = root / "design/specs/BATTLE_ULT_SPEC.md"
            p.write_text(
                p.read_text(encoding="utf-8").replace("| 3 600 / 300 |", "| 1 800 / 150 |", 1),
                encoding="utf-8",
            )
            out_json = root / "report.json"
            proc = subprocess.run(
                [sys.executable, str(REPO_ROOT / "tools/design_lint.py"), "--root", str(root), "--json", str(out_json)],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(proc.returncode, 0, msg="CLI must exit non-zero on discrepancy")
            data = json.loads(out_json.read_text(encoding="utf-8"))
            self.assertFalse(data["ok"])
            codes = {e["code"] for e in data["errors"]}
            self.assertIn("BU-2.7-PETALS-PRICES", codes)

    def test_skins_vs_shop_tier_price_mismatch_fails(self) -> None:
        with make_sandbox() as tmp:
            root = Path(tmp)
            p = root / "data/shop.json"
            doc = json.loads(p.read_text(encoding="utf-8"))
            doc["outfit_pricing"]["ssrp"]["petals"] = 1800
            p.write_text(json.dumps(doc, ensure_ascii=False, indent=2), encoding="utf-8")
            rep = dl.run_lint(root)
            self.assertFalse(rep.ok)
            codes = {e["code"] for e in rep.errors}
            self.assertIn("JSON-SYNC-TIER-SSRP", codes)
            self.assertIn("MP-4.5-OUTFIT-LADDER", codes)

    def test_ult_catalogue_id_drift_fails(self) -> None:
        with make_sandbox() as tmp:
            root = Path(tmp)
            p = root / "design/specs/ult_catalogue.json"
            doc = json.loads(p.read_text(encoding="utf-8"))
            doc["ults"][0]["id"] = "mc_base_typo"
            p.write_text(json.dumps(doc, ensure_ascii=False, indent=2), encoding="utf-8")
            rep = dl.run_lint(root)
            self.assertFalse(rep.ok)
            self.assertIn("ULT-JSON-ID-SET", {e["code"] for e in rep.errors})

    def test_ult_catalogue_md_drift_fails(self) -> None:
        with make_sandbox() as tmp:
            root = Path(tmp)
            p = root / "design/specs/ULT_CATALOGUE.md"
            p.write_text(
                p.read_text(encoding="utf-8").replace("| `yue_ssr_scalearmor` | SSR | S1 |", "| `yue_ssr_scalearmor` | SSR | S2 |", 1),
                encoding="utf-8",
            )
            rep = dl.run_lint(root)
            self.assertFalse(rep.ok)
            self.assertIn("ULT-MD-SYNC", {e["code"] for e in rep.errors})

    def test_mp_layer_b_ult_threshold_drift_fails(self) -> None:
        with make_sandbox() as tmp:
            root = Path(tmp)
            p = root / "design/specs/MONETIZATION_PLAN.md"
            p.write_text(
                p.read_text(encoding="utf-8").replace("порог ульты 8, заряд 0", "порог ульты 6, заряд 0", 1),
                encoding="utf-8",
            )
            rep = dl.run_lint(root)
            self.assertFalse(rep.ok)
            self.assertIn("MP-ULT-THRESHOLDS", {e["code"] for e in rep.errors})

    def test_sh_pass_s_header_drift_fails(self) -> None:
        with make_sandbox() as tmp:
            root = Path(tmp)
            p = root / "design/specs/SKIN_HUD_SYSTEM.md"
            p.write_text(
                p.read_text(encoding="utf-8").replace("3 по каталогу + 1 S дорожки", "3 по каталогу", 1),
                encoding="utf-8",
            )
            rep = dl.run_lint(root)
            self.assertFalse(rep.ok)
            self.assertIn("SH-6.5-CALENDAR", {e["code"] for e in rep.errors})

    def test_shop_forbidden_word_sl_txt_fails(self) -> None:
        with make_sandbox() as tmp:
            root = Path(tmp)
            p = root / "data/shop.json"
            doc = json.loads(p.read_text(encoding="utf-8"))
            doc["bundles"][0]["name_ru"] = "Успей купить набор"
            p.write_text(json.dumps(doc, ensure_ascii=False, indent=2), encoding="utf-8")
            rep = dl.run_lint(root)
            self.assertFalse(rep.ok)
            self.assertIn("SHOP-SL-TXT", {e["code"] for e in rep.errors})

    def test_shop_bundle_ratio_exceeds_limit_fails(self) -> None:
        with make_sandbox() as tmp:
            root = Path(tmp)
            p = root / "data/shop.json"
            doc = json.loads(p.read_text(encoding="utf-8"))
            doc["bundles"][0]["rub"] = 4000
            doc["bundles"][0]["value_ratio"] = 1.51
            p.write_text(json.dumps(doc, ensure_ascii=False, indent=2), encoding="utf-8")
            rep = dl.run_lint(root)
            self.assertFalse(rep.ok)
            self.assertIn("SHOP-SL-NUM", {e["code"] for e in rep.errors})

    def test_missing_required_file_fails(self) -> None:
        with make_sandbox() as tmp:
            root = Path(tmp)
            (root / "data/skins.json").unlink()
            rep = dl.run_lint(root)
            self.assertFalse(rep.ok)
            self.assertIn("FILES-EXIST", {e["code"] for e in rep.errors})


if __name__ == "__main__":
    unittest.main()
