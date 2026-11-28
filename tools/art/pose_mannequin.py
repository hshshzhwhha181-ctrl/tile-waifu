#!/usr/bin/env python3
"""Pose mannequin renderer for reference-pose conditioning (art bake-off, V2).

Renders a plain mannequin (capsule limbs, chest and pelvis ellipses, head ellipse,
facing symbols) from 2D keypoints on a 680x1024 (2:3) canvas. The image is uploaded as
an extra reference and the prompt says "follow this body pose exactly". It carries POSE
only: grey body, no identity, no clothes.

Conventions (y grows downward, canvas 680x1024):
  * standing figure about 880 px tall (7 heads of ~125 px), crotch line near 46 % of height
  * limbs: warm colours = limbs nearer to the camera, cool colours = farther limbs
  * facing symbols drawn on head / chest / pelvis:
        circle with dot   = faces the camera
        circle with cross = faces away from the camera (we see the back)
        arrow             = faces that way in the picture plane
  * a dashed spine line is drawn when the back is visible (back view / side-back view)
  * props (table, floor, stool) are light grey rectangles

Usage:
  python3 pose_mannequin.py OUTDIR            # writes pose_<id>.png for all poses + sheet
  python3 pose_mannequin.py OUTDIR a c        # only some poses
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H = 680, 1024
BG = (226, 226, 230)
BODY = (150, 154, 164)
NEAR = (214, 96, 84)
FAR = (84, 120, 200)
CORE = (120, 126, 140)
PROP = (190, 190, 198)

POSES = {
    # (a) over-the-shoulder back view, standing. Pelvis and legs seen from behind and
    # rotated WITH the body; only the head and upper chest twist back toward the camera.
    "a": dict(
        title="over-the-shoulder back view",
        head=(362, 120, 62, 74), neck=(352, 192), chest=(346, 262, 92, 70), pelvis=(332, 520, 112, 78),
        sh_l=(292, 228), sh_r=(408, 236),
        el_l=(262, 330), el_r=(450, 320), wr_l=(300, 440), wr_r=(404, 120 + 40),
        hip_l=(292, 528), hip_r=(376, 514),
        kn_l=(276, 740), kn_r=(404, 736), an_l=(262, 930), an_r=(424, 934),
        toe_l=(236, 960), toe_r=(452, 960),
        far=("l",), floor=960,
        marks=[("head", "dir", (-1, 0.3)), ("chest", "away"), ("pelvis", "away")], spine=True,
        notes="hips and legs face away; weight on the right leg; S-curve"),
    # (b) leaning forward on a table, seen from behind-side (3/4 rear).
    "b": dict(
        title="leaning on table from behind-side",
        head=(500, 262, 58, 70), neck=(450, 300), chest=(400, 350, 100, 70), pelvis=(238, 470, 108, 76),
        sh_l=(430, 330), sh_r=(396, 388),
        el_l=(520, 420), el_r=(470, 470), wr_l=(580, 500), wr_r=(540, 540),
        hip_l=(232, 452), hip_r=(246, 494),
        kn_l=(250, 700), kn_r=(300, 704), an_l=(256, 920), an_r=(330, 924),
        toe_l=(270, 960), toe_r=(356, 960),
        far=("l",), floor=960,
        props=[("rect", (470, 520, 680, 548)), ("rect", (520, 548, 540, 960)), ("rect", (640, 548, 660, 960))],
        marks=[("head", "dir", (-0.8, 0.4)), ("pelvis", "away")], spine=True,
        notes="torso bent forward, hips pushed back and up, arch in the lower back, forearms on the table; head turns back over the shoulder"),
    # (c) seated, crossed legs, on the edge of a table / counter, 3/4 front.
    "c": dict(
        title="seated crossed legs",
        head=(330, 150, 62, 74), neck=(328, 222), chest=(322, 300, 96, 74), pelvis=(318, 470, 114, 70),
        sh_l=(270, 262), sh_r=(386, 266),
        el_l=(222, 360), el_r=(440, 372), wr_l=(200, 440), wr_r=(420, 470),
        hip_l=(280, 480), hip_r=(358, 480),
        kn_l=(330, 620), kn_r=(436, 600), an_l=(470, 790), an_r=(250, 790),
        toe_l=(520, 800), toe_r=(214, 806),
        far=("l",), floor=960,
        props=[("rect", (120, 505, 560, 560)), ("rect", (150, 560, 170, 960)), ("rect", (510, 560, 530, 960))],
        marks=[("head", "front"), ("chest", "front"), ("pelvis", "front")], spine=False,
        notes="seated on the table edge, one thigh crossed over the other at the knee, shins visible and separate, thighs full and soft"),
    # (d) kneeling arch seen from the side-back.
    "d": dict(
        title="kneeling arch, side-back",
        head=(520, 410, 58, 70), neck=(470, 440), chest=(400, 470, 100, 66), pelvis=(236, 560, 108, 80),
        sh_l=(448, 466), sh_r=(414, 508),
        el_l=(520, 580), el_r=(474, 600), wr_l=(560, 700), wr_r=(520, 710),
        hip_l=(228, 540), hip_r=(246, 584),
        kn_l=(250, 760), kn_r=(310, 770), an_l=(120, 900), an_r=(176, 920),
        toe_l=(60, 940), toe_r=(110, 950),
        far=("l",), floor=960,
        props=[("rect", (20, 950, 660, 975))],
        marks=[("head", "dir", (-0.9, -0.2)), ("pelvis", "away")], spine=True,
        notes="knees on the floor hip-width apart, shins back along the floor, hips raised high behind, spine arched, hands on the floor, face turned back toward the camera"),
    # (e) lying on her side, hip up.
    "e": dict(
        title="lying on side, hip up",
        head=(130, 560, 58, 70), neck=(190, 580), chest=(268, 600, 110, 74), pelvis=(430, 590, 100, 90),
        sh_l=(215, 560), sh_r=(235, 640),
        el_l=(150, 650), el_r=(190, 700), wr_l=(110, 730), wr_r=(110, 740),
        hip_l=(425, 540), hip_r=(440, 630),
        kn_l=(560, 610), kn_r=(540, 720), an_l=(640, 690), an_r=(630, 770),
        toe_l=(668, 700), toe_r=(664, 790),
        far=("l",), floor=800,
        props=[("rect", (20, 800, 660, 840))],
        marks=[("head", "dir", (0, -1)), ("chest", "front")], spine=False,
        notes="lying on the left side, propped on the left elbow, waist dips and the upper hip rises in a curve, top leg bent forward over the lower leg"),
    # (f) standing, one leg lifted (knee bent, foot kicked back), 3/4 front.
    "f": dict(
        title="standing, one leg lifted",
        head=(340, 118, 62, 74), neck=(338, 190), chest=(334, 262, 96, 70), pelvis=(330, 518, 112, 76),
        sh_l=(286, 228), sh_r=(396, 232),
        el_l=(240, 150), el_r=(430, 150), wr_l=(290, 90), wr_r=(390, 90),
        hip_l=(290, 524), hip_r=(372, 520),
        kn_l=(294, 740), kn_r=(430, 650), an_l=(292, 930), an_r=(380, 790),
        toe_l=(262, 960), toe_r=(360, 830),
        far=("r",), floor=960,
        marks=[("head", "front"), ("chest", "front"), ("pelvis", "front")], spine=False,
        notes="standing on the left leg, right knee bent forward-out with the foot kicked up behind, both hands in her hair"),
}


def capsule(d, p, q, r, col):
    d.line([p, q], fill=col, width=int(2 * r))
    for c in (p, q):
        d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=col)


def ellipse(d, c, rx, ry, col, outline=None):
    d.ellipse([c[0] - rx, c[1] - ry, c[0] + rx, c[1] + ry], fill=col, outline=outline, width=3)


def marker(d, c, kind, scale=22):
    x, y = c
    if kind in ("front", "away"):
        d.ellipse([x - scale, y - scale, x + scale, y + scale], outline=(30, 30, 30), width=4)
        if kind == "front":
            d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=(30, 30, 30))
        else:
            s = scale * 0.6
            d.line([(x - s, y - s), (x + s, y + s)], fill=(30, 30, 30), width=4)
            d.line([(x - s, y + s), (x + s, y - s)], fill=(30, 30, 30), width=4)
    elif kind == "dir":
        pass


def arrow(d, c, v, ln=70, col=(30, 140, 60)):
    n = math.hypot(*v) or 1
    ux, uy = v[0] / n, v[1] / n
    e = (c[0] + ux * ln, c[1] + uy * ln)
    d.line([c, e], fill=col, width=6)
    px, py = -uy, ux
    d.polygon([e, (e[0] - ux * 18 + px * 11, e[1] - uy * 18 + py * 11), (e[0] - ux * 18 - px * 11, e[1] - uy * 18 - py * 11)], fill=col)


def dashed(d, p, q, col=(60, 60, 60), seg=14):
    L = math.hypot(q[0] - p[0], q[1] - p[1])
    n = int(L // seg)
    for i in range(0, n, 2):
        a = i / n
        b = min((i + 1) / n, 1)
        d.line([(p[0] + (q[0] - p[0]) * a, p[1] + (q[1] - p[1]) * a), (p[0] + (q[0] - p[0]) * b, p[1] + (q[1] - p[1]) * b)], fill=col, width=4)


def render(pid, label=True):
    P = POSES[pid]
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    for pr in P.get("props", []):
        d.rectangle(pr[1], fill=PROP)
    fl = P["floor"]
    d.line([(0, fl + 4), (W, fl + 4)], fill=(170, 170, 178), width=3)
    far = set(P["far"])

    def col(side):
        return FAR if side in far else NEAR

    # far limbs first
    order = ["l", "r"] if "l" in far else ["r", "l"]
    for side in order:
        c = col(side)
        capsule(d, P["hip_" + side], P["kn_" + side], 34, c)
        capsule(d, P["kn_" + side], P["an_" + side], 24, c)
        capsule(d, P["an_" + side], P["toe_" + side], 14, c)
    # torso
    capsule(d, P["neck"], P["chest"][:2], 22, CORE)
    ellipse(d, P["pelvis"][:2], P["pelvis"][2], P["pelvis"][3], BODY, (70, 70, 80))
    cx, cy, rx, ry = P["chest"]
    capsule(d, (cx, cy + 40), (P["pelvis"][0], P["pelvis"][1] - 30), 44, CORE)
    ellipse(d, (cx, cy), rx, ry, BODY, (70, 70, 80))
    for side in order:
        c = col(side)
        capsule(d, P["sh_" + side], P["el_" + side], 22, c)
        capsule(d, P["el_" + side], P["wr_" + side], 17, c)
        w = P["wr_" + side]
        d.ellipse([w[0] - 16, w[1] - 16, w[0] + 16, w[1] + 16], fill=c, outline=(60, 60, 60), width=2)
    hx, hy, hrx, hry = P["head"]
    ellipse(d, (hx, hy), hrx, hry, (176, 178, 188), (70, 70, 80))
    if P.get("spine"):
        dashed(d, P["neck"], P["pelvis"][:2])
    for m in P["marks"]:
        part = m[0]
        pos = {"head": (hx, hy), "chest": P["chest"][:2], "pelvis": P["pelvis"][:2]}[part]
        if m[1] == "dir":
            arrow(d, pos, m[2], ln=hrx + 36)
        else:
            marker(d, pos, m[1])
    if label:
        f = ImageFont.load_default()
        d.text((14, 12), f"pose {pid}: {P['title']}", fill=(40, 40, 40), font=f)
    return im


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    ids = sys.argv[2:] or list(POSES)
    ims = []
    for i in ids:
        im = render(i)
        im.save(out / f"pose_{i}.png")
        ims.append(im)
    sheet = Image.new("RGB", (W * len(ims) // 2, H // 2), BG)
    for k, im in enumerate(ims):
        sheet.paste(im.resize((W // 2, H // 2)), (k * W // 2, 0))
    sheet.save(out / "pose_sheet.png")
    print("wrote", len(ims), "poses to", out)


if __name__ == "__main__":
    main()
