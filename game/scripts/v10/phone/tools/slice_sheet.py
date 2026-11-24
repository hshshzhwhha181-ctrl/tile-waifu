"""Slice a 4x2 transparent sticker sheet into 8 square 512 px webp stickers.
usage: python3 -I slice.py sheet.png out_dir id1,id2,...,id8"""
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage

src, out, ids = sys.argv[1], sys.argv[2], sys.argv[3].split(",")
os.makedirs(out, exist_ok=True)
im = Image.open(src).convert("RGBA")
a = np.array(im)[:, :, 3]
mask = a > 24
mask = ndimage.binary_closing(mask, iterations=6)
lab, n = ndimage.label(mask)
objs = ndimage.find_objects(lab)
sizes = ndimage.sum(mask, lab, range(1, n + 1))
cands = []
for i, sl in enumerate(objs):
    if sizes[i] < 150:
        continue
    cands.append((sl, sizes[i], i + 1))
H, W = mask.shape
# a component wider than ~1.4 cells is two stickers touching: cut it at the emptiest column near the cell border
nxt = n + 1
fixed = []
for sl, sz, li in cands:
    w = sl[1].stop - sl[1].start
    if w > 1.4 * W / 4 and sz > 0.01 * mask.size:
        sub = (lab[sl] == li)
        cols = sub.sum(axis=0)
        x0 = sl[1].start
        border = round(((sl[1].start + sl[1].stop) / 2) / (W / 4)) * (W / 4)
        lo, hi = int(border - 160 - x0), int(border + 160 - x0)
        lo, hi = max(lo, 1), min(hi, len(cols) - 1)
        cut = lo + int(np.argmin(cols[lo:hi]))
        region = lab[sl]
        right = np.zeros_like(region, dtype=bool)
        right[:, cut:] = True
        region[(region == li) & right] = nxt
        lab[sl] = region
        print("split component at x", x0 + cut)
        fixed.append((sl, sz, li))
        fixed.append((sl, sz, nxt))
        nxt += 1
    else:
        fixed.append((sl, sz, li))
cands = []
for _, sz, li in fixed:
    ys, xs = np.nonzero(lab == li)
    cands.append(((slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1)), sz, li))
# assign each big component to a grid cell by its centre; merge components in the same cell
cells = {}
for sl, sz, li in cands:
    ys_, xs_ = np.nonzero(lab[sl] == li)
    cy = sl[0].start + ys_.mean()
    cx = sl[1].start + xs_.mean()
    key = (int(cy / (H / 2)), int(cx / (W / 4)))
    cells.setdefault(key, []).append(li)
print("components", len(cands), "cells", sorted(cells))
arr = np.array(im)
for r in range(2):
    for c in range(4):
        sid = ids[r * 4 + c]
        if (r, c) not in cells:
            print("MISSING", sid)
            continue
        m = np.isin(lab, cells[(r, c)])
        # keep small satellites (sparkles, steam) that lie inside the cell
        ys, xs = np.nonzero(m)
        by0, by1, bx0, bx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        crop = arr[by0:by1, bx0:bx1].copy()
        crop[:, :, 3] = np.where(m[by0:by1, bx0:bx1], crop[:, :, 3], 0)
        ci = Image.fromarray(crop)
        side = int(max(ci.size) * 1.04)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.paste(ci, ((side - ci.size[0]) // 2, (side - ci.size[1]) // 2))
        sq = sq.resize((512, 512), Image.LANCZOS)
        sq.save(os.path.join(out, sid + ".webp"), "WEBP", quality=90, method=6)
        print(sid, (bx0, by0, bx1, by1))
