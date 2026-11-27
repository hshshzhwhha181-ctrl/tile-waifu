#!/usr/bin/env python3
"""Compare Godot-loaded dumps (qa_dump.gd) against the original source images: PSNR + side-by-side detail crops.
usage: qa_compare.py DUMP_DIR OUT_PNG_PREFIX res://a.webp res://b.png ...   (run from repo root; sources in game/)"""
import sys, os
import numpy as np
from PIL import Image

def comp(src, dump, prefix, tag):
    a = Image.open(src).convert("RGBA"); b = Image.open(dump).convert("RGBA")
    if a.size != b.size:
        return "%s size mismatch %s vs %s" % (tag, a.size, b.size)
    A = np.asarray(a).astype(float); B = np.asarray(b).astype(float)
    al = A[..., 3] / 255.0
    w = np.maximum(al, 1e-3)[..., None]
    mse = (((A[..., :3] - B[..., :3]) ** 2) * w).sum() / (w.sum() * 3)   # alpha-weighted: invisible pixels do not count
    psnr = 10 * np.log10(255 ** 2 / max(mse, 1e-9))
    da = np.abs(A[..., 3] - B[..., 3]).max()
    # detail crop: 256x256 window with max local gradient energy
    g = np.abs(np.diff(A[..., :3].mean(-1), axis=0))[:, :-1] + np.abs(np.diff(A[..., :3].mean(-1), axis=1))[:-1, :]
    h, wd = g.shape; s = 256
    best = (0, 0, 0)
    for y in range(0, max(1, h - s), 64):
        for x in range(0, max(1, wd - s), 64):
            e = (g[y:y + s, x:x + s] * (al[y:y + s, x:x + s] > 0.5)).sum()
            if e > best[0]: best = (e, x, y)
    _, x, y = best
    def crop(im):
        c = im.crop((x, y, x + s, y + s))
        bg = Image.new("RGBA", c.size, (128, 128, 128, 255)); bg.alpha_composite(c)  # grey bg: halos show
        return bg.convert("RGB").resize((s * 2, s * 2), Image.NEAREST)
    sheet = Image.new("RGB", (s * 4 + 8, s * 2), (255, 0, 255))
    sheet.paste(crop(a), (0, 0)); sheet.paste(crop(b), (s * 2 + 8, 0))
    sheet.save("%s_%s.png" % (prefix, tag))
    return "%-48s PSNR %.1f dB  max|dAlpha| %d  crop@(%d,%d)" % (tag, psnr, da, x, y)

if __name__ == "__main__":
    dump, prefix = sys.argv[1], sys.argv[2]
    for r in sys.argv[3:]:
        rel = r[len("res://"):]
        d = os.path.join(dump, rel.replace("/", "__") + ".png")
        print(comp(os.path.join("game", rel), d, prefix, os.path.basename(rel).split(".")[0]))
