#!/usr/bin/env python3
"""Tile-back emblems of the wave-1 tile themes (V10W1Look.THEMES), drawn procedurally.

    python3 -I w1_look_emblems.py <out_dir>        -> crimson_moon.png sugar_lace.png foxfire.png monisto.png

Same format as assets/v10/look/emblems/*.png (tools/prep_emblems.py of the look lane): RGBA, cropped to alpha,
112 px tall (@2x of the theme thumb). Drawn at 8x and downsampled (LANCZOS) for clean edges. Each emblem is a small
gilded ornament in the goddess's palette (ROSTER_20 §2), no text:
  crimson_moon  Цубамэ  — crimson crescent in a gold rim, a silver swallow crossing it, two sparks
  sugar_lace    Миэль   — three-tier gala cake: cream tiers, raspberry glaze, sugar-lace pearls, a rose on top
  foxfire       Кохаку  — white fox mask with vermilion markings under an amber fox fire
  monisto       Ширин   — sun-coin with rays and a teal stone, a coin necklace hanging below
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SS = 8          # supersampling
H_OUT = 112     # final height


def hx(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))

    # ---- masks ------------------------------------------------------------------------------------------
    def mask(self):
        return Image.new("L", self.img.size, 0)

    def poly(self, pts, m=None):
        m = m or self.mask()
        ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
        return m

    def ellipse(self, cx, cy, rx, ry=None, m=None):
        ry = rx if ry is None else ry
        m = m or self.mask()
        ImageDraw.Draw(m).ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=255)
        return m

    def rrect(self, x0, y0, x1, y1, r, m=None):
        m = m or self.mask()
        ImageDraw.Draw(m).rounded_rectangle([x0 * SS, y0 * SS, x1 * SS, y1 * SS], radius=r * SS, fill=255)
        return m

    # ---- paint ------------------------------------------------------------------------------------------
    def grad(self, m, top, bot, y0=None, y1=None):
        """fill mask with a vertical gradient between rows y0..y1 (units; default = mask bbox)"""
        bb = m.getbbox()
        if not bb:
            return
        a = bb[1] if y0 is None else y0 * SS
        b = bb[3] if y1 is None else y1 * SS
        g = Image.new("RGBA", self.img.size)
        px = []
        for y in range(self.img.size[1]):
            t = min(1.0, max(0.0, (y - a) / max(1.0, b - a)))
            px.append(tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(4)))
        col = Image.new("RGBA", (1, self.img.size[1]))
        col.putdata(px)
        g = col.resize(self.img.size, Image.NEAREST)
        self.img.paste(g, (0, 0), m)

    def fill(self, m, c):
        self.img.paste(Image.new("RGBA", self.img.size, c), (0, 0), m)

    def outline(self, m, width, c):
        """paint a rim of `width` units outside the mask (draw BEFORE the fill)"""
        k = int(width * SS) * 2 + 1
        d = m.filter(ImageFilter.MaxFilter(k if k % 2 else k + 1))
        self.fill(d, c)

    def bevel(self, m, light, dark, off=1.2, alpha=0.55):
        """light on the top-left inner edge, shade on the bottom-right"""
        o = int(off * SS)
        sh = ImageChops.offset(m, o, o)
        hi = ImageChops.subtract(m, sh)
        sh2 = ImageChops.offset(m, -o, -o)
        lo = ImageChops.subtract(m, sh2)
        self.fill(hi.point(lambda v: int(v * alpha)), light)
        self.fill(lo.point(lambda v: int(v * alpha)), dark)

    def spark(self, cx, cy, r, c, rim):
        pts = []
        for i in range(8):
            a = math.pi * 0.25 * i - math.pi * 0.5
            rr = r if i % 2 == 0 else r * 0.3
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
        m = self.poly(pts)
        self.outline(m, 0.6, rim)
        self.fill(m, c)

    def gilded(self, m, rim=0.9):
        self.outline(m, rim, DARK_GOLD)
        self.grad(m, GOLD_HI, GOLD_LO)
        self.bevel(m, (255, 248, 214, 255), (92, 54, 12, 255))

    def save(self, path):
        im = self.img.resize((self.w * 2, self.h * 2), Image.LANCZOS)   # intermediate, keeps detail
        bb = im.getchannel("A").point(lambda a: 255 if a > 10 else 0).getbbox()
        if bb:
            im = im.crop(bb)
        im = im.resize((max(1, round(im.width * H_OUT / im.height)), H_OUT), Image.LANCZOS)
        im.save(path, optimize=True)
        print(os.path.basename(path), im.size)


GOLD_HI = hx("fff0b8")
GOLD_LO = hx("b8862e")
DARK_GOLD = hx("4a2a0a")


def rot(pts, ang, cx, cy, s=1.0):
    c, sn = math.cos(ang), math.sin(ang)
    return [(cx + (x * c - y * sn) * s, cy + (x * sn + y * c) * s) for x, y in pts]


# ------------------------------------------------------------------------------------------------- Цубамэ

SWALLOW = [(0, -15), (2.2, -11), (3.0, -6), (9, -7.5), (17, -5), (24, 1), (15, -0.5), (8, 0.5), (3.2, 3),
           (2.6, 8), (6.5, 21), (0.8, 11), (-0.8, 11), (-6.5, 21), (-2.6, 8), (-3.2, 3), (-8, 0.5), (-15, -0.5),
           (-24, 1), (-17, -5), (-9, -7.5), (-3.0, -6), (-2.2, -11)]


def crimson_moon(out):
    cv = Canvas(96, 120)
    outer = cv.ellipse(46, 56, 36)
    bite = cv.ellipse(62, 46, 31)
    moon = ImageChops.subtract(outer, bite)
    cv.outline(moon, 2.4, DARK_GOLD)
    cv.outline(moon, 1.4, hx("e8c46e"))
    cv.grad(moon, hx("ef5a6a"), hx("7a1222"))
    cv.bevel(moon, hx("ffb3bc"), hx("3d0610"), 1.4, 0.6)
    # a silver swallow crossing the crescent
    sw = cv.poly(rot(SWALLOW, math.radians(-38), 58, 80, 1.15))
    cv.outline(sw, 1.3, hx("1d1b2e"))
    cv.grad(sw, hx("f4f6fb"), hx("8f96a8"))
    cv.bevel(sw, (255, 255, 255, 255), hx("4a4f63"), 0.9, 0.5)
    cv.spark(20, 20, 7, hx("e8ebf2"), hx("1d1b2e"))
    cv.spark(80, 18, 4.5, hx("c8283c"), hx("3d0610"))
    cv.spark(18, 98, 4, hx("c8cfe0"), hx("1d1b2e"))
    cv.save(os.path.join(out, "crimson_moon.png"))


# ------------------------------------------------------------------------------------------------- Миэль

def sugar_lace(out):
    cv = Canvas(84, 124)
    cream_hi, cream_lo = hx("fffaf0"), hx("e9d3ac")
    rose_hi, rose_lo = hx("f07a90"), hx("b0304c")
    tiers = [(10, 78, 74, 104), (18, 54, 66, 78), (26, 33, 58, 54)]
    # stand
    stand = cv.rrect(4, 104, 80, 111, 3.5)
    stand = ImageChops.lighter(stand, cv.poly([(34, 110), (50, 110), (56, 118), (28, 118)]))
    cv.gilded(stand)
    for (x0, y0, x1, y1) in tiers:
        t = cv.rrect(x0, y0, x1, y1, 3)
        cv.outline(t, 1.0, hx("6e3a1e"))
        cv.grad(t, cream_hi, cream_lo)
        cv.bevel(t, (255, 255, 255, 255), hx("b99566"), 1.0, 0.5)
        # raspberry glaze with drips along the top
        glaze = cv.rrect(x0, y0, x1, y0 + 6, 3)
        n = int((x1 - x0) / 7)
        for i in range(n):
            cx = x0 + 4 + i * (x1 - x0 - 8) / max(1, n - 1)
            dl = 5.5 if i % 2 == 0 else 3.5
            glaze = ImageChops.lighter(glaze, cv.ellipse(cx, y0 + 5 + dl * 0.5, 2.2, dl * 0.6))
        glaze = ImageChops.multiply(glaze, t)
        cv.grad(glaze, rose_hi, rose_lo, y0, y0 + 11)
        cv.bevel(glaze, hx("ffc8d2"), hx("7a1f36"), 0.7, 0.5)
        # sugar lace: a gold line and a row of pearls along the bottom
        line = cv.rrect(x0 + 1, y1 - 4.2, x1 - 1, y1 - 2.8, 0.7)
        cv.fill(line, hx("d9a64a"))
        m = int((x1 - x0) / 5)
        for i in range(m):
            px = x0 + 3 + i * (x1 - x0 - 6) / max(1, m - 1)
            p = cv.ellipse(px, y1 - 7.2, 1.5)
            cv.fill(p, hx("fffdf6"))
            cv.fill(cv.ellipse(px - 0.4, y1 - 7.6, 0.6), (255, 255, 255, 255))
    # a sugar rose on top with two leaves
    for sx in (-1, 1):
        leaf = cv.poly(rot([(0, 0), (5, -2.5), (10, 0), (5, 2.5)], math.radians(-20 if sx > 0 else 200), 42, 27))
        cv.outline(leaf, 0.7, hx("2e4a1e"))
        cv.grad(leaf, hx("a8d27a"), hx("4f7a30"))
    rose = cv.ellipse(42, 24, 8.5)
    cv.outline(rose, 1.0, hx("5a0f22"))
    cv.grad(rose, rose_hi, rose_lo)
    for r, a0 in ((6.2, 30), (4.2, 200), (2.3, 90)):
        d = ImageDraw.Draw(cv.img)
        d.arc([(42 - r) * SS, (24 - r) * SS, (42 + r) * SS, (24 + r) * SS], a0, a0 + 250, fill=hx("7a1f36"), width=int(0.9 * SS))
    cv.fill(cv.ellipse(39.5, 21, 1.6), (255, 220, 228, 200))
    cv.spark(70, 22, 4.5, hx("fff0c8"), hx("8a5a2a"))
    cv.spark(12, 40, 3.2, hx("fff0c8"), hx("8a5a2a"))
    cv.save(os.path.join(out, "sugar_lace.png"))


# ------------------------------------------------------------------------------------------------- Кохаку

def flame(cv, cx, by, h, w, lean=0.0):
    pts = []
    n = 24
    for i in range(n + 1):
        t = i / n
        y = by - h * t
        half = w * math.sin(math.pi * min(1.0, t * 1.15)) * (1.0 - t) ** 0.35 * 0.5
        pts.append((cx + half + lean * t * t * h * 0.25, y))
    for i in range(n, -1, -1):
        t = i / n
        y = by - h * t
        half = w * math.sin(math.pi * min(1.0, t * 1.15)) * (1.0 - t) ** 0.35 * 0.5
        pts.append((cx - half + lean * t * t * h * 0.25, y))
    return cv.poly(pts)


def foxfire(out):
    cv = Canvas(96, 124)
    cx, cy = 48, 74
    # amber fox fire rising above the mask
    f = flame(cv, cx, 50, 40, 26, 0.6)
    cv.outline(f, 1.2, hx("6a120b"))
    cv.grad(f, hx("fff0b0"), hx("e0782a"))
    inner = flame(cv, cx + 1, 47, 26, 13, 0.4)
    cv.grad(inner, hx("fffbe6"), hx("f0b84f"))
    for sx, sy, s in ((16, 40, 9), (80, 44, 8)):
        w = flame(cv, sx, sy + 8, s * 2.0, s, 0.5 if sx < cx else -0.5)
        cv.outline(w, 0.8, hx("6a120b"))
        cv.grad(w, hx("fff0b0"), hx("e2a23d"))
    face = [(-21, -10), (-23, 1), (-18, 14), (-8, 25), (0, 30), (8, 25), (18, 14), (23, 1), (21, -10),
            (12, -13), (0, -11), (-12, -13)]
    ears = [[(-21, -10), (-19, -33), (-6, -12)], [(21, -10), (19, -33), (6, -12)]]
    m = cv.poly([(cx + x, cy + y) for x, y in face])
    for e in ears:
        m = ImageChops.lighter(m, cv.poly([(cx + x, cy + y) for x, y in e]))
    cv.outline(m, 2.0, DARK_GOLD)
    cv.outline(m, 1.1, hx("e2a23d"))
    cv.grad(m, hx("ffffff"), hx("ddd5ca"))
    cv.bevel(m, (255, 255, 255, 255), hx("a89c8c"), 1.2, 0.5)
    verm = hx("d63a2a")
    for sx in (-1, 1):
        ie = cv.poly([(cx + sx * 17.5, cy - 11), (cx + sx * 18, cy - 27), (cx + sx * 9, cy - 12)])
        cv.grad(ie, hx("f06a4a"), hx("9a1e12"))
        # slanted eye marking
        eye = cv.poly([(cx + sx * 4, cy + 1), (cx + sx * 10, cy - 4), (cx + sx * 17, cy - 5), (cx + sx * 12, cy + 1.5)])
        cv.fill(eye, verm)
        cv.fill(cv.poly([(cx + sx * 7, cy + 0.2), (cx + sx * 11, cy - 2.5), (cx + sx * 13.5, cy - 2.8), (cx + sx * 11, cy)]), hx("2a0806"))
        # cheek whisker marks
        for k in range(2):
            wk = cv.poly([(cx + sx * 11, cy + 8 + k * 4), (cx + sx * 19, cy + 5 + k * 5), (cx + sx * 18.5, cy + 7 + k * 5),
                          (cx + sx * 11, cy + 9.5 + k * 4)])
            cv.fill(wk, verm)
    # forehead jewel: a flame-drop of fox fire
    drop = flame(cv, cx, cy - 2, 9, 6)
    cv.fill(drop, verm)
    cv.fill(cv.ellipse(cx, cy - 4.5, 1.4), hx("f0b84f"))
    # nose and mouth
    cv.fill(cv.poly([(cx - 3.2, cy + 23), (cx + 3.2, cy + 23), (cx, cy + 27)]), hx("2a0806"))
    cv.fill(cv.rrect(cx - 0.5, cy + 26, cx + 0.5, cy + 29, 0.4), hx("2a0806"))
    cv.save(os.path.join(out, "foxfire.png"))


# ------------------------------------------------------------------------------------------------- Ширин

def coin(cv, cx, cy, r, gem=None):
    c = cv.ellipse(cx, cy, r)
    cv.outline(c, max(0.6, r * 0.13), DARK_GOLD)
    cv.grad(c, GOLD_HI, GOLD_LO)
    cv.bevel(c, (255, 248, 214, 255), (92, 54, 12, 255), max(0.5, r * 0.12), 0.6)
    ring = ImageChops.subtract(cv.ellipse(cx, cy, r * 0.74), cv.ellipse(cx, cy, r * 0.62))
    cv.fill(ring, hx("8a5a14", 200))
    if gem:
        g = cv.ellipse(cx, cy, r * 0.42)
        cv.grad(g, hx(gem[0]), hx(gem[1]))
        cv.fill(cv.ellipse(cx - r * 0.14, cy - r * 0.16, r * 0.13), (255, 255, 255, 230))


def monisto(out):
    cv = Canvas(100, 124)
    cx, cy = 50, 42
    rays = cv.mask()
    n = 16
    for i in range(n):
        a = 2 * math.pi * i / n - math.pi / 2
        ln = 38 if i % 2 == 0 else 31
        w = 0.17
        rays = ImageChops.lighter(rays, cv.poly([(cx + math.cos(a - w) * 20, cy + math.sin(a - w) * 20),
                                                  (cx + math.cos(a) * ln, cy + math.sin(a) * ln),
                                                  (cx + math.cos(a + w) * 20, cy + math.sin(a + w) * 20)]))
    cv.outline(rays, 1.0, DARK_GOLD)
    cv.grad(rays, hx("ffe08a"), hx("c08a1e"))
    coin(cv, cx, cy, 23, ("4fd1c8", "0f5f5a"))
    # the coin necklace (монисто): a chain arc of small coins and one larger in the middle
    d = ImageDraw.Draw(cv.img)
    pts = []
    for i in range(41):
        t = i / 40
        x = 12 + 76 * t
        y = 82 + 22 * math.sin(math.pi * t)
        pts.append((x * SS, y * SS))
    d.line(pts, fill=hx("8a5a14"), width=int(1.4 * SS), joint="curve")
    for i in range(9):
        t = (i + 0.5) / 9
        x = 12 + 76 * t
        y = 82 + 22 * math.sin(math.pi * t)
        if i == 4:
            continue
        coin(cv, x, y + 4.5, 4.2)
    coin(cv, 50, 111, 7.5, ("4fd1c8", "0f5f5a"))
    cv.save(os.path.join(out, "monisto.png"))


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    crimson_moon(out)
    sugar_lace(out)
    foxfire(out)
    monisto(out)


if __name__ == "__main__":
    main()
