#!/usr/bin/env python3
"""v10/mj/look: turn the Higgsfield table art into game assets.
usage: make_table_art.py <raw_dir> <game_dir>
  raw: bg_<hero>_<a|b>.png (gpt_image_2_6 xhigh 2k 9:16), near_<hero>.png (transparent, 1k), cloth_<hero>.png (1k)
  out: assets/v10/mj/look/tables/far_<id>.webp, near_<id>.webp, cloth_<id>.webp
Picks: founders use variant b (richer upper third, audited: no people, no text); the house table uses mc variant a.
Cloths are made seamless by a wrap cross-fade (hana's sun-ray cloth is one sheet, not tiled)."""
import sys, os
import numpy as np
from PIL import Image, ImageFilter

raw, game = sys.argv[1], sys.argv[2]
out = os.path.join(game, "assets/v10/mj/look/tables")
os.makedirs(out, exist_ok=True)
FAR = {"house": "bg_mc_a", "mc": "bg_mc_b", "rin": "bg_rin_b", "hana": "bg_hana_b", "yue": "bg_yue_b", "nova": "bg_nova_b"}


def far(src, dst):
    im = Image.open(os.path.join(raw, src + ".png")).convert("RGB")
    im = im.resize((1300, int(1300 * im.height / im.width)), Image.LANCZOS)
    im.save(os.path.join(out, dst), "WEBP", quality=86, method=6)


def seamless(im, k=0.18):
    a = np.asarray(im).astype(np.float32)
    h, w = a.shape[:2]
    # shift by half, blend the seam band with the unshifted image
    s = np.roll(np.roll(a, h // 2, 0), w // 2, 1)
    yy = np.abs(np.arange(h) - h / 2) / (h / 2)
    xx = np.abs(np.arange(w) - w / 2) / (w / 2)
    m = np.minimum(np.clip((1 - yy) / k, 0, 1)[:, None], np.clip((1 - xx) / k, 0, 1)[None, :])
    # m ≈ 1 in the middle of s (its old edges sit at the centre lines) — use a where s has a seam
    seam = np.maximum(np.clip(1 - np.abs(np.arange(h) - h / 2)[:, None] / (h * k / 2), 0, 1),
                      np.clip(1 - np.abs(np.arange(w) - w / 2)[None, :] / (w * k / 2), 0, 1))
    o = s * (1 - seam[..., None]) + a * seam[..., None]
    return Image.fromarray(o.clip(0, 255).astype(np.uint8))


for k, src in FAR.items():
    far(src, "far_%s.webp" % k)
for h in ["mc", "rin", "hana", "yue", "nova"]:
    n = Image.open(os.path.join(raw, "near_%s.png" % h)).convert("RGBA")
    # depth of field: the near layer is out of focus
    n = n.filter(ImageFilter.GaussianBlur(1.6))
    n.save(os.path.join(out, "near_%s.webp" % h), "WEBP", quality=88, method=6)
    c = Image.open(os.path.join(raw, "cloth_%s.png" % h)).convert("RGB").resize((640, 640), Image.LANCZOS)
    if h != "hana":
        c = seamless(c)
    c.save(os.path.join(out, "cloth_%s.webp" % h), "WEBP", quality=90, method=6)
# house cloth: mc's jade felt, de-saturated toward the classic salon green
c = Image.open(os.path.join(out, "cloth_mc.webp")).convert("RGB")
a = np.asarray(c).astype(np.float32)
g = a.mean(-1, keepdims=True)
a = g + (a - g) * 0.8
Image.fromarray(a.clip(0, 255).astype(np.uint8)).save(os.path.join(out, "cloth_house.webp"), "WEBP", quality=90, method=6)
for f in sorted(os.listdir(out)):
    print(f, os.path.getsize(os.path.join(out, f)))
