#!/usr/bin/env python3
"""Build a V10LiveRig scene (Skeleton2D + skinned Polygon2D layers) from a rig_def.json.

    python3 build_rig.py game/assets/v10/rig/mc_gown/rig_def.json [--debug out_dir]

For every mesh layer it makes a regular vertex grid over the cells of the layer texture that hold opaque pixels,
paints bone weights region by region (feathered polygons, y ramps, discs and chains), smooths them, keeps the 4
strongest per vertex (continuously, so no seams) and writes <asset dir>/rig.tscn next to rig_def.json.
--debug writes a weight + mesh overlay PNG per layer.

v2: rig_def "mesh_layers" lists several textures (cut by split_layers.py), each its own skinned Polygon2D sharing
the one Skeleton2D, drawn in list order (back to front). A layer paints its own "regions" over a "base" bone;
entries may be {"ref": <top-level region name>, ...overrides}; "default" = the whole top-level list. Without
"mesh_layers" the pilot's single mesh over rig_def "texture" is built. Needs numpy, scipy, pillow.
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

Q = 4  # weight maps are painted at 1/Q resolution, then sampled bilinearly at the vertices


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def raster_poly(poly, shape):
    im = Image.new('L', (shape[1], shape[0]), 0)
    ImageDraw.Draw(im).polygon([(x / Q, y / Q) for x, y in poly], fill=255)
    return np.asarray(im) > 127


def feathered(poly, feather, shape, side='both'):
    """Membership 0..1 with a smooth falloff around the polygon edge.
    side 'both': +-feather around the edge; 'in': the ramp lies inside (0 at the edge, 1 at 2*feather in) -
    use it for a part that is BEHIND its neighbours (hair behind the body), so the part in front stays rigid;
    'out': the ramp lies outside (1 at the edge) - for a part IN FRONT (an arm over the dress)."""
    inside = raster_poly(poly, shape)
    din = ndi.distance_transform_edt(inside) * Q
    dout = ndi.distance_transform_edt(~inside) * Q
    sd = np.where(inside, din, -dout)
    if side == 'in':
        return smoothstep(0.0, 2.0 * feather, sd)
    if side == 'out':
        return smoothstep(-2.0 * feather, 0.0, sd)
    return smoothstep(-feather, feather, sd)


def chain_param(joints, shape):
    """Continuous parameter s along the joint polyline (bone i covers s in [i, i+1]) and distance along it in px."""
    h, w = shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    px, py = (xx + 0.5) * Q, (yy + 0.5) * Q
    best_d = np.full(shape, 1e9, np.float32)
    best_s = np.zeros(shape, np.float32)
    lens = []
    for i in range(len(joints) - 1):
        ax, ay = joints[i]; bx, by = joints[i + 1]
        vx, vy = bx - ax, by - ay
        L2 = vx * vx + vy * vy
        lens.append(L2 ** 0.5)
        t = ((px - ax) * vx + (py - ay) * vy) / L2
        if i > 0:
            t = np.maximum(t, 0.0)
        if i < len(joints) - 2:
            t = np.minimum(t, 1.0)
        cx, cy = ax + t * vx, ay + t * vy
        d = np.hypot(px - cx, py - cy)
        m = d < best_d
        best_d[m] = d[m]
        best_s[m] = (i + t)[m]
    cum = np.concatenate([[0], np.cumsum(lens)])
    si = np.clip(np.floor(best_s), 0, len(lens) - 1).astype(int)
    dist = cum[si] + (best_s - si) * np.array(lens)[si]
    return best_s, dist


def paint(d, regions, shape, base_bone='root'):
    """Weight maps (n_bones, h, w) at 1/Q resolution for a list of regions painted in order."""
    bones = d['bones']
    names = [b['name'] for b in bones]
    bidx = {n: i for i, n in enumerate(names)}
    pos = {b['name']: b['pos'] for b in bones}
    end = {b['name']: b.get('end') for b in bones}
    children = {n: [b['name'] for b in bones if b['parent'] == n] for n in names}
    gy, gx = np.mgrid[0:shape[0], 0:shape[1]].astype(np.float32)
    yy = (gy + 0.5) * Q
    xx = (gx + 0.5) * Q
    Wm = np.zeros((len(bones),) + shape, np.float32)
    Wm[bidx[base_bone]] = 1.0

    def over(m, dist):
        """Paint membership m with bone distribution dist {bone: map} over the current weights."""
        Wm[:] *= (1.0 - m)[None]
        for n, dm in dist.items():
            Wm[bidx[n]] += m * dm

    for r in regions:
        t = r['type']
        if t == 'ramp_y':
            m = smoothstep(r['from'], r['to'], yy)
            over(m, {r['bone']: 1.0})
        elif t == 'poly':
            m = feathered(r['poly'], r['feather'], shape, r.get('side', 'both')) * r.get('strength', 1.0)
            over(m, {r['bone']: 1.0})
        elif t == 'disc':
            # lock: everything within r px of 'at' belongs to 'bone', fading out over 'fade' px. Used at the
            # roots of split layers so both layers carry identical weights where they cross-fade.
            dd = np.hypot(xx - r['at'][0], yy - r['at'][1])
            m = 1.0 - smoothstep(r['r'], r['r'] + r['fade'], dd)
            over(m, {r['bone']: 1.0})
        elif t == 'chain':
            cb = r['bones']
            joints = [pos[n] for n in cb]
            last = cb[-1]
            joints.append(end[last] or pos[children[last][0]])
            s, dist = chain_param(joints, shape)
            m = feathered(r['poly'], r['feather'], shape, r.get('side', 'both'))
            if r.get('root_fade'):
                m = m * smoothstep(0.0, r['root_fade'], dist)
            n = len(cb)
            b = r.get('blend', 0.3)
            # piecewise-linear partition: bone i is full inside [i+b, i+1-b], cross-fades over 2b around joints
            parts = []
            for i in range(n):
                lo = np.ones(shape, np.float32) if i == 0 else smoothstep(i - b, i + b, s)
                hi = np.ones(shape, np.float32) if i == n - 1 else 1.0 - smoothstep(i + 1 - b, i + 1 + b, s)
                parts.append(lo * hi)
            parts = np.array(parts)
            sm = r.get('smooth', 0) / Q
            if sm > 0:
                parts = np.array([ndi.gaussian_filter(p, sm) for p in parts])
            parts /= np.maximum(parts.sum(0), 1e-6)[None]
            over(m, {cb[i]: parts[i] for i in range(n)})
        else:
            raise ValueError('unknown region type ' + t)

    # final light smoothing of every map keeps the skin continuous; then renormalise
    Wm = np.array([ndi.gaussian_filter(w, 1.0) for w in Wm])
    Wm /= np.maximum(Wm.sum(0), 1e-6)[None]
    return Wm


def resolve_regions(d, lay):
    """A layer's region list: {"ref": name, ...overrides} pulls a top-level region; "default" = all of them."""
    if lay.get('regions', 'default') == 'default':
        out = list(d['regions'])
    else:
        named = {r['name']: r for r in d['regions']}
        out = []
        for r in lay['regions']:
            if 'ref' in r:
                q = dict(named[r['ref']])
                q.update({k: v for k, v in r.items() if k != 'ref'})
                out.append(q)
            else:
                out.append(r)
    return out + lay.get('extra_regions', [])


def make_mesh(alpha, g, origin):
    """Regular grid over the opaque cells of a layer texture (alpha in texture px). Returns art-px vertices,
    texture-px UVs and triangles."""
    H, W = alpha.shape
    nx, ny = int(np.ceil(W / g)), int(np.ceil(H / g))
    pad = np.zeros((ny * g, nx * g), np.uint8)
    pad[:H, :W] = alpha
    cell = pad.reshape(ny, g, nx, g).max((1, 3)) > 3
    cell = ndi.binary_dilation(cell, iterations=1)  # one cell of slack around the silhouette
    vid = -np.ones((ny + 1, nx + 1), int)
    verts, tris = [], []
    for j in range(ny):
        for i in range(nx):
            if not cell[j, i]:
                continue
            for (a, b) in ((j, i), (j, i + 1), (j + 1, i), (j + 1, i + 1)):
                if vid[a, b] < 0:
                    vid[a, b] = len(verts)
                    verts.append((b * g, a * g))
            v00, v01, v10, v11 = vid[j, i], vid[j, i + 1], vid[j + 1, i], vid[j + 1, i + 1]
            if (i + j) % 2 == 0:
                tris += [(v00, v01, v11), (v00, v11, v10)]
            else:
                tris += [(v00, v01, v10), (v01, v11, v10)]
    UV = np.array(verts, np.float32)
    V = UV + np.array(origin, np.float32)[None]
    return V, UV, tris


def sample_weights(Wm, V, shape, root_idx):
    fx = np.clip(V[:, 0] / Q - 0.5, 0, shape[1] - 1.001)
    fy = np.clip(V[:, 1] / Q - 0.5, 0, shape[0] - 1.001)
    x0, y0 = fx.astype(int), fy.astype(int)
    tx, ty = fx - x0, fy - y0
    VW = (Wm[:, y0, x0] * (1 - tx) * (1 - ty) + Wm[:, y0, x0 + 1] * tx * (1 - ty) +
          Wm[:, y0 + 1, x0] * (1 - tx) * ty + Wm[:, y0 + 1, x0 + 1] * tx * ty).T  # (nv, nb)
    # keep 4 strongest, continuously: subtract the 5th strongest so dropped influences fade to zero
    srt = np.sort(VW, 1)[:, ::-1]
    fifth = srt[:, 4:5] if VW.shape[1] > 4 else np.zeros((len(VW), 1))
    VW = np.maximum(VW - fifth, 0)
    order = np.argsort(-VW, 1)
    keep = np.zeros_like(VW, bool)
    np.put_along_axis(keep, order[:, :4], True, 1)
    VW = np.where(keep, VW, 0)
    VW[VW < 0.004] = 0
    VW /= np.maximum(VW.sum(1, keepdims=True), 1e-6)
    VW[VW.sum(1) == 0, root_idx] = 1.0
    return VW


def build(def_path, debug_dir=None):
    d = json.load(open(def_path))
    base = os.path.dirname(os.path.abspath(def_path))
    W, H = d['size']
    bones = d['bones']
    names = [b['name'] for b in bones]
    pos = {b['name']: b['pos'] for b in bones}
    shape = (H // Q, W // Q)
    meta = {}
    if os.path.exists(os.path.join(base, 'layers_meta.json')):
        meta = json.load(open(os.path.join(base, 'layers_meta.json')))
    layers = [l for l in d.get('mesh_layers', []) if 'name' in l] or [{'name': 'body', 'texture': d['texture']}]
    built = []
    stats = {'bones': len(bones), 'layers': {}}
    for lay in layers:
        ltex = Image.open(os.path.join(base, lay['texture'])).convert('RGBA')
        origin = meta.get(lay['name'], {}).get('origin', [0, 0])
        Wm = paint(d, resolve_regions(d, lay), shape, lay.get('base', 'root'))
        V, UV, tris = make_mesh(np.asarray(ltex)[..., 3], lay.get('grid', d.get('grid', 14)), origin)
        VW = sample_weights(Wm, V, shape, names.index('root'))
        built.append({'name': lay['name'], 'texture': lay['texture'], 'tex': ltex, 'origin': origin,
                      'V': V, 'UV': UV, 'tris': tris, 'VW': VW, 'Wm': Wm})
        stats['layers'][lay['name']] = {'vertices': len(V), 'triangles': len(tris),
                                        'max_influences': int((VW > 0).sum(1).max())}
    write_tscn(d, base, names, pos, bones, built)
    print(json.dumps(stats))
    if debug_dir:
        for b in built:
            debug(d, b, names, pos, debug_dir)
    return stats


def fmt(a):
    return ', '.join(('%.4g' % x) for x in a)


def write_tscn(d, base, names, pos, bones, built):
    rel = os.path.relpath(base, find_project_root(base)).replace(os.sep, '/')
    res = 'res://' + rel
    texs = []
    for b in built:
        if b['texture'] not in texs:
            texs.append(b['texture'])
    out = []
    out.append('[gd_scene load_steps=%d format=3]\n' % (len(texs) + 2))
    out.append('[ext_resource type="Script" path="res://scripts/v10/rig/live_rig.gd" id="1_rig"]')
    for i, t in enumerate(texs):
        out.append('[ext_resource type="Texture2D" path="%s/%s" id="%d_tex"]' % (res, t, i + 2))
    out.append('')
    out.append('[node name="%s" type="Node2D"]' % ''.join(p.capitalize() for p in d['name'].split('_')))
    out.append('script = ExtResource("1_rig")')
    out.append('def_path = "%s/rig_def.json"\n' % res)
    rx, ry = pos['root']
    out.append('[node name="Figure" type="Node2D" parent="."]')
    out.append('position = Vector2(%g, %g)\n' % (rx, ry))
    out.append('[node name="Art" type="Node2D" parent="Figure"]')
    out.append('position = Vector2(%g, %g)\n' % (-rx, -ry))
    paths = {}
    for b in bones:
        n, p = b['name'], b['parent']
        paths[n] = (paths[p] + '/' + n) if p else n
    for b in built:
        # layers draw in list order (back to front); the body layer keeps the node name "Body"
        node = 'Body' if b['name'] == 'body' else 'Layer_' + b['name']
        out.append('[node name="%s" type="Polygon2D" parent="Figure/Art"]' % node)
        out.append('texture_filter = 4')
        out.append('texture = ExtResource("%d_tex")' % (texs.index(b['texture']) + 2))
        out.append('skeleton = NodePath("../Skeleton")')
        out.append('polygon = PackedVector2Array(%s)' % fmt(b['V'].reshape(-1)))
        out.append('uv = PackedVector2Array(%s)' % fmt(b['UV'].reshape(-1)))
        out.append('polygons = [%s]' % ', '.join('PackedInt32Array(%d, %d, %d)' % t for t in b['tris']))
        bl = []
        VW = b['VW']
        for i, n in enumerate(names):
            if not (VW[:, i] > 0).any():
                continue
            bl.append('NodePath("%s")' % paths[n])
            bl.append('PackedFloat32Array(%s)' % ', '.join(('%.3g' % w) if w else '0' for w in VW[:, i]))
        out.append('bones = [%s]' % ', '.join(bl))
        out.append('internal_vertex_count = 0\n')
    out.append('[node name="Skeleton" type="Skeleton2D" parent="Figure/Art"]\n')
    for b in bones:
        n, p = b['name'], b['parent']
        if p:
            px, py = pos[p]
            parent_path = 'Figure/Art/Skeleton/' + paths[p]
        else:
            px, py = 0, 0
            parent_path = 'Figure/Art/Skeleton'
        x, y = b['pos'][0] - px, b['pos'][1] - py
        out.append('[node name="%s" type="Bone2D" parent="%s"]' % (n, parent_path))
        out.append('position = Vector2(%g, %g)' % (x, y))
        out.append('rest = Transform2D(1, 0, 0, 1, %g, %g)' % (x, y))
        out.append('auto_calculate_length_and_angle = false')
        e = b.get('end')
        out.append('length = %g' % (float(np.hypot(e[0] - b['pos'][0], e[1] - b['pos'][1])) if e else 24.0))
        if e:
            out.append('bone_angle = %g' % float(np.degrees(np.arctan2(e[1] - b['pos'][1], e[0] - b['pos'][0]))))
        out.append('')
    with open(os.path.join(base, 'rig.tscn'), 'w') as f:
        f.write('\n'.join(out))


def find_project_root(p):
    while p != '/':
        if os.path.exists(os.path.join(p, 'project.godot')):
            return p
        p = os.path.dirname(p)
    raise SystemExit('project.godot not found above ' + p)


def debug(d, b, names, pos, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    rng = np.random.default_rng(7)
    cols = rng.uniform(40, 255, (len(names), 3))
    cols[names.index('root')] = (60, 60, 60)
    rgb = np.tensordot(b['Wm'].transpose(1, 2, 0), cols, 1)
    W, H = d['size']
    wim = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).resize((W, H), Image.BILINEAR)
    full = Image.new('RGBA', (W, H))
    full.paste(b['tex'], tuple(int(v) for v in b['origin']))
    a = np.asarray(full)[..., 3:4] / 255.0
    mix = np.asarray(full.convert('RGB')) * 0.45 + np.asarray(wim) * 0.55
    mix = mix * a + 255 * (1 - a) * 0.9
    im = Image.fromarray(mix.astype(np.uint8))
    dr = ImageDraw.Draw(im)
    V = b['V']
    for t in b['tris']:
        p = [tuple(V[k]) for k in t]
        dr.line(p + [p[0]], fill=(0, 120, 255), width=1)
    for n in names:
        x, y = pos[n]
        dr.ellipse((x - 6, y - 6, x + 6, y + 6), outline=(0, 0, 0), width=2)
        dr.text((x + 8, y - 6), n, fill=(0, 0, 0))
    im.resize((W // 2, H // 2), Image.LANCZOS).save(os.path.join(out_dir, 'weights_%s.png' % b['name']))


if __name__ == '__main__':
    dbg = None
    if '--debug' in sys.argv:
        dbg = sys.argv[sys.argv.index('--debug') + 1]
    build(sys.argv[1], dbg)
