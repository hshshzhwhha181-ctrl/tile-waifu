#!/usr/bin/env python3
"""w1_art_cards.py — wave-1 goddesses: outfit cards, base-outfit pose slots, emotion cut-outs + their measurements.

Tile Waifu 0.10, lane 4 (art-cards). Deterministic: the same sources give the same files.

    python3 game/scripts/v10/wave1/tools/w1_art_cards.py <source dir> <repo root> [options]

<source dir> holds  w1src/FINAL_<hero>.png, w1src/<hero>__<outfit>__card.png, w1src/<hero>__<base>__<slot>.png,
                    gen/emo/emo_<hero>_<emotion>.png (grey background), gen/sh_sun_pick.png (optional, pending audit)
Writes (repo root relative):
    game/assets/v10/wave1/outfits/<outfit>.webp      850×1280 RGB (q 88)
    game/assets/v10/wave1/poses/<hero>_<slot>.webp   height 1280 RGB (q 88); <hero>_idle = the FINAL card
    game/assets/v10/wave1/emotions/<hero>_<emo>.webp RGBA waist-up, height 800, ≤ 600 wide (founders' framing)
    game/core/wave1/data/w1_art_cards.json    measurements (merged: entries not rebuilt this run are kept)

Options
    --only KEY [KEY ...]   rebuild only these: outfit ids (tb_post), pose keys (tsubame_win), emotion keys
                           (emo:tsubame_happy or tsubame_happy), or a hero name (all of her files)
    --skip-emotions        cards and poses only (no rembg)
    --set SRC=elx,ely,erx,ery,mx,my[,fw[,waist]]   store face landmarks of a source (source px; eyes = iris centres,
                           mouth = closed-lip line) in w1_art_landmarks.json; fw (0 = default) defaults to 1.75 × eye
                           distance; waist = waist line y of an outfit card (alt_rect bottom)
    --reject KEY [KEY ...] mark the CURRENT file of an emotion (tsubame_sad) as failed by the audit: it is left out
                           (no webp, no json entry → the runtime falls back to her base art) until the file changes
    --measure SRC          write a gridded zoom of SRC's head (or the whole top) to --sheets (default <src>/measure)
    --sheets DIR           write check sheets (cut-outs on dark/light, edge zooms, rect overlays, face marks) to DIR
    --cache DIR            cache rembg masks by source sha1 (default: none)

Landmarks (w1_art_landmarks.json next to this script) are per SOURCE file and carry its sha1.
  cards / poses: a changed source keeps its webp but loses its rects until new landmarks are given (--set).
  emotions: a missing or rejected source is left out (webp + .import removed, json entry dropped); a new or
  regenerated source (sha1 differs) is built at once with provisional landmarks found by template matching against
  her audited emotions (≈ ±10 px), marked "measured": "auto" in the json and listed in _meta.emotions_auto —
  pin it with --set after a look at --measure / --sheets. Re-running after a regeneration therefore just works.
  Emotion crops never go below HIP_MAX (hip line, red line: no legwear tops / bare thigh in a slit).
Everything else is derived:

  face centre   = rig_face rule of V8Art: x = (el.x + er.x + 2 m.x) / 4, y = ((el.y + er.y) / 2 + m.y) / 2
  face width    = cheek to cheek at the eyes (cards: read on the art; emotions: 1.75 × eye distance, V8Art's mc/hana rule)
  face_rect     = V9Ults semantics: square head-and-shoulders box, side = 2.56 × face width (founders' cards measure
                  0.37–0.40 face widths per side), face centre at (50 %, 45 %) of it; kept inside the art
  alt_rect      = modest crop, 4:5, head to waist: top = face_rect.y − 0.2 side, centred on the face_rect,
                  height = to the measured waist line (landmark "waist", source px) or 1.75 side
  emotion       = isnet-anime matte refined against the flat grey backdrop (difference matte + colour
                  decontamination: no grey halo, hair gaps opened), detached specks dropped, framed like
                  assets/v08/emotions (top of the head to ~3.3 face widths below the face centre ≈ hips,
                  ≤ 0.75 × height wide, soft fade where the frame cuts hair/cloth), scaled to height 800;
                  json face = face centre as a fraction of the file, face_w = face width in file px
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

HEROES = ["tsubame", "miel", "kohaku", "shirin", "zlata"]
EMOTIONS = ["happy", "sad", "surprised", "pout", "shy"]
BASE = {"tsubame": "tb_base", "miel": "me_base", "kohaku": "ko_base", "shirin": "sh_base", "zlata": "zl_base"}
# outfit id -> (hero, source path relative to the source dir)
OUTFITS = [
	("tb_base", "tsubame", "w1src/FINAL_tsubame.png"),
	("tb_post", "tsubame", "w1src/tsubame__tb_post__card.png"),
	("tb_crimson", "tsubame", "w1src/tsubame__tb_crimson__card.png"),
	("me_base", "miel", "w1src/FINAL_miel.png"),
	("me_parlor", "miel", "w1src/miel__me_parlor__card.png"),
	("me_gala", "miel", "w1src/miel__me_gala__card.png"),
	("ko_base", "kohaku", "w1src/FINAL_kohaku.png"),
	("ko_matsuri", "kohaku", "w1src/kohaku__ko_matsuri__card.png"),
	("ko_kyubi", "kohaku", "w1src/kohaku__ko_kyubi__card.png"),
	("ko_vow", "kohaku", "w1src/kohaku__ko_vow__card.png"),
	("sh_base", "shirin", "w1src/FINAL_shirin.png"),
	("sh_oasis", "shirin", "w1src/shirin__sh_oasis__card.png"),
	("sh_sun", "shirin", "gen/sh_sun_pick.png"),
	("sh_night", "shirin", "w1src/shirin__sh_night__card.png"),
	("zl_base", "zlata", "w1src/FINAL_zlata.png"),
	("zl_fair", "zlata", "w1src/zlata__zl_fair__card.png"),
	("zl_ember", "zlata", "w1src/zlata__zl_ember__card.png"),
	("zl_vow", "zlata", "w1src/zlata__zl_vow__card.png"),
]

CARD_H = 1280
EMO_H = 800
EMO_MAX_ASPECT = 0.75            # founders' emotion files are ≤ 600×800
EMO_BELOW_FACE = 3.3             # crop bottom = face centre + 3.3 face widths (founders: 2.9–3.9, mean ≈ 3.3)
WEBP_Q = 88
FACE_RECT_K = 2.56               # face_rect side / face width
FACE_RECT_FY = 0.45              # face centre height inside face_rect
ALT_TOP = 0.2                    # alt_rect top above face_rect, in face_rect sides
ALT_H = 1.75                     # default alt_rect height, in face_rect sides
ALT_ASPECT = 0.8                 # alt_rect w / h (4:5)
FACE_MIN, FACE_MAX = 180, 480    # V9Ults selftest bounds of a face_rect side
# Red line (HEROINES §4 / audit rule 1): an emotion portrait ends at the hip — no legwear top and no bare thigh in a
# skirt slit may enter the frame. Lowest source row (gen/emo 880×1168) a crop may reach, per heroine, read on the art:
# tsubame — skirt slit opens ≈ 880, fishnet tops ≈ 1090; miel — corset/apron/skirt, nothing below to 1168;
# kohaku — hakama slit ≈ 980; shirin — hip belt ≈ 900–950, skirt slit below ≈ 980; zlata — slit from ≈ 910, lace ≈ 1030.
HIP_MAX = {"tsubame": 870, "miel": 1000, "kohaku": 950, "shirin": 960, "zlata": 860}

HERE = os.path.dirname(os.path.abspath(__file__))
LANDMARKS = os.path.join(HERE, "w1_art_landmarks.json")
OUT_ASSETS = "game/assets/v10/wave1"
OUT_JSON = "game/core/wave1/data/w1_art_cards.json"
RES = "res://assets/v10/wave1"

BG_DARK = (0x1d, 0x1b, 0x2e)
BG_LIGHT = (0xf6, 0xef, 0xe6)


def log(*a) -> None:
	print(*a, flush=True)


def sha1(path: str) -> str:
	h = hashlib.sha1()
	with open(path, "rb") as f:
		for chunk in iter(lambda: f.read(1 << 20), b""):
			h.update(chunk)
	return h.hexdigest()


# ------------------------------------------------------------------ landmarks

def load_landmarks() -> dict:
	if os.path.exists(LANDMARKS):
		with open(LANDMARKS, encoding="utf-8") as f:
			return json.load(f)
	return {"sources": {}}


def save_landmarks(lm: dict) -> None:
	keys = sorted(lm["sources"])
	lines = ["{", '"_doc": %s,' % json.dumps(lm.get("_doc", "")), '"sources": {']
	for i, k in enumerate(keys):
		lines.append("%s: %s%s" % (json.dumps(k), json.dumps(lm["sources"][k], ensure_ascii=False), "," if i < len(keys) - 1 else ""))
	lines += ["}", "}"]
	with open(LANDMARKS, "w", encoding="utf-8") as f:
		f.write("\n".join(lines) + "\n")


def face_of(L: dict) -> tuple[float, float, float]:
	"""(cx, cy, fw) in source px from landmarks {el, er, m, fw?}."""
	el, er, m = L["el"], L["er"], L["m"]
	cx = (el[0] + er[0] + 2.0 * m[0]) / 4.0
	cy = ((el[1] + er[1]) / 2.0 + m[1]) / 2.0
	fw = float(L.get("fw") or 1.75 * math.dist(el, er))
	return cx, cy, fw


def emo_state(lm: dict, rel: str, path: str) -> str:
	"""'missing' | 'rejected' (this exact file failed the audit) | 'measured' | 'auto' (new or regenerated file)."""
	if not os.path.exists(path):
		return "missing"
	L = lm["sources"].get(rel)
	if not L or (L.get("sha1") and L["sha1"] != sha1(path)):
		return "auto"
	if L.get("rejected"):
		return "rejected"
	return "measured" if "el" in L else "auto"


def _gray_grad(path: str) -> np.ndarray:
	a = np.asarray(Image.open(path).convert("RGB")).astype(np.float64) @ np.array([0.299, 0.587, 0.114])
	a = ndi.gaussian_filter(a, 1.0)
	return np.hypot(ndi.sobel(a, 0), ndi.sobel(a, 1))


def _ncc(img: np.ndarray, tpl: np.ndarray) -> np.ndarray:
	from scipy.signal import fftconvolve
	t = tpl - tpl.mean()
	tn = math.sqrt(float((t * t).sum())) or 1.0
	num = fftconvolve(img, t[::-1, ::-1], mode="valid")
	ones = np.ones_like(tpl)
	s1 = fftconvolve(img, ones, mode="valid")
	s2 = fftconvolve(img * img, ones, mode="valid")
	var = np.maximum(s2 - s1 * s1 / tpl.size, 1e-6)
	return num / (np.sqrt(var) * tn)


def auto_landmarks(path: str, refs: list) -> tuple[dict, float, str]:
	"""Provisional landmarks of a new/regenerated emotion: the face of the best-matching verified emotion of the same
	heroine (same framing) found by normalised cross-correlation of edge maps over position and scale. Leave-one-out on
	the audited set: ≈ 9 px mean / 22 px worst in source px — good enough not to break anything, NOT final: measure
	it (--measure) and pin it with --set."""
	T = _gray_grad(path)
	best = (-2.0, None, "")
	for rpath, L in refs:
		I = _gray_grad(rpath)
		cx, cy, fw = face_of(L)
		half = int(1.25 * fw / 2)
		tpl0 = I[int(cy) - half:int(cy) + half, int(cx) - half:int(cx) + half]
		for s in np.arange(0.84, 1.17, 0.04):
			sz = max(16, int(round(tpl0.shape[0] * s)))
			tpl = np.asarray(Image.fromarray(tpl0.astype(np.float32)).resize((sz, sz), Image.BILINEAR)).astype(np.float64)
			R = 170
			x0, y0 = max(0, int(cx - R - sz / 2)), max(0, int(cy - R - sz / 2))
			x1, y1 = min(T.shape[1], int(cx + R + sz / 2)), min(T.shape[0], int(cy + R + sz / 2))
			sub = T[y0:y1, x0:x1]
			if sub.shape[0] < sz or sub.shape[1] < sz:
				continue
			c = _ncc(sub, tpl)
			iy, ix = np.unravel_index(int(np.argmax(c)), c.shape)
			v = float(c[iy, ix])
			if v > best[0]:
				tcx, tcy, ss = x0 + ix + sz / 2.0, y0 + iy + sz / 2.0, sz / float(tpl0.shape[0])

				def tr(p, tcx=tcx, tcy=tcy, ss=ss, cx=cx, cy=cy):
					return [round(tcx + ss * (p[0] - cx), 1), round(tcy + ss * (p[1] - cy), 1)]

				best = (v, {"el": tr(L["el"]), "er": tr(L["er"]), "m": tr(L["m"])}, os.path.basename(rpath))
	return best[1], best[0], best[2]


def landmarks_for(lm: dict, rel: str, path: str, problems: list) -> dict | None:
	L = lm["sources"].get(rel)
	if L is None:
		problems.append("%s: no face landmarks — measure it (--measure %s --sheets DIR) and store them with --set" % (rel, rel))
		return None
	if L.get("sha1") and L["sha1"] != sha1(path):
		problems.append("%s: the source changed since its landmarks were measured — re-measure (--measure) and --set" % rel)
		return None
	return L


# ------------------------------------------------------------------ cards + poses

def save_webp_rgb(img: Image.Image, path: str) -> None:
	os.makedirs(os.path.dirname(path), exist_ok=True)
	img.convert("RGB").save(path, "WEBP", quality=WEBP_Q, method=6)


def scale_card(src: str) -> tuple[Image.Image, float]:
	im = Image.open(src).convert("RGB")
	k = CARD_H / im.height
	w = int(round(im.width * k))
	return im.resize((w, CARD_H), Image.LANCZOS), k


def clamp_rect(x: float, y: float, w: float, h: float, W: float, H: float) -> list[int]:
	w = min(w, W)
	h = min(h, H)
	x = min(max(0.0, x), W - w)
	y = min(max(0.0, y), H - h)
	return [int(round(x)), int(round(y)), int(round(w)), int(round(h))]


def card_rects(L: dict, k: float, W: int, H: int) -> dict:
	cx, cy, fw = face_of(L)
	cx, cy, fw = cx * k, cy * k, fw * k
	s = min(max(FACE_RECT_K * fw, FACE_MIN), FACE_MAX, W, H)
	s = float(int(round(s)))
	fr = clamp_rect(cx - s / 2.0, cy - FACE_RECT_FY * s, s, s, W, H)
	top = fr[1] - ALT_TOP * s
	if L.get("waist"):
		ah = float(L["waist"]) * k - top
	else:
		ah = ALT_H * s
	ah = max(ah, s * 1.3)
	aw = ah * ALT_ASPECT
	acx = fr[0] + fr[2] / 2.0
	ar = clamp_rect(acx - aw / 2.0, top, aw, ah, W, H)
	return {"face_rect": fr, "alt_rect": ar, "face_c": [round(cx, 1), round(cy, 1)], "face_w": round(fw, 1)}


# ------------------------------------------------------------------ emotion cut-out

_SESSIONS: dict = {}


def isnet_mask(img: Image.Image, src_sha: str, cache: str | None, model: str = "isnet-anime") -> np.ndarray:
	if cache:
		cp = os.path.join(cache, "%s_%s.png" % (model, src_sha))
		if os.path.exists(cp):
			return np.asarray(Image.open(cp).convert("L")).astype(np.float64) / 255.0
	from rembg import new_session, remove  # imported lazily: cards/poses do not need it
	if model not in _SESSIONS:
		_SESSIONS[model] = new_session(model)
	m = remove(img, session=_SESSIONS[model], only_mask=True, post_process_mask=False)
	if cache:
		os.makedirs(cache, exist_ok=True)
		m.save(cp)
	return np.asarray(m.convert("L")).astype(np.float64) / 255.0


def fit_background(C: np.ndarray, M: np.ndarray) -> np.ndarray:
	"""Smooth (quadratic) model of the flat grey backdrop, fitted on pixels the matte calls background."""
	h, w, _ = C.shape
	sel = ndi.binary_erosion(M < 0.02, iterations=6)
	ys, xs = np.nonzero(sel)
	if len(ys) < 500:
		return np.broadcast_to(np.median(C.reshape(-1, 3), 0), C.shape).copy()
	idx = np.linspace(0, len(ys) - 1, min(len(ys), 30000)).astype(int)
	ys, xs = ys[idx], xs[idx]

	def basis(x, y):
		x = x / w
		y = y / h
		return np.stack([np.ones_like(x), x, y, x * x, y * y, x * y], -1)

	X = basis(xs.astype(np.float64), ys.astype(np.float64))
	yy, xx = np.mgrid[0:h, 0:w]
	Xf = basis(xx.astype(np.float64), yy.astype(np.float64))
	B = np.empty_like(C)
	for c in range(3):
		coef, *_ = np.linalg.lstsq(X, C[ys, xs, c], rcond=None)
		B[..., c] = Xf @ coef
	return B


def refine_matte(C: np.ndarray, M: np.ndarray, B: np.ndarray, dbg: dict | None = None) -> tuple[np.ndarray, np.ndarray]:
	"""Alpha + decontaminated colour from the network matte M and the known backdrop B (all float, 0–255 / 0–1)."""
	h, w, _ = C.shape
	diff = C - B
	D = np.sqrt((diff ** 2).sum(-1))
	lum = C @ np.array([0.299, 0.587, 0.114])
	G = np.hypot(ndi.sobel(lum, 1), ndi.sobel(lum, 0)) / 8.0
	G = ndi.maximum_filter(G, 3)
	# backdrop-coloured and flat: the grey itself (also where the net filled a gap between strands)
	bglike = (D < 9.0) & (G < 5.0)
	lab, n = ndi.label(bglike)
	if n:
		area = ndi.sum(bglike, lab, np.arange(1, n + 1))
		keep = np.zeros(n + 1, bool)
		keep[1:] = area >= 10
		holes = keep[lab]
	else:
		holes = np.zeros_like(bglike)
	seeds_bg = (M < 0.02) | holes
	fg_sure = (M > 0.95) & (D > 14.0) & ~ndi.binary_dilation(seeds_bg, iterations=2)
	fg_sure = ndi.binary_erosion(fg_sure, iterations=1)
	# pixels the net dropped but that are clearly not the backdrop (glow, thin strands) and touch the figure
	lost = (M < 0.5) & (D > 24.0) & ~bglike
	if lost.any():
		lab2, n2 = ndi.label(lost, structure=np.ones((3, 3)))
		near = ndi.binary_dilation(M > 0.5, iterations=3)
		touch = np.zeros(n2 + 1, bool)
		touch[np.unique(lab2[near & lost])] = True
		touch[0] = False
		lost = touch[lab2]
	# narrow backdrop gaps between strands that the net filled: low-contrast "valleys" (much closer to the backdrop than
	# the strands around them) connected to the backdrop, or small enclosed pockets of almost exact backdrop colour
	gapc = (D < 24.0) & (ndi.maximum_filter(D, 5) > 2.5 * D + 20.0) & ~seeds_bg
	lab_g, n_g = ndi.label(gapc | seeds_bg, structure=np.ones((3, 3)))
	gaps = np.zeros_like(gapc)
	if n_g:
		touch = np.zeros(n_g + 1, bool)
		touch[np.unique(lab_g[seeds_bg])] = True
		touch[0] = False
		gaps = gapc & touch[lab_g]
	encl = gapc & ~gaps
	lab_e, n_e = ndi.label(encl, structure=np.ones((3, 3)))
	if n_e:
		idx = np.arange(1, n_e + 1)
		thick = ndi.maximum(ndi.distance_transform_edt(encl), lab_e, idx)
		area = ndi.sum(np.ones_like(D), lab_e, idx)
		ok = np.zeros(n_e + 1, bool)
		# almost exact backdrop pockets, or thin (≤ 5 px wide) backdrop-ish slits between strands
		ok[1:] = ((area >= 4) & (ndi.maximum(D, lab_e, idx) < 14.0)) | \
			((area >= 3) & (thick <= 2.5) & (ndi.mean(D, lab_e, idx) < 20.0))
		gaps |= ok[lab_e]
	if dbg is not None:
		dbg["gaps"] = gaps
	gaps_near = ndi.binary_dilation(gaps, iterations=1)
	fg_sure &= ~gaps_near
	dist_bg = ndi.distance_transform_edt(~seeds_bg)
	band = (dist_bg <= 4.0) & ~fg_sure & ~seeds_bg
	band |= lost
	band |= gaps_near & ~seeds_bg
	band |= (M > 0.02) & (M < 0.95) & ~seeds_bg
	# nearest sure-foreground colour (smoothed) for each band pixel
	wgt = ndi.gaussian_filter(fg_sure.astype(np.float64), 1.5)
	Fs = np.stack([ndi.gaussian_filter(C[..., c] * fg_sure, 1.5) for c in range(3)], -1) / np.maximum(wgt, 1e-6)[..., None]
	src_ok = wgt > 0.05
	_, (iy, ix) = ndi.distance_transform_edt(~src_ok, return_indices=True)
	Fn = Fs[iy, ix]
	v = Fn - B
	vv = (v ** 2).sum(-1)
	a_proj = np.clip((diff * v).sum(-1) / np.maximum(vv, 1e-6), 0.0, 1.0)
	# hard lower bound: the smallest alpha whose unmixed colour B + diff / alpha still fits in 0–255
	up = np.where(diff > 0, diff / np.maximum(255.0 - B, 1.0), 0.0)
	dn = np.where(diff < 0, -diff / np.maximum(B, 1.0), 0.0)
	a_min = np.clip(np.maximum(up, dn).max(-1), 0.0, 1.0)
	reliable = vv > 30.0 ** 2
	a_band = np.where(reliable, a_proj, np.where(lost, np.clip((D - 6.0) / 60.0, 0.0, 1.0), M))
	a_band = np.maximum(a_band, a_min)
	# a pixel that is plainly the backdrop colour is backdrop, whatever the net said
	a_band = np.where(D < 6.0, 0.0, a_band)
	alpha = np.where(fg_sure, 1.0, 0.0)
	alpha = np.where(band, a_band, alpha)
	# interior pixels the band did not reach keep the net's verdict
	rest = ~fg_sure & ~band & ~seeds_bg
	alpha = np.where(rest, (M > 0.5).astype(np.float64), alpha)
	alpha[seeds_bg] = 0.0
	# faint, backdrop-coloured haze away from any solid edge (defocused ghost strands / pearls painted into the grey)
	# reads as grey speckle on a dark UI: drop it; the anti-aliasing of real edges sits next to solid pixels and stays
	solid_near = ndi.binary_dilation(alpha >= 0.5, iterations=1)
	alpha = np.where((D < 16.0) & (alpha < 0.3) & ~solid_near, 0.0, alpha)
	alpha = np.where(alpha < 0.03, 0.0, alpha)
	alpha = np.where(alpha > 0.97, 1.0, alpha)
	# drop detached specks: components that are small, or small and backdrop-coloured
	on = alpha > 0.05
	lab3, n3 = ndi.label(on, structure=np.ones((3, 3)))
	if n3 > 1:
		area = ndi.sum(on, lab3, np.arange(1, n3 + 1))
		meanD = ndi.mean(D, lab3, np.arange(1, n3 + 1))
		big = area.max()
		drop = np.zeros(n3 + 1, bool)
		drop[1:] = (area < big) & ((area < 40) | ((area < 400) & (meanD < 30.0)))
		alpha[drop[lab3]] = 0.0
	# colour: unmix the backdrop out of every partly transparent pixel
	a3 = np.maximum(alpha, 1e-3)[..., None]
	F = B + diff / a3
	wmix = np.clip((alpha - 0.05) / 0.3, 0.0, 1.0)[..., None]
	F = wmix * F + (1.0 - wmix) * Fn
	F = np.where((alpha >= 1.0)[..., None], C, F)
	F = np.clip(F, 0.0, 255.0)
	if dbg is not None:
		dbg.update({"D": D, "holes": holes, "lost": lost, "band": band, "fg_sure": fg_sure})
	return alpha, F


def premult_resize(F: np.ndarray, A: np.ndarray, size: tuple[int, int]) -> Image.Image:
	"""Resize an RGBA float image with premultiplied alpha (no dark/grey fringes), back to straight alpha."""
	chans = []
	for c in range(3):
		chans.append(Image.fromarray((F[..., c] * A).astype(np.float32), "F").resize(size, Image.LANCZOS))
	a = Image.fromarray(A.astype(np.float32), "F").resize(size, Image.LANCZOS)
	an = np.clip(np.asarray(a), 0.0, 1.0)
	rgb = np.stack([np.asarray(ch) for ch in chans], -1) / np.maximum(an, 1e-4)[..., None]
	rgb = np.clip(rgb, 0, 255)
	# fill the colour under fully transparent pixels from the nearest visible one (clean filtering in Godot)
	vis = an > 0.02
	if vis.any() and (~vis).any():
		_, (iy, ix) = ndi.distance_transform_edt(~vis, return_indices=True)
		rgb = np.where(vis[..., None], rgb, rgb[iy, ix])
	out = np.dstack([rgb, an * 255.0]).round().astype(np.uint8)
	return Image.fromarray(out, "RGBA")


def frame_emotion(alpha: np.ndarray, face: tuple[float, float, float], fw_hero: float, hip_max: int) -> dict:
	"""Crop window (source px) in the founders' framing + the side fades."""
	h, w = alpha.shape
	cx, cy, fw = face
	on = alpha > 0.04
	rows = np.nonzero(on.any(1))[0]
	top = max(0, int(rows[0]) - 10) if len(rows) else 0
	bottom = int(round(cy + EMO_BELOW_FACE * fw_hero))
	bottom = min(h, max(bottom, int(cy + 2.0 * fw_hero)))
	if len(rows) and rows[-1] + 10 < bottom:
		bottom = int(rows[-1]) + 10
	bottom = min(bottom, hip_max)
	H = bottom - top
	wmax = int(math.floor(EMO_MAX_ASPECT * H))
	cols_mass = alpha[top:bottom].sum(0)
	cols = np.nonzero(cols_mass > 0.5)[0]
	lo = max(0, int(cols[0]) - 10) if len(cols) else 0
	hi = min(w, int(cols[-1]) + 11) if len(cols) else w
	if hi - lo <= wmax:
		x0, x1 = lo, hi
	else:
		cs = np.concatenate([[0.0], np.cumsum(cols_mass)])
		best, bx = -1.0, lo
		# the face stays in the middle 40–60 % … 30–70 % of the width
		xmin = int(math.ceil(cx - 0.62 * wmax))
		xmax = int(math.floor(cx - 0.38 * wmax))
		for x in range(max(lo, xmin, 0), min(hi - wmax, xmax, w - wmax) + 1):
			mass = cs[x + wmax] - cs[x]
			# prefer the face near the centre when two windows hold about the same art
			score = mass - abs((x + wmax / 2.0) - cx) * H * 0.02
			if score > best:
				best, bx = score, x
		if best < 0:
			bx = int(round(min(max(cx - wmax / 2.0, 0), w - wmax)))
		x0, x1 = bx, bx + wmax
	# fade a side where the window cuts the figure (not where the source frame already cut it: same look anyway)
	fades = []
	if x0 > 0 and alpha[top:bottom, x0].max() > 0.05:
		fades.append("l")
	if x1 < w and alpha[top:bottom, x1 - 1].max() > 0.05:
		fades.append("r")
	if x0 == 0 and alpha[top:bottom, 0].max() > 0.05:
		fades.append("l")
	if x1 == w and alpha[top:bottom, w - 1].max() > 0.05:
		fades.append("r")
	return {"box": (x0, top, x1, bottom), "fades": sorted(set(fades))}


def build_emotion(src: str, L: dict, fw_hero: float, cache: str | None, dbg: dict | None = None,
		hip_max: int = 10 ** 6) -> tuple[Image.Image, dict]:
	img = Image.open(src).convert("RGB")
	C = np.asarray(img).astype(np.float64)
	M = isnet_mask(img, sha1(src), cache)
	B = fit_background(C, M)
	alpha, F = refine_matte(C, M, B, dbg)
	face = face_of(L)
	fr = frame_emotion(alpha, face, fw_hero, hip_max)
	x0, y0, x1, y1 = fr["box"]
	A = alpha[y0:y1, x0:x1].copy()
	Fc = F[y0:y1, x0:x1]
	k = EMO_H / float(y1 - y0)
	ow = int(round((x1 - x0) * k))
	# side fades: 22 output px, smoothstep
	fpx = max(4, int(round(22 / k)))
	ramp = np.clip(np.arange(A.shape[1], dtype=np.float64) / fpx, 0, 1)
	ramp = ramp * ramp * (3 - 2 * ramp)
	if "l" in fr["fades"]:
		A *= ramp[None, :]
	if "r" in fr["fades"]:
		A *= ramp[::-1][None, :]
	out = premult_resize(Fc, A, (ow, EMO_H))
	cx, cy, fw = face
	meta = {"size": [ow, EMO_H], "face": [round(float((cx - x0) * k / ow), 4), round(float((cy - y0) * k / EMO_H), 4)],
		"face_w": round(float(fw * k), 1), "_box": [x0, y0, x1, y1], "_k": k, "_fades": fr["fades"]}
	if dbg is not None:
		dbg.update({"alpha": alpha, "F": F, "C": C, "M": M, "B": B})
	return out, meta


def save_webp_rgba(img: Image.Image, path: str) -> None:
	os.makedirs(os.path.dirname(path), exist_ok=True)
	img.save(path, "WEBP", quality=WEBP_Q, alpha_quality=100, method=6)


# ------------------------------------------------------------------ sheets

def _font():
	return ImageFont.load_default()


def on_backdrop(rgba: Image.Image, col) -> Image.Image:
	bg = Image.new("RGBA", rgba.size, col + (255,))
	bg.alpha_composite(rgba)
	return bg.convert("RGB")


def sheet_grid(tiles: list, cols: int, path: str) -> None:
	if not tiles:
		return
	tw = max(t.width for t in tiles)
	th = max(t.height for t in tiles)
	rows = (len(tiles) + cols - 1) // cols
	s = Image.new("RGB", (tw * cols, th * rows), (40, 40, 40))
	for i, t in enumerate(tiles):
		s.paste(t, ((i % cols) * tw, (i // cols) * th))
	s.save(path)


def measure_sheet(src_path: str, rel: str, out_dir: str, L: dict | None) -> str:
	im = Image.open(src_path).convert("RGB")
	if L:
		cx, cy, fw = face_of(L)
		win = int(fw * 1.6)
	else:
		cx, cy, win = im.width / 2, im.height * 0.25, int(min(im.width, im.height) * 0.5)
	x0, y0 = int(cx - win / 2), int(cy - win / 2)
	D = 900
	sc = D / win
	crop = im.crop((x0, y0, x0 + win, y0 + win)).resize((D, D), Image.LANCZOS).convert("RGBA")
	ov = Image.new("RGBA", (D, D))
	d = ImageDraw.Draw(ov)
	step = 10 if win <= 400 else 20
	for x in range((x0 // step + 1) * step, x0 + win, step):
		X = (x - x0) * sc
		mj = x % (5 * step) == 0
		d.line((X, 0, X, D), fill=(0, 255, 255, 140 if mj else 45))
		if mj:
			d.text((X + 2, 2), str(x), fill=(255, 255, 0, 255), font=_font())
	for y in range((y0 // step + 1) * step, y0 + win, step):
		Y = (y - y0) * sc
		mj = y % (5 * step) == 0
		d.line((0, Y, D, Y), fill=(0, 255, 255, 140 if mj else 45))
		if mj:
			d.text((2, Y + 2), str(y), fill=(255, 255, 0, 255), font=_font())
	if L:
		for p in (L["el"], L["er"]):
			X, Y = (p[0] - x0) * sc, (p[1] - y0) * sc
			d.ellipse((X - 8, Y - 8, X + 8, Y + 8), outline=(0, 255, 0, 255), width=2)
		X, Y = (L["m"][0] - x0) * sc, (L["m"][1] - y0) * sc
		d.line((X - 12, Y, X + 12, Y), fill=(255, 0, 255, 255), width=2)
	crop.alpha_composite(ov)
	os.makedirs(out_dir, exist_ok=True)
	out = os.path.join(out_dir, "measure_" + os.path.basename(rel).replace(".png", ".png"))
	crop.convert("RGB").save(out)
	return out


def edge_row(key: str, img: Image.Image, n: int = 4, c: int = 96, z: int = 3) -> Image.Image:
	"""The n crops with the most semi-transparent edge (hair strands, veils), each on the dark and the light backdrop."""
	A = np.asarray(img)[..., 3] / 255.0
	semi = ((A > 0.08) & (A < 0.92)).astype(np.float64)
	dens = ndi.uniform_filter(semi, c)
	dens[:c // 2, :] = 0
	dens[-c // 2:, :] = 0
	dens[:, :c // 2] = 0
	dens[:, -c // 2:] = 0
	tiles = []
	for _ in range(n):
		y, x = np.unravel_index(int(np.argmax(dens)), dens.shape)
		dens[max(0, y - c):y + c, max(0, x - c):x + c] = 0
		cr = img.crop((x - c // 2, y - c // 2, x + c // 2, y + c // 2)).resize((c * z, c * z), Image.NEAREST)
		tiles += [on_backdrop(cr, BG_DARK), on_backdrop(cr, BG_LIGHT)]
	row = Image.new("RGB", (c * z * len(tiles), c * z + 14), (60, 60, 60))
	for i, t in enumerate(tiles):
		row.paste(t, (i * c * z, 14))
	ImageDraw.Draw(row).text((4, 1), key, fill=(255, 255, 0), font=_font())
	return row


def rect_overlay(card: Image.Image, r: dict, label: str) -> Image.Image:
	im = card.convert("RGB").copy()
	d = ImageDraw.Draw(im)
	a = r["alt_rect"]
	f = r["face_rect"]
	d.rectangle((a[0], a[1], a[0] + a[2], a[1] + a[3]), outline=(0, 255, 255), width=4)
	d.rectangle((f[0], f[1], f[0] + f[2], f[1] + f[3]), outline=(255, 40, 40), width=4)
	cx, cy = r["face_c"]
	d.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), fill=(255, 255, 0))
	d.line((cx - r["face_w"] / 2, cy, cx + r["face_w"] / 2, cy), fill=(0, 255, 0), width=2)
	d.text((8, im.height - 20), label, fill=(255, 255, 0), font=_font())
	full = im.resize((int(im.width * 0.5), int(im.height * 0.5)), Image.LANCZOS)
	fc = card.convert("RGB").crop((f[0], f[1], f[0] + f[2], f[1] + f[3])).resize((full.width, full.width), Image.LANCZOS)
	t = Image.new("RGB", (full.width, full.height + full.width), (20, 20, 20))
	t.paste(full, (0, 0))
	t.paste(fc, (0, full.height))
	return t


# ------------------------------------------------------------------ main

def main() -> int:
	ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
	ap.add_argument("src")
	ap.add_argument("repo")
	ap.add_argument("--only", nargs="*", default=None)
	ap.add_argument("--skip-emotions", action="store_true")
	ap.add_argument("--set", action="append", default=[])
	ap.add_argument("--measure", action="append", default=[])
	ap.add_argument("--sheets", default=None)
	ap.add_argument("--cache", default=None)
	ap.add_argument("--reject", nargs="*", default=[])
	args = ap.parse_args()
	S = os.path.abspath(args.src)
	R = os.path.abspath(args.repo)
	lm = load_landmarks()

	for spec in args.set:
		rel, vals = spec.split("=", 1)
		v = [float(x) for x in vals.split(",")]
		if len(v) not in (6, 7, 8):
			log("--set needs 6, 7 or 8 numbers: %s" % spec)
			return 2
		entry = {"el": v[0:2], "er": v[2:4], "m": v[4:6], "sha1": sha1(os.path.join(S, rel))}
		if len(v) >= 7 and v[6] > 0:
			entry["fw"] = v[6]
		if len(v) == 8:
			entry["waist"] = v[7]
		lm["sources"][rel] = entry
		log("landmarks stored for", rel)
	for key in args.reject:
		key = key.replace("emo:", "")
		rel = "gen/emo/emo_%s.png" % key
		if not os.path.exists(os.path.join(S, rel)):
			log("--reject: no source", rel)
			return 2
		lm["sources"][rel] = {"rejected": True, "sha1": sha1(os.path.join(S, rel))}
		log("rejected (this exact file is never built):", rel)
	if args.set or args.reject:
		save_landmarks(lm)
	for rel in args.measure:
		out = measure_sheet(os.path.join(S, rel), rel, args.sheets or os.path.join(S, "measure"), lm["sources"].get(rel))
		log("measure sheet:", out)
	if args.measure and not args.only:
		return 0

	only = set(args.only) if args.only is not None else None

	def wanted(*keys) -> bool:
		if only is None:
			return True
		return any(k in only for k in keys)

	out_json = os.path.join(R, OUT_JSON)
	data = {}
	if os.path.exists(out_json):
		with open(out_json, encoding="utf-8") as f:
			data = json.load(f)
	for k in ("outfits", "emotions", "poses"):
		data.setdefault(k, {})
	problems: list[str] = []
	pending: list[str] = []
	sheets = args.sheets
	if sheets:
		os.makedirs(sheets, exist_ok=True)
	overlay_tiles = []

	# ---- outfit cards
	for oid, hero, rel in OUTFITS:
		if not wanted(oid, hero):
			continue
		path = os.path.join(S, rel)
		if not os.path.exists(path):
			pending.append(oid)
			problems.append("%s: source %s not found — skipped (pending)" % (oid, rel))
			continue
		card, k = scale_card(path)
		dst = os.path.join(R, OUT_ASSETS, "outfits", oid + ".webp")
		save_webp_rgb(card, dst)
		entry = {"file": "%s/outfits/%s.webp" % (RES, oid), "size": [card.width, card.height]}
		L = landmarks_for(lm, rel, path, problems)
		if L:
			r = card_rects(L, k, card.width, card.height)
			entry.update(r)
			if sheets:
				overlay_tiles.append(rect_overlay(card, r, oid))
		data["outfits"][oid] = entry
		log("outfit", oid, card.size, "ok" if L else "NO RECTS")
	data["outfits"] = {o: data["outfits"][o] for o, _, _ in OUTFITS if o in data["outfits"]}

	# ---- pose slots of the base outfits (+ idle = the FINAL card)
	src_dir = os.path.join(S, "w1src")
	pose_srcs = []
	for hero in HEROES:
		pose_srcs.append((hero, "idle", "w1src/FINAL_%s.png" % hero))
		for fn in sorted(os.listdir(src_dir)):
			pre = "%s__%s__" % (hero, BASE[hero])
			if fn.startswith(pre) and fn.endswith(".png"):
				pose_srcs.append((hero, fn[len(pre):-4], "w1src/" + fn))
	pose_tiles = []
	for hero, slot, rel in pose_srcs:
		key = "%s_%s" % (hero, slot)
		if not wanted(key, hero):
			continue
		path = os.path.join(S, rel)
		card, k = scale_card(path)
		save_webp_rgb(card, os.path.join(R, OUT_ASSETS, "poses", key + ".webp"))
		entry = {"file": "%s/poses/%s.webp" % (RES, key), "size": [card.width, card.height]}
		L = landmarks_for(lm, rel, path, problems)
		if L:
			r = card_rects(L, k, card.width, card.height)
			entry.update({"face_rect": r["face_rect"], "face_c": r["face_c"], "face_w": r["face_w"]})
			if sheets and slot != "idle":
				pose_tiles.append(rect_overlay(card, {**r, "alt_rect": r["face_rect"]}, key))
		data["poses"][key] = entry
		log("pose", key, card.size, "ok" if L else "NO RECT")
	order = ["%s_%s" % (h, s) for h, s, _ in pose_srcs]
	data["poses"] = {k: data["poses"][k] for k in sorted(data["poses"], key=lambda k: (order.index(k) if k in order else 999, k))}

	# ---- emotions: built from audited landmarks; a missing or rejected source leaves the emotion out (file and json),
	# so the runtime falls back to her base art; a new / regenerated source is measured provisionally (auto_landmarks)
	emo_tiles_dark, emo_tiles_light, emo_marks = [], [], []
	edge_rows = []
	emo_skipped, emo_auto = [], []
	if not args.skip_emotions:
		for hero in HEROES:
			refs = []
			for emo in EMOTIONS:
				rel = "gen/emo/emo_%s_%s.png" % (hero, emo)
				path = os.path.join(S, rel)
				if emo_state(lm, rel, path) == "measured":
					refs.append((path, lm["sources"][rel]))
			fw_hero = float(np.median([face_of(L)[2] for _, L in refs])) if refs else 0.0
			for emo in EMOTIONS:
				key = "%s_%s" % (hero, emo)
				if not wanted(key, "emo:" + key, hero):
					continue
				rel = "gen/emo/emo_%s.png" % key
				path = os.path.join(S, rel)
				state = emo_state(lm, rel, path)
				L = lm["sources"].get(rel) if state == "measured" else None
				if state == "auto":
					if refs:
						L, score, ref = auto_landmarks(path, refs)
						L["fw"] = float(fw_hero)
						emo_auto.append(key)
						problems.append("%s: new/regenerated source, face measured AUTOMATICALLY (match %.2f vs %s, ≈ ±10 px) — "
							"verify on the sheets, then pin it: --measure %s, --set %s=elx,ely,erx,ery,mx,my" % (key, score, ref, rel, rel))
					else:
						problems.append("%s: no audited emotion of %s to measure against — skipped" % (key, hero))
				if L is None:
					if state != "auto":
						problems.append("%s: %s — left out (runtime falls back to her base art)" % (key, "source not found" if state == "missing" else "rejected by the audit"))
					emo_skipped.append(key)
					data["emotions"].pop(key, None)
					for ext in (".webp", ".webp.import"):
						stale = os.path.join(R, OUT_ASSETS, "emotions", key + ext)
						if os.path.exists(stale):
							os.remove(stale)
							log("removed stale", stale)
					continue
				dbg = {} if sheets else None
				img, meta = build_emotion(path, L, fw_hero or face_of(L)[2], args.cache, dbg, HIP_MAX.get(hero, 10 ** 6))
				save_webp_rgba(img, os.path.join(R, OUT_ASSETS, "emotions", key + ".webp"))
				entry = {"file": "%s/emotions/%s.webp" % (RES, key), "size": meta["size"],
					"face": meta["face"], "face_w": meta["face_w"]}
				if state == "auto":
					entry["measured"] = "auto"
				data["emotions"][key] = entry
				log("emotion", key, meta["size"], "face", meta["face"], "w", meta["face_w"], "crop", meta["_box"],
					"fades", meta["_fades"], "(AUTO)" if state == "auto" else "")
				if sheets:
					t = img.resize((img.width // 2, img.height // 2), Image.LANCZOS)
					emo_tiles_dark.append(on_backdrop(t, BG_DARK))
					emo_tiles_light.append(on_backdrop(t, BG_LIGHT))
					mk = on_backdrop(img, BG_DARK if EMOTIONS.index(emo) % 2 == 0 else BG_LIGHT)
					d = ImageDraw.Draw(mk)
					fx, fy = meta["face"][0] * img.width, meta["face"][1] * img.height
					fwp = meta["face_w"]
					d.ellipse((fx - 5, fy - 5, fx + 5, fy + 5), fill=(255, 0, 0))
					d.line((fx - fwp / 2, fy, fx + fwp / 2, fy), fill=(0, 255, 0), width=3)
					d.text((6, 6), key + (" AUTO" if state == "auto" else ""), fill=(255, 0, 0), font=_font())
					emo_marks.append(mk.resize((mk.width // 2, mk.height // 2), Image.LANCZOS))
					edge_rows.append(edge_row(key, img))
		ek = {"%s_%s" % (h, e): i for i, (h, e) in enumerate([(h, e) for h in HEROES for e in EMOTIONS])}
		data["emotions"] = {k: data["emotions"][k] for k in sorted(data["emotions"], key=lambda k: ek.get(k, 999))}

	data["_meta"] = {
		"generator": "game/scripts/v10/wave1/tools/w1_art_cards.py",
		"outfits": "face_rect / alt_rect in px of the 850×1280 webp (V9Ults semantics: face_rect = head-and-shoulders "
			"square, face centre at 45 % of it; alt_rect = 4:5 head-to-waist modest crop); face_c / face_w = face centre "
			"(eyes-to-mouth middle) and cheek-to-cheek width in px",
		"poses": "face_rect in px of the pose webp (same rule); <hero>_idle is the base FINAL card",
		"emotions": "face = face centre as a fraction of the file (V8Art.EMO_FACE), face_w = face width in file px "
			"(V8Art.EMO_FACE_W, 1.75 × eye distance)",
		"pending": sorted(set(pending + [o for o, _, _ in OUTFITS if o not in data["outfits"]])),
		"emotions_missing": [k for k in ("%s_%s" % (h, e) for h in HEROES for e in EMOTIONS) if k not in data["emotions"]],
		"emotions_auto": [k for k, v in data["emotions"].items() if v.get("measured") == "auto"],
	}
	os.makedirs(os.path.dirname(out_json), exist_ok=True)
	with open(out_json, "w", encoding="utf-8") as f:
		json.dump(data, f, ensure_ascii=False, indent="\t")
		f.write("\n")
	log("json:", out_json)

	if sheets:
		for i in range(0, len(overlay_tiles), 6):
			sheet_grid(overlay_tiles[i:i + 6], 6, os.path.join(sheets, "rects_outfits_%d.png" % (i // 6)))
		for i in range(0, len(pose_tiles), 7):
			sheet_grid(pose_tiles[i:i + 7], 7, os.path.join(sheets, "rects_poses_%d.png" % (i // 7)))
		if emo_tiles_dark:
			sheet_grid(emo_tiles_dark, 5, os.path.join(sheets, "emo_dark.png"))
			sheet_grid(emo_tiles_light, 5, os.path.join(sheets, "emo_light.png"))
			for i in range(0, len(emo_marks), 10):
				sheet_grid(emo_marks[i:i + 10], 5, os.path.join(sheets, "emo_face_%d.png" % (i // 10)))
			for i in range(0, len(edge_rows), 4):
				sheet_grid(edge_rows[i:i + 4], 1, os.path.join(sheets, "emo_edges_%d.png" % (i // 4)))
	if problems:
		log("\nPROBLEMS:")
		for p in problems:
			log("  -", p)
	return 0


if __name__ == "__main__":
	sys.exit(main())
