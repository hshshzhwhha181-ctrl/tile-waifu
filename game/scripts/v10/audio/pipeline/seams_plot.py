#!/usr/bin/env python3
"""Seam check sheet: waveform + spectrogram of the last 2 s + first 2 s of each loop (wrap at the red line).

  python3 game/scripts/v10/audio/pipeline/seams_plot.py out.png a.ogg b.ogg ...
"""
import os
import subprocess
import sys

import matplotlib
import numpy as np

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

SR = 22050


def main():
    out, files = sys.argv[1], sys.argv[2:]
    fig, axs = plt.subplots(len(files), 2, figsize=(14, 1.3 * len(files)), squeeze=False)
    for r, f in enumerate(files):
        raw = subprocess.run(["ffmpeg", "-v", "error", "-i", f, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                             capture_output=True, check=True).stdout
        y = np.frombuffer(raw, np.float32)
        yy = np.concatenate([y[-2 * SR:], y[:2 * SR]])
        t = np.arange(len(yy)) / SR - 2
        name = os.path.splitext(os.path.basename(f))[0]
        axs[r, 0].plot(t, yy, lw=0.3)
        axs[r, 0].axvline(0, color="r", lw=0.8)
        axs[r, 0].set_ylabel(name, rotation=0, ha="right", fontsize=8)
        axs[r, 0].set_yticks([])
        axs[r, 1].specgram(yy, Fs=SR, NFFT=1024, noverlap=768, cmap="magma")
        axs[r, 1].axvline(2, color="c", lw=0.8)
        axs[r, 1].set_yticks([])
    plt.tight_layout()
    plt.savefig(out, dpi=60)


if __name__ == "__main__":
    main()
