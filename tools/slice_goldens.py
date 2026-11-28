#!/usr/bin/env python3
"""Screen goldens of the vertical slice (P37 / WP10d).

Six screens (home, match, result, collection, wish, shop) x three sizes (720x1280, 720x1600, 1536x2048) are rendered by the game itself
(`res://shell/main_v11.tscn -- --slice=goldens`, shell/tests/slice_goldens.gd; xvfb + opengl3 + --fixed-fps 60, a frozen calendar, a fresh
save) and compared with game/tests/goldens/<WxH>/<screen>.png. A screen passes while at most 1.5 % of its pixels differ by more than THR
(24/255) in any channel.

Live art is not a golden: the home heroine breathes (V10LiveRig runs on real frames, the phase of two runs differs by a few frames). `--update`
therefore renders every screen twice and records the pixels that differ between the two renders (dilated by 4 px) as
`<screen>.mask.png` next to the golden; masked pixels are ignored by the comparison (the share of the screen a mask may cover is capped at
MASK_MAX = 20 %). A screen without live art has no mask file.

  python tools/slice_goldens.py                  compare (exit 0 = all within the tolerance)
  python tools/slice_goldens.py --update         re-record the goldens (do it when a screen changes ON PURPOSE; look at the diff sheet first)
  python tools/slice_goldens.py --sizes 720x1280 --screens home,shop
  python tools/slice_goldens.py --twice          render every size twice and report actual-vs-actual (the flake floor of the harness)
  python tools/slice_goldens.py --out DIR        keep actual PNGs, diff sheets (golden | actual | diff) and results.json in DIR

Prints `SLICE_GOLDENS ok/total` (judged by tools/tw_test.py as suite `slice_goldens`). Needs Godot (GODOT_BIN / --godot), xvfb-run,
numpy and Pillow; without them it exits 0 with `SLICE_GOLDENS SKIP <reason>` (tw_test shows that as skip).
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
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GAME = REPO / "game"
GOLD = GAME / "tests" / "goldens"
SIZES = ["720x1280", "720x1600", "1536x2048"]
SCREENS = ["home", "match", "result", "collection", "wish", "shop"]
TOL = 0.015          # share of pixels that may differ
THR = 24             # per-channel difference (0-255) that counts as "differs"
MASK_MAX = 0.20      # a mask (the live art of a screen) may cover at most this share of the pixels
MASK_MIN = 0.0005    # below this the two renders are "the same": no mask file
MASK_GROW = 4        # px


def find_godot(arg: str | None) -> str | None:
    for c in (arg, os.environ.get("GODOT_BIN"), shutil.which("godot4"), shutil.which("godot")):
        if c and Path(c).exists():
            return str(c)
    return None


def render(godot: str, size: str, out: Path, timeout: int) -> tuple[int, str]:
    w, h = size.split("x")
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="tw_slice_home_") as home:
        env = dict(os.environ, HOME=home, XDG_DATA_HOME=home + "/d", XDG_CONFIG_HOME=home + "/c", XDG_CACHE_HOME=home + "/k", APPDATA=home)
        cmd = []
        if not os.environ.get("DISPLAY") and shutil.which("xvfb-run"):
            cmd += ["xvfb-run", "-a", "-s", f"-screen 0 {w}x{h}x24 -nolisten tcp"]
        cmd += [godot, "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--resolution", size, "--fixed-fps", "60",
                "--path", str(GAME), "res://shell/main_v11.tscn", "--", "--slice=goldens", f"--slice_out={out}"]
        try:
            p = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=timeout, errors="replace")
            return p.returncode, p.stdout + p.stderr
        except subprocess.TimeoutExpired as e:
            return -9, (e.stdout.decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")) + "\nTIMEOUT"


def diff_ratio(a, b, mask=None):
    """(share of pixels that differ by more than THR, per-pixel max channel diff); masked pixels never count"""
    import numpy as np
    d = np.abs(a.astype(np.int16) - b.astype(np.int16)).max(axis=2)
    bad = d > THR
    if mask is not None:
        bad = bad & ~mask
    return float(bad.mean()), d


def make_mask(a, b):
    """pixels that differ between two renders of the same screen, grown by MASK_GROW px (None when the renders agree)"""
    import numpy as np
    from PIL import Image, ImageFilter
    d = np.abs(a.astype(np.int16) - b.astype(np.int16)).max(axis=2) > THR
    if d.mean() < MASK_MIN:
        return None
    im = Image.fromarray((d * 255).astype("uint8")).filter(ImageFilter.MaxFilter(2 * MASK_GROW + 1))
    return np.asarray(im) > 127


def sheet(golden, actual, d, path: Path) -> None:  # noqa
    import numpy as np
    from PIL import Image
    mask = np.zeros(golden.shape, dtype=np.uint8)
    mask[..., 0] = np.where(d > THR, 255, 0)
    mask[..., 1] = np.where(d > THR, 40, d.clip(0, 255) // 3)
    mask[..., 2] = mask[..., 1]
    row = np.concatenate([golden, actual, mask], axis=1)
    im = Image.fromarray(row)
    im.thumbnail((2400, 1400))
    im.save(path)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--godot")
    ap.add_argument("--update", action="store_true", help="write the rendered PNGs as the new goldens")
    ap.add_argument("--sizes", default=",".join(SIZES))
    ap.add_argument("--screens", default=",".join(SCREENS))
    ap.add_argument("--out", help="keep artifacts here (default: a temp dir)")
    ap.add_argument("--twice", action="store_true", help="render twice and compare actual vs actual (flake floor)")
    ap.add_argument("--tol", type=float, default=TOL)
    ap.add_argument("--timeout", type=int, default=420, help="seconds per size")
    ap.add_argument("--self-check", action="store_true", help="python-only: the comparison function on synthetic images")
    a = ap.parse_args()

    try:
        import numpy as np  # noqa: F401
        from PIL import Image
    except Exception as e:  # pragma: no cover
        print(f"SLICE_GOLDENS SKIP numpy/Pillow missing ({e})")
        return 0
    import numpy as np

    if a.self_check:
        base = np.zeros((100, 100, 3), np.uint8)
        other = base.copy()
        other[:1, :, :] = 255   # 1 row of 100 = 1.0 %
        r1, _ = diff_ratio(base, other)
        other[:2, :, :] = 255   # 2.0 %
        r2, _ = diff_ratio(base, other)
        faint = base.copy()
        faint[...] = THR      # at the threshold: not a difference
        r3, _ = diff_ratio(base, faint)
        good = abs(r1 - 0.01) < 1e-9 and abs(r2 - 0.02) < 1e-9 and r3 == 0.0 and (r1 <= TOL) and not (r2 <= TOL)
        print(f"SLICE_GOLDENS SELFCHECK {3 if good else 0}/3")
        return 0 if good else 1

    godot = find_godot(a.godot)
    if not godot:
        print("SLICE_GOLDENS SKIP no Godot binary (set GODOT_BIN or --godot)")
        return 0
    if not os.environ.get("DISPLAY") and not shutil.which("xvfb-run"):
        print("SLICE_GOLDENS SKIP needs a display and xvfb-run is not installed")
        return 0

    sizes = [s for s in a.sizes.split(",") if s]
    screens = [s for s in a.screens.split(",") if s]
    outroot = Path(a.out) if a.out else Path(tempfile.mkdtemp(prefix="tw_slice_goldens_"))
    outroot.mkdir(parents=True, exist_ok=True)
    ok = total = 0
    results: dict = {}

    def check(cond: bool, what: str) -> None:
        nonlocal ok, total
        total += 1
        if cond:
            ok += 1
        else:
            print("SLICE_GOLDENS FAIL:", what)

    for size in sizes:
        act = outroot / size / "actual"
        rc, out = render(godot, size, act, a.timeout)
        (outroot / size).mkdir(parents=True, exist_ok=True)
        (outroot / size / "run.log").write_text(out, encoding="utf-8")
        m = re.findall(r"SLICE_SELFTEST (\d+)/(\d+)", out)
        healthy = bool(m) and m[-1][0] == m[-1][1] and "SCRIPT ERROR" not in out
        check(healthy, f"{size}: the render run is healthy (marker {m[-1] if m else 'none'}, rc {rc}, script errors {out.count('SCRIPT ERROR')})")
        if a.twice or a.update:
            act2 = outroot / size / "actual2"
            render(godot, size, act2, a.timeout)
        for sc in screens:
            ap_ = act / f"{sc}.png"
            gp = GOLD / size / f"{sc}.png"
            if not ap_.exists():
                check(False, f"{size}/{sc}: no PNG rendered")
                continue
            mp = gp.with_name(sc + ".mask.png")
            if a.update:
                gp.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ap_, gp)
                b2 = act.parent / "actual2" / f"{sc}.png"
                mask = make_mask(np.asarray(Image.open(ap_).convert("RGB")), np.asarray(Image.open(b2).convert("RGB"))) if b2.exists() else None
                if mask is not None:
                    Image.fromarray((mask * 255).astype("uint8")).convert("1").save(mp, optimize=True)
                    print(f"SLICE_GOLDENS mask {mp.relative_to(REPO)}: {mask.mean() * 100:.1f} % of the screen is live art")
                    check(mask.mean() <= MASK_MAX, f"{size}/{sc}: the live-art mask covers {mask.mean() * 100:.1f} % (> {MASK_MAX * 100:.0f} %)")
                elif mp.exists():
                    mp.unlink()
                print(f"SLICE_GOLDENS updated {gp.relative_to(REPO)} ({gp.stat().st_size // 1024} KB)")
                check(True, "")
                continue
            if a.twice:
                b2 = act.parent / "actual2" / f"{sc}.png"
                if b2.exists():
                    ra, _ = diff_ratio(np.asarray(Image.open(ap_).convert("RGB")), np.asarray(Image.open(b2).convert("RGB")))
                    results.setdefault(size, {})[sc + "_flake"] = round(ra, 5)
                    print(f"SLICE_GOLDENS flake {size}/{sc}: {ra * 100:.3f} % of pixels differ between two renders")
            if not gp.exists():
                check(False, f"{size}/{sc}: no golden at {gp.relative_to(REPO)} (run with --update)")
                continue
            ga = np.asarray(Image.open(gp).convert("RGB"))
            aa = np.asarray(Image.open(ap_).convert("RGB"))
            if ga.shape != aa.shape:
                check(False, f"{size}/{sc}: size {aa.shape[1]}x{aa.shape[0]} != golden {ga.shape[1]}x{ga.shape[0]}")
                continue
            mask = np.asarray(Image.open(mp).convert("L")) > 127 if mp.exists() else None
            ratio, d = diff_ratio(ga, aa, mask)
            results.setdefault(size, {})[sc] = round(ratio, 5)
            good = ratio <= a.tol
            check(good, f"{size}/{sc}: {ratio * 100:.2f} % of pixels differ (> {a.tol * 100:.1f} %)")
            print(f"SLICE_GOLDENS {size}/{sc}: {ratio * 100:.3f} % differ ({'ok' if good else 'FAIL'})")
            if not good:
                sheet(ga, aa, d, outroot / size / f"diff_{sc}.png")
    (outroot / "results.json").write_text(json.dumps(results, indent=1), encoding="utf-8")
    print(f"SLICE_GOLDENS artifacts: {outroot}")
    print(f"SLICE_GOLDENS {ok}/{total}")
    return 0 if ok == total else 1


if __name__ == "__main__":
    sys.exit(main())
