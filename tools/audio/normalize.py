#!/usr/bin/env python3
"""Bring audio files to the GDD s8.1 loudness targets (companion of lufs_gate.py; same meter).

  python tools/audio/normalize.py FILE|DIR ... --kind voice --out OUT_DIR          # dry run unless --out/--inplace given
  python tools/audio/normalize.py game/assets/voice --kind voice --report          # only print what would change

Per file: measure (lufs_gate.measure_array), apply ONE linear gain to hit the target integrated LUFS
(music -16, voice -14, override with --target), but never let the true peak exceed --tp (default -1.0 dBTP):
if the target is unreachable under that ceiling the gain is limited and the file is reported as "limited"
(fix the source, do not squash it). --trim-lead cuts leading silence down to --keep-ms (voice default 10 ms) so
the <=40 ms start rule holds. Output is re-encoded with ffmpeg in the input's format (ogg q4 / mp3 q2 / wav 16-bit);
mono stays mono. Nothing is overwritten unless --inplace is passed.
Dependencies: python3, numpy, ffmpeg (libvorbis / libmp3lame for ogg / mp3 output).
"""
from __future__ import annotations

import argparse
import math
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lufs_gate as G  # noqa: E402

TARGET = {"music": -16.0, "voice": -14.0}


def plan(x: np.ndarray, fs: int, target: float, tp_ceiling: float, trim_lead: bool, keep_ms: float, basis: str = "file"):
    """Return (processed array, info dict). `basis` "play" targets the mono-duplicated loudness (see lufs_gate.MONO_BASIS)."""
    info = {"trimmed_ms": 0.0}
    if trim_lead:
        lead = G.leading_silence_ms(x, fs, G.TH["lead_thr_db"])
        cut = max(0.0, lead - keep_ms)
        if cut > 0:
            x = x[int(round(cut * fs / 1000)):]
            info["trimmed_ms"] = round(cut, 1)
    lu = G.loudness(x, fs)
    if basis == "play" and x.shape[1] == 1:
        lu += 10 * math.log10(2)
    if not math.isfinite(lu):
        info.update(status="silent", gain_db=0.0)
        return x, info
    tp = G.true_peak_db(x)
    want = target - lu
    ceil = tp_ceiling - tp
    gain = min(want, ceil)
    info.update(before_lufs=round(lu, 2), before_tp=round(tp, 2), gain_db=round(gain, 2),
                status="limited" if ceil < want - 0.05 else ("ok" if abs(want) > 0.05 else "unchanged"))
    y = x * 10 ** (gain / 20)
    info["after_lufs"] = round(lu + gain, 2)
    info["after_tp"] = round(tp + gain, 2)
    return y, info


def encode(y: np.ndarray, fs: int, out: Path, suffix: str) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    codec = {".ogg": ["-c:a", "libvorbis", "-q:a", "4"], ".mp3": ["-c:a", "libmp3lame", "-q:a", "2"],
             ".wav": ["-c:a", "pcm_s16le"]}[suffix]
    cmd = ["ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "f32le", "-ar", str(fs), "-ac", str(y.shape[1]), "-i", "-"] + codec + [str(out)]
    p = subprocess.run(cmd, input=y.astype("<f4").tobytes(), capture_output=True)
    if p.returncode != 0:
        raise RuntimeError(p.stderr.decode("utf-8", "replace")[-200:])


def process(src: Path, dst: Path | None, kind: str, target: float, tp: float, trim: bool, keep_ms: float) -> dict:
    x, fs = G.decode(str(src))
    basis = G.MONO_BASIS.get(kind, "file")
    y, info = plan(x, fs, target, tp, trim, keep_ms, basis)
    if dst is not None and info["status"] != "silent":
        encode(y, fs, dst, dst.suffix.lower())
    return info


def selftest() -> int:
    ok = total = 0

    def chk(c, m):
        nonlocal ok, total
        total += 1
        ok += bool(c)
        print(("  ok   " if c else "FAIL   ") + m)

    fs = 48000
    x = G._sine(997, -30, 2.0, fs).reshape(-1, 1)
    y, i = plan(x, fs, -14.0, -1.0, False, 10)
    chk(abs(G.loudness(y, fs) + 14.0) < 0.05 and i["status"] == "ok", f"gain-only normalisation reaches -14 LUFS (got {G.loudness(y, fs):.2f}, {i['status']})")
    x = np.concatenate([np.zeros(int(fs * 0.08)), G._sine(997, -30, 1.0, fs)]).reshape(-1, 1)
    y, i = plan(x, fs, -14.0, -1.0, True, 10)
    chk(abs(G.leading_silence_ms(y, fs, G.TH["lead_thr_db"]) - 10) < 1.5 and i["trimmed_ms"] > 60, f"80 ms lead trimmed to ~10 ms ({i['trimmed_ms']} ms cut)")
    # impulsive signal: loud peaks but low loudness -> target unreachable under the true-peak ceiling
    n = np.zeros(fs * 2)
    n[::4800] = 0.9
    n += G._sine(997, -50, 2.0, fs)
    y, i = plan(n.reshape(-1, 1), fs, -14.0, -1.0, False, 10)
    chk(i["status"] == "limited" and G.true_peak_db(y) <= -0.95, f"true-peak ceiling wins over loudness target (status {i['status']}, tp {G.true_peak_db(y):.2f})")
    x = G._sine(997, -26, 2.0, fs).reshape(-1, 1)
    with tempfile.TemporaryDirectory() as td:
        a, b = Path(td) / "a.wav", Path(td) / "b.ogg"
        G.write_wav(a, x, fs)
        info = process(a, b, "voice", -14.0, -1.0, False, 10)
        got = G.measure_file(str(b))["lufs"] if b.exists() else math.nan
        chk(b.exists() and abs(got + 14.0) <= 0.3, f"wav -> ogg round trip lands on -14 LUFS (got {got:.2f})")
    print(f"NORMALIZE SELFTEST {ok}/{total}")
    return 0 if ok == total else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--kind", choices=["music", "voice"], default="voice")
    ap.add_argument("--target", type=float, help="LUFS target (default music -16 / voice -14)")
    ap.add_argument("--tp", type=float, default=-1.0, help="true-peak ceiling in dBTP")
    ap.add_argument("--trim-lead", action="store_true", help="cut leading silence down to --keep-ms")
    ap.add_argument("--keep-ms", type=float, default=10.0)
    ap.add_argument("--out", help="write normalised copies here (same relative names)")
    ap.add_argument("--inplace", action="store_true", help="overwrite the sources (git is the undo)")
    ap.add_argument("--report", action="store_true", help="dry run: print the plan only")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if not a.paths:
        ap.error("no input paths")
    target = a.target if a.target is not None else TARGET[a.kind]
    files = []
    roots = []
    for p in a.paths:
        pp = Path(p)
        if pp.is_dir():
            fs_ = [f for f in sorted(pp.rglob("*")) if f.suffix.lower() in G.AUDIO_EXT]
            files += [(f, f.relative_to(pp)) for f in fs_]
        else:
            files.append((pp, Path(pp.name)))
    for f, rel in files:
        dst = None
        if not a.report:
            if a.inplace:
                dst = f
            elif a.out:
                dst = Path(a.out) / rel
        try:
            if dst is not None and dst == f:
                with tempfile.TemporaryDirectory() as td:
                    tmp = Path(td) / f.name
                    info = process(f, tmp, a.kind, target, a.tp, a.trim_lead, a.keep_ms)
                    if tmp.exists():
                        tmp.replace(f)
            else:
                info = process(f, dst, a.kind, target, a.tp, a.trim_lead, a.keep_ms)
        except Exception as e:  # noqa: BLE001
            print(f"ERROR {f}: {e}")
            continue
        print(f"{info['status']:9s} {f}  " + "  ".join(f"{k}={v}" for k, v in info.items() if k != "status"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
