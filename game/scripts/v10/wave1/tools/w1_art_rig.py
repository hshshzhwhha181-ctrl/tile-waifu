#!/usr/bin/env python3
"""Wave-1 goddesses: full-body «Hero» cut-outs + Hero.RIGS measurements (lane 4, art-rig agent).

Produces, for tsubame / miel / kohaku / shirin / zlata:
  game/assets/v10/wave1/hero/<hero>.png      848×1264 RGBA, standing figure, feet at y≈1240 (like assets/hero/<id>.png)
  game/core/wave1/data/w1_art_rig.json {<hero>: {file, source, fit, rig: {head_c: [x, y], …}}}

Pipeline (each stage is reproducible and cached):
  masks   rembg masks of the chosen source art (birefnet-general = crisp silhouette, isnet-anime = soft alpha
          used where the art is motion-blurred, Kohaku's wagging tail tip); cached as PNG in --work
  cut     alpha clean-up (largest island only, frame-edge / scarf-tip fades, 1 px erode), colour
          decontamination of the semi-transparent edge (pymatting estimate_foreground_ml), premultiplied
          Lanczos down-scale, fit into 848×1264 (feet on y 1240, body centred when the silhouette allows)
  json    RIGS rows (measured on the fitted cut-outs with debug overlays, see RIG below) -> data/w1_art_rig.json
  debug   overlays of every rig point + 4× face crops (+ blink / talk preview) into --work/debug
  sheet   contact sheet of the five next to founders mc and yue on #1d1b2e and #f6efe6

Usage:  python3 w1_art_rig.py all  [--src DIR] [--work DIR]
Needs Pillow, numpy, scipy, pymatting, rembg (models download on first use, CPU is fine).
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
OUT_DIR = os.path.join(GAME, "assets", "v10", "wave1", "hero")
JSON_PATH = os.path.join(GAME, "scripts", "v10", "wave1", "data", "w1_art_rig.json")
SCRATCH = "/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad"

W, H = 848, 1264
FEET_Y = 1240.0          # the ground line (founders: feet.y 1240, silhouette bottom 1244)
SOLE_Y = 1244            # lowest opaque row of the figure
MARGIN = 8               # min. transparent margin around the silhouette
TARGET_FACE = 94.0       # face width (1.75 × eye distance) of the founders on their rigged art: mc 95, hana 89,
                         # rin 91, yue 96, nova 96 by the same formula
FACE_PER_EYES = 1.75
ORDER = ["tsubame", "miel", "kohaku", "shirin", "zlata"]

# Source per goddess. Why not always FINAL_<hero>.png (the approved base card):
#  tsubame  FINAL is cut at mid-thigh (no feet) -> «shy» slot: full figure on the roof, LW33 swallow print + ankle
#           cord as in docs/LEGWEAR.md; the red scarf runs off the left frame edge in the source, so its tip fades out.
#  miel     FINAL has closed «^^» eyes (blink impossible) and cream stockings that contradict LW36 «Карамельная
#           лента» -> «select» slot: eyes open, caramel thigh-highs with cream ribbon (LW36); open smile -> no talk flap.
#  kohaku   FINAL leans on a staff resting on the torii (arms would hang on nothing) with one foot up a step ->
#           «shy» slot: both feet on one step, hands together, LW48 bell-bows under the knee. The tail tip is motion-
#           blurred: alpha there = min(birefnet, isnet-anime) remapped 0.45..0.85, so the faint wag ghost goes and
#           the tail keeps a soft, decontaminated edge.
#  shirin   FINAL (arms open, veil). birefnet keeps the sheer teal veil as cloth (isnet turns it into a ghost).
#  zlata    FINAL (firebird mantle). birefnet drops the parquet floor isnet keeps.
HEROES = {
    "tsubame": {"src": "tsubame__tb_base__shy.png", "slot": "tb_base «shy» slot (FINAL is cut at the thighs, no feet)",
                "model": "birefnet-general", "eyes": [(915, 508), (975, 503)], "axis_x": 905,
                # scarf tip: the source frame cuts it at x=0 -> fade it out between x 15 and 110 (rows of the scarf)
                "fade_x": (15, 110, 880, 1400)},
    "miel": {"src": "miel__me_base__select.png", "slot": "me_base «select» slot (FINAL: closed eyes, non-LW36 stockings)",
             "model": "birefnet-general", "eyes": [(316, 225), (395, 180)], "axis_x": 373},
    "kohaku": {"src": "kohaku__ko_base__shy.png", "slot": "ko_base «shy» slot (FINAL: staff on the torii, foot on a step)",
               "model": "birefnet-general", "eyes": [(818, 342), (900, 293)], "axis_x": 838,
               "soft_box": (150, 560, 600, 1300), "soft_model": "isnet-anime", "soft_remap": (0.45, 0.85)},
    "shirin": {"src": "FINAL_shirin.png", "slot": "sh_base approved card FINAL_shirin.png",
               "model": "birefnet-general", "eyes": [(674, 287), (761, 268)], "axis_x": 690},
    "zlata": {"src": "FINAL_zlata.png", "slot": "zl_base approved card FINAL_zlata.png",
              "model": "birefnet-general", "eyes": [(645, 262), (723, 257)], "axis_x": 690},
}


# ----------------------------------------------------------------------------------------------- masks
def mask_path(work, name, model):
    return os.path.join(work, "masks", "%s__%s.png" % (os.path.splitext(name)[0], model))


def stage_masks(src, work, heroes):
    from rembg import new_session, remove
    os.makedirs(os.path.join(work, "masks"), exist_ok=True)
    jobs = []
    for h in heroes:
        c = HEROES[h]
        jobs.append((c["src"], c["model"]))
        if c.get("soft_model"):
            jobs.append((c["src"], c["soft_model"]))
    # one model at a time (birefnet needs several GB of RAM on CPU)
    for model in sorted(set(m for _, m in jobs)):
        todo = [n for n, m in jobs if m == model and not os.path.exists(mask_path(work, n, model))]
        if not todo:
            continue
        sess = new_session(model)
        for n in todo:
            im = Image.open(os.path.join(src, n)).convert("RGB")
            remove(im, session=sess, only_mask=True, post_process_mask=False).save(mask_path(work, n, model))
            print("mask", n, model, flush=True)
        del sess


# ----------------------------------------------------------------------------------------------- cut
def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def clean_alpha(h, src, work):
    from scipy import ndimage
    c = HEROES[h]
    img = Image.open(os.path.join(src, c["src"])).convert("RGB")
    a = np.asarray(Image.open(mask_path(work, c["src"], c["model"])).convert("L"), np.float64) / 255.0
    if c.get("soft_box"):
        x0, y0, x1, y1 = c["soft_box"]
        s = np.asarray(Image.open(mask_path(work, c["src"], c["soft_model"])).convert("L"), np.float64) / 255.0
        box = np.minimum(a[y0:y1, x0:x1], s[y0:y1, x0:x1])
        if c.get("soft_remap"):
            # drop the faint wag ghost (smoky on dark UI), keep the solid tail with a soft edge
            box = smoothstep(c["soft_remap"][0], c["soft_remap"][1], box)
        a[y0:y1, x0:x1] = box
    # keep the figure only: the largest 8-connected island (scenery bits, floating music notes, roof eaves go)
    lab, n = ndimage.label(a > 0.12, structure=np.ones((3, 3)))
    if n > 1:
        sizes = ndimage.sum(np.ones_like(a), lab, range(1, n + 1))
        keep = lab == (1 + int(np.argmax(sizes)))
        a *= ndimage.binary_dilation(keep, iterations=3)
    hh, ww = a.shape
    yy, xx = np.mgrid[0:hh, 0:ww]
    if c.get("fade_x"):
        fx0, fx1, fy0, fy1 = c["fade_x"]
        band = (yy >= fy0) & (yy < fy1)
        a = np.where(band, a * smoothstep(fx0, fx1, xx), a)
    # anything the source frame cuts (a fingertip, a feather tip) fades over 6 px instead of ending in a straight edge
    edge = np.minimum(np.minimum(xx, ww - 1 - xx), np.minimum(yy, hh - 1 - yy))
    a *= smoothstep(0.0, 6.0, edge)
    # 1 px erode: the outermost ring of the matte carries the scene colour
    a = ndimage.grey_erosion(a, size=(3, 3))
    a[a < 0.02] = 0.0
    return np.asarray(img, np.float64) / 255.0, a


def fit_params(h, a):
    c = HEROES[h]
    ys, xs = np.nonzero(a > 0.02)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    (ex1, ey1), (ex2, ey2) = c["eyes"]
    face = FACE_PER_EYES * float(np.hypot(ex2 - ex1, ey2 - ey1))
    s_face = TARGET_FACE / face
    s_h = (SOLE_Y - MARGIN) / float(y1 - y0)
    s_w = (W - 2 * MARGIN) / float(x1 - x0)
    s = min(s_face, s_h, s_w)
    # sole row -> SOLE_Y; body axis -> canvas centre unless the silhouette would leave the canvas
    oy = SOLE_Y - y1 * s
    ox = W * 0.5 - c["axis_x"] * s
    ox = min(max(ox, MARGIN - x0 * s), W - MARGIN - x1 * s)
    return {"scale": round(s, 5), "ox": round(ox, 2), "oy": round(oy, 2), "bbox_src": [int(x0), int(y0), int(x1), int(y1)],
            "limited_by": "face" if s == s_face else ("height" if s == s_h else "width")}


def resample(arr, s, ox, oy):
    """Scale a float image (H, W, C) by s with Lanczos (PIL mode F per channel) and paste it into the canvas at the
    integer-rounded offset (ox, oy): no extra sub-pixel resampling blur."""
    hh, ww = arr.shape[:2]
    nw, nh = max(1, int(round(ww * s))), max(1, int(round(hh * s)))
    ix, iy = int(round(ox)), int(round(oy))
    out = np.zeros((H, W, arr.shape[2]), np.float64)
    for k in range(arr.shape[2]):
        sm = np.asarray(Image.fromarray(arr[..., k].astype(np.float32), "F").resize((nw, nh), Image.LANCZOS), np.float64)
        # clip the pasted block to the canvas
        sx0, sy0 = max(0, -ix), max(0, -iy)
        dx0, dy0 = max(0, ix), max(0, iy)
        w_ = min(nw - sx0, W - dx0); h_ = min(nh - sy0, H - dy0)
        out[dy0:dy0 + h_, dx0:dx0 + w_, k] = sm[sy0:sy0 + h_, sx0:sx0 + w_]
    return out


def stage_cut(src, work, heroes):
    from pymatting import estimate_foreground_ml
    os.makedirs(OUT_DIR, exist_ok=True)
    fits = {}
    for h in heroes:
        rgb, a = clean_alpha(h, src, work)
        fp = fit_params(h, a)
        x0, y0, x1, y1 = fp["bbox_src"]
        p = 8
        X0, Y0 = max(0, x0 - p), max(0, y0 - p)
        X1, Y1 = min(a.shape[1], x1 + p), min(a.shape[0], y1 + p)
        sub_rgb = rgb[Y0:Y1, X0:X1]
        sub_a = a[Y0:Y1, X0:X1]
        # colour decontamination: the true figure colour under a semi-transparent edge (no scene halo)
        fg = estimate_foreground_ml(sub_rgb, sub_a)
        fg = np.clip(fg, 0.0, 1.0)
        prem = np.concatenate([fg * sub_a[..., None], sub_a[..., None]], -1)
        out = resample(prem, fp["scale"], fp["ox"] + X0 * fp["scale"], fp["oy"] + Y0 * fp["scale"])
        out = np.clip(out, 0.0, 1.0)
        al = out[..., 3]
        col = np.where(al[..., None] > 1e-4, out[..., :3] / np.maximum(al[..., None], 1e-4), 0.0)
        # transparent pixels carry the nearest figure colour (no dark fringe under linear filtering / mipmaps)
        from scipy import ndimage
        solid = al > 0.02
        idx = ndimage.distance_transform_edt(~solid, return_distances=False, return_indices=True)
        col = np.where(solid[..., None], col, col[idx[0], idx[1]])
        al[al < 2.0 / 255.0] = 0.0
        rgba = np.concatenate([np.clip(col, 0, 1), al[..., None]], -1)
        Image.fromarray((rgba * 255.0 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT_DIR, "%s.png" % h), optimize=True)
        fits[h] = fp
        print("cut", h, fp, flush=True)
    os.makedirs(work, exist_ok=True)
    old = {}
    fpath = os.path.join(work, "fits.json")
    if os.path.exists(fpath):
        old = json.load(open(fpath))
    old.update(fits)
    json.dump(old, open(fpath, "w"), indent=1)
    return old


# ----------------------------------------------------------------------------------------------- rig
# Measured on the fitted cut-outs (848×1264) with the debug overlays of stage «debug» (points + ellipses on 4× face
# crops), the founders' conventions (hero.gd RIGS comments, shaders/hero.gdshader):
#   head_c/head_r  skull + hair mass; the head turns inside 0.92 r, fades out by 1.18 r and above neck.y ± 25
#   neck           the base of the neck (pivot of the head sway), chest_c/chest_r the bust ellipse, waist_y the waist
#   feet           ground contact between the feet;  hair_l/hair_r Vector4(x bound, y top, falloff, amp) — only free
#                  hair (or tail / scarf / veil) is beyond the bound, never a hand or the face
#   eye_*          Vector4(x, y, half-w, half-h) of the eye opening between the lash lines; lid_* = upper-lid skin
#                  samples (left x1,y1 -> right x2,y2) so the closing lid has her lid colour (blush-safe); lid_tilt = eye
#                  slant (rad, + = the outer side lower on screen for the image-left eye… measured as atan2(dy, dx) of the
#                  lash line, left corner -> right corner)
#   mouth          Vector4(x, y, half-w, half-h); half-w 0 = no talk flap (open / hidden mouth)
#   av             Vector3(face centre x, face centre y − 0.15 face width, 848 / (2 face widths)) — round avatar
#   zoom_k         face width of the art the fixed-zoom face crops were tuned on (mc/hana pre-redraw ≈ 115 px, i.e.
#                  their 95 / 89 px × 1.25) / her face width
RIG = {
    "tsubame": {
        "head_c": [650, 190], "head_r": 92, "neck": [652, 262], "chest_c": [667, 355], "chest_r": [72, 48],
        "waist_y": 470, "feet": [655, 1240], "hair_l": [500, 300, 15, 10], "hair_r": [0, 0, 0, 0],
        "eye_l": [623, 205, 14.3, 6.2], "eye_r": [673.5, 201.8, 11.8, 5.8], "mouth": [655, 241, 0, 6],
        "lash": "342428", "lid_l": [633, 195.5, 636, 195], "lid_r": [665.7, 193, 676.9, 186.9],
        "lid_tilt": [0.14, -0.25]},
    "miel": {
        "head_c": [405, 180], "head_r": 112, "neck": [452, 285], "chest_c": [487, 410], "chest_r": [85, 60],
        "waist_y": 520, "feet": [447, 1240], "hair_l": [0, 0, 0, 0], "hair_r": [0, 0, 0, 0],
        "eye_l": [388.6, 210.8, 15.5, 6.6], "eye_r": [439, 183.6, 11.5, 6.0], "mouth": [431, 227, 0, 8],
        "lash": "5d3525", "lid_l": [378.3, 204, 394.3, 195.8], "lid_r": [425.7, 181.3, 439.6, 169.4],
        "lid_tilt": [-0.42, -0.56]},
    "kohaku": {
        "head_c": [428, 268], "head_r": 115, "neck": [463, 355], "chest_c": [470, 440], "chest_r": [80, 55],
        "waist_y": 560, "feet": [432, 1240], "hair_l": [222, 300, 25, 12], "hair_r": [612, 420, 12, 10],
        "eye_l": [405, 304.5, 14.5, 5], "eye_r": [456.5, 277.8, 15, 4.8], "mouth": [451.5, 323.5, 10, 4],
        "lash": "4d2b29", "lid_l": [393.4, 297.6, 409.7, 292.4], "lid_r": [440.8, 278.2, 461.7, 262.7],
        "lid_tilt": [-0.22, -0.56]},
    "shirin": {
        "head_c": [440, 195], "head_r": 118, "neck": [448, 282], "chest_c": [480, 387], "chest_r": [85, 50],
        "waist_y": 520, "feet": [440, 1240], "hair_l": [200, 380, 20, 8], "hair_r": [600, 380, 20, 8],
        "eye_l": [417, 215.6, 13, 4.8], "eye_r": [467.5, 204.5, 12, 4.6], "mouth": [449, 247, 11, 4.5],
        "lash": "251c20", "lid_l": [406.4, 204.8, 428.8, 207.5], "lid_r": [454.4, 198.9, 465, 195],
        "lid_tilt": [0.04, -0.22]},
    "zlata": {
        "head_c": [430, 160], "head_r": 135, "neck": [432, 248], "chest_c": [443, 370], "chest_r": [75, 45],
        "waist_y": 510, "feet": [405, 1240], "hair_l": [225, 450, 20, 8], "hair_r": [620, 450, 20, 8],
        "eye_l": [406, 178, 13.5, 4.7], "eye_r": [454, 176, 13, 4.6], "mouth": [432, 207.5, 13, 4.5],
        "lash": "3a1c17", "lid_l": [408, 169, 420.3, 171.7], "lid_r": [447.1, 166.3, 452, 166]},
}
RIG_NOTES = {
    "tsubame": "Mouth hidden behind the scarf: talk flap off (mouth half-w 0), the point is where her lips are under it. "
               "Scarf + ponytail fill the left of the canvas, so the body stands right of centre (feet x 655); the fit is "
               "width-limited, her face is ~6% smaller than the founders'. Scarf tip fades out (the source frame cuts it). "
               "hair_l = ponytail + scarf; the head zone just reaches the letter hand (sub-pixel wobble).",
    "miel": "Open smile: talk flap off (mouth half-w 0, the point is the closed-lip line). Curls stay still: the skirt "
            "frill hangs right under them inside any hair_l band. Strong head tilt: lid_tilt follows it.",
    "kohaku": "hair_l = the fox tail (wag); its motion-blurred tip keeps the art's blur as soft decontaminated alpha. "
              "hair_r = the free strands right of the sleeve. Half-lidded, tilted eyes: eye boxes cover the thick lash.",
    "shirin": "hair_l / hair_r = the veil wings under her open arms (hands stay above y_min).",
    "zlata": "hair_l / hair_r = the outer feathers of the firebird mantle (boots stay outside the bands); the braid lies "
             "over the chest and stays still. The kokoshnik turns with the head (head_r 135).",
}


def face_w(r):
    el, er = r["eye_l"], r["eye_r"]
    return FACE_PER_EYES * float(np.hypot(er[0] - el[0], er[1] - el[1]))


def rig_face(r):
    el, er, m = r["eye_l"], r["eye_r"], r["mouth"]
    return ((el[0] + er[0] + m[0] * 2.0) * 0.25, ((el[1] + er[1]) * 0.5 + m[1]) * 0.5)


def derived(r):
    fw = face_w(r)
    fx, fy = rig_face(r)
    out = dict(r)
    out["face_w"] = round(fw, 1)
    out.setdefault("av", [round(fx, 1), round(fy - 0.15 * fw, 1), round(W / (2.0 * fw), 2)])
    out.setdefault("zoom_k", round(115.0 / fw, 2))
    return out


def _compact_json(obj, ind=0):
    """JSON with one key per line and flat arrays / small dicts inline (readable diffs)."""
    pad = " " * ind
    if isinstance(obj, dict):
        flat = all(not isinstance(v, (dict, list)) or (isinstance(v, list) and all(not isinstance(x, (dict, list)) for x in v))
                   for v in obj.values())
        if flat and ind >= 4:
            return "{" + ", ".join("%s: %s" % (json.dumps(k), json.dumps(v, ensure_ascii=False)) for k, v in obj.items()) + "}"
        items = ["%s %s: %s" % (pad, json.dumps(k), _compact_json(v, ind + 1)) for k, v in obj.items()]
        return "{\n" + ",\n".join(items) + "\n" + pad + "}"
    return json.dumps(obj, ensure_ascii=False)


def stage_json(work, heroes):
    fits = {}
    fpath = os.path.join(work, "fits.json")
    if os.path.exists(fpath):
        fits = json.load(open(fpath))
    data = {}
    if os.path.exists(JSON_PATH):
        data = json.load(open(JSON_PATH))
    for h in heroes:
        if h not in RIG:
            continue
        c = HEROES[h]
        data[h] = {"file": "res://assets/v10/wave1/hero/%s.png" % h,
                   "source": "w1src/" + c["src"], "source_note": c["slot"],
                   "fit": fits.get(h, {}), "rig": derived(RIG[h])}
        if h in RIG_NOTES:
            data[h]["notes"] = RIG_NOTES[h]
    out = {k: data[k] for k in ORDER if k in data}
    with open(JSON_PATH, "w") as f:
        f.write(_compact_json(out) + "\n")
    print("json", JSON_PATH, list(out))


# ----------------------------------------------------------------------------------------------- debug
def draw_rig(im, r, k=1.0, ox=0.0, oy=0.0):
    d = ImageDraw.Draw(im)
    T = lambda x, y: ((x - ox) * k, (y - oy) * k)
    def circ(c, rad, col, w=1):
        x, y = T(*c[:2]); d.ellipse((x - rad * k, y - rad * k, x + rad * k, y + rad * k), outline=col, width=w)
    def ell(c, rx, ry, col, w=1, ang=0.0):
        cs, sn = np.cos(ang), np.sin(ang)
        pts = []
        for t in np.linspace(0, 2 * np.pi, 49):
            vx, vy = rx * np.cos(t), ry * np.sin(t)
            pts.append(T(c[0] + cs * vx - sn * vy, c[1] + sn * vx + cs * vy))
        d.line(pts, fill=col, width=w)
    def dot(c, col, rad=2):
        x, y = T(*c[:2]); d.ellipse((x - rad, y - rad, x + rad, y + rad), fill=col)
    def hline(y, col, w=1):
        d.line((0, (y - oy) * k, im.width, (y - oy) * k), fill=col, width=w)
    hc, hr = r["head_c"], r["head_r"]
    circ(hc, hr * 0.92, (255, 255, 0)); circ(hc, hr * 1.18, (255, 170, 0)); dot(hc, (255, 255, 0), 4)
    dot(r["neck"], (0, 255, 255), 5); hline(r["neck"][1] - 25, (0, 200, 200)); hline(r["neck"][1] + 25, (0, 120, 200))
    ell(r["chest_c"], r["chest_r"][0], r["chest_r"][1], (255, 0, 255), 2); hline(r["waist_y"], (255, 0, 255), 2)
    dot(r["feet"], (255, 60, 60), 7); hline(r["feet"][1], (255, 60, 60))
    for key, col, sgn in (("hair_l", (60, 255, 60), -1), ("hair_r", (60, 160, 255), 1)):
        hx = r[key]
        if hx[3] > 0:
            for dx, w in ((0, 2), (-hx[2], 1), (hx[2], 1)):
                X, Y = T(hx[0] + dx, hx[1]); d.line((X, Y, X, im.height), fill=col, width=w)
            X, Y = T(hx[0], hx[1]); d.line((X - 60 * k * -sgn, Y, X, Y), fill=col, width=2)
    tilt = r.get("lid_tilt", [0.0, 0.0])
    for key, tl in (("eye_l", tilt[0]), ("eye_r", tilt[1])):
        e = r[key]
        if e[2] > 0:
            ell(e, e[2], e[3], (0, 255, 0), 1, tl)
            # the shader's lid area (1.25 hw × 1.45 hh) and the closed-lid line
            ell(e, e[2] * 1.25, e[3] * 1.45, (0, 140, 0), 1, tl)
        dot(e, (255, 0, 0), 1)
    m = r["mouth"]
    if m[2] > 0:
        ell(m, m[2], m[3], (255, 80, 80))
    dot(m, (255, 255, 255), 1)
    for key in ("lid_l", "lid_r"):
        if key in r:
            l = r[key]; dot(l[:2], (255, 140, 0), 2); dot(l[2:], (255, 140, 0), 2)
    if "av" in r:
        a = r["av"]; circ(a[:2], W / a[2] / 2.0, (255, 255, 255))


def shader_eyelid(img, r, blink):
    """numpy port of hero.gdshader eyelid() (static pose, no sway) to preview a closed blink."""
    a = np.asarray(img, np.float64) / 255.0
    out = a.copy()
    def tex(x, y):
        xi = int(np.clip(round(x - 0.5), 0, W - 1)); yi = int(np.clip(round(y - 0.5), 0, H - 1))
        return a[yi, xi, :3]
    def skin_at(x, y):
        return (tex(x - 1.5, y) + tex(x + 1.5, y) + tex(x, y - 1.5) + tex(x, y + 1.5)) * 0.25
    lash_col = np.array([int(r["lash"][i:i + 2], 16) / 255.0 for i in (0, 2, 4)])
    tilt = r.get("lid_tilt", [0.0, 0.0])
    for key, lk, tl in (("eye_l", "lid_l", tilt[0]), ("eye_r", "lid_r", tilt[1])):
        e = r[key]
        if e[2] <= 0:
            continue
        lid_s = r.get(lk, [0, 0, 0, 0])
        x0, x1 = int(e[0] - e[2] * 2), int(e[0] + e[2] * 2) + 1
        y0, y1 = int(e[1] - e[3] * 3), int(e[1] + e[3] * 3) + 1
        for py in range(y0, y1):
            for px in range(x0, x1):
                p0 = np.array([px + 0.5, py + 0.5])
                c, s = np.cos(-tl), np.sin(-tl)
                v = p0 - np.array(e[:2])
                p = np.array(e[:2]) + np.array([c * v[0] - s * v[1], s * v[0] + c * v[1]])
                q = (p - np.array(e[:2])) / (np.array(e[2:]) * np.array([1.25, 1.45]))
                er_ = np.hypot(*q)
                if er_ > 1.0:
                    continue
                u = np.clip((p[0] - e[0]) / (e[2] * 1.25), -1, 1)
                lid = e[1] - e[3] * 1.4 + (e[3] * 2.0) * blink + 0.35 * e[3] * (1 - u * u) * blink
                if lid_s[0] > 0:
                    t = np.clip(u * 0.5 + 0.5, 0, 1)
                    skin = skin_at(lid_s[0], lid_s[1]) * (1 - t) + skin_at(lid_s[2], lid_s[3]) * t
                else:
                    cy = e[1] + e[3] * 2.5
                    skin = (tex(e[0] - e[2] * 0.5, cy) + tex(e[0], cy) + tex(e[0] + e[2] * 0.5, cy) + tex(e[0], cy + e[3] * 0.6)) * 0.25
                    skin = skin * 0.75 + tex(p0[0], cy) * 0.25
                feather = 1.0 - smoothstep(0.82, 1.0, er_)
                above = (1.0 - smoothstep(lid - 1.0, lid + 1.0, p[1])) * feather
                col = out[py, px, :3] * (1 - above) + skin * above
                lw = 1.7 + 1.3 * smoothstep(0.2, 1.0, abs(u))
                lash = np.exp(-((p[1] - lid) / lw) ** 2) * smoothstep(0.35, 0.8, blink) * (1 - smoothstep(0.9, 1.0, abs(u) * 0.95))
                out[py, px, :3] = col * (1 - lash * feather) + lash_col * lash * feather
    return Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def shader_talk(img, r, talk):
    m = r["mouth"]
    if m[2] <= 0:
        return img
    a = np.asarray(img, np.float64) / 255.0
    out = a.copy()
    top = m[1] - m[3]
    for py in range(int(m[1] - m[3] * 2), int(m[1] + m[3] * 2) + 1):
        for px in range(int(m[0] - m[2] * 1.2), int(m[0] + m[2] * 1.2) + 1):
            q = np.array([(px + 0.5 - m[0]) / m[2], (py + 0.5 - m[1]) / m[3]])
            wm = 1.0 - smoothstep(0.55, 1.0, np.hypot(*q))
            sy = py + 0.5 + (py + 0.5 - top) * talk * 0.42 * wm
            yi = int(np.clip(round(sy - 0.5), 0, H - 1))
            out[py, px] = a[yi, px]
    return Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def stage_debug(work, heroes, face_k=4):
    dd = os.path.join(work, "debug")
    os.makedirs(dd, exist_ok=True)
    for h in heroes:
        if h not in RIG:
            continue
        r = derived(RIG[h])
        src = Image.open(os.path.join(OUT_DIR, "%s.png" % h)).convert("RGBA")
        bg = Image.new("RGBA", src.size, (58, 56, 70, 255)); bg.alpha_composite(src)
        full = bg.copy(); draw_rig(full, r)
        full.convert("RGB").resize((W // 2, H // 2), Image.LANCZOS).save(os.path.join(dd, "%s_full.jpg" % h), quality=86)
        fx, fy = rig_face(r)
        box = (int(fx - 75), int(fy - 70), int(fx + 75), int(fy + 60))
        tiles = []
        for variant in ("rig", "plain", "blink", "talk"):
            if variant == "blink":
                im = shader_eyelid(bg, r, 1.0)
            elif variant == "talk":
                im = shader_talk(bg, r, 1.0)
            else:
                im = bg.copy()
            crop = im.crop(box).resize(((box[2] - box[0]) * face_k, (box[3] - box[1]) * face_k), Image.NEAREST if variant == "rig" else Image.LANCZOS)
            if variant == "rig":
                draw_rig(crop, r, face_k, box[0], box[1])
            tiles.append(crop.convert("RGB"))
        sheet = Image.new("RGB", (tiles[0].width * 2 + 6, tiles[0].height * 2 + 6), (0, 0, 0))
        for i, t in enumerate(tiles):
            sheet.paste(t, ((i % 2) * (t.width + 6), (i // 2) * (t.height + 6)))
        sheet.save(os.path.join(dd, "%s_face.jpg" % h), quality=90)
        print("debug", h, os.path.join(dd, "%s_face.jpg" % h))


# ----------------------------------------------------------------------------------------------- sheet
def stage_sheet(work, heroes):
    ids = [("mc", os.path.join(GAME, "assets", "hero", "mc.png")), ("yue", os.path.join(GAME, "assets", "hero", "yue.png"))]
    ids += [(h, os.path.join(OUT_DIR, "%s.png" % h)) for h in heroes]
    k = 0.42
    tw, th = int(W * k), int(H * k)
    rows = []
    for bgc in ((0x1d, 0x1b, 0x2e), (0xf6, 0xef, 0xe6)):
        row = Image.new("RGB", (tw * len(ids), th + 24), bgc)
        d = ImageDraw.Draw(row)
        for i, (name, p) in enumerate(ids):
            im = Image.open(p).convert("RGBA").resize((tw, th), Image.LANCZOS)
            row.paste(im, (i * tw, 0), im)
            d.line((i * tw, 0, i * tw, th), fill=(128, 128, 128))
            d.line((i * tw, int(FEET_Y * k), (i + 1) * tw, int(FEET_Y * k)), fill=(200, 80, 80))
            d.text((i * tw + 6, th + 6), name, fill=(200, 200, 200) if bgc[0] < 100 else (60, 60, 60))
        rows.append(row)
    sheet = Image.new("RGB", (rows[0].width, rows[0].height * 2))
    sheet.paste(rows[0], (0, 0)); sheet.paste(rows[1], (0, rows[0].height))
    out = os.path.join(work, "w1_hero_sheet.jpg")
    sheet.save(out, quality=88)
    print("sheet", out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("stage", choices=["masks", "cut", "json", "debug", "sheet", "all"])
    ap.add_argument("--src", default=os.path.join(SCRATCH, "w1src"))
    ap.add_argument("--work", default=os.path.join(SCRATCH, "rig"))
    ap.add_argument("--hero", action="append")
    a = ap.parse_args()
    heroes = a.hero or ORDER
    if a.stage in ("masks", "all"):
        stage_masks(a.src, a.work, heroes)
    if a.stage in ("cut", "all"):
        stage_cut(a.src, a.work, heroes)
    if a.stage in ("json", "all"):
        stage_json(a.work, heroes)
    if a.stage in ("debug", "all"):
        stage_debug(a.work, heroes)
    if a.stage in ("sheet", "all"):
        stage_sheet(a.work, heroes)


if __name__ == "__main__":
    main()
