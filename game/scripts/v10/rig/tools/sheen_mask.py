#!/usr/bin/env python3
"""Generate an 8-bit legwear sheen mask PNG in a rig layer's texture space from gestures.json -> shaders.sheen.

    python3 game/scripts/v10/rig/tools/sheen_mask.py game/assets/v10/rig/mc_gown

Contract (game/scripts/v10/rig/DATA.md, docs/LEGWEAR.md §5.1, §6):
- Reads <rig_dir>/gestures.json -> shaders.sheen: layer, mask, knee_y, polys (in body.png px), optional feather.
- Rasterises polys into the target layer texture's pixel space (offset by layers_meta.json[layer].origin),
  multiplies by the layer's alpha so transparent pixels stay 0, feathers softly, and HARD-ZEROS every row above
  knee_y (body_y < knee_y -> 0).
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi


def build_mask(rig_dir: str) -> dict:
    g_path = os.path.join(rig_dir, 'gestures.json')
    gd = json.load(open(g_path, encoding='utf-8'))
    cfg = gd.get('shaders', {}).get('sheen')
    if not cfg:
        raise SystemExit(f'No shaders.sheen in {g_path}')
    layer = cfg.get('layer', 'body')
    mask_name = cfg.get('mask', 'sheen_mask.png')
    knee_y = int(np.ceil(float(cfg['knee_y'])))
    polys = cfg.get('polys', [])
    feather = float(cfg.get('feather', 6.0))

    meta_path = os.path.join(rig_dir, 'layers_meta.json')
    meta = json.load(open(meta_path, encoding='utf-8')) if os.path.exists(meta_path) else {}
    origin = meta.get(layer, {}).get('origin', [0, 0])
    ox, oy = int(origin[0]), int(origin[1])

    tex_file = 'layer_body.png' if layer == 'body' else f'layer_{layer}.png'
    if not os.path.exists(os.path.join(rig_dir, tex_file)) and layer == 'body':
        tex_file = 'body.png'
    tex = Image.open(os.path.join(rig_dir, tex_file)).convert('RGBA')
    W, H = tex.size
    alpha = np.asarray(tex)[..., 3].astype(np.float32) / 255.0

    canvas = Image.new('L', (W, H), 0)
    dr = ImageDraw.Draw(canvas)
    for poly in polys:
        pts = [(float(p[0]) - ox, float(p[1]) - oy) for p in poly]
        if len(pts) >= 3:
            dr.polygon(pts, fill=255)
    m = np.asarray(canvas).astype(np.float32) / 255.0
    if feather > 0:
        m = ndi.gaussian_filter(m, feather)
    m = m * (alpha > 0.08).astype(np.float32) * alpha

    # Strict LEGWEAR §5.1 / §6 rule: zero pixels above knee_y in body.png space
    cut_row = max(0, min(H, knee_y - oy))
    if cut_row > 0:
        m[:cut_row, :] = 0.0

    out = np.clip(np.round(m * 255.0), 0, 255).astype(np.uint8)
    out_path = os.path.join(rig_dir, mask_name)
    Image.fromarray(out, mode='L').save(out_path)
    above = int(out[:cut_row, :].sum()) if cut_row > 0 else 0
    nonzero = int((out > 0).sum())
    stats = {'rig_dir': rig_dir, 'mask': mask_name, 'size': [W, H], 'knee_y': knee_y,
             'above_knee_sum': above, 'nonzero_px': nonzero}
    print(json.dumps(stats))
    return stats


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise SystemExit('Usage: sheen_mask.py <rig_dir> [...]')
    for arg in sys.argv[1:]:
        build_mask(arg)
