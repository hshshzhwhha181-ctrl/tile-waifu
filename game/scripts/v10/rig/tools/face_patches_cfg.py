#!/usr/bin/env python3
"""Config-driven face patches (any heroine): the same method as face_patches.py, but the boxes, ellipses and
variant files come from a JSON file instead of being edited in the code.

    python3 face_patches_cfg.py <face_cfg.json> <art.png> <variants dir> <out dir> [--preview <png>]

face_cfg.json:
  "body_size": 1400                    rig texture size (body.png px); the art is resized to it
  "ref_box":  [x0, y0, x1, y1]         the face_ref crop in ART px (the variants were made from it, any size)
  "patches":  [{"name", "file", "box": [x0,y0,x1,y1] body px, "ellipses": [[cx, cy, rx, ry], ...] body px,
                "thresh"=14, "grow"=4, "feather"=5, "align": [x0,y0,x1,y1], "exclude": [x0,y0,x1,y1],
                "plate": false,
                "clean": [[cx, cy, r], ...] body px: stray marks of the variant to inpaint away}]
     plate: true keeps the whole aligned, colour-matched region inside the ellipses (no "what changed" mask):
     used for an under-painting plate (what is behind a hand), not for an overlay.
  "winks": {"from": "eyes_closed", "split_x": 688, "soft": 10}       optional: eyeL_closed / eyeR_closed
  "blush": {"box": [...], "cheeks": [[cx, cy, rx, ry, a], ...], "rgb": [255, 105, 130]}   optional
Writes <name>.png per patch and face_patches.json ({name: {pos, size}}) into <out dir>.
Each variant is pasted back into the art at ref_box, sub-pixel aligned by phase correlation on the area around
the feature (align minus exclude), colour-matched on a ring around the ellipses, and only the pixels that really
changed are kept, with feathered edges.
"""
import sys, json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage.registration import phase_cross_correlation

CFG, SRC, GEN, OUT = sys.argv[1:5]
cfg = json.load(open(CFG))
N = int(cfg.get('body_size', 1400))
orig = Image.open(SRC).convert('RGB')
AW = orig.width
S = N / float(AW)
RB = cfg['ref_box']
oN = np.asarray(orig.resize((N, N), Image.LANCZOS)).astype(np.float32)


def variant_to_body(path):
    v = Image.open(path).convert('RGB').resize((RB[2] - RB[0], RB[3] - RB[1]), Image.LANCZOS)
    full = orig.copy()
    full.paste(v, (RB[0], RB[1]))
    return np.asarray(full.resize((N, N), Image.LANCZOS)).astype(np.float32)


def gray(a):
    return a @ np.array([0.299, 0.587, 0.114], np.float32)


def align(var, box, exclude):
    x0, y0, x1, y1 = box
    a = gray(oN[y0:y1, x0:x1]).copy()
    b = gray(var[y0:y1, x0:x1]).copy()
    m = np.ones_like(a, bool)
    if exclude:
        ex0, ey0, ex1, ey1 = exclude
        m[max(ey0 - y0, 0):max(ey1 - y0, 0), max(ex0 - x0, 0):max(ex1 - x0, 0)] = False
    a[~m] = a[m].mean(); b[~m] = b[m].mean()
    shift, err, _ = phase_cross_correlation(a, b, upsample_factor=20)
    return shift


def make_patch(p):
    var = variant_to_body(GEN + p['file'])
    dy = dx = 0.0
    if p.get('align'):
        dy, dx = align(var, p['align'], p.get('exclude'))
        var = np.stack([ndi.shift(var[..., c], (dy, dx), order=3, mode='nearest') for c in range(3)], -1)
    x0, y0, x1, y1 = p['box']
    o = oN[y0:y1, x0:x1]
    v = var[y0:y1, x0:x1].copy()
    h, w = o.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    e = np.min([((xx + x0 - cx) / rx) ** 2 + ((yy + y0 - cy) / ry) ** 2 for cx, cy, rx, ry in p['ellipses']], 0)
    lim = np.clip((1.25 - e) / 0.5, 0, 1)
    ring = (e > 0.9) & (e < 1.6)
    corr = (o[ring] - v[ring]).mean(0) if ring.any() else np.zeros(3, np.float32)
    v = np.clip(v + corr * 0.85, 0, 255)
    for cx, cy, r in p.get('clean', []):
        # a stray mark the variant painted (a corner tick that reads as a mole): inpaint it from the skin around it
        import cv2
        m = (np.hypot(xx + x0 - cx, yy + y0 - cy) <= r).astype(np.uint8) * 255
        v = cv2.inpaint(np.ascontiguousarray(v.astype(np.uint8)[..., ::-1]), m, 3, cv2.INPAINT_TELEA)[..., ::-1].astype(np.float32)
    if p.get('plate'):
        a = lim
    else:
        diff = np.abs(gray(o) - gray(v))
        core = ndi.gaussian_filter(diff, 1.2) > float(p.get('thresh', 14.0))
        core = ndi.binary_closing(core, iterations=3)
        core = ndi.binary_fill_holes(core)
        core = ndi.binary_dilation(core, iterations=int(p.get('grow', 4)))
        a = ndi.gaussian_filter(core.astype(np.float32), float(p.get('feather', 5.0)))
        a = np.clip(a * 1.6, 0, 1) * lim
    rgba = np.dstack([v, a * 255]).astype(np.uint8)
    Image.fromarray(rgba, 'RGBA').save(f"{OUT}/{p['name']}.png")
    comp = o * (1 - a[..., None]) + v * a[..., None]
    print(p['name'], 'shift', round(float(dx), 2), round(float(dy), 2), 'corr', np.round(corr, 1),
          'cover', round(float((a > 0.5).mean()), 3))
    return {'pos': [x0, y0], 'size': [w, h]}, comp.astype(np.uint8), o.astype(np.uint8)


def main():
    meta, prev = {}, []
    for p in cfg['patches']:
        m, c, o = make_patch(p)
        meta[p['name']] = m
        prev.append((c, o, p['name']))
    wk = cfg.get('winks')
    if wk:
        e = np.asarray(Image.open(f"{OUT}/{wk['from']}.png")).copy()
        pos = meta[wk['from']]['pos']
        h, w = e.shape[:2]
        xx = np.mgrid[0:h, 0:w][1]
        t = np.clip((xx + pos[0] - wk['split_x']) / float(wk.get('soft', 10)), 0, 1)
        for name, k in (('eyeL_closed', 1 - t), ('eyeR_closed', t)):
            q = e.copy(); q[..., 3] = (e[..., 3] * k).astype(np.uint8)
            Image.fromarray(q).save(f'{OUT}/{name}.png')
            meta[name] = dict(meta[wk['from']])
    bl = cfg.get('blush')
    if bl:
        x0, y0, x1, y1 = bl['box']
        h, w = y1 - y0, x1 - x0
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        A = np.zeros((h, w), np.float32)
        for cx, cy, rx, ry, k in bl['cheeks']:
            d = ((xx + x0 - cx) / rx) ** 2 + ((yy + y0 - cy) / ry) ** 2
            A = np.maximum(A, k * np.exp(-d * 2.2))
        b = np.zeros((h, w, 4), np.float32)
        b[..., :3] = bl.get('rgb', [255, 105, 130]); b[..., 3] = A * 255
        Image.fromarray(b.astype(np.uint8)).save(f'{OUT}/blush.png')
        meta['blush'] = {'pos': [x0, y0], 'size': [w, h]}
    json.dump(meta, open(f'{OUT}/face_patches.json', 'w'), indent=1)
    if '--preview' in sys.argv:
        path = sys.argv[sys.argv.index('--preview') + 1]
        tiles = [np.concatenate([o, c], 1) for c, o, _ in prev]
        W = max(t.shape[1] for t in tiles)
        s = np.concatenate([np.pad(t, ((0, 4), (0, W - t.shape[1]), (0, 0))) for t in tiles], 0)
        Image.fromarray(s).resize((s.shape[1] * 2, s.shape[0] * 2), Image.LANCZOS).save(path)


if __name__ == '__main__':
    main()
