#!/usr/bin/env python3
"""lint_core_purity.py - CORE_PURITY lint for game/core (REPORT-ONLY in WP3).

game/core must be UI-free: only RefCounted / Resource / static code, no scene-tree or presentation APIs.
The lint greps every game/core/**/*.gd (comments and string literals stripped) for forbidden tokens and for
`extends` of a Node-family class, and additionally lists core -> shell class dependencies (a core file that names a
class_name defined under game/scripts, i.e. the shell) so the one-way rule "shell may use core, never the reverse"
can be burned down in later work packages.

  python3 tools/lint_core_purity.py                 # summary + per-token counts, exit 0 (report-only)
  python3 tools/lint_core_purity.py --files         # per-file findings
  python3 tools/lint_core_purity.py --json out.json # machine-readable
  python3 tools/lint_core_purity.py --strict        # exit 1 when anything is reported (future CI gate)
  python3 tools/lint_core_purity.py --max N         # exit 1 when findings exceed N (ratchet)

Rules (id -> pattern):
  NODE_BASE      `extends` Node / Node2D / Node3D / Control / CanvasLayer / CanvasItem / ... (the file IS a scene node)
  NODE_API       Node, Control, CanvasItem, Tween/create_tween, add_child, queue_free, get_tree, DisplayServer, Engine.get_main_loop
  AWAIT_TREE     `await` on get_tree()/create_timer
  AUDIO_FX       Sfx., V9Feel, AudioStreamPlayer
  AUTOLOAD_G     `G.`  (the legacy god-object; WP4 replaces it with injected TWState)
  ROOT_PATH      "/root/" node paths
  SHELL_DEP      class_name defined in game/scripts (shell) referenced from core
"""
from __future__ import annotations

import argparse
import collections
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CORE = REPO / "game" / "core"
SHELL = REPO / "game" / "scripts"

NODE_BASES = {
    "Node", "Node2D", "Node3D", "Control", "CanvasLayer", "CanvasItem", "SceneTree", "MainLoop", "Window",
    "Container", "BoxContainer", "VBoxContainer", "HBoxContainer", "Panel", "PanelContainer", "Label", "Button",
    "TextureRect", "ColorRect", "SubViewportContainer", "SubViewport", "AnimationPlayer", "Timer", "HTTPRequest",
}

RULES = [
    ("NODE_API", re.compile(r"\b(Node|Node2D|Node3D|Control|CanvasItem|CanvasLayer|Tween|create_tween|add_child|queue_free|get_tree|DisplayServer|TextureRect|ColorRect|Label|Button|Panel|PanelContainer|SubViewport)\b|Engine\.get_main_loop")),
    ("AWAIT_TREE", re.compile(r"\bawait\b[^\n]*\b(get_tree|create_timer)\b")),
    ("AUDIO_FX", re.compile(r"\b(Sfx|V9Feel|AudioStreamPlayer)\b")),
    ("AUTOLOAD_G", re.compile(r"(?<![A-Za-z0-9_.])G\.")),
    ("ROOT_PATH", re.compile(r"/root/")),
]


def strip_comments(text: str) -> str:
    return re.sub(r"(?m)#[^\n]*", "", text)


def strip_strings(text: str) -> str:
    text = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', text)
    return re.sub(r"'(?:\\.|[^'\\\n])*'", "''", text)


def class_names(root: Path) -> dict[str, str]:
    out = {}
    for p in root.rglob("*.gd"):
        m = re.search(r"(?m)^class_name\s+(\w+)", p.read_text(encoding="utf-8", errors="replace"))
        if m:
            out[m.group(1)] = p.relative_to(REPO).as_posix()
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--files", action="store_true", help="print per-file findings")
    ap.add_argument("--json", metavar="FILE", help="write findings as JSON")
    ap.add_argument("--strict", action="store_true", help="exit 1 if anything is reported")
    ap.add_argument("--max", type=int, default=None, help="exit 1 if the finding count exceeds N")
    a = ap.parse_args()

    if not CORE.is_dir():
        print("CORE_PURITY: game/core does not exist", file=sys.stderr)
        return 2
    shell_cls = class_names(SHELL)
    findings: dict[str, dict[str, int]] = {}
    shell_deps: dict[str, set[str]] = {}
    files = sorted(CORE.rglob("*.gd"))
    for p in files:
        rel = p.relative_to(REPO).as_posix()
        raw = p.read_text(encoding="utf-8", errors="replace")
        code = strip_strings(strip_comments(raw))
        f: dict[str, int] = {}
        m = re.search(r"(?m)^extends\s+(\w+)", code)
        if m and m.group(1) in NODE_BASES:
            f["NODE_BASE"] = 1
        for rid, rx in RULES:
            n = len(rx.findall(code))
            if n:
                f[rid] = n
        deps = {c for c in set(re.findall(r"\b[A-Z][A-Za-z0-9_]*\b", code)) if c in shell_cls}
        if deps:
            f["SHELL_DEP"] = len(deps)
            shell_deps[rel] = deps
        if f:
            findings[rel] = f

    totals = collections.Counter()
    for f in findings.values():
        for k, v in f.items():
            totals[k] += v
    clean = len(files) - len(findings)
    print(f"CORE_PURITY (report-only): {len(files)} core files, {clean} clean, {len(findings)} with findings")
    for rid in ["NODE_BASE", "NODE_API", "AWAIT_TREE", "AUDIO_FX", "AUTOLOAD_G", "ROOT_PATH", "SHELL_DEP"]:
        nf = sum(1 for f in findings.values() if rid in f)
        print(f"  {rid:<11} {nf:>4} files  {totals.get(rid, 0):>6} hits")
    if a.files:
        for rel, f in sorted(findings.items()):
            print(f"  {rel}: " + ", ".join(f"{k}={v}" for k, v in sorted(f.items())))
        if shell_deps:
            print("core -> shell class dependencies:")
            for rel, d in sorted(shell_deps.items()):
                print(f"  {rel} -> {', '.join(sorted(d))}")
    if a.json:
        Path(a.json).write_text(json.dumps({"files": len(files), "findings": findings, "totals": totals,
                                            "shell_deps": {k: sorted(v) for k, v in shell_deps.items()}},
                                           indent=1, sort_keys=True), encoding="utf-8")
    total = sum(totals.values())
    if a.strict and total:
        return 1
    if a.max is not None and total > a.max:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
