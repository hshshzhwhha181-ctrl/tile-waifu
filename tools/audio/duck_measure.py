#!/usr/bin/env python3
"""Independent cross-check of the TWAudio ducking proof (P30, GDD V11 8.5).

The Godot selftest (shell/audio/audio_selftest.gd) renders the duck envelope onto a -20 dBFS 440 Hz tone and measures it in
GDScript. This script re-measures the same WAV with numpy so the number does not depend on the code that produced it.

  python3 tools/audio/duck_measure.py WAV [--on 0.5] [--off 2.0]
  prints  DUCK_MEASURE depth_db=-8.00 attack_ms=72.5 release_ms=367.5 PASS|FAIL   (exit 1 on FAIL)

depth = plateau level vs the level before --on; attack = time to 95% of the depth; release = time back within 5% of 0 dB;
levels are RMS over 5 ms windows. Limits (acceptance of P30): depth 8 +-1 dB, attack 80 +-20 ms, release 400 +-60 ms.
"""
import argparse
import sys
import wave

import numpy as np


def measure(path, t_on, t_off):
    with wave.open(path, "rb") as w:
        rate = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
    win = int(rate * 0.005)
    n = len(x) // win
    lv = 10 * np.log10(np.maximum((x[: n * win].reshape(n, win) ** 2).mean(axis=1), 1e-12))
    t0 = np.arange(n) * win / rate
    base = lv[(t0 + win / rate) <= t_on - 0.02].mean()
    rel = lv - base
    plateau = rel[(t0 >= t_on + 0.2) & ((t0 + win / rate) <= t_off - 0.02)].mean()
    a = np.where((t0 >= t_on - 0.01) & (rel <= plateau * 0.95))[0][0]
    r = np.where((t0 >= t_off) & (rel >= plateau * 0.05))[0][0]
    half = win / rate / 2
    return plateau, (t0[a] + half - t_on) * 1000, (t0[r] + half - t_off) * 1000


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("wav")
    ap.add_argument("--on", type=float, default=0.5)
    ap.add_argument("--off", type=float, default=2.0)
    a = ap.parse_args()
    depth, att, rel = measure(a.wav, a.on, a.off)
    ok = abs(depth + 8) <= 1 and abs(att - 80) <= 20 and abs(rel - 400) <= 60
    print("DUCK_MEASURE depth_db=%.2f attack_ms=%.1f release_ms=%.1f %s" % (depth, att, rel, "PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
