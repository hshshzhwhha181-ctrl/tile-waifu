#!/usr/bin/env python3
"""P41 rig pilot: measures V10LiveRig budgets and layer-compression options, writes docs/rigs/pilot_yue_data.json.

  export GODOT_BIN=/path/to/Godot_v4.5.1
  python3 tools/rigs/pilot.py [--rigs mc_gown,rin_officer,hana_base] [--work DIR] [--no-gl] [--out docs/rigs/pilot_yue_data.json]

What it does (all in a scratch project copied from game/, the repo is never modified):
  1. measure: tools/rigs/measure.gd per rig, headless (structure, GPU-memory estimate, rig script ms/frame) and
     under xvfb + llvmpipe GL (real RENDER_TOTAL_DRAW_CALLS_IN_FRAME and GL texture memory; the ms there are NOT meaningful).
  2. compression: rewrites the .import of every rig PNG to N variants (lossless / lossy WebP q / VRAM ETC2+ASTC),
     runs the real Godot importer, sums imported-file bytes (what the PCK ships), decodes the result with the engine
     and compares to the source PNG (PSNR over pixels where either alpha > 0, premultiplied RGBA).
  3. picks per file the smallest variant that keeps PSNR >= --psnr (default 38 dB), else lossless.
Requires numpy + Pillow. xvfb-run for step 1b (skipped with --no-gl or if missing).
"""
import argparse, json, os, re, shutil, subprocess, sys, glob
import numpy as np
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GAME = os.path.join(REPO, "game")
HERE = os.path.dirname(os.path.abspath(__file__))
RIGS_DEFAULT = ["mc_gown", "rin_officer", "hana_base"]
# (name, compress/mode, lossy_quality)
VARIANTS = [("lossless", 0, 0.7), ("webp_q95", 1, 0.95), ("webp_q90", 1, 0.9), ("webp_q80", 1, 0.8),
            ("webp_q70", 1, 0.7), ("webp_q60", 1, 0.6), ("vram", 2, 0.7)]
SMALL = 24 * 1024  # files under this stay lossless in the hybrid policy (face patches, ornaments: tiny anyway)


def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def godot_bin(a):
    g = a or os.environ.get("GODOT_BIN") or shutil.which("godot4") or shutil.which("godot")
    if not g:
        sys.exit("set GODOT_BIN")
    return g


def build_base(dst, rigs):
    if os.path.exists(dst):
        shutil.rmtree(dst)
    os.makedirs(os.path.join(dst, "assets/v10/rig"))
    os.makedirs(os.path.join(dst, "scripts/v10/rig"))
    for r in rigs:
        shutil.copytree(os.path.join(GAME, "assets/v10/rig", r), os.path.join(dst, "assets/v10/rig", r),
                        ignore=shutil.ignore_patterns("*demo*", "*.import", "*.uid"))
    for f in glob.glob(os.path.join(GAME, "scripts/v10/rig/*")):
        if os.path.isfile(f) and re.search(r"(live_rig|rig_sheen)\.gd$|\.gdshader$", f):
            shutil.copy(f, os.path.join(dst, "scripts/v10/rig"))
    shutil.copy(os.path.join(GAME, "icon.png"), dst)
    open(os.path.join(dst, "project.godot"), "w").write(
        'config_version=5\n[application]\nconfig/name="rigpilot"\nconfig/features=PackedStringArray("4.5", "GL Compatibility")\n'
        '[display]\nwindow/size/viewport_width=720\nwindow/size/viewport_height=1280\nwindow/stretch/mode="canvas_items"\n'
        'window/stretch/aspect="expand"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
        'renderer/rendering_method.mobile="gl_compatibility"\ntextures/vram_compression/import_etc2_astc=true\n')


def write_imports(proj, mode, q):
    # seed .import files by letting Godot generate defaults first (mode 0 = what the game ships), then rewrite
    for p in glob.glob(os.path.join(proj, "assets/v10/rig/*/*.png.import")):
        s = open(p).read()
        s = re.sub(r"compress/mode=\d", "compress/mode=%d" % mode, s)
        s = re.sub(r"compress/lossy_quality=[\d.]+", "compress/lossy_quality=%s" % q, s)
        open(p, "w").write(s)


def gimport(g, proj):
    r = sh(["nice", "-n", "19", g, "--headless", "--path", proj, "--import"], timeout=900)
    return r


def imported_sizes(proj):
    """png path -> {fmt: bytes} from the .import files (what the PCK would ship)."""
    out = {}
    for p in glob.glob(os.path.join(proj, "assets/v10/rig/*/*.png.import")):
        s = open(p).read()
        rig = p.split(os.sep)[-2]
        name = os.path.basename(p)[:-len(".import")]
        d = {}
        for m in re.finditer(r'^path(?:\.(\w+))?="res://(\.godot/imported/[^"]+)"', s, re.M):
            f = os.path.join(proj, m.group(2))
            if os.path.exists(f):
                d[m.group(1) or "ctex"] = os.path.getsize(f)
        out["%s/%s" % (rig, name)] = d
    return out


def psnr_fg(src, dec):
    a = np.asarray(Image.open(src).convert("RGBA"), dtype=np.float64)
    b = np.asarray(Image.open(dec).convert("RGBA"), dtype=np.float64)
    if b.shape[0] >= a.shape[0] and b.shape[1] >= a.shape[1]:
        b = b[:a.shape[0], :a.shape[1]]  # VRAM-compressed textures are padded to a multiple of 4
    if a.shape != b.shape:
        return None
    fg = (a[..., 3] > 0) | (b[..., 3] > 0)
    def pm(x):
        al = x[..., 3:4] / 255.0
        return np.concatenate([x[..., :3] * al, x[..., 3:4]], axis=-1)
    d = pm(a) - pm(b)
    e_full = float((d ** 2).mean())
    e_fg = float((d[fg] ** 2).mean()) if fg.any() else 0.0
    ps = lambda e: 99.0 if e <= 1e-9 else float(10 * np.log10(255.0 ** 2 / e))
    return {"psnr_fg": round(ps(e_fg), 2), "psnr_full": round(ps(e_full), 2),
            "fg_px": int(fg.sum()), "px": int(fg.size)}


def runtime_files(rig_dir):
    """PNGs the engine really loads at runtime: rig.tscn textures + rig_def.json (face patches, sockets, irises, bg) + sheen."""
    want = set()
    for m in re.finditer(r'res://assets/v10/rig/[^/]+/([^"]+\.png)', open(os.path.join(rig_dir, "rig.tscn")).read()):
        want.add(m.group(1))
    d = json.load(open(os.path.join(rig_dir, "rig_def.json")))
    f = d.get("face", {})
    for k, v in f.get("patches", {}).items():
        want.add(v["file"])
    for side in ("L", "R"):
        ir = f.get("iris", {}).get(side)
        if ir:
            want.add(ir["socket"]); want.add(ir["iris"])
    want.add("bg.png")
    for pl in d.get("plates", []) if isinstance(d.get("plates"), list) else []:
        if isinstance(pl, dict) and "file" in pl:
            want.add(pl["file"])
    # sheen mask + any plates/overlays referenced by name in json/gd
    for fn in glob.glob(os.path.join(rig_dir, "*.png")):
        b = os.path.basename(fn)
        txt = open(os.path.join(rig_dir, "rig_def.json")).read() + "".join(
            open(x).read() for x in glob.glob(os.path.join(rig_dir, "*.gd")))
        if b in txt:
            want.add(b)
    want.add("sheen_mask.png") if os.path.exists(os.path.join(rig_dir, "sheen_mask.png")) else None
    # body.png is the build source of the cutout (rig_def.texture); the scene uses layer_body.png. Only a selftest
    # (hud2_selftest) loads mc_gown/body.png, so it is NOT a runtime file (listed separately as 'build_source').
    want.discard("body.png")
    return want


def measure(g, proj, rigs, gl):
    res = {}
    for r in rigs:
        cmd = [g, "--headless", "--path", proj, "--fixed-fps", "60", "-s", os.path.join(HERE, "measure.gd"), "--",
               "rig=" + r, "frames=900"]
        o = sh(["nice", "-n", "19"] + cmd, timeout=300).stdout
        m = re.search(r"RIGMEASURE (\{.*\})", o)
        res[r] = {"headless": json.loads(m.group(1)) if m else None}
        if gl and shutil.which("xvfb-run"):
            cmd = ["xvfb-run", "-a", "-s", "-screen 0 720x1280x24", g, "--rendering-driver", "opengl3", "--path", proj,
                   "--fixed-fps", "60", "-s", os.path.join(HERE, "measure.gd"), "--", "rig=" + r, "frames=240"]
            o = sh(["nice", "-n", "19"] + cmd, timeout=300).stdout
            m = re.search(r"RIGMEASURE (\{.*\})", o)
            res[r]["gl"] = json.loads(m.group(1)) if m else None
    if gl and shutil.which("xvfb-run"):
        cmd = ["xvfb-run", "-a", "-s", "-screen 0 720x1280x24", g, "--rendering-driver", "opengl3", "--path", proj,
               "--fixed-fps", "60", "-s", os.path.join(HERE, "measure.gd"), "--", "rig=none", "frames=120"]
        m = re.search(r"RIGMEASURE (\{.*\})", sh(["nice", "-n", "19"] + cmd, timeout=300).stdout)
        res["_empty_scene_gl"] = json.loads(m.group(1)) if m else None
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rigs", default=",".join(RIGS_DEFAULT))
    ap.add_argument("--work", default="/tmp/p41_pilot")
    ap.add_argument("--godot")
    ap.add_argument("--no-gl", action="store_true")
    ap.add_argument("--psnr", type=float, default=38.0)
    ap.add_argument("--out", default=os.path.join(REPO, "docs/rigs/pilot_yue_data.json"))
    ap.add_argument("--skip-measure", action="store_true")
    a = ap.parse_args()
    g = godot_bin(a.godot)
    rigs = a.rigs.split(",")
    work = os.path.abspath(a.work)
    os.makedirs(work, exist_ok=True)
    base = os.path.join(work, "lossless")
    build_base(base, rigs)
    print("import baseline ...", flush=True)
    gimport(g, base)
    result = {"godot": sh([g, "--version"]).stdout.strip(), "rigs": rigs, "psnr_gate_db": a.psnr}
    if not a.skip_measure:
        print("measure ...", flush=True)
        result["measure"] = measure(g, base, rigs, not a.no_gl)
    # compression variants
    per_file = {}  # key -> {variant -> {...}}
    for name, mode, q in VARIANTS:
        proj = os.path.join(work, name)
        if name != "lossless":
            if os.path.exists(proj):
                shutil.rmtree(proj)
            shutil.copytree(base, proj, ignore=shutil.ignore_patterns(".godot"))
            gimport(g, proj)  # generates default .import
            write_imports(proj, mode, q)
            for d in glob.glob(os.path.join(proj, ".godot/imported/*")):
                os.remove(d)
            gimport(g, proj)
        print("variant", name, flush=True)
        sizes = imported_sizes(proj)
        dec = os.path.join(work, "dec_" + name)
        if os.path.exists(dec):
            shutil.rmtree(dec)
        o = sh(["nice", "-n", "19", g, "--headless", "--path", proj, "-s", os.path.join(HERE, "dump_decoded.gd"), "--",
                "out=" + dec, "rigs=" + a.rigs], timeout=600).stdout
        fmts = {}
        for m in re.finditer(r"DUMP (\S+)/(\S+) \d+x\d+ fmt=(\d+)", o):
            fmts["%s/%s" % (m.group(1), m.group(2))] = int(m.group(3))
        for key, d in sizes.items():
            rig, fn = key.split("/")
            src = os.path.join(GAME, "assets/v10/rig", rig, fn)
            ps = psnr_fg(src, os.path.join(dec, "%s__%s" % (rig, fn)))
            ent = per_file.setdefault(key, {"src_bytes": os.path.getsize(src)})
            ship = d.get("astc") or d.get("etc2") or d.get("ctex") or d.get("s3tc") or max(d.values() or [0])
            ent[name] = {"bytes": ship, "all_formats": d, "image_format_enum": fmts.get(key), **(ps or {})}
    # per-rig aggregation
    summary = {}
    for r in rigs:
        rd = os.path.join(GAME, "assets/v10/rig", r)
        rt = runtime_files(rd)
        files = {k: v for k, v in per_file.items() if k.startswith(r + "/")}
        agg = {}
        for name, _m, _q in VARIANTS:
            tot_rt = sum(v[name]["bytes"] for k, v in files.items() if k.split("/")[1] in rt)
            tot_all = sum(v[name]["bytes"] for k, v in files.items())
            ps = [v[name]["psnr_fg"] for k, v in files.items() if k.split("/")[1] in rt and v[name].get("psnr_fg") is not None]
            big = [v[name]["psnr_fg"] for k, v in files.items() if k.split("/")[1] in rt and v["src_bytes"] >= SMALL and v[name].get("psnr_fg") is not None]
            agg[name] = {"runtime_bytes": tot_rt, "all_bytes": tot_all, "min_psnr_runtime": min(ps) if ps else None,
                         "min_psnr_big_files": min(big) if big else None}
        # hybrid: per runtime file smallest variant meeting the gate; small files lossless
        tot = 0
        choice = {}
        for k, v in files.items():
            fn = k.split("/")[1]
            if fn not in rt:
                continue
            best = ("lossless", v["lossless"]["bytes"])
            if v["src_bytes"] >= SMALL:
                for name, _m, _q in VARIANTS[1:]:
                    e = v[name]
                    if e.get("psnr_fg") is not None and e["psnr_fg"] >= a.psnr and e["bytes"] < best[1]:
                        best = (name, e["bytes"])
            choice[fn] = best[0]
            tot += best[1]
        agg["hybrid_gate"] = {"runtime_bytes": tot, "choice": choice}
        summary[r] = {"runtime_png": sorted(rt), "other_bytes_runtime": sum(os.path.getsize(f) for f in glob.glob(os.path.join(rd, "*")) if os.path.isfile(f) and not f.endswith((".png", ".import", ".uid")) and "demo" not in f), "source_png_bytes_all": sum(v["src_bytes"] for v in files.values()),
                      "source_png_bytes_runtime": sum(v["src_bytes"] for k, v in files.items() if k.split("/")[1] in rt),
                      "variants": agg}
    result["per_file"] = per_file
    result["summary"] = summary
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    json.dump(result, open(a.out, "w"), indent=1, sort_keys=True)
    print("wrote", a.out)
    for r in rigs:
        s = summary[r]
        print(r, "source runtime", s["source_png_bytes_runtime"], {k: v["runtime_bytes"] for k, v in s["variants"].items()})


if __name__ == "__main__":
    main()
