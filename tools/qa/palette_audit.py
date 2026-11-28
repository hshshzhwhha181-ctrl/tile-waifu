#!/usr/bin/env python3
"""palette_audit.py - "does this image live in the Tile Waifu palette?"  (design/specs/UNIFIED_QA_PLAN.md section 2)

For every PNG/WEBP/JPG given (files or directories, recursive):
  1. load, drop transparent pixels (alpha < 0.5), box-downscale to --max-side, convert to CIELAB
  2. deterministic weighted k-means++ (seed 7) -> k dominant colours with area shares
  3. CIEDE2000 distance of every cluster to the nearest colour of design/specs/palette_ramps.json
  4. PASS / WARN / FAIL by the image's PROFILE (chrome | icon | fx | art, picked by path rules in the ramps file)
Outputs a per-image line, a per-category drift summary and (with --json) the full machine report.

  python tools/qa/palette_audit.py game/assets/ui game/assets/icons --json /tmp/pal.json
  python tools/qa/palette_audit.py shot.png --profile chrome --hero yue --theme MOON --verbose
  python tools/qa/palette_audit.py game/assets --write-baseline tools/qa/palette_baseline.json   # freeze today's numbers
  python tools/qa/palette_audit.py game/assets --baseline tools/qa/palette_baseline.json         # ratchet: worse than baseline = FAIL

Exit code: 0 = no FAIL (and no WARN with --fail-on-warn), 1 = FAIL found, 2 = usage / I/O error.
Needs numpy + Pillow. Thresholds are in the ramps file ("profiles") and are [ГИПОТЕЗА] until calibrated on approved art.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import colorlib as cl  # noqa: E402

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    print("palette_audit.py needs Pillow (pip install pillow)", file=sys.stderr)
    raise SystemExit(2)

REPO = Path(__file__).resolve().parents[2]
DEFAULT_RAMPS = REPO / "design" / "specs" / "palette_ramps.json"
EXTS = {".png", ".webp", ".jpg", ".jpeg"}
SEED = 7
MAX_FIT_PIXELS = 12000
EDGE_GROW = 2


# ---------------------------------------------------------------------------------------------
# palette
# ---------------------------------------------------------------------------------------------
class Palette:
    def __init__(self, doc: dict, repo_only: bool = False, hero: str | None = None, theme: str | None = None):
        self.doc = doc
        names, labs, meta = [], [], []
        for name, e in doc["colors"].items():
            if repo_only and e["status"] != "repo":
                continue
            if hero and e["kind"] == "hero" and e["family"] != "HERO_" + hero.upper():
                continue
            if theme and e["kind"] == "theme" and not (e["family"] == "THEME_" + theme.upper()
                                                       or (theme.upper() == "NEON" and e["family"] == "THEME_NEON2")):
                continue
            if (hero or theme) and e["kind"] == "theme" and not theme:
                continue
            names.append(name)
            labs.append(cl.hex_to_lab(e["hex"]))
            meta.append(e)
        if not names:
            raise ValueError("palette is empty after filters")
        self.names, self.meta = names, meta
        self.lab = np.array(labs)
        self.profiles = doc["profiles"]
        self.rules = [(re.compile(r[0]) if r[0] else None, r[1], r[2]) for r in doc["category_rules"]]

    def nearest(self, lab: np.ndarray):
        """lab (n,3) -> (idx (n,), de (n,))"""
        d = cl.delta_e2000(lab[:, None, :], self.lab[None, :, :])
        idx = np.argmin(d, axis=1)
        return idx, d[np.arange(len(lab)), idx]

    def categorize(self, rel_posix: str):
        for rx, cat, prof in self.rules:
            if rx is None or rx.search(rel_posix):
                return cat, prof
        return "other", "art"


def load_palette(path: Path | str = DEFAULT_RAMPS, **kw) -> Palette:
    return Palette(json.loads(Path(path).read_text(encoding="utf-8")), **kw)


# ---------------------------------------------------------------------------------------------
# image -> clusters
# ---------------------------------------------------------------------------------------------
def load_pixels(path: Path, max_side: int = 256, flat_tol: float | None = None):
    """-> (rgb float (n,3), n_opaque, (w,h)). Transparent pixels (alpha<0.5) are ignored; colours are NOT premultiplied.
    flat_tol (e.g. 0.04): additionally drop EDGE pixels (any 4-neighbour differs by more than flat_tol in some channel or is
    transparent) = anti-aliasing and lossy-compression ringing, which are blends and not 'colours'. Falls back to all opaque
    pixels when fewer than 25 % would remain (painted/textured art)."""
    with Image.open(path) as im:
        im.load()
        size = im.size
        im = im.convert("RGBA")
        w, h = im.size
        if max(w, h) > max_side:
            s = max_side / max(w, h)
            im = im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.BOX)
        a = np.asarray(im, dtype=np.float64) / 255.0
    opaque = a[..., 3] >= 0.5
    n_op = int(opaque.sum())
    keep = opaque
    if flat_tol and n_op:
        pad = np.pad(a[..., :3], ((1, 1), (1, 1), (0, 0)), mode="edge")
        opad = np.pad(opaque, 1, mode="edge")
        flat = np.ones(opaque.shape, dtype=bool)
        H, W = opaque.shape
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nb = pad[1 + dy:1 + dy + H, 1 + dx:1 + dx + W]
            flat &= (np.abs(nb - a[..., :3]).max(axis=2) <= flat_tol) & opad[1 + dy:1 + dy + H, 1 + dx:1 + dx + W]
        edge = ~flat & opaque
        for _ in range(EDGE_GROW):      # lossy ringing / chroma bleed reaches a few pixels past the edge
            e2 = edge.copy()
            e2[1:, :] |= edge[:-1, :]
            e2[:-1, :] |= edge[1:, :]
            e2[:, 1:] |= edge[:, :-1]
            e2[:, :-1] |= edge[:, 1:]
            edge = e2
        trimmed = opaque & ~edge
        if trimmed.sum() >= 0.25 * n_op:
            keep = trimmed
    return a[keep][:, :3], n_op, size


def _kmeans_pp(x: np.ndarray, k: int, rng: np.random.RandomState) -> np.ndarray:
    n = len(x)
    cent = [x[rng.randint(n)]]
    d2 = ((x - cent[0]) ** 2).sum(1)
    for _ in range(1, k):
        tot = d2.sum()
        if tot <= 1e-12:
            break
        c = x[np.searchsorted(np.cumsum(d2) / tot, rng.rand())] if tot > 0 else x[rng.randint(n)]
        cent.append(c)
        d2 = np.minimum(d2, ((x - c) ** 2).sum(1))
    return np.array(cent)


def kmeans_lab(lab: np.ndarray, k: int, seed: int = SEED, iters: int = 14):
    """Deterministic k-means in Lab. Returns (centroids (m,3), share (m,)), sorted by share desc, m <= k."""
    n = len(lab)
    if n == 0:
        return np.zeros((0, 3)), np.zeros(0)
    rng = np.random.RandomState(seed)
    fit = lab if n <= MAX_FIT_PIXELS else lab[rng.choice(n, MAX_FIT_PIXELS, replace=False)]
    cent = _kmeans_pp(fit, min(k, len(fit)), rng)
    for _ in range(iters):
        lab_ = ((fit[:, None, :] - cent[None, :, :]) ** 2).sum(2).argmin(1)
        new = cent.copy()
        for j in range(len(cent)):
            m = lab_ == j
            if m.any():
                new[j] = fit[m].mean(0)
        if np.allclose(new, cent, atol=1e-4):
            cent = new
            break
        cent = new
    assign = ((lab[:, None, :] - cent[None, :, :]) ** 2).sum(2).argmin(1) if n * len(cent) < 4_000_000 else \
        np.concatenate([((lab[i:i + 20000, None, :] - cent[None, :, :]) ** 2).sum(2).argmin(1) for i in range(0, n, 20000)])
    cnt = np.bincount(assign, minlength=len(cent)).astype(np.float64)
    keep = cnt > 0
    sums = np.zeros_like(cent)
    np.add.at(sums, assign, lab)   # final centroid = exact mean of ALL member pixels (not only the fit subsample)
    cent = sums[keep] / cnt[keep][:, None]
    cnt = cnt[keep]
    order = np.argsort(-cnt, kind="stable")
    return cent[order], cnt[order] / cnt.sum()


def consolidate(cent: np.ndarray, share: np.ndarray, merge_de: float = 2.0, bridge_de: float = 3.0):
    """Clean the raw k-means result: (1) merge clusters closer than merge_de dE00 (weighted mean);
    (2) drop 'bridge' clusters = anti-aliasing / lossy ringing blends that lie within bridge_de of the Lab segment between two
    clusters that are each >= 3x bigger. Returns (cent, share renormalised, bridge_share_pct)."""
    cent, share = cent.copy(), share.copy()
    merged = True
    while merged and len(cent) > 1:
        merged = False
        for i in range(len(cent)):
            for j in range(i + 1, len(cent)):
                if float(cl.delta_e2000(cent[i], cent[j])) < merge_de:
                    w = share[i] + share[j]
                    cent[i] = (cent[i] * share[i] + cent[j] * share[j]) / w
                    share[i] = w
                    cent, share = np.delete(cent, j, 0), np.delete(share, j)
                    merged = True
                    break
            if merged:
                break
    drop, bridge = [], 0.0
    for c in range(len(cent)):
        big = [i for i in range(len(cent)) if i != c and share[i] >= 3 * share[c]]
        hit = False
        for ai, a in enumerate(big):
            for b in big[ai + 1:]:
                ab = cent[b] - cent[a]
                t = float(np.clip(np.dot(cent[c] - cent[a], ab) / max(1e-9, np.dot(ab, ab)), 0, 1))
                if 0.02 < t < 0.98 and float(cl.delta_e2000(cent[c], cent[a] + t * ab)) <= bridge_de:
                    hit = True
        if hit:
            drop.append(c)
            bridge += share[c]
    if drop and len(drop) < len(cent):
        keep = [i for i in range(len(cent)) if i not in drop]
        cent, share = cent[keep], share[keep] / share[keep].sum()
    order = np.argsort(-share, kind="stable")
    return cent[order], share[order], round(float(bridge * 100), 2)


def gold_band_share(rgb: np.ndarray) -> float:
    if len(rgb) == 0:
        return 0.0
    lch = cl.rgb_to_oklch(rgb)
    m = (lch[:, 2] >= 70) & (lch[:, 2] <= 98) & (lch[:, 1] >= 0.07) & (lch[:, 0] >= 0.60)
    return float(m.mean() * 100.0)


# ---------------------------------------------------------------------------------------------
# one image
# ---------------------------------------------------------------------------------------------
def audit_image(path: Path, pal: Palette, rel: str, profile: str | None = None, category: str | None = None,
                max_side: int = 256, seed: int = SEED) -> dict:
    cat, prof = pal.categorize(rel)
    if category:
        cat = category
    if profile:
        prof = profile
    P = pal.profiles[prof]
    rec = {"path": rel, "category": cat, "profile": prof, "verdict": "PASS", "reasons": [], "clusters": [], "metrics": {}}
    try:
        rgb, n_op, size = load_pixels(path, max_side, P.get("flat_tol"))
    except Exception as e:  # unreadable file is a FAIL, never a crash of the whole run
        rec.update(verdict="FAIL", reasons=[f"unreadable: {type(e).__name__}: {e}"])
        return rec
    rec["size"] = list(size)
    rec["opaque_px"] = n_op
    rec["audited_px"] = int(len(rgb))
    if n_op == 0 or len(rgb) == 0:
        rec.update(verdict="WARN", reasons=["fully transparent image (nothing to audit)"])
        return rec
    # fixed-point colours: quantise to 8-bit so identical inputs give identical Lab
    lab = cl.rgb_to_lab(np.rint(rgb * 255) / 255)
    cent, share = kmeans_lab(lab, int(P["k"]), seed)
    cent, share, bridge_pct = consolidate(cent, share)
    idx, de = pal.nearest(cent)
    cent_rgb = cl.lab_to_rgb(cent)
    cent_lch = cl.rgb_to_oklch(cent_rgb)
    clusters = []
    for j in range(len(cent)):
        e = pal.meta[idx[j]]
        clusters.append({"hex": cl.rgb_to_hex(cent_rgb[j]), "share_pct": round(float(share[j] * 100), 2),
                         "nearest": pal.names[idx[j]], "nearest_hex": e["hex"], "nearest_status": e["status"],
                         "nearest_kind": e["kind"], "de": round(float(de[j]), 2),
                         "oklch": [round(float(v), 3) for v in cent_lch[j]]})
    rec["clusters"] = clusters
    sig = share * 100 >= 0.5
    w = share[sig] / share[sig].sum() if sig.any() else share
    mean_de = float((de[sig] * w).sum()) if sig.any() else float((de * share).sum())
    thr_in = float(P["warn_de"]) if P.get("warn_de") else 6.0
    coverage = float(share[de <= thr_in].sum() * 100)
    gold = gold_band_share(rgb)
    rec["metrics"] = {"mean_de": round(mean_de, 2), "coverage_pct": round(coverage, 1), "coverage_de": thr_in,
                      "worst_de": round(float(de[share * 100 >= P.get("min_area_pct", 1.5)].max()
                                              if (share * 100 >= P.get("min_area_pct", 1.5)).any() else de.max()), 2),
                      "gold_band_pct": round(gold, 2),
                      "mean_chroma_oklch": round(float((cent_lch[:, 1] * share).sum()), 3),
                      "bridge_pct": bridge_pct}
    verdict, reasons = "PASS", []

    def bump(v, why):
        nonlocal verdict
        if {"PASS": 0, "WARN": 1, "FAIL": 2}[v] > {"PASS": 0, "WARN": 1, "FAIL": 2}[verdict]:
            verdict = v
        reasons.append(f"{v}: {why}")

    if P["mode"] == "absolute":
        minA = float(P["min_area_pct"])
        for c in clusters:
            if c["share_pct"] < minA:
                continue
            if P.get("fail_de") is not None and c["de"] > P["fail_de"]:
                bump("FAIL", f"off-palette cluster {c['hex']} {c['share_pct']}% dE00={c['de']} > {P['fail_de']} (nearest {c['nearest']})")
            elif P.get("warn_de") is not None and c["de"] > P["warn_de"]:
                bump("WARN", f"drifting cluster {c['hex']} {c['share_pct']}% dE00={c['de']} > {P['warn_de']} (nearest {c['nearest']})")
        cap, capA = P.get("chroma_cap_oklch"), P.get("chroma_cap_min_area_pct", 1.0)
        for c in clusters:
            if cap and c["share_pct"] >= capA and c["oklch"][1] > cap and c["de"] > float(P["warn_de"] or 0) \
                    and c["nearest_kind"] not in ("brand", "rarity", "hero", "theme"):
                bump("WARN", f"loud colour {c['hex']} {c['share_pct']}% C={c['oklch'][1]} > {cap} outside brand/rarity/hero (PALETTE_LOCK A4)")
        if gold > float(P.get("gold_band_cap_pct", 100)):
            bump("WARN", f"gold-band area {gold:.1f}% > {P['gold_band_cap_pct']}% (PALETTE_LOCK A5; rarity components excluded only by the caller)")
    else:  # art: palette match is informative; only garish outliers are flagged
        gA, gC, gD = P["garish_min_area_pct"], P["garish_chroma_oklch"], P["garish_min_de"]
        for c in clusters:
            if c["share_pct"] >= gA and c["oklch"][1] > gC and c["de"] > gD:
                bump("WARN", f"garish colour {c['hex']} {c['share_pct']}% C={c['oklch'][1]} dE00={c['de']} to {c['nearest']}")
    rec["verdict"], rec["reasons"] = verdict, reasons
    return rec


# ---------------------------------------------------------------------------------------------
# runs: collect, relative drift, baseline, summary
# ---------------------------------------------------------------------------------------------
def collect(paths, exclude=()):
    files = []
    for p in paths:
        p = Path(p)
        if p.is_dir():
            files += sorted(f for f in p.rglob("*") if f.is_file() and f.suffix.lower() in EXTS)
        elif p.is_file():
            files.append(p)
        else:
            raise FileNotFoundError(str(p))
    rx = [re.compile(e) for e in exclude]
    return [f for f in files if not any(r.search(f.as_posix()) for r in rx)]


def rel_of(f: Path, root: Path = REPO) -> str:
    try:
        return f.resolve().relative_to(root).as_posix()
    except ValueError:
        return f.as_posix()


def mark_relative_outliers(recs, zmax=3.5, min_n=8):
    """Within a category, flag images whose mean_de is a robust outlier (MAD z-score) -> WARN (PASS only)."""
    by = {}
    for r in recs:
        if "mean_de" in r["metrics"]:
            by.setdefault(r["category"], []).append(r)
    for cat, rs in by.items():
        if len(rs) < min_n:
            continue
        v = np.array([r["metrics"]["mean_de"] for r in rs])
        med = float(np.median(v))
        mad = max(float(np.median(np.abs(v - med))), 0.3)   # floor: below ~0.3 dE00 'spread' is noise
        for r, x in zip(rs, v):
            z = 0.6745 * (x - med) / mad
            r["metrics"]["z_in_category"] = round(float(z), 2)
            if z > zmax and r["verdict"] == "PASS":
                r["verdict"] = "WARN"
                r["reasons"].append(f"WARN: outlier inside category '{cat}': mean dE00 {x:.1f} vs median {med:.1f} (z={z:.1f})")


def apply_baseline(recs, base: dict, tol_de=1.5, tol_cov=5.0):
    for r in recs:
        b = base.get("images", {}).get(r["path"])
        if not b or "mean_de" not in r["metrics"]:
            continue
        m = r["metrics"]
        if m["mean_de"] > b["mean_de"] + tol_de or m["coverage_pct"] < b["coverage_pct"] - tol_cov:
            r["verdict"] = "FAIL"
            r["reasons"].append(f"FAIL: ratchet - mean dE00 {m['mean_de']} (baseline {b['mean_de']}), coverage {m['coverage_pct']}% "
                                f"(baseline {b['coverage_pct']}%)")


def summarize(recs):
    cats = {}
    for r in recs:
        c = cats.setdefault(r["category"], {"n": 0, "PASS": 0, "WARN": 0, "FAIL": 0, "de": [], "cov": [], "profile": r["profile"]})
        c["n"] += 1
        c[r["verdict"]] += 1
        if "mean_de" in r["metrics"]:
            c["de"].append(r["metrics"]["mean_de"])
            c["cov"].append(r["metrics"]["coverage_pct"])
    out = {}
    for k, c in sorted(cats.items()):
        de, cov = np.array(c["de"] or [0.0]), np.array(c["cov"] or [0.0])
        bad = (c["WARN"] + c["FAIL"]) / max(1, c["n"])
        out[k] = {"profile": c["profile"], "n": c["n"], "PASS": c["PASS"], "WARN": c["WARN"], "FAIL": c["FAIL"],
                  "median_mean_de": round(float(np.median(de)), 2), "p90_mean_de": round(float(np.percentile(de, 90)), 2),
                  "median_coverage_pct": round(float(np.median(cov)), 1), "drift": "DRIFT" if bad > 0.25 else ("minor" if bad > 0 else "ok")}
    return out


def run(paths, ramps=DEFAULT_RAMPS, repo_only=False, hero=None, theme=None, profile=None, category=None, max_side=256,
        baseline=None, exclude=(), root: Path = REPO, relative=True, seed=SEED):
    pal = load_palette(ramps, repo_only=repo_only, hero=hero, theme=theme)
    files = collect(paths, exclude)
    recs = [audit_image(f, pal, rel_of(f, root), profile, category, max_side, seed) for f in files]
    if relative:
        mark_relative_outliers(recs)
    if baseline:
        apply_baseline(recs, json.loads(Path(baseline).read_text(encoding="utf-8")))
    cnt = {"PASS": 0, "WARN": 0, "FAIL": 0}
    for r in recs:
        cnt[r["verdict"]] += 1
    return {"tool": "palette_audit", "version": 1, "ramps": str(ramps), "palette_colors": len(pal.names),
            "options": {"repo_only": repo_only, "hero": hero, "theme": theme, "max_side": max_side, "seed": seed},
            "counts": cnt, "categories": summarize(recs), "images": recs}


def baseline_from(report: dict) -> dict:
    return {"_doc": "palette_audit ratchet baseline: an image may not get worse than this (tol 1.5 dE00 / 5 pts coverage)",
            "images": {r["path"]: {"mean_de": r["metrics"]["mean_de"], "coverage_pct": r["metrics"]["coverage_pct"]}
                       for r in report["images"] if "mean_de" in r["metrics"]}}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--ramps", default=str(DEFAULT_RAMPS))
    ap.add_argument("--profile", choices=["chrome", "icon", "fx", "art"], help="force a profile for every image")
    ap.add_argument("--category", help="force the category label")
    ap.add_argument("--hero", help="restrict hero ramps to this heroine id (e.g. yue)")
    ap.add_argument("--theme", help="restrict skin-theme ramps to this theme (e.g. MOON); without it themes are all allowed")
    ap.add_argument("--repo-only", action="store_true", help="ignore status=proposed/legacy colours (strict: only shipped tokens)")
    ap.add_argument("--max-side", type=int, default=256)
    ap.add_argument("--seed", type=int, default=SEED, help="k-means seed (default 7); sweep it to check clustering stability (hypothesis H2)")
    ap.add_argument("--exclude", action="append", default=[], help="regex on the path; repeatable")
    ap.add_argument("--json", help="write the full report here")
    ap.add_argument("--baseline", help="ratchet file written by --write-baseline")
    ap.add_argument("--write-baseline", help="write today's per-image numbers as the new baseline")
    ap.add_argument("--no-relative", action="store_true", help="skip the in-category outlier (MAD) check")
    ap.add_argument("--fail-on-warn", action="store_true")
    ap.add_argument("--quiet", action="store_true", help="print only non-PASS lines and the summary")
    ap.add_argument("--verbose", action="store_true", help="print clusters of every image")
    a = ap.parse_args(argv)
    try:
        rep = run(a.paths, a.ramps, a.repo_only, a.hero, a.theme, a.profile, a.category, a.max_side, a.baseline,
                  a.exclude, relative=not a.no_relative, seed=a.seed)
    except (FileNotFoundError, ValueError, json.JSONDecodeError) as e:
        print(f"palette_audit: {e}", file=sys.stderr)
        return 2
    for r in rep["images"]:
        if a.quiet and r["verdict"] == "PASS":
            continue
        m = r["metrics"]
        print(f"{r['verdict']:4} {r['category']:<11} {r['profile']:<6} dE={m.get('mean_de', '-'):>5} cov={m.get('coverage_pct', '-'):>5}%  {r['path']}")
        for why in r["reasons"] if r["verdict"] != "PASS" or a.verbose else []:
            print(f"       {why}")
        if a.verbose:
            for c in r["clusters"]:
                print(f"       {c['hex']} {c['share_pct']:5.1f}%  -> {c['nearest']:<22} dE={c['de']:5.2f} [{c['nearest_status']}]")
    print(f"\nPALETTE_AUDIT {rep['counts']['PASS']} PASS / {rep['counts']['WARN']} WARN / {rep['counts']['FAIL']} FAIL "
          f"of {len(rep['images'])} images, palette={rep['palette_colors']} colours")
    print(f"{'category':<12}{'profile':<7}{'n':>5}{'PASS':>6}{'WARN':>6}{'FAIL':>6}{'med dE':>8}{'p90 dE':>8}{'med cov%':>9}  drift")
    for k, c in rep["categories"].items():
        print(f"{k:<12}{c['profile']:<7}{c['n']:>5}{c['PASS']:>6}{c['WARN']:>6}{c['FAIL']:>6}{c['median_mean_de']:>8}"
              f"{c['p90_mean_de']:>8}{c['median_coverage_pct']:>9}  {c['drift']}")
    if a.json:
        Path(a.json).parent.mkdir(parents=True, exist_ok=True)
        Path(a.json).write_text(json.dumps(rep, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    if a.write_baseline:
        Path(a.write_baseline).write_text(json.dumps(baseline_from(rep), indent=1, sort_keys=True) + "\n", encoding="utf-8")
        print(f"baseline written: {a.write_baseline}")
    if rep["counts"]["FAIL"] or (a.fail_on_warn and rep["counts"]["WARN"]):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
