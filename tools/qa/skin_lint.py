#!/usr/bin/env python3
"""skin_lint.py - validates SkinPack manifest.json against design/specs/skin_manifest.schema.json + the rule tables inside it.
(design/specs/UNIFIED_QA_PLAN.md section 3; rule codes follow SKIN_HUD_SYSTEM.md section 7.1.)  Pure standard library.

  python tools/qa/skin_lint.py tools/qa/fixtures/skins                 # every manifest.json under the directory
  python tools/qa/skin_lint.py game/skins/yue/yue_ssr_scalearmor --check-files   # + files exist, bytes, sha256, status
  python tools/qa/skin_lint.py <paths> --json report.json [--release]

What it enforces (code -> rule):
  SL-MAN-01 JSON shape (schema)             SL-MAN-02 id/hero/dir consistent       SL-MAN-03 tier <-> hud_level
  SL-MAN-04 theme allowed for tier          SL-MAN-06/07 files: exist/hash/unique/known     SL-MAN-08 disk budget
  SL-MAN-09 voice lines >= tier minimum     SL-MAN-11 name/id word blacklist (red line 4)    SL-MAN-12 sign-offs (release)
  SL-SLOT-01 slot in registry + allowed for tier   SL-SLOT-03 9-slice margins   SL-SLOT-04 file size caps
  SL-SLOT-05 required slots present         SL-SLOT-06 slot kind == registry kind
  SL-PAL-01 NO raw colour literal anywhere  SL-PAL-02 colour ref allowed for slot/level   SL-PAL-03 one theme, own hero ramp
  SL-PAL-04 locked slot/token touched       SL-PAL-06 dyes
  SL-FONT-01 no fonts / font keys           SL-SEC-01 no scripts/shaders/binaries     SL-SEC-02 no URLs
  SL-FB-01 fallback chain declared + valid  SL-ULT-01 ult beats/name_key   SL-DUP-01 duplicate keys / ids / items
  SL-ID-01 duplicate skin id across manifests in one run
Exit code 0 = clean, 1 = at least one error, 2 = usage / unreadable schema.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULT_SCHEMA = REPO / "design" / "specs" / "skin_manifest.schema.json"

RAW_COLOR_RE = re.compile(r"(#[0-9A-Fa-f]{3,8}\b|\b(?:rgb|rgba|hsl|hsla|hsv|oklch|oklab)\s*\(|\bColor(?:8)?\s*\(|\bColor\.[A-Za-z_]+|\b0x[0-9A-Fa-f]{6,8}\b)")
URL_RE = re.compile(r"(?:[a-z][a-z0-9+.-]*://|\bwww\.)", re.I)
# red line 4 (no school / minor coding) and 2 (no nudity) in names; stems, case-insensitive. Review, don't auto-allow.
BLACKLIST = [r"stud(?:ent|y)", r"teen", r"\bkid", r"minor", r"child", r"school", r"loli", r"shota", r"uniform", r"sailor", r"gym[_ ]?class",
             r"nude", r"naked", r"nsfw", r"топлес", r"обнаж", r"голая", r"школ", r"учени[кц]", r"парта", r"ранец", r"матрос", r"малолет",
             r"несовершеннолет", r"девочк", r"лоли", r"детск", r"\bдети\b"]
BLACKLIST_RE = re.compile("|".join(BLACKLIST), re.I)


class DupKeyError(Exception):
    pass


def _pairs_hook_factory(dups: list):
    def hook(pairs):
        seen = {}
        for k, v in pairs:
            if k in seen:
                dups.append(k)
            seen[k] = v
        return seen
    return hook


def load_json(path: Path):
    dups: list = []
    doc = json.loads(Path(path).read_text(encoding="utf-8"), object_pairs_hook=_pairs_hook_factory(dups))
    return doc, dups


# ---------------------------------------------------------------------------------------------
# tiny JSON-Schema validator (subset used by skin_manifest.schema.json)
# ---------------------------------------------------------------------------------------------
def _type_ok(v, t):
    if t == "null":
        return v is None
    if t == "boolean":
        return isinstance(v, bool)
    if t == "integer":
        return isinstance(v, int) and not isinstance(v, bool)
    if t == "number":
        return isinstance(v, (int, float)) and not isinstance(v, bool)
    if t == "string":
        return isinstance(v, str)
    if t == "array":
        return isinstance(v, list)
    if t == "object":
        return isinstance(v, dict)
    return False


def validate(inst, sch, root, path="$", out=None):
    out = [] if out is None else out
    if "$ref" in sch:
        node = root
        for part in sch["$ref"].lstrip("#/").split("/"):
            node = node[part]
        return validate(inst, node, root, path, out)

    def err(msg):
        out.append((path, msg))

    if "const" in sch and not (inst == sch["const"] and type(inst) is type(sch["const"])):
        err(f"must be {sch['const']!r}")
        return out
    if "enum" in sch and not any(inst == e and type(inst) is type(e) for e in sch["enum"]):
        err(f"{inst!r} not in {sch['enum']}")
        return out
    if "type" in sch:
        ts = sch["type"] if isinstance(sch["type"], list) else [sch["type"]]
        if not any(_type_ok(inst, t) for t in ts):
            err(f"expected {'|'.join(ts)}, got {type(inst).__name__}")
            return out
    if isinstance(inst, str):
        if "pattern" in sch and not re.search(sch["pattern"], inst):
            err(f"{inst!r} does not match /{sch['pattern']}/")
        if "minLength" in sch and len(inst) < sch["minLength"]:
            err(f"shorter than {sch['minLength']}")
        if "maxLength" in sch and len(inst) > sch["maxLength"]:
            err(f"longer than {sch['maxLength']}")
    if isinstance(inst, (int, float)) and not isinstance(inst, bool):
        if "minimum" in sch and inst < sch["minimum"]:
            err(f"{inst} < minimum {sch['minimum']}")
        if "maximum" in sch and inst > sch["maximum"]:
            err(f"{inst} > maximum {sch['maximum']}")
    if isinstance(inst, list):
        if "minItems" in sch and len(inst) < sch["minItems"]:
            err(f"fewer than {sch['minItems']} items")
        if "maxItems" in sch and len(inst) > sch["maxItems"]:
            err(f"more than {sch['maxItems']} items")
        if sch.get("uniqueItems"):
            seen = []
            for x in inst:
                if x in seen:
                    err(f"duplicate item {x!r}")
                seen.append(x)
        if "items" in sch:
            for i, x in enumerate(inst):
                validate(x, sch["items"], root, f"{path}[{i}]", out)
    if isinstance(inst, dict):
        for r in sch.get("required", []):
            if r not in inst:
                err(f"missing required key '{r}'")
        props = sch.get("properties", {})
        if "maxProperties" in sch and len(inst) > sch["maxProperties"]:
            err(f"more than {sch['maxProperties']} properties")
        if "propertyNames" in sch:
            for k in inst:
                if "pattern" in sch["propertyNames"] and not re.search(sch["propertyNames"]["pattern"], k):
                    out.append((f"{path}.{k}", f"key {k!r} does not match /{sch['propertyNames']['pattern']}/"))
        for k, v in inst.items():
            if k in props:
                validate(v, props[k], root, f"{path}.{k}", out)
            else:
                ap = sch.get("additionalProperties", True)
                if ap is False:
                    out.append((f"{path}.{k}", f"unknown key '{k}' (additionalProperties=false)"))
                elif isinstance(ap, dict):
                    validate(v, ap, root, f"{path}.{k}", out)
    return out


# ---------------------------------------------------------------------------------------------
# lint
# ---------------------------------------------------------------------------------------------
class Result:
    def __init__(self, path):
        self.path = str(path)
        self.errors: list[dict] = []
        self.warnings: list[dict] = []
        self.id = None

    def e(self, code, where, msg):
        self.errors.append({"code": code, "path": where, "msg": msg})

    def w(self, code, where, msg):
        self.warnings.append({"code": code, "path": where, "msg": msg})

    @property
    def ok(self):
        return not self.errors

    def codes(self):
        return sorted({x["code"] for x in self.errors})


def walk(node, path="$"):
    """yield (path, key_or_None, value) for every scalar and every dict key"""
    if isinstance(node, dict):
        for k, v in node.items():
            yield f"{path}.{k}", k, None
            yield from walk(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk(v, f"{path}[{i}]")
    else:
        yield path, None, node


def _ref_parts(ref):
    """'NIGHT_700+T5@0.12' -> ('NIGHT_700', 'T5', 0.12); 'H300' -> ('H300', None, None)"""
    if "+" in ref:
        base, rest = ref.split("+", 1)
        tint, amt = rest.split("@")
        return base, tint, float(amt)
    return ref, None, None


def check_colour_slots(res: Result, slots: dict, where: str, doc: dict, sch: dict, theme, hero):
    cs, locked = sch["x-color-slots"], set(sch["x-locked-slots"])
    level = doc.get("hud_level")
    for name, ref in slots.items():
        p = f"{where}.{name}"
        if name in locked or name.upper() in sch["x-locked-tokens"]:
            res.e("SL-PAL-04", p, f"slot '{name}' is LOCKED (payment/semantic/rarity/text/combo/foil): a skin may not override it")
            continue
        if name not in cs:
            res.e("SL-PAL-02", p, f"unknown colour slot '{name}' (allowed: {', '.join(sorted(cs))})")
            continue
        rule = cs[name]
        if level not in rule["levels"]:
            res.e("SL-PAL-02", p, f"slot '{name}' is not overridable at HUD level L{level} (levels {rule['levels']})")
        if not isinstance(ref, str):
            continue
        base, tint, amt = _ref_parts(ref)
        if tint is None:
            if ref not in rule["from"]:
                res.e("SL-PAL-02", p, f"ref '{ref}' not allowed for slot '{name}' (allowed: {', '.join(rule['from'])})")
        else:
            if "mix" not in rule:
                res.e("SL-PAL-02", p, f"slot '{name}' does not allow mixing ('{ref}')")
            else:
                if base not in rule["from"]:
                    res.e("SL-PAL-02", p, f"mix base '{base}' not allowed for '{name}' (allowed: {', '.join(rule['from'])})")
                if tint not in rule["mix"]:
                    res.e("SL-PAL-02", p, f"mix tint '{tint}' not allowed for '{name}' (allowed: {', '.join(rule['mix'])})")
                if amt is not None and amt > rule["mix_max"] + 1e-9:
                    res.e("SL-PAL-02", p, f"mix amount {amt} > {rule['mix_max']} for '{name}'")
        parts = [x for x in (base, tint) if x]
        if any(re.fullmatch(r"T[1-5]", x) for x in parts) and not theme:
            res.e("SL-PAL-03", p, f"ref '{ref}' uses a theme ramp but theme is null (L0 skins take colours from the heroine ramp only)")
        if hero is None and any(re.fullmatch(r"H[1-9]00", x) for x in parts):
            res.e("SL-PAL-03", p, "heroine ramp ref without hero")


def lint_manifest(doc, dups, sch, path: Path, opts) -> Result:
    res = Result(path)
    for k in dups:
        res.e("SL-DUP-01", "$", f"duplicate JSON key '{k}'")
    # SL-PAL-01 / SL-FONT-01 / SL-SEC-02 / forbidden keys: deep scan BEFORE schema so the specific code always shows up
    forbidden = set(sch["x-forbidden-keys"])
    for p, k, v in walk(doc):
        if k is not None:
            if k.lower() in forbidden:
                code = "SL-FONT-01" if "font" in k.lower() else ("SL-SEC-02" if k.lower() in ("url", "urls", "exec", "command") else "SL-SEC-01")
                res.e(code, p, f"key '{k}' is forbidden in a manifest (skins cannot override fonts, scripts, shaders, geometry, timings, tokens)")
            if RAW_COLOR_RE.search(k):
                res.e("SL-PAL-01", p, f"raw colour literal in key {k!r}")
        elif isinstance(v, str):
            m = RAW_COLOR_RE.search(v)
            if m:
                res.e("SL-PAL-01", p, f"raw colour literal {m.group(0)!r}: use a palette ref (H500, T3, NIGHT_700+T5@0.12), never hex/rgb/Color()")
            if URL_RE.search(v):
                res.e("SL-SEC-02", p, f"external URL / scheme in {v!r}")
    # shape
    for p, msg in validate(doc, sch, sch):
        res.e("SL-MAN-01", p, msg)
    if not isinstance(doc, dict):
        return res
    res.id = doc.get("id") if isinstance(doc.get("id"), str) else None
    n_shape = len(res.errors)
    try:
        return _semantic(res, doc, sch, path, opts)
    except Exception as e:      # a hostile/garbled manifest must never crash the gate; the shape errors above already say why
        if len(res.errors) == n_shape and n_shape == 0:
            raise                # valid shape + crash = a BUG in skin_lint, do not hide it
        res.e("SL-MAN-01", "$", f"structure too malformed for the semantic rules ({type(e).__name__}: {e})")
        return res


def _semantic(res: Result, doc: dict, sch: dict, path: Path, opts) -> Result:
    tier, hero = doc.get("tier"), doc.get("hero")
    tr = sch["x-tier-rules"].get(tier) if isinstance(tier, str) else None
    if tr is None:
        return res                                    # shape errors already reported; tier tables need a valid tier
    rank = tr["rank"]
    pid = doc.get("id") if isinstance(doc.get("id"), str) else ""
    # SL-MAN-02
    if pid:
        suffix = "base" if tier == "base" else "vow" if tier == "vow" else None
        if not pid.startswith(f"{hero}_"):
            res.e("SL-MAN-02", "$.id", f"id '{pid}' must start with hero '{hero}_'")
        elif suffix and pid != f"{hero}_{suffix}":
            res.e("SL-MAN-02", "$.id", f"tier '{tier}' requires id '{hero}_{suffix}'")
        elif not suffix and not pid.startswith(f"{hero}_{tier}_"):
            res.e("SL-MAN-02", "$.id", f"tier '{tier}' requires id '{hero}_{tier}_<name>'")
        if opts.get("dirname", True) and path.name == "manifest.json" and path.parent.name != pid:
            res.e("SL-MAN-02", "$.id", f"directory '{path.parent.name}' != id '{pid}'")
    # SL-MAN-03/04 + boldness
    if doc.get("hud_level") != tr["hud_level"]:
        res.e("SL-MAN-03", "$.hud_level", f"tier '{tier}' requires hud_level {tr['hud_level']}, got {doc.get('hud_level')}")
    theme = doc.get("theme")
    if tr["hud_level"] == 0 and theme is not None:
        res.e("SL-MAN-04", "$.theme", f"L0 skin ('{tier}') must have theme null, got '{theme}'")
    elif tr["hud_level"] > 0 and theme is None:
        res.e("SL-MAN-04", "$.theme", f"tier '{tier}' needs one of {tr['themes']}")
    elif theme is not None and theme not in tr["themes"]:
        res.e("SL-MAN-04", "$.theme", f"theme '{theme}' is not allowed for tier '{tier}' (allowed {tr['themes']}; GILT = ssrp only)")
    if doc.get("boldness") not in tr["boldness"]:
        res.e("SL-TIER-02", "$.boldness", f"boldness {doc.get('boldness')} above the ceiling of tier '{tier}' (allowed {tr['boldness']})")
    pal = doc.get("palette") if isinstance(doc.get("palette"), dict) else {}
    if pal.get("hero") != hero:
        res.e("SL-PAL-03", "$.palette.hero", f"palette.hero '{pal.get('hero')}' != hero '{hero}' (a skin uses its own heroine's ramp)")
    if pal.get("theme") != theme:
        res.e("SL-PAL-03", "$.palette.theme", f"palette.theme '{pal.get('theme')}' != theme '{theme}' (one theme per skin)")
    # colour slots
    if isinstance(pal.get("slots"), dict):
        check_colour_slots(res, pal["slots"], "$.palette.slots", doc, sch, theme, hero)
    dyes = doc.get("dyes") or []
    if dyes and tier in ("base", "vow"):
        res.e("SL-PAL-06", "$.dyes", f"tier '{tier}' cannot have dyes")
    ids = [d.get("id") for d in dyes if isinstance(d, dict)]
    if len(ids) != len(set(ids)):
        res.e("SL-DUP-01", "$.dyes", "duplicate dye ids")
    for i, d in enumerate(dyes):
        if not isinstance(d, dict):
            continue
        if d.get("theme") not in tr["themes"]:
            res.e("SL-PAL-06", f"$.dyes[{i}].theme", f"dye theme '{d.get('theme')}' not allowed for tier '{tier}'")
        if isinstance(d.get("slots"), dict):
            check_colour_slots(res, d["slots"], f"$.dyes[{i}].slots", doc, sch, d.get("theme"), hero)
    # slots registry
    reg = sch["x-slot-registry"]
    slots = doc.get("slots") if isinstance(doc.get("slots"), dict) else {}
    fb = doc.get("fallbacks") if isinstance(doc.get("fallbacks"), dict) else {}
    hero_base = fb.get("hero_base")
    if tier == "base" and hero_base is not None:
        res.e("SL-FB-01", "$.fallbacks.hero_base", "a base skin has no hero_base fallback (must be null; chain = five_winds -> vector)")
    if tier != "base" and fb and hero_base != f"{hero}_base":
        res.e("SL-FB-01", "$.fallbacks.hero_base", f"must be '{hero}_base' (the base skin of the same heroine is always in the APK)")
    files = {f.get("path"): f for f in doc.get("files", []) if isinstance(f, dict)}
    paths = [f.get("path") for f in doc.get("files", []) if isinstance(f, dict)]
    if len(paths) != len(set(paths)):
        res.e("SL-DUP-01", "$.files", "duplicate file paths")
    for name, ent in slots.items():
        p = f"$.slots.{name}"
        if name not in reg:
            res.e("SL-SLOT-01", p, f"slot '{name}' is not in the slot registry (TWSkinSlots.TABLE)")
            continue
        r = reg[name]
        if r["min_tier"] > rank:
            res.e("SL-SLOT-01", p, f"slot '{name}' needs tier rank >= {r['min_tier']} but '{tier}' has {rank}")
        if not isinstance(ent, dict):
            continue
        kinds_ok = {r["kind"]} | ({"anim"} if r["kind"] in ("tex9", "tex") else set()) | ({"video", "clip"} if name == "ult.short" else set())
        if ent.get("kind") not in kinds_ok:
            res.e("SL-SLOT-06", f"{p}.kind", f"kind '{ent.get('kind')}' != registry kind '{r['kind']}'")
        if ent.get("kind") == "tex9":
            nine, w, h = ent.get("nine"), ent.get("w"), ent.get("h")
            if not (nine and w and h):
                res.e("SL-SLOT-03", p, "tex9 slot needs nine[4], w and h")
            elif max(nine) > min(w, h) / 3 + 1e-9:
                res.e("SL-SLOT-03", f"{p}.nine", f"9-slice margin {max(nine)} > min(w,h)/3 = {min(w, h) / 3:.1f}")
        fbv = ent.get("fallback")
        if fbv == "vector" and not r["vector"]:
            res.e("SL-FB-01", f"{p}.fallback", f"slot '{name}' has no vector drawer in the registry: fallback must be base/global")
        if fbv == "base" and hero_base is None:
            res.e("SL-FB-01", f"{p}.fallback", "fallback 'base' but the manifest has no hero_base (base skins fall back to global/vector)")
        f = ent.get("file")
        if f and f not in files:
            res.e("SL-MAN-07", f"{p}.file", f"'{f}' is not listed in files[]")
        elif f:
            kb = files[f].get("bytes", 0) / 1024
            cap = min(r["max_kb"], sch["x-max-video-kb"] if ent.get("kind") == "video" else sch["x-max-file-kb"])
            if kb > cap:
                res.e("SL-SLOT-04", f"{p}.file", f"{f} is {kb:.0f} KB > cap {cap} KB for slot '{name}'")
    if fb.get("vector") is not True:
        res.e("SL-FB-01", "$.fallbacks.vector", "vector fallback must be declared true (every slot has a vector drawer; the UI is never empty)")
    # required slots (SL-SLOT-05)
    for name, r in reg.items():
        if r["min_tier"] <= rank and name not in slots:
            if tier == "vow" and name.startswith("rig.") and "rig" not in doc:
                continue
            res.e("SL-SLOT-05", "$.slots", f"required slot '{name}' missing for tier '{tier}'")
    # files: forbidden extensions, every file referenced (SL-MAN-07), status approved
    for i, f in enumerate(doc.get("files", [])):
        if not isinstance(f, dict) or not isinstance(f.get("path"), str):
            continue
        ext = "." + f["path"].rsplit(".", 1)[-1].lower() if "." in f["path"] else ""
        if ext in sch["x-forbidden-extensions"]:
            code = "SL-FONT-01" if ext in (".ttf", ".otf", ".woff", ".woff2") else "SL-SEC-01"
            res.e(code, f"$.files[{i}].path", f"{f['path']}: files of type {ext} are forbidden inside a skin pack")
        if opts.get("release") and f.get("status") != "approved":
            res.e("SL-MAN-06", f"$.files[{i}].status", f"{f['path']} status '{f.get('status')}' (release needs approved)")
    # budget (SL-MAN-08)
    b = doc.get("budget") if isinstance(doc.get("budget"), dict) else {}
    if isinstance(b.get("disk_mb"), (int, float)):
        cap = tr["disk_budget_mb"] * (1 + sch["x-disk-tolerance"])
        if b["disk_mb"] > cap:
            res.e("SL-SIZE-01", "$.budget.disk_mb", f"{b['disk_mb']} MB > tier budget {tr['disk_budget_mb']} MB +{int(sch['x-disk-tolerance'] * 100)}% = {cap:.2f}")
        if files and sum(f.get("bytes", 0) for f in files.values() if isinstance(f, dict)) > 0:
            real = sum(f.get("bytes", 0) for f in files.values()) / 1048576
            if abs(real - b["disk_mb"]) > 0.02 * max(real, 0.5) + 0.05:
                res.e("SL-MAN-08", "$.budget.disk_mb", f"declared {b['disk_mb']} MB but files[] sum to {real:.2f} MB (budget is recomputed, never hand-set)")
    # voice (SL-MAN-09)
    lines = (doc.get("voice") or {}).get("lines", []) if isinstance(doc.get("voice"), dict) else []
    vids = [x.get("id") for x in lines if isinstance(x, dict)]
    if len(vids) != len(set(vids)):
        res.e("SL-DUP-01", "$.voice.lines", "duplicate voice line ids")
    if len(lines) < tr["min_voice_lines"]:
        res.e("SL-MAN-09", "$.voice.lines", f"{len(lines)} voice lines < minimum {tr['min_voice_lines']} for tier '{tier}'")
    # ult (SL-ULT-01 / SL-SLOT-05)
    ult = doc.get("ult") if isinstance(doc.get("ult"), dict) else {}
    if isinstance(ult.get("beats"), int) and ult["beats"] < tr["min_ult_beats"]:
        res.e("SL-ULT-01", "$.ult.beats", f"{ult['beats']} beats < {tr['min_ult_beats']} required for tier '{tier}'")
    if rank >= 2 and not ult.get("full"):
        res.e("SL-ULT-01", "$.ult.full", f"tier '{tier}' needs a full video ult (ult.full)")
    nk = ult.get("name_key", "")
    if isinstance(nk, str) and nk and nk.split(".")[1:2] and nk.split(".")[1] != tier:
        res.e("SL-ULT-04", "$.ult.name_key", f"name_key class '{nk.split('.')[1]}' != tier '{tier}'")
    for k, sl in (("rig_clip", "ult.rig_clip"), ("short", "ult.short"), ("full", "ult.full")):
        if ult.get(k) and sl in slots and isinstance(slots[sl], dict) and slots[sl].get("file") != ult[k]:
            res.e("SL-ULT-01", f"$.ult.{k}", f"'{ult[k]}' differs from slot {sl} file '{slots[sl].get('file')}'")
    # red line words (SL-MAN-11 / SL-RL-03)
    texts = {"$.name_ru": doc.get("name_ru"), "$.id": doc.get("id"), "$.ult.name_key": ult.get("name_key"),
             "$.provenance.element": (doc.get("provenance") or {}).get("element") if isinstance(doc.get("provenance"), dict) else None,
             "$.release.banner": (doc.get("release") or {}).get("banner") if isinstance(doc.get("release"), dict) else None}
    for p, t in texts.items():
        if isinstance(t, str) and BLACKLIST_RE.search(t):
            res.e("SL-MAN-11", p, f"'{t}' contains a blacklisted word stem (red lines 2/4: no minor/school coding, no nudity words)")
    for i, f in enumerate(doc.get("faces", []) if isinstance(doc.get("faces"), list) else []):
        if isinstance(f, str) and BLACKLIST_RE.search(f):
            res.e("SL-MAN-11", f"$.faces[{i}]", f"face id '{f}' contains a blacklisted word stem")
    # sign-offs (SL-MAN-12): always require two distinct auditors; pending checks only block --release
    qa = doc.get("qa") if isinstance(doc.get("qa"), dict) else {}
    if qa.get("adult_face", {}).get("by") if isinstance(qa.get("adult_face"), dict) else None:
        rb = (qa.get("red_line") or {}).get("by", []) if isinstance(qa.get("red_line"), dict) else []
        if qa["adult_face"]["by"] in rb and len(rb) < 3:
            res.w("SL-MAN-12", "$.qa", "adult_face auditor is also one of the 2 red-line auditors (4 eyes recommended)")
    for k in ("palette_lint", "ocr"):
        if qa.get(k) != "pass":
            (res.e if opts.get("release") else res.w)("SL-MAN-12", f"$.qa.{k}", f"qa.{k} is '{qa.get(k)}' (release needs 'pass')")
    return res


def check_files_on_disk(doc, root: Path, res: Result):
    listed = set()
    for i, f in enumerate(doc.get("files", [])):
        if not isinstance(f, dict) or "path" not in f:
            continue
        p = root / f["path"]
        listed.add(f["path"])
        if not p.is_file():
            res.e("SL-MAN-06", f"$.files[{i}]", f"{f['path']} does not exist in the pack")
            continue
        data = p.read_bytes()
        if len(data) != f.get("bytes"):
            res.e("SL-MAN-06", f"$.files[{i}].bytes", f"{f['path']}: {len(data)} bytes on disk != {f.get('bytes')}")
        if hashlib.sha256(data).hexdigest() != f.get("sha256"):
            res.e("SL-MAN-06", f"$.files[{i}].sha256", f"{f['path']}: sha256 mismatch (corrupted or edited after approval)")
    for p in sorted(root.rglob("*")):
        if p.is_file() and p.name != "manifest.json":
            rel = p.relative_to(root).as_posix()
            if rel not in listed:
                res.e("SL-MAN-07", "$.files", f"{rel} exists in the pack but is not listed in files[]")


def find_manifests(paths):
    out = []
    for p in map(Path, paths):
        if p.is_dir():
            out += sorted(p.rglob("manifest.json"))
        elif p.is_file():
            out.append(p)
        else:
            raise FileNotFoundError(str(p))
    return out


def lint_paths(paths, schema_path=DEFAULT_SCHEMA, check_files=False, release=False, dirname=True):
    sch = json.loads(Path(schema_path).read_text(encoding="utf-8"))
    results = []
    for mp in find_manifests(paths):
        try:
            doc, dups = load_json(mp)
        except (json.JSONDecodeError, UnicodeDecodeError) as e:
            r = Result(mp)
            r.e("SL-MAN-01", "$", f"not valid JSON: {e}")
            results.append(r)
            continue
        r = lint_manifest(doc, dups, sch, mp, {"release": release, "dirname": dirname})
        if check_files and isinstance(doc, dict):
            check_files_on_disk(doc, mp.parent, r)
        results.append(r)
    seen = {}
    for r in results:
        if r.id:
            if r.id in seen:
                r.e("SL-ID-01", "$.id", f"duplicate skin id '{r.id}' (also in {seen[r.id]})")
            else:
                seen[r.id] = r.path
    return results


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--schema", default=str(DEFAULT_SCHEMA))
    ap.add_argument("--check-files", action="store_true", help="files[] exist next to manifest.json, bytes + sha256 match, nothing unlisted")
    ap.add_argument("--release", action="store_true", help="pending QA sign-offs / unapproved files become errors")
    ap.add_argument("--no-dirname", action="store_true", help="do not require the directory name to equal the skin id")
    ap.add_argument("--json")
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args(argv)
    try:
        res = lint_paths(a.paths, a.schema, a.check_files, a.release, not a.no_dirname)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"skin_lint: {e}", file=sys.stderr)
        return 2
    n_err = sum(len(r.errors) for r in res)
    for r in res:
        if a.quiet and r.ok:
            continue
        print(f"{'OK  ' if r.ok else 'FAIL'} {r.id or '?':<26} {r.path}")
        for x in r.errors:
            print(f"     {x['code']:<10} {x['path']}: {x['msg']}")
        for x in r.warnings:
            print(f"     warn {x['code']:<6} {x['path']}: {x['msg']}")
    print(f"SKIN_LINT {len(res)} manifest(s), {sum(1 for r in res if r.ok)} ok, {n_err} error(s)")
    if a.json:
        Path(a.json).write_text(json.dumps([{"path": r.path, "id": r.id, "ok": r.ok, "errors": r.errors, "warnings": r.warnings}
                                            for r in res], ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return 1 if n_err else 0


if __name__ == "__main__":
    sys.exit(main())
