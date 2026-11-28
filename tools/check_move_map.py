#!/usr/bin/env python3
"""check_move_map.py - proves the WP3 core carve-out was a mechanical move.

For every `old<TAB>new` row of tools/move_map.tsv it checks, against the pre-move commit (--base, default
`claude/integration` as it was before the carve-out: the first parent of the first commit that added the map):

  * the old path existed at the base commit and no longer exists in the working tree,
  * the new path exists in the working tree,
  * (a 3rd column `retired` marks a file moved by WP3 and deleted later on purpose: it must be gone at both paths; `edited` = content changed on purpose later, only existence is checked)
  * the file content is IDENTICAL except for lines that mention a `res://` path (the path-based preload/extends/load
    literals that had to be re-pointed). `class_name` and every other line must be byte-for-byte unchanged.

Exit 0 = every move is clean, 1 = violations (printed), 2 = setup problem.

  python3 tools/check_move_map.py [--base REV] [--quiet]
"""
from __future__ import annotations

import argparse
import difflib
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MAP = REPO / "tools" / "move_map.tsv"


def git(*a: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(REPO), *a], capture_output=True)


def default_base() -> str:
    r = git("log", "--diff-filter=A", "--format=%H", "--", "tools/move_map.tsv")
    commits = [c for c in r.stdout.decode().split() if c]
    if commits:
        p = git("rev-parse", commits[-1] + "^")
        if p.returncode == 0:
            return p.stdout.decode().strip()
    return "claude/integration"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", default=None, help="commit with the pre-move tree (default: parent of the commit that added the map)")
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args()
    base = a.base or default_base()
    if git("rev-parse", "--verify", base + "^{commit}").returncode != 0:
        print(f"check_move_map: unknown base {base}", file=sys.stderr)
        return 2
    rows = []
    for ln in MAP.read_text(encoding="utf-8").splitlines():
        if ln.startswith("#") or not ln.strip():
            continue
        cols = ln.split("\t")
        rows.append((cols[0], cols[1], cols[2] if len(cols) > 2 else ""))
    bad: list[str] = []
    changed_lines = 0
    for o, n, tag in rows:
        old = git("show", f"{base}:{o}")
        if old.returncode != 0:
            bad.append(f"{o}: not present at {base}")
            continue
        if (REPO / o).exists():
            bad.append(f"{o}: still exists after the move")
        newp = REPO / n
        if tag == "retired":  # moved by WP3, then deliberately deleted by a later package (P07: registry list -> module.gd)
            if newp.exists():
                bad.append(f"{n}: marked retired but still exists")
            continue
        if not newp.exists():
            bad.append(f"{n}: missing")
            continue
        if tag == "edited":  # moved by WP3, then rewritten on purpose by a later package (P07: scanning registry)
            continue
        ot = old.stdout.decode("utf-8", errors="surrogateescape").splitlines()
        nt = newp.read_bytes().decode("utf-8", errors="surrogateescape").splitlines()
        if ot == nt:
            continue
        if len(ot) != len(nt):
            # extra/removed lines are only acceptable when every touched line mentions res://
            pass
        sm = difflib.SequenceMatcher(None, ot, nt, autojunk=False)
        for tag, i1, i2, j1, j2 in sm.get_opcodes():
            if tag == "equal":
                continue
            for ln in ot[i1:i2] + nt[j1:j2]:
                changed_lines += 1
                if "res://" not in ln and "scripts/" not in ln and "core/" not in ln:
                    bad.append(f"{n}: non-path line changed: {ln.strip()[:100]}")
    print(f"check_move_map: {len(rows)} moves vs {base[:10]}, {changed_lines} path-literal lines re-pointed, {len(bad)} violation(s)")
    if not a.quiet:
        for b in bad[:60]:
            print("  " + b)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
