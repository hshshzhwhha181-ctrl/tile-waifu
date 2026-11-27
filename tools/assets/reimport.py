#!/usr/bin/env python3
"""Tile Waifu asset slimming, stage 1: rewrite Godot .import parameters (sources are NOT touched).

What it does (only edits `game/assets/**/*.import`, so it is reversible with `git checkout -- game/assets`):
  * texture importer: large art -> compress/mode=1 (lossy WebP in the .ctex) + compress/lossy_quality=0.82
                      small UI / 9-patch / rig layer / HUD skin images stay compress/mode=0 (lossless)
  * wav importer:     compress/mode=2 (QOA, ~5x smaller, loop points are kept by the importer)  [--no-wav to skip]
  * optional size cap (--cap N [--cap-dir DIR ...]): process/size_limit=N for ALLOW-LISTED dirs only. Off by default:
    measured gain was only ~2 MB for the whole project and several dirs carry pixel coordinates in code/JSON
    (hud2/combo face rects, rig layers, outfit face_rect), so a blanket cap is NOT safe.

Idempotent: a file already at the target values is reported as "unchanged" and not rewritten.
Run from anywhere; paths are relative to the repo root (parent of tools/).

  reimport.py --dry-run [--estimate] [--report r.json]   # numbers only, writes nothing
  reimport.py --apply                                    # rewrites .import files, then run `godot --headless --import`
"""
import argparse, io, json, os, re, sys
from collections import defaultdict
from multiprocessing import Pool

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GAME = os.path.join(REPO, "game")
LOSSY_Q = 0.82

# Images that must stay lossless (regexes on the res-relative path "assets/..."): rig layers (alpha-edged body parts
# that are composited and rotated at runtime), 9-patch / plate / button / frame skins, HUD skin plates, particles.
KEEP_LOSSLESS = [
    r"/rig/",
    r"^assets/v08/ui/(btn|frame|nav|misc|rank|league|icon|cur)/",
    r"^assets/v10/look/.*\.png$",    # V10HudSkin plates/buttons (9-patch margins in texture px); look/*.webp are backgrounds
    r"^assets/v10/hudfx/",
    r"^assets/v10/mj/triples/tray_",  # NinePatchRect trays (margins in texture pixels)
    r"^assets/(icons|fx|tiles)/",
    r"^assets/v06/(hud|board)/",
    r"^assets/v08/table/",
    r"(^|/)(plate|window|btn|button|nine|9p|patch|frame)[_\w]*\.(png|webp)$",
]
SMALL_PIXELS = 300 * 300  # <= this many pixels: lossless (gain is tiny, edges matter)


def parse_import(path):
    txt = open(path, encoding="utf-8").read()
    imp = re.search(r'^importer="(.*?)"', txt, re.M)
    src = re.search(r'^source_file="res://(.*?)"', txt, re.M)
    return txt, (imp.group(1) if imp else None), (src.group(1) if src else None)


def set_param(txt, key, val):
    pat = re.compile(r"^%s=.*$" % re.escape(key), re.M)
    if pat.search(txt):
        return pat.sub(lambda m: "%s=%s" % (key, val), txt, count=1)
    return txt.rstrip("\n") + "\n%s=%s\n" % (key, val)


def img_info(srcpath):
    from PIL import Image
    with Image.open(srcpath) as im:
        return im.size, (im.mode in ("RGBA", "LA", "PA") or "transparency" in im.info)


def enc_lossy(args):
    srcpath, cap, q = args
    from PIL import Image
    im = Image.open(srcpath)
    im.load()
    im = im.convert("RGBA")
    w, h = im.size
    m = max(w, h)
    if cap and m > cap:
        s = cap / m
        im = im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    b = io.BytesIO()
    im.save(b, "WEBP", quality=int(round(q * 100)), method=4)  # same libwebp Godot uses for lossy ctex
    return len(b.getvalue())


def imported_size(txt):
    tot = 0
    m = re.search(r"dest_files=\[(.*?)\]", txt, re.S)
    for d in re.findall(r'"res://(.*?)"', m.group(1)) if m else []:
        p = os.path.join(GAME, d)
        if os.path.exists(p):
            tot += os.path.getsize(p)
    return tot


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--dry-run", action="store_true")
    g.add_argument("--apply", action="store_true")
    ap.add_argument("--estimate", action="store_true", help="dry-run: encode lossy candidates with PIL to estimate sizes")
    ap.add_argument("--quality", type=float, default=LOSSY_Q)
    ap.add_argument("--no-wav", action="store_true", help="do not touch wav importer settings")
    ap.add_argument("--cap", type=int, default=0, help="process/size_limit for --cap-dir dirs only (default off)")
    ap.add_argument("--cap-dir", action="append", default=[], help="res-relative dir (allow-list) for --cap")
    ap.add_argument("--keep", action="append", default=[], help="extra regex to keep lossless")
    ap.add_argument("--report", help="write json report")
    ap.add_argument("-j", type=int, default=os.cpu_count() or 2)
    a = ap.parse_args()

    keep_res = [re.compile(p) for p in KEEP_LOSSLESS + a.keep]
    plan = []  # (importfile, new_txt|None, info)
    stats = defaultdict(int)
    est_jobs = []
    for dp, dn, fn in os.walk(os.path.join(GAME, "assets")):
        for f in sorted(fn):
            if not f.endswith(".import"):
                continue
            ip = os.path.join(dp, f)
            txt, importer, src = parse_import(ip)
            if importer not in ("texture", "wav"):
                continue
            srcpath = os.path.join(GAME, src)
            new = txt
            info = {"import": os.path.relpath(ip, GAME), "src": src, "importer": importer}
            if importer == "wav":
                if a.no_wav:
                    continue
                new = set_param(new, "compress/mode", "2")
                info["action"] = "wav_qoa"
            else:
                (w, h), alpha = img_info(srcpath)
                info.update(w=w, h=h, alpha=alpha)
                keep = any(r.search(src) for r in keep_res) or w * h <= SMALL_PIXELS
                if keep:
                    info["action"] = "keep_lossless"
                else:
                    new = set_param(new, "compress/mode", "1")
                    new = set_param(new, "compress/lossy_quality", "%g" % a.quality)
                    info["action"] = "lossy"
                    cap = 0
                    if a.cap and max(w, h) > a.cap and any(src.startswith(d.rstrip("/") + "/") for d in a.cap_dir):
                        new = set_param(new, "process/size_limit", str(a.cap))
                        cap = a.cap
                        info["cap"] = cap
                    if a.estimate:
                        est_jobs.append((len(plan), (srcpath, cap, a.quality)))
                info["imp_before"] = imported_size(txt)
            info["changed"] = new != txt
            stats[info["action"] + ("" if info["changed"] else ":unchanged")] += 1
            plan.append((ip, new if new != txt else None, info))

    if est_jobs:
        with Pool(a.j) as p:
            res = p.map(enc_lossy, [j[1] for j in est_jobs], chunksize=4)
        for (idx, _), sz in zip(est_jobs, res):
            plan[idx][2]["est_after"] = sz

    print("== reimport plan (%s)" % ("APPLY" if a.apply else "DRY-RUN"))
    for k in sorted(stats):
        print("  %-26s %5d" % (k, stats[k]))
    bef = sum(i.get("imp_before", 0) for _, _, i in plan if i["importer"] == "texture")
    lossy = [i for _, _, i in plan if i.get("action") == "lossy"]
    keepl = [i for _, _, i in plan if i.get("action") == "keep_lossless"]
    print("  textures: imported size before (.godot/imported) = %.1f MB" % (bef / 1e6))
    print("    lossless kept: %d files, %.1f MB" % (len(keepl), sum(i.get("imp_before", 0) for i in keepl) / 1e6))
    print("    to lossy q%g : %d files, %.1f MB before" % (a.quality, len(lossy), sum(i.get("imp_before", 0) for i in lossy) / 1e6))
    if a.estimate:
        e = sum(i.get("est_after", 0) for i in lossy)
        print("    estimated after (PIL libwebp): %.1f MB  -> textures total ~%.1f MB"
              % (e / 1e6, (sum(i.get("imp_before", 0) for i in keepl) + e) / 1e6))
        bydir = defaultdict(lambda: [0, 0, 0])
        for i in lossy:
            d = os.path.dirname(i["src"])
            bydir[d][0] += 1
            bydir[d][1] += i.get("imp_before", 0)
            bydir[d][2] += i.get("est_after", 0)
        print("  top dirs (n, before MB -> est MB):")
        for d, v in sorted(bydir.items(), key=lambda x: -x[1][1])[:15]:
            print("    %3d %7.1f -> %6.1f  %s" % (v[0], v[1] / 1e6, v[2] / 1e6, d))
    if a.report:
        json.dump([i for _, _, i in plan], open(a.report, "w"), indent=1)

    if a.apply:
        n = 0
        for ip, new, info in plan:
            if new is not None:
                with open(ip, "w", encoding="utf-8", newline="\n") as fh:
                    fh.write(new)
                n += 1
        print("rewrote %d .import files. Now run: godot --headless --import --path game  (re-encodes the .ctex files)" % n)
    else:
        print("dry-run: nothing written")


if __name__ == "__main__":
    main()
