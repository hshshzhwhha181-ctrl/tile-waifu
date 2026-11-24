#!/usr/bin/env python3
"""v10/mj/look: bake the tile maps used by the material shaders.
  body3.png  — from assets/v06/board/tile_body.png: R shade, G layer (0 slab · 0.5 seam · 1 back), B gloss
  grain.png  — 256² tileable fbm noise (material grain: crackle, veins, bone, ice, amber)
  badge_*.png are not needed: the contrast badge is drawn with draw_* calls.
usage: python3 make_tile_maps.py <game_dir>"""
import sys, os
import numpy as np
from PIL import Image

game = sys.argv[1] if len(sys.argv) > 1 else "."
out = os.path.join(game, "assets/v10/mj/look/tile")
os.makedirs(out, exist_ok=True)

b = np.array(Image.open(os.path.join(game, "assets/v06/board/tile_body.png")).convert("RGBA")).astype(np.float32)
g = b[..., 1] > 127
slab = (~g) & (b[..., 3] > 0)
seam = np.zeros_like(g)
# seam: back pixels within 3 px below/right of a slab pixel (the inlay line between the slab and the back)
for dy in range(1, 4):
    sh = np.zeros_like(slab)
    sh[dy:, :] = slab[:-dy, :]
    seam |= sh & g
for dx in range(1, 3):
    sh = np.zeros_like(slab)
    sh[:, dx:] = slab[:, :-dx]
    seam |= sh & g
G = np.where(g, 255, 0).astype(np.float32)
G[seam] = 128
o = b.copy()
o[..., 1] = G
Image.fromarray(o.clip(0, 255).astype(np.uint8), "RGBA").save(os.path.join(out, "body3.png"))

# tileable fbm noise
rng = np.random.default_rng(1010)
N = 256
acc = np.zeros((N, N), np.float32)
amp = 1.0
tot = 0.0
for octave in range(6):
    f = 4 * 2 ** octave
    lat = rng.random((f, f)).astype(np.float32)
    # bicubic-ish upsample with wrap
    xs = np.arange(N) * f / N
    x0 = np.floor(xs).astype(int)
    t = xs - x0
    t = t * t * (3 - 2 * t)
    x1 = (x0 + 1) % f
    rows = lat[:, x0] * (1 - t) + lat[:, x1] * t          # f × N
    up = rows[x0, :] * (1 - t)[:, None] + rows[x1, :] * t[:, None]
    acc += up * amp
    tot += amp
    amp *= 0.55
acc /= tot
acc = (acc - acc.min()) / (acc.max() - acc.min())
img = np.stack([acc * 255] * 3 + [np.full_like(acc, 255)], -1).astype(np.uint8)
Image.fromarray(img, "RGBA").save(os.path.join(out, "grain.png"))
print("ok", out)
