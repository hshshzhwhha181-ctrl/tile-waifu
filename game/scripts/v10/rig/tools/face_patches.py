#!/usr/bin/env python3
"""Align face variants (eyes closed, mouth closed, mouth small) to the original and cut feathered
overlay patches at the rig texture scale (1400 px for the 2048 art).

    python3 face_patches.py <art 2048.png> <variants dir> <out dir> [--v2]

The variants were made with Higgsfield gpt_image_2_6 from a 700x700 crop of the face (REF_BOX,
upscaled to 1024) with prompts like "same image, identical in every way, only her eyes are gently
closed" (0.75 credits each). Each variant is pasted back into the full art, sub-pixel aligned by
phase correlation on the area AROUND the feature, colour-matched on a ring, and only the pixels
that really changed (inside a soft ellipse) are kept, with feathered edges.
FOR THE NEXT HEROINE: edit REF_BOX, the boxes / ellipses and the variant file names below.
"""
import sys, json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage.registration import phase_cross_correlation

SRC, GEN, OUT = sys.argv[1], sys.argv[2].rstrip('/') + '/', sys.argv[3]  # [--v2]
S = 1400 / 2048.0
REF_BOX = (700, 100, 1400, 800)  # face_ref crop in 2048 px

orig = Image.open(SRC).convert('RGB')
o14 = np.asarray(orig.resize((1400, 1400), Image.LANCZOS)).astype(np.float32)


def variant_to_1400(path):
    v = Image.open(path).convert('RGB').resize((700, 700), Image.LANCZOS)
    full = orig.copy()
    full.paste(v, REF_BOX[:2])
    return np.asarray(full.resize((1400, 1400), Image.LANCZOS)).astype(np.float32)


def gray(a):
    return a @ np.array([0.299, 0.587, 0.114], np.float32)


def align(var, box, exclude):
    """Sub-pixel shift that best maps var onto orig inside box, ignoring exclude box."""
    x0, y0, x1, y1 = box
    a = gray(o14[y0:y1, x0:x1]).copy()
    b = gray(var[y0:y1, x0:x1]).copy()
    ex0, ey0, ex1, ey1 = exclude
    m = np.ones_like(a, bool)
    m[ey0 - y0:ey1 - y0, ex0 - x0:ex1 - x0] = False
    a[~m] = a[m].mean(); b[~m] = b[m].mean()
    shift, err, _ = phase_cross_correlation(a, b, upsample_factor=20)
    return shift  # (dy, dx) to apply to var


def make_patch(var_path, box, ellipse, name, thresh=14.0, grow=4, feather=5.0, align_box=None, exclude=None):
    var = variant_to_1400(var_path)
    if align_box is not None:
        dy, dx = align(var, align_box, exclude)
        var = np.stack([ndi.shift(var[..., c], (dy, dx), order=3, mode='nearest') for c in range(3)], -1)
    else:
        dy = dx = 0.0
    x0, y0, x1, y1 = box
    o = o14[y0:y1, x0:x1]
    v = var[y0:y1, x0:x1].copy()
    h, w = o.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # elliptical limit (soft) where the patch may live
    ells = ellipse if isinstance(ellipse, list) else [ellipse]
    e = np.min([((xx + x0 - cx) / rx) ** 2 + ((yy + y0 - cy) / ry) ** 2 for cx, cy, rx, ry in ells], 0)
    lim = np.clip((1.25 - e) / 0.5, 0, 1)
    # colour match: mean difference on a ring where lim is small but nonzero
    ring = (e > 0.9) & (e < 1.6)
    corr = (o[ring] - v[ring]).mean(0)
    v = np.clip(v + corr * 0.85, 0, 255)
    diff = np.abs(gray(o) - gray(v))
    core = ndi.gaussian_filter(diff, 1.2) > thresh
    core = ndi.binary_closing(core, iterations=3)
    core = ndi.binary_fill_holes(core)
    core = ndi.binary_dilation(core, iterations=grow)
    a = ndi.gaussian_filter(core.astype(np.float32), feather)
    a = np.clip(a * 1.6, 0, 1) * lim
    rgba = np.dstack([v, a * 255]).astype(np.uint8)
    Image.fromarray(rgba, 'RGBA').save(f'{OUT}/{name}.png')
    # preview: composite over original
    comp = o * (1 - a[..., None]) + v * a[..., None]
    print(name, 'shift', round(float(dx), 2), round(float(dy), 2), 'corr', np.round(corr, 1), 'cover', round(float((a > 0.5).mean()), 3))
    return {'name': name, 'pos': [x0, y0], 'size': [w, h]}, comp.astype(np.uint8), o.astype(np.uint8)


def sheet(prev, path):
    tiles = [np.concatenate([o, c], 1) for c, o in prev]
    W = max(t.shape[1] for t in tiles)
    s = np.concatenate([np.pad(t, ((0, 4), (0, W - t.shape[1]), (0, 0))) for t in tiles], 0)
    Image.fromarray(s).resize((s.shape[1] * 3, s.shape[0] * 3), Image.LANCZOS).save(path)


def v1_set(G):
    """The pilot's patches (g0 eyes closed, g3 mouth closed, g5 mouth small) plus winks and blush."""
    eyes_box = (570, 160, 830, 300)
    mouth_box = (660, 262, 790, 352)
    meta = []
    prev = []
    p, c, o = make_patch(G + 'g0.png', eyes_box, [(636, 245, 58, 34), (756, 206, 60, 34)], 'eyes_closed', align_box=(560, 120, 860, 360), exclude=(580, 170, 820, 280))
    meta.append(p); prev.append((c, o))
    p, c, o = make_patch(G + 'g3.png', mouth_box, (722, 306, 52, 34), 'mouth_closed', thresh=10, align_box=(620, 230, 830, 400), exclude=(670, 270, 780, 345))
    meta.append(p); prev.append((c, o))
    p, c, o = make_patch(G + 'g5.png', mouth_box, (722, 306, 52, 34), 'mouth_small', thresh=10, align_box=(620, 230, 830, 400), exclude=(670, 270, 780, 345))
    meta.append(p); prev.append((c, o))
    json.dump(meta, open(f'{OUT}/face_patches.json', 'w'), indent=1)
    sheet(prev, OUT + '/face_preview.png')
    # winks: split the closed-eyes patch at the bridge of the nose (soft over 10 px)
    e = np.asarray(Image.open(f'{OUT}/eyes_closed.png')).copy()
    h, w = e.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    split_x = 692
    t = np.clip((xx + eyes_box[0] - split_x) / 10.0, 0, 1)
    for name, k in (('eyeL_closed', 1 - t), ('eyeR_closed', t)):
        q = e.copy(); q[..., 3] = (e[..., 3] * k).astype(np.uint8)
        Image.fromarray(q).save(f'{OUT}/{name}.png')
    # blush: soft cheek glow in the same box as the eyes (cheek centres in body px)
    def glow(cx, cy, rx, ry, a):
        d = ((xx + eyes_box[0] - cx) / rx) ** 2 + ((yy + eyes_box[1] - cy) / ry) ** 2
        return a * np.exp(-d * 2.2)
    A = np.maximum(glow(640, 283, 34, 15, 0.55), glow(790, 248, 32, 14, 0.55))
    b = np.zeros((h, w, 4), np.float32)
    b[..., 0] = 255; b[..., 1] = 105; b[..., 2] = 130; b[..., 3] = A * 255
    Image.fromarray(b.astype(np.uint8)).save(f'{OUT}/blush.png')


def v2_set(G):
    """v2 expression patches (Higgsfield gpt_image_2_6 from the same face_ref, 0.75 credits each):
    v0 pucker (air kiss), v3 pout with puffed cheeks, v4 'ah', v5 'oh', v6 happy ^^ eyes, v7 frown brows."""
    mouth_box = (640, 250, 800, 362)
    m_align = dict(align_box=(600, 220, 850, 400), exclude=(650, 262, 790, 352))
    prev = []
    for f, name in (('v0', 'mouth_pucker'), ('v4', 'mouth_ah'), ('v5', 'mouth_oh')):
        p, c, o = make_patch(G + f + '.png', mouth_box, (722, 308, 56, 38), name, thresh=10, **m_align)
        prev.append((c, o))
    # the pout puffs both cheeks: wider box and two cheek ellipses besides the mouth
    p, c, o = make_patch(G + 'v3.png', (590, 236, 830, 372), [(722, 308, 56, 38), (640, 305, 46, 52), (780, 300, 44, 56)],
                         'mouth_pout', thresh=8, grow=6, feather=6.0, align_box=(570, 200, 860, 400), exclude=(600, 250, 820, 365))
    prev.append((c, o))
    eyes_box = (566, 140, 840, 300)
    e_align = dict(align_box=(550, 110, 870, 360), exclude=(575, 150, 830, 285))
    p, c, o = make_patch(G + 'v6.png', eyes_box, [(636, 242, 60, 36), (756, 204, 62, 36)], 'eyes_happy', **e_align)
    prev.append((c, o))
    p, c, o = make_patch(G + 'v7.png', eyes_box, [(634, 230, 64, 48), (756, 196, 66, 48)], 'eyes_frown', **e_align)
    prev.append((c, o))
    sheet(prev, OUT + '/face_preview_v2.png')


if __name__ == '__main__':
    # FOR THE NEXT HEROINE: copy v1_set / v2_set and edit the boxes, ellipses and file names.
    if '--v2' in sys.argv:
        v2_set(GEN)
    else:
        v1_set(GEN)
