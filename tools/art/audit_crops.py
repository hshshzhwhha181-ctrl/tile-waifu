#!/usr/bin/env python3
"""P58: cut audit crops (hands, fingers, feet, legs, face) from a character image and build one contact sheet.

The double anatomy audit needs a human to LOOK at hands, fingers, feet and legs at full resolution.  This tool prepares
that view in well under a second per image: no pose model is needed, windows come from anatomical priors applied to
the subject's bounding box (alpha, or distance from the border colour for opaque images).  Poses where the priors miss
(sitting, arms raised, lying) can pass exact landmarks: --landmarks FILE.json with pixel coordinates

    {"hand_l": [x, y], "hand_r": [x, y], "foot_l": [x, y], "foot_r": [x, y], "face": [x, y], "knee_l": [x, y]}

(any subset; a landmark replaces the prior window for that part).  A landmark's crop is a square of 0.16 x subject height.

outputs (OUT/<stem>/): crop_<part>.png (upscaled so the long side is >= 512 px), contact_sheet.jpg, crops.json
usage: audit_crops.py IMAGE [-o OUT] [--landmarks FILE] [--cell 384] [--cols 4]
"""
import argparse, json, os, sys, time
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps

# part -> (x0, y0, x1, y1) as fractions of the subject bbox; standing figure (height/width >= 1.35) / bust-up
PRIORS_FULL = {
    "face":      (0.25, 0.00, 0.75, 0.17),
    "hand_l":    (0.00, 0.36, 0.34, 0.58),
    "hand_r":    (0.66, 0.36, 1.00, 0.58),
    "fingers_l": (0.02, 0.42, 0.24, 0.55),
    "fingers_r": (0.76, 0.42, 0.98, 0.55),
    "legs":      (0.22, 0.58, 0.78, 0.88),
    "foot_l":    (0.12, 0.86, 0.52, 1.00),
    "foot_r":    (0.48, 0.86, 0.88, 1.00),
}
PRIORS_BUST = {
    "face":      (0.25, 0.00, 0.75, 0.40),
    "hand_l":    (0.00, 0.50, 0.38, 0.92),
    "hand_r":    (0.62, 0.50, 1.00, 0.92),
    "fingers_l": (0.02, 0.62, 0.28, 0.88),
    "fingers_r": (0.72, 0.62, 0.98, 0.88),
    "legs":      (0.15, 0.70, 0.85, 1.00),
    "foot_l":    (0.00, 0.80, 0.50, 1.00),
    "foot_r":    (0.50, 0.80, 1.00, 1.00),
}
LM_NAMES = {"hand_l": "hand_l", "hand_r": "hand_r", "foot_l": "foot_l", "foot_r": "foot_r", "face": "face",
            "knee_l": "legs", "knee_r": "legs", "fingers_l": "fingers_l", "fingers_r": "fingers_r"}


def subject_bbox(im):
    """(x0, y0, x1, y1) of the figure: alpha when the image has real transparency, else difference from the border colour."""
    rgba = im.convert("RGBA")
    a = np.asarray(rgba)[..., 3]
    w, h = rgba.size
    if (a < 250).mean() > 0.02:
        m = a > 16
    else:
        small = rgba.convert("RGB").resize((max(8, w // 8), max(8, h // 8)), Image.BILINEAR).filter(ImageFilter.GaussianBlur(1))
        arr = np.asarray(small).astype("float32")
        border = np.concatenate([arr[0], arr[-1], arr[:, 0], arr[:, -1]])
        bg = np.median(border, axis=0)
        d = np.abs(arr - bg).sum(axis=2)
        m = d > 60
        if m.mean() < 0.05 or m.mean() > 0.97:           # flat or full-bleed picture: whole frame is the subject
            return (0, 0, w, h)
        m = np.asarray(Image.fromarray((m * 255).astype("uint8")).resize((w, h), Image.NEAREST)) > 127
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return (0, 0, w, h)
    # robust to specks: 0.2 / 99.8 percentiles
    x0, x1 = np.percentile(xs, [0.2, 99.8])
    y0, y1 = np.percentile(ys, [0.2, 99.8])
    return (int(x0), int(y0), int(x1) + 1, int(y1) + 1)


def windows(size, bbox, landmarks=None):
    w, h = size
    bx0, by0, bx1, by1 = bbox
    bw, bh = bx1 - bx0, by1 - by0
    pri = PRIORS_FULL if bh / max(1, bw) >= 1.35 else PRIORS_BUST
    out = {}
    for part, (fx0, fy0, fx1, fy1) in pri.items():
        out[part] = [bx0 + fx0 * bw, by0 + fy0 * bh, bx0 + fx1 * bw, by0 + fy1 * bh]
    for name, xy in (landmarks or {}).items():
        part = LM_NAMES.get(name)
        if not part:
            continue
        r = 0.08 * bh
        x, y = float(xy[0]), float(xy[1])
        out[part] = [x - r, y - r, x + r, y + r]
    clipped = {}
    for part, (x0, y0, x1, y1) in out.items():
        x0, y0 = max(0, int(round(x0))), max(0, int(round(y0)))
        x1, y1 = min(w, int(round(x1))), min(h, int(round(y1)))
        if x1 - x0 >= 16 and y1 - y0 >= 16:
            clipped[part] = (x0, y0, x1, y1)
    return clipped


def _flatten(im):
    """RGB for viewing: transparent regions on a mid-grey chequer so edges stay judgeable."""
    rgba = im.convert("RGBA")
    bg = Image.new("RGBA", rgba.size, (128, 128, 128, 255))
    return Image.alpha_composite(bg, rgba).convert("RGB")


def make_audit(path, outdir, landmarks=None, cell=384, cols=4, min_long=512):
    t0 = time.time()
    im = Image.open(path)
    im.load()
    rgb = _flatten(im)
    bbox = subject_bbox(im)
    wins = windows(im.size, bbox, landmarks)
    stem = os.path.splitext(os.path.basename(path))[0]
    od = os.path.join(outdir, stem)
    os.makedirs(od, exist_ok=True)
    items = []
    for part, box in wins.items():
        c = rgb.crop(box)
        long_edge = max(c.size)
        if long_edge < min_long:
            s = min_long / long_edge
            c = c.resize((max(1, round(c.width * s)), max(1, round(c.height * s))), Image.LANCZOS)
        fn = os.path.join(od, "crop_%s.png" % part)
        c.save(fn)
        items.append({"part": part, "box": list(box), "file": fn, "size": list(c.size)})
    rows = (len(items) + cols - 1) // cols
    lab_h = 22
    sheet = Image.new("RGB", (cols * cell, rows * (cell + lab_h) + 0), (24, 24, 28))
    d = ImageDraw.Draw(sheet)
    for i, it in enumerate(items):
        c = Image.open(it["file"])
        c = ImageOps.contain(c, (cell, cell), Image.LANCZOS)
        cx, cy = (i % cols) * cell, (i // cols) * (cell + lab_h)
        sheet.paste(c, (cx + (cell - c.width) // 2, cy + lab_h + (cell - c.height) // 2))
        d.rectangle([cx, cy, cx + cell - 1, cy + lab_h + cell - 1], outline=(70, 70, 80))
        d.text((cx + 6, cy + 5), "%s  %s" % (it["part"], "x".join(map(str, [it["box"][2] - it["box"][0], it["box"][3] - it["box"][1]]))), fill=(235, 235, 235))
    sheet_path = os.path.join(od, "contact_sheet.jpg")
    sheet.save(sheet_path, quality=88)
    meta = {"image": path, "size": list(im.size), "subject_bbox": list(bbox), "crops": items,
            "contact_sheet": sheet_path, "seconds": round(time.time() - t0, 2)}
    with open(os.path.join(od, "crops.json"), "w") as f:
        json.dump(meta, f, indent=1)
    return meta


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("image")
    ap.add_argument("-o", "--out", default="audit_out")
    ap.add_argument("--landmarks")
    ap.add_argument("--cell", type=int, default=384)
    ap.add_argument("--cols", type=int, default=4)
    a = ap.parse_args(argv)
    lm = json.load(open(a.landmarks)) if a.landmarks else None
    m = make_audit(a.image, a.out, lm, a.cell, a.cols)
    print("AUDIT %s crops=%d sheet=%s %.2fs" % (a.image, len(m["crops"]), m["contact_sheet"], m["seconds"]))


if __name__ == "__main__":
    main()
