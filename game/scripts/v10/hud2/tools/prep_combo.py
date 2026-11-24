#!/usr/bin/env python3
"""Prepare combo-showcase sprites (HUD_V2 §7.5) for the game.

  python3 -I prep_combo.py <src_dir> <dst_dir>

For each founder x tier: alpha < 8 -> 0 (generator noise), crop to the alpha>24 bbox, optimise PNG,
and write combo_meta.json with the crop, the face rect (x, y, w, h in CROPPED px) and the pose key.
Source face rects come from the art reports (mixed formats, normalised here; approximate, by eye).
"""
import json
import os
import sys

from PIL import Image

TIERS = {"x5": 1, "x10": 2, "x20": 3}
# hero -> tier key -> (pose key, job id, framing, face rect in ORIGINAL px as x, y, w, h)
SRC = {
    "mc": {
        "x5": ("edge-lean-tile-salute", "9b019f1b-53a2-42ee-bc16-6494aa25ec61", "knees", [580, 216, 341, 341]),
        "x10": ("slit-step-tail-lift", "2af597a2-a2e5-42e7-9016-5c0c90c77f61", "knees", [523, 204, 318, 318]),
        "x20": ("tile-fan-s-curve", "198295a0-84f5-4e15-ac1b-966a400825a5", "full", [557, 125, 250, 250]),
    },
    "rin": {
        "x5": ("glasses-dip-edge", "cd649614-7f2c-409c-9378-25957cab958b", "knees", [353, 200, 250, 260]),
        "x10": ("glasses-temple-lip-three-quarter", "02d088ef-0a97-4da6-b378-2f728a44a0ac", "full", [573, 120, 150, 220]),
        "x20": ("braid-release-s-curve", "cd258161-0fbc-4282-8d7c-7b06d4027e7f", "full", [553, 110, 160, 190]),
    },
    "hana": {
        "x5": ("edge-highfive-pop", "854cbeec-7e76-445f-9295-7986ab7ec137", "knees", [600, 180, 340, 320]),
        "x10": ("heel-flick-profile-hair-push", "d229b378-5d1d-4367-8ca9-f2d07af7e0ab", "full", [600, 180, 200, 200]),
        "x20": ("sunburst-stride", "3eaa7826-1ff0-46f5-9409-172aff392a28", "full", [720, 160, 320, 260]),
    },
    "yue": {
        "x5": ("fan-lower-reveal", "893c2d1d-9587-48d1-9ded-ef9adaf96866", "knees", [350, 150, 250, 300]),
        "x10": ("weightless-sleeve-arc-toe", "fd9b5150-c2ad-4867-aabf-8757cb857d4f", "full", [430, 180, 160, 170]),
        "x20": ("crescent-step-descent", "bd11d7f4-43a0-468e-a2cc-1fd6aa1a896e", "full", [400, 215, 160, 170]),
    },
    "nova": {
        "x5": ("glitch-headphone-tap", "347cbdfc-ce8d-4b7a-bab2-462a9afe1810", "knees", [482, 210, 309, 321]),
        "x10": ("bike-seat-lean-heel-lift", "63db0587-fccd-4783-aceb-01380242f176", "full", [692, 148, 297, 272]),
        "x20": ("holo-hip-drop-hand-in-hair", "c4097c91-40d2-4da3-a37f-c87d460be25d", "full", [581, 124, 309, 284]),
    },
}


def main(src, dst):
    os.makedirs(dst, exist_ok=True)
    meta = {"_doc": "HUD_V2 §7.5. crop = [x, y, w, h] of the cropped sprite inside the 2:3 source; face = [x, y, w, h] "
                    "in cropped px (approximate, by eye); framing knees = cut at the shin/calf (anchor bottom to the "
                    "screen edge), full = feet visible. All sprites face frame-left and enter from the right.",
            "sprites": {}}
    for hero, tiers in SRC.items():
        for tk, (pose, job, framing, face) in tiers.items():
            im = Image.open(os.path.join(src, f"{hero}_{tk}.png")).convert("RGBA")
            r, g, b, a = im.split()
            a = a.point(lambda v: 0 if v < 8 else v)
            im = Image.merge("RGBA", (r, g, b, a))
            x0, y0, x1, y1 = a.point(lambda v: 255 if v > 24 else 0).getbbox()
            if framing == "knees":  # the cut line stays exactly at the source bottom
                y1 = im.height
            crop = im.crop((x0, y0, x1, y1))
            name = f"{hero}_t{TIERS[tk]}.png"
            crop.save(os.path.join(dst, name), optimize=True)
            fx, fy, fw, fh = face
            meta["sprites"][f"{hero}_t{TIERS[tk]}"] = {
                "file": name, "hero": hero, "tier": TIERS[tk], "pose": f"combo{TIERS[tk]} {pose}", "job": job,
                "framing": framing, "src_size": [im.width, im.height], "crop": [x0, y0, x1 - x0, y1 - y0],
                "face": [fx - x0, fy - y0, fw, fh], "enter": "right",
            }
            print(name, crop.size, os.path.getsize(os.path.join(dst, name)))
    with open(os.path.join(dst, "combo_meta.json"), "w") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
