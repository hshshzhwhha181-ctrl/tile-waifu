#!/usr/bin/env python3
"""Background plate for the parallax layer: remove the heroine (push-pull fill under a dilated mask),
soften (depth of field), and extend upward to cover a 9:16 screen in the cutout's own frame.

    python3 make_bg.py <art 2048.png> <body.png cutout> <out bg.png> [x0=0] [x1=1800] [ext=900]

The plate covers art x0..x1 and y -ext..H at half scale; put the matching numbers in rig_def.json
"layout" (bg_origin = (x0, -ext) * body_px_per_art_px, bg_scale = 2 * body_px_per_art_px).
The fill under her is only seen at the silhouette edges while the layers drift, so a smooth fill is
enough; the top extension is a mirrored, darkened ceiling (UI usually sits there).
"""
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

src, cut, out = sys.argv[1:4]
X0 = int(sys.argv[4]) if len(sys.argv) > 4 else 0
X1 = int(sys.argv[5]) if len(sys.argv) > 5 else 1800
EXT = int(sys.argv[6]) if len(sys.argv) > 6 else 900
im = np.asarray(Image.open(src).convert('RGB')).astype(np.float32) / 255
H, W = im.shape[:2]
a = np.asarray(Image.open(cut).split()[3].resize((W, H), Image.BILINEAR)).astype(np.float32) / 255
hole = ndi.binary_dilation(a > 0.05, iterations=18)
known = (~hole).astype(np.float32)


def pushpull(img, w):
    if min(img.shape[:2]) <= 4:
        m = (img * w[..., None]).sum((0, 1)) / max(w.sum(), 1e-6)
        return np.broadcast_to(m, img.shape).copy()
    # pull: weighted 2x downsample
    h2, w2 = (img.shape[0] + 1) // 2, (img.shape[1] + 1) // 2
    pi = np.zeros((h2 * 2, w2 * 2, 3), np.float32); pw = np.zeros((h2 * 2, w2 * 2), np.float32)
    pi[:img.shape[0], :img.shape[1]] = img * w[..., None]; pw[:img.shape[0], :img.shape[1]] = w
    si = pi.reshape(h2, 2, w2, 2, 3).sum((1, 3)); sw = pw.reshape(h2, 2, w2, 2).sum((1, 3))
    small = si / np.maximum(sw, 1e-6)[..., None]
    small = pushpull(small, np.clip(sw, 0, 1))
    up = np.asarray(Image.fromarray((np.clip(small, 0, 1) * 255).astype(np.uint8)).resize((w2 * 2, h2 * 2), Image.BILINEAR)).astype(np.float32) / 255
    up = up[:img.shape[0], :img.shape[1]]
    return img * w[..., None] + up * (1 - w[..., None])


filled = pushpull(im * known[..., None], known)
# soften the filled area further so no silhouette echo remains
blur = np.asarray(Image.fromarray((filled * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(24))).astype(np.float32) / 255
hm = ndi.gaussian_filter(hole.astype(np.float32), 20)
filled = filled * (1 - hm[..., None]) + blur * hm[..., None]
img = Image.fromarray((np.clip(filled, 0, 1) * 255).astype(np.uint8))
# depth of field + slight dim so the heroine pops
img = img.filter(ImageFilter.GaussianBlur(2.2))
arr = np.asarray(img).astype(np.float32) * 0.92
img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
# portrait plate in the same frame as the cutout, top extended by EXT mirrored rows; saved at 0.5 scale
x0, x1 = X0, X1
base = np.asarray(img).astype(np.float32)[:, x0:x1]
mir = base[1:EXT + 1][::-1]
mirb = np.asarray(Image.fromarray(mir.astype(np.uint8)).filter(ImageFilter.GaussianBlur(10))).astype(np.float32)
d = (EXT - np.arange(EXT)[:, None, None]) / EXT  # 1 at top, 0 at seam
mirb = mirb * (1 - 0.55 * d) + np.array([40, 26, 38], np.float32) * (0.55 * d)
plate = np.concatenate([mirb, base], 0)
# soften the seam
seam = ndi.gaussian_filter1d(plate, 6, axis=0)
w = np.exp(-((np.arange(plate.shape[0]) - EXT) / 14.0) ** 2)[:, None, None]
plate = plate * (1 - w) + seam * w
img = Image.fromarray(np.clip(plate, 0, 255).astype(np.uint8))
img = img.resize((img.width // 2, img.height // 2), Image.LANCZOS)
img.save(out)
print('bg', img.size, 'frame offset (2048px):', x0, -EXT)
