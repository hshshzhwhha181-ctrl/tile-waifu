#!/usr/bin/env python3
"""Split the cutout into separate mesh layers (v2): twin tails behind the body, the raised arm, the thigh in
the dress slit. Each split part is painted UNDER its neighbours (inpainted), so it can slide instead of
stretching the single mesh.

    python3 split_layers.py game/assets/v10/rig/mc_gown/rig_def.json [--debug out_dir]

Reads rig_def["layers"] (see the _doc there). For every split layer:
  * selection  mode "hair": hair-coloured pixels inside `zone` that are not part of the solid "front" (skin, lace,
               dress: big non-hair blobs); mode "front": front pixels inside `zone`; mode "poly": the zone itself.
               `exclude` polygons are always left in the body.
  * root       pixels within `root.r0` px of `root.at` stay in the body too, cross-fading over `root.fade` px:
               the layer is complete underneath, the body fades out on top, so at rest the composite equals the
               art. Near the root the mesh weights of both layers match (same parent bone), so nothing ghosts.
  * extension  the layer is continued `ext` px under whatever covered it (only inside `ext_zone` when given),
               with OpenCV Telea inpainting from the layer's own pixels only, a little darker with depth
               (ambient occlusion), so a slide reveals plausible hair / lace / skin, never a hole.
Writes layer_<name>.png (cropped to its bbox), layer_body.png (the cutout minus the split parts) and
layers_meta.json ({name: {origin, size}}) next to rig_def.json. build_rig.py then makes one skinned Polygon2D per
layer. Needs numpy, scipy, pillow, scikit-image, opencv-python-headless.
"""
import json, os, sys
import numpy as np
import cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from skimage.color import rgb2hsv
from skimage.morphology import remove_small_objects, disk


def _small_objects(m, n):
    try:
        return remove_small_objects(m, max_size=n - 1)
    except TypeError:
        return remove_small_objects(m, n)


def poly_mask(poly, shape):
    im = Image.new('L', (shape[1], shape[0]), 0)
    ImageDraw.Draw(im).polygon([tuple(p) for p in poly], fill=255)
    return np.asarray(im) > 127


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def bleed(rgb, alpha):
    """Give transparent pixels the colour of the nearest solid one (no dark fringes under bilinear/mipmaps)."""
    solid = alpha > 200
    if not solid.any():
        return rgb
    idx = ndi.distance_transform_edt(~solid, return_distances=False, return_indices=True)
    out = rgb.copy()
    m = ~solid
    out[m] = rgb[idx[0], idx[1]][m]
    return out


def inpaint_from(rgb, known, fill, radius=6):
    """Inpaint `fill` pixels using only `known` pixels as the source (everything else is treated as unknown),
    working in the bbox of fill grown by 64 px."""
    ys, xs = np.nonzero(fill)
    if len(ys) == 0:
        return rgb.copy()
    H, W = known.shape
    y0, y1 = max(ys.min() - 64, 0), min(ys.max() + 65, H)
    x0, x1 = max(xs.min() - 64, 0), min(xs.max() + 65, W)
    src = rgb[y0:y1, x0:x1].copy()
    k = known[y0:y1, x0:x1]
    unknown = (~k).astype(np.uint8) * 255
    res = cv2.inpaint(np.ascontiguousarray(src[..., ::-1]), unknown, radius, cv2.INPAINT_TELEA)[..., ::-1]
    out = rgb.copy()
    f = fill[y0:y1, x0:x1]
    out[y0:y1, x0:x1][f] = res[f]
    return out


def main(def_path, debug_dir=None):
    d = json.load(open(def_path))
    base = os.path.dirname(os.path.abspath(def_path))
    L = d['layers']
    src = np.asarray(Image.open(os.path.join(base, L.get('source', 'body.png'))).convert('RGBA')).copy()
    H, W = src.shape[:2]
    rgb = src[..., :3].copy()
    a = src[..., 3].astype(np.float32) / 255.0
    hsv = rgb2hsv(rgb)
    hue, sat, val = hsv[..., 0] * 360.0, hsv[..., 1], hsv[..., 2]
    hc = L['hair_color']
    hair_col = ((hue >= hc['hue'][0]) | (hue < hc['hue'][1] - 360.0)) & (sat > hc['s_min']) & (val > hc['v_min'])
    # solid "front": skin, lace, dress, gold. Thin dark strokes inside the hair are opened away; lace holes closed.
    nonhair = (a > 0.5) & ~hair_col
    front = cv2.morphologyEx(nonhair.astype(np.uint8), cv2.MORPH_OPEN, disk(2).astype(np.uint8)) > 0
    front = _small_objects(front, 1500)
    front = cv2.morphologyEx(front.astype(np.uint8), cv2.MORPH_CLOSE, disk(4).astype(np.uint8)) > 0
    # holes in the front: fill the ones that are fully opaque (skin seen through lace, pink skin shading);
    # keep the big ones that hold background (the gap between an arm and the waist, where hair shows through);
    # small ones are lace holes, even when the background shows through them
    lab, n = ndi.label(~front)
    if n:
        idx = np.arange(1, n + 1)
        size = ndi.sum(np.ones_like(a), lab, idx)
        clear = ndi.sum((a < 0.3).astype(np.float32), lab, idx)
        border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])))
        fill = np.array([(i not in border) and (size[i - 1] < 400 or (clear[i - 1] < 0.03 * size[i - 1] and size[i - 1] < 40000)) for i in idx])
        front |= fill[lab - 1] & (lab > 0)
    for g in L.get('front_grow', []):
        # locally grow the front (lace scallops and see-through glove edges belong to the glove, not the hair)
        grown = cv2.dilate(front.astype(np.uint8), disk(int(g['px'])).astype(np.uint8)) > 0
        front |= grown & poly_mask(g['poly'], (H, W)) & (a > 0.05)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    body_keep = np.ones((H, W), np.float32)
    meta = {}
    dbg_tiles = []
    taken = np.zeros((H, W), bool)
    unders = []  # (mask, root factor) of body areas to under-paint below layers drawn IN FRONT of the body
    for lay in L['split']:
        name = lay['name']
        zone = poly_mask(lay['zone'], (H, W))
        for p in lay.get('exclude', []):
            zone &= ~poly_mask(p, (H, W))
        if lay.get('inset'):
            zone = ndi.binary_erosion(zone, iterations=int(lay["inset"]), border_value=1)
        mode = lay['mode']
        if mode == 'hair':
            sel = zone & (a > 0) & ~front  # every faint edge pixel too, or it ghosts in the body
            # ...but the antialiased fringe of the front (dark dress / lace edge, not hair-coloured) stays with it,
            # or a dark ghost of the dress edge rides on the hair
            fringe = (cv2.dilate(front.astype(np.uint8), disk(3).astype(np.uint8)) > 0) & ~front & ~hair_col
            sel &= ~fringe
        elif mode == 'front':
            # solid pixels plus the dark outline strokes hugging them (but not the hair behind)
            near = cv2.dilate(front.astype(np.uint8), disk(3).astype(np.uint8)) > 0
            sel = zone & (a > 0) & (front | (near & ~hair_col))
            for p in lay.get('take_all', []):
                # no hair behind here: every opaque pixel of the zone is the part (pinkish lace edges included)
                sel |= zone & (a > 0.02) & poly_mask(p, (H, W))
        elif mode == 'color':
            # an ornament picked by colour (gold), grown by its dark outline
            c = lay['color']
            m = (hue >= c['hue'][0]) & (hue <= c['hue'][1]) & (sat > c['s_min']) & (val > c['v_min'])
            m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, disk(2).astype(np.uint8)) > 0
            m = cv2.dilate(m.astype(np.uint8), disk(int(c.get('grow', 2))).astype(np.uint8)) > 0
            sel = zone & (a > 0) & m
        else:
            sel = zone & (a > 0)
        sel &= ~taken
        sel = _small_objects(sel, int(lay.get('min_px', 200)))
        taken |= sel
        r = np.ones((H, W), np.float32)
        if 'root' in lay:
            rt = lay['root']
            dist = np.hypot(xx - rt['at'][0], yy - rt['at'][1])
            r = smoothstep(rt['r0'], rt['r0'] + rt['fade'], dist)
        over = bool(lay.get('over'))
        # hard cut: the pixel lives in exactly one layer, except at the root, where the layer BEHIND is complete and
        # the body fades out on top of it, or the layer IN FRONT fades in over the complete body
        body_keep *= 1.0 - sel * ((r >= 0.999) if over else r)
        if over:
            # a layer in FRONT of the body (the hand on the hip): the body gets the dress painted in under it where
            # the `under` polygon says there is body behind; elsewhere (the arm against the hair) it is left open
            und = np.zeros((H, W), bool)
            for p in lay.get('under', []):
                und |= poly_mask(p, (H, W))
            unders.append((sel & und, (r >= 0.999).astype(np.float32)))
        # layer colour: the art inside the selection, inpainted extension under whatever covered it
        E = int(lay.get('ext', 0))
        lay_rgb = rgb.copy()
        ext = np.zeros((H, W), bool)
        depth = np.zeros((H, W), np.float32)
        if E > 0:
            dsel = ndi.distance_transform_edt(~sel)
            ext = (dsel <= E) & ~sel
            if lay.get('ext_under', 'covered') == 'covered':
                ext &= (a > 0.5)  # only under the art that covered it, never out into the background
            if 'ext_zone' in lay:
                ext &= poly_mask(lay['ext_zone'], (H, W))
            ext = _small_objects(ext, 30)
            # source: the layer's own solid pixels, minus a rim along its cut edge (outline strokes, trims and
            # antialiasing there would smear into the under-painting)
            rim = float(lay.get('rim', 4))
            core = sel & (a > 0.85) & (ndi.distance_transform_edt(sel | (a < 0.3)) > rim)
            lay_rgb = inpaint_from(rgb, core, ext | (sel & ~core), radius=int(lay.get('radius', 6)))
            ext_alpha = np.ones((H, W), np.float32)
            if lay.get('fill', 'telea') == 'mirror':
                # strands and lace keep their texture: an under-painted pixel copies the part's pixel mirrored
                # across the nearest point of the cut, colour AND alpha (sparse hair stays sparse, a gap stays a
                # gap); Telea only where the mirror lands on something else
                cut = (a > 0.5) & ~sel
                src_ok = sel & (ndi.distance_transform_edt(~cut) > rim)
                # not a reflection (that echoes the cut's outline) but a translation by a fixed E + rim along the
                # normal: the strip of hair just outside the cut, slid in under it, strands keep their direction
                dd, (iy, ix) = ndi.distance_transform_edt(~src_ok, return_indices=True)
                py, px = np.mgrid[0:H, 0:W].astype(np.float32)
                nrm = np.maximum(dd, 1e-3)
                T = float(E + rim)
                my = np.clip(np.round(py + (iy - py) / nrm * T), 0, H - 1).astype(int)
                mx = np.clip(np.round(px + (ix - px) / nrm * T), 0, W - 1).astype(int)
                hit = ext & src_ok[my, mx]
                gap = ext & ~sel[my, mx] & (a[my, mx] < 0.3)
                mir = rgb[my, mx].astype(np.float32)
                k = hit[..., None].astype(np.float32)
                lay_rgb = (lay_rgb.astype(np.float32) * (1 - k) + mir * k).astype(np.uint8)
                ext_alpha = np.where(hit, a[my, mx], np.where(gap, 0.0, 1.0)).astype(np.float32)
                ext_alpha = ndi.gaussian_filter(ext_alpha, 0.6)
            depth = np.where(ext, dsel, 0).astype(np.float32)
            ao = 1.0 - float(lay.get('ao', 0.18)) * np.clip(depth / max(E, 1), 0, 1)
            lay_rgb = np.clip(lay_rgb * ao[..., None], 0, 255).astype(np.uint8)
            lay_rgb[sel] = rgb[sel]
        ext_a = smoothstep(E + 1.0, E - 6.0, depth) * ext if E > 0 else 0.0
        if E > 0:
            ext_a = ext_a * ext_alpha
            # also feather where the under-painting meets open background, so a slide never shows a cut edge
            ext_a = ext_a * np.clip(ndi.distance_transform_edt(ext | sel) / 5.0, 0, 1)
        la = np.clip(np.where(sel, a, 0.0) + ext_a, 0, 1)
        if over:
            la = la * r  # in front: the layer itself fades out at its root, over the intact body
        # where the selection meets the extension the original edge alpha would show a seam: make it solid
        la = np.where(sel & (ndi.binary_dilation(ext, iterations=2)) , np.maximum(la, 1.0 * (a > 0.3)), la)
        A8 = (la * 255).astype(np.uint8)
        out = np.dstack([bleed(lay_rgb, A8), A8])
        ys, xs = np.nonzero(A8 > 0)
        pad = 8
        x0, y0 = max(int(xs.min()) - pad, 0), max(int(ys.min()) - pad, 0)
        x1, y1 = min(int(xs.max()) + pad + 1, W), min(int(ys.max()) + pad + 1, H)
        Image.fromarray(out[y0:y1, x0:x1], 'RGBA').save(os.path.join(base, 'layer_%s.png' % name), optimize=True)
        meta[name] = {'origin': [x0, y0], 'size': [x1 - x0, y1 - y0]}
        print(name, 'sel px', int(sel.sum()), 'ext px', int(ext.sum()), 'bbox', (x0, y0, x1, y1))
        dbg_tiles.append((name, out, sel))
    body_rgb = rgb.copy()
    ba_f = a * body_keep
    if unders:
        fill = np.zeros((H, W), bool)
        for m, _ in unders:
            fill |= m
        known = (a > 0.85) & (body_keep > 0.99) & ~taken & (ndi.distance_transform_edt(~taken) > 3)
        painted = inpaint_from(rgb, known, fill, radius=8)
        for m, r in unders:
            k = (m * r)[..., None]
            body_rgb = (body_rgb * (1 - k) + painted * k).astype(np.uint8)
            ba_f = np.maximum(ba_f, np.clip(ndi.gaussian_filter(m.astype(np.float32), 0.8) * 1.6 - 0.3, 0, 1) * (m > 0) * r)
        print('under-painted body px', int(fill.sum()))
    # drop specks: tiny opaque islands left between split parts would only ride the wrong bone
    solid = ba_f > 0.5
    specks = solid & ~_small_objects(solid, 60)
    ba_f[ndi.binary_dilation(specks, iterations=1) & (ba_f < 1.01)] = 0.0
    ba = (np.clip(ba_f, 0, 1) * 255).astype(np.uint8)
    body = np.dstack([bleed(body_rgb, ba), ba])
    Image.fromarray(body, 'RGBA').save(os.path.join(base, 'layer_body.png'), optimize=True)
    meta['body'] = {'origin': [0, 0], 'size': [W, H]}
    json.dump(meta, open(os.path.join(base, 'layers_meta.json'), 'w'), indent=1)
    if debug_dir:
        os.makedirs(debug_dir, exist_ok=True)
        def on_green(x):
            g = Image.new('RGBA', (x.shape[1], x.shape[0]), (0, 150, 0, 255))
            g.alpha_composite(Image.fromarray(x, 'RGBA'))
            return g.convert('RGB').resize((x.shape[1] // 2, x.shape[0] // 2), Image.LANCZOS)
        on_green(body).save(os.path.join(debug_dir, 'layer_body.png'))
        cols = [(255, 60, 60), (60, 220, 255), (255, 220, 40), (170, 90, 255), (60, 255, 120), (255, 140, 0)]
        ov = rgb.astype(np.float32) * 0.5
        for i, (n, x, s) in enumerate(dbg_tiles):
            on_green(x).save(os.path.join(debug_dir, 'layer_%s.png' % n))
            ov[s] = ov[s] * 0.4 + np.array(cols[i % len(cols)], np.float32) * 0.6
        Image.fromarray(ov.astype(np.uint8)).save(os.path.join(debug_dir, 'selections.png'))
        f = np.zeros((H, W, 3), np.uint8)
        f[front] = (60, 60, 200); f[hair_col & (a > 0.5)] = (255, 90, 170)
        Image.fromarray(f).resize((W // 2, H // 2)).save(os.path.join(debug_dir, 'front.png'))


if __name__ == '__main__':
    dbg = sys.argv[sys.argv.index('--debug') + 1] if '--debug' in sys.argv else None
    main(sys.argv[1], dbg)
