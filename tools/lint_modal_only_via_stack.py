#!/usr/bin/env python3
"""lint_modal_only_via_stack.py - MODAL_ONLY_VIA_STACK lint (P24 / WP8b).

Every modal lives in the ModalStack (game/shell/nav/modal_stack.gd, TWModal base class) and nobody else touches the modal layer.
The legacy `main.overlay` is the opposite: anything adds children to it, and "is a modal open?" is answered by scanning its
children (the detector that missed a tag in 0.12.1 and left a STOP scrim over the next screen).

Rules (static, pure Python, comments and string literals are ignored)
  SCAN    `overlay.get_children(` / `overlay.get_child_count(` / `overlay.find_children(`   an overlay-children detector
  INDEX   `overlay.get_child(`                                                                the indexed half of a detector loop
  ADD     `overlay.add_child(`                                                                a view added straight to the layer
  SHELL   in game/shell/** (ENFORCING, 0 allowed): any SCAN / INDEX / ADD, any `.overlay` member access, and any `add_child(` on
          the modal layer (`modals.` / `modal_stack.` / `modal_layer.`); the only files allowed are shell/nav/modal_stack.gd and
          shell/nav/tw_modal.gd (the stack itself) and the selftests under shell/nav/ that probe the layer (modal_selftest.gd, legacy_host_selftest.gd)

Scope of the legacy rules: game/**/*.gd outside game/shell/. REPORT MODE: they are counted per file and compared with
tools/lint_modal_baseline.json as a ratchet (a file may not gain a site, a new file may not appear); losing sites is fine and is
written to the baseline with --update-baseline. The count of SCAN sites is the audit number of the 0.12.1 post-mortem (39).

  python3 tools/lint_modal_only_via_stack.py                 report (all sites per file) + ratchet, exit 1 on a breach
  python3 tools/lint_modal_only_via_stack.py --files         list every site (file:line)
  python3 tools/lint_modal_only_via_stack.py --update-baseline
  python3 tools/lint_modal_only_via_stack.py --selftest      synthetic trees, each rule must fire exactly as expected
  python3 tools/lint_modal_only_via_stack.py --selftest --check      (what tools/tw_test.py runs)
Markers: "MODAL_ONLY_VIA_STACK RESULT: PASS|FAIL (...)" and "MODAL_ONLY_VIA_STACK SELFTEST ok/total PASS|FAIL".
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BASELINE = REPO / "tools" / "lint_modal_baseline.json"

SCAN = re.compile(r"\boverlay\.(?:get_children|get_child_count|find_children)\s*\(")
INDEX = re.compile(r"\boverlay\.get_child\s*\(")
ADD = re.compile(r"\boverlay\.add_child\s*\(")
MEMBER = re.compile(r"\.overlay\b")
LAYER_ADD = re.compile(r"\b(?:modals|modal_stack|modal_layer)\.add_child\s*\(")
SHELL_ALLOWED = ("shell/nav/modal_stack.gd", "shell/nav/tw_modal.gd", "shell/nav/modal_selftest.gd", "shell/nav/legacy_host_selftest.gd")
KINDS = ("scan", "index", "add")


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
    """-> [(line, kind, source line)], one entry per match (two scans on one line count twice)"""
    res = []
    for n, raw in enumerate(text.splitlines(), 1):
        code = strip(raw)
        if "overlay" not in code and "add_child" not in code:
            continue
        for _ in SCAN.finditer(code):
            res.append((n, "scan", raw.strip()))
        for _ in INDEX.finditer(code):
            res.append((n, "index", raw.strip()))
        for _ in ADD.finditer(code):
            res.append((n, "add", raw.strip()))
        for _ in LAYER_ADD.finditer(code):
            res.append((n, "layer_add", raw.strip()))
        if MEMBER.search(code) and not (SCAN.search(code) or INDEX.search(code) or ADD.search(code)):
            res.append((n, "member", raw.strip()))
    return res


def lint(game: Path):
    """-> (shell violations [(rule, rel, line, text)], legacy {kind: {rel: n}}, sites [(kind, rel, line, text)])"""
    shell_v: list[tuple[str, str, int, str]] = []
    legacy: dict[str, dict[str, int]] = {k: {} for k in KINDS}
    sites: list[tuple[str, str, int, str]] = []
    for g in sorted(game.rglob("*.gd")):
        rel = g.relative_to(game).as_posix()
        if rel.startswith(".godot/") or rel.startswith("tests/fixtures/"):
            continue
        text = g.read_text(encoding="utf-8", errors="replace")
        hits = scan_text(text)
        if not hits:
            continue
        if rel.startswith("shell/"):
            if rel in SHELL_ALLOWED:
                continue
            for n, kind, src in hits:
                shell_v.append(("SHELL_" + kind.upper(), rel, n, src))
            continue
        for n, kind, src in hits:
            if kind in KINDS:
                legacy[kind][rel] = legacy[kind].get(rel, 0) + 1
                sites.append((kind, rel, n, src))
    return shell_v, legacy, sites


def totals(legacy: dict) -> dict:
    return {k: sum(v.values()) for k, v in legacy.items()}


def ratchet(legacy: dict, base: dict) -> list[str]:
    """messages for every file whose count grew over the baseline (or that is new)"""
    msgs = []
    for k in KINDS:
        b = base.get(k, {})
        for rel, n in sorted(legacy[k].items()):
            if n > b.get(rel, 0):
                msgs.append(f"{k}: {rel} has {n} site(s), baseline {b.get(rel, 0)}")
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

    LEG = ("func a():\n\tfor c in main.overlay.get_children():\n\t\tpass\n"
           "\tvar n = overlay.get_child_count()\n\tvar x = overlay.get_child(0)\n"
           "\tfor n in m.overlay.find_children(\"*\", \"\", true, false):\n\t\tpass\n\toverlay.add_child(v)\n")
    sv, lg, sites = run({"scripts/main.gd": LEG})
    case("legacy: 3 scan + 1 index + 1 add counted, 0 shell violations",
         totals(lg) == {"scan": 3, "index": 1, "add": 1} and not sv, str(totals(lg)))
    sv, lg, _ = run({"scripts/a.gd": "var p = main.overlay.get_children()\nvar q = a.overlay.get_children() + b.overlay.get_children()\n"})
    case("legacy: two scans on one line are two sites", totals(lg)["scan"] == 3, str(totals(lg)))
    sv, lg, _ = run({"scripts/a.gd": "# for c in overlay.get_children():\nvar s = \"overlay.get_children()\"\nvar t = 1 # overlay.add_child(x)\n"})
    case("legacy: comments and string literals are ignored", totals(lg) == {"scan": 0, "index": 0, "add": 0} and not sv, str(totals(lg)))
    sv, lg, _ = run({"scripts/a.gd": "var d = overlay.get_children_count()\nvar e = overlay_get_children()\nvar f = my_overlay.get_children()\n"})
    case("legacy: look-alike names do not count (get_children_count, overlay_get_children, my_overlay)",
         totals(lg)["scan"] == 0, str(totals(lg)))
    sv, lg, _ = run({"shell/screens/x/screen.gd": "func f():\n\tfor c in main.overlay.get_children():\n\t\tpass\n"})
    case("shell: an overlay scan is an enforced violation (SHELL_SCAN)", [v[0] for v in sv] == ["SHELL_SCAN"] and totals(lg)["scan"] == 0, str(sv))
    sv, _, _ = run({"shell/screens/x/screen.gd": "func f():\n\tmain.overlay.add_child(v)\n"})
    case("shell: overlay.add_child is SHELL_ADD", [v[0] for v in sv] == ["SHELL_ADD"], str(sv))
    sv, _, _ = run({"shell/screens/x/screen.gd": "func f():\n\tvar o = main.overlay\n"})
    case("shell: any .overlay member access is SHELL_MEMBER", [v[0] for v in sv] == ["SHELL_MEMBER"], str(sv))
    sv, _, _ = run({"shell/screens/x/screen.gd": "func f():\n\tctx.modals.add_child(v)\n"})
    case("shell: add_child on the modal layer is SHELL_LAYER_ADD", [v[0] for v in sv] == ["SHELL_LAYER_ADD"], str(sv))
    sv, _, _ = run({"shell/nav/modal_stack.gd": "func f():\n\tvar k = overlay.get_children()\n\tmodals.add_child(m)\n",
                    "shell/nav/tw_modal.gd": "func f():\n\tmodal_layer.add_child(m)\n"})
    case("shell: the stack and TWModal themselves are allowed", not sv, str(sv))
    sv, _, _ = run({"shell/screens/x/screen.gd": "func f():\n\tctx.modals.open(m)\n\tvar o = overlay_alpha\n"})
    case("shell: going through the stack is clean", not sv, str(sv))
    # ratchet
    base = {"scan": {"scripts/main.gd": 3}, "index": {"scripts/main.gd": 1}, "add": {"scripts/main.gd": 1}}
    _, lg, _ = run({"scripts/main.gd": LEG})
    case("ratchet: same counts pass", ratchet(lg, base) == [])
    _, lg, _ = run({"scripts/main.gd": LEG + "\tfor c in overlay.get_children():\n\t\tpass\n"})
    case("ratchet: one more scan in a known file is a breach", len(ratchet(lg, base)) == 1, str(ratchet(lg, base)))
    _, lg, _ = run({"scripts/main.gd": LEG, "scripts/new.gd": "var z = overlay.get_children()\n"})
    case("ratchet: a new file with a scan is a breach", len(ratchet(lg, base)) == 1, str(ratchet(lg, base)))
    _, lg, _ = run({"scripts/main.gd": "var z = 1\n"})
    case("ratchet: fewer sites pass (the legacy is being deleted)", ratchet(lg, base) == [])
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
        print(f"MODAL_ONLY_VIA_STACK SELFTEST {ok}/{n} {'PASS' if ok == n else 'FAIL'}")
        rc |= 0 if ok == n else 1
    if a.check or a.files or a.update_baseline or not a.selftest:
        shell_v, legacy, sites = lint(Path(a.game))
        tot = totals(legacy)
        if a.files:
            for kind, rel, n, src in sites:
                print(f"game/{rel}:{n}: {kind.upper()} {src[:110]}")
        for rule, rel, n, src in shell_v:
            print(f"game/{rel}:{n}: {rule} {src[:110]}")
        if a.update_baseline:
            BASELINE.write_text(json.dumps({"_note": "MODAL_ONLY_VIA_STACK legacy ratchet: sites per file (report mode); regenerate with --update-baseline",
                                            "totals": tot, **{k: dict(sorted(legacy[k].items())) for k in KINDS}}, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
            print(f"baseline written: {tot}")
        base = load_baseline()
        breach: list[str] = []
        if base is None:
            breach.append("tools/lint_modal_baseline.json is missing (run --update-baseline)")
        else:
            breach = ratchet(legacy, base)
        for m in breach:
            print("RATCHET " + m)
        bad = len(shell_v) + len(breach)
        base_scan = base.get("totals", {}).get("scan", "?") if base else "?"
        print(f"MODAL_ONLY_VIA_STACK RESULT: {'PASS' if not bad else 'FAIL'} (shell {len(shell_v)} violations; "
              f"legacy report-mode sites: {tot['scan']} overlay-scan, {tot['index']} index, {tot['add']} add; "
              f"scan baseline {base_scan}; {len(breach)} ratchet breaches)")
        rc |= 1 if bad else 0
    return rc


if __name__ == "__main__":
    sys.exit(main())
