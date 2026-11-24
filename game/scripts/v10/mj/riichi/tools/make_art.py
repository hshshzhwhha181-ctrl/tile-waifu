#!/usr/bin/env python3
"""Reproducible build of the riichi table art from the Higgsfield sources (gpt_image_2_6, xhigh, 2k).

usage: python3 -I make_art.py <raw_dir> <game_dir>
raw_dir holds cloth_{school,bamboo,jade,gold,sky}.png, back_{rose,jade,night}.png, crest_{mc,rin,hana,yue,nova}.png
Writes game/assets/v10/mj/riichi/{cloth_*.webp, back_*.png, crest_*.webp}.
"""
import sys, os
from PIL import Image, ImageFilter, ImageEnhance, ImageChops

raw, game = sys.argv[1], sys.argv[2]
out = os.path.join(game, "assets/v10/mj/riichi")
os.makedirs(out, exist_ok=True)

# cloths: 900x1600 portrait, centre hotspot calmed so tiles read on top (UX: low contrast under the play area)
for n in ["school", "bamboo", "jade", "gold", "sky"]:
    im = Image.open(os.path.join(raw, "cloth_%s.png" % n)).convert("RGB")
    im = im.resize((900, 1600), Image.LANCZOS)
    im = ImageEnhance.Brightness(im).enhance(0.78)
    im = ImageEnhance.Contrast(im).enhance(0.9)
    im.save(os.path.join(out, "cloth_%s.webp" % n), quality=86)

# tile backs: the ornament replaces the lacquer face of the v08 back.png, keeping its ivory body and depth
base = Image.open(os.path.join(game, "assets/v08/table/back.png")).convert("RGBA")
W, H = base.size
mask = Image.new("L", (W, H), 0)
mp = mask.load()
bp = base.load()
for y in range(H):
    for x in range(W):
        r, g, b, a = bp[x, y]
        ivory = r > 195 and g > 178 and b > 150
        if a > 0 and y < 182 and not ivory:
            mp[x, y] = a
mask = mask.filter(ImageFilter.MinFilter(3))
bbox = mask.getbbox()
for n in ["rose", "jade", "night"]:
    orn = Image.open(os.path.join(raw, "back_%s.png" % n)).convert("RGBA")
    bw, bh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    orn = orn.resize((bw * 3, bh * 3), Image.LANCZOS).resize((bw, bh), Image.LANCZOS)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer.paste(orn, (bbox[0], bbox[1]))
    res = base.copy()
    res.paste(layer, (0, 0), mask)
    # inner rim: 1 px darker line along the face edge
    edge = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(3)))
    shade = Image.new("RGBA", (W, H), (20, 10, 14, 150))
    res.paste(shade, (0, 0), edge)
    res.save(os.path.join(out, "back_%s.png" % n))

# dora crests: glow line art on black -> alpha from luminance (drawn additively in game)
for n in ["mc", "rin", "hana", "yue", "nova"]:
    im = Image.open(os.path.join(raw, "crest_%s.png" % n)).convert("RGB").resize((512, 512), Image.LANCZOS)
    lum = im.convert("L").point(lambda v: 0 if v < 14 else min(255, int((v - 14) * 1.25)))
    rgba = im.copy()
    rgba.putalpha(lum)
    rgba.save(os.path.join(out, "crest_%s.webp" % n), quality=90)
print("ok", out)
