"""python3 -m unittest discover -s tools/qa -p 'test_*.py'   (skin_lint is stdlib-only; jsonschema cross-check is optional)"""
import copy
import hashlib
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_skin_schema as bss
import make_skin_fixtures as mkf
import skin_lint as sl

REPO = Path(__file__).resolve().parents[2]
FIX = Path(__file__).resolve().parent / "fixtures" / "skins"
SCHEMA = json.loads((REPO / "design/specs/skin_manifest.schema.json").read_text(encoding="utf-8"))
# colour constants of the slot table that do not exist in tokens.json yet (added by RFC PAL-0001, PALETTE_LOCK 6.3)
PENDING_TOKENS = {"TAB_ACTIVE", "LANTERN_BODY", "LANTERN_FLAME", "TRAY_FRAME", "TRAY_SLOT_BG", "SHEET_BG", "WINDOW_BG", "TILE_BACK_MAIN",
                  "TILE_BACK_TRIM", "TILE_SELECT_RING", "MATCH_SPARK", "ULT_RING", "FX_GLOW", "STING_FLASH", "LOADING_BG_TOP", "LOADING_BG_BOT"}


def lint(doc, release=False, dirname=False):
    return sl.lint_manifest(doc, [], SCHEMA, Path("manifest.json"), {"release": release, "dirname": dirname})


class Base(unittest.TestCase):
    def setUp(self):
        self.valid = mkf.build_valid()

    def mut(self, fn):
        d = copy.deepcopy(self.valid)
        fn(d)
        return lint(d)

    def assertCode(self, res, code, where=None):
        hit = [e for e in res.errors if e["code"] == code and (where is None or where in e["path"])]
        self.assertTrue(hit, f"expected {code} ({where}); got {[(e['code'], e['path']) for e in res.errors][:8]}")


class Fixtures(Base):
    def test_valid_fixture_is_clean_and_in_sync_with_generator(self):
        r = sl.lint_paths([FIX / "valid"])
        self.assertEqual(len(r), 1)
        self.assertTrue(r[0].ok, r[0].errors)
        on_disk = json.loads((FIX / "valid/yue_ssr_scalearmor/manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(on_disk, self.valid, "fixture is stale: python tools/qa/make_skin_fixtures.py")

    def test_godot_fixture_copies_in_sync(self):
        g = REPO / "game/tests/fixtures/skins"
        for src, dst in (("valid/yue_ssr_scalearmor", "valid_yue_ssr_scalearmor.json"), ("invalid_hex/yue_ssr_hexrim", "invalid_hex_yue_ssr_hexrim.json")):
            self.assertEqual((FIX / src / "manifest.json").read_bytes(), (g / dst).read_bytes(), dst)

    def test_invalid_hex_fixture(self):
        r = sl.lint_paths([FIX / "invalid_hex"])[0]
        self.assertFalse(r.ok)
        self.assertIn("SL-PAL-01", r.codes())
        self.assertEqual(len([e for e in r.errors if e["code"] == "SL-PAL-01"]), 3)     # '#..', '#..', 'rgb('

    def test_missing_slot_fixture(self):
        r = sl.lint_paths([FIX / "missing_slot"])[0]
        self.assertEqual(sorted(e["msg"].split("'")[1] for e in r.errors if e["code"] == "SL-SLOT-05"),
                         ["bg.board", "kit.cta_overlay", "kit.nine.window"])
        self.assertEqual(r.codes(), ["SL-SLOT-05"])

    def test_whole_fixture_dir_exit_codes(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            self.assertEqual(sl.main([str(FIX / "valid")]), 0)
            self.assertEqual(sl.main([str(FIX)]), 1)
            self.assertEqual(sl.main([str(FIX / "nope")]), 2)
        self.assertIn("SKIN_LINT", buf.getvalue())

    def test_schema_in_sync(self):
        self.assertEqual(bss.main(["--check"]), 0)

    def test_optional_jsonschema_crosscheck(self):
        try:
            import jsonschema
        except ImportError:
            self.skipTest("jsonschema not installed")
        v = jsonschema.Draft202012Validator(SCHEMA)
        self.assertEqual(list(v.iter_errors(self.valid)), [])
        bad = json.loads((FIX / "invalid_hex/yue_ssr_hexrim/manifest.json").read_text(encoding="utf-8"))
        self.assertTrue(list(v.iter_errors(bad)))
        # my mini validator and jsonschema agree on the shape verdict
        mine = [p for p, _ in sl.validate(bad, SCHEMA, SCHEMA)]
        self.assertTrue(any("palette.slots.rim" in p for p in mine))


class PaletteRules(Base):
    def test_no_raw_colour_anywhere(self):
        for where, fn in {
            "provenance": lambda d: d["provenance"].__setitem__("element", "#FF00AA"),
            "faces": lambda d: d["faces"].__setitem__(0, "Color(1,0,0)"),
            "slot_key": lambda d: d["palette"]["slots"].__setitem__("rgba(0,0,0,1)", "T3"),
            "hex3": lambda d: d["palette"]["slots"].__setitem__("rim", "#f0a"),
            "0x": lambda d: d["release"].__setitem__("announce", "tint 0xFF8800") if "release" in d else d.__setitem__("release", {"announce": "0xFF8800"}),
        }.items():
            self.assertCode(self.mut(fn), "SL-PAL-01")

    def test_sha256_is_not_mistaken_for_colour(self):
        self.assertEqual(lint(self.valid).errors, [])

    def test_locked_slots_rejected(self):
        for slot in ("btn_cash_top", "btn_play_text", "tab_inactive", "foil", "combo_numeral", "text", "currency", "semantic", "rarity"):
            r = self.mut(lambda d, s=slot: d["palette"]["slots"].__setitem__(s, "T3"))
            self.assertCode(r, "SL-PAL-04", slot)

    def test_unknown_slot_and_disallowed_ref(self):
        self.assertCode(self.mut(lambda d: d["palette"]["slots"].__setitem__("sidebar_bg", "T3")), "SL-PAL-02", "sidebar_bg")
        self.assertCode(self.mut(lambda d: d["palette"]["slots"].__setitem__("rim", "T5")), "SL-PAL-02", "rim")        # T5 not in rim sources
        self.assertCode(self.mut(lambda d: d["palette"]["slots"].__setitem__("felt_hi", "T4")), "SL-PAL-02", "felt_hi")  # L2 only, skin is L1

    def test_mix_amount_cap(self):
        self.assertCode(self.mut(lambda d: d["palette"]["slots"].__setitem__("plate_top", "NIGHT_700+T5@0.30")), "SL-PAL-02", "plate_top")
        self.assertCode(self.mut(lambda d: d["palette"]["slots"].__setitem__("sheet_bg", "NIGHT_700+T5@0.20")), "SL-PAL-02", "sheet_bg")  # cap .12
        self.assertCode(self.mut(lambda d: d["palette"]["slots"].__setitem__("rim", "NIGHT_700+T5@0.10")), "SL-PAL-02", "rim")           # no mixing for rim

    def test_one_theme_and_own_hero_ramp(self):
        self.assertCode(self.mut(lambda d: d["palette"].__setitem__("theme", "TIDE")), "SL-PAL-03", "palette.theme")
        self.assertCode(self.mut(lambda d: d["palette"].__setitem__("hero", "rin")), "SL-PAL-03", "palette.hero")

    def test_l0_skin_cannot_use_theme_or_l1_slots(self):
        def to_s(d):
            d.update(tier="s", id="yue_s_scales", hud_level=0, theme=None, boldness="B1")
            d["palette"]["theme"] = None
        r = self.mut(to_s)
        self.assertCode(r, "SL-PAL-02", "btn_play_top")      # L1 slot on an L0 skin
        self.assertCode(r, "SL-PAL-03")                      # T-ref with theme null

    def test_dyes(self):
        self.assertCode(self.mut(lambda d: d["dyes"].append({"id": "dye_1", "theme": "SAKURA", "slots": {"rim": "T3"}})), "SL-DUP-01", "dyes")
        self.assertCode(self.mut(lambda d: d["dyes"][0].__setitem__("theme", "GILT")), "SL-PAL-06")           # GILT is ssrp-only
        self.assertCode(self.mut(lambda d: d["dyes"][0]["slots"].__setitem__("btn_cash_top", "T3")), "SL-PAL-04")
        r = self.mut(lambda d: d.__setitem__("dyes", [{"id": f"dye_{i}", "theme": "TIDE", "slots": {"rim": "T3"}} for i in (1, 2, 3)] +
                                                [{"id": "dye_1", "theme": "TIDE", "slots": {"rim": "T3"}}]))
        self.assertCode(r, "SL-MAN-01", "dyes")                                                                 # > 3


class TierRules(Base):
    def test_hud_level_matches_tier(self):
        self.assertCode(self.mut(lambda d: d.__setitem__("hud_level", 2)), "SL-MAN-03")
        self.assertCode(self.mut(lambda d: d.__setitem__("hud_level", 0)), "SL-MAN-03")

    def test_theme_allowed_per_tier(self):
        self.assertCode(self.mut(lambda d: (d.__setitem__("theme", "GILT"), d["palette"].__setitem__("theme", "GILT"))), "SL-MAN-04")
        self.assertCode(self.mut(lambda d: (d.__setitem__("theme", None), d["palette"].__setitem__("theme", None))), "SL-MAN-04")

    def test_boldness_ceiling(self):
        self.assertCode(self.mut(lambda d: d.__setitem__("boldness", "B3")), "SL-TIER-02")

    def test_id_hero_dir_consistency(self):
        self.assertCode(self.mut(lambda d: d.__setitem__("id", "rin_ssr_scalearmor")), "SL-MAN-02")
        self.assertCode(self.mut(lambda d: d.__setitem__("id", "yue_s_scalearmor")), "SL-MAN-02")
        res = sl.lint_manifest(self.valid, [], SCHEMA, Path("/x/wrongdir/manifest.json"), {"dirname": True})
        self.assertCode(res, "SL-MAN-02", "$.id")

    def test_voice_and_ult_minimums(self):
        self.assertCode(self.mut(lambda d: d["voice"]["lines"].__delitem__(slice(3, None))), "SL-MAN-09")
        self.assertCode(self.mut(lambda d: d["ult"].__setitem__("beats", 4)), "SL-ULT-01", "beats")
        self.assertCode(self.mut(lambda d: d["ult"].pop("full")), "SL-ULT-01", "ult.full")
        self.assertCode(self.mut(lambda d: d["ult"].__setitem__("name_key", "ult.ssrp.yue_x")), "SL-ULT-04")

    def test_proportions_adult_range(self):
        self.assertCode(self.mut(lambda d: d["proportions"].__setitem__("heads", 6.0)), "SL-MAN-01", "proportions")
        self.assertCode(self.mut(lambda d: d["proportions"].__setitem__("heads", 8.5)), "SL-MAN-01", "proportions")

    def test_blacklisted_words(self):
        for name in ("Школьная форма", "Student look", "Teen idol", "nude"):
            self.assertCode(self.mut(lambda d, n=name: d.__setitem__("name_ru", n)), "SL-MAN-11")
        self.assertEqual(self.mut(lambda d: d.__setitem__("name_ru", "Классика ночи")).errors, [])   # 'класс' alone is NOT a stem we ban

    def test_disk_budget(self):
        self.assertCode(self.mut(lambda d: d["budget"].__setitem__("disk_mb", 30.0)), "SL-SIZE-01")


class SlotRules(Base):
    def test_required_slot_per_tier_rank(self):
        self.assertTrue(any(r["min_tier"] == 3 for r in SCHEMA["x-slot-registry"].values()))
        def to_ssrp(d):
            d.update(tier="ssrp", id="yue_ssrp_x1234", hud_level=2, boldness="B3")
            d["ult"]["name_key"] = "ult.ssrp.x1234"
        r = self.mut(to_ssrp)
        missing = {e["msg"].split("'")[1] for e in r.errors if e["code"] == "SL-SLOT-05"}
        self.assertIn("bg.riichi", missing)
        self.assertIn("au.loop_menu", missing)
        self.assertIn("bt.stance", missing)

    def test_slot_not_allowed_for_lower_tier(self):
        def add(d):
            d["slots"]["bg.riichi"] = {"file": "bg/riichi.webp", "kind": "tex", "fallback": "vector"}
            d["files"].append({"path": "bg/riichi.webp", "bytes": 1000, "sha256": "0" * 64, "status": "approved"})
        self.assertCode(self.mut(add), "SL-SLOT-01", "bg.riichi")

    def test_unknown_slot_kind_mismatch_and_nine_slice(self):
        self.assertCode(self.mut(lambda d: d["slots"].__setitem__("zz.junk", copy.deepcopy(d["slots"]["bg.menu"]))), "SL-SLOT-01", "zz.junk")
        self.assertCode(self.mut(lambda d: d["slots"]["bg.menu"].__setitem__("kind", "video")), "SL-SLOT-06")
        self.assertCode(self.mut(lambda d: d["slots"]["kit.nine.plate_m"].__setitem__("nine", [40, 24, 24, 24])), "SL-SLOT-03")   # 40 > 96/3

    def test_file_not_listed_and_size_cap(self):
        def unlist(d):
            d["files"] = [f for f in d["files"] if f["path"] != "bg/menu.webp"]
        self.assertCode(self.mut(unlist), "SL-MAN-07")
        def big(d):
            for f in d["files"]:
                if f["path"] == "art/card_thumb.webp":
                    f["bytes"] = 500 * 1024
        self.assertCode(self.mut(big), "SL-SLOT-04")

    def test_fallback_chain(self):
        self.assertCode(self.mut(lambda d: d["fallbacks"].__setitem__("hero_base", "rin_base")), "SL-FB-01")
        self.assertCode(self.mut(lambda d: d["fallbacks"].__setitem__("vector", False)), "SL-MAN-01")
        self.assertCode(self.mut(lambda d: d["slots"]["art.card"].__setitem__("fallback", "vector")), "SL-FB-01", "art.card")   # no vector drawer
        self.assertCode(self.mut(lambda d: d["slots"]["bg.menu"].pop("fallback")), "SL-MAN-01", "slots.bg.menu")
        def base_skin(d):
            d.update(tier="base", id="yue_base", hud_level=0, theme=None, boldness="B1")
            d["palette"]["theme"] = None
        r = self.mut(base_skin)
        self.assertCode(r, "SL-FB-01", "hero_base")                                                                         # base skin must have null hero_base


class SecurityAndHygiene(Base):
    def test_font_script_shader_keys_and_files(self):
        self.assertCode(self.mut(lambda d: d.__setitem__("font", "nunito")), "SL-FONT-01")
        self.assertCode(self.mut(lambda d: d["palette"].__setitem__("font_size", 30)), "SL-FONT-01")
        self.assertCode(self.mut(lambda d: d.__setitem__("script", "res://x.gd")), "SL-SEC-01")
        self.assertCode(self.mut(lambda d: d.__setitem__("layout", {"x": 1})), "SL-SEC-01")
        def ttf(d):
            d["files"].append({"path": "kit/nunito.ttf", "bytes": 1000, "sha256": "1" * 64, "status": "approved"})
        self.assertCode(self.mut(ttf), "SL-FONT-01", "files")
        def gd(d):
            d["files"].append({"path": "rig/helper.gd", "bytes": 1000, "sha256": "2" * 64, "status": "approved"})
        self.assertCode(self.mut(gd), "SL-SEC-01", "files")

    def test_urls_rejected(self):
        self.assertCode(self.mut(lambda d: d["provenance"].__setitem__("tool", "https://evil.example/x")), "SL-SEC-02")

    def test_unknown_top_level_key(self):
        self.assertCode(self.mut(lambda d: d.__setitem__("hud_scale", 1.2)), "SL-MAN-01", "hud_scale")

    def test_duplicates(self):
        raw = json.dumps(self.valid).replace('"schema": 1', '"schema": 1, "schema": 1', 1)
        with tempfile.TemporaryDirectory() as t:
            p = Path(t) / "yue_ssr_scalearmor" / "manifest.json"
            p.parent.mkdir()
            p.write_text(raw, encoding="utf-8")
            r = sl.lint_paths([p])[0]
        self.assertIn("SL-DUP-01", r.codes())
        self.assertCode(self.mut(lambda d: d["voice"]["lines"].append(copy.deepcopy(d["voice"]["lines"][0]))), "SL-DUP-01", "voice")
        self.assertCode(self.mut(lambda d: d["files"].append(copy.deepcopy(d["files"][0]))), "SL-DUP-01", "files")
        self.assertCode(self.mut(lambda d: d["faces"].append("neutral")), "SL-MAN-01", "faces")

    def test_ids_unique_across_manifests(self):
        with tempfile.TemporaryDirectory() as t:
            for sub in ("a", "b"):
                p = Path(t) / sub / "yue_ssr_scalearmor" / "manifest.json"
                p.parent.mkdir(parents=True)
                p.write_text(json.dumps(self.valid), encoding="utf-8")
            res = sl.lint_paths([t])
        self.assertEqual(sorted(r.ok for r in res), [False, True])
        self.assertIn("SL-ID-01", [c for r in res for c in r.codes()])

    def test_release_mode_blocks_pending_signoffs(self):
        d = copy.deepcopy(self.valid)
        d["qa"]["ocr"] = "pending"
        self.assertEqual(lint(d).errors, [])                                  # draft: warning only
        self.assertTrue(lint(d).warnings)
        self.assertCode(lint(d, release=True), "SL-MAN-12")
        d2 = copy.deepcopy(self.valid)
        d2["files"][0]["status"] = "pending"
        self.assertCode(lint(d2, release=True), "SL-MAN-06")

    def test_bad_json_is_reported_not_crash(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t) / "manifest.json"
            p.write_text("{not json", encoding="utf-8")
            r = sl.lint_paths([p], dirname=False)[0]
        self.assertEqual(r.codes(), ["SL-MAN-01"])


class FilesOnDisk(Base):
    def make_pack(self, root: Path):
        doc = copy.deepcopy(self.valid)
        for f in doc["files"]:
            data = (f["path"] + "\n").encode() * 3
            p = root / f["path"]
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(data)
            f["bytes"], f["sha256"] = len(data), hashlib.sha256(data).hexdigest()
        doc["budget"]["disk_mb"] = round(sum(f["bytes"] for f in doc["files"]) / 1048576, 2)
        (root / "manifest.json").write_text(json.dumps(doc), encoding="utf-8")
        return doc

    def test_real_pack_passes_then_detects_tamper_missing_and_extra(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t) / "yue_ssr_scalearmor"
            doc = self.make_pack(root)
            r = sl.lint_paths([root], check_files=True)[0]
            self.assertTrue(r.ok, r.errors[:3])
            (root / "art/card.webp").write_bytes(b"tampered!")
            (root / "bg/menu.webp").unlink()
            (root / "bg/stowaway.webp").write_bytes(b"x")
            r = sl.lint_paths([root], check_files=True)[0]
            msgs = " | ".join(e["msg"] for e in r.errors)
            self.assertIn("sha256 mismatch", msgs)
            self.assertIn("does not exist", msgs)
            self.assertIn("stowaway.webp exists in the pack but is not listed", msgs)


class TableSanity(unittest.TestCase):
    def test_slot_tokens_exist_or_are_pending(self):
        tok = json.loads((REPO / "game/shell/design/tokens.json").read_text(encoding="utf-8"))["color"]
        for slot, rule in SCHEMA["x-color-slots"].items():
            for t in rule["tokens"]:
                self.assertTrue(t in tok or t in PENDING_TOKENS, f"{slot} -> {t}: neither in tokens.json nor in the RFC-pending list")
        for t in SCHEMA["x-locked-tokens"]:
            self.assertIn(t, tok)

    def test_slots_have_no_overlap_with_locked(self):
        self.assertFalse(set(SCHEMA["x-color-slots"]) & set(SCHEMA["x-locked-slots"]))

    def test_every_color_slot_source_is_a_valid_ref(self):
        import re
        rx = re.compile(SCHEMA["properties"]["palette"]["properties"]["slots"]["additionalProperties"]["pattern"])
        for slot, rule in SCHEMA["x-color-slots"].items():
            for ref in rule["from"]:
                self.assertTrue(rx.search(ref), (slot, ref))

    def test_tier_tables_monotone(self):
        tr = SCHEMA["x-tier-rules"]
        self.assertLess(tr["s"]["disk_budget_mb"], tr["ssr"]["disk_budget_mb"])
        self.assertLess(tr["ssr"]["disk_budget_mb"], tr["ssrp"]["disk_budget_mb"])
        self.assertLessEqual(tr["s"]["min_voice_lines"], tr["ssr"]["min_voice_lines"])
        self.assertLessEqual(tr["ssr"]["min_ult_beats"], tr["ssrp"]["min_ult_beats"])
        self.assertIn("GILT", tr["ssrp"]["themes"])
        self.assertNotIn("GILT", tr["ssr"]["themes"])


if __name__ == "__main__":
    unittest.main()
