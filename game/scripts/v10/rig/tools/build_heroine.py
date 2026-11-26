#!/usr/bin/env python3
"""One-shot rig build for a heroine (wraps split_layers.py + build_rig.py, adds a few optional steps):

    python3 build_heroine.py game/assets/v10/rig/<name>/rig_def.json [--debug out_dir]

Steps, each only when rig_def.json asks for it:
  1. auto_zones   a split zone traced from a colour mask (hue/sat/val ranges) inside a loose polygon: the largest
                  blob, closed, hole-filled, simplified to a polygon. Split entries with "zone": "auto" (or
                  "zone_auto": true) get it. Handy for a braid lying over a dark coat (hair is told apart by hue).
  2. split        split_layers.main (layer_*.png, layer_body.png, layers_meta.json)
  3. plates       a generated plate (e.g. fan_plate.png from face_patches_cfg.py, "what is behind the hand") is
                  pasted into layer_body.png where the body was under-painted below the given split layer, instead
                  of the Telea smear
  4. face         face.patches_from (face_patches.json from face_patches_cfg.py) -> face.patches; face.glint -> a
                  lens mask texture (white ellipses, feathered) for the glasses glint sweep
  5. build        build_rig.build -> rig.tscn; "script" swaps the root script (a V10LiveRig subclass)
Writes rig_def.json back (computed zones and the patch table are kept in it, so the runtime reads one file).
"""
import json, os, sys
import numpy as np
import cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from skimage.color import rgb2hsv

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import split_layers  # noqa: E402
import build_rig  # noqa: E402


def poly_mask(poly, shape):
    im = Image.new('L', (shape[1], shape[0]), 0)
    ImageDraw.Draw(im).polygon([tuple(p) for p in poly], fill=255)
    return np.asarray(im) > 127


def auto_zone(cfg, body):
    a = body[..., 3] / 255.0
    hsv = rgb2hsv(body[..., :3])
    hue, sat, val = hsv[..., 0] * 360.0, hsv[..., 1], hsv[..., 2]
    H, W = a.shape
    m = np.zeros((H, W), bool)
    for h0, h1, s0, s1, v0 in cfg['hsv']:
        m |= (hue >= h0) & (hue <= h1) & (sat >= s0) & (sat <= s1) & (val >= v0)
    m &= a > 0.05
    m &= poly_mask(cfg['loose'], (H, W))
    for p in cfg.get('exclude', []):
        m &= ~poly_mask(p, (H, W))
    for p in cfg.get('take', []):
        m |= poly_mask(p, (H, W)) & (a > 0.05)
    c = int(cfg.get('close', 3))
    m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * c + 1, 2 * c + 1))) > 0
    m = ndi.binary_fill_holes(m)
    m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))) > 0
    lab, n = ndi.label(m)
    if n == 0:
        raise SystemExit('auto zone: empty mask')
    sizes = ndi.sum(np.ones_like(a), lab, range(1, n + 1))
    m = lab == (1 + int(np.argmax(sizes)))
    cs, _ = cv2.findContours(m.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    cnt = max(cs, key=cv2.contourArea)
    cnt = cv2.approxPolyDP(cnt, float(cfg.get('simplify', 0.8)), True)
    return [[int(p[0][0]), int(p[0][1])] for p in cnt], int(m.sum())


def lens_mask(g, base):
    x0, y0, x1, y1 = g['box']
    S = 4
    im = Image.new('L', ((x1 - x0) * S, (y1 - y0) * S), 0)
    for cx, cy, rx, ry, deg in g['lenses']:
        t = np.radians(deg)
        pts = [(((cx + rx * np.cos(u) * np.cos(t) - ry * np.sin(u) * np.sin(t)) - x0) * S,
                ((cy + rx * np.cos(u) * np.sin(t) + ry * np.sin(u) * np.cos(t)) - y0) * S)
               for u in np.linspace(0, 2 * np.pi, 72, endpoint=False)]
        ImageDraw.Draw(im).polygon(pts, fill=255)
    im = im.resize((x1 - x0, y1 - y0), Image.LANCZOS)
    a = ndi.gaussian_filter(np.asarray(im).astype(np.float32), 1.2)
    out = np.dstack([np.full(a.shape + (3,), 255, np.uint8), a.astype(np.uint8)])
    Image.fromarray(out, 'RGBA').save(os.path.join(base, g['file']))


def main(def_path, dbg=None):
    base = os.path.dirname(os.path.abspath(def_path))
    d = json.load(open(def_path))
    body = np.asarray(Image.open(os.path.join(base, d['layers'].get('source', 'body.png'))).convert('RGBA'))
    # 1. auto zones
    for lay in d['layers']['split']:
        if lay.get('zone') == 'auto' or lay.get('zone_auto'):
            lay['zone_auto'] = True
            lay['zone'], npx = auto_zone(d['auto_zones'][lay['name']], body)
            print('auto zone', lay['name'], len(lay['zone']), 'points', npx, 'px')
    json.dump(d, open(def_path, 'w'), indent=1)
    # 2. split
    split_layers.main(def_path, dbg)
    meta = json.load(open(os.path.join(base, 'layers_meta.json')))
    # 3. plates
    for pl in d.get('plates', []):
        fp = json.load(open(os.path.join(base, 'face_patches.json')))
        name = os.path.splitext(pl['file'])[0]
        px, py = fp[name]['pos']
        plate = np.asarray(Image.open(os.path.join(base, pl['file'])).convert('RGBA')).astype(np.float32)
        lb = np.asarray(Image.open(os.path.join(base, 'layer_body.png')).convert('RGBA')).astype(np.float32).copy()
        lay = np.asarray(Image.open(os.path.join(base, 'layer_%s.png' % pl['under_layer'])).convert('RGBA'))
        ox, oy = meta[pl['under_layer']]['origin']
        H, W = lb.shape[:2]
        over = np.zeros((H, W), np.float32)
        over[oy:oy + lay.shape[0], ox:ox + lay.shape[1]] = lay[..., 3] / 255.0
        ph, pw = plate.shape[:2]
        k = np.zeros((H, W), np.float32)
        k[py:py + ph, px:px + pw] = plate[..., 3] / 255.0
        # only where the part covered the body and the body was under-painted (alpha > 0)
        under = ndi.binary_dilation(over > 0.05, iterations=3) & (lb[..., 3] > 8)
        k = k * ndi.gaussian_filter(under.astype(np.float32), 1.0)
        rgb = lb[..., :3].copy()
        rgb[py:py + ph, px:px + pw] = rgb[py:py + ph, px:px + pw] * (1 - k[py:py + ph, px:px + pw, None]) + \
            plate[..., :3] * k[py:py + ph, px:px + pw, None]
        lb[..., :3] = rgb
        Image.fromarray(np.clip(lb, 0, 255).astype(np.uint8), 'RGBA').save(os.path.join(base, 'layer_body.png'), optimize=True)
        print('plate', pl['file'], 'under', pl['under_layer'], 'px', int((k > 0.5).sum()))
    # 3b. repaint: redo the under-painting below a layer inside `region` from known pixels of a given colour only
    # (Telea from everything around smears hair into a dark coat; here only coat pixels feed it)
    for rp in d.get('repaint', []):
        lb = np.asarray(Image.open(os.path.join(base, 'layer_body.png')).convert('RGBA')).copy()
        lay = np.asarray(Image.open(os.path.join(base, 'layer_%s.png' % rp['layer'])).convert('RGBA'))
        ox, oy = meta[rp['layer']]['origin']
        H, W = lb.shape[:2]
        over = np.zeros((H, W), bool)
        over[oy:oy + lay.shape[0], ox:ox + lay.shape[1]] = lay[..., 3] > 12
        reg = poly_mask(rp['region'], (H, W))
        fill = over & reg & (lb[..., 3] > 8)
        hsv = rgb2hsv(body[..., :3])
        hue, sat, val = hsv[..., 0] * 360.0, hsv[..., 1], hsv[..., 2]
        km = np.zeros((H, W), bool)
        for h0, h1, s0, s1, v0, v1 in rp['known_hsv']:
            km |= (hue >= h0) & (hue <= h1) & (sat >= s0) & (sat <= s1) & (val >= v0) & (val <= v1)
        known = km & (body[..., 3] > 230) & ~ndi.binary_dilation(over, iterations=4)
        known &= poly_mask(rp.get('known_region', rp['region']), (H, W))
        rgb = split_layers.inpaint_from(lb[..., :3].copy(), known, fill, radius=int(rp.get('radius', 9)))
        if rp.get('blur'):
            bl = cv2.GaussianBlur(rgb, (0, 0), float(rp['blur']))
            rgb = np.where(fill[..., None], bl, rgb)
        lb[..., :3] = np.where(fill[..., None], rgb, lb[..., :3])
        Image.fromarray(lb, 'RGBA').save(os.path.join(base, 'layer_body.png'), optimize=True)
        print('repaint under', rp['layer'], 'px', int(fill.sum()), 'known', int(known.sum()))
    # 4. face
    f = d.get('face', {})
    if f.get('patches_from'):
        fp = json.load(open(os.path.join(base, f['patches_from'])))
        skip = {os.path.splitext(p['file'])[0] for p in d.get('plates', [])}
        f['patches'] = {k: {'file': k + '.png', 'pos': v['pos']} for k, v in fp.items() if k not in skip}
    if f.get('glint'):
        lens_mask(f['glint'], base)
    json.dump(d, open(def_path, 'w'), indent=1)
    # 5. build
    build_rig.build(def_path, dbg)
    if d.get('script'):
        p = os.path.join(base, 'rig.tscn')
        s = open(p).read().replace('res://scripts/v10/rig/live_rig.gd', d['script'])
        open(p, 'w').write(s)
        print('script', d['script'])


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[sys.argv.index('--debug') + 1] if '--debug' in sys.argv else None)
