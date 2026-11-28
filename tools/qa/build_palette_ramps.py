#!/usr/bin/env python3
"""build_palette_ramps.py - (re)generates design/specs/palette_ramps.json, the machine palette used by tools/qa/palette_audit.py.

Sources, in this order of authority:
  1. game/shell/design/tokens.json           status "repo"      (the shipped palette; NEVER edited here)
  2. design/specs/PALETTE_LOCK.md (branch claude/spec-skin) -> constants PROPOSED below, status "proposed"
     (hero ramps H100..H900, 8 skin themes, rarity colours, new neutral steps). Until RFC PAL-0001 is accepted they are a
     DRAFT: the audit accepts them by default and marks hits as "proposed" in the report (use --repo-only to forbid them).
  3. V10ProfileCos.TIER_COL / TIER_DARK        status "legacy"    (old rarity colours; allowed so existing art is not flagged for them)

  python tools/qa/build_palette_ramps.py            # write design/specs/palette_ramps.json
  python tools/qa/build_palette_ramps.py --check    # exit 1 if the file is stale vs tokens.json (CI-cheap, stdlib only)
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TOKENS = REPO / "game" / "shell" / "design" / "tokens.json"
OUT = REPO / "design" / "specs" / "palette_ramps.json"

# token-name prefix -> (family, kind). First match wins; order matters (BTN_PLAY before BTN_).
FAMILIES = [
    ("NIGHT_", "NIGHT", "chrome"), ("PAPER_", "PAPER", "chrome"), ("PLATE_RIM", "GOLD", "gold_chrome"),
    ("PLATE_SPARK", "GOLD", "gold_chrome"), ("PLATE_", "PLATE", "chrome"), ("GOLD_", "GOLD", "gold_chrome"),
    ("ROSE_", "ROSE", "brand"), ("BTN_PLAY_", "BTN_PLAY", "brand"), ("BTN_SEC_", "BTN_SEC", "chrome"),
    ("BTN_CASH_", "BTN_CASH", "chrome"), ("JADE_", "JADE", "semantic"), ("CINNABAR", "RED", "semantic"),
    ("EMBER", "RED", "semantic"), ("FELT_", "FELT", "chrome"), ("TINT_", "TINT", "chrome"), ("SHADOW", "SHADOW", "chrome"),
]

# ---- PROPOSED (PALETTE_LOCK v1.0 draft, branch claude/spec-skin) -- [ГИПОТЕЗА] until RFC PAL-0001 --------------------------
PROPOSED_NEUTRAL = {"NIGHT_500": "#403B44", "NIGHT_400": "#59535D", "GOLD_900": "#65461D", "ROSE_900": "#5E293A",
                    "JADE_700": "#2B5748", "LAV_100": "#E6DFFE", "LAV_300": "#CFBEFF", "LAV_500": "#8A7CB2",
                    "LAV_700": "#57497A", "SEM_ERR_TEXT": "#ED7668"}
PROPOSED_HEROES = {  # H100 H300 H500 H700 H900 (H500 of mc/rin/hana/yue/nova/zlata == tokens.json accent)
    "mc": ["#F9E1E7", "#E6B4C3", "#F2A7BF", "#AB6D81", "#2F161F"],
    "rin": ["#D7EEE4", "#A0D1BC", "#7FCFB0", "#488E74", "#07251B"],
    "hana": ["#FBE3CB", "#EBB985", "#FFB25A", "#B77623", "#2F1A01"],
    "yue": ["#EBE4F7", "#CABCE4", "#C9B2F0", "#8A76AA", "#231B2F"],
    "nova": ["#D0EFF2", "#8CD2D9", "#6FE6F2", "#36A4AE", "#002528"],
    "zlata": ["#FEE1D3", "#FFAE86", "#FF7A2A", "#AA4901", "#371300"],
    "tsubame": ["#FEDFDF", "#FEAAAB", "#C4233F", "#6B001A", "#3F050E"],
    "miel": ["#FEE0DE", "#FEAAA7", "#E25358", "#951626", "#3D090D"],
    "kohaku": ["#FFE0D8", "#FEAD96", "#D73B02", "#7A1D00", "#3D0A00"],
    "shirin": ["#D3EEEC", "#95D1CD", "#4EB4AF", "#0B7571", "#012524"],
}
PROPOSED_THEMES = {  # T1..T5
    "SAKURA": ["#F9DBE4", "#EBB2C4", "#CA7E98", "#8C4C63", "#45202E"],
    "MOON": ["#E7E0FA", "#C9BBEC", "#A08BCE", "#6A5790", "#322748"],
    "JADE": ["#D5EBE1", "#A4D0BD", "#69A78F", "#39705B", "#143529"],
    "EMBER": ["#FFDBD4", "#FDAD9C", "#E17460", "#9E4232", "#501910"],
    "TIDE": ["#CCECED", "#90D2D5", "#41AAAF", "#077176", "#003538"],
    "NEON": ["#C0EEF9", "#72D5EC", "#01AAC6", "#016F82", "#02343E"],
    "NEON2": ["#F8D9F4", "#E9ADE3", "#C876C1", "#8A4585", "#441B41"],
    "INK": ["#E6E3E8", "#C7C2CB", "#9C95A2", "#66616B", "#302C32"],
    "GILT": ["#F0E3CB", "#DBC090", "#B7924B", "#7D5D1C", "#3D2A02"],
}
PROPOSED_RARITY = {"RARITY_R": "#30C883", "RARITY_S": "#D2D6EC", "RARITY_SSR": "#FFC93C", "RARITY_R_DARK": "#1E5A3C",
                   "RARITY_S_DARK": "#44455D", "RARITY_SSR_DARK": "#6E4210", "RARITY_FOIL_1": "#F1D9A0",
                   "RARITY_FOIL_2": "#ECC0C9", "RARITY_FOIL_3": "#D2D6EC"}
LEGACY_RARITY = {"LEGACY_TIER_A": "#74DCB8", "LEGACY_TIER_S": "#CDBFFF", "LEGACY_TIER_SSR": "#FFCF5A",
                 "LEGACY_TIER_A_DARK": "#1D5A49", "LEGACY_TIER_S_DARK": "#3E3470"}

# ---- profiles: what "PASS/WARN/FAIL" means for each kind of image (all numbers [ГИПОТЕЗА], calibrate with --calibrate) ------
PROFILES = {
    "chrome": {"doc": "UI chrome/plates/buttons/HUD kit: must live on the ramps (PALETTE_LOCK A3/A4/A5)",
               "mode": "absolute", "flat_tol": 0.04, "k": 10, "min_area_pct": 1.5, "warn_de": 3.5, "fail_de": 6.0,
               "chroma_cap_oklch": 0.14, "chroma_cap_min_area_pct": 1.0, "gold_band_cap_pct": 4.0},
    "icon": {"doc": "icons / small glyphs: same discipline as chrome, fewer clusters",
             "mode": "absolute", "flat_tol": 0.04, "k": 6, "min_area_pct": 2.0, "warn_de": 4.5, "fail_de": 8.0,
             "chroma_cap_oklch": 0.16, "chroma_cap_min_area_pct": 2.0, "gold_band_cap_pct": 100.0},
    "fx": {"doc": "particles/glows/overlays with alpha: lenient (additive blending shifts colours)",
           "mode": "absolute", "flat_tol": 0.06, "k": 6, "min_area_pct": 2.0, "warn_de": 7.0, "fail_de": 14.0,
           "chroma_cap_oklch": 0.20, "chroma_cap_min_area_pct": 3.0, "gold_band_cap_pct": 100.0},
    "art": {"doc": "painted art (heroines, outfits, backgrounds, CG): palette match is NOT required; only 'garish outlier' "
                   "and the relative/baseline drift checks apply",
            "mode": "relative", "k": 8, "min_area_pct": 3.0, "warn_de": None, "fail_de": None,
            "garish_chroma_oklch": 0.24, "garish_min_area_pct": 3.0, "garish_min_de": 12.0, "gold_band_cap_pct": 100.0},
}
# ordered, first match on the POSIX relative path (regex, searched). category -> profile
CATEGORY_RULES = [
    ["golden_full/", "golden", "art"],
    ["hud2/combo/|/emotions/|/stickers/", "hero_art", "art"],
    ["assets/fx/|v10/hudfx/particles/|v06/fx/|/fx/", "fx", "fx"],
    ["assets/icons/|v06/icon|v08/ui/(icon|nav|rank|league|cur|misc)/|v10/hf_ui/|v10/hudfx/items/|v10/shop/(item|boost|set|moon|hanko)",
     "icons", "icon"],
    ["assets/tiles/|/tiles/|v10/mj/look/tile|v08/table/|v10/hudfx/card/", "tile_faces", "icon"],
    ["v10/shop/bg_|assets/bg/|v10/cg_16/|/scenes/|v10/path/|v10/salon", "bg_cg_art", "art"],
    ["assets/ui/|v08/ui/(btn|frame|bg)/|v10/hud2/|v10/phone/|v06/hud", "ui_chrome", "chrome"],
    ["assets/hero/|v10/rig/|v10/look/", "hero_art", "art"],
    ["assets/outfits/|/outfits/", "outfit_art", "art"],
    ["", "other", "art"],
]


def _family(token: str):
    for prefix, fam, kind in FAMILIES:
        if token.startswith(prefix):
            return fam, kind
    return "MISC", "chrome"


def build() -> dict:
    raw = TOKENS.read_bytes()
    tok = json.loads(raw)
    colors: dict[str, dict] = {}

    def add(name, hexv, family, kind, status, note=""):
        assert name not in colors, f"duplicate colour name {name}"
        e = {"hex": hexv.upper(), "family": family, "kind": kind, "status": status}
        if note:
            e["note"] = note
        colors[name] = e

    for name, hexv in sorted(tok["color"].items()):
        fam, kind = _family(name)
        add(name, hexv, fam, kind, "repo")
    for hid, h in sorted(tok["heroes"].items()):
        for part in ("accent", "deep", "glow"):
            add(f"HERO_{hid.upper()}_{part.upper()}", h[part], "HERO_" + hid.upper(), "hero", "repo")
    for name, hexv in PROPOSED_NEUTRAL.items():
        fam = name.split("_")[0]
        add(name, hexv, fam, "semantic" if fam in ("LAV", "SEM") else "chrome" if fam in ("NIGHT",) else
            "gold_chrome" if fam == "GOLD" else "brand" if fam == "ROSE" else "semantic", "proposed")
    for hid, steps in sorted(PROPOSED_HEROES.items()):
        for step, hexv in zip(("H100", "H300", "H500", "H700", "H900"), steps):
            add(f"HERO_{hid.upper()}_{step}", hexv, "HERO_" + hid.upper(), "hero", "proposed")
    for th, steps in sorted(PROPOSED_THEMES.items()):
        for i, hexv in enumerate(steps, 1):
            add(f"THEME_{th}_T{i}", hexv, "THEME_" + th, "theme", "proposed")
    for name, hexv in PROPOSED_RARITY.items():
        add(name, hexv, "RARITY", "rarity", "proposed")
    for name, hexv in LEGACY_RARITY.items():
        add(name, hexv, "RARITY", "rarity", "legacy", "V10ProfileCos.TIER_COL/TIER_DARK; to be replaced by RARITY_* (PALETTE_LOCK 2.3)")

    return {
        "_meta": {
            "schema": 1,
            "doc": "Machine palette for tools/qa/palette_audit.py. GENERATED by tools/qa/build_palette_ramps.py; do not edit by hand.",
            "tokens_source": "game/shell/design/tokens.json",
            "tokens_sha256": hashlib.sha256(raw).hexdigest(),
            "tokens_schema": tok["_meta"]["schema"],
            "proposed_source": "design/specs/PALETTE_LOCK.md @ branch claude/spec-skin (draft v1.0); [ГИПОТЕЗА] until RFC PAL-0001",
            "counts": {},
            "flag": "The shipped palette (tokens.json) has NO ramps for heroine steps, skin themes, rarity or LAV; "
                    "status=proposed entries are a first version defined by PALETTE_LOCK and are NOT yet in the code.",
        },
        "colors": colors,
        "profiles": PROFILES,
        "category_rules": CATEGORY_RULES,
    }


def finalize(doc: dict) -> dict:
    cnt: dict[str, int] = {}
    for e in doc["colors"].values():
        cnt[e["status"]] = cnt.get(e["status"], 0) + 1
    doc["_meta"]["counts"] = dict(sorted(cnt.items()))
    return doc


def dumps(doc: dict) -> str:
    return json.dumps(doc, ensure_ascii=False, indent=1, sort_keys=False) + "\n"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="exit 1 when design/specs/palette_ramps.json is stale")
    ap.add_argument("--out", default=str(OUT))
    a = ap.parse_args(argv)
    text = dumps(finalize(build()))
    out = Path(a.out)
    if a.check:
        if not out.exists() or out.read_text(encoding="utf-8") != text:
            print(f"PALETTE_RAMPS STALE: re-run python tools/qa/build_palette_ramps.py ({out})")
            return 1
        print("PALETTE_RAMPS OK (in sync with tokens.json)")
        return 0
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(f"wrote {out} ({len(text)//1024} KiB, {len(json.loads(text)['colors'])} colours)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
