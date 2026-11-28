#!/usr/bin/env python3
"""P25 / WP8c acceptance: `--shell=v11` shows the v10 screens pixel-identical.

For each screen it captures a 720x1280 frame with the same dev args (`--screen= --shots= --at=`) three times: twice on the default
launch (main.tscn, flag OFF) and once with `--shell=v11` (main.tscn hands over to shell/main_v11.tscn = LegacyHost). The share of pixels
whose (4x4-averaged) max channel difference is > THRESH must be <= LIMIT (0.5 % of the area).

A screen with idle animation (petals, the pulsing tab icon, a lobby video) differs from ITSELF between two v10 runs, so the second v10
capture is the control: v11 passes when it is within LIMIT strictly, or within LIMIT of that control difference.

`--fixed-fps 30` makes engine time (shader TIME: the backdrop drift) a function of the frame count, not of the machine speed, so the extra
scene load of the `--shell=v11` hand-over shifts the animation phase by frames, not by seconds.

  python3 tools/legacy_host_shots.py                              # 6 screens, one line per screen, exit 0 = all pass
  python3 tools/legacy_host_shots.py -s home,shop --keep /tmp/x   # chosen screens, keep the PNGs

Needs GODOT_BIN, xvfb-run (or a DISPLAY), Pillow + numpy.
"""
import argparse, os, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
SCREENS = ["home", "collection", "summon", "shop", "modes", "profile"]
PER_SCREEN = {"home": ["--outfit=o_dragon"]}  # home in «art» mode (her painting) instead of the animated lobby video
LIMIT = 0.5      # percent of the pixels allowed to differ
BOX = 4          # averaging window in px
THRESH = 16      # per-channel difference (0..255) of the averaged pixels below which they count as equal


def capture(godot: str, screen: str, v11: bool, out: Path, at: float, extra=()) -> bool:
    with tempfile.TemporaryDirectory(prefix="tw_hs_") as td:
        tmp = Path(td)
        shots = tmp / "shots"
        shots.mkdir()
        env = dict(os.environ, HOME=str(tmp), APPDATA=str(tmp), XDG_DATA_HOME=str(tmp / "d"), XDG_CONFIG_HOME=str(tmp / "c"),
                   XDG_CACHE_HOME=str(tmp / "k"))
        cmd = []
        if not os.environ.get("DISPLAY") and shutil.which("xvfb-run"):
            cmd += ["xvfb-run", "-a", "-s", "-screen 0 1600x2700x24"]
        cmd += [godot, "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--resolution", "720x1280", "--fixed-fps", "30", "--path", str(GAME), "--",
                f"--screen={screen}", f"--shots={shots}", "--name=cap", f"--at={at}", "--unlock=50",
                "--save=user://hs_save.json", "--save_wipe=1", "--story_off=1"]
        cmd += list(extra)
        if v11:
            cmd.append("--shell=v11")
        try:
            subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
        except subprocess.TimeoutExpired:
            return False
        png = shots / "cap_0.png"
        if not png.exists():
            return False
        shutil.copy(png, out)
        return True


def diff_pct(a: Path, b: Path) -> float:
    """share (%) of the 4x4 box-averaged pixels whose max channel differs by more than THRESH. The averaging removes what is not layout:
    the petal particles (random positions on every run, v10 against v10 too) and the sub-pixel edge motion of a swaying hero."""
    import numpy as np
    from PIL import Image
    ia = Image.open(a).convert("RGB")
    ib = Image.open(b).convert("RGB")
    if ia.size != ib.size:
        return 100.0
    sz = (ia.size[0] // BOX, ia.size[1] // BOX)
    xa = np.asarray(ia.resize(sz, Image.BOX), dtype=np.int16)
    xb = np.asarray(ib.resize(sz, Image.BOX), dtype=np.int16)
    bad = (np.abs(xa - xb).max(axis=2) > THRESH)
    return 100.0 * float(bad.sum()) / bad.size


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("-s", "--screens", default=",".join(SCREENS))
    ap.add_argument("--at", type=float, default=2.5)
    ap.add_argument("--keep", default="")
    ap.add_argument("--extra", default="", help="extra dev args for every capture, written as --extra=--modest=1")
    ap.add_argument("--noise", action="store_true", help="self-test of the control: v10 against v10 instead of v11")
    ap.add_argument("--godot", default=os.environ.get("GODOT_BIN", ""))
    a = ap.parse_args()
    if not a.godot:
        print("LEGACY_SHOTS: no GODOT_BIN")
        return 2
    out = Path(a.keep) if a.keep else Path(tempfile.mkdtemp(prefix="tw_hs_out_"))
    out.mkdir(parents=True, exist_ok=True)
    ok_n, ids = 0, [s for s in a.screens.split(",") if s]
    for sid in ids:
        pa, pa2, pb = out / f"{sid}_v10.png", out / f"{sid}_v10b.png", out / f"{sid}_v11.png"
        ex = a.extra.split() + PER_SCREEN.get(sid, [])
        # order v10, v11, v10: the control spans twice the wall-clock gap of the pair under test, so a slow time-of-day tint
        # (V7DayNight follows the real clock) cannot count against v11
        if not (capture(a.godot, sid, False, pa, a.at, ex) and capture(a.godot, sid, not a.noise, pb, a.at, ex)
                and capture(a.godot, sid, False, pa2, a.at, ex)):
            print(f"LEGACY_SHOTS {sid}: capture FAILED")
            continue
        d, ctrl = diff_pct(pa, pb), diff_pct(pa, pa2)
        good = d <= LIMIT or d <= ctrl + LIMIT
        how = "strict" if d <= LIMIT else "vs control"
        ok_n += good
        print(f"LEGACY_SHOTS {sid}: v11 vs v10 {d:.4f}% | v10 vs v10 control {ctrl:.4f}% -> "
              f"{'ok (' + how + ')' if good else 'OVER'} (limit {LIMIT}%)", flush=True)
    print(f"LEGACY_SHOTS RESULT {ok_n}/{len(ids)} within {LIMIT}%")
    if not a.keep:
        shutil.rmtree(out, ignore_errors=True)
    return 0 if ok_n == len(ids) else 1


if __name__ == "__main__":
    sys.exit(main())
