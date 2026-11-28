#!/usr/bin/env python3
"""Visual QA of the asset slimming (WP2 tail / P03): textures + ogv.

Textures: compares the ORIGINAL source image (game/<res path>) with what Godot really loads (dump made by qa_dump.gd from the
imported .ctex, i.e. after the lossy WebP q0.82 re-import). Per file: alpha-weighted PSNR, SSIM (7x7 box window on luma over
grey), edge-zone error (pixels with partial alpha + 2 px: cutout halos), banding score (smooth gradient tiles: share of pixels
off by >=2 levels, and loss of distinct levels), max |dAlpha|. Up to 3 detail crops per file (worst structure tile, worst
alpha-edge tile, worst smooth-gradient tile), each saved as  ORIGINAL | LOADED | |diff|x8 .

Video: for every .ogv (Theora) frames at 10/50/90 % are decoded with ffmpeg; if the clip was re-encoded by WP2 the original is
taken from git (--git-base REV, default 0d83a09^) and compared (whole-clip PSNR/SSIM from ffmpeg + 3 frame crops each).

usage (repo root):
  qa_visual.py tex  DUMP_DIR OUT_DIR LIST.txt            # LIST = res://... paths, one per line
  qa_visual.py vid  OUT_DIR [--git-base REV]
  qa_visual.py all-report ...                            # (see docs/qa/SLIM_VISUAL_QA.md for the exact commands used)
Writes OUT_DIR/results.json (+ crops/*.png). Needs numpy, Pillow, ffmpeg (video only).
"""
import json, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TILE = 64
THR_PSNR, THR_SSIM = 38.0, 0.95


def box(a, k):
    """mean filter k x k (valid), via integral image"""
    c = np.cumsum(np.cumsum(np.pad(a, ((1, 0), (1, 0))), 0), 1)
    return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)


def ssim_map(x, y, k=7):
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    mx, my = box(x, k), box(y, k)
    sxx = box(x * x, k) - mx * mx; syy = box(y * y, k) - my * my; sxy = box(x * y, k) - mx * my
    return ((2 * mx * my + c1) * (2 * sxy + c2)) / ((mx * mx + my * my + c1) * (sxx + syy + c2))


def dilate(m, r):
    out = m.copy()
    for _ in range(r):
        p = np.pad(out, 1)
        out = p[1:-1, 1:-1] | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    return out


def luma(rgb):
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def over_grey(A, g=128.0):
    al = A[..., 3:4] / 255.0
    return A[..., :3] * al + g * (1 - al)


def tile_reduce(m, valid, fn=np.mean):
    """per-TILE reduction of a 2d map -> dict {(tx,ty): value} for tiles that have >= 50% valid pixels"""
    h, w = m.shape; out = {}
    for ty in range(0, h - TILE + 1, TILE):
        for tx in range(0, w - TILE + 1, TILE):
            v = valid[ty:ty + TILE, tx:tx + TILE]
            if v.mean() < 0.5: continue
            out[(tx, ty)] = fn(m[ty:ty + TILE, tx:tx + TILE][v])
    return out


def save_crop(path, A, B, tx, ty, pad=32, scale=3):
    """ORIGINAL | LOADED | |diff|x8 composited over grey, around tile (tx,ty)"""
    h, w = A.shape[:2]
    x0 = max(0, min(w - TILE - 2 * pad, tx - pad)) if w >= TILE + 2 * pad else 0
    y0 = max(0, min(h - TILE - 2 * pad, ty - pad)) if h >= TILE + 2 * pad else 0
    x1, y1 = min(w, x0 + TILE + 2 * pad), min(h, y0 + TILE + 2 * pad)
    ca, cb = over_grey(A[y0:y1, x0:x1]), over_grey(B[y0:y1, x0:x1])
    d = np.clip(np.abs(ca - cb) * 8, 0, 255)
    sheet = np.concatenate([ca, np.full((ca.shape[0], 6, 3), 255.0), cb, np.full((ca.shape[0], 6, 3), 255.0), d], 1)
    im = Image.fromarray(sheet.astype(np.uint8)).resize((sheet.shape[1] * scale, sheet.shape[0] * scale), Image.NEAREST)
    im.save(path)


def analyse(A, B, tag, cropdir):
    """A, B float RGBA arrays of equal size"""
    al = A[..., 3] / 255.0
    w = np.maximum(al, 1e-3)[..., None]
    mse = (((A[..., :3] - B[..., :3]) ** 2) * w).sum() / (w.sum() * 3)
    psnr = 10 * np.log10(255 ** 2 / max(mse, 1e-9))
    ga, gb = luma(over_grey(A)), luma(over_grey(B))
    sm = ssim_map(ga, gb)
    vis = al[3:-3, 3:-3] > 0.02
    ssim = float(sm[vis].mean()) if vis.any() else 1.0
    r = {"psnr": round(float(psnr), 2), "ssim": round(ssim, 4), "dalpha": int(np.abs(A[..., 3] - B[..., 3]).max()),
         "w": A.shape[1], "h": A.shape[0], "crops": []}
    # --- alpha-edge zone (cutout halos)
    partial = (A[..., 3] > 8) & (A[..., 3] < 247)
    r["edge_px"] = int(partial.sum())
    edge_err = None
    if partial.sum() > 200:
        zone = dilate(partial, 2) & (A[..., 3] > 0)
        # composite over black AND white: a coloured halo shows on one of them
        e = []
        for g in (0.0, 255.0):
            e.append(((over_grey(A, g) - over_grey(B, g)) ** 2).mean(-1))
        em = np.maximum(e[0], e[1])
        emse = em[zone].mean()
        r["edge_psnr"] = round(float(10 * np.log10(255 ** 2 / max(emse, 1e-9))), 2)
        edge_err = (em, zone)
    # --- smooth gradient tiles (banding)
    gy = np.abs(np.diff(ga, axis=0))[:, :-1]; gx = np.abs(np.diff(ga, axis=1))[:-1, :]
    gm = np.zeros_like(ga); gm[:-1, :-1] = gy + gx
    opaque = al > 0.98
    gtiles = tile_reduce(gm, opaque, np.mean)
    smooth = [k for k, v in gtiles.items() if 0.15 < v < 3.0]
    band = None
    if smooth:
        worst = (-1, None)
        for (tx, ty) in smooth:
            a = ga[ty:ty + TILE, tx:tx + TILE]; b = gb[ty:ty + TILE, tx:tx + TILE]
            off = float((np.abs(a - b) >= 2.0).mean())
            if off > worst[0]: worst = (off, (tx, ty))
        r["smooth_tiles"] = len(smooth); r["band_off2"] = round(worst[0], 3)
        # distinct-level loss in the worst few tiles
        lv = []
        for (tx, ty) in smooth[:400]:
            ua = len(np.unique(np.round(ga[ty:ty + TILE, tx:tx + TILE]))); ub = len(np.unique(np.round(gb[ty:ty + TILE, tx:tx + TILE])))
            if ua >= 8: lv.append(ub / ua)
        r["band_levels_ratio_min"] = round(float(min(lv)), 2) if lv else None
        band = worst[1]
    # --- blockiness: WebP/Theora macroblock edges (16 px) in smooth areas, loaded vs source (1.0 = same, >1.15 = visible grid)
    msk = opaque[:-1, :-1] & (gm[:-1, :-1] < 3.0)
    def blk(g):
        out = []
        for ax in (0, 1):
            d = np.abs(g[1:, :-1] - g[:-1, :-1]) if ax == 0 else np.abs(g[:-1, 1:] - g[:-1, :-1])
            idx = (np.arange(d.shape[ax]) + 1) % 16 == 0
            e = d[idx, :] if ax == 0 else d[:, idx]; o = d[~idx, :] if ax == 0 else d[:, ~idx]
            me = msk[idx, :] if ax == 0 else msk[:, idx]; mo = msk[~idx, :] if ax == 0 else msk[:, ~idx]
            if me.sum() < 200: continue
            out.append((e[me].mean() + 1e-3) / (o[mo].mean() + 1e-3))
        return max(out) if out else 1.0
    if msk.sum() > 5000:
        r["block_ratio"] = round(float(blk(gb) / blk(ga)), 3)
    # --- worst structure tile (lowest tile SSIM)
    full = np.ones_like(ga); full[3:-3, 3:-3] = sm
    st = tile_reduce(full, opaque | (al > 0.3), np.mean)
    wt = min(st.items(), key=lambda kv: kv[1])[0] if st else None
    r["min_tile_ssim"] = round(float(min(st.values())), 3) if st else None
    # --- write crops
    os.makedirs(cropdir, exist_ok=True)
    def put(kind, tl):
        if tl is None: return
        fn = "%s__%s.png" % (tag, kind)
        save_crop(os.path.join(cropdir, fn), A, B, tl[0], tl[1]); r["crops"].append(fn)
    put("detail", wt)
    if edge_err is not None:
        em, zone = edge_err
        # tile with the largest summed edge-zone error (needs >= 40 zone pixels so a stray pixel does not win)
        hh, ww = em.shape; best = (0.0, None); zm = em * zone
        for ty in range(0, hh - TILE + 1, TILE):
            for tx in range(0, ww - TILE + 1, TILE):
                if zone[ty:ty + TILE, tx:tx + TILE].sum() < 40: continue
                sc = zm[ty:ty + TILE, tx:tx + TILE].sum()
                if sc > best[0]: best = (sc, (tx, ty))
        put("edge", best[1])
    put("gradient", band)
    return r


def load_rgba(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.float64)


def cmd_tex(dump, out, lst):
    paths = [l.strip() for l in open(lst) if l.strip()]
    res = {}
    rp = os.path.join(out, "results_tex.json")
    if os.path.exists(rp): res = json.load(open(rp))
    for i, r in enumerate(paths):
        if r in res: continue
        rel = r[len("res://"):]
        d = os.path.join(dump, rel.replace("/", "__") + ".png")
        s = os.path.join(REPO, "game", rel)
        if not os.path.exists(d): res[r] = {"error": "no dump"}; continue
        A, B = load_rgba(s), load_rgba(d)
        if A.shape != B.shape: res[r] = {"error": "size mismatch %s vs %s" % (A.shape, B.shape)}; continue
        tag = rel.replace("/", "__").rsplit(".", 1)[0]
        res[r] = analyse(A, B, tag, os.path.join(out, "crops"))
        print(i + 1, len(paths), r, res[r]["psnr"], res[r]["ssim"], flush=True)
        if i % 20 == 0: json.dump(res, open(rp, "w"))
    json.dump(res, open(rp, "w"), indent=0)


def ff(*a, **k):
    return subprocess.run(["ffmpeg", "-v", "error", "-y", *a], capture_output=True, text=True, **k)


def duration(p):
    o = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", p], capture_output=True, text=True).stdout
    return float(o.strip())


def cmd_vid(out, base):
    ogvs = sorted(subprocess.run(["git", "-C", REPO, "ls-files", ":(glob)game/**/*.ogv"], capture_output=True, text=True).stdout.split())
    res = {}; tmp = tempfile.mkdtemp(prefix="qa_ogv_")
    for p in ogvs:
        full = os.path.join(REPO, p)
        old = os.path.join(tmp, os.path.basename(p) + ".orig.ogv")
        blob = subprocess.run(["git", "-C", REPO, "show", "%s:%s" % (base, p)], capture_output=True).stdout
        open(old, "wb").write(blob)
        same = open(full, "rb").read() == blob
        dur = duration(full)
        r = {"bytes_new": os.path.getsize(full), "bytes_old": len(blob), "reencoded": not same, "dur": round(dur, 2), "crops": []}
        if not same:
            sf = os.path.join(tmp, "ssim_stats.txt")
            # whole-clip metrics (scale new to old size if needed)
            o = subprocess.run(["ffmpeg", "-v", "info", "-i", full, "-i", old, "-lavfi",
                                "[0:v][1:v]scale2ref=flags=bicubic[a][b];[a]split[a1][a2];[b]split[b1][b2];[a1][b1]ssim=stats_file=" + sf + ";[a2][b2]psnr",
                                "-f", "null", "-"], capture_output=True, text=True).stderr
            for line in o.splitlines():
                if "SSIM" in line and "All:" in line: r["ssim"] = float(line.split("All:")[1].split()[0])
                if "PSNR" in line and "average:" in line: r["psnr"] = float(line.split("average:")[1].split()[0])
            fr = sorted(float(l.split("All:")[1].split()[0]) for l in open(sf) if "All:" in l)
            r["ssim_worst_frame"] = fr[0]; r["ssim_p5"] = fr[len(fr) // 20]
        tag = p.replace("game/", "").replace("/", "__").rsplit(".", 1)[0]
        for pct in (10, 50, 90):
            t = dur * pct / 100
            fn = os.path.join(tmp, "%s_%d_new.png" % (tag, pct)); fo = os.path.join(tmp, "%s_%d_old.png" % (tag, pct))
            ff("-ss", "%.3f" % t, "-i", full, "-frames:v", "1", fn); ff("-ss", "%.3f" % t, "-i", old, "-frames:v", "1", fo)
            if not (os.path.exists(fn) and os.path.exists(fo)): continue
            A, B = load_rgba(fo), load_rgba(fn)
            if A.shape != B.shape:
                B = np.asarray(Image.fromarray(B.astype(np.uint8)).resize((A.shape[1], A.shape[0]), Image.BICUBIC)).astype(np.float64)
            fr = analyse(A, B, "%s__f%d" % (tag, pct), os.path.join(out, "crops"))
            r["crops"] += fr.pop("crops"); r.setdefault("frames", {})[pct] = fr
        res[p] = r
        print(p, {k: v for k, v in r.items() if k not in ("frames", "crops")}, flush=True)
    json.dump(res, open(os.path.join(out, "results_vid.json"), "w"), indent=0)


if __name__ == "__main__":
    if len(sys.argv) >= 5 and sys.argv[1] == "tex": cmd_tex(sys.argv[2], sys.argv[3], sys.argv[4])
    elif len(sys.argv) >= 3 and sys.argv[1] == "vid":
        base = sys.argv[sys.argv.index("--git-base") + 1] if "--git-base" in sys.argv else "0d83a09^"
        cmd_vid(sys.argv[2], base)
    else: print(__doc__); sys.exit(2)
