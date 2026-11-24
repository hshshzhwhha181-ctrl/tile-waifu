#!/usr/bin/env python3
"""Cut the Higgsfield art of the «Лаковая сказка» HUD skin (Злата) into game textures.

    python3 -I prep_zlata.py <raw_dir> <loading_src.webp> <out_dir>

raw_dir holds the downloads named by role (window.png, plate.png, ... see JOBS in the README).
Every texture is @2x of its on-screen size (HUD_V2 §2.4); skin_nine draws it at scale 0.5.
Writes <out_dir>/nine.json with the patch margins the skin data reads.
"""
import json
import os
import sys

from PIL import Image


def crop_alpha(im, pad=4):
    if im.mode != "RGBA":
        return im
    bb = im.getchannel("A").point(lambda a: 255 if a > 10 else 0).getbbox()
    if not bb:
        return im
    l, t, r, b = bb
    return im.crop((max(0, l - pad), max(0, t - pad), min(im.width, r + pad), min(im.height, b + pad)))


def fit_h(im, h):
    w = max(1, round(im.width * h / im.height))
    return im.resize((w, h), Image.LANCZOS)


def fit_w(im, w):
    h = max(1, round(im.height * w / im.width))
    return im.resize((w, h), Image.LANCZOS)


def main():
    raw, loading_src, out = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    meta = {}

    def save(name, im, margins=None, lossy=False):
        path = os.path.join(out, name + (".webp" if lossy else ".png"))
        if lossy:
            im.convert("RGB").save(path, "WEBP", quality=90, method=6)
        else:
            im.save(path, optimize=True)
        meta[name] = {"file": os.path.basename(path), "size": [im.width, im.height]}
        if margins:
            meta[name]["margins"] = margins  # [left, top, right, bottom] in texture px

    def load(n):
        return Image.open(os.path.join(raw, n + ".png"))

    # window / sheet: square lacquer panel, ornament border ~9.5 % of the side
    w = load("window").convert("RGBA").resize((1024, 1024), Image.LANCZOS)
    save("window", w, [104, 104, 104, 104])

    # plates S/M/L: the bar is opaque edge to edge; only the ends carry ornament.
    # Vertical: no stretch (2 centre px), horizontal: centre strip stretches.
    p = load("plate").convert("RGBA")
    for cls, h in (("plate_s", 96), ("plate_m", 160), ("plate_l", 320)):
        im = fit_h(p, h)
        side = round(im.width * 0.12)
        save(cls, im, [side, h // 2 - 1, side, h // 2 - 1])

    # «Игра»: scarlet lacquer pill, @2x of 104
    b = fit_h(crop_alpha(load("btn_play")), 208)
    save("btn_play", b, [104, 103, 104, 103])
    # «Касса»: black lacquer with the one gold line, @2x of 80
    c = fit_h(crop_alpha(load("btn_cash")), 160)
    save("btn_cash", c, [48, 79, 48, 79])
    # secondary = plate_m (same lacquer); quiet / help disc = medallion
    m = crop_alpha(load("medallion"))
    save("medallion", m.resize((256, 256), Image.LANCZOS))
    # tab: firebird feather (vertical)
    f = crop_alpha(load("feather"))
    save("feather", fit_h(f, 256))
    save("feather_tile", fit_h(f, 112))
    # currency: flame ribbon, plain strip in the middle, @2x of 56
    cu = fit_h(crop_alpha(load("currency")), 128)
    end = round(cu.width * 0.24)
    save("currency", cu, [end, 63, end, 63])
    # header: only the ornament band of the bottom edge (rows 860..1120 of the 2688x1152 source). The centre feather
    # would collide with left-aligned titles, so the left 0..1200 px are mirrored into a symmetric vine border.
    src = load("header").convert("RGB")
    band = src.crop((0, 860, 1200, 1120))
    strip = Image.new("RGB", (2400, band.height))
    strip.paste(band, (0, 0))
    strip.paste(band.transpose(Image.FLIP_LEFT_RIGHT), (1200, 0))
    save("header", strip.resize((1440, round(band.height * 1440 / 2400)), Image.LANCZOS), lossy=True)
    # window corner ornament for the pen-stroke opening
    save("corner", crop_alpha(load("corner")).resize((256, 256), Image.LANCZOS))
    # menu background and lacquer-box table
    save("menu_bg", load("menu_bg").convert("RGB").resize((1080, 1910), Image.LANCZOS), lossy=True)
    save("table", load("table").convert("RGB").resize((1080, 1446), Image.LANCZOS), lossy=True)
    # loading: the approved wave-1 card (frontal on the terem gallery, POSES §16 pose 1)
    ld = Image.open(loading_src).convert("RGB")
    save("loading", fit_w(ld, 1020), lossy=True)

    with open(os.path.join(out, "nine.json"), "w", encoding="utf-8") as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=1, sort_keys=True)
    for k, v in sorted(meta.items()):
        print(k, v)


if __name__ == "__main__":
    main()
