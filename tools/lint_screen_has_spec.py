#!/usr/bin/env python3
"""lint_screen_has_spec.py - SCREEN_HAS_SPEC lint (P23 / WP8a): a v11 screen without a ScreenSpec does not exist.

Rules (static, pure Python, no Godot):
  NO_SPEC          a folder under game/shell/screens/ holds a script that `extends TWScreen` (or a .tscn) but has no spec.tres
  BAD_SPEC         spec.tres is not a ScreenSpec resource, has no snake_case `id`, or points at a script/scene that is missing
  DUP_ID           two specs (anywhere under game/) declare the same id
  OUTSIDE_SCREENS  a script that `extends TWScreen` lives outside game/shell/screens/ (allowed: game/shell/nav/ test doubles,
                   game/tests/ fixtures); screens are folders: shell/screens/<name>/{spec.tres, screen.gd, ...}
The runtime twin is TWScreens.register()/scan(), which refuses the same cases (tested in TWNAV_SELFTEST).

  python3 tools/lint_screen_has_spec.py --check       lint the repo; exit 1 on a violation
  python3 tools/lint_screen_has_spec.py --selftest    7 synthetic trees, each rule must fire exactly once
  python3 tools/lint_screen_has_spec.py --selftest --check    (what tools/tw_test.py runs)
Markers: "SCREEN_HAS_SPEC RESULT: PASS|FAIL (N violations)" and "SCREEN_HAS_SPEC SELFTEST ok/total".
"""
from __future__ import annotations

import argparse
import re
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
EXTENDS = re.compile(r'^\s*extends\s+(?:TWScreen\b|"res://shell/nav/tw_screen\.gd")', re.M)
ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")
ALLOW_OUTSIDE = ("shell/nav/", "tests/")


def _spec_fields(text: str) -> dict:
    out = {}
    for m in re.finditer(r'^(\w+)\s*=\s*"([^"]*)"\s*$', text, re.M):
        out[m.group(1)] = m.group(2)
    return out


def _res_exists(game: Path, p: str) -> bool:
    return p.startswith("res://") and (game / p[6:]).exists()


def lint(game: Path) -> list[tuple[str, str, str]]:
    """-> [(rule, path relative to game, message)]"""
    v: list[tuple[str, str, str]] = []
    screens = game / "shell" / "screens"
    ids: dict[str, str] = {}
    for spec in sorted(game.rglob("spec.tres")):
        rel = spec.relative_to(game).as_posix()
        if rel.startswith("tests/"):
            continue                # fixtures (some of them deliberately broken, see TWNAV_SELFTEST scan)
        text = spec.read_text(encoding="utf-8", errors="replace")
        if 'script_class="ScreenSpec"' not in text:
            if screens in spec.parents:
                v.append(("BAD_SPEC", rel, "spec.tres is not a ScreenSpec resource"))
            continue
        f = _spec_fields(text)
        sid = f.get("id", "")
        if not ID_RE.match(sid):
            v.append(("BAD_SPEC", rel, f"id '{sid}' is missing or not snake_case"))
        else:
            if sid in ids:
                v.append(("DUP_ID", rel, f"id '{sid}' already declared in {ids[sid]}"))
            ids.setdefault(sid, rel)
        src = f.get("scene") or f.get("script_path") or ""
        if not src or not _res_exists(game, src):
            v.append(("BAD_SPEC", rel, f"scene/script_path '{src}' does not exist"))
    if screens.is_dir():
        for d in sorted(p for p in screens.iterdir() if p.is_dir()):
            has_screen = any(EXTENDS.search(g.read_text(encoding="utf-8", errors="replace")) for g in d.glob("*.gd")) \
                or any(d.glob("*.tscn"))
            if has_screen and not (d / "spec.tres").exists():
                v.append(("NO_SPEC", d.relative_to(game).as_posix(), "screen folder without spec.tres"))
    for g in sorted(game.rglob("*.gd")):
        rel = g.relative_to(game).as_posix()
        if rel.startswith("shell/screens/") or rel.startswith(ALLOW_OUTSIDE):
            continue
        if EXTENDS.search(g.read_text(encoding="utf-8", errors="replace")):
            v.append(("OUTSIDE_SCREENS", rel, "extends TWScreen outside shell/screens/<name>/"))
    return v


# --------------------------------------------------------------------------------------------------
def _w(p: Path, text: str = "") -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")


SPEC = '[gd_resource type="Resource" script_class="ScreenSpec" load_steps=2 format=3]\n\n[resource]\nid = "%s"\nscript_path = "res://shell/screens/%s/screen.gd"\n'
SCREEN = "extends TWScreen\n"


def selftest() -> tuple[int, int]:
    cases = []

    def case(name, build, expect):
        with tempfile.TemporaryDirectory() as t:
            g = Path(t) / "game"
            build(g)
            got = sorted({r for r, _, _ in lint(g)})
            ok = got == expect
            cases.append(ok)
            print(("PASS " if ok else "FAIL ") + f"{name}: {got} (expected {expect})")

    def good(g):
        _w(g / "shell/screens/home/screen.gd", SCREEN)
        _w(g / "shell/screens/home/spec.tres", SPEC % ("home", "home"))

    def no_spec(g):
        good(g)
        _w(g / "shell/screens/shop/screen.gd", SCREEN)

    def bad_spec_missing(g):
        good(g)
        _w(g / "shell/screens/shop/screen.gd", SCREEN)
        _w(g / "shell/screens/shop/spec.tres", SPEC % ("shop", "nope"))

    def bad_spec_id(g):
        good(g)
        _w(g / "shell/screens/shop/screen.gd", SCREEN)
        _w(g / "shell/screens/shop/spec.tres", SPEC % ("Shop-1", "shop"))

    def dup(g):
        good(g)
        _w(g / "shell/screens/shop/screen.gd", SCREEN)
        _w(g / "shell/screens/shop/spec.tres", SPEC % ("home", "shop"))

    def outside(g):
        good(g)
        _w(g / "scripts/v10/stray.gd", SCREEN)

    def allowed(g):
        good(g)
        _w(g / "shell/nav/fake.gd", SCREEN)
        _w(g / "tests/fixtures/screens/a/screen.gd", SCREEN)

    case("clean tree", good, [])
    case("screen.gd without spec.tres", no_spec, ["NO_SPEC"])
    case("spec points at a missing script", bad_spec_missing, ["BAD_SPEC"])
    case("spec id not snake_case", bad_spec_id, ["BAD_SPEC"])
    case("duplicate id", dup, ["DUP_ID"])
    case("TWScreen subclass outside shell/screens", outside, ["OUTSIDE_SCREENS"])
    case("nav/ test doubles and fixtures are allowed", allowed, [])
    return sum(cases), len(cases)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--game", default=str(REPO / "game"))
    a = ap.parse_args()
    rc = 0
    if a.selftest:
        ok, n = selftest()
        print(f"SCREEN_HAS_SPEC SELFTEST {ok}/{n} {'PASS' if ok == n else 'FAIL'}")
        rc |= 0 if ok == n else 1
    if a.check or not a.selftest:
        v = lint(Path(a.game))
        for r, p, m in v:
            print(f"game/{p}: {r} {m}")
        print(f"SCREEN_HAS_SPEC RESULT: {'PASS' if not v else 'FAIL'} ({len(v)} violations)")
        rc |= 1 if v else 0
    return rc


if __name__ == "__main__":
    sys.exit(main())
