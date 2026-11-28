#!/usr/bin/env python3
"""lint_no_direct_wallet.py - currency moves through TWWallet / V10Money only (P10 / WP6).

The truth of every balance is the wallet inside the save (S.econ.wallet). The top-level S.gems / S.coins / S.tickets / S.petals /
S.moon are a derived snapshot that only game/core/economy/tw_wallet.gd writes. A direct write used to be "absorbed" as a wallet
operation (V10Money._absorb); it is now undone at run time, and this lint keeps it from being written at all. Forbidden everywhere
under game/ (comments and string literals are ignored):

  FIELD   `S.gems = n`, `G.S.coins += n`, `State.S().gems -= n`, `root["gems"] = n` ... (receivers: S, G.S, g.S, gg.S, State.S(), S(),
          root, save_root(), sv; fields gems coins tickets petals moon; operators = += -= *= /=)
  DYN     `G.S[k] = ...` / `S[k] += ...` where the line (or one of the 3 lines before it) names a currency: the same write by a variable key

Allowed: the line carries `# wallet-lint: ok <reason>` (a legacy migrator that transforms a raw dictionary before any wallet exists,
a save FIXTURE that is the file content itself). Every such line is listed by --report.

  python3 tools/lint_no_direct_wallet.py             report + exit 1 on any finding
  python3 tools/lint_no_direct_wallet.py --selftest  synthetic cases, must give exactly the expected findings
  python3 tools/lint_no_direct_wallet.py --check     with --selftest: run both (what tw_test.py does)
Prints:  NO_DIRECT_WALLET RESULT: PASS|FAIL (N violations)   /   NO_DIRECT_WALLET SELFTEST: k/k PASS
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GAME = REPO / "game"
ALLOWED_FILES = {"game/core/economy/tw_wallet.gd"}      # the one writer of the snapshot

CUR = r"(?:gems|coins|tickets|petals|moon)"
RECV = r"(?:\bG\.S|\bg\.S|\bgg\.S|\bState\.S\(\)|(?<![\w.])S\(\)|(?<![\w.])S|\broot|\bsave_root\(\)|\bsv)"
OP = r"(?:\+=|-=|\*=|/=|=(?!=))"
FIELD = re.compile(RECV + r"\s*(?:\." + CUR + r"\b|\[\s*\"" + CUR + r"\"\s*\])\s*" + OP)
DYN = re.compile(r"(?:\bG\.S|\bg\.S|\bgg\.S|(?<![\w.])S|\broot)\s*\[\s*[a-z_]\w*\s*\]\s*" + OP)
CURWORD = re.compile(r"[\"']" + CUR + r"[\"']")
OK_MARK = "wallet-lint: ok"


def blank_strings(line: str) -> str:
    """replace string literals by same-length blanks (keeps columns) and cut the trailing # comment"""
    out, q, i = [], "", 0
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\":
                out.append("  ")
                i += 2
                continue
            if c == q:
                q = ""
                out.append(c)
            else:
                out.append(" ")
        elif c in "\"'":
            q = c
            out.append(c)
        elif c == "#":
            break
        else:
            out.append(c)
        i += 1
    return "".join(out)


def _in_string(raw: str, pos: int) -> bool:
    q, i = "", 0
    while i < pos:
        c = raw[i]
        if q:
            if c == "\\":
                i += 2
                continue
            if c == q:
                q = ""
        elif c in "\"'":
            q = c
        elif c == "#":
            return False
        i += 1
    return bool(q)


def scan_text(text: str) -> list[tuple[int, str, str, bool]]:
    """-> [(line, rule, source line, allowed)]"""
    res = []
    lines = text.splitlines()
    for n, raw in enumerate(lines, 1):
        s = raw.lstrip()
        if s.startswith("#"):
            continue
        allowed = OK_MARK in raw
        # the key literal stays visible for FIELD (it is a string), everything after a # is dropped
        code = raw.split("#", 1)[0] if "#" in raw and not _in_string(raw, raw.index("#")) else raw
        for m in FIELD.finditer(code):
            if not _in_string(code, m.start()):
                res.append((n, "FIELD", raw.strip(), allowed))
                break
        else:
            code2 = blank_strings(raw)
            if DYN.search(code2):
                ctx = " ".join(x.split("#", 1)[0] for x in lines[max(0, n - 4):n])
                if CURWORD.search(ctx):
                    res.append((n, "DYN", raw.strip(), allowed))
    return res


def scan() -> tuple[list, list]:
    bad, ok = [], []
    for f in sorted(GAME.rglob("*.gd")):
        rel = f.relative_to(REPO).as_posix()
        if rel in ALLOWED_FILES or "/.godot/" in rel:
            continue
        for n, rule, line, allowed in scan_text(f.read_text(encoding="utf-8", errors="replace")):
            (ok if allowed else bad).append((rel, n, rule, line))
    return bad, ok


def selftest() -> int:
    cases = [
        ("G.S.gems = 12450", 1), ("S.coins += 5", 1), ("G.S[\"gems\"] = 640", 1), ("State.S().gems = 100", 1),
        ("S().gems -= 60", 1), ("root[\"gems\"] = int(root.get(\"gems\", 0)) + 3", 1), ("g.S.tickets = 3", 1),
        ("var x = G.S.gems", 0), ("if G.S.gems == 5:", 0), ("check(int(S.gems) == 100)", 0), ("# G.S.gems = 1", 0),
        ("print(\"S.gems += 1\")", 0), ("var pat = \"G.S.gems = \"", 0), ("rw.gems = 5", 0), ("rw[\"gems\"] = 5", 0),
        ("s.gems = gems", 0), ("run.gems = int(run.gems) + 1", 0), ("V10Money.grant({\"gems\": 5}, \"x\")", 0),
        ("S.gems = 1  # wallet-lint: ok raw save fixture", 0), ("G.S.mjs = 3", 0), ("G.S.pity = 4", 0),
        ("for k in [\"gems\"]:\n\tG.S[k] = 1", 1), ("G.S[key] = v", 0), ("S[\"gems\"] = 24600", 1),
    ]
    ok = 0
    for text, want in cases:
        got = len([1 for _, _, _, allowed in scan_text(text) if not allowed])
        if got == want:
            ok += 1
        else:
            print("NO_DIRECT_WALLET selftest mismatch: %r want %d got %d" % (text, want, got))
    print("NO_DIRECT_WALLET SELFTEST: %d/%d %s" % (ok, len(cases), "PASS" if ok == len(cases) else "FAIL"))
    return 0 if ok == len(cases) else 1


def main() -> int:
    rc = 0
    if "--selftest" in sys.argv:
        rc = selftest()
        if "--check" not in sys.argv:
            return rc
    bad, ok = scan()
    for rel, n, rule, line in bad:
        print("%s:%d: %s: %s" % (rel, n, rule, line))
    if "--report" in sys.argv:
        for rel, n, rule, line in ok:
            print("allowed %s:%d: %s: %s" % (rel, n, rule, line))
    print("NO_DIRECT_WALLET RESULT: %s (%d violations, %d allowed with a reason)" % ("PASS" if not bad else "FAIL", len(bad), len(ok)))
    return 1 if (bad or rc) else 0


if __name__ == "__main__":
    sys.exit(main())
