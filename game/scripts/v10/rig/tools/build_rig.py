#!/usr/bin/env python3
"""Build a V10LiveRig scene (Skeleton2D + one skinned Polygon2D) from a rig_def.json.

    python3 build_rig.py game/assets/v10/rig/mc_gown/rig_def.json [--debug out_dir]

Reads the cutout (rig_def "texture", RGBA), makes a regular vertex grid over every cell that holds
opaque pixels, paints bone weights region by region (feathered polygons, y ramps and chains),
smooths them, keeps the 4 strongest per vertex (continuously, so no seams) and writes
<asset dir>/rig.tscn next to rig_def.json. --debug writes a weight overlay and a mesh overlay PNG.
Needs numpy, scipy, pillow.
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


def build(def_path, debug_dir=None):
    d = json.load(open(def_path))
    base = os.path.dirname(os.path.abspath(def_path))
    tex = Image.open(os.path.join(base, d['texture'])).convert('RGBA')
    W, H = tex.size
    alpha = np.asarray(tex)[..., 3]
    bones = d['bones']
    names = [b['name'] for b in bones]
    bidx = {n: i for i, n in enumerate(names)}
    pos = {b['name']: b['pos'] for b in bones}
    end = {b['name']: b.get('end') for b in bones}
    children = {n: [b['name'] for b in bones if b['parent'] == n] for n in names}
    shape = (H // Q, W // Q)
    yy = (np.mgrid[0:shape[0], 0:shape[1]][0].astype(np.float32) + 0.5) * Q
    Wm = np.zeros((len(bones),) + shape, np.float32)
    Wm[bidx['root']] = 1.0

    def over(m, dist):
        """Paint membership m with bone distribution dist {bone: map} over the current weights."""
        Wm[:] *= (1.0 - m)[None]
        for n, dm in dist.items():
            Wm[bidx[n]] += m * dm

    for r in d['regions']:
        t = r['type']
        if t == 'ramp_y':
            m = smoothstep(r['from'], r['to'], yy)
            over(m, {r['bone']: 1.0})
        elif t == 'poly':
            m = feathered(r['poly'], r['feather'], shape, r.get('side', 'both')) * r.get('strength', 1.0)
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

    # --- mesh: regular grid over opaque cells
    g = d.get('grid', 14)
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
    V = np.array(verts, np.float32)
    # sample weights at vertices (bilinear on the 1/Q maps)
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
    VW[VW.sum(1) == 0, bidx['root']] = 1.0

    write_tscn(d, base, names, pos, bones, V, tris, VW)
    stats = {'vertices': len(V), 'triangles': len(tris), 'bones': len(bones),
             'max_influences': int((VW > 0).sum(1).max())}
    print(json.dumps(stats))
    if debug_dir:
        debug(d, base, tex, Wm, V, tris, names, pos, debug_dir)
    return stats


def fmt(a):
    return ', '.join(('%.4g' % x) for x in a)


def write_tscn(d, base, names, pos, bones, V, tris, VW):
    rel = os.path.relpath(base, find_project_root(base)).replace(os.sep, '/')
    res = 'res://' + rel
    out = []
    out.append('[gd_scene load_steps=3 format=3]\n')
    out.append('[ext_resource type="Script" path="res://scripts/v10/rig/live_rig.gd" id="1_rig"]')
    out.append('[ext_resource type="Texture2D" path="%s/%s" id="2_tex"]\n' % (res, d['texture']))
    out.append('[node name="%s" type="Node2D"]' % ''.join(p.capitalize() for p in d['name'].split('_')))
    out.append('script = ExtResource("1_rig")')
    out.append('def_path = "%s/rig_def.json"\n' % res)
    rx, ry = pos['root']
    out.append('[node name="Figure" type="Node2D" parent="."]')
    out.append('position = Vector2(%g, %g)\n' % (rx, ry))
    out.append('[node name="Art" type="Node2D" parent="Figure"]')
    out.append('position = Vector2(%g, %g)\n' % (-rx, -ry))
    out.append('[node name="Body" type="Polygon2D" parent="Figure/Art"]')
    body_at = len(out)
    out.append('[node name="Skeleton" type="Skeleton2D" parent="Figure/Art"]\n')
    paths = {}
    for b in bones:
        n, p = b['name'], b['parent']
        if p:
            px, py = pos[p]
            parent_path = 'Figure/Art/Skeleton/' + paths[p]
            paths[n] = paths[p] + '/' + n
        else:
            px, py = 0, 0
            parent_path = 'Figure/Art/Skeleton'
            paths[n] = n
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
    body = ['texture_filter = 4']
    body.append('texture = ExtResource("2_tex")')
    body.append('skeleton = NodePath("../Skeleton")')
    body.append('polygon = PackedVector2Array(%s)' % fmt(V.reshape(-1)))
    body.append('uv = PackedVector2Array(%s)' % fmt(V.reshape(-1)))
    body.append('polygons = [%s]' % ', '.join('PackedInt32Array(%d, %d, %d)' % t for t in tris))
    bl = []
    for i, n in enumerate(names):
        bl.append('NodePath("%s")' % paths[n])
        bl.append('PackedFloat32Array(%s)' % ', '.join(('%.3g' % w) if w else '0' for w in VW[:, i]))
    body.append('bones = [%s]' % ', '.join(bl))
    body.append('internal_vertex_count = 0')
    body.append('')
    out[body_at:body_at] = body
    with open(os.path.join(base, 'rig.tscn'), 'w') as f:
        f.write('\n'.join(out))


def find_project_root(p):
    while p != '/':
        if os.path.exists(os.path.join(p, 'project.godot')):
            return p
        p = os.path.dirname(p)
    raise SystemExit('project.godot not found above ' + p)


def debug(d, base, tex, Wm, V, tris, names, pos, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    rng = np.random.default_rng(7)
    cols = rng.uniform(40, 255, (len(names), 3))
    cols[names.index('root')] = (60, 60, 60)
    rgb = np.tensordot(Wm.transpose(1, 2, 0), cols, 1)
    W, H = tex.size
    wim = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).resize((W, H), Image.BILINEAR)
    art = tex.convert('RGB')
    a = np.asarray(tex)[..., 3:4] / 255.0
    mix = np.asarray(art) * 0.45 + np.asarray(wim) * 0.55
    mix = mix * a + 255 * (1 - a) * 0.9
    im = Image.fromarray(mix.astype(np.uint8))
    dr = ImageDraw.Draw(im)
    for n in names:
        x, y = pos[n]
        dr.ellipse((x - 6, y - 6, x + 6, y + 6), outline=(0, 0, 0), width=2)
        dr.text((x + 8, y - 6), n, fill=(0, 0, 0))
    im.resize((W // 2, H // 2), Image.LANCZOS).save(os.path.join(out_dir, 'weights.png'))
    m = tex.copy()
    bg = Image.new('RGBA', m.size, (255, 255, 255, 255)); bg.alpha_composite(m)
    dr = ImageDraw.Draw(bg)
    for t in tris[::1]:
        p = [tuple(V[k]) for k in t]
        dr.line(p + [p[0]], fill=(0, 120, 255, 255), width=1)
    bg.convert('RGB').resize((W // 2, H // 2), Image.LANCZOS).save(os.path.join(out_dir, 'mesh.png'))


if __name__ == '__main__':
    dbg = None
    if '--debug' in sys.argv:
        dbg = sys.argv[sys.argv.index('--debug') + 1]
    build(sys.argv[1], dbg)
