#!/usr/bin/env python3
"""Tile-back emblems of the V10TileTheme themes: crop to alpha, 112 px tall (@2x of the thumb / flip back).

    python3 -I prep_emblems.py <raw_dir> <out_dir>      raw_dir holds em_<name>.png
"""
import glob
import os
import sys

from PIL import Image


def main():
    raw, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    for f in sorted(glob.glob(os.path.join(raw, "em_*.png"))):
        im = Image.open(f).convert("RGBA")
        bb = im.getchannel("A").point(lambda a: 255 if a > 10 else 0).getbbox()
        if bb:
            im = im.crop(bb)
        h = 112
        im = im.resize((max(1, round(im.width * h / im.height)), h), Image.LANCZOS)
        name = os.path.basename(f)[3:]
        im.save(os.path.join(out, name), optimize=True)
        print(name, im.size)


if __name__ == "__main__":
    main()
