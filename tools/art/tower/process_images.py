"""Turns the raw Higgsfield results into the game sizes (run in the Higgsfield sandbox, raw/*.png in cwd).

raw/icons.png  2336x1744 RGBA (4x3 medallions)  -> icons_sheet 640x480 (12 cells of 160, order = ICON_IDS)
raw/mid.png    672x2016 RGBA -> pagoda_mid 720x2400 (non-uniform: x1.071, y1.190, pagoda 11 % more slender)
raw/near.png   672x2016 RGBA -> pagoda_near 720x2400 (same stretch)
raw/far.png    672x2016 RGB  -> uniform x1.190 to 800x2400, centre crop 720 (the moon stays round)
raw/journey.png 864x1920 RGB -> 720x1600 (same 0.45 ratio)
Alpha layers: alpha < 8 dropped (invisible haze), colour under transparent pixels bled by push-pull
(cleaner edges, smaller files). Resizes of RGBA are premultiplied (no dark fringes).
"""
import numpy as np
from PIL import Image

ICON_IDS = ["shroud", "hourglass", "greedy", "narrow", "one_lamp", "no_ult", "no_undo", "no_hint",
	"no_shuffle", "fog", "guards", "heat"]


def rs(im, size):
	if im.mode == "RGBA":
		return im.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
	return im.resize(size, Image.LANCZOS)


def runs(v):
	r, on, s = [], False, 0
	for i, x in enumerate(v):
		if x and not on:
			s, on = i, True
		if not x and on:
			r.append((s, i - 1))
			on = False
	if on:
		r.append((s, len(v) - 1))
	return r


def icon_sheet(src):
	ic = Image.open(src).convert("RGBA")
	a = np.asarray(ic)[..., 3] > 8
	sheet = Image.new("RGBA", (640, 480), (0, 0, 0, 0))
	k = 0
	for (y0, y1) in runs(a.any(1)):
		for (x0, x1) in runs(a.any(0)):
			ys, xs = np.where(a[y0:y1 + 1, x0:x1 + 1])
			bx0, by0, bx1, by1 = x0 + xs.min(), y0 + ys.min(), x0 + xs.max() + 1, y0 + ys.max() + 1
			cx, cy = (bx0 + bx1) / 2, (by0 + by1) / 2
			side = max(bx1 - bx0, by1 - by0) * 160 / 156  # 2 px clear margin at 160
			box = (round(cx - side / 2), round(cy - side / 2), round(cx + side / 2), round(cy + side / 2))
			sheet.paste(rs(ic.crop(box), (160, 160)), ((k % 4) * 160, (k // 4) * 160))
			k += 1
	return sheet


def pushpull(rgb, w):
	levels = [(rgb * w[..., None], w)]
	c, ww = levels[0]
	while min(c.shape[:2]) > 2:
		h, wd = c.shape[:2]
		h2, w2 = h // 2 * 2, wd // 2 * 2
		c = c[:h2, :w2].reshape(h2 // 2, 2, w2 // 2, 2, 3).sum((1, 3))
		ww = ww[:h2, :w2].reshape(h2 // 2, 2, w2 // 2, 2).sum((1, 3))
		levels.append((c, ww))
	col = levels[-1][0] / np.maximum(levels[-1][1], 1e-6)[..., None]
	for c, ww in reversed(levels[:-1]):
		h, wd = ww.shape
		up = np.repeat(np.repeat(col, 2, 0), 2, 1)
		up = np.pad(up, ((0, max(0, h - up.shape[0])), (0, max(0, wd - up.shape[1])), (0, 0)), mode="edge")[:h, :wd]
		m = np.clip(ww, 0, 1)[..., None]
		col = (c / np.maximum(ww, 1e-6)[..., None]) * m + up * (1 - m)
	return col


def clean_alpha(im):
	a = np.asarray(im).astype(np.float32)
	al = a[..., 3].copy()
	al[al < 8] = 0
	opaque = al >= 250
	fill = pushpull(a[..., :3] / 255.0, opaque.astype(np.float32))
	rgb = np.where(opaque[..., None], a[..., :3] / 255.0, fill)
	semi = (al > 0) & (al < 250)
	rgb[semi] = a[..., :3][semi] / 255.0
	return Image.fromarray(np.dstack([np.clip(rgb * 255 + 0.5, 0, 255), al]).astype(np.uint8), "RGBA")


if __name__ == "__main__":
	icon_sheet("raw/icons.png").save("icons_sheet.png")
	clean_alpha(rs(Image.open("raw/mid.png").convert("RGBA"), (720, 2400))).save("pagoda_mid.png")
	clean_alpha(rs(Image.open("raw/near.png").convert("RGBA"), (720, 2400))).save("pagoda_near.png")
	far = Image.open("raw/far.png").convert("RGB").resize((800, 2400), Image.LANCZOS).crop((40, 0, 760, 2400))
	far.save("pagoda_far.webp", "WEBP", quality=95, method=6)
	Image.open("raw/journey.png").convert("RGB").resize((720, 1600), Image.LANCZOS).save(
		"journey_far.webp", "WEBP", quality=95, method=6)
	# locally: cut icons_sheet into curses/<id>.png (row-major ICON_IDS), pagoda_mid/near -> PNG RGBA
