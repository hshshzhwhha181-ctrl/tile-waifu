#!/usr/bin/env python3
"""Bake the riichi faces of «Чтение руки» onto the game's tile face (185x192).

The board is a TrayBoard: every Tile draws its face texture through the v06 porcelain shader, whose bevel map
covers a 185x192 quad. The riichi art (game/assets/v08/table/tNN.png, 144x200) is a whole tile in another
aspect, so it cannot be dropped in as the face. This script:
  1. builds a blank game face: per-pixel median of the 36 game faces (game/assets/tiles/*.png) on the outer
     ring (removes the art that reaches the border), flat porcelain inside, the shape alpha of the median;
  2. keys the glyph out of each riichi tile (distance to the per-row porcelain colour of that tile);
  3. scales the glyph uniformly (no stretch) into the face and writes game/assets/v10/palm/faces/fNN.png.
Reproducible: python3 game/scripts/v10/palm/tools/make_faces.py  (from the repo root; needs Pillow + numpy).
"""
import os
import sys
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", ".."))
GAME = os.path.join(ROOT, "game")
TILES = os.path.join(GAME, "assets", "tiles")
RIICHI = os.path.join(GAME, "assets", "v08", "table")
OUT = os.path.join(GAME, "assets", "v10", "palm", "faces")
FW, FH = 185, 192
BG = np.array([252, 243, 230], dtype=np.float32)      # the porcelain of the game faces (sampled)
CROP = (13, 8, 131, 169)                              # inside the riichi inner frame (frame line at y 170-172)
FEATHER = 4.0
GLYPH_H = 150.0                                       # glyph box height on the 192 px face


def blank_face():
    faces = []
    for fn in sorted(os.listdir(TILES)):
        if fn.endswith(".png") and fn[:2].isdigit():
            im = Image.open(os.path.join(TILES, fn)).convert("RGBA")
            if im.size == (FW, FH):
                faces.append(np.asarray(im, dtype=np.float32))
    st = np.stack(faces)
    med = np.median(st, axis=0)
    alpha = med[:, :, 3]
    inside = (alpha > 200).astype(np.uint8) * 255
    # distance into the shape: erode the mask step by step
    m = Image.fromarray(inside)
    depth = np.zeros((FH, FW), dtype=np.float32)
    cur = m
    for d in range(1, 22):
        cur = cur.filter(ImageFilter.MinFilter(3))
        depth += (np.asarray(cur) > 0)
    ring_w = np.clip((depth - 9.0) / 8.0, 0.0, 1.0)[:, :, None]  # 0 on the ring, 1 deep inside
    rgb = med[:, :, :3] * (1.0 - ring_w) + BG[None, None, :] * ring_w
    out = np.dstack([rgb, alpha])
    return out


def porcelain():
    """The riichi porcelain is a vertical gradient shared by every tile: fit it (per channel, linear in y) on the
    blank inside of the white dragon (t31) and the blank side margins of 1 man (t00)."""
    ys, cols = [], []
    t31 = np.asarray(Image.open(os.path.join(RIICHI, "t31.png")).convert("RGB"), dtype=np.float32)
    t00 = np.asarray(Image.open(os.path.join(RIICHI, "t00.png")).convert("RGB"), dtype=np.float32)
    for y in range(36, 146):
        ys.append(y)
        cols.append(np.median(t31[y, 52:92], axis=0))
    for y in range(14, 166):
        ys.append(y)
        cols.append(np.median(np.concatenate([t00[y, 14:22], t00[y, 122:130]]), axis=0))
    ys = np.array(ys, dtype=np.float32)
    cols = np.array(cols)
    fit = [np.polyfit(ys, cols[:, c], 1) for c in range(3)]
    return lambda y: np.stack([np.polyval(fit[c], y) for c in range(3)], axis=-1)


PORC = None


def glyph(k):
    """The porcelain crop of tile k, colour-shifted so its porcelain equals the game face porcelain (every detail of
    the art is kept: concentric pin rings, thin strokes), with a feathered border that is pure porcelain anyway."""
    global PORC
    if PORC is None:
        PORC = porcelain()
    im = np.asarray(Image.open(os.path.join(RIICHI, "t%02d.png" % k)).convert("RGBA"), dtype=np.float32)
    x0, y0, x1, y1 = CROP
    g = im[y0:y1, x0:x1, :3]
    bg = PORC(np.arange(y0, y1, dtype=np.float32))[:, None, :]
    rgb = np.clip(g + (BG[None, None, :] - bg), 0, 255)
    h, w = rgb.shape[:2]
    fy = np.minimum(np.arange(h), np.arange(h)[::-1])[:, None]
    fx = np.minimum(np.arange(w), np.arange(w)[::-1])[None, :]
    a = np.clip(np.minimum(fx, fy) / FEATHER, 0.0, 1.0)
    return np.dstack([rgb, a * 255.0])


def bake(k, face):
    gl = Image.fromarray(glyph(k).astype(np.uint8), "RGBA")
    s = GLYPH_H / gl.size[1]
    gw, gh = int(round(gl.size[0] * s)), int(round(gl.size[1] * s))
    gl = gl.resize((gw, gh), Image.LANCZOS)
    base = Image.fromarray(face.astype(np.uint8), "RGBA")
    layer = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    layer.paste(gl, ((FW - gw) // 2, (FH - gh) // 2 - 3))
    comp = Image.alpha_composite(base, layer)
    # keep the face silhouette (the glyph never paints outside the tile)
    arr = np.asarray(comp).copy()
    arr[:, :, 3] = face[:, :, 3].astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    face = blank_face()
    Image.fromarray(face.astype(np.uint8), "RGBA").save(os.path.join(OUT, "blank.png"))
    for k in range(34):
        bake(k, face).save(os.path.join(OUT, "f%02d.png" % k))
    print("faces:", OUT)


if __name__ == "__main__":
    sys.exit(main())
