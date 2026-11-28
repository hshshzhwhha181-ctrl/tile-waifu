#!/usr/bin/env python3
"""Screen recordings of the vertical slice on three aspects for the owner's gate package (P38).

  python tools/slice_reel.py --out design/slice_gate [--seconds 90] [--sizes 720x1280,720x1600,1536x2048] [--every 4]

For every size runs `res://shell/main_v11.tscn -- --slice=reel` (shell/tests/slice_goldens.gd `_reel`): xvfb + opengl3 + `--fixed-fps 60`, so one
frame is 1/60 s of GAME time whatever the machine does (a 90 s video is 5400 game frames, recorded in a few minutes of wall time), the
Home hour pinned to 12 (`--v7_hour=12`), a frozen calendar, a fresh save, Effects = minimum. The solver bot plays whole rounds at a human pace
(14 frames = 0.23 s per tap) through the same screen API as the P37 suite; each round ends on the real victory modal and its button; the
tail visits Collection, Wish, Shop. Output per size:
  <out>/reel_<WxH>.mp4          H.264, yuv420p, scaled to <= 720 px wide, 60/every fps
  <out>/reel_<WxH>_contact.png  24 evenly spaced frames
  <out>/reel_<WxH>.log          the SLICE_REEL line (frames, game seconds, rounds, taps, wins) + SLICE_SELFTEST
The frames are JPEG in a temp dir that is deleted. Needs Godot (GODOT_BIN), xvfb-run, ffmpeg, Pillow.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from slice_tour import sheet  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
GAME = REPO / "game"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--godot")
    ap.add_argument("--out", required=True)
    ap.add_argument("--seconds", type=int, default=90)
    ap.add_argument("--sizes", default="720x1280,720x1600,1536x2048")
    ap.add_argument("--every", type=int, default=4, help="record every N-th game frame (video fps = 60/N)")
    ap.add_argument("--timeout", type=int, default=3000)
    a = ap.parse_args()
    godot = next((c for c in (a.godot, os.environ.get("GODOT_BIN"), shutil.which("godot4"), shutil.which("godot")) if c and Path(c).exists()), None)
    if not godot:
        print("SLICE_REEL SKIP no Godot binary")
        return 0
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    bad = 0
    for size in a.sizes.split(","):
        w, h = size.split("x")
        t0 = time.time()
        with tempfile.TemporaryDirectory(prefix="tw_reel_") as td:
            frames = Path(td) / "frames"
            frames.mkdir()
            env = dict(os.environ, HOME=td + "/h", XDG_DATA_HOME=td + "/d", XDG_CONFIG_HOME=td + "/c", XDG_CACHE_HOME=td + "/k", APPDATA=td)
            cmd = []
            if not os.environ.get("DISPLAY") and shutil.which("xvfb-run"):
                cmd += ["xvfb-run", "-a", "-s", f"-screen 0 {w}x{h}x24 -nolisten tcp"]
            cmd += [godot, "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--resolution", size, "--fixed-fps", "60",
                    "--path", str(GAME), "res://shell/main_v11.tscn", "--", "--slice=reel", f"--slice_out={frames}",
                    f"--slice_every={a.every}", f"--slice_seconds={a.seconds}", "--v7_hour=12"]
            p = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=a.timeout, errors="replace")
            log = p.stdout + p.stderr
            keep = [ln for ln in log.splitlines() if "SLICE" in ln or "SCRIPT ERROR" in ln]
            (out / f"reel_{size}.log").write_text("\n".join(keep) + "\n", encoding="utf-8")
            files = sorted(frames.glob("f_*.jpg"))
            wall = time.time() - t0
            line = next((ln for ln in keep if ln.startswith("SLICE_REEL")), "SLICE_REEL no result line")
            print(f"[{size}] {len(files)} frames, wall {wall:.0f} s: {line}")
            if not files:
                print(log[-1500:])
                bad += 1
                continue
            n = 24
            pick = [files[round(i * (len(files) - 1) / (n - 1))] for i in range(n)] if len(files) > n else files
            sheet(pick, 6, 240, out / f"reel_{size}_contact.png")
            if shutil.which("ffmpeg"):
                fps = 60 // a.every
                vf = "scale='min(720,iw)':-2"
                r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps), "-i", str(frames / "f_%05d.jpg"),
                                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "27", "-preset", "medium", "-vf", vf,
                                    str(out / f"reel_{size}.mp4")], capture_output=True, text=True)
                print(f"[{size}] video:", "ok" if r.returncode == 0 else r.stderr[-300:])
                bad += r.returncode != 0
            else:
                print("no ffmpeg: contact sheet only")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
