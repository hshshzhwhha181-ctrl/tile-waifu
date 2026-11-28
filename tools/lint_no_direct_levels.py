#!/usr/bin/env python3
"""lint_no_direct_levels.py - the Path table is read through TWLevels.at(n) only (P19).

`G.LEVELS[i]` returns a light stub (generic 6x8 rect board) for every arc that was not materialised yet; that is
how trial mode played levels 499/699/799/899/999 as empty rectangles. The only place allowed to index the store is
game/core/levels/tw_levels.gd. Forbidden everywhere else under game/ (comments and string literals are ignored):

  INDEX   `G.LEVELS[`, `gg.LEVELS[`, `g.LEVELS[` or a bare `LEVELS[` that is not a qualified constant (V10VipDate.LEVELS)
  ALIAS   `= G.LEVELS` / `= gg.LEVELS` (an alias array gets indexed behind the lint's back); `.size()` / iteration are fine

  python3 tools/lint_no_direct_levels.py            report + exit 1 on any finding
  python3 tools/lint_no_direct_levels.py --selftest  synthetic cases, must give exactly the expected findings
Prints one marker line:  NO_DIRECT_LEVELS RESULT: PASS|FAIL (N violations)   /   NO_DIRECT_LEVELS SELFTEST: k/k PASS
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GAME = REPO / "game"
# vip_date.gd: its own unrelated `const LEVELS` (VIP dates)
ALLOWED = {"game/core/levels/tw_levels.gd", "game/core/salon/vip_date.gd"}

INDEX = re.compile(r"(?:\b(?:G|gg|g)\.LEVELS|(?<![\w.])LEVELS)\s*\[")
ALIAS = re.compile(r"=\s*(?:G|gg|g)\.LEVELS\s*$")


def strip(line: str) -> str:
    """drop string literals and the trailing # comment"""
    out, q, i = [], "", 0
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\":
                i += 2
                continue
            if c == q:
                q = ""
        elif c in "\"'":
            q = c
        elif c == "#":
            break
        else:
            out.append(c)
        i += 1
    return "".join(out).rstrip()


def scan_text(text: str) -> list[tuple[int, str, str]]:
    res = []
    for n, raw in enumerate(text.splitlines(), 1):
        code = strip(raw)
        if INDEX.search(code):
            res.append((n, "INDEX", raw.strip()))
        if ALIAS.search(code):
            res.append((n, "ALIAS", raw.strip()))
    return res


def scan() -> list[tuple[str, int, str, str]]:
    out = []
    for f in sorted(GAME.rglob("*.gd")):
        rel = f.relative_to(REPO).as_posix()
        if rel in ALLOWED:
            continue
        for n, rule, line in scan_text(f.read_text(encoding="utf-8", errors="replace")):
            out.append((rel, n, rule, line))
    return out


def selftest() -> int:
    cases = [
        ("var a = G.LEVELS[3]", 1), ("var a = gg.LEVELS[i].duplicate(true)", 1), ("x = LEVELS[i]", 1),
        ("var L: Array = G.LEVELS", 1), ("var d = V10VipDate.LEVELS[i]", 0), ("# G.LEVELS[0] in a comment", 0),
        ('print("G.LEVELS[0]")', 0), ("for i in G.LEVELS.size():", 0), ("var n = (G.LEVELS as Array).size()", 0),
        ("var lv = TWLevels.at(i)", 0),
    ]
    ok = 0
    for text, want in cases:
        got = len(scan_text(text))
        if got == want:
            ok += 1
        else:
            print("NO_DIRECT_LEVELS selftest mismatch: %r want %d got %d" % (text, want, got))
    print("NO_DIRECT_LEVELS SELFTEST: %d/%d %s" % (ok, len(cases), "PASS" if ok == len(cases) else "FAIL"))
    return 0 if ok == len(cases) else 1


def main() -> int:
    rc = 0
    if "--selftest" in sys.argv:
        rc = selftest()
        if "--check" not in sys.argv:
            return rc
    found = scan()
    for rel, n, rule, line in found:
        print("%s:%d: %s: %s" % (rel, n, rule, line))
    print("NO_DIRECT_LEVELS RESULT: %s (%d violations)" % ("PASS" if not found else "FAIL", len(found)))
    return 1 if (found or rc) else 0


if __name__ == "__main__":
    sys.exit(main())
