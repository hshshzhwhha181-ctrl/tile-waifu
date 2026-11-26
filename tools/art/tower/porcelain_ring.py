"""Adds a faint porcelain ring (cup modes) after the crack of heart_break, so it reads as porcelain.
Usage: python3 porcelain_ring.py in.wav out.wav <crack_time_s>   (mono 16-bit wav)"""
import sys
import wave

import numpy as np

w = wave.open(sys.argv[1])
sr = w.getframerate()
n = w.getnframes()
x = np.frombuffer(w.readframes(n), np.int16).astype(np.float32) / 32768
t = np.arange(n) / sr
t0 = float(sys.argv[3])
tt = np.clip(t - t0, 0, None)
ring = np.zeros(n)
for f, a, t60 in [(1901, 1.0, 0.55), (2954, 0.6, 0.42), (4610, 0.35, 0.3), (6120, 0.2, 0.22)]:
	ring += a * np.sin(2 * np.pi * f * tt) * 10 ** (-3 * tt / t60) * np.clip(tt / 0.002, 0, 1)
ring[t < t0] = 0
y = x + 0.035 * ring / np.abs(ring).max()
o = wave.open(sys.argv[2], "w")
o.setnchannels(1)
o.setsampwidth(2)
o.setframerate(sr)
o.writeframes((np.clip(y, -1, 1) * 32767).astype(np.int16).tobytes())
o.close()
