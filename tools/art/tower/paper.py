"""Procedural seamless washi paper texture (512x512) for the tower track.

Everything is periodic on the 512 torus: noise is FFT-filtered white noise, fibers are
drawn on a 3x3 tiled canvas and folded back, so the texture tiles without seams.
Usage: python3 tools/art/tower/paper.py <out.webp> [seed]
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

N = 512


def periodic_noise(rng, lo, hi):
	"""Band-pass filtered white noise, periodic, normalized to [-1, 1]."""
	w = rng.standard_normal((N, N))
	f = np.fft.fft2(w)
	fy = np.fft.fftfreq(N)[:, None] * N
	fx = np.fft.fftfreq(N)[None, :] * N
	r = np.sqrt(fx * fx + fy * fy)
	mask = np.exp(-((r / hi) ** 2)) * (1.0 - np.exp(-((r / max(lo, 1e-3)) ** 2)))
	n = np.real(np.fft.ifft2(f * mask))
	n -= n.mean()
	return n / (np.abs(n).max() + 1e-9)


def fiber_layer(rng, count, length, width, ss=2):
	"""Thin curved fibers on a tiled canvas, folded back to one periodic tile (alpha 0..1)."""
	S = N * ss
	big = Image.new("L", (S * 3, S * 3), 0)
	d = ImageDraw.Draw(big)
	for _ in range(count):
		x, y = rng.uniform(S, 2 * S), rng.uniform(S, 2 * S)
		ang = rng.uniform(0, np.pi)
		L = rng.uniform(length[0], length[1]) * ss
		steps = max(4, int(L / (6 * ss)))
		val = int(rng.uniform(70, 255))
		wd = max(1, int(round(rng.uniform(width[0], width[1]) * ss)))
		pts = []
		for _ in range(steps):
			pts.append((x, y))
			ang += rng.normal(0, 0.18)
			x += np.cos(ang) * L / steps
			y += np.sin(ang) * L / steps
		d.line(pts, fill=val, width=wd, joint="curve")
	a = np.asarray(big, dtype=np.float32) / 255.0
	tile = np.zeros((S, S), np.float32)
	for i in range(3):
		for j in range(3):
			tile = np.maximum(tile, a[i * S:(i + 1) * S, j * S:(j + 1) * S])
	img = Image.fromarray((tile * 255).astype(np.uint8)).resize((N, N), Image.LANCZOS)
	return np.asarray(img, dtype=np.float32) / 255.0


def main():
	out = sys.argv[1]
	seed = int(sys.argv[2]) if len(sys.argv) > 2 else 7
	rng = np.random.default_rng(seed)
	base = np.array([239, 228, 208], np.float32)  # warm ivory, a shade under paper.100 #F5EAD8
	cloud = periodic_noise(rng, 0.5, 4.0)      # large soft mottling
	mid = periodic_noise(rng, 6.0, 28.0)       # pulp clouds
	grain = periodic_noise(rng, 60.0, 200.0)   # fine tooth
	lum = 1.0 + 0.016 * cloud + 0.016 * mid + 0.022 * grain
	img = base[None, None, :] * lum[..., None]
	# long kozo fibers: slightly lighter, slightly translucent
	f_long = fiber_layer(rng, 170, (80, 300), (0.7, 1.6))
	# short dense fibers: slightly darker
	f_short = fiber_layer(rng, 1100, (10, 50), (0.5, 1.0))
	img = img * (1.0 - 0.10 * f_short[..., None]) + np.array([150, 128, 96], np.float32) * 0.10 * f_short[..., None]
	img = img * (1.0 - 0.22 * f_long[..., None]) + np.array([253, 249, 240], np.float32) * 0.22 * f_long[..., None]
	# a few faint bark specks
	sp = np.zeros((N, N), np.float32)
	for _ in range(26):
		y, x = rng.integers(0, N, 2)
		r = rng.uniform(0.6, 1.6)
		yy, xx = np.ogrid[:N, :N]
		dy = np.minimum(np.abs(yy - y), N - np.abs(yy - y))
		dx = np.minimum(np.abs(xx - x), N - np.abs(xx - x))
		sp = np.maximum(sp, np.clip(1.0 - np.sqrt(dx * dx + dy * dy) / (r + 0.8), 0, 1) * rng.uniform(0.15, 0.35))
	img = img * (1.0 - sp[..., None]) + np.array([150, 125, 95], np.float32) * sp[..., None]
	img = np.clip(img, 0, 255).astype(np.uint8)
	Image.fromarray(img, "RGB").save(out, "WEBP", quality=94, method=6)
	print("saved", out)


if __name__ == "__main__":
	main()
