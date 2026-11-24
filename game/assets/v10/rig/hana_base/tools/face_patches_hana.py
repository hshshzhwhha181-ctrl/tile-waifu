#!/usr/bin/env python3
"""Hana's face patches. Reuses scripts/v10/rig/tools/face_patches.py (alignment, colour match, feathered diff
patches) with her boxes; the shared tool is imported, not copied.

    python3 face_patches_hana.py <art 2048.png> <variants dir> <out dir>

Variants (Higgsfield gpt_image_2_6, quality high, 1k, from the 700x700 face crop REF_BOX upscaled to 1024 =
media bda44a8b-1b57-495f-a3fd-2a4b4430be3d; jobs in README.md):
  v1 eyes closed + closed smile   -> eyes_closed (+ winks), mouth_closed
  v2 laugh ^^                      -> eyes_happy, mouth_ah (open laugh with tongue)
  v3 pout + frown brows            -> eyes_frown, mouth_pout
  v4 'oh'                          -> mouth_oh
  v5 half-lidded sly + small open  -> eyes_half, mouth_small
  v6 pucker (air kiss)             -> mouth_pucker
The base art itself is the big toothy grin: mouth "open" = no patch.
"""
import importlib.util, json, os, sys
import numpy as np
from PIL import Image

SRC, GEN, OUT = sys.argv[1], sys.argv[2].rstrip('/') + '/', sys.argv[3]
here = os.path.dirname(os.path.abspath(__file__))
shared = os.path.normpath(os.path.join(here, '../../../../../scripts/v10/rig/tools/face_patches.py'))
sys.argv = [shared, SRC, GEN, OUT]
spec = importlib.util.spec_from_file_location('face_patches', shared)
fp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fp)
fp.REF_BOX = (700, 60, 1400, 760)  # face crop in 2048 px (body px 478..957, 41..520)

EYES_BOX = (628, 186, 852, 300)
E_ALIGN = dict(align_box=(600, 150, 880, 330), exclude=(640, 200, 840, 290))
EYE_ELL = [(690, 256, 50, 30), (797, 242, 40, 28)]
BROW_ELL = [(690, 246, 54, 44), (796, 232, 44, 42)]
MOUTH_BOX = (686, 282, 834, 386)
M_ALIGN = dict(align_box=(650, 262, 870, 410), exclude=(700, 292, 822, 376))
MOUTH_ELL = (760, 334, 56, 36)

prev = []
meta = {}


def mk(v, box, ell, name, **kw):
    p, c, o = fp.make_patch(GEN + v + '.png', box, ell, name, **kw)
    prev.append((c, o))
    meta[name] = {'file': name + '.png', 'pos': p['pos']}


mk('v1', EYES_BOX, EYE_ELL, 'eyes_closed', **E_ALIGN)
mk('v2', EYES_BOX, EYE_ELL, 'eyes_happy', **E_ALIGN)
mk('v3', EYES_BOX, BROW_ELL, 'eyes_frown', **E_ALIGN)
mk('v5', EYES_BOX, BROW_ELL, 'eyes_half', **E_ALIGN)
mk('v1', MOUTH_BOX, MOUTH_ELL, 'mouth_closed', thresh=10, **M_ALIGN)
mk('v5', MOUTH_BOX, MOUTH_ELL, 'mouth_small', thresh=10, **M_ALIGN)
mk('v2', (680, 282, 840, 396), (760, 340, 62, 44), 'mouth_ah', thresh=10, align_box=(640, 262, 880, 420), exclude=(690, 292, 830, 390))
mk('v4', MOUTH_BOX, MOUTH_ELL, 'mouth_oh', thresh=10, **M_ALIGN)
mk('v6', MOUTH_BOX, MOUTH_ELL, 'mouth_pucker', thresh=10, **M_ALIGN)
mk('v3', (640, 262, 860, 396), [(760, 334, 56, 36), (700, 318, 44, 48), (820, 306, 32, 46)], 'mouth_pout',
   thresh=8, grow=6, feather=6.0, align_box=(620, 230, 880, 420), exclude=(650, 272, 850, 390))
fp.sheet(prev, OUT + '/face_preview.png')

# winks: split the closed-eyes patch at the bridge of the nose
e = np.asarray(Image.open(f'{OUT}/eyes_closed.png')).copy()
h, w = e.shape[:2]
yy, xx = np.mgrid[0:h, 0:w]
split_x = 748
t = np.clip((xx + EYES_BOX[0] - split_x) / 10.0, 0, 1)
for name, k in (('eyeL_closed', 1 - t), ('eyeR_closed', t)):
    q = e.copy(); q[..., 3] = (e[..., 3] * k).astype(np.uint8)
    Image.fromarray(q).save(f'{OUT}/{name}.png')
    meta[name] = {'file': name + '.png', 'pos': list(EYES_BOX[:2])}


# blush: soft cheek glow (sun-kissed, a little warmer than mc's pink)
def glow(cx, cy, rx, ry, a):
    d = ((xx + EYES_BOX[0] - cx) / rx) ** 2 + ((yy + EYES_BOX[1] - cy) / ry) ** 2
    return a * np.exp(-d * 2.2)


A = np.maximum(glow(688, 290, 36, 15, 0.6), glow(812, 272, 26, 14, 0.55))
b = np.zeros((h, w, 4), np.float32)
b[..., 0] = 255; b[..., 1] = 95; b[..., 2] = 105; b[..., 3] = A * 255
Image.fromarray(b.astype(np.uint8)).save(f'{OUT}/blush.png')
meta['blush'] = {'file': 'blush.png', 'pos': list(EYES_BOX[:2])}
json.dump(meta, open(f'{OUT}/face_patches.json', 'w'), indent=1)
print('patches', sorted(meta))
