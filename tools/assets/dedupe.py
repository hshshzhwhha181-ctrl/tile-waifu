#!/usr/bin/env python3
"""Tile Waifu asset slimming, stage 4: find byte-identical assets (md5), report the waste, emit a duplicate->canonical map.

Modes
  dedupe.py                     report only: duplicate groups, wasted bytes (source + imported)
  dedupe.py --json out.json     machine-readable groups
  dedupe.py --emit-map map.json  duplicate -> canonical map for a loader-side remap

Why there is no automatic remap: rewriting a duplicate's .import `path=`/`dest_files` onto the canonical .ctex was TRIED
(godot 4.5.1, `--export-pack`): the pack still stores one entry per source file, so the exported size did not change
(81.39 MB of .ctex before and after), and the editor rewrites `path=` on the next reimport anyway. Removing duplicates for
real needs a code-side change (resolve duplicate -> canonical in the loader, or delete one file and point the two call
sites at the survivor). After lossy slimming the duplicates cost ~2.0 MB of the pack (16 texture pairs), 3.3 MB as sources.

Only files under game/assets are considered; `.import`/`.uid` files and tiny (<4 KB) files are ignored (the
.gdignore / OFL.txt / helper .py duplicates are listed but flagged "ignore").
"""
import argparse, hashlib, json, os, re, sys
from collections import defaultdict

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GAME = os.path.join(REPO, "game")


def md5(p):
    h = hashlib.md5()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def import_info(src_abs):
    ip = src_abs + ".import"
    if not os.path.exists(ip):
        return None
    t = open(ip, encoding="utf-8").read()
    params = t.split("[params]", 1)[1] if "[params]" in t else ""
    dest = re.findall(r'"(res://\.godot/imported/[^"]+)"', (re.search(r"dest_files=\[(.*?)\]", t, re.S) or [None, ""])[1])
    size = sum(os.path.getsize(os.path.join(GAME, d[6:])) for d in dest if os.path.exists(os.path.join(GAME, d[6:])))
    return {"import": ip, "text": t, "params": params.strip(), "dest": dest, "imported_bytes": size}


def groups():
    by = defaultdict(list)
    for dp, dn, fn in os.walk(os.path.join(GAME, "assets")):
        for f in fn:
            if f.endswith((".import", ".uid")):
                continue
            p = os.path.join(dp, f)
            if os.path.getsize(p) < 4096:
                continue
            by[md5(p)].append(p)
    return {k: sorted(v) for k, v in by.items() if len(v) > 1}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json")
    ap.add_argument("--emit-map", help="write {duplicate res:// path: canonical res:// path} for a loader-side remap")
    a = ap.parse_args()
    gs = groups()
    out = []
    waste_src = waste_imp = 0
    for k, files in sorted(gs.items(), key=lambda x: -os.path.getsize(x[1][0])):
        infos = [import_info(f) for f in files]
        canon = files[0]
        g = {"md5": k, "bytes": os.path.getsize(canon), "files": [os.path.relpath(f, GAME) for f in files],
             "imported": all(i is not None for i in infos)}
        if g["imported"]:
            g["imported_bytes_each"] = [i["imported_bytes"] for i in infos]
            g["same_params"] = len({i["params"] for i in infos}) == 1
            waste_imp += sum(i["imported_bytes"] for i in infos[1:])
            waste_src += g["bytes"] * (len(files) - 1)
        out.append(g)
    print("== %d duplicate groups (md5, >=4 KB, game/assets)" % len(out))
    for g in out:
        print("  %8d B  %s%s" % (g["bytes"], " <-> ".join(g["files"]),
                                 "" if g["imported"] else "   [not imported: ignore]"))
    print("== wasted in sources: %.2f MB; wasted in imported (.ctex/.oggstr) now: %.2f MB"
          % (waste_src / 1e6, waste_imp / 1e6))
    if a.json:
        json.dump(out, open(a.json, "w"), indent=1)
    if a.emit_map:
        # canonical map for a future loader-side remap (needs a code change; see docstring): duplicate res:// -> canonical res://
        m = {}
        for g in out:
            for f in g["files"][1:]:
                if g["imported"]:
                    m["res://" + f] = "res://" + g["files"][0]
        json.dump(m, open(a.emit_map, "w"), indent=1)
        print("wrote %d duplicate->canonical entries to %s" % (len(m), a.emit_map))


if __name__ == "__main__":
    main()
