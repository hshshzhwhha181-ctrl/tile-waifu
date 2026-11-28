#!/usr/bin/env python3
"""Performance budget of the vertical slice (P37 / WP10d).

  python tools/perf_budget.py                 headless profile + software-GL profile + PCK size
  python tools/perf_budget.py --no-pck        skip the export (the PCK step takes ~1-2 min)
  python tools/perf_budget.py --report FILE   also write a Markdown report (default: print only)
  python tools/perf_budget.py --selftest      python-only: the budget arithmetic on synthetic numbers

Budgets (GDD 10.x, backlog P37):
  * p95 of the frame cost of a live 60-tile round <= 16.6 ms. "Frame cost" = what the match view owns of a frame: its timeline step + the
    script time of its draw list (`TWSlicePerf`, game/shell/tests/slice_perf.gd). Measured twice:
      - headless (dummy renderer): pure CPU/script cost, no rasteriser;
      - xvfb + opengl3 on Mesa llvmpipe: the same cost with the draw commands really executed, plus the wall-clock frame of the PROCESS
        (software raster; reported, never judged - it is not a phone).
    The reference device is the owner's phone (M2): until he measures it every result carries "device not verified".
  * the exported pack (`--export-pack Android-store`) <= 135 MB (decimal, as WP2 counts).

Prints `PERF_BUDGET ok/total`.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GAME = REPO / "game"
FRAME_LIMIT_MS = 16.6
PCK_LIMIT = 135_000_000
PRESET = "Android-store"


def find_godot(arg):
    for c in (arg, os.environ.get("GODOT_BIN"), shutil.which("godot4"), shutil.which("godot")):
        if c and Path(c).exists():
            return str(c)
    return None


def env_for(home: str) -> dict:
    return dict(os.environ, HOME=home, XDG_DATA_HOME=home + "/d", XDG_CONFIG_HOME=home + "/c", XDG_CACHE_HOME=home + "/k", APPDATA=home)


def run_perf(godot: str, headless: bool, timeout: int = 300):
    with tempfile.TemporaryDirectory(prefix="tw_perf_home_") as home:
        cmd = []
        if headless:
            cmd += [godot, "--headless"]
        else:
            if not os.environ.get("DISPLAY") and shutil.which("xvfb-run"):
                cmd += ["xvfb-run", "-a", "-s", "-screen 0 720x1280x24 -nolisten tcp"]
            cmd += [godot, "--rendering-driver", "opengl3"]
        cmd += ["--audio-driver", "Dummy", "--resolution", "720x1280", "--path", str(GAME), "res://shell/main_v11.tscn", "--", "--slice=perf"]
        try:
            p = subprocess.run(cmd, env=env_for(home), capture_output=True, text=True, timeout=timeout, errors="replace")
            out = p.stdout + p.stderr
        except subprocess.TimeoutExpired:
            return None, "TIMEOUT"
    m = re.findall(r"SLICE_PERF (\{.*\})", out)
    return (json.loads(m[-1]) if m else None), out


def export_pck(godot: str, timeout: int = 900):
    with tempfile.TemporaryDirectory(prefix="tw_perf_pck_") as td:
        pck = Path(td) / "slice.pck"
        t0 = time.time()
        p = subprocess.run([godot, "--headless", "--path", str(GAME), "--export-pack", PRESET, str(pck)], env=env_for(td + "/home"),
                           capture_output=True, text=True, timeout=timeout, errors="replace")
        size = pck.stat().st_size if pck.exists() else 0
        return size, time.time() - t0, p.stdout + p.stderr


def judge(rows: list) -> tuple[int, int, list]:
    """rows = [(name, value, limit)] - ok when value <= limit; returns (ok, total, failures)"""
    bad = [f"{n}: {v} > {lim}" for n, v, lim in rows if not (v is not None and v <= lim)]
    return len(rows) - len(bad), len(rows), bad


def selftest() -> int:
    good = judge([("a", 16.6, 16.6), ("b", 3, 16.6), ("pck", 133_429_988, PCK_LIMIT)])
    bad = judge([("a", 16.7, 16.6), ("b", None, 16.6), ("pck", 135_000_001, PCK_LIMIT)])
    parsed = json.loads(re.findall(r"SLICE_PERF (\{.*\})", 'x\nSLICE_PERF {"cost_p95_ms": 1.5}\ny')[-1])
    checks = [good == (3, 3, []), bad[0] == 0 and bad[1] == 3 and len(bad[2]) == 3, parsed["cost_p95_ms"] == 1.5, FRAME_LIMIT_MS == 16.6, PCK_LIMIT == 135_000_000]
    n = sum(checks)
    print(f"PERF_BUDGET SELFTEST {n}/{len(checks)}")
    return 0 if n == len(checks) else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--godot")
    ap.add_argument("--no-pck", action="store_true")
    ap.add_argument("--report")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    godot = find_godot(a.godot)
    if not godot:
        print("PERF_BUDGET SKIP no Godot binary (set GODOT_BIN or --godot)")
        return 0
    rows = []
    lines = ["# Slice performance budget (P37)", "",
             "Reference device: the owner's phone (M2) - **not verified** here; numbers below are this container (4 vCPU, Mesa llvmpipe).", ""]
    head, hlog = run_perf(godot, True)
    print("PERF headless:", json.dumps(head) if head else "no SLICE_PERF line\n" + hlog[-1500:])
    if head:
        rows.append(("headless frame cost p95 ms (%d tiles)" % head["tiles"], head["cost_p95_ms"], FRAME_LIMIT_MS))
        lines += ["## Frame cost, headless (script side, no rasteriser)", "", f"{head['tiles']} tiles, {head['frames']} frames: p50 {head['cost_p50_ms']} ms, p95 **{head['cost_p95_ms']} ms**, max {head['cost_max_ms']} ms (limit {FRAME_LIMIT_MS} ms).", ""]
    else:
        rows.append(("headless run produced SLICE_PERF", None, 0))
    if not os.environ.get("DISPLAY") and not shutil.which("xvfb-run"):
        print("PERF software-GL profile skipped: no display / xvfb-run")
    else:
        sw, slog = run_perf(godot, False)
        print("PERF software GL:", json.dumps(sw) if sw else "no SLICE_PERF line\n" + slog[-1500:])
        if sw:
            rows.append(("software-GL frame cost p95 ms (%d tiles)" % sw["tiles"], sw["cost_p95_ms"], FRAME_LIMIT_MS))
            lines += ["## Frame cost, xvfb + opengl3 (" + str(sw["renderer"]) + ")", "",
                      f"cost p50 {sw['cost_p50_ms']} ms, p95 **{sw['cost_p95_ms']} ms**, max {sw['cost_max_ms']} ms; wall frame of the process (software raster, NOT judged): p50 {sw['wall_p50_ms']} ms, p95 {sw['wall_p95_ms']} ms; Home idle wall p95 {sw['home_wall_p95_ms']} ms. Screen {sw['size']}.", ""]
        else:
            rows.append(("software-GL run produced SLICE_PERF", None, 0))
    if not a.no_pck:
        size, secs, plog = export_pck(godot)
        print(f"PERF pck: {size} bytes ({size / 1e6:.2f} MB) in {secs:.0f} s")
        if size == 0:
            print(plog[-1500:])
        rows.append((f"PCK ({PRESET}) bytes", size if size else None, PCK_LIMIT))
        lines += ["## Pack size", "", f"`--export-pack {PRESET}`: **{size:,} bytes = {size / 1e6:.1f} MB** (limit 135 MB decimal, {secs:.0f} s to export).", ""]
    ok, total, bad = judge(rows)
    for b in bad:
        print("PERF_BUDGET FAIL:", b)
    lines += ["## Verdict", "", f"{ok}/{total} budget lines met. Frame budget on the reference device: **device not verified** (owner action M2: FPS and start time on the phone)."]
    if a.report:
        Path(a.report).write_text("\n".join(lines) + "\n", encoding="utf-8")
        print("PERF report:", a.report)
    print(f"PERF_BUDGET {ok}/{total}")
    return 0 if ok == total else 1


if __name__ == "__main__":
    sys.exit(main())
