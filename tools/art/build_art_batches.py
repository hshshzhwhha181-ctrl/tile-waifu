#!/usr/bin/env python3
"""Build design/art_batches/*.json (P59).  Text only: this script never calls any generator and spends nothing.

    python3 tools/art/build_art_batches.py            # rewrite every batch JSON + design/art_batches/index.json
    python3 tools/art/validate_batches.py             # then validate

Inputs live in design/art_batches/src/ (trimmed identity data of the 10 heroines, from lora-v2/heroines_v2.json).
Prices and counts come from the budget table in the P59 backlog entry (section 7, 'Арт-бэтчи Higgsfield и бюджет кредитов');
every number that is an assumption (not a quote) is marked `unit_cost_basis: "assumed"`.
"""
from __future__ import annotations

import argparse
import json
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "design" / "art_batches"
SRC = OUT / "src" / "heroines_v2.json"

# ----------------------------------------------------------------------------------------------------------------------
# Style tail.  Tier FULL is the art direction for every heroine batch (owner decision 2026-11-28, design/ART_TIER_FULL.md);
# there is no Standard / Neutral fallback tier.  Positive constraints only (gpt_image_2_6 has no negative prompt).
# The word list in validate_batches.py is applied to every prompt.
# ----------------------------------------------------------------------------------------------------------------------
NOTEXT = "no text, no letters or numerals, no logos, no watermark"

LORA_TRIGGER = "twmaster2 style"
LORA_ENV_TAIL = (
    "rich saturated painted anime gacha background, deep night palette with glowing practical lights, volumetric light shafts, warm "
    "and cool color contrast, glossy wet reflections, thin warm-colored lineart, soft painterly shading, empty scene, no "
    "characters, clean image with no lettering"
)
LORA_ENV_TAIL_DAY = (
    "rich saturated painted anime gacha background, luminous warm daylight, clear colors, thin warm-colored lineart, soft painterly "
    "shading, empty scene, no characters, clean image with no lettering"
)
LORA_TILES_TAIL = (
    "glossy painted anime gacha game art, ivory bone and black lacquer tiles with crisp specular highlights, thin warm-colored "
    "lineart, soft painterly shading, saturated jewel palette with a deep dark ground, no numerals, no letters, no logos, no people"
)
LORA_FX_TAIL = (
    "glowing painted anime game effect on a pure black background for additive blending, saturated jewel colors, thin warm-colored "
    "lineart, soft painterly shading, centered, no characters, no numerals, no letters, no logos"
)
LORA_UI_TAIL = (
    "dark lacquer mobile game ui background art, near-black plum ground with saturated rim glows, thin gold hairline details, soft "
    "volumetric light, blank plates and empty frames, absolutely no text, no letters, no numerals"
)

PX = {  # nominal pixel sizes; gpt_image_2_6 sizes are chosen by aspect + resolution tier, LoRA uses these directly
    "1:1": (1024, 1024), "2:3": (832, 1248), "3:4": (896, 1184), "9:16": (768, 1344), "16:9": (1344, 768), "4:3": (1184, 896),
}
GPT_LONG = {"1k": 1024, "2k": 2048}

CAND_FINAL = 2
OUTPUT_ROOT = "assets/incoming"


# ----------------------------------------------------------------------------------------------------------------------
def r2(x: float) -> float:
    return round(x + 1e-9, 2)


def seed_for(batch: str, tid: str) -> int:
    return 100000 + zlib.crc32(f"{batch}:{tid}".encode()) % 900000


def size_gpt(aspect: str, res: str) -> dict:
    w, h = PX[aspect]
    k = GPT_LONG[res] / max(w, h)
    return {"aspect": aspect, "resolution": res, "width": int(round(w * k / 8) * 8), "height": int(round(h * k / 8) * 8)}


def size_lora(aspect: str) -> dict:
    w, h = PX[aspect]
    return {"aspect": aspect, "resolution": "native", "width": w, "height": h}


class Batch:
    def __init__(self, bid: str, meta: dict):
        self.bid = bid
        self.meta = meta
        self.tasks: list[dict] = []

    def add(self, tid: str, **kw) -> dict:
        t = {"id": f"{self.bid}.{tid}", "seed": seed_for(self.bid + getattr(self, "seed_salt", ""), tid), "status": "pending", "quote_ref": None}
        t.update(kw)
        n, u = t["candidates"], t["unit_cost_cr"]
        t["quota_cr"] = r2(n * u)
        t["max_credits"] = t["quota_cr"]
        t.setdefault("element_ids", [])
        t.setdefault("lora", None)
        t.setdefault("heroine", None)
        t.setdefault("unit_cost_basis", "quoted")
        t.setdefault("output", {"dir": f"{OUTPUT_ROOT}/{self.bid}/{tid}", "name": "cand_{n:02d}"})
        self.tasks.append(t)
        return t

    def total(self) -> float:
        return r2(sum(t["quota_cr"] for t in self.tasks))

    def dump(self) -> dict:
        d = dict(self.meta)
        d["batch_id"] = self.bid
        d["tasks"] = self.tasks
        d["totals"] = {"tasks": len(self.tasks), "task_quota_sum_cr": self.total(),
                       "candidates": sum(t["candidates"] for t in self.tasks if t.get("media") in ("image", "audio", "video"))}
        return d


# ----------------------------------------------------------------------------------------------------------------------
# heroine data
# ----------------------------------------------------------------------------------------------------------------------
def load_heroines() -> dict:
    return {h["key"]: h for h in json.loads(SRC.read_text(encoding="utf-8"))["heroines"]}


def identity_block(h: dict, body: str | None = None, skin: str | None = None) -> str:
    i = h["immutable_identity"]
    sig = "; ".join(i["signature_accessories"])
    return (
        f"<<<{h['element_id']}>>> is {h['name']}, an adult woman of {h['age']}, {h['role']}. "
        f"Hair: {i['hair']}. Eyes: {i['eyes']}. Skin: {skin or i['skin']}. Face: {i['face_shape_and_features']}. "
        f"Signature items that must be present: {sig}. Body: {body or i['body_proportion_note']}."
    )


def hero_task_fields(h: dict) -> dict:
    return {"heroine": h["key"], "element_ids": [h["element_id"]], "model": "gpt_image_2_6", "media": "image", "tool": "generate_image"}


PALETTE2 = {"mc": "mint-jade green", "rin": "deep forest green", "hana": "navy blue", "yue": "deep indigo", "nova": "hot pink",
            "tsubame": "crimson", "miel": "caramel brown", "kohaku": "vermilion red", "shirin": "teal", "zlata": "warm gold"}


def secondary_color_words(h: dict) -> str:
    return f"softly tinted toward {PALETTE2[h['key']]}"


def clean_outfit(txt: str) -> str:
    import re
    return re.sub(r"\s*\((canon|alt)[^)]*\)", "", txt).strip()


CULL_ANATOMY = [
    "anatomy double audit passed: crops of hands, fingers, legs and feet show no extra or fused limbs",
    "face reads as the canon heroine (>= 4 of 5 traits: eye shape, face width, nose/mouth, apparent age, brows) vs the element portrait",
    "hair colour, signature items and outfit match the canon card; no drift (hair_never rules)",
    "no text, no logos, no watermark, no garbled glyphs anywhere; mahjong tiles blank",
    "adult proportions about 7-7.5 heads; garment opaque and in place; eye-level camera; no red-line pose",
]

GUARDS_COMMON = [
    "Before each launch: estimate_*_cost -> quote_ref; abort the task when the quote is above max_credits.",
    "Actual spend goes to design/art_batches/SPEND_LOG.csv; more than 15% over the batch nominal = stop and ask the owner.",
    "Every output lands in assets/incoming, then double anatomy audit -> metadata scrub -> watermark pass -> manifest `approve`.",
    "Prompts are untested: run the pilot tasks first (2-3 frames), look at them, only then release the rest.",
]


def base_meta(bid, package, title, week, section, nominal, hard_stop=None, hard_stop_reason="", in_plan=True, status="ready_for_owner_approval",
              depends_on=(), owner_gate="", pilot=None, selection=None, candidates_policy="", tool_note="", assumptions=(),
              blocked_by=(), notes=()):
    return {
        "schema_version": 1,
        "package": package,
        "title": title,
        "week": week,
        "section": section,
        "status": status,
        "in_plan_ceiling": in_plan,
        "blocked_by": list(blocked_by),
        "depends_on": list(depends_on),
        "owner_gate": owner_gate,
        "budget": {
            "currency": "higgsfield_credits",
            "nominal_cr": nominal,
            "hard_stop_cr": hard_stop if hard_stop is not None else r2(nominal * 1.15),
            "hard_stop_rule": "nominal + 15%: above that the run stops and the owner is asked",
            **({"hard_stop_override_reason": hard_stop_reason} if hard_stop is not None else {}),
            "assumptions": list(assumptions),
        },
        "candidates_policy": candidates_policy,
        "selection": selection or {},
        "pilot": pilot or {},
        "tool_note": tool_note,
        "guards": GUARDS_COMMON,
        "notes": list(notes),
    }


def pilot_of(b: Batch, ids: list[str], cands: int | None = None, rule: str = "") -> dict:
    full = [f"{b.bid}.{i}" for i in ids]
    cost = 0.0
    for t in b.tasks:
        if t["id"] in full:
            n = cands if cands is not None else t["candidates"]
            cost += n * t["unit_cost_cr"]
    return {"task_ids": full, "candidates_per_task": cands, "max_cr": r2(cost),
            "go_rule": rule or "owner looks at the pilot frames; any red-line or drift failure -> fix the prompt before the full run"}


# ----------------------------------------------------------------------------------------------------------------------
# TIER FULL (P50b): the art direction of every heroine batch.  Spec: design/ART_TIER_FULL.md.  Wardrobe tables (10 heroines x 7
# outfits x 3 poses): tools/art/full_tier_wardrobe.py.  Fashion / pin-up vocabulary only.
# ----------------------------------------------------------------------------------------------------------------------
import full_tier_wardrobe as WD  # same folder, on sys.path when run as a script

TAILS = {}
FULL_TAIL_ID = "v5f"
FULL_TAIL = (
    "Glossy-warm painterly anime gacha key art with premium mobile-gacha production quality, original character design, adult "
    "fashion pin-up styling. {figure} a direct "
    "teasing gaze, lacquer-like specular highlights on hair, satin and sheer legwear, a warm colored rim light, rich saturated "
    "colors with a slightly softened supporting background, thin warm-colored lineart with soft cel-painted shading, fabric "
    "texture and at least three accessories. Garments and legwear cover the chest, hips and groin and stay exactly in place, adult "
    "mature face, adult setting, mahjong tiles blank or absent, one single character in frame, no text, no letters or numerals, "
    "no logos, no watermark."
)
FULL_BODY = {
    "mc": "soft shapely figure, defined waist, rounded hips, soft thighs, soft shoulders, a full natural bust in proportion",
    "rin": "slender figure, long neck, long legs, slim waist, gently rounded hips, a natural bust in proportion",
    "hana": "athletic toned figure, bare midriff with a flat stomach, long toned legs, a natural bust in proportion, no visible muscle definition",
    "yue": "statuesque figure, long limbs, regal posture, defined waist, rounded hips, long thighs, a full natural bust in proportion",
    "nova": "lean toned figure, slim waist, gently rounded hips, long legs, a natural bust in proportion",
    "tsubame": "lithe slender figure, long legs, slim waist, rounded hips, a natural bust in proportion",
    "miel": "soft pear-shaped figure with fuller hips and soft thighs, slim waist, a full natural bust in proportion",
    "kohaku": "soft athletic-soft figure, slim waist, long legs, rounded hips, a full natural bust in proportion",
    "shirin": "soft shapely figure, defined waist, fuller hips, a full natural bust in proportion, bare midriff",
    "zlata": "statuesque figure, slim waist, broad regal shoulders, rounded hips, long legs, a full natural bust in proportion",
}
FULL_SKIN = {"nova": "fair pale cool-neutral porcelain-peach skin with a soft pink blush (not tanned, not dark)"}
FULL_H0_SCENES = {
    "match": dict(
        framing="thigh-up figure filling the lower 55% of a vertical mobile game frame, the upper 45% an empty clear dark field left for a tile board",
        setting=("night mahjong parlor: black lacquer pillars, warm paper lanterns, a lacquer mahjong table across the bottom of the frame, "
                 "large empty center above her left clear for a tile board")),
    "tea": dict(
        framing="full-body three-quarter view, camera at eye level, figure centered with space above for interface",
        setting="night tea house: lacquered pillars, paper lanterns, a low tea table, a cushioned daybed, round moon window"),
    "summon": dict(
        framing="full-body view, centered under the arch, camera at eye level",
        setting="golden lantern altar arch: glowing lanterns, light rays, drifting petals, deep night ground"),
    "shop": dict(
        framing="full-length view with the counter at her side, camera at eye level",
        setting="lantern-lit lacquer shop counter with shelves of blank jars, folded cloth and small boxes, no price tags, no signs"),
    "win": dict(
        framing="full-body view, centered, generous empty space above",
        setting="night sky with falling gold petals and a few blank ivory mahjong tiles drifting, warm glow behind her"),
}
# (pose, expression, optional setting override)
FULL_POSES = {
    "mc": {
        "match": ("perched on the edge of the mahjong table with her legs crossed, one hand on her hip and the other lifting her long hair, glancing at the viewer", "confident teasing smile"),
        "tea": ("leaning back against the edge of the mahjong table on one forearm, holding up a single blank mahjong tile in the other hand, weight on one leg, a wink", "playful wink with a laughing open smile"),
        "summon": ("standing with her weight on one leg, one hand on her hip and the other raised into her hair, the stocking top visible through the high side slit", "playful teasing smile"),
        "shop": ("leaning over the lacquer counter on both elbows, chin on one hand, one leg lifted behind her", "sly smile, eyes on the viewer"),
        "win": ("leaning forward over the mahjong table with one hand pressing a single blank tile on the felt and the other arm thrown up in the air", "joyful open-mouth laugh with a wink"),
    },
    "yue": {
        "match": ("seated sideways on the armrest of a lacquer chair at the table edge, legs crossed, the moon-phase fan held against her lips, glancing past the viewer", "amused teasing smile"),
        "tea": ("reclining on a moon-cushion divan, one leg crossed over the other, one arm stretched toward the viewer holding a small blank jade tile", "serene teasing smile"),
        "summon": ("standing in an S-curve with one hip tilted, one hand held out palm up toward the viewer, the fan resting on her hip", "slow inviting half-smile"),
        "shop": ("leaning on the counter with one elbow, one hand in her long hair, one knee bent, the fan in the other hand", "lazy teasing smile, half-lidded eyes"),
        "win": ("seated on a throne armrest with her legs crossed, the fan open beside her cheek, laughing, head turned toward the viewer", "radiant delighted laugh"),
    },
    "nova": {
        "match": ("perched on the edge of the mahjong table with her boots crossed, one finger tapping her cat-ear headphones, a hip tilted", "confident smirk"),
        "tea": ("reclining back on cushions propped on both hands, legs crossed at the ankle, a tea bowl on the table beside her", "smug half-smile"),
        "summon": ("standing with a hip tilt, one hand on her hip and the other pointing a finger at the viewer, a small cyan hologram card floating beside her", "playful wink with a smirk"),
        "shop": ("leaning over the counter on one forearm, holding a glowing cyan card between two fingers, looking sideways at the viewer", "teasing smirk"),
        "win": ("idol pose on a concert stage, singing into a microphone, one hand pointing at the viewer, one leg stepped forward, winking, truss lights and glow sticks behind her", "wink with a bright confident grin"),
    },
}
FULL_H1_FRAMES = {
    "base": ("standing with one hip tilted, one hand on her hip, the other hand touching her hair, eyes on the viewer", "confident teasing smile"),
    "win": ("leaning toward the viewer in a joyful victory pose, one hand holding up a single blank ivory mahjong tile, a wink", "bright laugh with a wink"),
    "tease": ("glancing back at the viewer over her shoulder, one fingertip at her lips, shoulders turned, hip tilted", "playful flirty smile"),
}



TAILS[FULL_TAIL_ID] = FULL_TAIL  # contains the {figure} placeholder, filled per heroine by figure_line()
HERO_ORDER = ["mc", "rin", "hana", "yue", "nova", "tsubame", "miel", "kohaku", "shirin", "zlata"]
H0_HEROINES = ["mc", "yue", "nova"]
# MC wears her night qipao on the board / altar and the floral tea cheongsam elsewhere (owner mock-ups 12-15)
H0_MC_SLOT = {"match": "base", "summon": "base", "tea": "evening", "shop": "evening", "win": "evening"}


def body_line(hk: str) -> str:
    b = WD.HEIGHTS[hk]
    return f"{b['tag']}, about {b['cm']} cm tall ({b['heads']} heads tall), {FULL_BODY[hk]}"


def figure_line(hk: str) -> str:
    """Per-heroine figure sentence of the tail.  Hard floor: a mature adult face and a grown woman's figure, never below WD.HEADS_MIN heads."""
    b = WD.HEIGHTS[hk]
    return (f"Adult woman with grown-woman proportions, {b['heads']} heads tall ({b['cm']} cm, {b['tag']}), {b['legs']}, a mature adult face "
            f"and figure, a defined waist,")


def full_prompt(h: dict, outfit: str, pose: str, expr: str, framing: str, setting: str, extra: str = "") -> str:
    hk = h["key"]
    tail = FULL_TAIL.replace("{figure}", figure_line(hk))
    return (f"{identity_block(h, body_line(hk), FULL_SKIN.get(hk))} Outfit: {outfit}. Pose: {pose}. Expression: {expr}. Framing: {framing}. "
            f"Setting: {setting}. {extra} {tail}").replace("  ", " ").strip()


HERO_FRAMING = "dynamic splash-art composition, three-quarter figure from head to knees, strong diagonal, camera at eye level to slightly low"


def full_selection(extra_criteria=()):
    return {"keep_per_task": 1, "gate": "Full-tier look gate (design/ART_TIER_FULL.md section 7) + anatomy audit",
            "criteria": ["boldness at the owner's reference level (stockings with bands, deep neckline, playful pose), not tamer",
                         "hard lines: clearly adult face and 7-7.5 heads, nothing nude (no nipples, no genitals), no explicit act, no school or minor coding, no text"]
                        + CULL_ANATOMY[:4] + list(extra_criteria)}


# ----------------------------------------------------------------------------------------------------------------------
# H0 golden composites: MC / Yue / Nova x 5 screens, Full tier
# ----------------------------------------------------------------------------------------------------------------------
def build_H0(H, tail=None):
    b = Batch("H0", base_meta(
        "H0", "P50", "Golden composites, tier Full: MC / Yue / Nova x 5 screens", 2, "Heroines", 180,
        owner_gate="Owner looks at the finals and approves the tier (design/golden_full/contact_sheet.jpg is the first pass); nothing is registered by the generator",
        candidates_policy="search: 8 candidates per frame at 1k medium (1 cr); final: 2 candidates of the best prompt at 2k high (2 cr)",
        selection={"keep_per_task": 2, "gate": "Full-tier look gate + GDD 11.4 a-e",
                   "criteria": ["boldness at the owner's reference level (stockings with bands, deep neckline, playful pose), not tamer",
                                "hard lines: clearly adult face and 7-7.5 heads, nothing nude, no explicit act, no school or minor coding, no text",
                                "faces distinguishable on >= 3 of 5 traits across mc/yue/nova",
                                "heroine accent colour <= 20% of the frame area; Nova's neon lives only in outfit and FX"] + CULL_ANATOMY[:4]},
        tool_note="gpt_image_2_6 + Elements (<<<element_id>>> in the prompt; do not also pass the element in medias). Tail `v5f`. P50b ran this batch with 3 candidates per frame (not 8): see design/golden_full/REPORT.md.",
        assumptions=["1k medium = 1 cr, 2k high = 2 cr per image (quoted by estimate_image_cost)"]))
    b.meta["tier"] = "full"
    for hk in H0_HEROINES:
        h = H[hk]
        for sk, sc in FULL_H0_SCENES.items():
            pose, expr = FULL_POSES[hk][sk]
            slot = H0_MC_SLOT[sk] if hk == "mc" else "base"
            setting = sc["setting"]
            if hk == "nova" and sk == "win":
                setting = "concert stage with truss lights, glow sticks in the dark crowd far behind her, drifting petals"
            extra = "Her signature accent color covers less than a fifth of the frame. " + ("Her neon glow exists only on the outfit and a small effect. " if hk == "nova" else "")
            tid = f"{hk}_{sk}"
            common = dict(hero_task_fields(h), kind="golden_composite_full", tier="full", prompt=full_prompt(h, WD.outfit(hk, slot)["outfit"], pose, expr, sc["framing"], setting, extra), quality="medium")
            b.add(f"{tid}.search", stage="search", size=size_gpt("9:16", "1k"), candidates=8, unit_cost_cr=1.0, **common)
            b.add(f"{tid}.final", stage="final", size=size_gpt("9:16", "2k"), candidates=CAND_FINAL, unit_cost_cr=2.0,
                  **dict(common, quality="high", depends_on_task=f"H0.{tid}.search", seed_policy="replace seed with the winning search candidate seed"))
    b.meta["pilot"] = pilot_of(b, ["mc_match.search", "yue_tea.search", "nova_win.search"], 2,
                               "3 frames x 2 candidates: boldness at the reference level, faces clearly different, no text, hard lines intact")
    return b


# ----------------------------------------------------------------------------------------------------------------------
# H1 canon set: 10 heroines x 3 frames (three-quarter base, win, tease), Full tier, base outfit
# ----------------------------------------------------------------------------------------------------------------------
def build_H1(H, tail=None):
    b = Batch("H1", base_meta(
        "H1", "P51", "Canon set, tier Full: 10 heroines x 3 frames (three-quarter base, win, tease)", 3, "Heroines", 330,
        depends_on=["H0"], owner_gate="owner approves the Full tier from the H0 frames; finals pass the anatomy audit and the 45-pair face matrix",
        candidates_policy="search: 6 candidates per frame at 1k medium (1 cr); final: 2 candidates at 2k high (2 cr); post: 30 units of upscale / remove_background at ~1 cr",
        selection=full_selection(["face matrix: no two heroines share a face (pairwise >= 3 of 5 traits differ)",
                                  "the base frame is usable as the three-quarter card of the heroine strip (cut at mid-thigh, hands visible)"]),
        tool_note="gpt_image_2_6 + Elements, tail `v5f`, outfit = the base slot of the wardrobe table.",
        assumptions=["post pool: 30 x 1 cr is the plan figure (~10%); upscale_image / remove_background are not quoted"]))
    b.meta["tier"] = "full"
    for hk in HERO_ORDER:
        h = H[hk]
        setting = f"softly blurred teahouse interior with paper lanterns, background {secondary_color_words(h)}"
        for fk, (pose, expr) in FULL_H1_FRAMES.items():
            p = full_prompt(h, WD.outfit(hk, "base")["outfit"], pose, expr, "three-quarter figure cut at mid-thigh so the thigh band or hem is visible, centered", setting)
            tid = f"{hk}_{fk}"
            common = dict(hero_task_fields(h), kind="canon_frame_full", tier="full", prompt=p, quality="medium")
            b.add(f"{tid}.search", stage="search", size=size_gpt("2:3", "1k"), candidates=6, unit_cost_cr=1.0, **common)
            b.add(f"{tid}.final", stage="final", size=size_gpt("2:3", "2k"), candidates=CAND_FINAL, unit_cost_cr=2.0,
                  **dict(common, quality="high", depends_on_task=f"H1.{tid}.search", seed_policy="replace seed with the winning search candidate seed"))
    b.add("post_pool", stage="post", kind="post_pool", media="post", tool="upscale_image|remove_background", model="higgsfield_post",
          prompt="Post-processing pool: upscale or remove_background for approved finals only. No prompt; the owner names the files.",
          candidates=30, unit_cost_cr=1.0, unit_cost_basis="assumed", size={"aspect": "n/a", "resolution": "n/a", "width": 0, "height": 0})
    b.meta["pilot"] = pilot_of(b, ["mc_base.search", "kohaku_tease.search", "miel_base.search"], 2,
                               "3 frames x 2 candidates; compare against the owner's reference images")
    return b


# ----------------------------------------------------------------------------------------------------------------------
# H2 wardrobe: 10 heroines x 7 outfits (base, evening, swim, service, robe, battle, seasonal), 3 poses per outfit
# ----------------------------------------------------------------------------------------------------------------------
def build_H2(H, tail=None):
    b = Batch("H2", base_meta(
        "H2", "P55", "Wardrobe, tier Full: 10 heroines x 7 outfits (3 pose candidates + 1 final each)", 3, "Heroines", 350,
        depends_on=["H1"], owner_gate="face of every frame matches the H1 canon; owner approves each outfit from the 3-pose search sheet before its final is paid",
        candidates_policy="search: 3 candidates per outfit at 1k medium (1 cr), candidate n uses prompt_variants[n] (three different poses); final: 1 candidate of the chosen pose at 2k high (2 cr)",
        selection=full_selection(["outfit matches the wardrobe table text (colour, cut, legwear band); the heroine identity items stay (hair, horns, ears, glasses, headphones, signature accessories)",
                                  "the three pose candidates are three different poses (not the same pose three times)"]),
        tool_note="gpt_image_2_6 + Elements, tail `v5f`. Outfit slots: base, evening, swim, service (bunny / maid / bartender), robe (sleepwear robe-dress), battle (battle / idol), seasonal.",
        assumptions=["search 3 x 1 cr + final 1 x 2 cr = 5 cr per outfit, 70 outfits = 350 cr (the Standard-tier H2 was 200 cr)"]))
    b.meta["tier"] = "full"
    for hk in HERO_ORDER:
        h = H[hk]
        for slot in WD.SLOTS:
            o = WD.outfit(hk, slot)
            fr = "full-body view from head to heels, centered"
            variants = [full_prompt(h, o["outfit"], pose, expr, fr, o["setting"], "") for pose, expr in o["poses"]]
            tid = f"{hk}_{slot}"
            common = dict(hero_task_fields(h), kind="wardrobe_outfit", tier="full", outfit_name=o["name"], prompt=variants[0], quality="medium")
            b.add(f"{tid}.search", stage="search", size=size_gpt("2:3", "1k"), candidates=3, unit_cost_cr=1.0, prompt_variants=variants, **common)
            heroes = [full_prompt(h, o["outfit"], pose, expr, HERO_FRAMING, o["setting"], "SSR splash art, the richest costume of the heroine.") for pose, expr in o["hero"]]
            b.add(f"{tid}.final", stage="final", size=size_gpt("2:3", "2k"), candidates=1, unit_cost_cr=2.0, hero_prompt_variants=heroes,
                  **dict(common, quality="high", depends_on_task=f"H2.{tid}.search", seed_policy="replace seed with the winning search candidate seed; use the winning pose (hero_prompt_variants = 2 splash poses for SSR use, H4)"))
    b.meta["pilot"] = pilot_of(b, ["mc_swim.search", "nova_service.search", "kohaku_robe.search"], None,
                               "3 outfits x 3 poses: the swim, bunny and robe outfits are the ones most likely to trip the generator moderation; look at them before releasing the rest")
    return b


# ----------------------------------------------------------------------------------------------------------------------
# H3 combo T1/T2/T3 for 5 heroines (assumption: founders mc, rin, hana, yue, nova), Full tier, base outfit
# ----------------------------------------------------------------------------------------------------------------------
H3_HEROINES = ["mc", "rin", "hana", "yue", "nova"]
H3_TIERS = {
    "t1": ("T1 edge (x5): short quick reaction", "leaning in from the side with a wink, one hand on her hip and a tiny wave of the other",
           "playful wink, small smile", "bust-up, cropped at the ribs, slightly off-center"),
    "t2": ("T2 exit (x10): confident step", "stepping forward in three-quarter view, a hip tilted, one hand on her hip, the other pointing at the viewer",
           "confident grin, eyes on the viewer", "three-quarter figure cut at mid-thigh, centered"),
    "t3": ("T3 showcase (x20): big finish", "arms open wide in a proud presenting gesture with an arched back, hair and ribbons flowing in a breeze",
           "radiant triumphant smile, eyes on the viewer", "three-quarter figure cut at mid-thigh with clear headroom, centered"),
}


def build_H3(H, tail=None):
    b = Batch("H3", base_meta(
        "H3", "P56", "Combo T1/T2/T3 frames for 5 heroines (cut-outs), tier Full", 3, "Heroines", 150,
        depends_on=["H1"], owner_gate="halo-score and face comparison with H1 after remove_background",
        candidates_policy="search: 6 candidates at 1k (1 cr); final: 2 candidates at 2k high (2 cr)",
        selection=full_selection(["flat light-grey backdrop with no scenery (clean cut-out), no cast shadow on the backdrop",
                                  "T1 reads at 0.45 alpha over the board: single strong silhouette, face in the upper third"]),
        tool_note="Heroine = 5 founders by assumption (mc, rin, hana, yue, nova). Swap `H3_HEROINES` in the builder to change the five; cost is unchanged.",
        assumptions=["remove_background is not quoted and is not in the 150 cr plan figure: it is covered by the 20% reserve"],
        notes=["GDD 9.3: tiers show as T1 'edge' x5, T2 'exit' x10, T3 'showcase' x20"]))
    b.meta["tier"] = "full"
    for hk in H3_HEROINES:
        h = H[hk]
        for tk, (label, pose, ex, fr) in H3_TIERS.items():
            p = full_prompt(h, WD.outfit(hk, "base")["outfit"], pose, ex, fr, "isolated on a plain flat light-grey studio backdrop with no scenery and no floor, easy to cut out")
            tid = f"{hk}_{tk}"
            common = dict(hero_task_fields(h), kind="combo_frame_full", tier="full", prompt=p, quality="medium", tier_label=label)
            b.add(f"{tid}.search", stage="search", size=size_gpt("2:3", "1k"), candidates=6, unit_cost_cr=1.0, **common)
            b.add(f"{tid}.final", stage="final", size=size_gpt("2:3", "2k"), candidates=CAND_FINAL, unit_cost_cr=2.0,
                  **dict(common, quality="high", depends_on_task=f"H3.{tid}.search", seed_policy="replace seed with the winning search candidate seed"))
    b.meta["pilot"] = pilot_of(b, ["mc_t1.search", "nova_t3.search"], 2)
    return b


# ----------------------------------------------------------------------------------------------------------------------
# H4 SSR key art 'First guest' (outside the 4-week window): richest wardrobe outfits, Full tier
# ----------------------------------------------------------------------------------------------------------------------
H4_PICK = {"rin": "service", "hana": "swim", "yue": "battle"}


def build_H4(H, tail=None):
    b = Batch("H4", base_meta(
        "H4", "ART plan (H4)", "SSR key art 'First guest' (rin_ssr, hana_ssr, yue_ssr), tier Full", 5, "Heroines", 80, in_plan=False, status="blocked_owner_decision",
        blocked_by=["Q-15 (SSR line-up of 'First guest')", "H0 gate (P50)"], depends_on=["H0", "H1"],
        owner_gate="Q-15 decides which three SSR outfits; the prompts below use wardrobe outfits (rin bunny tea-server, hana sunflower bikini, yue dragon-scale armour) as placeholders",
        candidates_policy="per SSR heroine: 2 hero splash poses; search 7 candidates per pose at 1k medium (14 per heroine); final 3 candidates per pose at 2k high (6 per heroine); post 2 cr",
        selection=full_selection(["raw model output is forbidden on showcase screens: AD pass is mandatory before approve"]),
        assumptions=["plan figure is 60-100 cr outside the 4-week window; 80 is the middle", "the three outfits are placeholders until Q-15"],
        tool_note="Not part of the plan nominal; needs a separate approval after P50 and Q-15."))
    b.meta["tier"] = "full"
    for hk, slot in H4_PICK.items():
        h = H[hk]
        o = WD.outfit(hk, slot)
        for n, (pose, ex) in enumerate(o["hero"], 1):
            p = full_prompt(h, o["outfit"], pose, ex, HERO_FRAMING, "grand showcase backdrop: " + o["setting"],
                            "SSR key art, richest costume of the heroine, layered fabric, gold accents reserved for the outfit.")
            common = dict(hero_task_fields(h), kind="ssr_keyart_full", tier="full", prompt=p, quality="medium", outfit_source=f"{hk}.{slot}", hero_pose=n)
            b.add(f"{hk}_ssr_h{n}.search", stage="search", size=size_gpt("2:3", "1k"), candidates=7, unit_cost_cr=1.0, **common)
            b.add(f"{hk}_ssr_h{n}.final", stage="final", size=size_gpt("2:3", "2k"), candidates=3, unit_cost_cr=2.0,
                  **dict(common, quality="high", depends_on_task=f"H4.{hk}_ssr_h{n}.search", seed_policy="replace seed with the winning search candidate seed"))
    b.add("post_pool", stage="post", kind="post_pool", media="post", tool="upscale_image", model="higgsfield_post",
          prompt="Post-processing pool for approved finals only. No prompt.", candidates=2, unit_cost_cr=1.0, unit_cost_basis="assumed",
          size={"aspect": "n/a", "resolution": "n/a", "width": 0, "height": 0})
    b.meta["pilot"] = pilot_of(b, ["yue_ssr_h1.search"], 3)
    return b


# ----------------------------------------------------------------------------------------------------------------------
# E0 LoRA v2 training, E1 production run, E2 upscale
# ----------------------------------------------------------------------------------------------------------------------
def build_E0(H, tail):
    b = Batch("E0", base_meta(
        "E0", "P52", "Train tw_master_v2 (H200, 4500 steps)", 1, "Environments (LoRA v2)", 215, hard_stop=270,
        hard_stop_reason="measured fork of the GPU session cost is 160-270 cr (v1 cost 248 cr); 270 is the upper end, not nominal + 15%",
        owner_gate="M3: owner clicks gpu_rent (H200) and ONE gpu_rental_exec (lora-v2/MORNING.md); before that gpu_my to avoid touching someone else's box",
        candidates_policy="no candidates: one training run; checkpoints s3000/s4000/final are evaluated, 5 tags x 80 images",
        selection={"keep_per_task": 1, "gate": "SPEC_V2 section 8 gates G1-G5",
                   "criteria": ["G1 identity (10 tokens hold hair/eyes/signature)", "G2 proportions (no exaggerated bust/hips)",
                                "G3 palette via image_stats.py (pink/lavender share and saturation near base model)",
                                "G4 no garbled text in UI outputs (OCR gate)", "G5 red lines (HEROINES, LEGWEAR)",
                                "pick s3000 or s4000; later steps over-bake (v1 lesson)"]},
        tool_note="GPU job, not an image prompt. The prepared kit (dataset on CloudFront, launch_v2.sh, EXEC_COMMAND_V2.txt, MORNING.md) lives in the research workspace lora-v2/, not in this repo. Upload slots in the exec command expire 24 h after 2026-11-27 23:13 UTC.",
        assumptions=["fork 160-270 cr; v1 cost 248 cr for the whole session; 215 is the middle", "134 cr/h H200; expected 70-100 min training + eval"]))
    b.add("train", stage="train", kind="gpu_training", media="gpu", tool="gpu_rent+gpu_rental_exec", model="tw_master_v2 (Z-Image Turbo + ostris adapter v2)",
          prompt=("Launch tw_master_v2 training with lora-v2/EXEC_COMMAND_V2.txt via ONE gpu_rental_exec: rank 128, 4500 steps, trigger 'twmaster2 style', "
                  "dataset 348 images used. Poll gpu_rental_logs every 10 minutes for DONE_V2 / FAILED_V2, hard deadline 150 minutes, then gpu_rental_stop. "
                  "Eval pack: 5 tags x 80 images."),
          candidates=1, unit_cost_cr=215.0, unit_cost_basis="assumed",
          size={"aspect": "n/a", "resolution": "n/a", "width": 0, "height": 0},
          gpu={"type": "H200", "count": 1, "max_credits_per_hour": 134, "auto_pause_minutes": 30, "expected_hours": 1.6, "range_cr": [160, 270]})
    b.meta["pilot"] = {"task_ids": [], "candidates_per_task": None, "max_cr": 0.0,
                       "go_rule": "no pilot; the 5% rule does not apply to a training job; the 270 cr hard stop is the upper end of the measured fork"}
    return b


ENV_THEMES = {
    "teahouse": ("Chinese-style tea house veranda with a lacquered pavilion, sliding screens and hanging lanterns",
                 "tea house courtyard in daylight with lacquered pillars and paper screens"),
    "bamboo": ("bamboo garden path with stone lanterns and a small pond", "sunlit bamboo garden with a stone path and a pond"),
    "city": ("night city lane with blank neon signs, wet pavement and warm shop windows", "sunlit city lane with blank awnings and warm shop fronts"),
}
SEASONS = {
    "spring": "cherry blossoms drifting", "summer": "lush green leaves and fireflies", "autumn": "red maple leaves falling", "winter": "light snow falling",
}
SALON_ZONES = [
    ("mc", "mahjong salon parlor with carved cherry wood, a green felt table and pink paper lanterns"),
    ("rin", "tea study library with celadon tea sets, bookshelves and a green-shaded lamp"),
    ("hana", "sunlit training courtyard with sunflowers, a running track edge and a bench"),
    ("yue", "moon palace balcony with crescent windows, pale silk curtains and a silver moon"),
    ("nova", "neon loft workshop with blank holo-screens and cables, cyan and pink light"),
    ("tsubame", "tiled rooftop at dusk with chimneys, hanging scarves and a distant lantern bridge"),
    ("miel", "cozy pastry parlor with display shelves, blank cake stands and warm honey light"),
    ("kohaku", "shrine stairway with a row of red torii gates and fox-shaped lanterns"),
    ("shirin", "desert bazaar tent with hanging lamps, rugs and brass trays"),
    ("zlata", "wooden fairy-tale terem hall with embroidered cloths, a warm stove and carved beams"),
]
KOIKOI = [
    ("01_pine", "pine branches in snow at dawn"), ("02_plum", "blooming plum tree by a stone wall"), ("03_cherry", "cherry trees in full bloom with a curtain of petals"),
    ("04_wisteria", "hanging wisteria over a wooden arbor"), ("05_iris", "iris pond with a small wooden bridge"), ("06_peony", "peony garden with stone paths"),
    ("07_bush_clover", "bush clover field under a pale evening sky"), ("08_pampas_moon", "pampas grass hill under a large full moon"),
    ("09_chrysanthemum", "chrysanthemum garden with a low fence and lanterns"), ("10_maple", "maple valley with a stream and red leaves"),
    ("11_willow_rain", "willow tree by a river in gentle rain"), ("12_paulownia", "paulownia tree with golden leaves and a distant shrine roof"),
]
TILE_SETS = [
    ("bamboo", "tile set 'Bamboo': pale green jade-bamboo tile frame and back with fine bamboo leaf pattern, blank face"),
    ("lacquer", "tile set 'Lacquer': black lacquer tile frame and back with gold hairline, blank ivory face"),
    ("jade", "tile set 'Jade': translucent green jade tile frame and back with carved border, blank face"),
    ("night", "tile set 'Night': deep indigo tile frame and back with silver star dust border, blank face"),
]
FX_LIST = [
    ("sakura_burst", "burst of pink cherry petals radiating from the center"), ("gold_sparkle_ring", "expanding ring of gold sparkles"),
    ("lantern_glow", "soft glowing paper lantern bokeh cluster"), ("combo_t1_edge", "thin curved light streak sweeping from the edge"),
    ("combo_t2_wave", "wide shimmering energy wave sweeping across"), ("combo_t3_burst", "large radial firework burst with petals"),
    ("ult_charge_ring", "circular charging ring of light with small runes-free glow marks"), ("match_pop", "small crisp pop of stars at a point"),
    ("rain_streaks", "falling rain streaks with soft glow"),
]


def build_E1(H, tail):
    b = Batch("E1", base_meta(
        "E1", "P53", "Production run LoRA v2: 24 table backgrounds, 10 salon zones, 12 koikoi months, tiles and FX", 2, "Environments (LoRA v2)", 267.9,
        depends_on=["E0"], owner_gate="E0 gates G1-G5 passed and the owner picked the checkpoint; box rented by the owner (M3)",
        candidates_policy="8 candidates per background (46 x 8 = 368), 16 per tile set (64), 12 per FX (108): 540 images at 0.085 cr; 3 sessions with a model load each",
        selection={"keep_per_task": 1, "gate": "palette (image_stats.py) + AD pass; 46 finalists go to E2",
                   "criteria": ["palette: dark saturated, pink/lavender share not above the base model's 0.1 on backgrounds",
                                "no text, glyphs, signs with letters; no characters; center free for the board (backgrounds)",
                                "tile frames: same material language across the four sets, passes the contrast rule of GDD 7.2",
                                "FX on pure black (additive-blend ready), no hard border, no text"]},
        tool_note="LoRA tw_master_v2 on the rented H200 box via gen.py (9 steps, guidance 0, trigger 'twmaster2 style'). This is not a Higgsfield gpt call.",
        assumptions=["box 1.5 h x 134 cr/h = 201 cr", "0.085 cr per image (measured on v1)", "model load 7 cr x 3 sessions"]))
    lora = {"name": "tw_master_v2", "trigger": LORA_TRIGGER, "weight": 1.0, "checkpoint": "s3000 or s4000 (owner picks after E0 gates)", "steps": 9, "guidance": 0.0}

    b.add("box_rental", stage="infra", kind="gpu_box", media="gpu", tool="gpu_rent", model="H200", prompt="Rent one H200 for the production run; stop it right after the last session.",
          candidates=1, unit_cost_cr=201.0, unit_cost_basis="assumed", size={"aspect": "n/a", "resolution": "n/a", "width": 0, "height": 0},
          gpu={"type": "H200", "count": 1, "max_credits_per_hour": 134, "expected_hours": 1.5})

    def gen(tid, prompt, aspect, n, session):
        b.add(tid, stage=f"session_{session}", kind="lora_image", media="image", tool="gen.py", model="tw_master_v2", prompt=prompt, lora=dict(lora),
              size=size_lora(aspect), candidates=n, unit_cost_cr=0.085, unit_cost_basis="assumed", session=session, quality="native")

    def load(s):
        b.add(f"model_load_{s}", stage=f"session_{s}", kind="model_load", media="gpu", tool="gen.py", model="tw_master_v2",
              prompt=f"Load tw_master_v2 into VRAM for session {s} (fixed cost).", candidates=1, unit_cost_cr=7.0, unit_cost_basis="assumed",
              size={"aspect": "n/a", "resolution": "n/a", "width": 0, "height": 0}, session=s)

    # session A: 24 table backgrounds
    load("A")
    for th, (night_d, day_d) in ENV_THEMES.items():
        for se, sd in SEASONS.items():
            for tod in ("day", "night"):
                if tod == "night":
                    pr = f"{LORA_TRIGGER}, environments, {night_d}, {sd}, night, empty calm center for a game board, {LORA_ENV_TAIL}"
                else:
                    pr = f"{LORA_TRIGGER}, environments, {day_d}, {sd}, daytime, empty calm center for a game board, {LORA_ENV_TAIL_DAY}"
                gen(f"table_{th}_{se}_{tod}", pr, "9:16", 8, "A")
    # session B: salon zones + koikoi months
    load("B")
    for hk, desc in SALON_ZONES:
        gen(f"salon_{hk}", f"{LORA_TRIGGER}, environments, {desc}, warm lantern light, the zone of one heroine, no characters, {LORA_ENV_TAIL}", "9:16", 8, "B")
    for mk, desc in KOIKOI:
        gen(f"koikoi_{mk}", f"{LORA_TRIGGER}, environments, {desc}, seasonal mood of the month, empty center, {LORA_ENV_TAIL}", "9:16", 8, "B")
    # session C: tiles + FX
    load("C")
    for tk, desc in TILE_SETS:
        gen(f"tiles_{tk}", f"{LORA_TRIGGER}, tiles_fx, {desc}, front view, centered, {LORA_TILES_TAIL}", "1:1", 16, "C")
    for fk, desc in FX_LIST:
        gen(f"fx_{fk}", f"{LORA_TRIGGER}, tiles_fx, {desc}, {LORA_FX_TAIL}", "1:1", 12, "C")
    b.meta["pilot"] = pilot_of(b, ["table_teahouse_spring_night", "salon_mc", "tiles_lacquer", "fx_sakura_burst"], 2,
                               "2 candidates each inside session A/B/C budget; box time is not a pilot cost: owner stays at the box for this run")
    return b


def build_E2(H, tail):
    b = Batch("E2", base_meta(
        "E2", "P53", "Finalists upscale: 46 backgrounds", 2, "Environments (LoRA v2)", 92, depends_on=["E1"],
        owner_gate="AD picked one finalist per background in E1 (46 files)",
        candidates_policy="one upscale per finalist",
        selection={"keep_per_task": 1, "gate": "AD pass", "criteria": ["no new artifacts or smeared lineart after upscale", "no text appears", "palette unchanged vs the E1 pick"]},
        tool_note="Higgsfield upscale_image (price per frame is NOT quoted; 2 cr is an assumption). Run estimate first and re-plan if it differs.",
        assumptions=["upscale_image ~2 cr per frame (assumption, not a quote)"]))
    names = [f"table_{th}_{se}_{tod}" for th in ENV_THEMES for se in SEASONS for tod in ("day", "night")]
    names += [f"salon_{hk}" for hk, _ in SALON_ZONES] + [f"koikoi_{mk}" for mk, _ in KOIKOI]
    for n in names:
        b.add(n, stage="post", kind="upscale", media="post", tool="upscale_image", model="higgsfield_upscale",
              prompt=f"Upscale the AD-approved finalist of E1.{n} (2x). No prompt change; keep the painted look.", candidates=1, unit_cost_cr=2.0,
              unit_cost_basis="assumed", size={"aspect": "n/a", "resolution": "2x", "width": 0, "height": 0}, depends_on_task=f"E1.{n}")
    b.meta["pilot"] = pilot_of(b, [names[0], names[24]], 1, "estimate_image_cost-style quote on 2 frames first")
    return b


# ----------------------------------------------------------------------------------------------------------------------
# U1 UI kit
# ----------------------------------------------------------------------------------------------------------------------
ICONS = [
    # nav (5)
    ("tab_tea", "a lacquer teapot with a small steam curl"), ("tab_heroines", "a folding fan with a tassel"), ("tab_games", "two blank ivory mahjong tiles leaning together"),
    ("tab_wishes", "a glowing paper lantern with a small star above"), ("tab_shop", "a lacquer pouch bag tied with a knot cord"),
    # currencies (6)
    ("cur_gems", "a faceted jade crystal"), ("cur_moon", "a crescent moon stone with a soft glow"), ("cur_coins", "a round coin with a square hole"),
    ("cur_petals", "a single cherry blossom petal"), ("cur_ticket", "a wish ticket slip tied with a thin cord"), ("cur_candle", "a golden candle with a small flame"),
    # actions (8)
    ("act_undo", "a curved return arrow"), ("act_shuffle", "two crossing curved arrows"), ("act_hint", "a lantern casting a light cone"),
    ("act_slot", "an empty tray slot with a plus-shaped glow"), ("act_pause", "two vertical lacquer bars"), ("act_play", "a rounded triangle pointing right"),
    ("act_retry", "a circular arrow"), ("act_next", "a double chevron pointing right"),
    # status (10)
    ("st_star", "a five-point star"), ("st_heart_bond", "a heart with a small ribbon"), ("st_lock", "a closed padlock"), ("st_check", "a check mark in a circle"),
    ("st_cross", "a cross mark in a circle"), ("st_bell", "a small brass bell"), ("st_calendar", "a blank calendar page with a tab"),
    ("st_timer", "a sand timer glass on a small stand"), ("st_trophy", "a small trophy cup"), ("st_flag", "a small pennant flag"),
    # system (12)
    ("sys_settings", "a gear with a lotus center"), ("sys_back", "a left-pointing arrow"), ("sys_close", "a cross mark"), ("sys_home", "a small house with a tiled roof"),
    ("sys_phone", "a smartphone with a blank screen"), ("sys_mail", "a sealed envelope"), ("sys_gift", "a wrapped gift box with a ribbon"), ("sys_chest", "a lacquer treasure chest"),
    ("sys_quests", "a rolled scroll tied with a cord"), ("sys_gallery", "an empty picture frame"), ("sys_wardrobe", "a hanger with a folded kimono"), ("sys_salon", "a small pavilion"),
    # audio and accessibility (6)
    ("au_music", "a musical note"), ("au_sfx", "a small drum"), ("au_voice", "a speech bubble with sound waves"), ("au_mute", "a speaker with a slash"),
    ("au_subtitles", "a blank rounded caption bar"), ("au_quiet", "a leaf with a crescent"),
    # modes (11) + misc (2)
    ("md_path", "a winding stone path"), ("md_daily", "a rising sun over mountains"), ("md_classic", "a stack of blank tiles in a pyramid"),
    ("md_triples", "three matching blank tiles"), ("md_connect", "two tiles joined by a glowing line"), ("md_garden", "a raked zen garden stone"),
    ("md_riichi", "a thin riichi stick with a red dot"), ("md_koikoi", "a hanafuda-style flower card back"), ("md_palm", "an open hand with line patterns"),
    ("md_duels", "two crossed paper fans"), ("md_adventure", "a pagoda tower"),
    ("misc_share", "an arrow leaving a box"), ("misc_filter", "a funnel"),
]
MODE_COVERS = [
    ("path", "a winding lantern-lit path through mountains to a distant pagoda"), ("daily", "sunrise over a tea house roof with a floating calendar leaf"),
    ("classic", "a calm table with a pyramid of blank ivory tiles in warm light"), ("triples", "three glowing blank tiles aligned above a tray"),
    ("connect", "two tiles joined by a glowing silk thread over water"), ("garden", "a quiet zen garden with raked sand, moss and a lantern"),
    ("riichi", "a tense table with a single glowing riichi stick and blank tiles"), ("koikoi", "twelve flower cards fanned out under a moon"),
    ("palm", "a hand with glowing lines holding a few blank tiles"), ("duels", "two crossed fans over an arena of lanterns"),
    ("adventure", "a tall pagoda on a cliff with floating lanterns and fog"),
]
SMALL_ITEMS = [
    ("rarity_a_frame", "ornate square frame in jade green"), ("rarity_s_frame", "ornate square frame in lavender-silver"), ("rarity_ssr_frame", "ornate square frame in gold"),
    ("avatar_frame_bamboo", "round avatar frame with bamboo"), ("avatar_frame_lacquer", "round avatar frame in black lacquer with gold"), ("avatar_frame_jade", "round avatar frame in carved jade"),
    ("avatar_frame_night", "round avatar frame in indigo with silver stars"), ("badge_bronze", "a round bronze mastery badge"), ("badge_silver", "a round silver mastery badge"),
    ("badge_gold", "a round gold mastery badge"), ("badge_perfect", "a round pearl mastery badge"), ("ribbon_new", "a plain unlabeled corner ribbon in red lacquer"),
    ("ribbon_limited", "a plain unlabeled corner ribbon in gold"), ("divider_lantern", "a horizontal ornamental divider with small lanterns"),
    ("divider_wave", "a horizontal ornamental divider with seigaiha waves"), ("panel_corner_gold", "a gold hairline panel corner ornament"),
    ("panel_corner_jade", "a jade panel corner ornament"), ("button_plate_lacquer", "a blank rounded lacquer button plate"),
    ("button_plate_paper", "a blank rounded paper button plate"), ("tab_underline", "a thin glowing underline stroke"),
    ("loading_ring", "a thin ring of lantern light"), ("toast_plate", "a blank slim lacquer toast plate"),
]
UI_STYLE = ("flat lacquer style with soft painterly shading, thin gold hairline outline, near-black plum background, one centered object, "
            "generous padding, saturated jewel colors, " + NOTEXT)


def build_U1(H, tail):
    b = Batch("U1", base_meta(
        "U1", "P54", "UI kit: 60 icons, 11 mode covers, 22 small items", 3, "UI kit", 372,
        depends_on=["H0"], owner_gate="icon set approved as one family (one nav-bar set), palette from tokens.json",
        candidates_policy="icons: 4 candidates at 1k medium (1 cr); covers: 4 at 2k high (2 cr); small items: 2 at 1k (1 cr)",
        selection={"keep_per_task": 1, "gate": "set consistency: same stroke weight, same lacquer/gold language, tokens.json palette",
                   "criteria": ["zero text, letters, numerals or glyph-like marks (OCR gate = 0 characters)", "reads at 48 px: one strong silhouette",
                                "same stroke weight and corner language as the rest of the kit", "colors inside the tokens.json palette: lacquer / paper / gold / jade",
                                "gold only for SSR and one accent"]},
        tool_note="gpt_image_2_6 without elements. Backgrounds of covers could be re-rendered with LoRA v2 later; this plan uses gpt for all three groups.",
        assumptions=["60 icons: 5 nav + 6 currencies + 8 actions + 10 status + 12 system + 6 audio + 11 modes + 2 misc"]))
    assert len(ICONS) == 60 and len(MODE_COVERS) == 11 and len(SMALL_ITEMS) == 22
    for k, sub in ICONS:
        b.add(f"icon_{k}", stage="search", kind="icon", media="image", tool="generate_image", model="gpt_image_2_6", quality="medium", size=size_gpt("1:1", "1k"),
              prompt=f"Mobile game UI icon: {sub}. {UI_STYLE}.", candidates=4, unit_cost_cr=1.0)
    for k, sub in MODE_COVERS:
        b.add(f"cover_{k}", stage="final", kind="mode_cover", media="image", tool="generate_image", model="gpt_image_2_6", quality="high", size=size_gpt("4:3", "2k"),
              prompt=(f"Mode cover art for a mahjong puzzle game card: {sub}. Painted anime gacha background, dark lacquer palette with warm lantern light, "
                      f"empty lower third left clear for a title added in the engine, no characters, {NOTEXT}."), candidates=4, unit_cost_cr=2.0)
    for k, sub in SMALL_ITEMS:
        b.add(f"small_{k}", stage="search", kind="small_item", media="image", tool="generate_image", model="gpt_image_2_6", quality="medium", size=size_gpt("1:1", "1k"),
              prompt=f"Game UI element: {sub}. {UI_STYLE}.", candidates=2, unit_cost_cr=1.0)
    b.meta["pilot"] = pilot_of(b, ["icon_tab_tea", "cover_classic", "small_rarity_ssr_frame"], 2)
    return b


# ----------------------------------------------------------------------------------------------------------------------
# V1/V2/V3 voice
# ----------------------------------------------------------------------------------------------------------------------
V1_LINES = [
    ("greet", "いらっしゃいませ。今日もいい牌が来るといいですね。", "warm welcoming greeting, 2.5 s, smiling voice"),
    ("win", "やった、和了です！ふふ、見ましたか？", "bright delighted, 2 s, small proud laugh at the end"),
    ("lose", "あっ、負けちゃいました…次は負けませんよ。", "disappointed then determined, 2.5 s"),
    ("combo", "すごい、連続で決まりましたね！", "excited praise, 1.5 s"),
    ("tease", "ふふ、そんなに見つめられると照れてしまいます。", "playful teasing aimed at the player, adult, 3 s, light breath"),
    ("shy", "も、もう…からかわないでください。", "flustered and shy, 2 s, hesitant"),
    ("vow", "これからもずっと、あなたの隣で牌を打たせてください。", "sincere tender promise, 4 s, soft and slow"),
    ("idle", "お茶が入りましたよ。少し休憩しませんか？", "relaxed gentle invitation, 3 s"),
    ("gift", "わあ、ありがとうございます。大切にしますね。", "touched and grateful, 3 s"),
    ("ult", "いきますよ…これが私の本気です！", "focused build-up to a powerful shout, 2.5 s"),
]
V1_MODELS = [("seed_audio", 0.20, "quoted"), ("elevenlabs_v4", 0.23, "assumed"), ("text2speech_v2", 0.15, "assumed")]


def build_V1(H, tail):
    b = Batch("V1", base_meta(
        "V1", "P46", "Blind test: JP voice, 3 models x 3 voices x 10 lines", 1, "Voice", 17.4,
        owner_gate="M8: owner or a JP native listens to the 90 samples blind; threshold >= 70% 'indistinguishable from studio' (Q-14)",
        candidates_policy="one take per (model, voice, line); no culling inside the batch: all 90 samples go to the blind test",
        selection={"keep_per_task": 1, "gate": ">= 70% of listeners cannot tell it from a studio recording; otherwise a live actress is needed for mc, yue, zlata (Q-14)",
                   "criteria": ["naturalness of intonation and pitch accent in Japanese", "no robotic artifacts, no clipping, no breaths cut",
                                "emotion matches the direction", "LUFS around -16 after normalisation", "lines are the same 10 sentences for every model and voice"]},
        tool_note="Voice ids are chosen at run time from list_voices / the model's JP library (voice_id is null here). The three voice slots per model are 'young bright', 'warm mature', 'calm low'. Model ids are the GDD names and must be confirmed with models_explore.",
        assumptions=["seed_audio 0.20 cr per line (quoted); ElevenLabs v4 0.23 and text2speech_v2 0.15 are from R2/PS, not quoted"]))
    slots = [("v_young_bright", "young adult female, bright and lively"), ("v_warm_mature", "adult female, warm and mature"), ("v_calm_low", "adult female, calm lower register")]
    for mid, price, basis in V1_MODELS:
        for sid, sdesc in slots:
            for lid, text, direction in V1_LINES:
                b.add(f"{mid}.{sid}.{lid}", stage="generate", kind="voice_test", media="audio", tool="generate_audio", model=mid, voice_id=None, voice_hint=sdesc,
                      language="ja", text=text, prompt=f"Japanese voice line, {direction}. Voice type: {sdesc}. Text: {text}", candidates=1, unit_cost_cr=price,
                      unit_cost_basis=basis, size={"aspect": "n/a", "resolution": "n/a", "width": 0, "height": 0}, duration_s=3,
                      output={"dir": f"{OUTPUT_ROOT}/V1/{mid}", "name": f"{sid}_{lid}"})
    b.meta["pilot"] = pilot_of(b, [f"seed_audio.v_young_bright.{V1_LINES[0][0]}", f"seed_audio.v_young_bright.{V1_LINES[4][0]}"], 1)
    return b


# Beta-24 lines (24 per heroine) and the remaining 36 of Launch-60: id, delivery direction
BETA24 = [
    ("login_morning", "bright gentle morning greeting, 2 s"), ("login_evening", "relaxed warm evening greeting, 2 s"),
    ("intro_summon", "first-meeting introduction of herself, confident and charming, 3-4 s"), ("outfit_equip", "pleased reaction to a new outfit, 1.5 s"),
    ("idle_1", "casual hum or remark while waiting, 2 s"), ("idle_2", "light thoughtful remark about the player, 2.5 s"), ("idle_3", "small playful comment, 2 s"),
    ("idle_warm_1", "warmer affectionate remark, 3 s, soft"), ("touch_head_1", "pleased reaction to a headpat, 1 s"), ("touch_head_2", "flustered happy reaction to a headpat, 1.2 s"),
    ("touch_hand_1", "shy reaction to a hand touch, 1.2 s"), ("touch_hair_1", "soft surprised reaction to a hair touch, 1.2 s"),
    ("touch_outfit_1", "embarrassed reaction to an outfit touch, no reference to the body, 1.2 s"),
    ("gift_normal", "polite thanks for a gift, 2 s"), ("gift_liked", "delighted thanks for a favourite gift, 2.5 s"),
    ("level_max_vow", "sincere vow of devotion, slow and tender, 6-8 s"), ("combo_t1", "short quick cheer, 0.6 s"), ("combo_t2", "stronger cheer, 0.9 s"),
    ("combo_t3", "big excited shout of praise, 1.2 s"), ("clear_normal", "happy relieved cheer after clearing the board, 1.5 s"),
    ("fail", "gentle disappointed encouragement, 1.5 s"), ("ult_cast_a", "powerful focused battle shout, 1 s"), ("riichi", "calm declaration of riichi, 1 s"), ("ron", "triumphant call of ron, 1 s"),
]
LAUNCH_REST = [
    ("profile_intro", "calm self-introduction on the profile, 3-4 s"), ("login_day", "cheerful afternoon greeting, 2 s"), ("login_night", "sleepy soft late-night greeting, 2 s"),
    ("login_return3d", "glad and slightly reproachful welcome back after days away, 2.5 s"), ("outfit_new_ssr", "excited about a brand-new special outfit, 2.5 s"),
    ("parting", "short warm goodbye, 0.6 s"), ("idle_warm_2", "warm affectionate remark, 3 s"), ("idle_warm_3", "warm affectionate remark, 3 s, a little shy"),
    ("idle_wait", "gentle nudge after minutes of no touch, 3 s"), ("idle_late", "quiet late-night remark, 3 s"), ("touch_head_3", "happy giggle after a headpat, 1.2 s"),
    ("touch_hand_2", "shy murmur after a hand touch, 1.2 s"), ("touch_hair_2", "soft contented sigh after a hair touch, 1.2 s"),
    ("touch_outfit_2", "embarrassed protest, playful, no reference to the body, 1.2 s"), ("touch_spam_1", "mock-annoyed protest at repeated taps, 1.5 s"),
    ("touch_spam_2", "pouting protest at repeated taps, 1.5 s"), ("touch_bold_1", "playful teasing at the player, flustered, adult, 2 s, no explicit content"),
    ("touch_bold_2", "flustered teasing at the player, 2 s, no explicit content"), ("touch_bold_3", "shy flirtatious murmur to the player, 2 s, no explicit content"),
    ("touch_rare_1", "rare surprised squeak and giggle, 1.5 s"), ("gift_special", "overjoyed and moved by a special gift, 3 s"),
    ("level_2", "pleased remark at a small bond milestone, 3 s"), ("level_4", "warmer remark at a bond milestone, 3 s"), ("level_6", "affectionate remark at a bond milestone, 3.5 s"),
    ("level_8", "tender remark at a bond milestone, 4 s"), ("bond_memory", "wistful fond memory shared with the player, 5 s"),
    ("clear_perfect", "proud delighted cheer after a perfect clear, 2 s"), ("tray_danger", "worried quick warning that the tray is almost full, 1 s"),
    ("hint_given", "helpful quick hint remark, 1.2 s"), ("shuffle", "quick playful remark while tiles shuffle, 1 s"), ("ult_ready", "eager 'I'm ready' line, 1 s"),
    ("ult_cast_b", "second powerful battle shout, different wording, 1 s"), ("chi", "short call of chi, 0.5 s"), ("pon", "short call of pon, 0.5 s"),
    ("kan", "short call of kan, 0.6 s"), ("tsumo", "triumphant call of tsumo, 1 s"),
]
CASTING = {"zlata": "Helena", "kohaku": "Isla", "shirin": "Giselle", "tsubame": "Elodie", "miel": "Hana"}


def voice_tasks(b: Batch, H, heroines, lines, takes, price, prefix):
    for hk in heroines:
        h = H[hk]
        for lid, direction in lines:
            b.add(f"{hk}.{lid}", stage="generate", kind="voice_line", media="audio", tool="generate_audio", model="voice_winner_of_V1", heroine=hk,
                  voice_id=None, voice_hint=CASTING.get(hk, "decided by the V1 blind test"), language="ja", text=None,
                  text_ref=f"content voice registry (P44): {hk}_{lid} JP text", text_status="pending_P44",
                  prompt=(f"Japanese voice line for {h['name']} ({h['role']}), adult woman of {h['age']}. Delivery: {direction}. "
                          f"Line id {hk}_{lid}. Take {takes} versions; keep the same voice and mic distance, no background noise. Text is supplied from the P44 registry."),
                  candidates=takes, unit_cost_cr=price, unit_cost_basis="assumed", size={"aspect": "n/a", "resolution": "n/a", "width": 0, "height": 0},
                  duration_s=2, output={"dir": f"{OUTPUT_ROOT}/{prefix}/{hk}", "name": f"{hk}_{lid}" + "_t{n}"})


def build_V2(H, tail):
    b = Batch("V2", base_meta(
        "V2", "P47", "Beta-24 x 10 heroines, 3 takes per line", 2, "Voice", 144, depends_on=["V1"], blocked_by=["P44 JP texts", "V1 verdict (Q-14)"],
        owner_gate="V1 passed >= 70% (otherwise live actress for mc, yue, zlata and the model is used only for the rest); P44 delivers JP texts",
        candidates_policy="3 takes per line (240 lines x 3 = 720 generations at 0.20 cr)",
        selection={"keep_per_task": 1, "gate": "LUFS gate + listening to a 10% sample", "criteria": ["-16 LUFS mono after normalisation", "no clipping or cut breaths",
                                                                                                    "pitch accent and emotion correct; JP text matches the registry exactly", "same voice across all lines of one heroine"]},
        tool_note="24 lines per heroine = the Beta-24 list of GDD 8.4 (touch_spam, touch_bold and tsumo are deferred to Launch-60; touch lines of the Full tier are not in Beta). Texts are not in this file: they come from P44; the task stays `pending_P44` until `text` is filled.",
        assumptions=["0.20 cr per line (seed_audio quoted); if the winning model is ElevenLabs v4 (0.23) the batch is 165.6 cr"]))
    assert len(BETA24) == 24
    voice_tasks(b, H, HERO_ORDER, BETA24, 3, 0.20, "V2")
    b.meta["pilot"] = pilot_of(b, ["mc.intro_summon", "rin.touch_head_1"], 1)
    return b


def build_V3(H, tail):
    b = Batch("V3", base_meta(
        "V3", "P47 (extension)", "Launch-60 remaining 36 lines for 3 flagships (mc, yue, zlata)", 5, "Voice", 64.8, in_plan=False, status="blocked_owner_decision",
        blocked_by=["V1 passed", "Q-14 accepted", "P44 JP texts"], depends_on=["V2"],
        owner_gate="only if the V1 blind test is passed and Q-14 is accepted",
        candidates_policy="3 takes per line (3 heroines x 36 x 3 = 324 generations at 0.20 cr)",
        selection={"keep_per_task": 1, "gate": "LUFS gate + sample listening", "criteria": ["same as V2", "touch_bold_* only with the Full-tier toggle; flirt only at the player; no explicit content"]},
        tool_note="Outside the 4-week window; the plan figure is 65-75 cr.", assumptions=["0.20 cr per line"]))
    assert len(LAUNCH_REST) == 36
    voice_tasks(b, H, ["mc", "yue", "zlata"], LAUNCH_REST, 3, 0.20, "V3")
    b.meta["pilot"] = pilot_of(b, ["mc.profile_intro"], 1)
    return b


# ----------------------------------------------------------------------------------------------------------------------
# M1 music
# ----------------------------------------------------------------------------------------------------------------------
M1_TRACKS = [
    ("table_riichi", 75, True, "Riichi table music, a focused premium mahjong table at night in a magical East-Asian teahouse. Calm, intense, grown-up, never aggressive. Lead melody on guzheng with a soft erhu answer, warm Rhodes piano chords, soft analog synth pads, soft lo-fi drums with brushed snare, warm upright-style bass, pizzicato strings and woodblock accents. Built on a short hummable five-note pentatonic hook. Anime-pop fusion with traditional Chinese instruments, 92 BPM, A minor pentatonic leaning major. Seamless loop: no intro, no fade-in, no fade-out, no ending, starts directly on the groove. Instrumental only."),
    ("match_finale", 22, True, "Finale layer for a calm puzzle game, the last pairs of tiles, almost there. Sparkling anticipation, 8 bars. Rising guzheng runs over a pulsing synth bass, bell-like synth, light risers, warm piano chords, the same hook as a calm lo-fi puzzle loop at 88 BPM in A minor pentatonic leaning major. Tight ending that resolves on the tonic, no fade-out. Instrumental only."),
    ("results_bed", 30, True, "Results screen underscore, soft and rewarding, premium anime mobile game. Warm piano and gentle bell-like synth over a slow guzheng arpeggio, soft pad, very light brushed percussion, 84 BPM, D major pentatonic. Satisfied, calm, grown-up. Seamless loop: no intro, no fade-in, no fade-out, no ending. Instrumental only."),
    ("event_regular", 60, True, "Seasonal event theme for a premium anime mahjong game in a festive lantern market. Joyful, warm, festive, grown-up, not childish. Lead melody on plucky koto and guzheng doubled by bell-like synth, erhu countermelody, bright piano chords, light anime-pop drums with shaker and hand claps, gentle bass, finger snaps. Instantly hummable five-note pentatonic hook. 110 BPM, G major pentatonic. Seamless loop: no intro, no fade-in, no fade-out, no ending. Instrumental only."),
    ("event_fever", 17, False, "Short high-energy event fever sting-loop, festive lantern market at its peak. Driving 128 BPM four-on-the-floor kick, taiko accents, bright guzheng and synth lead, rising energy, anime-pop EDM costume, C major pentatonic. Joyful, energetic, never aggressive. Seamless loop. Instrumental only."),
    ("memorial_mc", 50, True, "Memorial scene theme for the mahjong salon owner, a heartfelt quiet moment at dawn in a teahouse. Tender, nostalgic, warm and grateful, never sad. Solo guzheng and warm piano with a soft erhu countermelody, light string pad, almost no percussion, 72 BPM, D major pentatonic. Gentle build to a warm resolution, soft ending, instrumental only."),
    ("memorial_yue", 50, True, "Memorial scene theme for a serene moon-palace ruler, a hushed night under a silver moon. Elegant, mysterious, tender, never scary. Solo pipa and soft piano with a slow erhu line, airy synth pads and distant bells, no drums, 3/4 waltz feel at 80 BPM, B minor pentatonic. Gentle resolution, soft ending, instrumental only."),
    ("memorial_zlata", 50, True, "Memorial scene theme for a firebird tsarevna of a fairy-tale kingdom, a warm glowing hearth at night. Proud, warm, nostalgic, never sad. Folk-inspired melody on gusli-like plucked strings and warm piano with a soft cello line, gentle pads, hand drum very soft, 78 BPM, E minor pentatonic leaning major. Gentle resolution, soft ending, instrumental only."),
    ("motif_zlata", 20, False, "Short leitmotif for a firebird tsarevna, regal and warm. Bright plucked gusli-like melody doubled by bells, warm piano chords, light hand drum, 108 BPM, E minor pentatonic leaning major. Instantly hummable hook stated twice. Seamless loop. Instrumental only."),
    ("motif_kohaku", 20, False, "Short leitmotif for a white fox shrine maiden, playful and mysterious. Plucky koto melody with a shakuhachi answer, soft bells, light percussion with wood blocks, 104 BPM, A minor pentatonic leaning major. Instantly hummable hook stated twice. Seamless loop. Instrumental only."),
    ("mode_classic", 56, True, "Classic solitaire mode loop, serene tea garden. Calm, meditative, grown-up. Slow guzheng arpeggios and sparse warm piano, soft pad, no drums, 72 BPM, G major pentatonic. Seamless loop: no intro, no fade-in, no fade-out, no ending. Instrumental only."),
    ("summon_ssr", 6, False, "Short rare-reveal sting for a premium gacha summon: silence-to-sparkle, rising bell-like synth and guzheng glissando into a golden major chord with a soft shimmer tail, C major. Resolves and rings out, no loop. Instrumental only."),
]
STEMS_FOR = ["table_riichi", "match_finale", "event_regular", "mode_classic", "memorial_mc", "memorial_yue", "memorial_zlata", "results_bed"]


def build_M1(H, tail):
    b = Batch("M1", base_meta(
        "M1", "P48", "Priority music: 12 tracks, 3 variants each, stems for the match tracks", 3, "Music", 298.5, depends_on=[],
        owner_gate="owner listens to the shortlist of each track after the seam gate (seam-flux/gate.py); key mismatches are accepted per track (the model keeps the key in 12 of 17 tracks)",
        candidates_policy="3 variants per track (456 s of material x 3 variants x 0.1453 cr/s = 198.8 cr), stems for 8 tracks (assumed 5 cr), reserve 25% for re-takes",
        selection={"keep_per_task": 1, "gate": "seam gate + LUFS -16 + listening",
                   "criteria": ["loop seam inaudible (no click, no tail), starts on the groove", "hook recognisable but does not distract in match tracks",
                                "key and tempo within the intended zone (log mismatches)", "instrumental only, no vocals", "no clipping, LUFS about -16"]},
        tool_note="elevenlabs_music_v2_5 (force_instrumental true, batch_size = variants), then separate_stems(four) only for tracks flagged with stems. Prompts follow AUDIO_BIBLE 9.2.",
        assumptions=["13.08 cr per 90 s = 0.1453 cr/s (quoted)", "separate_stems is not quoted: 5 cr per track is an assumption", "reserve 25% = 59.7 cr is one pool task"]))
    assert sum(t[1] for t in M1_TRACKS) == 456, sum(t[1] for t in M1_TRACKS)
    for tid, dur, stems, prompt in M1_TRACKS:
        b.add(tid, stage="generate", kind="music_track", media="audio", tool="generate_audio", model="elevenlabs_music_v2_5", prompt=prompt, force_instrumental=True,
              duration_s=dur, candidates=3, unit_cost_cr=round(0.1453 * dur, 4), unit_cost_basis="quoted", stems_planned=stems and tid in STEMS_FOR,
              size={"aspect": "n/a", "resolution": "n/a", "width": 0, "height": 0}, output={"dir": f"{OUTPUT_ROOT}/M1/{tid}", "name": "v{n}"})
    for tid in STEMS_FOR:
        b.add(f"stems_{tid}", stage="post", kind="stems", media="post", tool="separate_stems", model="separate_stems(four)",
              prompt=f"Split the approved variant of {tid} into 4 stems: base, tension, 'ardor' layer by the partner instrument, finale.", candidates=1, unit_cost_cr=5.0,
              unit_cost_basis="assumed", size={"aspect": "n/a", "resolution": "n/a", "width": 0, "height": 0}, depends_on_task=f"M1.{tid}")
    b.add("reserve_retakes", stage="reserve", kind="reserve_pool", media="post", tool="generate_audio", model="elevenlabs_music_v2_5",
          prompt="Pool of 25% for re-takes of tracks that fail the seam gate. Spend only after the owner names the track.", candidates=1,
          unit_cost_cr=r2((0.1453 * 456 * 3 + 40) * 0.25), unit_cost_basis="assumed", size={"aspect": "n/a", "resolution": "n/a", "width": 0, "height": 0})
    b.meta["pilot"] = pilot_of(b, ["summon_ssr", "event_fever"], 1)
    return b


# ----------------------------------------------------------------------------------------------------------------------
# S1 SFX
# ----------------------------------------------------------------------------------------------------------------------
SFX = [
    ("summon_banner", "soft ceremonial gong with rising shimmer, a banner unrolling"), ("summon_card_fly", "light whoosh of a card flying across, airy"),
    ("rarity_glow_r", "gentle jade chime glow, short"), ("rarity_glow_sr", "lavender-silver bright chime glow, short"), ("rarity_glow_ssr", "golden resonant bell glow with a shimmer tail"),
    ("summon_outfit_reveal", "silk fabric swish with a sparkle"), ("summon_skip", "quick soft whoosh and tick"),
    ("results_appear", "paper slide and soft wooden knock"), ("results_confirm", "warm wooden stamp with a small chime"),
    ("heart_levelup_small", "tiny heart sparkle, two rising bell notes"), ("heart_levelup_big", "warm heart bloom, ascending arpeggio of bells"),
    ("gift_give", "small box rustle and tied ribbon"), ("gift_liked", "happy sparkle chime"), ("vow_ring", "pure single ring of a bell, long reverb"),
    ("touch_head", "very soft pat on hair, cloth rustle"), ("touch_hand", "light fingertip touch, tiny tick"), ("touch_hair_swish", "soft hair swish"),
    ("touch_outfit_rustle", "gentle silk rustle"), ("blush_pop", "tiny cute pop with a soft sparkle"),
    ("tray_heartbeat", "low soft heartbeat pulse, two beats"), ("last_slot_tick", "dry wooden tick, tense"), ("hint_reveal", "soft glow chime with a bright sparkle"),
    ("new_dora", "bright clack of a tile flip and a small chime"), ("riichi_stick", "thin stick placed on lacquer with a clear click"), ("meld_clack", "two tiles clacking together firmly"),
    ("win_mangan", "short triumphant drum hit and bell flourish"), ("win_baiman", "stronger triumphant taiko and bell flourish"), ("win_yakuman", "grand taiko roll with gong and rising shimmer"),
    ("yakuman_ready", "rising tension riser with a soft heartbeat that releases into sparkle"), ("countdown_tick", "crisp small wooden tick"),
    ("round_start_tiles", "tiles being swept and stacked on a felt table"), ("score_count", "quick tally of tiny wooden beads"), ("rank_change", "soft ascending sweep with a gentle bell"),
    ("toggle", "small lacquer switch click"), ("slider_tick", "very short light tick"), ("popup_open", "soft airy lift with a faint chime"), ("popup_close", "soft airy drop with a faint tap"),
    ("locked_deny", "soft dull wooden knock, polite no"), ("purchase_seal", "wax seal stamp with a warm chime"), ("daily_claim", "bright coin pouch jingle with a sparkle"),
]
AMBIENT = [("amb_teahouse", "calm tea house interior ambience: faint kettle simmer, distant wind chimes, wooden creaks, very soft crowd murmur, seamless loop"),
           ("amb_rain_bamboo", "gentle rain on a bamboo grove with distant water drips and faint bamboo knocks, seamless loop")]


def build_S1(H, tail):
    assert len(SFX) == 40, len(SFX)
    b = Batch("S1", base_meta(
        "S1", "P49", "SFX: 40 sounds x 3 variants + 2 ambient loops of 30 s", 3, "SFX", 105, depends_on=[],
        owner_gate="owner listens to the three variants per sound; pick one, normalise peaks to -6 dBFS (P45)",
        candidates_policy="3 variants per sound (2 s each at 0.50 cr); ambient 3 variants x 30 s",
        selection={"keep_per_task": 1, "gate": "peak -6 dBFS and P45 mix rules",
                   "criteria": ["soft wood / lacquer / silk character, no buzzing or harsh synth", "no clipping, no click at the start or end", "length within 2 s (ambient 30 s seamless)",
                                "distinct from the existing 36 sounds (not a duplicate)", "variants differ enough to pick from"]},
        tool_note=("Mirelo 0.50 cr per 2 s (quoted in R2/PS). The GDD list has 42 new names; `summon_item_reveal` (reuse reward_pop) and `yakuman_chance` (merged into yakuman_ready) "
                   "are dropped so the plan figure of 40 holds. License of the audio source for embedding is marked NOT VERIFIED in the GDD."),
        assumptions=["0.50 cr per 2 s of audio (R2/PS)"]))
    for sid, desc in SFX:
        b.add(sid, stage="generate", kind="sfx", media="audio", tool="generate_audio", model="mirelo_sfx", prompt=f"Sound effect for a premium anime mahjong mobile game: {desc}. Clean, short, no music, no voice.",
              duration_s=2, candidates=3, unit_cost_cr=0.5, size={"aspect": "n/a", "resolution": "n/a", "width": 0, "height": 0},
              output={"dir": f"{OUTPUT_ROOT}/S1/{sid}", "name": "v{n}"})
    for sid, desc in AMBIENT:
        b.add(sid, stage="generate", kind="ambient", media="audio", tool="generate_audio", model="mirelo_sfx", prompt=f"Ambient loop for a premium anime mahjong mobile game: {desc}. No music, no voice, no sudden sounds.",
              duration_s=30, candidates=3, unit_cost_cr=7.5, size={"aspect": "n/a", "resolution": "n/a", "width": 0, "height": 0},
              output={"dir": f"{OUTPUT_ROOT}/S1/{sid}", "name": "v{n}"})
    b.meta["pilot"] = pilot_of(b, ["locked_deny", "rarity_glow_ssr", "win_yakuman"], 1)
    return b


# ----------------------------------------------------------------------------------------------------------------------
# X1 video pilots
# ----------------------------------------------------------------------------------------------------------------------
def build_X1(H, tail):
    b = Batch("X1", base_meta(
        "X1", "P57", "Video pilots: SSR ultimate (Kling 3.0 / Seedance 2.5) + memorial", 4, "Video", 190, depends_on=["H1", "H4"],
        blocked_by=["approved start frames (H1 / H4)", "P38 pipeline"],
        owner_gate="M-gate: owner approves the start frames and the pilot clips; face-similarity and size gates after encoding",
        candidates_policy="ultimate: 2 Kling prompts x 3 attempts (6 x 10 cr) + 1 Seedance prompt x 2 attempts (2 x 35 cr); memorial: 2 Kling prompts x 3 attempts (6 x 10 cr)",
        selection={"keep_per_task": 1, "gate": "face similarity to the start frame + final .ogv size <= 0.9 MB",
                   "criteria": ["no redraw of the frame (the main failure of seedance_2_5 omni_reference in the earlier pilot)", "no extra blink / double wink; anatomy stays 5/5",
                                "seam: first and last frame match for loops (drift check)", "no text appears; style and colors identical to the key frame"]},
        tool_note=("Plan prices: Kling 3.0 10 cr per 5 s, Seedance 2.5 35 cr per 5 s (R2/PS). VIDEO_BIBLE lists different prices (kling3_0 7 cr, kling4_0 15 cr per 4 s, seedance_2_5 64 cr) "
                   "and `kling4_0` as the loop winner: run estimate_video_cost before every task and re-plan if the quote exceeds max_credits."),
        assumptions=["video prices come from R2/PS and are not re-quoted tonight", "start frames are placeholders until H1/H4 finals are approved"]))
    ult = ("2D anime character ultimate cut-in animation in the style of a premium gacha game: the heroine raises the moon-phase fan, crescent light gathers "
           "and a pearly gold energy ring expands behind her, hair and ribbons sway upward with the energy, a bright flash at the peak, then she smiles at the viewer. "
           "Camera slowly pushes in, no cuts. Keep exact face, art style, colors and line art of the start frame, no redraw, anatomy unchanged. No text.")
    ult2 = ("2D anime character ultimate animation in the style of a premium gacha game: calm focus, eyes narrow, the heroine sweeps one hand in a wide arc, petals and gold sparks "
            "follow the arc and swirl around her, a soft light bloom, ends with a confident smile at the viewer. Camera completely still. Keep exact face, art style, colors "
            "and line art of the start frame, anatomy unchanged. No text.")
    mem1 = ("2D anime character memorial scene animation in the style of a premium gacha game: dawn light slowly rises in a quiet tea house, the heroine stands by a window and "
            "breathes softly, a faint warm smile, steam from a cup, curtains move gently, lantern lights fade as sunlight comes in. Camera completely still. Keep exact face, art style, "
            "colors and line art of the start frame. No text.")
    mem2 = ("2D anime character memorial scene animation in the style of a premium gacha game: the heroine turns her head slowly toward the viewer, eyes soften, a tender smile, "
            "a few cherry petals drift past, hair and ribbons follow with slight delay, a soft golden glow. Camera completely still. Keep exact face, art style, colors and line art of the "
            "start frame. No text.")
    heroes = {"ult": H["yue"], "mem": H["mc"]}
    for i, (tid, pr) in enumerate([("ult_a", ult), ("ult_b", ult2)]):
        b.add(f"kling_{tid}", stage="generate", kind="video_ult", media="video", tool="generate_video", model="kling3_0", heroine="yue", prompt=pr, duration_s=5,
              start_frame="H4.yue_ssr.final (approved)", candidates=3, unit_cost_cr=10.0, unit_cost_basis="assumed",
              size={"aspect": "9:16", "resolution": "1080p", "width": 1080, "height": 1920}, output={"dir": f"{OUTPUT_ROOT}/X1/{tid}", "name": "kling_{n:02d}"})
    b.add("seedance_ult_a", stage="generate", kind="video_ult", media="video", tool="generate_video", model="seedance_2_5", heroine="yue", prompt=ult, duration_s=5,
          start_frame="H4.yue_ssr.final (approved)", candidates=2, unit_cost_cr=35.0, unit_cost_basis="assumed",
          size={"aspect": "9:16", "resolution": "720p", "width": 720, "height": 1280}, output={"dir": f"{OUTPUT_ROOT}/X1/seedance_ult_a", "name": "seed_{n:02d}"})
    for tid, pr in [("mem_a", mem1), ("mem_b", mem2)]:
        b.add(f"kling_{tid}", stage="generate", kind="video_memorial", media="video", tool="generate_video", model="kling3_0", heroine="mc", prompt=pr, duration_s=5,
              start_frame="H1.mc_base.final (approved)", candidates=3, unit_cost_cr=10.0, unit_cost_basis="assumed",
              size={"aspect": "9:16", "resolution": "1080p", "width": 1080, "height": 1920}, output={"dir": f"{OUTPUT_ROOT}/X1/{tid}", "name": "kling_{n:02d}"})
    b.meta["pilot"] = pilot_of(b, ["kling_ult_a"], 1, "one 10 cr Kling attempt on the approved start frame before the rest")
    return b



BUILDERS = [build_H0, build_H1, build_H2, build_H3, build_H4, build_E0, build_E1, build_E2, build_U1, build_V1, build_V2, build_V3, build_M1, build_S1, build_X1]
FILENAMES = {
    "H0": "H0_golden_composites", "H1": "H1_canon_set", "H2": "H2_wardrobe", "H3": "H3_combo_frames", "H4": "H4_ssr_keyart",
    "E0": "E0_lora_v2_training", "E1": "E1_lora_production", "E2": "E2_upscale_backgrounds", "U1": "UI_U1_ui_kit",
    "V1": "V1_blind_voice_test", "V2": "V2_beta24_voice", "V3": "V3_launch60_flagships", "M1": "M1_music_priority", "S1": "S1_sfx", "X1": "X1_video_pilots",
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tail", choices=sorted(TAILS), default=FULL_TAIL_ID)
    ap.add_argument("--out", default=str(OUT))
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    H = load_heroines()
    tail = TAILS[a.tail]
    index = []
    for fn in BUILDERS:
        b = fn(H, tail)
        d = b.dump()
        d["style_tail_id"] = a.tail if b.bid in ("H0", "H1", "H2", "H3", "H4") else None
        path = out / f"{FILENAMES[b.bid]}.json"
        path.write_text(json.dumps(d, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        index.append({"batch_id": b.bid, "file": path.name, "package": d["package"], "title": d["title"], "nominal_cr": d["budget"]["nominal_cr"],
                      "task_quota_sum_cr": d["totals"]["task_quota_sum_cr"], "tasks": d["totals"]["tasks"], "in_plan_ceiling": d["in_plan_ceiling"],
                      "status": d["status"]})
    (out / "index.json").write_text(json.dumps(index, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    plan = sum(i["nominal_cr"] for i in index if i["in_plan_ceiling"])
    print(f"built {len(index)} batches; in-plan nominal {plan:.1f} cr; tasks {sum(i['tasks'] for i in index)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
