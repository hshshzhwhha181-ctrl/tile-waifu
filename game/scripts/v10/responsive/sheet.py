"""0.10 M0: contact sheets for layout_shots.sh — one JPEG per view with that view at every resolution side by side
(scaled to one height, labelled), so squashed art, gaps and overflow jump out. Usage: sheet.py <out dir>"""
import os, re, sys
from PIL import Image, ImageDraw

out = sys.argv[1]
res_dirs = sorted([d for d in os.listdir(out) if re.fullmatch(r"\d+x\d+", d)], key=lambda d: (int(d.split("x")[0]) * 10000 + int(d.split("x")[1])))
views = {}
for d in res_dirs:
    for f in os.listdir(os.path.join(out, d)):
        m = re.fullmatch(r"\d+_(.+)\.png", f)
        if m:
            views.setdefault(m.group(1), {})[d] = os.path.join(out, d, f)
os.makedirs(os.path.join(out, "sheets"), exist_ok=True)
H = 760
for v, files in sorted(views.items()):
    ims = []
    for d in res_dirs:
        if d in files:
            im = Image.open(files[d]).convert("RGB")
            k = H / im.size[1]
            ims.append((d, im.resize((max(1, int(im.size[0] * k)), H), Image.LANCZOS)))
    W = sum(i.size[0] for _, i in ims) + 10 * (len(ims) - 1)
    sh = Image.new("RGB", (W, H + 26), (30, 30, 34))
    dr = ImageDraw.Draw(sh)
    x = 0
    for d, im in ims:
        sh.paste(im, (x, 26))
        dr.text((x + 6, 6), "%s  %s" % (v, d), fill=(255, 230, 120))
        x += im.size[0] + 10
    sh.save(os.path.join(out, "sheets", v + ".jpg"), quality=84)
print("sheets: %d views x %d resolutions -> %s" % (len(views), len(res_dirs), os.path.join(out, "sheets")))
