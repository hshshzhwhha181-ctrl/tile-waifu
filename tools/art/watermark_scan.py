#!/usr/bin/env python3
"""P58: heuristic watermark / stray-text detector for image EDGES (corners and border strips).

Generated art tends to carry small marks in a corner or along the bottom edge (sparkle logos, "AI generated" text, site
names).  This is a REVIEW AID, not a proof: it flags candidates, the human audit decides.  No model, only Pillow + numpy.

Method (on a <=1024 px luma copy):
  detail = |luma - gaussian_blur(luma)|, strokes = detail > T (silhouette edges of cut-outs excluded)
  strokes are merged into blobs (dilation); a blob is a MARK candidate when it lies in the outer ~20% band of the image,
  has a plausible size, is ISOLATED (the ring around it has almost no strokes, i.e. smooth ground) and is either
    text : >= 5 letter-like components of similar height on one horizontal line, or
    logo : a compact blob with the aspect of a badge/sparkle sitting in a corner.
  Busy borders (texture, foliage) are not judged: a mark hidden in texture is a known miss.
Alpha is honoured: fully transparent pixels are ignored (zone is judged on the opaque part).

usage: watermark_scan.py [--json] [--debug-dir DIR] [--strict] FILE...    exit 1 when any file is flagged
"""
import argparse, json, os, sys
import numpy as np
from PIL import Image, ImageFilter

MAXSIDE = 1024


def _load(path):
    im = Image.open(path)
    im.load()
    rgba = im.convert("RGBA")
    w, h = rgba.size
    s = min(1.0, MAXSIDE / max(w, h))
    if s < 1.0:
        rgba = rgba.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    a = np.asarray(rgba).astype("float32")
    alpha = a[..., 3] / 255.0
    luma = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    return luma, alpha


def _detail(luma, sigma=5):
    g = Image.fromarray(np.clip(luma, 0, 255).astype("uint8"), "L")
    blur = np.asarray(g.filter(ImageFilter.GaussianBlur(sigma))).astype("float32")
    return np.abs(luma - blur)


def _close(mask, k=3):
    im = Image.fromarray((mask * 255).astype("uint8"), "L").filter(ImageFilter.MaxFilter(k)).filter(ImageFilter.MinFilter(k))
    return np.asarray(im) > 127


def _components(mask):
    """4-connected components of a small boolean mask -> list of (x0, y0, x1, y1, area)."""
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    ys, xs = np.nonzero(mask)
    out = []
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if seen[y0, x0]:
            continue
        stack = [(y0, x0)]
        seen[y0, x0] = True
        mnx = mxx = x0
        mny = mxy = y0
        area = 0
        while stack:
            y, x = stack.pop()
            area += 1
            if x < mnx: mnx = x
            if x > mxx: mxx = x
            if y < mny: mny = y
            if y > mxy: mxy = y
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
        out.append((mnx, mny, mxx, mxy, area))
        if len(out) > 4000:       # absurdly busy zone = texture, not a mark
            break
    return out


def _text_line(mask, minn=5):
    """Best horizontal line of letter-like components: returns (count, span_px)."""
    comps = [c for c in _components(mask)
             if 3 <= c[2] - c[0] + 1 <= 70 and 4 <= c[3] - c[1] + 1 <= 70 and c[4] >= 6]
    if len(comps) < minn:
        return 0, 0
    best = (0, 0)
    cy = np.array([(c[1] + c[3]) / 2 for c in comps])
    ch = np.array([c[3] - c[1] + 1 for c in comps], dtype="float32")
    for i in range(len(comps)):
        tol = max(3.0, 0.45 * ch[i])
        sel = [j for j in range(len(comps)) if abs(cy[j] - cy[i]) <= tol and 0.5 * ch[i] <= ch[j] <= 2.0 * ch[i]]
        if len(sel) > best[0]:
            xs0 = min(comps[j][0] for j in sel)
            xs1 = max(comps[j][2] for j in sel)
            # letters sit close together: reject lines whose members are spread over most of the image
            if xs1 - xs0 <= 18 * float(np.median(ch[sel])) + 40:
                best = (len(sel), xs1 - xs0)
    return best


def _dilate(mask, size):
    im = Image.fromarray((mask * 255).astype("uint8"), "L").filter(ImageFilter.MaxFilter(size | 1))
    return np.asarray(im) > 127


def _label(mask, step=2):
    """Connected components of a boolean mask at 1/step resolution -> [(x0,y0,x1,y1)] in full-res pixels."""
    h, w = mask.shape
    sm = mask[:h - h % step, :w - w % step].reshape(h // step, step, w // step, step).any(axis=(1, 3))
    lab = np.zeros(sm.shape, dtype="int32")
    boxes = []
    n = 0
    ys, xs = np.nonzero(sm)
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if lab[y0, x0]:
            continue
        n += 1
        stack = [(y0, x0)]
        lab[y0, x0] = n
        mnx = mxx = x0
        mny = mxy = y0
        while stack:
            y, x = stack.pop()
            mnx = min(mnx, x); mxx = max(mxx, x); mny = min(mny, y); mxy = max(mxy, y)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < sm.shape[0] and 0 <= nx < sm.shape[1] and sm[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = n
                    stack.append((ny, nx))
        boxes.append((mnx * step, mny * step, (mxx + 1) * step, (mxy + 1) * step))
        if n > 3000:
            break
    return boxes


def scan_image(path, thr=14.0):
    """Looks for ISOLATED marks near the border: a compact stroke cluster (letters or a logo) sitting on an otherwise smooth
    ground.  Busy art borders are not judged (a mark hidden in texture is a known miss of this heuristic)."""
    luma, alpha = _load(path)
    h, w = luma.shape
    det = _detail(luma)
    # silhouette edges of cut-outs are structure, not marks
    a_img = Image.fromarray(np.clip(alpha * 255, 0, 255).astype("uint8"), "L")
    a_edge = np.abs(alpha - np.asarray(a_img.filter(ImageFilter.GaussianBlur(3))) / 255.0) > 0.04
    a_edge = _dilate(a_edge, 7) if a_edge.any() else a_edge
    opaque = alpha > 0.5
    strokes = (det > thr) & opaque & ~a_edge
    zones = []
    if opaque.mean() < 0.2 or strokes.mean() > 0.30:
        return {"file": path, "size": [w, h], "flagged": False, "zones": [], "note": "mostly transparent or texture"}
    r = max(5, int(0.007 * max(w, h)))
    boxes = _label(_dilate(strokes, 2 * r + 1))
    ring_r = max(10, int(0.016 * max(w, h)))
    for (x0, y0, x1, y1) in boxes:
        x0, y0, x1, y1 = max(0, x0), max(0, y0), min(w, x1), min(h, y1)
        bw, bh = x1 - x0, y1 - y0
        if bw < 0.02 * w or bw > 0.55 * w or bh < 0.010 * h or bh > 0.16 * h:
            continue
        near_edge = x1 < 0.22 * w or x0 > 0.78 * w or y1 < 0.20 * h or y0 > 0.80 * h
        if not near_edge:
            continue
        sub = strokes[y0:y1, x0:x1]
        fill = float(sub.mean())
        if not 0.03 <= fill <= 0.55:
            continue
        sy, sx = np.nonzero(sub)
        if len(sx) == 0:
            continue
        # an overlay is inset from the frame; art cropped by the frame touches the border
        m = int(0.006 * max(w, h)) + 1
        if x0 + sx.min() < m or y0 + sy.min() < m or x0 + sx.max() > w - m or y0 + sy.max() > h - m:
            continue
        sharp = float(np.percentile(det[y0:y1, x0:x1][sub], 90))
        ex0, ey0, ex1, ey1 = max(0, x0 - ring_r), max(0, y0 - ring_r), min(w, x1 + ring_r), min(h, y1 + ring_r)
        win = strokes[ey0:ey1, ex0:ex1].copy()
        win[y0 - ey0:y1 - ey0, x0 - ex0:x1 - ex0] = False
        ring_dens = float(win.sum()) / max(1, win.size - bw * bh)
        if ring_dens > 0.012:
            continue
        # letters: re-measure with a tight blur; the threshold is relative to the blob's own contrast and swept,
        # because bold letters touch at low thresholds and hollow out at high ones
        fd = _detail(luma[y0:y1, x0:x1], 1.0)
        p97 = float(np.percentile(fd, 97))
        n, span = 0, 0
        for fr in (0.25, 0.4, 0.55):
            n2, sp2 = _text_line((fd > max(6.0, fr * p97)) & opaque[y0:y1, x0:x1])
            if n2 > n:
                n, span = n2, sp2
        kind = None
        if n >= 5:
            kind, detail = "text", "%d letter-like marks on one line, span %dpx" % (n, span)
        elif 0.4 <= bw / bh <= 2.6 and 0.035 * w <= bw <= 0.2 * w and fill >= 0.06 and sharp >= 30 and (x1 < 0.2 * w or x0 > 0.8 * w) and (y1 < 0.2 * h or y0 > 0.8 * h):
            kind, detail = "logo", "compact isolated mark %dx%d in a corner, fill %.0f%%" % (bw, bh, fill * 100)
        if kind:
            zones.append({"zone": "%s_%s" % ("top" if y1 < 0.5 * h else "bottom", "left" if x1 < 0.5 * w else ("right" if x0 > 0.5 * w else "centre")),
                          "kind": kind, "score": round(fill, 3), "box": [x0, y0, x1, y1], "detail": detail})
    return {"file": path, "size": [w, h], "flagged": bool(zones), "zones": zones}


def debug_overlay(path, res, outdir):
    from PIL import ImageDraw
    im = Image.open(path).convert("RGB")
    w, h = im.size
    s = min(1.0, MAXSIDE / max(w, h))
    if s < 1.0:
        im = im.resize((round(w * s), round(h * s)), Image.LANCZOS)
    d = ImageDraw.Draw(im)
    for z in res["zones"]:
        d.rectangle(z["box"], outline=(255, 0, 0), width=3)
    os.makedirs(outdir, exist_ok=True)
    im.save(os.path.join(outdir, os.path.splitext(os.path.basename(path))[0] + "_wm.png"))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--debug-dir")
    ap.add_argument("--thr", type=float, default=14.0)
    a = ap.parse_args(argv)
    flagged = 0
    out = []
    for f in a.files:
        r = scan_image(f, a.thr)
        out.append(r)
        flagged += r["flagged"]
        if a.debug_dir and r["flagged"]:
            debug_overlay(f, r, a.debug_dir)
        if not a.json:
            print("%s %s%s" % ("FLAG" if r["flagged"] else "ok  ", f,
                               "".join("\n    %s/%s: %s" % (z["zone"], z["kind"], z["detail"]) for z in r["zones"])))
    if a.json:
        print(json.dumps(out, indent=1))
    sys.exit(1 if flagged else 0)


if __name__ == "__main__":
    main()
