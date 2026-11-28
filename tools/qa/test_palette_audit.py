"""python3 -m unittest discover -s tools/qa -p 'test_*.py'   (needs numpy + Pillow; skipped cleanly without them)"""
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    import numpy as np
    from PIL import Image
    import colorlib as cl
    import palette_audit as pa
    import build_palette_ramps as bpr
except ImportError as e:  # pragma: no cover
    raise unittest.SkipTest(f"numpy/Pillow missing: {e}")

REPO = Path(__file__).resolve().parents[2]


def solid(path, colors, size=(64, 64), **save_kw):
    """colors: list of hex -> vertical bands of equal width."""
    im = Image.new("RGB", size)
    w = size[0] // len(colors)
    for i, c in enumerate(colors):
        im.paste(Image.new("RGB", (w if i < len(colors) - 1 else size[0] - w * i, size[1]), c), (w * i, 0))
    im.save(path, **save_kw)


class ColorMath(unittest.TestCase):
    def test_de2000_sharma_reference(self):
        # Sharma, Wu, Dalal 2005 supplementary test data
        cases = [((50, 2.6772, -79.7751), (50, 0, -82.7485), 2.0425), ((50, 3.1571, -77.2803), (50, 0, -82.7485), 2.8615),
                 ((50, 2.5, 0), (73, 25, -18), 27.1492), ((50, 2.5, 0), (61, -5, 29), 22.8977),
                 ((50, 2.5, 0), (56, -27, -3), 31.9030), ((50, 2.5, 0), (58, 24, 15), 19.4535),
                 ((2.0776, 0.0795, -1.135), (0.9033, -0.0636, -0.5514), 0.9082)]
        for a, b, e in cases:
            self.assertAlmostEqual(float(cl.delta_e2000(np.array(a), np.array(b))), e, places=3)
            self.assertAlmostEqual(float(cl.delta_e2000(np.array(b), np.array(a))), e, places=3)  # symmetric

    def test_lab_roundtrip_and_contrast(self):
        for h in ("#1B171C", "#F5EAD8", "#DF4F74", "#000000", "#FFFFFF"):
            self.assertEqual(cl.lab_to_hex(cl.hex_to_lab(h)), h)
        self.assertAlmostEqual(cl.contrast_ratio(cl.hex_to_rgb("#F5EAD8"), cl.hex_to_rgb("#1B171C")), 14.88, places=2)  # PALETTE_LOCK 2.2
        self.assertAlmostEqual(cl.contrast_ratio(cl.hex_to_rgb("#000000"), cl.hex_to_rgb("#FFFFFF")), 21.0, places=6)

    def test_bad_hex(self):
        with self.assertRaises(ValueError):
            cl.hex_to_rgb("#12345")


class RampsFile(unittest.TestCase):
    def setUp(self):
        self.doc = json.loads((REPO / "design/specs/palette_ramps.json").read_text(encoding="utf-8"))

    def test_in_sync_with_tokens(self):
        self.assertEqual(bpr.main(["--check"]), 0)

    def test_every_token_present_and_valid(self):
        tok = json.loads((REPO / "game/shell/design/tokens.json").read_text(encoding="utf-8"))
        for name, h in tok["color"].items():
            self.assertEqual(self.doc["colors"][name]["hex"], h.upper(), name)
            self.assertEqual(self.doc["colors"][name]["status"], "repo")
        for name, e in self.doc["colors"].items():
            cl.hex_to_rgb(e["hex"])
            self.assertIn(e["status"], ("repo", "proposed", "legacy"))

    def test_profiles_and_rules_complete(self):
        for _, cat, prof in self.doc["category_rules"]:
            self.assertIn(prof, self.doc["profiles"])
        self.assertEqual(self.doc["category_rules"][-1][0], "")  # catch-all last

    def test_proposed_heroes_cover_all_tokens_heroes(self):
        tok = json.loads((REPO / "game/shell/design/tokens.json").read_text(encoding="utf-8"))
        for hid in tok["heroes"]:
            for s in ("H100", "H300", "H500", "H700", "H900"):
                self.assertIn(f"HERO_{hid.upper()}_{s}", self.doc["colors"])

    def test_h900_darker_than_h100_monotone_lightness(self):
        for hid in ("mc", "rin", "kohaku"):
            L = [float(cl.hex_to_lab(self.doc["colors"][f"HERO_{hid.upper()}_{s}"]["hex"])[0]) for s in ("H100", "H300", "H500", "H700", "H900")]
            self.assertEqual(L, sorted(L, reverse=True), hid)


class AuditImages(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = Path(self.tmp.name)
        self.pal = pa.load_palette()

    def tearDown(self):
        self.tmp.cleanup()

    def audit(self, name, profile="chrome", **kw):
        return pa.audit_image(self.d / name, self.pal, name, profile=profile, **kw)

    def test_exact_palette_colours_pass_with_zero_de(self):
        im = Image.new("RGB", (100, 100), "#1B171C")
        im.paste(Image.new("RGB", (100, 40), "#F5EAD8"), (0, 0))
        im.paste(Image.new("RGB", (30, 10), "#E8C47E"), (0, 40))     # 3 % gold: under the 4 % gold-band cap
        im.paste(Image.new("RGB", (30, 10), "#DF4F74"), (30, 40))
        im.save(self.d / "ok.png")
        r = self.audit("ok.png")
        self.assertEqual(r["verdict"], "PASS", r["reasons"])
        self.assertLess(r["metrics"]["mean_de"], 0.1)
        self.assertEqual(r["metrics"]["coverage_pct"], 100.0)
        self.assertEqual({c["nearest"] for c in r["clusters"]}, {"NIGHT_800", "PAPER_100", "GOLD_500", "BTN_PLAY_TOP"})

    def test_off_palette_lime_fails_chrome_warns_nothing_in_art_unless_garish(self):
        solid(self.d / "lime.png", ["#1B171C", "#00FF00"])
        self.assertEqual(self.audit("lime.png")["verdict"], "FAIL")
        art = self.audit("lime.png", profile="art")
        self.assertEqual(art["verdict"], "WARN")      # garish outlier, but art never FAILs on palette
        self.assertTrue(any("garish" in x for x in art["reasons"]))

    def test_small_drift_is_warn_not_fail(self):
        # NIGHT_800 nudged by ~dE 4.4: between warn_de (3.5) and fail_de (6.0)
        h = cl.lab_to_hex(cl.hex_to_lab("#DDD2C4") + np.array([0.0, 0.0, 6.0]))   # PAPER_300 pushed to b+6: nearest ramp dE ~4
        solid(self.d / "d.png", [h, "#1B171C"])
        r = self.audit("d.png")
        de = [c["de"] for c in r["clusters"] if c["nearest"] != "NIGHT_800"][0]
        self.assertTrue(3.5 < de < 6.0, de)
        self.assertEqual(r["verdict"], "WARN")

    def test_tiny_off_palette_area_is_ignored(self):
        im = Image.new("RGB", (100, 100), "#1B171C")
        im.paste(Image.new("RGB", (10, 10), "#00FF00"), (0, 0))   # 1% < min_area_pct 1.5
        im.save(self.d / "tiny.png")
        self.assertEqual(self.audit("tiny.png")["verdict"], "PASS")

    def test_alpha_is_ignored_and_empty_image_warns(self):
        im = Image.new("RGBA", (64, 64), (0, 255, 0, 0))             # transparent green must not count
        im.paste(Image.new("RGBA", (32, 64), (0x1B, 0x17, 0x1C, 255)), (0, 0))
        im.save(self.d / "alpha.png")
        r = self.audit("alpha.png")
        self.assertEqual(r["verdict"], "PASS", r["reasons"])
        self.assertEqual(r["opaque_px"], 32 * 64)
        Image.new("RGBA", (8, 8), (255, 0, 0, 0)).save(self.d / "empty.png")
        self.assertEqual(self.audit("empty.png")["verdict"], "WARN")

    def test_unreadable_file_is_fail_not_crash(self):
        (self.d / "bad.png").write_bytes(b"not an image")
        r = self.audit("bad.png")
        self.assertEqual(r["verdict"], "FAIL")

    def test_deterministic(self):
        rng = np.random.RandomState(1)
        Image.fromarray(rng.randint(0, 255, (96, 96, 3), dtype=np.uint8)).save(self.d / "noise.png")
        a = json.dumps(self.audit("noise.png", profile="art"), sort_keys=True)
        b = json.dumps(self.audit("noise.png", profile="art"), sort_keys=True)
        self.assertEqual(a, b)

    def test_repo_only_forbids_proposed_colours(self):
        solid(self.d / "rar.png", ["#1B171C", "#30C883"])            # RARITY_R is proposed only
        with_prop = self.audit("rar.png")
        self.assertEqual(with_prop["verdict"], "PASS", with_prop["reasons"])
        strict = pa.audit_image(self.d / "rar.png", pa.load_palette(repo_only=True), "rar.png", profile="chrome")
        self.assertEqual(strict["verdict"], "FAIL")

    def test_hero_filter_only_own_ramp(self):
        solid(self.d / "yue.png", ["#1B171C", "#C9B2F0"])            # Yue accent
        ok = pa.audit_image(self.d / "yue.png", pa.load_palette(hero="yue"), "yue.png", profile="chrome")
        self.assertEqual(ok["verdict"], "PASS", ok["reasons"])
        wrong = pa.audit_image(self.d / "yue.png", pa.load_palette(hero="zlata", repo_only=True), "yue.png", profile="chrome")
        self.assertNotEqual(wrong["verdict"], "PASS")

    def test_hero_without_theme_excludes_theme_ramps(self):
        pal = pa.load_palette(hero="yue")
        self.assertFalse([n for n in pal.names if n.startswith("THEME_")])
        self.assertTrue([n for n in pal.names if n.startswith("HERO_YUE_")])
        self.assertFalse([n for n in pal.names if n.startswith("HERO_RIN_")])
        pal2 = pa.load_palette(hero="yue", theme="NEON")
        self.assertTrue([n for n in pal2.names if n.startswith("THEME_NEON2_")])        # NEON carries its second ramp
        self.assertFalse([n for n in pal2.names if n.startswith("THEME_MOON_")])

    def test_gold_band_cap(self):
        solid(self.d / "gold.png", ["#E8C47E", "#1B171C"])
        r = self.audit("gold.png")
        self.assertGreater(r["metrics"]["gold_band_pct"], 40)
        self.assertEqual(r["verdict"], "WARN")
        self.assertTrue(any("gold-band" in x for x in r["reasons"]))

    def test_category_rules(self):
        c = self.pal.categorize
        self.assertEqual(c("game/assets/ui/btn.png"), ("ui_chrome", "chrome"))
        self.assertEqual(c("game/assets/icons/gem.png"), ("icons", "icon"))
        self.assertEqual(c("game/assets/tiles/05_clover.png"), ("tile_faces", "icon"))
        self.assertEqual(c("game/assets/v10/hud2/combo/mc_t1.png"), ("hero_art", "art"))
        self.assertEqual(c("game/assets/fx/glow.png"), ("fx", "fx"))
        self.assertEqual(c("game/assets/outfits/hana_base.webp"), ("outfit_art", "art"))
        self.assertEqual(c("design/golden_full/picks/x.png"), ("golden", "art"))
        self.assertEqual(c("something/else.png"), ("other", "art"))

    def test_webp_and_jpg_inputs(self):
        solid(self.d / "a.webp", ["#26212A", "#F5EAD8"], lossless=True)
        solid(self.d / "lossy.webp", ["#26212A", "#F5EAD8"], quality=80)   # block ringing may WARN, must never FAIL
        self.assertNotEqual(self.audit("lossy.webp")["verdict"], "FAIL")
        im = Image.new("RGB", (64, 64), "#26212A")
        im.save(self.d / "b.jpg", quality=95)
        self.assertEqual(self.audit("a.webp")["verdict"], "PASS")
        self.assertIn(self.audit("b.jpg")["verdict"], ("PASS", "WARN"))


class RunAndCli(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = Path(self.tmp.name)
        (self.d / "game/assets/ui").mkdir(parents=True)
        (self.d / "game/assets/hero").mkdir(parents=True)
        solid(self.d / "game/assets/ui/good.png", ["#1B171C", "#F5EAD8"])
        solid(self.d / "game/assets/ui/bad.png", ["#1B171C", "#00FF00"])
        solid(self.d / "game/assets/hero/art.png", ["#7A5A48", "#3B5A7A", "#C9B2F0"])

    def tearDown(self):
        self.tmp.cleanup()

    def cli(self, *args):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = pa.main([str(a) for a in args])
        return rc, buf.getvalue()

    def test_directory_scan_report_and_exit_codes(self):
        out = self.d / "rep.json"
        rep = pa.run([self.d], root=self.d)
        by = {r["path"]: r for r in rep["images"]}
        self.assertEqual(by["game/assets/ui/good.png"]["verdict"], "PASS")
        self.assertEqual(by["game/assets/ui/bad.png"]["verdict"], "FAIL")
        self.assertEqual(by["game/assets/hero/art.png"]["profile"], "art")
        self.assertIn(rep["categories"]["ui_chrome"]["drift"], ("DRIFT", "minor"))
        rc, text = self.cli(self.d / "game/assets/ui", "--json", out)
        self.assertEqual(rc, 1)
        self.assertIn("PALETTE_AUDIT", text)
        self.assertEqual(json.loads(out.read_text())["counts"]["FAIL"], 1)
        rc, _ = self.cli(self.d / "game/assets/ui/good.png")
        self.assertEqual(rc, 0)

    def test_missing_path_is_exit_2(self):
        rc, _ = self.cli(self.d / "nope")
        self.assertEqual(rc, 2)

    def test_baseline_ratchet(self):
        base = self.d / "base.json"
        good = self.d / "game/assets/ui/good.png"
        base.write_text(json.dumps(pa.baseline_from(pa.run([good], root=self.d))))
        # same path, drifted content (nudge the light band to a visible blue-ish shade) -> worse than the baseline
        solid(good, ["#1B171C", "#C8D8F0"])
        rep = pa.run([good], baseline=base, root=self.d)
        self.assertEqual(rep["images"][0]["verdict"], "FAIL")
        self.assertTrue(any("ratchet" in r for r in rep["images"][0]["reasons"]))

    def test_fail_on_warn(self):
        solid(self.d / "g.png", ["#E8C47E", "#1B171C"])
        rc, _ = self.cli(self.d / "g.png", "--profile", "chrome")
        self.assertEqual(rc, 0)
        rc, _ = self.cli(self.d / "g.png", "--profile", "chrome", "--fail-on-warn")
        self.assertEqual(rc, 1)

    def test_relative_outlier_marks_warn(self):
        d = self.d / "game/assets/ui2"
        d.mkdir()
        for i in range(10):
            solid(d / f"n{i}.png", ["#DDD2C4", "#1B171C"])
        lab = cl.hex_to_lab("#DDD2C4") + np.array([0.0, 0.0, 5.0])  # dE ~3.4 < warn_de, but far from the siblings' 0
        solid(d / "z.png", [cl.lab_to_hex(lab), "#1B171C"])
        rep = pa.run([d], root=self.d)
        z = [r for r in rep["images"] if r["path"].endswith("z.png")][0]
        self.assertEqual(z["verdict"], "WARN")
        self.assertTrue(any("outlier inside category" in x for x in z["reasons"]))


if __name__ == "__main__":
    unittest.main()
