#!/usr/bin/env python3
"""lint_core_purity.py - CORE_PURITY lint for game/core (report + ratchet, pure Python, no Godot).

game/core must be UI-free: only RefCounted / Resource / static code, no scene-tree or presentation APIs.
The lint scans every game/core/**/*.gd (comments and string literals are ignored, so a `#` line or a quoted
"G." never trips it) and counts findings per file in six categories:

  NODE_BASE   `extends` a Node-family class (the file IS a scene node)
  NODE_API    Node/Control/CanvasItem/Tween/create_tween/create_timer/add_child/queue_free/get_tree/DisplayServer/
              Engine.get_main_loop and UI classes (Label, Button, ...)  (incl. `await get_tree()...`)
  AUDIO_FX    Sfx., V9Feel, AudioStreamPlayer
  AUTOLOAD_G  `G.`  (the legacy god-object; WP4 replaces it with an injected TWState)
  ROOT_PATH   "/root/" node paths (the path lives in a string literal, so this rule reads the raw code line)
  SHELL_DEP   a class_name defined under game/scripts (the shell) referenced from core: "shell may use core,
              never the reverse" (counted once per class per file)

A finding is one (rule, line) pair (SHELL_DEP: one (class, file) pair).

Modes
  python3 tools/lint_core_purity.py                  report (summary + per-rule counts), exit 0
  python3 tools/lint_core_purity.py --files          + per-file findings and core -> shell dependencies
  python3 tools/lint_core_purity.py --by-file        + per-file table sorted by findings
  python3 tools/lint_core_purity.py --json out.json  machine-readable report
  python3 tools/lint_core_purity.py --check          ratchet gate vs tools/lint_baseline.json: any file/rule that
                                                     exceeds its baseline count, any new violating file, or a total
                                                     above N is RED (exit 1); fewer findings is fine
  python3 tools/lint_core_purity.py --update-baseline  write the current findings as the new baseline
                                                     (refuses to raise N unless --allow-raise)
  python3 tools/lint_core_purity.py --selftest       6 synthetic files (one violation per rule) must give exactly 6
  python3 tools/lint_core_purity.py --strict         exit 1 when anything is reported (future hard gate)
  python3 tools/lint_core_purity.py --max N          exit 1 when findings exceed N

--check and --selftest print one machine-readable marker line each:
  CORE_PURITY RESULT: PASS|FAIL (N violations, baseline B, +X new)
  CORE_PURITY SELFTEST: 6/6 PASS
"""
from __future__ import annotations

import argparse
import collections
import json
import re
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CORE = REPO / "game" / "core"
SHELL = REPO / "game" / "scripts"
BASELINE = REPO / "tools" / "lint_baseline.json"

RULE_IDS = ["NODE_BASE", "NODE_API", "AUDIO_FX", "AUTOLOAD_G", "ROOT_PATH", "SHELL_DEP", "BATTLE_INT_ONLY"]

# T10 (BATTLE_ULT_SPEC Appendix R, P74): game/core/modes/battle/**/*.gd must be strictly integer-deterministic.
BATTLE_INT_ONLY_RX = re.compile(r"\b(pow|exp|log|sin|cos|randf|randfn)\b")

NODE_BASES = {
    "Node", "Node2D", "Node3D", "Control", "CanvasLayer", "CanvasItem", "SceneTree", "MainLoop", "Window",
    "Container", "BoxContainer", "VBoxContainer", "HBoxContainer", "Panel", "PanelContainer", "Label", "Button",
    "TextureRect", "ColorRect", "SubViewportContainer", "SubViewport", "AnimationPlayer", "Timer", "HTTPRequest",
}

# rules matched on code with comments AND strings blanked
CODE_RULES = [
    ("NODE_API", re.compile(
        r"\b(Node|Node2D|Node3D|Control|CanvasItem|CanvasLayer|Tween|create_tween|create_timer|add_child|queue_free|"
        r"get_tree|DisplayServer|TextureRect|ColorRect|Label|Button|Panel|PanelContainer|SubViewport)\b"
        r"|Engine\.get_main_loop")),
    ("AUDIO_FX", re.compile(r"\b(Sfx|V9Feel|AudioStreamPlayer)\b")),
    ("AUTOLOAD_G", re.compile(r"(?<![A-Za-z0-9_.])G\.")),
]
# matched on code with comments blanked but string contents kept (the path IS a string)
ROOT_RX = re.compile(r"/root/")
EXTENDS_RX = re.compile(r"^\s*extends\s+(\w+)")
CLASS_RX = re.compile(r"(?m)^class_name\s+(\w+)")
IDENT_RX = re.compile(r"\b[A-Z][A-Za-z0-9_]*\b")


def split_line(line: str) -> tuple[str, str]:
    """One pass over a line: returns (no_comment, blanked). no_comment keeps string contents, blanked replaces
    them by "" ; both drop everything after an unquoted `#`."""
    keep, blank = [], []
    q = ""
    i, n = 0, len(line)
    while i < n:
        c = line[i]
        if q:
            if c == "\\" and i + 1 < n:
                keep.append(line[i:i + 2])
                i += 2
                continue
            keep.append(c)
            if c == q:
                q = ""
                blank.append(c)
            i += 1
            continue
        if c == "#":
            break
        if c in "\"'":
            q = c
        blank.append(c)
        keep.append(c)
        i += 1
    return "".join(keep), "".join(blank)


def is_battle_core_path(rel_path: str) -> bool:
    norm = rel_path.replace("\\", "/")
    return norm.startswith("game/core/modes/battle/") or "/modes/battle/" in norm


def analyze(text: str, shell_classes: set[str] | frozenset[str] = frozenset(), rel_path: str = "") -> dict:
    """Pure function: GDScript source -> {"rules": {rule: count}, "lines": {rule: [lineno,...]}, "deps": [...]}."""
    rules: dict[str, int] = collections.Counter()
    lines: dict[str, list[int]] = collections.defaultdict(list)
    ident_pool: set[str] = set()
    battle_int_check = is_battle_core_path(rel_path)
    in_triple = False
    for no, raw in enumerate(text.split("\n"), 1):
        # triple-quoted strings (docstrings / multi-line texts) are string content: skip their lines
        if raw.count('"""') % 2 == 1:
            in_triple = not in_triple
            continue
        if in_triple:
            continue
        keep, blank = split_line(raw)
        if not blank.strip():
            continue
        m = EXTENDS_RX.match(blank)
        if m:
            if m.group(1) in NODE_BASES:
                rules["NODE_BASE"] += 1
                lines["NODE_BASE"].append(no)
            continue  # the extends line is not scanned for NODE_API: it would double-count the same fact
        for rid, rx in CODE_RULES:
            if rx.search(blank):
                rules[rid] += 1
                lines[rid].append(no)
        if battle_int_check and BATTLE_INT_ONLY_RX.search(blank):
            rules["BATTLE_INT_ONLY"] += 1
            lines["BATTLE_INT_ONLY"].append(no)
        if ROOT_RX.search(keep):
            rules["ROOT_PATH"] += 1
            lines["ROOT_PATH"].append(no)
        ident_pool.update(IDENT_RX.findall(blank))
    deps = sorted(c for c in ident_pool if c in shell_classes)
    if deps:
        rules["SHELL_DEP"] = len(deps)
    return {"rules": dict(rules), "lines": {k: v for k, v in lines.items()}, "deps": deps}


def class_names(root: Path) -> dict[str, str]:
    out = {}
    for p in root.rglob("*.gd"):
        m = CLASS_RX.search(p.read_text(encoding="utf-8", errors="replace"))
        if m:
            out[m.group(1)] = p.relative_to(REPO).as_posix()
    return out


def scan(core: Path = CORE, shell: Path = SHELL) -> dict:
    shell_cls = set(class_names(shell)) if shell.is_dir() else set()
    files = sorted(core.rglob("*.gd"))
    findings: dict[str, dict[str, int]] = {}
    lines: dict[str, dict[str, list[int]]] = {}
    deps: dict[str, list[str]] = {}
    for p in files:
        rel = p.relative_to(REPO).as_posix() if REPO in p.parents else p.as_posix()
        a = analyze(p.read_text(encoding="utf-8", errors="replace"), shell_cls, rel_path=rel)
        if a["rules"]:
            findings[rel] = a["rules"]
            lines[rel] = a["lines"]
        if a["deps"]:
            deps[rel] = a["deps"]
    totals = collections.Counter()
    for f in findings.values():
        for k, v in f.items():
            totals[k] += v
    return {"files": len(files), "findings": findings, "lines": lines, "totals": dict(totals),
            "total": sum(totals.values()), "shell_deps": deps}


# ------------------------------------------------------------------------------------------------ baseline ratchet
def load_baseline(path: Path = BASELINE) -> dict | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def baseline_doc(rep: dict) -> dict:
    return {"version": 1, "N": rep["total"], "by_rule": {r: rep["totals"].get(r, 0) for r in RULE_IDS},
            "core_files": rep["files"], "files": {k: v for k, v in sorted(rep["findings"].items())},
            "note": "CORE_PURITY ratchet: counts may only go down. Regenerate with "
                    "`python3 tools/lint_core_purity.py --update-baseline` after burning violations down."}


def compare(rep: dict, base: dict) -> tuple[list[str], list[str]]:
    """-> (new_violations, improvements). A violation is new when a file/rule count exceeds its baseline."""
    new, better = [], []
    bf = base.get("files", {})
    for rel, f in sorted(rep["findings"].items()):
        for rid, n in sorted(f.items()):
            was = bf.get(rel, {}).get(rid, 0)
            if n > was:
                where = ""
                ls = rep["lines"].get(rel, {}).get(rid)
                if ls:
                    where = f" (line {', '.join(map(str, ls[:5]))})"
                new.append(f"{rel}: {rid} {was} -> {n}{where}")
    for rel, f in sorted(bf.items()):
        for rid, was in sorted(f.items()):
            n = rep["findings"].get(rel, {}).get(rid, 0)
            if n < was:
                better.append(f"{rel}: {rid} {was} -> {n}")
    return new, better


# ------------------------------------------------------------------------------------------------ selftest
SYNTH = {
    "node_base.gd": ("extends Node2D\n", "NODE_BASE"),
    "node_api.gd": ("extends RefCounted\nfunc f(t):\n\tvar tw = t.create_tween()\n", "NODE_API"),
    "audio_fx.gd": ("extends RefCounted\nfunc f():\n\tSfx.play(\"tap\")\n", "AUDIO_FX"),
    "autoload_g.gd": ("extends RefCounted\nfunc f():\n\treturn G.coins\n", "AUTOLOAD_G"),
    "root_path.gd": ("extends RefCounted\nfunc f(t):\n\treturn t.get_node(\"/root/Main\")\n", "ROOT_PATH"),
    "shell_dep.gd": ("extends RefCounted\nfunc f():\n\treturn ShellScreen.new()\n", "SHELL_DEP"),
}
SYNTH_BATTLE = {
    "battle_pow.gd": ("extends RefCounted\nfunc f(x):\n\treturn pow(x, 1.5)\n", "BATTLE_INT_ONLY"),
    "battle_exp.gd": ("extends RefCounted\nfunc f(x):\n\treturn exp(x)\n", "BATTLE_INT_ONLY"),
    "battle_log.gd": ("extends RefCounted\nfunc f(x):\n\treturn log(x)\n", "BATTLE_INT_ONLY"),
    "battle_sin.gd": ("extends RefCounted\nfunc f(x):\n\treturn sin(x)\n", "BATTLE_INT_ONLY"),
    "battle_cos.gd": ("extends RefCounted\nfunc f(x):\n\treturn cos(x)\n", "BATTLE_INT_ONLY"),
    "battle_randf.gd": ("extends RefCounted\nfunc f():\n\treturn randf()\n", "BATTLE_INT_ONLY"),
    "battle_randfn.gd": ("extends RefCounted\nfunc f():\n\treturn randfn(0.0, 1.0)\n", "BATTLE_INT_ONLY"),
}
# clean look-alikes that MUST NOT fire (comments, strings, member access, identifiers containing the tokens)
SYNTH_CLEAN = (
    "extends RefCounted\n"
    "class_name SynthClean\n"
    "# Node Control Tween G.coins /root/Main Sfx.play get_tree() ShellScreen pow exp log sin cos randf randfn\n"
    "var a := \"G. is a string, Node too, Sfx.x, pow(1,2) randf()\"  # trailing Node comment\n"
    "var b := 1  # G.x\n"
    "var color := \"#ff00ff\"\n"
    "func f(player, NodeCount, Ring, power_val, catalog, cosine):\n"
    "\tvar g = player.G.x\n"
    "\tvar my_G = 1\n"
    "\treturn NodeCount + Ring + power_val + catalog + cosine\n"
    "\"\"\"\ndocstring with Node and G.coins and get_tree() and pow() and randf()\n\"\"\"\n"
)


def selftest() -> int:
    import tempfile
    shell_cls = {"ShellScreen"}
    total_cases = len(SYNTH) + len(SYNTH_BATTLE)
    with tempfile.TemporaryDirectory(prefix="core_purity_selftest_") as td:
        d = Path(td)
        for name, (src, _) in SYNTH.items():
            (d / name).write_text(src, encoding="utf-8")
        (d / "clean.gd").write_text(SYNTH_CLEAN, encoding="utf-8")
        # Non-battle core file using pow() must NOT trip BATTLE_INT_ONLY
        (d / "non_battle_pow.gd").write_text("extends RefCounted\nfunc f(x):\n\treturn pow(x, 2)\n", encoding="utf-8")
        bdir = d / "game" / "core" / "modes" / "battle"
        bdir.mkdir(parents=True, exist_ok=True)
        for name, (src, _) in SYNTH_BATTLE.items():
            (bdir / name).write_text(src, encoding="utf-8")
        (bdir / "battle_clean.gd").write_text(SYNTH_CLEAN, encoding="utf-8")

        total, ok, bad = 0, 0, []
        for p in sorted(d.glob("*.gd")):
            a = analyze(p.read_text(encoding="utf-8"), shell_cls, rel_path=p.name)
            n = sum(a["rules"].values())
            total += n
            if p.name in ("clean.gd", "non_battle_pow.gd"):
                if n:
                    bad.append(f"{p.name} false positives: {a['rules']}")
                continue
            want = SYNTH[p.name][1]
            if a["rules"] == {want: 1}:
                ok += 1
            else:
                bad.append(f"{p.name}: want {{{want}: 1}} got {a['rules']}")
        for p in sorted(bdir.glob("*.gd")):
            rel = p.relative_to(d).as_posix()
            a = analyze(p.read_text(encoding="utf-8"), shell_cls, rel_path=rel)
            n = sum(a["rules"].values())
            total += n
            if p.name == "battle_clean.gd":
                if n:
                    bad.append(f"{rel} false positives: {a['rules']}")
                continue
            want = SYNTH_BATTLE[p.name][1]
            if a["rules"] == {want: 1}:
                ok += 1
            else:
                bad.append(f"{rel}: want {{{want}: 1}} got {a['rules']}")
    for b in bad:
        print("SELFTEST FAIL:", b)
    good = ok == total_cases and total == total_cases and not bad
    print(f"CORE_PURITY SELFTEST: {ok}/{total_cases} {'PASS' if good else 'FAIL'} ({total} findings in "
          f"{total_cases} synthetic files + 3 clean look-alike files)")
    return 0 if good else 1


# ------------------------------------------------------------------------------------------------ main
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--files", action="store_true", help="print per-file findings and core -> shell dependencies")
    ap.add_argument("--by-file", action="store_true", help="print a per-file table sorted by findings")
    ap.add_argument("--json", metavar="FILE", help="write findings as JSON")
    ap.add_argument("--check", action="store_true", help="ratchet gate vs tools/lint_baseline.json (exit 1 on growth)")
    ap.add_argument("--update-baseline", action="store_true", help="write current findings as the baseline")
    ap.add_argument("--allow-raise", action="store_true", help="let --update-baseline raise N (needs a reason)")
    ap.add_argument("--selftest", action="store_true", help="6 synthetic files must give exactly 6 findings")
    ap.add_argument("--strict", action="store_true", help="exit 1 if anything is reported")
    ap.add_argument("--max", type=int, default=None, help="exit 1 if the finding count exceeds N")
    ap.add_argument("--baseline", default=str(BASELINE), help="baseline file (default tools/lint_baseline.json)")
    a = ap.parse_args()

    rc = 0
    if a.selftest:
        rc = selftest()
        if not (a.check or a.update_baseline or a.files or a.by_file or a.json or a.strict or a.max is not None):
            return rc
    if not CORE.is_dir():
        print("CORE_PURITY: game/core does not exist", file=sys.stderr)
        return 2
    t0 = time.time()
    rep = scan()
    secs = time.time() - t0
    findings, totals = rep["findings"], rep["totals"]
    print(f"CORE_PURITY: {rep['files']} core files, {rep['files'] - len(findings)} clean, "
          f"{len(findings)} with findings, {rep['total']} findings total ({secs:.2f}s)")
    for rid in RULE_IDS:
        nf = sum(1 for f in findings.values() if rid in f)
        print(f"  {rid:<11} {nf:>4} files  {totals.get(rid, 0):>6} hits")
    if a.by_file:
        print("per-file findings (most first):")
        for rel, f in sorted(findings.items(), key=lambda kv: (-sum(kv[1].values()), kv[0])):
            print(f"  {sum(f.values()):>4}  {rel}: " + ", ".join(f"{k}={v}" for k, v in sorted(f.items())))
    if a.files:
        for rel, f in sorted(findings.items()):
            print(f"  {rel}: " + ", ".join(f"{k}={v}" for k, v in sorted(f.items())))
        if rep["shell_deps"]:
            print("core -> shell class dependencies:")
            for rel, d in sorted(rep["shell_deps"].items()):
                print(f"  {rel} -> {', '.join(d)}")
    if a.json:
        Path(a.json).write_text(json.dumps({k: rep[k] for k in ("files", "findings", "lines", "totals", "total",
                                                                  "shell_deps")}, indent=1, sort_keys=True),
                                encoding="utf-8")
    bpath = Path(a.baseline)
    if a.update_baseline:
        old = load_baseline(bpath)
        if old and rep["total"] > old["N"] and not a.allow_raise:
            print(f"REFUSED: baseline N would rise {old['N']} -> {rep['total']} (the ratchet only goes down; "
                  f"--allow-raise to override)")
            return 1
        bpath.write_text(json.dumps(baseline_doc(rep), indent=1, sort_keys=False) + "\n", encoding="utf-8")
        print(f"baseline written: {bpath} (N={rep['total']})")
        return rc
    if a.check:
        base = load_baseline(bpath)
        if base is None:
            print(f"CORE_PURITY RESULT: FAIL ({rep['total']} violations, no baseline file {bpath.name})")
            return 1
        new, better = compare(rep, base)
        over = rep["total"] > base["N"]
        for line in new:
            print("NEW VIOLATION:", line)
        if better:
            print(f"{len(better)} file/rule count(s) went down; run --update-baseline to ratchet N from "
                  f"{base['N']} to {rep['total']}")
        ok = not new and not over
        print(f"CORE_PURITY RESULT: {'PASS' if ok else 'FAIL'} ({rep['total']} violations, baseline {base['N']}, "
              f"+{len(new)} new)")
        return rc or (0 if ok else 1)
    total = rep["total"]
    if (a.strict and total) or (a.max is not None and total > a.max):
        return 1
    return rc


if __name__ == "__main__":
    sys.exit(main())
