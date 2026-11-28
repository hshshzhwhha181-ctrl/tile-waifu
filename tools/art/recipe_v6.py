#!/usr/bin/env python3
"""Art factory v6 prompt assembler: identity + outfit (with coverage rule) + proportions + anatomy + joint-by-joint pose + setting + tail.

Recipe, rules and evidence: design/art_v6/ANATOMY_RECIPE.md.  Poses: design/art_v6/pose_library.json.  Slot -> pose: design/art_v6/assignments.json.
This module builds prompts only; it does not call any generator and spends nothing.

  python tools/art/recipe_v6.py --show mc base 0          # print one prompt (heroine, slot, idx)
  python tools/art/recipe_v6.py --dump out.jsonl           # all 170 prompts as jsonl
  python tools/art/recipe_v6.py --selftest                 # build all 170 and run the validator word / proportion checks
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_art_batches as B  # noqa: E402
import full_tier_wardrobe as WD  # noqa: E402
import validate_batches as V  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "design" / "art_v6" / "pose_library.json"
ASSIGN = ROOT / "design" / "art_v6" / "assignments.json"
RECIPE_MD = ROOT / "design" / "art_v6" / "ANATOMY_RECIPE.md"
GRAMMAR_ID = "v6a"

# ---------------------------------------------------------------------------------------------------------------------------------
# Coverage rule per outfit class (the decisive fix of the bake-off: hem rule took 13/24 hard-line fails to 0/18).  Positive wording only.
# ---------------------------------------------------------------------------------------------------------------------------------
RULES = {
    "long": ("SLIT RULE: the long skirt panels always fall in place; the side slit opens no higher than the upper thigh and only the skin of the thigh shows through it; "
             "an opaque lining always covers the hip and the buttocks, from behind, from the side and in every pose; no bare skin of the hip or the buttocks is ever visible."),
    "mini": ("HEM RULE: the opaque skirt or shorts hem always stays in place and fully covers the buttocks from behind, from the side and in every pose; "
             "no bare skin of the buttocks is ever visible and the skin between the hem and the stocking tops is only the thigh."),
    "leo": ("LEOTARD RULE: the high-cut leotard is opaque and lined with a full-coverage seat that covers the whole buttocks; the cut at the hip shows only the outer flank, "
            "never a thong cut; no bare skin of the buttocks is ever visible, from behind, from the side or in any pose."),
    "swim": ("SWIM RULE: the bikini or swimsuit bottoms are an opaque full-coverage cut with side ties at the hips that covers the whole buttocks in every pose, and the wet-look sheer sarong or shirt stays tied on; "
             "no bare skin of the buttocks is ever visible, from behind, from the side or in any pose."),
    "robe": ("ROBE RULE: the satin robe stays belted by its sash and closed over the lined mini nightgown, the nightgown hem stays at mid-thigh, and the robe covers the hips and the buttocks "
             "from behind, from the side and in every pose; no bare skin of the buttocks is ever visible."),
}
ANAT = ("ANATOMY RULES: exactly two arms and two legs, two hands with five fingers each, two feet; no duplicated, extra or fused limbs; both legs clearly separate and countable; "
        "thighs full and soft but anatomically proportional: each thigh is narrower than the pelvis at the hip line and the two thighs together are never wider than the shoulders; "
        "knees and calves visible with a calf taper to the ankle; natural foot size, no exaggerated perspective on shins or feet. "
        "The body twist is physically continuous: pelvis, buttocks and legs rotate together with the torso, the spine twists gradually through waist and ribcage and only the head and neck turn further.")
CAMERA = "Camera: portrait lens (long focal length) at hip height or higher, no wide-angle distortion, no from-below angle, the legs never enlarged by perspective."
THIGH = {  # per-heroine thigh clause (lush but proportional; wording tuned in the bake-off: 'balloon' removed, knee and calf taper added)
    "mc":      "Thighs: full, soft, athletic-proportional thighs with a visible knee and a calf taper, lush but narrower than the hip line.",
    "miel":    "Thighs: thick, shapely, soft thighs with a visible knee and a calf taper; the hips are the widest point of the pear shape, the thighs narrower than the hip line.",
    "kohaku":  "Thighs: full, soft, athletic-proportional thighs with a visible knee and a calf taper, narrower than the hip line.",
    "zlata":   "Thighs: full, firm, regal thighs balanced by broad shoulders, a visible knee and a calf taper, narrower than the hip line.",
    "rin":     "Thighs: full, soft, slender-proportional thighs with a visible knee and a calf taper, narrower than the hip line.",
    "yue":     "Thighs: full, graceful thighs balanced by the shoulders, a visible knee and a calf taper, narrower than the hip line.",
    "shirin":  "Thighs: full, soft, shapely thighs with a visible knee and a calf taper, narrower than the hip line.",
    "hana":    "Thighs: strong, athletic-proportional thighs with soft definition, a visible knee and a defined calf taper, narrower than the hip line.",
    "tsubame": "Thighs: slim, toned, shapely thighs with a visible knee and a calf taper.",
    "nova":    "Thighs: slim, toned, shapely thighs with a visible knee and a calf taper.",
}
V6_TAIL = B.FULL_TAIL.replace("{figure} a direct ", "A direct ").replace("portrait-lens camera with a long focal length at hip height or higher and no wide-angle distortion, ", "")


def proportions(hk: str) -> str:
    b = WD.HEIGHTS[hk]
    return (f"Proportions (binding): adult woman, {b['heads']} heads tall ({b['cm']} cm, {b['tag']}), a slightly larger head and shoulders, a compact torso and balanced proportions: "
            f"the crotch line sits at about {WD.CROTCH_PCT}% of her total height and her leg length from crotch to floor is no longer than her shoulder-to-crotch length plus one head; "
            f"{b['legs']}; a mature adult face and figure, a defined waist, a full natural bust in proportion.")


def adapt_outfit(outfit: str, pose: dict) -> str:
    """Bake-off V1h outfit grammar: moderate court heels instead of stilettos (stilettos add 5-8% to the leg line); the slit is lowered on every pose that shows the rear, a kneel or a lying hip."""
    o = re.sub(r"\bstiletto heels\b", "court heels of moderate height", outfit)
    o = re.sub(r"\bstilettos\b", "moderate court heels", o)
    o = re.sub(r"\bstiletto\b", "court", o)
    if pose["hips_in_frame"] and (pose["rear_emphasis"] or pose["category"] in ("kneeling", "lying")):
        o = re.sub(r"\b(side )?slit (up )?to the hip\b", lambda m: (m.group(1) or "") + "slit up to the upper thigh", o)
        o = re.sub(r"\ba (side )?slit up to the hip\b", lambda m: "a " + (m.group(1) or "") + "slit up to the upper thigh", o)
    return o


def load():
    lib = {p["id"]: p for p in json.loads(LIB.read_text(encoding="utf-8"))["poses"]}
    asg = json.loads(ASSIGN.read_text(encoding="utf-8"))
    return lib, asg


def slot_setting(h: dict, hk: str, slot: str) -> str:
    if slot.startswith("canon_"):
        return f"softly blurred teahouse interior with paper lanterns, background {B.secondary_color_words(h)}"
    return WD.outfit(hk, slot)["setting"]


def build_prompt(H: dict, lib: dict, hk: str, slot: str, pose_id: str, prop: str = "") -> str:
    h = H[hk]
    pose = lib[pose_id]
    base_slot = "base" if slot.startswith("canon_") else slot
    cls = _class_of(hk, base_slot)
    outfit = adapt_outfit(WD.outfit(hk, base_slot)["outfit"], pose)
    rule = (" " + RULES[cls]) if pose["hips_in_frame"] else ""
    setting = slot_setting(h, hk, slot) + (f"; the pose uses {prop}" if prop else "")
    framing = pose["framing"] if not slot.startswith("canon_") or pose["framing_code"] in ("P", "F") else "full-body from head to heels, centered"
    ident = B.identity_block(h, B.body_line(hk), B.FULL_SKIN.get(hk))
    txt = (f"{ident} Outfit: {outfit}.{rule} {proportions(hk)} {THIGH[hk]} {ANAT} {CAMERA} {pose['prompt']} "
           f"Expression: {pose['expression_hint']}. Framing: {framing}. Setting: {setting}. {V6_TAIL}")
    return re.sub(r"\s+", " ", txt).strip()


def _class_of(hk, slot):
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import assign_poses as A
    return A.OUTFIT_CLASS[hk][slot]


def build_all():
    H = B.load_heroines()
    lib, asg = load()
    out = []
    for hk, h in asg["heroines"].items():
        for s in h["slots"]:
            p = build_prompt(H, lib, hk, s["slot"], s["pose_id"], s.get("prop", ""))
            out.append(dict(id=f"{hk}.{s['slot']}.{s['idx']}", heroine=hk, slot=s["slot"], idx=s["idx"], pose_id=s["pose_id"], element_id=H[hk]["element_id"], prompt=p))
    return out


def selftest() -> int:
    items = build_all()
    errs = []
    lens = [len(i["prompt"]) for i in items]
    ids = set()
    for it in items:
        t, hk = it["prompt"], it["heroine"]
        w = WD.HEIGHTS[hk]
        if it["id"] in ids:
            errs.append(f"{it['id']}: duplicate id")
        ids.add(it["id"])
        for m in V.RE_HARD.finditer(t):
            errs.append(f"{it['id']}: hard-banned word '{m.group(0)}'")
        for m in V.RE_PROP.finditer(t):
            errs.append(f"{it['id']}: proportion-banned phrase '{m.group(0)}'")
        hs = [float(x) for x in V.HEADS_RE.findall(t)]
        if not hs or any(abs(x - w["heads"]) > 0.011 for x in hs) or not all(WD.HEADS_MIN <= x <= WD.HEADS_MAX for x in hs):
            errs.append(f"{it['id']}: heads {hs} vs table {w['heads']}")
        for need in ("mature adult face", "crotch line", "shoulder-to-crotch", WD.FIGURE[hk], "no text", "ANATOMY RULES", "POSE, joint by joint"):
            if need not in t:
                errs.append(f"{it['id']}: missing '{need[:40]}'")
        if t.count(f"<<<{it['element_id']}>>>") != 1 or len(V.UUID_RE.findall(t)) != 1:
            errs.append(f"{it['id']}: element id count")
        if "stiletto" in t.lower():
            errs.append(f"{it['id']}: stiletto left in the outfit")
    # the documented rule blocks must equal the code (doc drift guard)
    if RECIPE_MD.exists():
        md = RECIPE_MD.read_text(encoding="utf-8")
        for k, v in list(RULES.items()) + [("ANAT", ANAT), ("CAMERA", CAMERA)]:
            if v not in md:
                errs.append(f"ANATOMY_RECIPE.md does not contain the {k} block verbatim")
    else:
        errs.append("ANATOMY_RECIPE.md missing")
    for e in errs[:40]:
        print("ERROR", e)
    print(f"RECIPE_V6 {'OK' if not errs else 'FAIL'}: {len(items)} prompts, length min/avg/max {min(lens)}/{sum(lens)//len(lens)}/{max(lens)} chars, {len(errs)} errors")
    return 1 if errs else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--show", nargs=3, metavar=("HEROINE", "SLOT", "IDX"))
    ap.add_argument("--dump")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    items = build_all()
    if a.show:
        hk, slot, idx = a.show[0], a.show[1], int(a.show[2])
        for it in items:
            if it["heroine"] == hk and it["slot"] == slot and it["idx"] == idx:
                print(it["prompt"])
                return 0
        print("not found", file=sys.stderr)
        return 1
    if a.dump:
        Path(a.dump).write_text("\n".join(json.dumps(i, ensure_ascii=False) for i in items) + "\n", encoding="utf-8")
        print(f"wrote {len(items)} prompts to {a.dump}")
        return 0
    ap.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
