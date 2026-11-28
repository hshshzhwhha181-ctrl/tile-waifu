#!/usr/bin/env python3
"""Cold-start numbers of the vertical slice (P38).

  python tools/slice_boot.py [--runs 5] [--size 720x1280] [--headless]

Starts `res://shell/main_v11.tscn -- --slice=boot` N times (fresh HOME each time = no save, no shader / user caches) and prints, per run, the
process wall clock from spawn to the `SLICE_BOOT` line plus the engine-side split (see `_boot` in game/shell/tests/slice_goldens.gd):
  engine_to_host_ms  engine start -> the shell host is ready (engine + project load + autoloads + shell scene)
  home_ms            Home opened -> first drawn frame
  board_ms           the v11 60-tile board mounted -> first drawn frame
  wall_s             spawn -> SLICE_BOOT printed (includes xvfb start, process spawn)
Software GL (llvmpipe) on a 4-vCPU container reading the project from the .godot import cache, NOT an exported APK on a phone: label every number
"device not verified". GDD 11.1 target (not verified): <= 6 s to the first board. Prints `SLICE_BOOT_MEDIAN wall_s=.. to_board_s=..`.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

GAME = Path(__file__).resolve().parent.parent / "game"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--godot")
    ap.add_argument("--runs", type=int, default=5)
    ap.add_argument("--size", default="720x1280")
    ap.add_argument("--headless", action="store_true")
    a = ap.parse_args()
    godot = next((c for c in (a.godot, os.environ.get("GODOT_BIN"), shutil.which("godot4"), shutil.which("godot")) if c and Path(c).exists()), None)
    if not godot:
        print("SLICE_BOOT SKIP no Godot binary")
        return 0
    w, h = a.size.split("x")
    rows = []
    for i in range(a.runs):
        with tempfile.TemporaryDirectory(prefix="tw_boot_") as td:
            env = dict(os.environ, HOME=td, XDG_DATA_HOME=td + "/d", XDG_CONFIG_HOME=td + "/c", XDG_CACHE_HOME=td + "/k", APPDATA=td)
            cmd = []
            if a.headless:
                cmd += [godot, "--headless"]
            else:
                if not os.environ.get("DISPLAY") and shutil.which("xvfb-run"):
                    cmd += ["xvfb-run", "-a", "-s", f"-screen 0 {w}x{h}x24 -nolisten tcp"]
                cmd += [godot, "--rendering-driver", "opengl3"]
            cmd += ["--audio-driver", "Dummy", "--resolution", a.size, "--path", str(GAME), "res://shell/main_v11.tscn", "--", "--slice=boot", "--v7_hour=12"]
            t0 = time.time()
            p = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=300, errors="replace")
            wall = time.time() - t0
        m = re.search(r"SLICE_BOOT engine_to_host_ms=(\d+) home_ms=(\d+) board_ms=(\d+) static_mem_peak_mb=(\d+)", p.stdout + p.stderr)
        if not m:
            print(f"run {i + 1}: no SLICE_BOOT line\n{(p.stdout + p.stderr)[-800:]}")
            return 1
        host, home, board, mem = (int(x) for x in m.groups())
        rows.append((wall, host, home, board, mem))
        print(f"run {i + 1}: wall {wall:.1f} s | engine_to_host {host} ms | home {home} ms | board {board} ms | static mem peak {mem} MB")
    med = lambda k: statistics.median(r[k] for r in rows)  # noqa: E731
    to_board = (med(1) + med(3)) / 1000.0
    print(f"SLICE_BOOT_MEDIAN wall_s={med(0):.1f} engine_to_host_s={med(1) / 1000:.1f} home_s={med(2) / 1000:.1f} board_s={med(3) / 1000:.1f} "
          f"to_board_s={to_board:.1f} static_mem_peak_mb={med(4):.0f} renderer={'headless' if a.headless else 'opengl3/llvmpipe'} (device not verified)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
