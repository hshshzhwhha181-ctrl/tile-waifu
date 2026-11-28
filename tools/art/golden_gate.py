#!/usr/bin/env python3
"""P50: measurable parts of the GDD 11.4 'Single style' gate for the golden composites.

usage: golden_gate.py PICKS_DIR [--landmarks FILE] [-o OUT.json]
  PICKS_DIR holds <heroine>_<scene>_1k.png (heroine in mc|yue|nova).
Measures per frame (HSV, whole frame, background of the same hue counts against the heroine = strict):
  accent_pct (strict mask, verdict) / accent_loose_pct  area share of the heroine accent hue (mc: pink hair #ff8fb8; yue: lavender #c8b6ff; nova: neon cyan+magenta)
  gold_pct    area share of saturated gold (hue 36-55 deg, s>0.28, v>0.45)
  heads       (crown_y -> sole_y) / head height, from --landmarks {frame: {crown, chin, sole}} (pixel y); frames
              without a sole landmark (figure cropped at thigh/knee) are reported as null = not measurable.
Criteria: accent <= 20%, heads 7.0-7.5 (tolerance +-0.4 because landmarks are hand-placed on 1344 px frames).
"""
import argparse, glob, json, os, colorsys
import numpy as np
from PIL import Image

def hsv(path, scale=4):
    im = Image.open(path).convert('RGB')
    im = im.resize((im.width // scale, im.height // scale), Image.BILINEAR)
    return np.asarray(im.convert('HSV')).astype(np.float32)

# two definitions: strict = clearly saturated accent pixels; loose = whole hue family incl. hazy/dark tints
# (the gate verdict uses STRICT; loose is an upper bound that also counts haze, dark wood and background tints)
TH = {'strict': {'mc': (0.22, 0.45), 'yue': (0.15, 0.45), 'nova': (0.5, 0.6)},
      'loose':  {'mc': (0.12, 0.30), 'yue': (0.10, 0.30), 'nova': (0.30, 0.40)}}

def accent_mask(h, who, mode='strict'):
    H, S, V = h[..., 0] * 360 / 255, h[..., 1] / 255, h[..., 2] / 255
    s, v = TH[mode][who]
    if who == 'mc':     # sakura pink hair; skin (hue 10-35) excluded
        hue = (H >= 325) | (H <= 5)
    elif who == 'yue':  # lavender / violet
        hue = (H >= 245) & (H <= 290)
    elif who == 'nova':  # neon cyan + magenta
        hue = ((H >= 170) & (H <= 200)) | ((H >= 295) & (H <= 335))
    else:
        raise ValueError(who)
    return hue & (S > s) & (V > v)

def gold_mask(h):
    H, S, V = h[..., 0] * 360 / 255, h[..., 1] / 255, h[..., 2] / 255
    return (H >= 36) & (H <= 55) & (S > 0.28) & (V > 0.45)

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('picks'); ap.add_argument('--landmarks'); ap.add_argument('-o', '--out')
    a = ap.parse_args()
    lm = json.load(open(a.landmarks)) if a.landmarks else {}
    out = {}
    for f in sorted(glob.glob(os.path.join(a.picks, '*_1k.png'))):
        key = os.path.basename(f)[:-7]
        who = key.split('_')[0]
        h = hsv(f)
        r = {'accent_pct': round(100 * accent_mask(h, who, 'strict').mean(), 1),
             'accent_loose_pct': round(100 * accent_mask(h, who, 'loose').mean(), 1), 'gold_pct': round(100 * gold_mask(h).mean(), 2),
             'heads': None}
        L = lm.get(key)
        if L and L.get('sole'):
            head = L['chin'] - L['crown']
            r['heads'] = round((L['sole'] - L['crown']) / head, 2)
        r['accent_ok'] = bool(r['accent_pct'] <= 20.0)
        r['heads_ok'] = None if r['heads'] is None else bool(6.6 <= r['heads'] <= 7.9)
        out[key] = r
    txt = json.dumps(out, indent=1)
    if a.out: open(a.out, 'w').write(txt)
    print(txt)

if __name__ == '__main__':
    main()
