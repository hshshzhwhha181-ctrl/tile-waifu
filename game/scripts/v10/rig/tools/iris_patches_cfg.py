#!/usr/bin/env python3
"""Config-driven copy of iris_patches.py (any heroine): the EYES table comes from a JSON file.

    python3 iris_patches_cfg.py <body.png> <out dir> <iris_cfg.json>

iris_cfg.json: {"eyes": {"L": {"box": [x0,y0,x1,y1], "centre": [x,y], "r": 10, "open": [[x,y],...]}, "R": {...}}}
(body.png px). Everything below is the original description.

Iris patches (v2): lets the pupils move. For each eye it writes two textures of the same box:
  eye<S>_socket.png  the eye opening with the iris painted out (OpenCV Telea from the visible sclera and lid
                     line), alpha = the opening (feathered 0.8 px). Drawn over the face on the head bone.
  eye<S>_iris.png    the iris disc (art pixels; the parts hidden under the lids inpainted from the visible iris),
                     alpha = the disc. Sampled by scripts/v10/rig/v10_iris.gdshader at an offset inside the opening.
At offset 0 the composite is the original art, so nothing changes until the eyes look somewhere.

    python3 iris_patches.py <body.png> <out dir>

FOR THE NEXT HEROINE: edit EYES below (box, opening polygon, iris centre and radius in body.png px). Trace them on a
9x crop (any image viewer with a grid). Keep the opening polygon on the inside of the lash line.
"""
import sys
import numpy as np
import cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

EYES = {}  # from the config (see the module doc)


def main(src, out):
    im = np.asarray(Image.open(src).convert('RGBA')).astype(np.float32)
    for side, e in EYES.items():
        x0, y0, x1, y1 = e['box']
        rgb = im[y0:y1, x0:x1, :3].copy()
        h, w = rgb.shape[:2]
        # opening mask (supersampled for a soft edge)
        S = 4
        m = Image.new('L', (w * S, h * S), 0)
        ImageDraw.Draw(m).polygon([((x - x0) * S, (y - y0) * S) for x, y in e['open']], fill=255)
        op = np.asarray(m.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255
        op = ndi.gaussian_filter(op, 0.4)
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        cx, cy = e['centre'][0] - x0, e['centre'][1] - y0
        dd = np.hypot(xx + 0.5 - cx, yy + 0.5 - cy)
        disc = np.clip(e['r'] + 2.5 - dd, 0, 1)  # covers the painted-out hole exactly at rest
        # socket: paint the iris out of the opening with sclera: the brightest visible sclera colour at the bottom,
        # a lid shadow towards the top (anime eyes shade the upper third), blended in over 1.5 px
        hole_f = np.clip(e['r'] + 2.0 - dd, 0, 1) * (op > 0.01)
        hole = (hole_f > 0).astype(np.uint8) * 255
        bgr = np.ascontiguousarray(rgb[..., ::-1].clip(0, 255).astype(np.uint8))
        scl = (op > 0.9) & (dd > e['r'] + 1.5)
        lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
        light = rgb[scl & (lum >= np.percentile(lum[scl], 80))].mean(0)
        light = light * 0.96
        shadow = light * np.array([0.60, 0.48, 0.55], np.float32)
        ys = np.nonzero(op > 0.5)[0]
        top, bot = ys.min(), ys.max()
        k = np.clip((yy - top) / max(bot - top, 1) / 0.95, 0, 1)
        k = k * k * (3 - 2 * k)
        fill = shadow[None, None] * (1 - k[..., None]) + light[None, None] * k[..., None]
        sock = rgb * (1 - hole_f[..., None]) + fill * hole_f[..., None]
        a = (op * 255).astype(np.uint8)
        Image.fromarray(np.dstack([sock.clip(0, 255).astype(np.uint8), a]), 'RGBA').save(f'{out}/eye{side}_socket.png')
        # iris: visible iris pixels, the rest of the disc inpainted from them, padded so shifts never sample outside
        vis = (dd < e['r'] + 2.0) & (op > 0.9)
        unk = (~vis).astype(np.uint8) * 255  # fill from the visible iris only
        ir = cv2.inpaint(bgr, unk, 3, cv2.INPAINT_TELEA)[..., ::-1].astype(np.float32)
        ir = np.where(vis[..., None], rgb, ir)
        ia = (disc * 255).astype(np.uint8)
        Image.fromarray(np.dstack([ir.clip(0, 255).astype(np.uint8), ia]), 'RGBA').save(f'{out}/eye{side}_iris.png')
        print(side, 'box', e['box'], 'iris px', int(vis.sum()))


if __name__ == '__main__':
    import json
    cfg = json.load(open(sys.argv[3]))
    for k, e in cfg['eyes'].items():
        EYES[k] = {'box': tuple(e['box']), 'centre': tuple(e['centre']), 'r': float(e['r']),
                   'open': [tuple(p) for p in e['open']]}
    main(sys.argv[1], sys.argv[2])
