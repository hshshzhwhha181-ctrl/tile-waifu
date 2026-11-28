#!/usr/bin/env python3
"""build_skin_schema.py - writes design/specs/skin_manifest.schema.json (the contract of a SkinPack manifest.json, schema 1).

The JSON Schema (draft 2020-12 subset) carries the SHAPE; the x-* keys carry the RULE TABLES that tools/qa/skin_lint.py reads
(slot registry, per-slot colour sources, locked slots, tier tables). One generator = no typos in 60-row tables.
Rules follow design/specs/SKIN_HUD_SYSTEM.md (branch claude/spec-skin) sections 2.3, 2.5, 7.1 and PALETTE_LOCK.md section 6.

  python tools/qa/build_skin_schema.py            # write
  python tools/qa/build_skin_schema.py --check    # exit 1 if stale
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "design" / "specs" / "skin_manifest.schema.json"
GODOT_FIX = REPO / "game" / "tests" / "fixtures" / "skins" / "ramps_min.json"     # read by game/tests/skin_swap_soak (res://tests/fixtures/skins)

TIERS = ["base", "vow", "s", "ssr", "ssrp"]
TIER_RANK = {"base": 0, "vow": 1, "s": 1, "ssr": 2, "ssrp": 3}
HUD_LEVEL = {"base": 0, "vow": 0, "s": 0, "ssr": 1, "ssrp": 2}
THEMES = ["SAKURA", "MOON", "JADE", "EMBER", "TIDE", "NEON", "INK", "GILT"]
THEMES_BY_TIER = {"base": [], "vow": [], "s": ["SAKURA", "MOON", "JADE", "TIDE", "INK"],
                  "ssr": ["SAKURA", "MOON", "JADE", "TIDE", "INK", "EMBER", "NEON"], "ssrp": THEMES}
BOLDNESS_BY_TIER = {"base": ["B1"], "vow": ["B1"], "s": ["B1"], "ssr": ["B1", "B2"], "ssrp": ["B1", "B2", "B3"]}
MIN_VOICE = {"base": 0, "vow": 4, "s": 4, "ssr": 8, "ssrp": 20}
MIN_ULT_BEATS = {"base": 4, "vow": 4, "s": 4, "ssr": 6, "ssrp": 8}                    # [ГИПОТЕЗА] base/vow
DISK_BUDGET_MB = {"base": 4.3, "vow": 6.9, "s": 6.9, "ssr": 12.3, "ssrp": 23.2}        # +-15 % allowed by the lint
DISK_TOL = 0.15
MAX_FILE_KB, MAX_VIDEO_KB = 2560, 2457                                                 # 2.5 MB / 2.4 MB (SL-SLOT-04)

# slot registry: name -> (kind, min_tier_rank, load class, max_kb, vector_fallback)
R = {}


def reg(names, kind, rank, cls, kb, vec):
    for n in names.split():
        R[n] = {"kind": kind, "min_tier": rank, "class": cls, "max_kb": kb, "vector": vec}


reg("art.card", "tex", 0, "E", 300, False)
reg("art.card_thumb", "tex", 0, "E", 40, False)
reg("art.medallion", "tex", 0, "E", 160, False)
reg("art.splash_a", "tex", 1, "L", 1000, False)
reg("art.splash_b art.portrait art.win art.tease", "tex", 2, "L", 1000, False)
reg("rig.scene", "rig", 0, "A", 7000, False)
reg("rig.faces", "tex", 0, "A", 900, False)
reg("rig.touchmap", "tex", 0, "A", 30, False)
reg("kit.nine.plate_s kit.nine.plate_m kit.nine.plate_l", "tex9", 2, "E", 120, True)
reg("kit.nine.header kit.nine.window kit.nine.sheet kit.nine.tab_bar kit.nine.tray kit.nine.lantern_chip", "tex9", 2, "E", 220, True)
reg("kit.ic.nav_tea_on kit.ic.nav_heroines_on kit.ic.nav_games_on kit.ic.nav_wishes_on kit.ic.nav_shop_on", "tex", 2, "E", 30, True)
reg("kit.cta_overlay", "tex", 2, "A", 60, True)
reg("kit.ring_ult", "tex", 1, "A", 60, True)
reg("cf.frame", "tex9", 1, "E", 200, True)
reg("bg.menu bg.menu_night", "tex", 2, "A", 520, True)
reg("bg.board", "tex", 2, "A", 300, True)
reg("bg.riichi bg.results bg.gacha bg.shop bg.battle bg.load", "tex", 3, "L", 850, True)
reg("bg.menu_anim bg.gacha_anim", "video", 3, "P", 2457, True)
reg("tl.back", "tex", 3, "L", 80, True)
reg("fx.match fx.touch", "particles", 1, "A", 300, True)
reg("fx.ambient_a fx.press fx.open", "particles", 2, "A", 300, True)
reg("fx.ambient_b fx.ambient_c fx.heat", "particles", 3, "L", 400, True)
reg("ult.rig_clip ult.short", "clip", 0, "A", 150, False)
reg("ult.full", "video", 2, "L", 2457, False)
reg("bt.stance bt.hurt bt.win", "clip", 3, "L", 200, False)
reg("bt.ring bt.hit_fx", "tex", 3, "L", 200, False)
reg("au.sting_equip au.sting_ult", "audio", 1, "A", 100, False)
reg("au.sfx.press au.sfx.open au.sfx.tab au.sfx.confirm au.sfx.deny au.sfx.charge au.sfx.hit", "audio", 2, "A", 40, False)
reg("au.loop_menu", "audio", 3, "P", 500, False)

# colour slots (PALETTE_LOCK 6.2/6.3): name -> allowed refs, mix tint list, mix max, hud levels, TWTokens constants
H_ALL = ["H100", "H300", "H500", "H700", "H900"]
T_ALL = ["T1", "T2", "T3", "T4", "T5"]
NIGHT_MIX = ["NIGHT_600", "NIGHT_700", "NIGHT_800"]
COLOR_SLOTS = {
    "rim": {"from": ["PLATE_RIM", "T2", "T3", "H300", "H500"], "levels": [1, 2], "tokens": ["PLATE_RIM"]},
    "rim_spark": {"from": ["PLATE_SPARK", "T1", "H100"], "levels": [0, 1, 2], "tokens": ["PLATE_SPARK"]},
    "plate_top": {"from": NIGHT_MIX, "mix": ["T5", "H900"], "mix_max": 0.18, "levels": [0, 1, 2], "tokens": ["PLATE_TOP"]},
    "plate_bot": {"from": NIGHT_MIX, "mix": ["T5", "H900"], "mix_max": 0.18, "levels": [0, 1, 2], "tokens": ["PLATE_BOT"]},
    "plate_sel_top": {"from": NIGHT_MIX, "mix": ["T5", "H900"], "mix_max": 0.25, "levels": [0, 1, 2], "tokens": ["PLATE_SEL_TOP"]},
    "plate_sel_bot": {"from": NIGHT_MIX, "mix": ["T5", "H900"], "mix_max": 0.25, "levels": [0, 1, 2], "tokens": ["PLATE_SEL_BOT"]},
    "btn_play_top": {"from": H_ALL + T_ALL, "levels": [1, 2], "tokens": ["BTN_PLAY_TOP"]},
    "btn_play_mid": {"from": H_ALL + T_ALL, "levels": [1, 2], "tokens": ["BTN_PLAY_MID"]},
    "btn_play_bot": {"from": H_ALL + T_ALL, "levels": [1, 2], "tokens": ["BTN_PLAY_BOT"]},
    "btn_play_down_top": {"from": H_ALL + T_ALL, "levels": [1, 2], "tokens": ["BTN_PLAY_DOWN_TOP"]},
    "btn_play_down_bot": {"from": H_ALL + T_ALL, "levels": [1, 2], "tokens": ["BTN_PLAY_DOWN_BOT"]},
    "btn_play_outline": {"from": H_ALL + T_ALL, "levels": [1, 2], "tokens": ["BTN_PLAY_OUTLINE"]},
    "btn_play_glow": {"from": H_ALL + T_ALL, "levels": [1, 2], "tokens": ["BTN_PLAY_GLOW"]},
    "tab_active": {"from": ["T2", "T3", "H300", "H500"], "levels": [1, 2], "tokens": ["TAB_ACTIVE"]},
    "lantern_body": {"from": ["T2", "T3", "T4", "H300", "H500", "H700"], "levels": [1, 2], "tokens": ["LANTERN_BODY"]},
    "lantern_flame": {"from": ["T2", "T3", "T4", "H300", "H500", "H700"], "levels": [1, 2], "tokens": ["LANTERN_FLAME"]},
    "tray_frame": {"from": NIGHT_MIX, "mix": ["T5", "H900"], "mix_max": 0.15, "levels": [1, 2], "tokens": ["TRAY_FRAME"]},
    "tray_slot_bg": {"from": NIGHT_MIX, "mix": ["T5", "H900"], "mix_max": 0.15, "levels": [1, 2], "tokens": ["TRAY_SLOT_BG"]},
    "sheet_bg": {"from": ["NIGHT_700", "NIGHT_800"], "mix": ["T5", "H900"], "mix_max": 0.12, "levels": [1, 2], "tokens": ["SHEET_BG"]},
    "window_bg": {"from": ["NIGHT_700", "NIGHT_800"], "mix": ["T5", "H900"], "mix_max": 0.12, "levels": [1, 2], "tokens": ["WINDOW_BG"]},
    # review 2026-11-28 (T15): T4 is OKLab L 0.50 (outside the felt range) and T5 chroma of EMBER/NEON2 > 0.07, so felt uses T5 or a NIGHT_800+T5 mix
    "felt_hi": {"from": ["T5", "NIGHT_800"], "mix": ["T5"], "mix_max": 0.6, "levels": [2], "tokens": ["FELT_HI"]},
    "felt_lo": {"from": ["NIGHT_800"], "mix": ["T5"], "mix_max": 0.5, "levels": [2], "tokens": ["FELT_LO"]},
    "tile_back_main": {"from": ["T3", "T4"], "levels": [2], "tokens": ["TILE_BACK_MAIN"]},
    "tile_back_trim": {"from": ["T1", "T3"], "levels": [2], "tokens": ["TILE_BACK_TRIM"]},
    "tile_select_ring": {"from": ["H300"], "levels": [0, 1, 2], "tokens": ["TILE_SELECT_RING"]},
    "match_spark": {"from": ["H100", "H300", "T2"], "levels": [0, 1, 2], "tokens": ["MATCH_SPARK"]},
    "ult_ring": {"from": ["H300", "H500", "PLATE_RIM"], "levels": [0, 1, 2], "tokens": ["ULT_RING"]},
    "fx_glow": {"from": ["T1", "T2"], "levels": [1, 2], "tokens": ["FX_GLOW"]},
    "sting_flash": {"from": ["T1", "T2"], "levels": [1, 2], "tokens": ["STING_FLASH"]},
    "loading_bg_top": {"from": ["T5", "H900"], "levels": [2], "tokens": ["LOADING_BG_TOP"]},
    "loading_bg_bot": {"from": ["NIGHT_900"], "levels": [2], "tokens": ["LOADING_BG_BOT"]},
}
LOCKED_SLOTS = ["btn_cash_top", "btn_cash_bot", "btn_play_text", "tab_inactive", "foil", "combo_numeral", "text", "currency",
                "semantic", "rarity", "rarity_frame", "paper", "shadow"]
# Colour constants a skin may NEVER touch even when a manifest names them by token (defence in depth; AT-S23)
LOCKED_TOKENS = ["BTN_CASH_TOP", "BTN_CASH_BOT", "BTN_PLAY_TEXT", "PAPER_100", "PAPER_300", "PAPER_500", "PAPER_700", "GOLD_300",
                 "GOLD_500", "GOLD_700", "JADE_300", "JADE_500", "CINNABAR", "EMBER", "SHADOW"]

REF_RE = ("^(NIGHT_(900|800|700|600|500|400)|PLATE_RIM|PLATE_SPARK|H(100|300|500|700|900)|T[1-5])"
          "$|^NIGHT_(800|700|600)\\+(T5|H900)@0\\.[0-9]{1,2}$")

SLOT_ENTRY = {
    "type": "object", "additionalProperties": False, "required": ["file", "kind", "fallback"],
    "properties": {
        "file": {"type": "string", "pattern": "^[a-z0-9_]+(/[a-z0-9_]+)*\\.(webp|png|ogv|ogg|tscn|json)$", "maxLength": 96},
        "kind": {"enum": ["tex", "tex9", "anim", "video", "rig", "audio", "particles", "clip"]},
        "w": {"type": "integer", "minimum": 1, "maximum": 2048}, "h": {"type": "integer", "minimum": 1, "maximum": 2048},
        "nine": {"type": "array", "items": {"type": "integer", "minimum": 0, "maximum": 512}, "minItems": 4, "maxItems": 4},
        "fps": {"type": "integer", "minimum": 1, "maximum": 60}, "loop": {"type": "boolean"},
        "mem_kb": {"type": "integer", "minimum": 0, "maximum": 65536},
        "fallback": {"enum": ["base", "global", "vector"]},
    },
}


def schema() -> dict:
    ref = {"type": "string", "pattern": REF_RE}
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "tile-waifu/skin_manifest.schema.json",
        "title": "Tile Waifu SkinPack manifest.json, schema 1",
        "description": "Shape of a skin manifest + rule tables read by tools/qa/skin_lint.py. GENERATED by tools/qa/build_skin_schema.py. "
                       "Manifest holds NO raw colours (palette refs only), NO fonts, NO scripts, NO geometry.",
        "type": "object",
        "additionalProperties": False,
        "required": ["schema", "id", "hero", "tier", "name_ru", "season", "hud_level", "theme", "boldness", "pack_ver", "engine",
                     "min_game", "proportions", "palette", "presence", "faces", "touch", "ult", "voice", "slots", "files",
                     "budget", "qa", "provenance", "fallbacks"],
        "properties": {
            "schema": {"const": 1},
            "id": {"type": "string", "pattern": "^[a-z][a-z0-9]{1,15}_(base|vow|(s|ssr|ssrp)_[a-z0-9]{3,16})$"},
            "hero": {"type": "string", "pattern": "^[a-z][a-z0-9]{1,15}$"},
            "tier": {"enum": TIERS},
            "name_ru": {"type": "string", "minLength": 2, "maxLength": 24},
            "season": {"type": "string", "pattern": "^(launch|S[1-9][0-9]?)$"},
            "hud_level": {"enum": [0, 1, 2]},
            "theme": {"enum": THEMES + [None]},
            "boldness": {"enum": ["B1", "B2", "B3"]},
            "pack_ver": {"type": "string", "pattern": "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$"},
            "engine": {"type": "string", "pattern": "^4\\.[0-9]+\\.x$"},
            "min_game": {"type": "string", "pattern": "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$"},
            "proportions": {"type": "object", "additionalProperties": False, "required": ["heads", "height_cm"],
                            "properties": {"heads": {"type": "number", "minimum": 7.0, "maximum": 8.0},
                                           "height_cm": {"type": "number", "minimum": 150, "maximum": 190}}},
            "palette": {"type": "object", "additionalProperties": False, "required": ["hero", "theme", "slots"],
                        "properties": {"hero": {"type": "string", "pattern": "^[a-z][a-z0-9]{1,15}$"},
                                       "theme": {"enum": THEMES + [None]},
                                       "slots": {"type": "object", "propertyNames": {"pattern": "^[a-z][a-z0-9_]*$"},
                                                 "additionalProperties": ref, "maxProperties": 40}}},
            "dyes": {"type": "array", "maxItems": 3, "items": {
                "type": "object", "additionalProperties": False, "required": ["id", "theme", "slots"],
                "properties": {"id": {"type": "string", "pattern": "^dye_[1-3]$"}, "theme": {"enum": THEMES},
                               "slots": {"type": "object", "propertyNames": {"pattern": "^[a-z][a-z0-9_]*$"},
                                         "additionalProperties": ref, "maxProperties": 40}}}},
            "presence": {"type": "object", "additionalProperties": False, "required": ["full", "std", "min"],
                         "properties": {"full": {"$ref": "#/$defs/crop"}, "std": {"$ref": "#/$defs/crop"},
                                        "min": {"type": "object", "additionalProperties": False, "required": ["medallion"],
                                                "properties": {"medallion": {"type": "string", "pattern": "^art/[a-z0-9_]+\\.webp$"}}}}},
            "rig": {"type": "object", "additionalProperties": False, "required": ["scene", "bones", "polys", "verts"],
                    "properties": {"scene": {"type": "string", "pattern": "^rig/[a-z0-9_]+\\.tscn$"},
                                   "bones": {"type": "integer", "minimum": 1, "maximum": 54},
                                   "polys": {"type": "integer", "minimum": 1, "maximum": 64},
                                   "verts": {"type": "integer", "minimum": 1, "maximum": 2900},
                                   "spring_chains": {"type": "integer", "minimum": 0, "maximum": 12},
                                   "spring_bones": {"type": "integer", "minimum": 0, "maximum": 40},
                                   "fps_full": {"enum": [30, 60]}, "fps_std": {"enum": [30, 60]}}},
            "faces": {"type": "array", "items": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"}, "minItems": 4, "maxItems": 40,
                      "uniqueItems": True},
            "touch": {"type": "object", "additionalProperties": False, "required": ["zones", "reactions"],
                      "properties": {"zones": {"type": "integer", "minimum": 1, "maximum": 16},
                                     "reactions": {"type": "integer", "minimum": 1, "maximum": 64},
                                     "gestures": {"type": "integer", "minimum": 0, "maximum": 16}}},
            "ult": {"type": "object", "additionalProperties": False, "required": ["beats", "short", "rig_clip", "name_key"],
                    "properties": {"beats": {"type": "integer", "minimum": 1, "maximum": 12},
                                   "full": {"type": "string", "pattern": "^ult/[a-z0-9_]+\\.ogv$"},
                                   "short": {"type": "string", "pattern": "^ult/[a-z0-9_]+\\.(ogv|json)$"},
                                   "rig_clip": {"type": "string", "pattern": "^ult/[a-z0-9_]+\\.json$"},
                                   "name_key": {"type": "string", "pattern": "^ult\\.[a-z]+\\.[a-z0-9_]+$"}}},
            "voice": {"type": "object", "additionalProperties": False, "required": ["lines"],
                      "properties": {"lines": {"type": "array", "items": {
                          "type": "object", "additionalProperties": False, "required": ["id", "bond", "subtitle_key"],
                          "properties": {"id": {"type": "string", "pattern": "^[a-z][a-z0-9_]{2,40}$"},
                                         "bond": {"type": "integer", "minimum": 0, "maximum": 10},
                                         "tags": {"type": "array", "items": {"type": "string", "pattern": "^[a-z_]+$"}},
                                         "subtitle_key": {"type": "string", "pattern": "^[a-z][a-z0-9_.]*$"}}}}}},
            "audio": {"type": "object", "additionalProperties": False,
                      "properties": {"sting_equip": {"type": "string"}, "sting_ult": {"type": "string"},
                                     "sfx": {"type": "array", "maxItems": 8, "items": {"type": "string"}},
                                     "loop_menu": {"type": "string"}}},
            "slots": {"type": "object", "propertyNames": {"pattern": "^[a-z]{2,3}\\.[a-z0-9_.]+$"}, "additionalProperties": SLOT_ENTRY},
            "files": {"type": "array", "items": {
                "type": "object", "additionalProperties": False, "required": ["path", "bytes", "sha256", "status"],
                "properties": {"path": {"type": "string", "pattern": "^[a-z0-9_]+(/[a-z0-9_]+)*\\.[a-z0-9]{2,5}$", "maxLength": 96},
                               "bytes": {"type": "integer", "minimum": 1, "maximum": 2621440},
                               "sha256": {"type": "string", "pattern": "^[0-9a-f]{64}$"},
                               "status": {"enum": ["approved", "pending", "rejected"]}}}},
            "budget": {"type": "object", "additionalProperties": False, "required": ["disk_mb", "vram_lobby_mb", "vram_match_mb"],
                       "properties": {"disk_mb": {"type": "number", "minimum": 0, "maximum": 40},
                                      "vram_lobby_mb": {"type": "number", "minimum": 0, "maximum": 60},
                                      "vram_match_mb": {"type": "number", "minimum": 0, "maximum": 30},
                                      "particles_full": {"type": "integer", "minimum": 0, "maximum": 200}}},
            "qa": {"type": "object", "additionalProperties": False, "required": ["adult_face", "red_line", "palette_lint", "ocr"],
                   "properties": {"adult_face": {"$ref": "#/$defs/signoff"},
                                  "red_line": {"type": "object", "additionalProperties": False, "required": ["by", "date"],
                                               "properties": {"by": {"type": "array", "items": {"type": "string", "minLength": 2},
                                                                     "minItems": 2, "uniqueItems": True},
                                                              "date": {"$ref": "#/$defs/date"}}},
                                  "palette_lint": {"enum": ["pass", "fail", "pending"]}, "ocr": {"enum": ["pass", "fail", "pending"]},
                                  "perf": {"type": "object"}}},
            "provenance": {"type": "object", "additionalProperties": False, "required": ["tool", "prompt_log_sha256", "metadata_scrubbed"],
                           "properties": {"tool": {"type": "string", "maxLength": 40}, "element": {"type": "string", "maxLength": 40},
                                          "prompt_log_sha256": {"type": "string", "pattern": "^[0-9a-f]{64}$"},
                                          "ad_pass": {"type": "array", "items": {"type": "object"}},
                                          "metadata_scrubbed": {"const": True}}},
            "release": {"type": "object", "additionalProperties": False,
                        "properties": {"banner": {"type": "string"}, "announce": {"type": "string"}, "direct_sale_from_day": {"type": "integer"}}},
            "fallbacks": {"type": "object", "additionalProperties": False, "required": ["hero_base", "global", "vector"],
                          "properties": {"hero_base": {"type": ["string", "null"], "pattern": "^[a-z][a-z0-9]{1,15}_base$"},
                                         "global": {"const": "five_winds"}, "vector": {"const": True}}},
        },
        "$defs": {
            "crop": {"type": "object", "additionalProperties": False, "required": ["crop"],
                     "properties": {"crop": {"type": "array", "minItems": 4, "maxItems": 4,
                                             "items": {"type": "number", "minimum": 0, "maximum": 1}}}},
            "date": {"type": "string", "pattern": "^20[0-9]{2}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$"},
            "signoff": {"type": "object", "additionalProperties": False, "required": ["by", "date"],
                        "properties": {"by": {"type": "string", "minLength": 2}, "date": {"$ref": "#/$defs/date"}}},
        },
        "x-tiers": TIERS,
        "x-tier-rules": {t: {"hud_level": HUD_LEVEL[t], "rank": TIER_RANK[t], "themes": THEMES_BY_TIER[t],
                             "boldness": BOLDNESS_BY_TIER[t], "min_voice_lines": MIN_VOICE[t], "min_ult_beats": MIN_ULT_BEATS[t],
                             "disk_budget_mb": DISK_BUDGET_MB[t]} for t in TIERS},
        "x-disk-tolerance": DISK_TOL,
        "x-max-file-kb": MAX_FILE_KB, "x-max-video-kb": MAX_VIDEO_KB,
        "x-slot-registry": R,
        "x-color-slots": COLOR_SLOTS,
        "x-locked-slots": LOCKED_SLOTS,
        "x-locked-tokens": LOCKED_TOKENS,
        "x-forbidden-extensions": [".ttf", ".otf", ".woff", ".woff2", ".gd", ".gdc", ".cs", ".dll", ".so", ".apk", ".exe", ".sh", ".py",
                                   ".js", ".gdshader", ".shader", ".res", ".tres"],  # .res/.tres: binary/text resources may embed scripts or method tracks (review T12)
        "x-forbidden-keys": ["font", "fonts", "font_size", "font_override", "theme_override", "script", "scripts", "shader", "shaders",
                             "tokens", "token_overrides", "layout", "geometry", "hit_size", "hit_target", "size_override", "timing",
                             "bus_volume", "url", "urls", "exec", "command"],
        "x-vo-minimum-note": "voice lines count is checked against x-tier-rules[tier].min_voice_lines (SL-MAN-09)",
    }


def godot_fixture() -> dict:
    """Minimal resolver data for the Godot soak test (no palette code exists in game/ yet): ramps + slot rules, hex literals allowed
    here because this is a TEST FIXTURE under game/tests (the NO_RAW_HEX lint scans game/shell and game/core)."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import build_palette_ramps as bpr
    doc = bpr.finalize(bpr.build())
    colors = doc["colors"]
    hx = lambda n: colors[n]["hex"]                                        # noqa: E731
    heroes = {h: {s: hx(f"HERO_{h.upper()}_{s}") for s in ("H100", "H300", "H500", "H700", "H900")} for h in bpr.PROPOSED_HEROES}
    themes = {t: {f"T{i}": hx(f"THEME_{t}_T{i}") for i in range(1, 6)} for t in bpr.PROPOSED_THEMES if t != "NEON2"}
    neutrals = {n: hx(n) for n in ("NIGHT_900", "NIGHT_800", "NIGHT_700", "NIGHT_600", "NIGHT_500", "NIGHT_400", "PLATE_RIM", "PLATE_SPARK")}
    sch = schema()
    return {"_doc": "GENERATED by tools/qa/build_skin_schema.py from palette_ramps.json + skin_manifest.schema.json. Test fixture only.",
            "heroes": heroes, "themes": themes, "neutrals": neutrals, "slots": sch["x-color-slots"],
            "locked_slots": sch["x-locked-slots"], "locked_tokens": sch["x-locked-tokens"],
            "tiers": {t: {"hud_level": r["hud_level"], "themes": r["themes"]} for t, r in sch["x-tier-rules"].items()}}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--out", default=str(OUT))
    a = ap.parse_args(argv)
    text = json.dumps(schema(), ensure_ascii=False, indent=1) + "\n"
    ftext = json.dumps(godot_fixture(), ensure_ascii=False, indent=1) + "\n"
    out = Path(a.out)
    if a.check:
        if not out.exists() or out.read_text(encoding="utf-8") != text or not GODOT_FIX.exists() or GODOT_FIX.read_text(encoding="utf-8") != ftext:
            print("SKIN_SCHEMA STALE: re-run python tools/qa/build_skin_schema.py")
            return 1
        print("SKIN_SCHEMA OK")
        return 0
    out.write_text(text, encoding="utf-8")
    GODOT_FIX.parent.mkdir(parents=True, exist_ok=True)
    GODOT_FIX.write_text(ftext, encoding="utf-8")
    print(f"wrote {out} ({len(text)//1024} KiB, {len(R)} registry slots, {len(COLOR_SLOTS)} colour slots)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
