#!/usr/bin/env python3
"""Slice the Higgsfield sheets of Лавка 2 into item sprites and convert the backgrounds.

usage: python3 prep_art.py <raw_dir> <out_dir>
raw_dir holds moon_sheet.png, items_sheet.png, ladder_sheet.png (3x2 grids, transparent),
bg_shop.png, bg_age.png (9:16) and bg_pass.png (21:9). Job ids: art_jobs.tsv next to this script.
"""
import sys
import numpy as np
from scipy import ndimage
from PIL import Image, ImageFilter

RAW, OUT = sys.argv[1], sys.argv[2]
SHEETS = {
    "moon_sheet.png": ["moon_1", "moon_2", "moon_3", "moon_4", "moon_5", "moon_6"],
    "items_sheet.png": ["item_crystal", "item_wish", "item_petal", "item_gift", "item_month", "item_pass"],
    "ladder_sheet.png": ["set_cup", "set_guest", "set_novice", "set_growth", "set_traveler", "hanko"],
    "extra_sheet.png": ["item_coin", "item_tea", "item_frame", "boost_lantern", "boost_wind", "boost_scroll"],
}

import os
for f, names in SHEETS.items():
    if not os.path.exists(f"{RAW}/{f}"):
        continue
    im = Image.open(f"{RAW}/{f}").convert("RGBA")
    W, H = im.size
    cw, ch = W // 3, H // 2
    for i, n in enumerate(names):
        c = im.crop(((i % 3) * cw, (i // 3) * ch, (i % 3 + 1) * cw, (i // 3 + 1) * ch))
        arr = np.array(c)
        a = arr[:, :, 3]
        lab, nl = ndimage.label(a > 40)
        if nl > 1:
            sizes = ndimage.sum(np.ones_like(a), lab, range(1, nl + 1))
            main = int(np.argmax(sizes)) + 1
            objs = ndimage.find_objects(lab)
            my, mx = objs[main - 1]
            gx0, gx1, gy0, gy1 = mx.start - 90, mx.stop + 90, my.start - 90, my.stop + 90
            keep = np.zeros_like(a, dtype=bool)
            for k, (sy, sx) in enumerate(objs, start=1):
                # the item and its own sparkle/glow; fragments of neighbours sit at the cell edge, outside this box
                if sx.start >= gx0 and sx.stop <= gx1 and sy.start >= gy0 and sy.stop <= gy1:
                    keep |= lab == k
            keep = ndimage.binary_dilation(keep, iterations=14)
            arr[:, :, 3] = np.where(keep, a, 0)
            c = Image.fromarray(arr)
            a = arr[:, :, 3]
        ys, xs = np.where(a > 24)
        box = (max(0, xs.min() - 8), max(0, ys.min() - 8), min(cw, xs.max() + 9), min(ch, ys.max() + 9))
        c = c.crop(box)
        s = 384 / max(c.size)
        if s < 1:
            c = c.resize((round(c.size[0] * s), round(c.size[1] * s)), Image.LANCZOS)
        c.save(f"{OUT}/{n}.png")
        print(n, c.size)

bg = Image.open(f"{RAW}/bg_shop.png").convert("RGB").resize((1080, 1910), Image.LANCZOS)
bg.save(f"{OUT}/bg_shop.webp", quality=86)
# pre-blurred snapshot for sheets (no live blur on Mali, UX §6.1)
bg.resize((360, 637)).filter(ImageFilter.GaussianBlur(10)).resize((720, 1273), Image.LANCZOS).save(f"{OUT}/bg_shop_blur.webp", quality=80)
Image.open(f"{RAW}/bg_age.png").convert("RGB").resize((1080, 1910), Image.LANCZOS).save(f"{OUT}/bg_age.webp", quality=86)
p = Image.open(f"{RAW}/bg_pass.png").convert("RGB")
W, H = p.size
p = p.crop((int(W * 0.05), int(H * 0.06), int(W * 0.95), int(H * 0.94)))
p = p.resize((1680, round(1680 * p.size[1] / p.size[0])), Image.LANCZOS)
p.save(f"{OUT}/bg_pass.webp", quality=86)
print("bg_pass", p.size)
