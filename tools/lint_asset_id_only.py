#!/usr/bin/env python3
"""lint_asset_id_only.py - ASSET_ID_ONLY lint (P29 / WP9c).

Runtime assets are reached by id through TWAssets (game/shell/assets/tw_assets.gd): TWAssets.tex("bg.bg_festival"),
TWAssets.stream(id), TWAssets.video(id). A path literal into game/assets is a bypass of the approved-only gate.

Rule (static, pure Python; comments are ignored, string literals are what is looked at)
  LITERAL   a string literal that contains `res://assets/` (or a quoted `assets/<dir>/...` path) in a .gd / .tscn / .tres file

Scope
  game/shell/**  ENFORCING, 0 allowed. Exempt: game/shell/assets/ (the registry and its resolvers, they are the manifest tooling)
                 and selftests that probe the registry (game/shell/**/*_selftest.gd).
  everything else under game/ (scripts/, core/, ...)   REPORT MODE: counted per file and compared with
                 tools/lint_asset_id_baseline.json as a ratchet (a file may not gain a literal, a new file may not appear);
                 losing literals is fine and is written to the baseline with --update-baseline.
                 game/assets/** (scripts living next to the art), game/tests/fixtures and .godot are out of scope.

  python3 tools/lint_asset_id_only.py                 report + ratchet, exit 1 on a breach / a shell violation
  python3 tools/lint_asset_id_only.py --files         list every literal (file:line)
  python3 tools/lint_asset_id_only.py --update-baseline
  python3 tools/lint_asset_id_only.py --selftest      synthetic trees, each rule must fire exactly as expected
  python3 tools/lint_asset_id_only.py --selftest --check      (what tools/tw_test.py runs)
Markers: "ASSET_ID_ONLY RESULT: PASS|FAIL (...)" and "ASSET_ID_ONLY SELFTEST ok/total PASS|FAIL".
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BASELINE = REPO / "tools" / "lint_asset_id_baseline.json"
EXTS = (".gd", ".tscn", ".tres")
LIT = re.compile(r"""(["'])(?:res://assets/|assets/[A-Za-z0-9_]+/)""")
SHELL_EXEMPT_DIR = "shell/assets/"


def strip_comment(line: str) -> str:
    """drop a trailing # comment but keep string literals (they are what we look at)"""
    q, i = "", 0
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
            return line[:i]
        i += 1
    return line


def scan_text(rel: str, text: str) -> list[tuple[int, str]]:
    hits = []
    for n, raw in enumerate(text.splitlines(), 1):
        code = strip_comment(raw) if rel.endswith(".gd") else raw
        if "assets/" not in code:
            continue
        if rel.endswith(".gd") and code.lstrip().startswith("#"):
            continue
        for _ in LIT.finditer(code):
            hits.append((n, raw.strip()))
    return hits


def exempt_shell(rel: str) -> bool:
    return rel.startswith(SHELL_EXEMPT_DIR) or rel.endswith("_selftest.gd") or rel.endswith("_selftest_runner.gd")


def lint(game: Path):
    """-> (shell violations [(rel, line, text)], legacy {rel: n}, sites [(rel, line, text)])"""
    shell_v: list[tuple[str, int, str]] = []
    legacy: dict[str, int] = {}
    sites: list[tuple[str, int, str]] = []
    for f in sorted(game.rglob("*")):
        if not f.is_file() or f.suffix not in EXTS:
            continue
        rel = f.relative_to(game).as_posix()
        if rel.startswith((".godot/", "assets/", "tests/fixtures/", "addons/")):
            continue
        hits = scan_text(rel, f.read_text(encoding="utf-8", errors="replace"))
        if not hits:
            continue
        if rel.startswith("shell/"):
            if exempt_shell(rel):
                continue
            for n, src in hits:
                shell_v.append((rel, n, src))
            continue
        legacy[rel] = len(hits)
        for n, src in hits:
            sites.append((rel, n, src))
    return shell_v, legacy, sites


def ratchet(legacy: dict, base: dict) -> list[str]:
    msgs = []
    for rel, n in sorted(legacy.items()):
        if n > base.get(rel, 0):
            msgs.append(f"{rel} has {n} literal(s), baseline {base.get(rel, 0)}")
    return msgs


def load_baseline() -> dict | None:
    if not BASELINE.exists():
        return None
    return json.loads(BASELINE.read_text(encoding="utf-8"))


# --------------------------------------------------------------------------------------------------
def _w(p: Path, text: str = "") -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")


def selftest() -> tuple[int, int]:
    cases: list[bool] = []

    def case(name: str, ok: bool, info: str = "") -> None:
        cases.append(ok)
        print(("PASS " if ok else "FAIL ") + name + ("" if ok else " " + info))

    def run(files: dict[str, str]):
        with tempfile.TemporaryDirectory() as t:
            g = Path(t) / "game"
            for rel, txt in files.items():
                _w(g / rel, txt)
            return lint(g)

    sv, lg, _ = run({"scripts/a.gd": 'var t = load("res://assets/hero/rin.png")\nvar u = preload("res://assets/bg/x.webp")\n'})
    case("legacy: two res://assets literals counted, no shell violation", lg == {"scripts/a.gd": 2} and not sv, str(lg))
    sv, lg, _ = run({"scripts/a.gd": '# load("res://assets/hero/rin.png")\nvar t = 1 # "res://assets/x.png"\n'})
    case("legacy: comments are ignored", lg == {} and not sv, str(lg))
    sv, lg, _ = run({"scripts/a.gd": 'const P = "assets/sfx/clack"\nvar q = "my_assets/x"\nvar r = "res://data/assets.json"\n'})
    case("legacy: quoted assets/<dir>/ counts, look-alikes (my_assets, data/assets.json) do not", lg == {"scripts/a.gd": 1}, str(lg))
    sv, _, _ = run({"shell/screens/x/screen.gd": 'func f():\n\tvar t = load("res://assets/hero/rin.png")\n'})
    case("shell: a res://assets literal is an enforced violation", len(sv) == 1 and sv[0][0] == "shell/screens/x/screen.gd", str(sv))
    sv, _, _ = run({"shell/screens/x/screen.tscn": '[ext_resource type="Texture2D" path="res://assets/ui/logo.webp" id="1"]\n'})
    case("shell: a literal in a .tscn counts too", len(sv) == 1, str(sv))
    sv, _, _ = run({"shell/assets/tw_assets.gd": 'const M = "res://assets/manifest/assets.json"\n',
                    "shell/assets/resolvers/r.gd": 'var p = "res://assets/hero/"\n'})
    case("shell: the registry and its resolvers are exempt", not sv, str(sv))
    sv, _, _ = run({"shell/assets/assets_selftest.gd": 'const A = "res://assets/ui/logo.webp"\n',
                    "shell/nav/foo_selftest.gd": 'var x = "res://assets/ui/logo.webp"\n'})
    case("shell: selftests are exempt", not sv, str(sv))
    sv, _, _ = run({"shell/screens/x/screen.gd": 'func f():\n\tvar t = TWAssets.tex("bg.bg_festival")\n\tvar d = "res://shell/assets/x"\n'})
    case("shell: going through TWAssets is clean (shell/assets/ path is not game/assets/)", not sv, str(sv))
    sv, lg, _ = run({"assets/v10/rig/x/rig.gd": 'var t = load("res://assets/v10/rig/x/body.png")\n', "tests/fixtures/f.gd": 'var a = "res://assets/z.png"\n'})
    case("scripts living inside game/assets and test fixtures are out of scope", lg == {} and not sv, str(lg))
    base = {"scripts/a.gd": 2}
    _, lg, _ = run({"scripts/a.gd": 'var t = "res://assets/a.png"\nvar u = "res://assets/b.png"\n'})
    case("ratchet: same counts pass", ratchet(lg, base) == [])
    _, lg, _ = run({"scripts/a.gd": 'var t = "res://assets/a.png"\nvar u = "res://assets/b.png"\nvar v = "res://assets/c.png"\n'})
    case("ratchet: one more literal is a breach", len(ratchet(lg, base)) == 1, str(ratchet(lg, base)))
    _, lg, _ = run({"scripts/a.gd": 'var t = "res://assets/a.png"\n', "scripts/new.gd": 'var z = "res://assets/z.png"\n'})
    case("ratchet: a new file with a literal is a breach", len(ratchet(lg, base)) == 1, str(ratchet(lg, base)))
    _, lg, _ = run({"scripts/a.gd": "var t = 1\n"})
    case("ratchet: fewer literals pass (the legacy is being migrated)", ratchet(lg, base) == [])
    return sum(cases), len(cases)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--files", action="store_true")
    ap.add_argument("--update-baseline", action="store_true")
    ap.add_argument("--game", default=str(REPO / "game"))
    a = ap.parse_args()
    rc = 0
    if a.selftest:
        ok, n = selftest()
        print(f"ASSET_ID_ONLY SELFTEST {ok}/{n} {'PASS' if ok == n else 'FAIL'}")
        rc |= 0 if ok == n else 1
    if a.check or a.files or a.update_baseline or not a.selftest:
        shell_v, legacy, sites = lint(Path(a.game))
        tot = sum(legacy.values())
        if a.files:
            for rel, n, src in sites:
                print(f"game/{rel}:{n}: LITERAL {src[:110]}")
        for rel, n, src in shell_v:
            print(f"game/{rel}:{n}: ASSET_ID_ONLY {src[:110]}")
        if a.update_baseline:
            BASELINE.write_text(json.dumps({"_note": "ASSET_ID_ONLY legacy ratchet: res://assets literals per file outside game/shell (report mode); regenerate with --update-baseline",
                                            "total": tot, "files": dict(sorted(legacy.items()))}, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
            print(f"baseline written: {tot} literals in {len(legacy)} files")
        base = load_baseline()
        breach: list[str] = []
        if base is None:
            breach.append("tools/lint_asset_id_baseline.json is missing (run --update-baseline)")
        else:
            breach = ratchet(legacy, base.get("files", {}))
        for m in breach:
            print("RATCHET " + m)
        bad = len(shell_v) + len(breach)
        print(f"ASSET_ID_ONLY RESULT: {'PASS' if not bad else 'FAIL'} (shell {len(shell_v)} violations; legacy report-mode: "
              f"{tot} literals in {len(legacy)} files; baseline {base.get('total', '?') if base else '?'}; {len(breach)} ratchet breaches)")
        rc |= 1 if bad else 0
    return rc


if __name__ == "__main__":
    sys.exit(main())
