#!/usr/bin/env python3
"""Record one whole round of the vertical slice as frames, a short video and a contact sheet (P37 / WP10d).

  python tools/slice_tour.py --out design/slice [--every 3] [--no-goldens]

Runs `res://shell/main_v11.tscn -- --slice=tour` at 720x1280 (xvfb + opengl3 + --fixed-fps 60, so a frame is 1/60 s of game time whatever
the machine does): Home -> Match (the solver bot taps, the real timeline plays) -> victory modal -> Collection -> Wish -> Shop. Every
--every-th frame is saved; then
  <out>/tour.mp4            the frames at 60/every fps (ffmpeg, H.264, yuv420p)
  <out>/tour_contact.png    a contact sheet of ~24 evenly spaced frames
  <out>/screens/<WxH>_<screen>.png   the golden screenshots (game/tests/goldens), copied for the owner to look at (unless --no-goldens)
  <out>/screens_contact.png a contact sheet of the 6 screens at 720x1280
Needs Godot (GODOT_BIN), xvfb-run, Pillow; ffmpeg for the video (skipped with a note when missing).
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GAME = REPO / "game"
SCREENS = ["home", "match", "result", "collection", "wish", "shop"]


def sheet(files: list, cols: int, thumb_w: int, out: Path, labels: list | None = None) -> None:
    from PIL import Image, ImageDraw
    ims = [Image.open(f).convert("RGB") for f in files]
    if not ims:
        return
    tw = thumb_w
    th = int(ims[0].height * tw / ims[0].width)
    rows = (len(ims) + cols - 1) // cols
    pad = 6
    canvas = Image.new("RGB", (cols * (tw + pad) + pad, rows * (th + pad) + pad), (24, 20, 28))
    d = ImageDraw.Draw(canvas)
    for i, im in enumerate(ims):
        x = pad + (i % cols) * (tw + pad)
        y = pad + (i // cols) * (th + pad)
        canvas.paste(im.resize((tw, th)), (x, y))
        if labels:
            d.rectangle([x, y, x + 8 + 7 * len(labels[i]), y + 16], fill=(0, 0, 0))
            d.text((x + 4, y + 2), labels[i], fill=(255, 255, 255))
    canvas.save(out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--godot")
    ap.add_argument("--out", required=True)
    ap.add_argument("--every", type=int, default=3)
    ap.add_argument("--no-goldens", action="store_true")
    ap.add_argument("--timeout", type=int, default=900)
    a = ap.parse_args()
    godot = next((c for c in (a.godot, os.environ.get("GODOT_BIN"), shutil.which("godot4"), shutil.which("godot")) if c and Path(c).exists()), None)
    if not godot:
        print("SLICE_TOUR SKIP no Godot binary")
        return 0
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="tw_tour_") as td:
        frames = Path(td) / "frames"
        frames.mkdir()
        env = dict(os.environ, HOME=td + "/h", XDG_DATA_HOME=td + "/d", XDG_CONFIG_HOME=td + "/c", APPDATA=td)
        cmd = []
        if not os.environ.get("DISPLAY") and shutil.which("xvfb-run"):
            cmd += ["xvfb-run", "-a", "-s", "-screen 0 720x1280x24 -nolisten tcp"]
        cmd += [godot, "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--resolution", "720x1280", "--fixed-fps", "60",
                "--path", str(GAME), "res://shell/main_v11.tscn", "--", "--slice=tour", f"--slice_out={frames}", f"--slice_every={a.every}", "--v7_hour=12"]
        p = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=a.timeout, errors="replace")
        log = p.stdout + p.stderr
        (out / "tour.log").write_text("\n".join(ln for ln in log.splitlines() if "SLICE" in ln or "ERROR" in ln) + "\n", encoding="utf-8")
        files = sorted(frames.glob("f_*.png"))
        print(f"SLICE_TOUR {len(files)} frames")
        if not files:
            print(log[-1500:])
            return 1
        n = 24
        pick = [files[round(i * (len(files) - 1) / (n - 1))] for i in range(n)] if len(files) > n else files
        sheet(pick, 6, 240, out / "tour_contact.png")
        if shutil.which("ffmpeg"):
            fps = 60 // a.every
            r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps), "-i", str(frames / "f_%05d.png"),
                                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "26", "-vf", "scale=540:-2", str(out / "tour.mp4")],
                               capture_output=True, text=True)
            print("SLICE_TOUR video:", "ok" if r.returncode == 0 else r.stderr[-300:])
        else:
            print("SLICE_TOUR no ffmpeg: contact sheet only")
    if not a.no_goldens:
        sd = out / "screens"
        sd.mkdir(exist_ok=True)
        gold = GAME / "tests" / "goldens"
        small = []
        for size_dir in sorted(gold.glob("*x*")):
            for sc in SCREENS:
                f = size_dir / f"{sc}.png"
                if f.exists():
                    shutil.copyfile(f, sd / f"{size_dir.name}_{sc}.png")
        for sc in SCREENS:
            f = gold / "720x1280" / f"{sc}.png"
            if f.exists():
                small.append(f)
        if small:
            sheet(small, 6, 300, out / "screens_contact.png", SCREENS)
    return 0


if __name__ == "__main__":
    sys.exit(main())
