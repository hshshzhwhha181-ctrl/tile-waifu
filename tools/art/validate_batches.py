#!/usr/bin/env python3
"""Validate design/art_batches/*.json (P59).  Text only, spends nothing.

    python3 tools/art/validate_batches.py              # validate every batch file; exit 0 = OK
    python3 tools/art/validate_batches.py --selftest   # prove the checks bite (injects 8 defects into in-memory copies)
    python3 tools/art/validate_batches.py --dir D --budget-md F

What is checked
  1. every file against design/art_batches/schema.json (jsonschema when installed, built-in required/type checks always)
  2. task math: quota = candidates x unit cost (+-0.011), max_credits >= quota, unique task ids, depends_on_task exists
  3. batch sum of task quotas == nominal (+-1%), and nominal == the row in design/ART_BATCHES.md (+-1%)
  4. plan: sum of in-plan nominals == plan_nominal_cr of ART_BATCHES.md (+-1%) and <= plan_ceiling_cr; hard stop <= nominal x 1.15 unless justified
  5. every batch has a credit ceiling, candidate counts, a cull criterion list and a pilot that costs <= 10% of the nominal
  6. heroine image prompts carry the element id of THEIR heroine (canonical list of HANDOFF 2.2), no foreign id, all 10 ids used
  7. banned words in 0 prompts, tier aware.  Standard files (no `tier` field): garter, lingerie, panties, upskirt, school, schoolgirl, teacher + the
     SPEC_V2 body/red-line list.  Tier FULL files (`"tier": "full"`, the heroine batches H0-H4): the costume words garter, stockings, bikini, bunny,
     curvy, hourglass, wide hips, full thighs, full bust are allowed (design/ART_TIER_FULL.md section 2), the HARD bans stay: school, schoolgirl, seifuku,
     student, teacher, minor, child, teen, loli, nude, naked, nipple, topless, genitals, sex, lingerie, panties, upskirt, plus the vocabulary tripwires cleavage, sexy, busty, thicc.
  8. every image prompt has a 'no text' constraint
"""
from __future__ import annotations

import argparse
import copy
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import full_tier_wardrobe as WD  # noqa: E402  (body table: heads per heroine)

ROOT = Path(__file__).resolve().parents[2]
DEF_DIR = ROOT / "design" / "art_batches"
DEF_MD = ROOT / "design" / "ART_BATCHES.md"

# HANDOFF 2.2 (Higgsfield Character Elements), verbatim
ELEMENTS = {
    "mc": "7df3cc78-06be-4080-87f0-49d3c1da4ff0", "rin": "4d50001c-c2be-4758-a1e5-6d2c7d5f70be", "hana": "ded72d02-6c3a-45e4-874a-0afdc3936c07",
    "yue": "8edeacc2-f24b-4a41-a166-66896711f259", "nova": "0c657961-8e36-4535-a0c3-0059ce5df987", "tsubame": "259cfc8a-2078-4aae-b99a-8670ac4ec5e1",
    "miel": "25525e3b-fa65-4695-a1c7-3253d092582a", "kohaku": "0b0bc9fd-fb9e-44c9-8f6b-bdb4899cacd8", "shirin": "33741746-8b6c-4e41-85a0-81a6adcd74db",
    "zlata": "ebdd5f33-3cc1-4d7e-afb6-13a698b1284f",
}
BANNED_PACKAGE = ["garter", "lingerie", "panties", "upskirt", "school", "schoolgirl", "teacher"]
# SPEC_V2 section 3 banned terms (body-size words, red lines) applied to image and video prompts too
BANNED_SPEC = ["curvy", "hourglass", "full bust", "large bust", "big bust", "huge", "busty", "voluptuous", "oversized", "wide hips", "full thighs",
               "thicc", "plump", "cleavage", "sexy", "seifuku", "bikini", "nude", "naked", "bunny", "stockings"]
# Tier FULL (RuStore / APK 18+ default, owner decision 2026-11-28): costume vocabulary that the Standard list banned is allowed ONLY for
# the costume itself.  Everything that is a hard line for every build stays banned (see the spec, section 2).
FULL_ALLOWED = {"garter", "stockings", "bikini", "bunny", "curvy", "hourglass", "wide hips", "full thighs", "full bust"}
HARD_BANNED_FULL = ["school", "schoolgirl", "seifuku", "student", "teacher", "classroom", "uniform", "minor", "underage", "child", "kid", "teen", "loli", "shota",
                    "nude", "naked", "nipple", "areola", "topless", "bottomless", "genital", "pussy", "vagina", "penis", "sex", "cum", "semen", "orgasm", "fellatio",
                    "sideboob", "underboob", "cameltoe", "lingerie", "panties", "upskirt", "cleavage", "sexy", "thicc", "busty"]
# Proportions rule (owner decision 2026-11-28, binding): the old "tall and statuesque, very long legs" wording is forbidden in Tier FULL image prompts;
# height is expressed by scale and framing, never by longer legs.  Camera must not be from below / wide-angle (it stretches the legs).
PROPORTION_BANNED = ["very long legs", "long legs", "long legged", "elongat", "statuesque", "leggy", "endless legs", "legs for days", "knee-level", "knee level",
                     "worm's-eye", "wide-angle lens", "fisheye"]
# a from-below / low-angle camera is banned unless the prompt negates it ("never from below", "no from-below angle")
RE_PROP = re.compile("|".join(re.escape(w) for w in PROPORTION_BANNED) + r"|(?<!never )(?<!no )(?<!not )(?:from[- ]below|\blow[- ]angle)", re.I)
PROP_REQUIRED = ["crotch line", "shoulder-to-crotch"]   # every Tier FULL heroine prompt carries the proportion rule
PROMPT_FIELDS = ("prompt", "text_ref")
NOTEXT_RE = re.compile(r"\bno (text|letters|lettering)\b|absolutely no text", re.I)
HEADS_RE = re.compile(r"(\d+(?:\.\d+)?) heads tall", re.I)
UUID_RE = re.compile(r"<<<([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})>>>")


def word_re(words):
    return re.compile(r"\b(" + "|".join(re.escape(w) for w in words) + r")\w*", re.I)


RE_PKG = word_re(BANNED_PACKAGE)
RE_SPEC = word_re(BANNED_SPEC)
# hard bans are matched as whole words with an optional plural/ing suffix, so 'sex' does not hit 'sextant' and 'cum' does not hit 'cumulus'
RE_HARD = re.compile(r"\b(" + "|".join(re.escape(w) for w in HARD_BANNED_FULL) + r")(s|es|ed|ing)?\b", re.I)


def parse_budget_md(path: Path):
    """Return ({batch: (nominal, plan_flag)}, plan_nominal, plan_ceiling) read from design/ART_BATCHES.md."""
    txt = path.read_text(encoding="utf-8")
    rows, idx = {}, None
    for line in txt.splitlines():
        if not line.startswith("|"):
            if idx is not None and rows:
                break
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if idx is None:
            low = [c.lower() for c in cells]
            if "batch" in low[0] and any("nominal" in c for c in low):
                idx = {"nom": next(i for i, c in enumerate(low) if "nominal" in c), "plan": next(i for i, c in enumerate(low) if ("plan" in c or "плане" in c) and "nominal" not in c)}
            continue
        key = cells[0].replace("*", "").strip()
        if re.fullmatch(r"[A-Z][0-9]", key):
            rows[key] = (float(cells[idx["nom"]].replace(",", "").replace(" ", "")), cells[idx["plan"]].strip().lower() in ("yes", "да"))
    m1 = re.search(r"plan_nominal_cr:\s*([\d.]+)", txt)
    m2 = re.search(r"plan_ceiling_cr:\s*([\d.]+)", txt)
    return rows, float(m1.group(1)) if m1 else None, float(m2.group(1)) if m2 else None


def type_ok(v, t):
    ts = t if isinstance(t, list) else [t]
    for x in ts:
        if x == "string" and isinstance(v, str): return True
        if x == "number" and isinstance(v, (int, float)) and not isinstance(v, bool): return True
        if x == "integer" and isinstance(v, int) and not isinstance(v, bool): return True
        if x == "boolean" and isinstance(v, bool): return True
        if x == "array" and isinstance(v, list): return True
        if x == "object" and isinstance(v, dict): return True
        if x == "null" and v is None: return True
    return False


def mini_check(obj, sch, root, path, errs):
    """Small subset of JSON Schema: $ref, type, required, properties, items, minItems, minLength, minimum, enum, const, pattern."""
    if "$ref" in sch:
        node = root
        for part in sch["$ref"].lstrip("#/").split("/"):
            node = node[part]
        return mini_check(obj, node, root, path, errs)
    if "const" in sch and obj != sch["const"]:
        errs.append(f"{path}: expected {sch['const']!r}")
    if "enum" in sch and obj not in sch["enum"]:
        errs.append(f"{path}: {obj!r} not in {sch['enum']}")
    if "type" in sch and not type_ok(obj, sch["type"]):
        errs.append(f"{path}: wrong type {type(obj).__name__}, want {sch['type']}")
        return
    if isinstance(obj, str):
        if len(obj) < sch.get("minLength", 0): errs.append(f"{path}: shorter than {sch['minLength']}")
        if "pattern" in sch and not re.search(sch["pattern"], obj): errs.append(f"{path}: {obj!r} does not match {sch['pattern']}")
    if isinstance(obj, (int, float)) and not isinstance(obj, bool):
        if "minimum" in sch and obj < sch["minimum"]: errs.append(f"{path}: below {sch['minimum']}")
        if "maximum" in sch and obj > sch["maximum"]: errs.append(f"{path}: above {sch['maximum']}")
        if "exclusiveMinimum" in sch and obj <= sch["exclusiveMinimum"]: errs.append(f"{path}: not above {sch['exclusiveMinimum']}")
    if isinstance(obj, list):
        if len(obj) < sch.get("minItems", 0): errs.append(f"{path}: fewer than {sch['minItems']} items")
        if "items" in sch:
            for i, x in enumerate(obj[:2000]):
                mini_check(x, sch["items"], root, f"{path}[{i}]", errs)
    if isinstance(obj, dict):
        for k in sch.get("required", []):
            if k not in obj: errs.append(f"{path}: missing required '{k}'")
        for k, sub in sch.get("properties", {}).items():
            if k in obj: mini_check(obj[k], sub, root, f"{path}.{k}", errs)


def validate(batches: dict, schema: dict, md_rows, plan_nom, plan_ceil, quiet=False):
    errs: list[str] = []
    warns: list[str] = []
    ids: dict[str, str] = {}
    used_elements: set[str] = set()
    plan_sum = 0.0
    try:
        import jsonschema  # type: ignore
        have_js = True
    except Exception:
        have_js = False
    for fname, d in sorted(batches.items()):
        bid = d.get("batch_id", "?")
        pre = f"{fname}"
        local: list[str] = []
        mini_check(d, schema, schema, "$", local)
        if have_js:
            v = jsonschema.Draft202012Validator(schema)
            for e in list(v.iter_errors(d))[:20]:
                local.append("schema: " + "/".join(str(p) for p in e.absolute_path) + ": " + e.message[:160])
        errs += [f"{pre}: {e}" for e in dict.fromkeys(local)]
        if local:
            continue
        tasks = d["tasks"]
        tsum = 0.0
        nominal = d["budget"]["nominal_cr"]
        for t in tasks:
            tid = t["id"]
            if not tid.startswith(bid + "."): errs.append(f"{pre}: task {tid} does not start with batch id {bid}.")
            if tid in ids: errs.append(f"{pre}: duplicate task id {tid} (also in {ids[tid]})")
            ids[tid] = fname
            exp = round(t["candidates"] * t["unit_cost_cr"], 2)
            if abs(exp - t["quota_cr"]) > 0.011: errs.append(f"{tid}: quota {t['quota_cr']} != candidates x unit = {exp}")
            if t["max_credits"] + 1e-9 < t["quota_cr"]: errs.append(f"{tid}: max_credits {t['max_credits']} < quota {t['quota_cr']}")
            tsum += t["quota_cr"]
            if t["media"] == "image" and (t["size"]["width"] <= 0 or t["size"]["height"] <= 0): errs.append(f"{tid}: image task without pixel size")
            if t["media"] in ("audio", "video") and "duration_s" not in t: errs.append(f"{tid}: {t['media']} task without duration_s")
            # banned words
            tier_full = d.get("tier") == "full" or t.get("tier") == "full"
            texts = ([(f, t.get(f) or "") for f in PROMPT_FIELDS] + [(f"prompt_variants[{i}]", v) for i, v in enumerate(t.get("prompt_variants") or [])]
                     + [(f"hero_prompt_variants[{i}]", v) for i, v in enumerate(t.get("hero_prompt_variants") or [])])
            for f, s in texts:
                if tier_full:
                    for m in RE_HARD.finditer(s): errs.append(f"{tid}: banned word '{m.group(0)}' in {f} (hard line, all tiers)")
                    continue
                for m in RE_PKG.finditer(s): errs.append(f"{tid}: banned word '{m.group(0)}' in {f}")
                if t["media"] in ("image", "video"):
                    for m in RE_SPEC.finditer(s): errs.append(f"{tid}: banned SPEC term '{m.group(0)}' in {f}")
            if tier_full and t["media"] == "image" and t.get("heroine"):
                # per-heroine body rules (owner decision 2026-11-28): heads tall in [HEADS_MIN, HEADS_MAX] and equal to the body table; adult face stated
                want_h = WD.HEIGHTS[t["heroine"]]["heads"]
                for f, v in texts:
                    if not v: continue
                    hs = [float(x) for x in HEADS_RE.findall(v)]
                    if not hs: errs.append(f"{tid}: no 'N heads tall' in {f}"); continue
                    for x in hs:
                        if not (WD.HEADS_MIN <= x <= WD.HEADS_MAX): errs.append(f"{tid}: {x} heads tall in {f} is outside the hard range {WD.HEADS_MIN}-{WD.HEADS_MAX}")
                        elif abs(x - want_h) > 0.011: errs.append(f"{tid}: {x} heads tall in {f} but the body table says {want_h} for {t['heroine']}")
                    if "mature adult face" not in v: errs.append(f"{tid}: {f} does not state a mature adult face")
                    for m in RE_PROP.finditer(v): errs.append(f"{tid}: proportion-banned phrase '{m.group(0)}' in {f} (owner proportions decision 2026-11-28)")
                    for need in PROP_REQUIRED:
                        if need not in v: errs.append(f"{tid}: {f} lacks the proportion rule phrase '{need}'")
                    if WD.FIGURE[t["heroine"]] not in v: errs.append(f"{tid}: {f} lacks the approved figure descriptor of {t['heroine']} (body table, leg fullness and bust)")
            if tier_full and t["media"] == "image":
                for i, v in enumerate(list(t.get("prompt_variants") or []) + list(t.get("hero_prompt_variants") or [])):
                    if not NOTEXT_RE.search(v): errs.append(f"{tid}: variant {i} lacks a 'no text' constraint")
                    if any(u not in v for u in UUID_RE.findall(t["prompt"])): errs.append(f"{tid}: variant {i} lacks the element id")
            # element ids
            found = UUID_RE.findall(t["prompt"])
            for u in found:
                if u not in ELEMENTS.values(): errs.append(f"{tid}: element id {u} is not in the HANDOFF 2.2 list")
                used_elements.add(u)
            if t["media"] == "image" and t.get("heroine"):
                want = ELEMENTS.get(t["heroine"])
                if want is None: errs.append(f"{tid}: unknown heroine '{t['heroine']}'")
                elif want not in found: errs.append(f"{tid}: prompt lacks <<<{want}>>> of {t['heroine']}")
                elif len(set(found)) != 1: errs.append(f"{tid}: more than one element id in a single-heroine prompt")
                if t["element_ids"] != ([want] if want else None): errs.append(f"{tid}: element_ids {t['element_ids']} != [{want}]")
            elif t["media"] == "image" and found:
                errs.append(f"{tid}: element id in a task without a heroine")
            if t["media"] == "image" and not NOTEXT_RE.search(t["prompt"]): errs.append(f"{tid}: image prompt lacks a 'no text' constraint")
            if t["media"] == "image" and t["tool"] == "generate_image" and t.get("heroine") and t.get("lora"):
                errs.append(f"{tid}: heroine frames must not use a LoRA (canon = gpt_image_2_6 + Elements)")
            if t["media"] == "audio" and t.get("text") is None and t.get("text_status") != "pending_P44" and t["kind"] == "voice_test":
                errs.append(f"{tid}: voice test without text")
            if "depends_on_task" in t and t["depends_on_task"] not in {x["id"] for b in batches.values() for x in b.get("tasks", [])}:
                errs.append(f"{tid}: depends_on_task {t['depends_on_task']} does not exist")
        tsum = round(tsum, 2)
        if abs(tsum - d["totals"]["task_quota_sum_cr"]) > 0.02: errs.append(f"{pre}: totals.task_quota_sum_cr {d['totals']['task_quota_sum_cr']} != {tsum}")
        if abs(tsum - nominal) > 0.01 * nominal: errs.append(f"{pre}: task quotas sum {tsum} differ from nominal {nominal} by more than 1%")
        if d["budget"]["hard_stop_cr"] < nominal: errs.append(f"{pre}: hard_stop below nominal")
        if d["budget"]["hard_stop_cr"] > nominal * 1.15 + 0.011 and not d["budget"].get("hard_stop_override_reason"):
            errs.append(f"{pre}: hard_stop {d['budget']['hard_stop_cr']} above nominal +15% without hard_stop_override_reason")
        if d["totals"]["tasks"] != len(tasks): errs.append(f"{pre}: totals.tasks mismatch")
        # pilot
        pil = d["pilot"]
        tids = {t["id"]: t for t in tasks}
        pc = 0.0
        for pid in pil["task_ids"]:
            if pid not in tids: errs.append(f"{pre}: pilot task {pid} not in batch"); continue
            n = pil.get("candidates_per_task") or tids[pid]["candidates"]
            pc += n * tids[pid]["unit_cost_cr"]
        if abs(pc - pil["max_cr"]) > 0.02: errs.append(f"{pre}: pilot max_cr {pil['max_cr']} != computed {round(pc, 2)}")
        if pc > 0.10 * nominal + 0.01: errs.append(f"{pre}: pilot costs {round(pc, 2)} > 10% of nominal {nominal}")
        if not pil["task_ids"] and bid != "E0": errs.append(f"{pre}: empty pilot")
        # budget md
        if md_rows is not None:
            if bid not in md_rows: errs.append(f"{pre}: batch {bid} has no row in ART_BATCHES.md")
            else:
                mn, mplan = md_rows[bid]
                if abs(mn - tsum) > 0.01 * mn: errs.append(f"{pre}: task quota sum {tsum} vs ART_BATCHES.md {mn} differ by more than 1%")
                if abs(mn - nominal) > 0.005: errs.append(f"{pre}: nominal {nominal} != ART_BATCHES.md {mn}")
                if mplan != d["in_plan_ceiling"]: errs.append(f"{pre}: in_plan_ceiling {d['in_plan_ceiling']} != ART_BATCHES.md plan flag {mplan}")
        if d["in_plan_ceiling"]: plan_sum += tsum
    if md_rows is not None:
        for k in md_rows:
            if k not in {d.get("batch_id") for d in batches.values()}: errs.append(f"ART_BATCHES.md lists {k} but there is no JSON for it")
        if plan_nom is None or plan_ceil is None:
            errs.append("ART_BATCHES.md lacks plan_nominal_cr / plan_ceiling_cr lines")
        else:
            if abs(plan_sum - plan_nom) > 0.01 * plan_nom: errs.append(f"plan: task quotas {round(plan_sum, 2)} vs plan_nominal_cr {plan_nom} differ by more than 1%")
            if plan_sum > plan_ceil: errs.append(f"plan: task quotas {round(plan_sum, 2)} above plan_ceiling_cr {plan_ceil}")
    missing = set(ELEMENTS.values()) - used_elements
    if missing and batches: errs.append("element ids never used in any prompt: " + ", ".join(sorted(k for k, v in ELEMENTS.items() if v in missing)))
    h1 = next((d for d in batches.values() if d.get("batch_id") == "H1"), None)
    if h1:
        have = {t.get("heroine") for t in h1["tasks"] if t.get("heroine")}
        if have != set(ELEMENTS): errs.append(f"H1 must cover all 10 heroines, has {sorted(have)}")
    return errs, warns, round(plan_sum, 2)


def load(dirp: Path):
    out = {}
    for p in sorted(dirp.glob("*.json")):
        if p.name in ("schema.json", "index.json"): continue
        out[p.name] = json.loads(p.read_text(encoding="utf-8"))
    return out


def selftest(batches, schema, md_rows, pn, pc):
    base_errs, _, _ = validate(batches, schema, md_rows, pn, pc)
    if base_errs:
        print("SELFTEST needs a clean baseline; errors:", *base_errs[:5], sep="\n  ")
        return 1
    cases = []

    def mut(name, fn, needle):
        cases.append((name, fn, needle))

    def first(c, b, pred):
        return next(t for t in c[b]["tasks"] if pred(t))

    def append_prompt(c, b, pred, extra):
        t = first(c, b, pred)
        t["prompt"] += extra

    def swap_element(c):
        t = first(c, "H1_canon_set.json", lambda t: t.get("heroine") == "rin")
        t["prompt"] = t["prompt"].replace(ELEMENTS["rin"], ELEMENTS["mc"])

    def scale_h3(c):
        for t in c["H3_combo_frames.json"]["tasks"]:
            t["unit_cost_cr"] = round(t["unit_cost_cr"] * 1.05, 4)
            t["quota_cr"] = round(t["candidates"] * t["unit_cost_cr"], 2)
            t["max_credits"] = t["quota_cr"]

    mut("banned word in a heroine prompt", lambda c: append_prompt(c, "H1_canon_set.json", lambda t: t.get("heroine"), " lingerie"), "banned word")
    mut("foreign element id", swap_element, "lacks")
    mut("quota arithmetic", lambda c: first(c, "H0_golden_composites.json", lambda t: True).__setitem__("quota_cr", 999.0), "quota")
    mut("batch sum off by 5%", scale_h3, "more than 1%")
    mut("no cull criteria", lambda c: c["S1_sfx.json"]["selection"].__setitem__("criteria", []), "fewer than 1")
    mut("no candidates field", lambda c: first(c, "UI_U1_ui_kit.json", lambda t: True).pop("candidates"), "missing required 'candidates'")
    mut("school word in an icon prompt", lambda c: append_prompt(c, "UI_U1_ui_kit.json", lambda t: True, " school bag"), "banned word")
    mut("text-free constraint dropped", lambda c: first(c, "UI_U1_ui_kit.json", lambda t: True).__setitem__("prompt", "Mobile game UI icon: a lantern on dark background."), "no text")
    mut("school word in a Tier FULL heroine prompt", lambda c: append_prompt(c, "H1_canon_set.json", lambda t: t.get("heroine"), " in a school classroom"), "banned word")
    mut("nude word in a Tier FULL wardrobe variant", lambda c: first(c, "H2_wardrobe.json", lambda t: t.get("prompt_variants")).__setitem__(
        "prompt_variants", [v + " fully nude" for v in first(c, "H2_wardrobe.json", lambda t: t.get("prompt_variants"))["prompt_variants"]]), "banned word")
    mut("minor word in a Tier FULL prompt", lambda c: append_prompt(c, "H0_golden_composites.json", lambda t: t.get("heroine"), " a teen girl"), "banned word")
    mut("heads below the hard floor in a Tier FULL prompt", lambda c: first(c, "H1_canon_set.json", lambda t: t.get("heroine") == "miel").__setitem__(
        "prompt", first(c, "H1_canon_set.json", lambda t: t.get("heroine") == "miel")["prompt"].replace("6.75 heads tall", "6.0 heads tall")), "hard range")
    mut("heads differ from the body table", lambda c: first(c, "H0_golden_composites.json", lambda t: t.get("heroine") == "yue").__setitem__(
        "prompt", first(c, "H0_golden_composites.json", lambda t: t.get("heroine") == "yue")["prompt"].replace("7.0 heads tall", "6.9 heads tall")), "body table")
    mut("heads above the new ceiling in a Tier FULL prompt", lambda c: first(c, "H1_canon_set.json", lambda t: t.get("heroine") == "yue").__setitem__(
        "prompt", first(c, "H1_canon_set.json", lambda t: t.get("heroine") == "yue")["prompt"].replace("7.0 heads tall", "7.5 heads tall")), "hard range")
    mut("'long legs' in a Tier FULL prompt", lambda c: append_prompt(c, "H1_canon_set.json", lambda t: t.get("heroine"), " with very long legs"), "proportion-banned")
    mut("'statuesque' in a Tier FULL wardrobe variant", lambda c: first(c, "H2_wardrobe.json", lambda t: t.get("prompt_variants")).__setitem__(
        "prompt_variants", [v + " statuesque" for v in first(c, "H2_wardrobe.json", lambda t: t.get("prompt_variants"))["prompt_variants"]]), "proportion-banned")
    mut("low knee-level camera that elongates the legs", lambda c: append_prompt(c, "H3_combo_frames.json", lambda t: t.get("heroine"), " low camera at knee level that elongates the legs"), "proportion-banned")
    mut("crotch-line rule dropped from a Tier FULL prompt", lambda c: first(c, "H0_golden_composites.json", lambda t: t.get("heroine")).__setitem__(
        "prompt", first(c, "H0_golden_composites.json", lambda t: t.get("heroine"))["prompt"].replace("the crotch line sits", "the waist sits")), "proportion rule")
    mut("banned word in a hero splash variant", lambda c: first(c, "H2_wardrobe.json", lambda t: t.get("hero_prompt_variants")).__setitem__(
        "hero_prompt_variants", [v + " fully nude" for v in first(c, "H2_wardrobe.json", lambda t: t.get("hero_prompt_variants"))["hero_prompt_variants"]]), "banned word")
    mut("adult-face statement dropped", lambda c: first(c, "H3_combo_frames.json", lambda t: t.get("heroine")).__setitem__(
        "prompt", first(c, "H3_combo_frames.json", lambda t: t.get("heroine"))["prompt"].replace("mature adult face", "face")), "mature adult face")
    mut("figure descriptor missing in a Tier FULL prompt", lambda c: first(c, "H3_combo_frames.json", lambda t: t.get("heroine") == "mc").__setitem__(
        "prompt", first(c, "H3_combo_frames.json", lambda t: t.get("heroine") == "mc")["prompt"].replace(WD.FIGURE["mc"], "soft figure")), "figure descriptor")
    mut("wardrobe variant loses its figure descriptor", lambda c: first(c, "H2_wardrobe.json", lambda t: t.get("prompt_variants")).__setitem__(
        "prompt_variants", [v.replace("full soft thighs", "slim legs") for v in first(c, "H2_wardrobe.json", lambda t: t.get("prompt_variants"))["prompt_variants"]]), "figure descriptor")
    mut("minor word next to a fuller-thigh body term", lambda c: append_prompt(c, "H2_wardrobe.json", lambda t: t.get("heroine") == "miel", " thick thighs on a schoolgirl"), "banned word")
    bad = 0
    for name, fn, needle in cases:
        c = copy.deepcopy(batches)
        fn(c)
        errs, _, _ = validate(c, schema, md_rows, pn, pc)
        hit = any(needle in e for e in errs)
        print(("ok   " if hit else "FAIL ") + f"selftest: {name} -> {'detected' if hit else 'NOT detected'}")
        bad += 0 if hit else 1
    c = copy.deepcopy(batches)
    append_prompt(c, "H1_canon_set.json", lambda t: t.get("heroine"), " with garter straps and thigh-high stockings, a bunny headband, a bikini, thick shapely thighs, wide hips and a curvy figure")
    errs, _, _ = validate(c, schema, md_rows, pn, pc)
    ok = not any("banned" in e for e in errs)
    print(("ok   " if ok else "FAIL ") + "selftest: Tier FULL allows garter / stockings / bunny / bikini / thick thighs / wide hips / curvy as body and costume words -> " + ("accepted" if ok else "WRONGLY flagged"))
    bad += 0 if ok else 1
    print(f"ART_BATCHES_SELFTEST {len(cases) + 1 - bad}/{len(cases) + 1}")
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=str(DEF_DIR))
    ap.add_argument("--budget-md", default=str(DEF_MD))
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    d = Path(a.dir)
    schema = json.loads((d / "schema.json").read_text(encoding="utf-8"))
    batches = load(d)
    md = Path(a.budget_md)
    md_rows, pn, pc = parse_budget_md(md) if md.exists() else (None, None, None)
    if md_rows is None:
        print("WARN: ART_BATCHES.md not found, budget cross-check skipped")
    if a.selftest:
        return selftest(batches, schema, md_rows, pn, pc)
    errs, _, plan_sum = validate(batches, schema, md_rows, pn, pc)
    for e in errs[:60]:
        print("ERROR", e)
    if len(errs) > 60:
        print(f"... and {len(errs) - 60} more")
    ntask = sum(len(b["tasks"]) for b in batches.values() if "tasks" in b)
    print(f"ART_BATCHES {'OK' if not errs else 'FAIL'}: {len(batches)} batches, {ntask} tasks, in-plan quota {plan_sum} cr "
          f"(plan_nominal {pn}, ceiling {pc}), {len(errs)} errors")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
