import sys
import numpy as np
from PIL import Image
from scipy import ndimage
src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGB')
a = np.asarray(im).astype(np.float32)
H, W, _ = a.shape
# background model: per-row linear fit from the left/right border columns (soft grey gradient)
bg = np.zeros_like(a)
for y in range(H):
    l = a[y, :8].mean(0); r = a[y, -8:].mean(0)
    t = np.linspace(0, 1, W)[:, None]
    bg[y] = l * (1 - t) + r * t
d = np.sqrt(((a - bg) ** 2).sum(2))
fg = d > 18
fg = ndimage.binary_closing(fg, iterations=2)
fg = ndimage.binary_fill_holes(fg)
lab, n = ndimage.label(fg)
sizes = ndimage.sum(fg, lab, range(1, n + 1))
keep = [i + 1 for i, s in enumerate(sizes) if s > 5000]
objs = ndimage.find_objects(lab)
items = []
for k in keep:
    sl = objs[k - 1]
    cy = (sl[0].start + sl[0].stop) / 2; cx = (sl[1].start + sl[1].stop) / 2
    items.append((round(cy / (H / 2)), cx, k, sl))
items.sort(key=lambda t: (t[0], t[1]))
names = ['tsubame', 'miel', 'kohaku', 'shirin', 'zlata']
assert len(items) == 5, len(items)
for name, (_, _, k, sl) in zip(names, items):
    m = (lab == k)
    m = ndimage.binary_fill_holes(m)
    # soft alpha: core = mask eroded, edge ramp from colour distance
    core = ndimage.binary_erosion(m, iterations=1)
    edge = m & ~core
    alpha = np.where(core, 255.0, 0.0)
    alpha[edge] = np.clip((d[edge] - 6) / 30 * 255, 0, 255)
    alpha = ndimage.gaussian_filter(alpha, 0.6) * m
    pad = 4
    y0, y1 = max(sl[0].start - pad, 0), min(sl[0].stop + pad, H)
    x0, x1 = max(sl[1].start - pad, 0), min(sl[1].stop + pad, W)
    rgb = a[y0:y1, x0:x1]
    # de-matte the grey from semi-transparent edge pixels
    al = alpha[y0:y1, x0:x1][..., None] / 255.0
    bgc = bg[y0:y1, x0:x1]
    fgc = np.where(al > 0.05, (rgb - bgc * (1 - al)) / np.maximum(al, 0.05), rgb)
    rgba = np.dstack([np.clip(fgc, 0, 255), alpha[y0:y1, x0:x1]]).astype(np.uint8)
    t = Image.fromarray(rgba, 'RGBA')
    t = t.crop(t.getchannel('A').getbbox())
    s = 186 / t.height
    t = t.resize((max(1, round(t.width * s)), 186), Image.LANCZOS)
    c = Image.new('RGBA', (t.width + 6, 192), (0, 0, 0, 0))
    c.alpha_composite(t, (3, 3))
    c.save(f'{out}/sig_{name}.webp', 'WEBP', quality=92, method=6)
    print(name, c.size)
