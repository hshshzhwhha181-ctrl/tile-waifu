"""Modal synthesis of the soft temple gong (sfx/gong.ogg).

Both Higgsfield gong takes were rejected (one a flat sine hum without attack or decay, one a tinny
bell tick), so the gong is synthesized: inharmonic partials as slowly beating doublets, exponential
decays (low partials ring longest), a low-passed felt-mallet thump, a smooth tail fade.
Usage: python3 gong.py out_dry.wav, then (sox):
  sox out_dry.wav g1.wav reverb 22 40 55 0 8 -8
  sox g1.wav g2.wav highpass 60 silence 1 0.005 -60d reverse silence 1 0.01 -60d reverse
  sox g2.wav gong.wav gain -n -6.5
  ffmpeg -i gong.wav -ac 1 -ar 44100 -c:a libvorbis -q:a 5 gong.ogg
"""
import sys
import wave

import numpy as np

sr = 44100
dur = 2.45
n = int(sr * dur)
t = np.arange(n) / sr
rng = np.random.default_rng(11)
f0 = 196.0  # G3: warm but still present on phone speakers
P = [  # ratio, amp, T60 s, beat Hz
	(1.00, 1.00, 4.2, 0.55), (1.51, 0.30, 3.2, 0.8), (2.02, 0.62, 3.0, 1.1), (2.76, 0.48, 2.5, 0.9),
	(3.52, 0.26, 1.9, 1.6), (4.41, 0.22, 1.4, 1.3), (5.43, 0.12, 1.0, 2.0), (6.58, 0.07, 0.7, 2.4),
	(8.10, 0.04, 0.45, 3.1)]
y = np.zeros(n)
for r, a, t60, beat in P:
	f = f0 * r
	dec = 10 ** (-3 * t / t60)
	att = np.clip(t / (0.004 + 0.010 / r), 0, 1)
	att = 0.5 - 0.5 * np.cos(np.pi * att)
	ph1, ph2 = rng.uniform(0, 2 * np.pi, 2)
	s = 0.55 * np.sin(2 * np.pi * f * t + ph1) + 0.45 * np.sin(2 * np.pi * (f + beat) * t + ph2)
	y += a * dec * att * s
# felt mallet thump: 25 ms of low-passed noise
k = int(0.025 * sr)
nz = rng.standard_normal(k)
for _ in range(4):
	out = np.zeros(k)
	acc = 0.0
	for i in range(k):
		acc += 0.12 * (nz[i] - acc)
		out[i] = acc
	nz = out
nz *= np.hanning(2 * k)[k:] ** 2
y[:k] += 0.35 * nz / (np.abs(nz).max() + 1e-9)
fl = int(0.7 * sr)
y[-fl:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, fl))
y /= np.abs(y).max()
w = wave.open(sys.argv[1], "w")
w.setnchannels(1)
w.setsampwidth(2)
w.setframerate(sr)
w.writeframes((y * 0.9 * 32767).astype(np.int16).tobytes())
w.close()
