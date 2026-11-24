#!/usr/bin/env python3
"""Draw the task rects of salon_data.gd over each zone's done | broken art (dev check of the masks).

    python3 rects.py <out_dir>        -> <out_dir>/rects_z1.png ... (1600x597: done left, broken right)
"""
import os, re, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, '..', '..', '..', '..'))
ART = os.path.join(GAME, 'assets', 'v10', 'salon')
src = open(os.path.join(HERE, '..', 'salon_data.gd'), encoding='utf-8').read()
cols = [(255, 80, 80), (80, 255, 80), (80, 160, 255), (255, 220, 60), (255, 80, 255), (60, 255, 255), (255, 150, 40)]
out_dir = sys.argv[1]
for z in ['z1', 'z2', 'z3']:
    m = re.search(r'"id": "%s".*?"tasks": \[(.*?)\n\t\t\],' % z, src, re.S)
    tasks = re.findall(r'"id": "(t\d)".*?"anchor": Vector2\(([\d.]+), ([\d.]+)\).*?"rects": \[(.*?)\]\]', m.group(1), re.S)
    out = Image.new('RGB', (1600, 597))
    for k, f in enumerate(['done', 'broken']):
        im = Image.open(os.path.join(ART, '%s_%s.webp' % (z, f))).convert('RGB').resize((800, 597))
        d = ImageDraw.Draw(im)
        for i, (tid, ax, ay, rs) in enumerate(tasks):
            for r in re.findall(r'\[?([\d.]+, [\d.]+, [\d.]+, [\d.]+)', rs):
                x, y, w, h = [float(v) for v in r.split(',')]
                d.rectangle([x * 800, y * 597, (x + w) * 800, (y + h) * 597], outline=cols[i % 7], width=3)
                d.text((x * 800 + 5, y * 597 + 3), tid, fill=cols[i % 7])
            d.ellipse([float(ax) * 800 - 6, float(ay) * 597 - 6, float(ax) * 800 + 6, float(ay) * 597 + 6], fill=cols[i % 7])
        out.paste(im, (k * 800, 0))
    out.save(os.path.join(out_dir, 'rects_%s.png' % z))
    print(z, len(tasks), 'tasks')
