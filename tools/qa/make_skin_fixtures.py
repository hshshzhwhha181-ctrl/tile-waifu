#!/usr/bin/env python3
"""make_skin_fixtures.py - deterministic generator of the 3 sample skin manifests under tools/qa/fixtures/skins/:
  valid/yue_ssr_scalearmor/manifest.json      passes skin_lint (tier ssr, L1, theme MOON, B2, every required slot, 1 dye)
  invalid_hex/yue_ssr_hexrim/manifest.json    raw hex + rgb() literals in palette.slots (SL-PAL-01, SL-MAN-01, SL-PAL-02)
  missing_slot/yue_ssr_noboard/manifest.json  slots bg.board, kit.nine.window, kit.cta_overlay removed (SL-SLOT-05)
The manifests describe a pack whose files do not exist on disk (lint without --check-files). Tests build real packs separately.
"""
from __future__ import annotations

import copy
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_skin_schema as bss  # noqa: E402

OUT = Path(__file__).resolve().parent / "fixtures" / "skins"
GODOT = Path(__file__).resolve().parents[2] / "game" / "tests" / "fixtures" / "skins"      # copies read by the Godot skin_swap_soak test
FOLDER = {"art": "art", "rig": "rig", "kit": "kit", "cf": "kit", "bg": "bg", "tl": "bg", "fx": "fx", "ult": "ult", "bt": "battle", "au": "audio"}
EXT = {"tex": "webp", "tex9": "webp", "particles": "webp", "video": "ogv", "audio": "ogg", "clip": "json", "rig": "tscn", "anim": "webp"}


def slot_file(name: str, kind: str) -> str:
    grp, rest = name.split(".", 1)
    rest = rest.replace(".", "_")
    if name == "rig.scene":
        return "rig/rig.tscn"
    if name == "rig.touchmap":
        return "rig/touchmap.png"
    if grp == "ult":
        rest = "ult_" + rest.replace("rig_clip", "rig")
    if name == "ult.short":
        return "ult/ult_short.ogv"
    return f"{FOLDER[grp]}/{rest}.{EXT[kind]}"


def build_valid() -> dict:
    sch = bss.schema()
    reg = sch["x-slot-registry"]
    tier, rank = "ssr", 2
    slots, files = {}, {}
    dims = {"tex9": (96, 96, [24, 24, 24, 24])}
    for name, r in sorted(reg.items()):
        if r["min_tier"] > rank:
            continue
        kind = "video" if name == "ult.short" else r["kind"]
        f = slot_file(name, r["kind"])
        ent = {"file": f, "kind": kind, "fallback": "vector" if r["vector"] else ("base" if name.startswith(("art.", "rig.", "ult.")) else "global")}
        if r["kind"] == "tex9":
            ent.update(w=96, h=96, nine=[24, 24, 24, 24])
        if r["kind"] == "video":
            ent.update(w=540 if name.startswith("bg") else 720, h=960 if name.startswith("bg") else 1280, fps=24, loop=name.startswith("bg"))
        slots[name] = ent
        size = int(min(r["max_kb"], 2400) * 1024 * 0.42)
        files[f] = {"path": f, "bytes": size, "sha256": hashlib.sha256(f.encode()).hexdigest(), "status": "approved"}
    total = sum(x["bytes"] for x in files.values()) / 1048576
    lines = [{"id": f"yue_ssr_scalearmor_{n}", "bond": b, "tags": t, "subtitle_key": f"vo.yue_ssr_scalearmor.{n}"}
             for n, b, t in [("greet", 0, ["menu"]), ("equip", 0, ["equip"]), ("touch_hand", 1, ["touch"]), ("touch_head", 2, ["touch"]),
                             ("win", 3, ["win"]), ("ult_cast", 3, ["ult"]), ("night", 5, ["menu"]), ("vow_hint", 7, ["bond"])]]
    return {
        "schema": 1, "id": "yue_ssr_scalearmor", "hero": "yue", "tier": tier, "name_ru": "Чешуйчатая броня", "season": "S1",
        "hud_level": 1, "theme": "MOON", "boldness": "B2", "pack_ver": "1.0.0", "engine": "4.5.x", "min_game": "1.0.0",
        "proportions": {"heads": 7.5, "height_cm": 168},
        "palette": {"hero": "yue", "theme": "MOON", "slots": {
            "rim": "T3", "rim_spark": "H100", "plate_top": "NIGHT_700+T5@0.12", "plate_bot": "NIGHT_800+T5@0.12",
            "plate_sel_top": "NIGHT_600+T5@0.2", "plate_sel_bot": "NIGHT_700+T5@0.2",
            "btn_play_top": "H300", "btn_play_mid": "H500", "btn_play_bot": "H700", "btn_play_down_top": "H500", "btn_play_down_bot": "H900",
            "btn_play_outline": "H900", "btn_play_glow": "H100", "tab_active": "T3", "lantern_body": "T3", "lantern_flame": "T2",
            "tray_frame": "NIGHT_700+T5@0.1", "tray_slot_bg": "NIGHT_800+T5@0.1", "sheet_bg": "NIGHT_700+T5@0.08",
            "window_bg": "NIGHT_800+H900@0.06", "tile_select_ring": "H300", "match_spark": "H100", "ult_ring": "H300",
            "fx_glow": "T2", "sting_flash": "T1"}},
        "dyes": [{"id": "dye_1", "theme": "TIDE", "slots": {"rim": "T3", "tab_active": "T2", "fx_glow": "T2"}}],
        "presence": {"full": {"crop": [0.05, 0.02, 0.9, 0.96]}, "std": {"crop": [0.12, 0.1, 0.76, 0.42]},
                     "min": {"medallion": "art/medallion.webp"}},
        "rig": {"scene": "rig/rig.tscn", "bones": 34, "polys": 24, "verts": 1900, "spring_chains": 4, "spring_bones": 20, "fps_full": 60, "fps_std": 30},
        "faces": ["neutral", "smile", "shy", "surprised", "pout", "wink"],
        "touch": {"zones": 6, "reactions": 18, "gestures": 3},
        "ult": {"beats": 6, "full": "ult/ult_full.ogv", "short": "ult/ult_short.ogv", "rig_clip": "ult/ult_rig.json", "name_key": "ult.ssr.yue_scalearmor"},
        "voice": {"lines": lines},
        "slots": slots,
        "files": [files[k] for k in sorted(files)],
        "budget": {"disk_mb": round(total, 2), "vram_lobby_mb": 24, "vram_match_mb": 14, "particles_full": 64},
        "qa": {"adult_face": {"by": "ad_anna", "date": "2026-11-20"}, "red_line": {"by": ["qa_boris", "qa_vera"], "date": "2026-11-21"},
               "palette_lint": "pass", "ocr": "pass", "perf": {"ref_l_fps_p5": 58, "ref_l_ms_p95": 15.2}},
        "provenance": {"tool": "gpt_image_2_6", "element": "yue_main", "prompt_log_sha256": hashlib.sha256(b"yue_ssr_scalearmor").hexdigest(),
                       "ad_pass": [{"layer": "card", "by": "ad_anna", "date": "2026-11-19"}], "metadata_scrubbed": True},
        "fallbacks": {"hero_base": "yue_base", "global": "five_winds", "vector": True},
    }


def drop_slots(doc: dict, names) -> dict:
    d = copy.deepcopy(doc)
    gone = {d["slots"].pop(n)["file"] for n in names}
    d["files"] = [f for f in d["files"] if f["path"] not in gone]
    d["budget"]["disk_mb"] = round(sum(f["bytes"] for f in d["files"]) / 1048576, 2)
    return d


def rename(doc: dict, new_id: str) -> dict:
    d = copy.deepcopy(doc)
    d["id"] = new_id
    d["ult"]["name_key"] = "ult.ssr." + new_id.split("_", 2)[2]
    return d


def write(rel: str, doc: dict):
    p = OUT / rel / "manifest.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def main() -> int:
    v = build_valid()
    write("valid/yue_ssr_scalearmor", v)
    bad = rename(v, "yue_ssr_hexrim")
    bad["palette"]["slots"]["rim"] = "#C99E54"
    bad["palette"]["slots"]["plate_top"] = "#26212A"
    bad["palette"]["slots"]["fx_glow"] = "rgb(255, 0, 0)"
    write("invalid_hex/yue_ssr_hexrim", bad)
    GODOT.mkdir(parents=True, exist_ok=True)
    for name, doc in (("valid_yue_ssr_scalearmor.json", v), ("invalid_hex_yue_ssr_hexrim.json", bad)):
        (GODOT / name).write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    write("missing_slot/yue_ssr_noboard", rename(drop_slots(v, ["bg.board", "kit.nine.window", "kit.cta_overlay"]), "yue_ssr_noboard"))
    print(f"fixtures written under {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
