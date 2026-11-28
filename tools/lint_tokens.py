#!/usr/bin/env python3
"""lint_tokens.py - design-token lints (P27 / WP9a): NO_RAW_HEX, NO_RAW_FONT_SIZE, TYPE_SCALE_MAX_4, HIT_TARGET_MIN.

Scope (decision ARCH WP9): ENFORCING on game/shell/** (0 violations allowed), REPORT-ONLY (ratchet) on all legacy
GDScript under game/. Generated game/shell/design/tw_tokens.gd is the only .gd allowed to hold hex literals.

  python3 tools/lint_tokens.py                    # summary; exit 1 on shell violation / token error / ratchet breach
  python3 tools/lint_tokens.py --files            # per-file legacy findings (top 40)
  python3 tools/lint_tokens.py --json out.json    # machine readable
  python3 tools/lint_tokens.py --update-baseline  # re-fix the legacy counts in tools/lint_tokens_baseline.json
  python3 tools/lint_tokens.py --selftest         # run the lint on built-in positive/negative samples

Rules
  NO_RAW_HEX        colour literal outside tokens: "#rrggbb[aa]" in a string, Color8(), Color.html(), Color.from_string()
                    (reported as NO_RAW_HEX); Color(<number>, ...) is reported as NO_RAW_COLOR_CTOR (legacy) and is part of
                    NO_RAW_HEX in shell (pure white/black with alpha, Color(1,1,1,a) / Color(0,0,0,a), is allowed)
  NO_RAW_FONT_SIZE  add_theme_font_size_override("font_size", <numeric literal>) / font_size = <numeric literal>
  TYPE_SCALE_MAX_4  a file uses > 4 distinct font sizes (literals or TWTokens.TYPE_*)  [per-screen budget]; additionally the
                    token scale itself must be exactly 64/44/34/30/26 (+36 subtitle) and the TWTokens consts must match tokens.json
  HIT_TARGET_MIN    tokens.json hit.HIT_TARGET_MIN == 96, HIT_TARGET_BIG == 112; shell code must not use V10DS.HIT_MIN (80) or
                    a numeric size < 96 in a custom_minimum_size of a *button* line
Also checks V10DS parity: every colour / hero / alpha / motion token of game/scripts/v10/hud2/tokens.gd is present in
tokens.json with the identical value (100 %).
"""
from __future__ import annotations

import argparse
import collections
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GAME = REPO / "game"
SHELL = GAME / "shell"
TOKENS_JSON = SHELL / "design" / "tokens.json"
TW_TOKENS_GD = SHELL / "design" / "tw_tokens.gd"
V10DS_GD = GAME / "scripts" / "v10" / "hud2" / "tokens.gd"
BASELINE = REPO / "tools" / "lint_tokens_baseline.json"
GENERATED = {TW_TOKENS_GD.resolve()}

HEX_IN_STR = re.compile(r"(?<![\w&#])#(?:[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?)(?![\w])")
HEX_SHORT = re.compile(r"[\"']#(?:[0-9A-Fa-f]{3,4})[\"']")
COLOR_FN = re.compile(r"\bColor8\s*\(|\bColor\.html\s*\(|\bColor\.from_string\s*\(")
COLOR_NUM = re.compile(r"\bColor\(\s*(-?[0-9.]+)\s*,\s*(-?[0-9.]+)\s*,\s*(-?[0-9.]+)\s*(?:,\s*([^)]*))?\)")
FS_OVERRIDE = re.compile(r"add_theme_font_size_override\s*\(\s*[\"']font_size[\"']\s*,\s*([^)]*)\)")
FS_ASSIGN = re.compile(r"(?<![\w.])(?:[\w.]*\.)?font_size\s*=\s*([^\n=]+)")
FS_DICT = re.compile(r"[\"']font_size[\"']\s*:\s*(\d+)")
NUM_ONLY = re.compile(r"^[\s0-9.+\-*/()]+$")
TOKEN_FS = re.compile(r"TWTokens\.TYPE_(DISPLAY|H1|H2|BODY|CAPTION|SUBTITLE)")
MINSIZE = re.compile(r"custom_minimum_size\s*=\s*Vector2\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\)")


def strip_comment(line: str, state: dict) -> str:
    """Return the code part of a line (comment removed), honouring "..." '...' and triple-quoted strings."""
    out: list[str] = []
    i, n = 0, len(line)
    while i < n:
        if state.get("tq"):
            j = line.find(state["tq"], i)
            if j < 0:
                out.append(line[i:])
                return "".join(out)
            out.append(line[i:j + 3])
            i = j + 3
            state["tq"] = None
            continue
        ch = line[i]
        if ch == "#":
            break
        if ch in "\"'":
            if line.startswith(ch * 3, i):
                state["tq"] = ch * 3
                out.append(ch * 3)
                i += 3
                continue
            j = i + 1
            while j < n:
                if line[j] == "\\":
                    j += 2
                    continue
                if line[j] == ch:
                    break
                j += 1
            out.append(line[i:j + 1])
            i = j + 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def scan_text(text: str) -> dict:
    """Findings for one .gd source: {'hex': [(line, snippet)], 'font': [...], 'sizes': set, 'hit': [...]}"""
    hex_f, ctor_f, font_f, hit_f = [], [], [], []
    sizes: set = set()
    state: dict = {}
    for no, raw in enumerate(text.splitlines(), 1):
        code = strip_comment(raw, state)
        if not code.strip():
            continue
        found = False
        for m in HEX_IN_STR.finditer(code):
            hex_f.append((no, m.group(0)))
            found = True
        fn_hits = list(COLOR_FN.finditer(code))
        for m in fn_hits:
            hex_f.append((no, m.group(0)))
        if not found and not fn_hits:
            for m in HEX_SHORT.finditer(code):
                hex_f.append((no, m.group(0)))
        for m in COLOR_NUM.finditer(code):
            r, g, b = m.group(1), m.group(2), m.group(3)
            try:
                fr, fg, fb = float(r), float(g), float(b)
            except ValueError:
                continue
            if (fr, fg, fb) in ((1.0, 1.0, 1.0), (0.0, 0.0, 0.0)):
                continue  # neutral white/black with alpha is not a palette colour
            ctor_f.append((no, m.group(0)))
        arg_exprs: list[str] = []
        for m in FS_OVERRIDE.finditer(code):
            arg_exprs.append(m.group(1).strip())
        for m in FS_ASSIGN.finditer(code):
            arg_exprs.append(m.group(1).strip())
        for m in FS_DICT.finditer(code):
            arg_exprs.append(m.group(1).strip())
        for e in arg_exprs:
            e = e.rstrip(",")
            if NUM_ONLY.match(e) and re.search(r"\d", e):
                font_f.append((no, e))
                try:
                    sizes.add(int(float(eval(e, {"__builtins__": {}}, {}))))  # numerals/operators only (NUM_ONLY)
                except Exception:
                    sizes.add(e)
        for m in TOKEN_FS.finditer(code):
            sizes.add("TYPE_" + m.group(1))
        if "V10DS.HIT_MIN" in code or "LEGACY_HIT_MIN" in code:
            hit_f.append((no, "uses 80 px legacy hit min"))
        if re.search(r"btn|button|Button", code):
            for m in MINSIZE.finditer(code):
                if float(m.group(1)) < 96 or float(m.group(2)) < 96:
                    hit_f.append((no, m.group(0)))
    return {"hex": hex_f, "ctor": ctor_f, "font": font_f, "sizes": sizes, "hit": hit_f}


def gd_files() -> list[Path]:
    return sorted(p for p in GAME.rglob("*.gd") if ".godot" not in p.parts)


def lint_repo() -> dict:
    res = {"shell": collections.defaultdict(list), "legacy": collections.Counter(), "legacy_files": {}, "files": 0}
    legacy_hex = legacy_font = legacy_hit = legacy_scale = 0
    sub_numeric = 0
    for p in gd_files():
        if p.resolve() in GENERATED:
            continue
        rel = p.relative_to(REPO).as_posix()
        try:
            text = p.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            text = p.read_text(encoding="utf-8", errors="replace")
        r = scan_text(text)
        res["files"] += 1
        in_shell = SHELL in p.parents
        too_many = len(r["sizes"]) > 4
        if in_shell:
            for no, s in r["hex"] + r["ctor"]:
                res["shell"]["NO_RAW_HEX"].append(f"{rel}:{no}: {s}")
            for no, s in r["font"]:
                res["shell"]["NO_RAW_FONT_SIZE"].append(f"{rel}:{no}: font size {s}")
            if too_many:
                res["shell"]["TYPE_SCALE_MAX_4"].append(f"{rel}: {len(r['sizes'])} distinct font sizes {sorted(map(str, r['sizes']))}")
            for no, s in r["hit"]:
                res["shell"]["HIT_TARGET_MIN"].append(f"{rel}:{no}: {s}")
        else:
            legacy_hex += len(r["hex"])
            legacy_font += len(r["font"])
            legacy_hit += len(r["hit"])
            legacy_scale += 1 if too_many else 0
            sub_numeric += len(r["ctor"])
            if r["hex"] or r["font"] or r["ctor"]:
                res["legacy_files"][rel] = len(r["hex"]) + len(r["font"]) + len(r["ctor"])
    res["legacy"].update({"NO_RAW_HEX": legacy_hex, "NO_RAW_COLOR_CTOR": sub_numeric,
                          "NO_RAW_FONT_SIZE": legacy_font, "TYPE_SCALE_MAX_4_files": legacy_scale,
                          "HIT_TARGET_MIN": legacy_hit})
    return res


# ------------------------------------------------------------------ token-level checks
def parse_v10ds(text: str) -> dict:
    colors = {k: v.upper() for k, v in re.findall(r'const (\w+): = Color\("(#[0-9A-Fa-f]{6})"\)', text)}
    heroes = {}
    for m in re.finditer(r'"(\w+)": \{"name": "([^"]+)", "accent": Color\("(#\w+)"\), "glow": Color\("(#\w+)"\), "deep": Color\("(#\w+)"\), "element": "(\w+)"\}', text):
        heroes[m.group(1)] = {"name": m.group(2), "accent": m.group(3).upper(), "glow": m.group(4).upper(),
                              "deep": m.group(5).upper(), "element": m.group(6)}
    nums = {k: float(v) for k, v in re.findall(r"const ([A-Z_]+): = (-?[0-9.]+)\b", text)}
    return {"colors": colors, "heroes": heroes, "nums": nums}


def check_v10ds_parity(tok: dict) -> tuple[list[str], dict]:
    errs: list[str] = []
    ds = parse_v10ds(V10DS_GD.read_text(encoding="utf-8"))
    total = same = 0
    for k, v in ds["colors"].items():
        total += 1
        if tok["color"].get(k, "").upper() == v:
            same += 1
        else:
            errs.append(f"V10DS parity: color {k} {v} != tokens.json {tok['color'].get(k)}")
    for h, d in ds["heroes"].items():
        for f in ("accent", "glow", "deep"):
            total += 1
            if tok["heroes"].get(h, {}).get(f, "").upper() == d[f]:
                same += 1
            else:
                errs.append(f"V10DS parity: hero {h}.{f}")
    num_map = {**{k: ("alpha", k) for k in tok["alpha"]}, **{k: ("motion", k) for k in tok["motion"]["dur"]}}
    for k, (sec, _) in num_map.items():
        if k in ds["nums"]:
            total += 1
            have = tok["alpha"].get(k) if sec == "alpha" else tok["motion"]["dur"].get(k)
            if have is not None and abs(float(have) - ds["nums"][k]) < 1e-9:
                same += 1
            else:
                errs.append(f"V10DS parity: {k} {ds['nums'][k]} != {have}")
    total += 1
    if int(ds["nums"].get("GRID", -1)) == tok["space"]["GRID"]:
        same += 1
    else:
        errs.append("V10DS parity: GRID")
    total += 1
    if int(ds["nums"].get("RADIUS", -1)) == tok["radius"]["R_XS"]:
        same += 1
    else:
        errs.append("V10DS parity: RADIUS vs R_XS")
    return errs, {"total": total, "same": same, "colors": len(ds["colors"]), "heroes": len(ds["heroes"])}


def check_tokens(tok: dict) -> list[str]:
    errs: list[str] = []
    sizes = sorted(tok["type"]["scale"].values(), reverse=True)
    if sizes != [64, 44, 34, 30, 26]:
        errs.append(f"TYPE_SCALE_MAX_4: token scale must be 64/44/34/30/26, got {sizes}")
    if tok["type"]["TYPE_SUBTITLE"] != 36:
        errs.append("TYPE_SCALE_MAX_4: subtitle must be 36")
    if min(sizes) < 26:
        errs.append("TYPE_SCALE_MAX_4: no text below 26 px at 720")
    if tok["hit"]["HIT_TARGET_MIN"] != 96:
        errs.append(f"HIT_TARGET_MIN must be 96, got {tok['hit']['HIT_TARGET_MIN']}")
    if tok["hit"]["HIT_TARGET_BIG"] != 112:
        errs.append(f"HIT_TARGET_BIG (Undo/Hint/Shuffle) must be 112, got {tok['hit']['HIT_TARGET_BIG']}")
    # tw_tokens.gd in sync with tokens.json (determinism gate)
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import gen_tokens  # noqa: E402
    tok_txt, gd_txt, theme_txt = gen_tokens.outputs()
    for path, want in ((TOKENS_JSON, tok_txt), (TW_TOKENS_GD, gd_txt), (SHELL / "design" / "tw_theme.tres", theme_txt)):
        if not path.exists() or path.read_bytes() != want.encode("utf-8"):
            errs.append(f"STALE: {path.relative_to(REPO).as_posix()} differs from tokens.json (run python tools/gen_tokens.py)")
    # raw hex must not appear in the tw_tokens.gd outside Color("#...") const lines (sanity)
    return errs


# ------------------------------------------------------------------ selftest
def selftest() -> int:
    ok = True

    def expect(name: str, cond: bool) -> None:
        nonlocal ok
        print(f"  {'ok  ' if cond else 'FAIL'} {name}")
        ok = ok and cond

    r = scan_text('var c = Color("#FF00AA")\nvar d = Color.WHITE # "#112233" in comment\n')
    expect("hex in string found, comment ignored", len(r["hex"]) == 1)
    r = scan_text('var c = Color(0.1, 0.2, 0.3, 1.0)\nvar w = Color(1,1,1,0.5)\nvar k = Color(0, 0, 0, 0)\n')
    expect("numeric ctor flagged, white/black allowed", len(r["ctor"]) == 1)
    r = scan_text('var c = Color8(1, 2, 3)\nvar h = Color.html("#fff")\n')
    expect("Color8 / Color.html flagged", len(r["hex"]) == 2)
    r = scan_text('l.add_theme_font_size_override("font_size", 28)\nl.add_theme_font_size_override("font_size", TWTokens.TYPE_H1)\n')
    expect("literal font size flagged, token not", len(r["font"]) == 1 and "TYPE_H1" in r["sizes"])
    r = scan_text('lb.text = "[color=#E8C47E]x[/color]"\n')
    expect("BBCode hex flagged", len(r["hex"]) == 1)
    r = scan_text('var s = """\n#123456\n"""\nvar x = 1\n')
    expect("hex inside triple-quoted string is data, still flagged", len(r["hex"]) == 1)
    r = scan_text("\n".join(f"a.add_theme_font_size_override(\"font_size\", {n})" for n in (20, 22, 24, 26, 28)))
    expect("5 distinct sizes seen", len(r["sizes"]) == 5)
    r = scan_text('b.custom_minimum_size = Vector2(80, 80) # btn\nvar btn_x := Button.new()\nbtn_x.custom_minimum_size = Vector2(80, 96)\n')
    expect("button min size < 96 flagged", len(r["hit"]) == 1)
    r = scan_text('var x = V10DS.HIT_MIN\n')
    expect("V10DS.HIT_MIN flagged", len(r["hit"]) == 1)
    print("TOKEN_LINT SELFTEST " + ("OK" if ok else "FAIL"))
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--files", action="store_true")
    ap.add_argument("--json")
    ap.add_argument("--update-baseline", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        return selftest()

    tok = json.loads(TOKENS_JSON.read_text(encoding="utf-8"))
    tok_errs = check_tokens(tok)
    par_errs, par = check_v10ds_parity(tok)
    res = lint_repo()
    shell_n = sum(len(v) for v in res["shell"].values())
    leg = dict(res["legacy"])

    base = json.loads(BASELINE.read_text(encoding="utf-8")) if BASELINE.exists() else None
    if args.update_baseline:
        BASELINE.write_text(json.dumps({"NO_RAW_HEX": leg["NO_RAW_HEX"], "NO_RAW_COLOR_CTOR": leg["NO_RAW_COLOR_CTOR"],
                                        "NO_RAW_FONT_SIZE": leg["NO_RAW_FONT_SIZE"],
                                        "TYPE_SCALE_MAX_4_files": leg["TYPE_SCALE_MAX_4_files"],
                                        "HIT_TARGET_MIN": leg["HIT_TARGET_MIN"], "mode": "report-only legacy, ratchet (count may only fall)"},
                                       indent=1, sort_keys=True) + "\n", encoding="utf-8")
        print(f"baseline written: {leg}")
        base = json.loads(BASELINE.read_text(encoding="utf-8"))
    ratchet: list[str] = []
    if base:
        for k in ("NO_RAW_HEX", "NO_RAW_COLOR_CTOR", "NO_RAW_FONT_SIZE", "TYPE_SCALE_MAX_4_files", "HIT_TARGET_MIN"):
            if leg[k] > base[k]:
                ratchet.append(f"legacy {k} rose {base[k]} -> {leg[k]}")

    print(f"files scanned: {res['files']} .gd (shell: {sum(1 for p in gd_files() if SHELL in p.parents)})")
    print(f"V10DS parity: {par['same']}/{par['total']} tokens identical ({par['colors']} colours, {par['heroes']} heroines)")
    print("legacy (report-only): " + ", ".join(f"{k}={v}" for k, v in sorted(leg.items())))
    if base:
        print("legacy baseline    : " + ", ".join(f"{k}={base[k]}" for k in ("NO_RAW_HEX", "NO_RAW_COLOR_CTOR", "NO_RAW_FONT_SIZE", "TYPE_SCALE_MAX_4_files", "HIT_TARGET_MIN")))
    print(f"shell (enforced)   : {shell_n} violations " + ", ".join(f"{k}={len(v)}" for k, v in sorted(res['shell'].items())))
    for k, v in sorted(res["shell"].items()):
        for line in v[:20]:
            print(f"  {k} {line}")
    for e in tok_errs + par_errs + ratchet:
        print("  ERROR " + e)
    if args.files:
        for f, n in sorted(res["legacy_files"].items(), key=lambda kv: -kv[1])[:40]:
            print(f"  legacy {n:4d} {f}")
    if args.json:
        Path(args.json).write_text(json.dumps({"shell": res["shell"], "legacy": leg, "parity": par,
                                                "errors": tok_errs + par_errs + ratchet}, indent=1, sort_keys=True), encoding="utf-8")
    bad = shell_n + len(tok_errs) + len(par_errs) + len(ratchet)
    print(f"TOKEN_LINT RESULT: {'OK' if bad == 0 else 'FAIL'} ({shell_n} shell violations, {len(tok_errs) + len(par_errs)} token errors, "
          f"legacy raw colour literals {leg['NO_RAW_HEX']} report-only)")
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
