#!/usr/bin/env python3
"""Extend Hana's stadium background plate upward with sky (make_bg.py mirrors the top, which flips the
floodlight towers upside down in an outdoor scene).

    python3 make_bg.py art.png body.png bg_raw.png 0 2048 2      # plate with no extension (0.5 scale)
    python3 sky_extend.py bg_raw.png bg.png 560                   # + 560 plate px (= 1120 art px) of sky

Each column continues upward from its own top colour (averaged over the top 40 rows), blending towards a deeper
dusk violet (2b4a7a family) near the top, blurred horizontally so nothing reads as stripes; a light grain
keeps it from banding.
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

src, dst, ext = sys.argv[1], sys.argv[2], int(sys.argv[3])
im = np.asarray(Image.open(src).convert('RGB')).astype(np.float32)
H, W = im.shape[:2]
top = ndi.gaussian_filter1d(im[2:42].mean(0), 30, axis=0)  # (W, 3)
deep = np.array([74, 72, 128], np.float32)
yy = np.arange(ext, dtype=np.float32)[:, None, None]
k = ((ext - yy) / ext) ** 1.4  # 1 at the very top, 0 at the seam
sky = top[None] * (1 - 0.75 * k) + deep * (0.75 * k)
rng = np.random.default_rng(3)
sky += rng.normal(0, 1.2, sky.shape)
plate = np.concatenate([sky, im[2:]], 0)
# soften the seam
s = ndi.gaussian_filter1d(plate, 8, axis=0)
w = np.exp(-((np.arange(plate.shape[0]) - ext) / 18.0) ** 2)[:, None, None]
plate = plate * (1 - w) + s * w
Image.fromarray(np.clip(plate, 0, 255).astype(np.uint8)).save(dst, optimize=True)
print('bg', plate.shape[1], plate.shape[0], 'top extension', ext, 'plate px')
