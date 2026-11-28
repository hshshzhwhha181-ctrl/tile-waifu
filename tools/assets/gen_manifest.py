#!/usr/bin/env python3
"""Tile Waifu asset manifest: game/assets/manifest/assets.json  (res://assets/manifest/assets.json)

One record per shipped asset file under game/assets (the manifest itself, .import and .uid files excluded):
  id            stable slug = path under assets/ without extension, '/' -> '.'   (extension appended on collision)
  path          res:// path
  kind          image | audio | video | font | data | other
  group         coarse role: music | voice | sfx | audio | rig_layer | ui | art | video ... (from path conventions)
  md5, bytes    of the SOURCE file (so re-running after slimming records the slimmed bytes)
  px            "WxH" for images and videos, else null
  dup_of        id of the first file with the same md5 (byte-identical duplicate), else null
  status        approved | generated | pending | rejected (generated = P58 art waiting in assets/incoming, see tools/art/approve.py). First seed (--seed) marks every existing asset `approved`; later runs keep the
                status already in the manifest and mark NEW files `pending` (review gate for generated art).
  referenced_by sorted list of source files (gd/tscn/tres/json/tsv/godot) that reference it, from a STATIC graph:
                  1. exact "res://assets/..." literals                         (direct)
                  2. format-string literals ("res://assets/x/%s.png", "...%d...") expanded as globs      (pattern)
                  3. a directory literal ("res://assets/x/" or "assets/x") plus a string in the same file that equals an
                     asset's file name / stem inside that dir (DIR + "mc_t1.png", "hana_t1")                (dir+name)
                  4. data files (json/tsv): any quoted string equal to an asset's relative path or file name inside a
                     directory that the same file's neighbours declare                                       (data)
                Dynamic composition the script cannot see leaves referenced_by empty: treat `[]` as "unreferenced by
                static analysis", not as "safe to delete" (the file may still be built by name at runtime).

usage: gen_manifest.py [--seed] [--check] [--out PATH]
  default  rewrite the manifest (deterministic: sorted, no timestamps)
  --check  exit 1 if the manifest on disk differs from what would be generated
"""
import argparse, fnmatch, hashlib, json, os, re, sys
from collections import defaultdict

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GAME = os.path.join(REPO, "game")
ASSETS = os.path.join(GAME, "assets")
OUT_REL = "assets/manifest/assets.json"
SKIP_SUFFIX = (".import", ".uid", ".gdignore")
IMG = (".png", ".webp", ".jpg", ".jpeg", ".svg")
AUD = (".ogg", ".wav", ".mp3")
VID = (".ogv",)
FNT = (".ttf", ".otf", ".woff", ".woff2")
CODE = (".gd", ".tscn", ".tres", ".json", ".tsv", ".cfg", ".godot", ".gdshader", ".scn", ".chat")


def md5(p):
    h = hashlib.md5()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def px_of(p, kind):
    try:
        if kind == "image" and not p.endswith(".svg"):
            from PIL import Image
            with Image.open(p) as im:
                return "%dx%d" % im.size
        if kind == "video":
            import subprocess
            o = subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                                         "stream=width,height", "-of", "csv=p=0:s=x", p], text=True).strip()
            return o or None
    except Exception:
        return None
    return None


def kind_group(rel):
    ext = os.path.splitext(rel)[1].lower()
    if ext in IMG:
        k = "image"
        g = "rig_layer" if "/rig/" in rel else "ui" if re.search(r"/(ui|hud|hudfx|icons?|fx|look)/", rel) else "art"
    elif ext in AUD:
        k = "audio"
        g = "music" if re.search(r"/music/|/look/.*ambience|menu\.ogg", rel) else "voice" if "/voice" in rel else "sfx" if "/sfx" in rel else "audio"
    elif ext in VID:
        k, g = "video", "video"
    elif ext in FNT:
        k, g = "font", "font"
    elif ext in (".json", ".tsv", ".txt", ".csv", ".md"):
        k, g = "data", "data"
    else:
        k, g = "other", "other"
    return k, g


def slug(rel, taken):
    base = os.path.splitext(rel[len("assets/"):])[0].replace("/", ".")
    if base in taken:
        base = base + "_" + os.path.splitext(rel)[1][1:]
    return base


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", action="store_true", help="mark every asset approved (first run)")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--out", default=os.path.join(GAME, OUT_REL))
    a = ap.parse_args()

    files = []
    for dp, dn, fn in os.walk(ASSETS):
        dn[:] = sorted(d for d in dn)
        if os.path.relpath(dp, GAME).replace(os.sep, "/") == "assets":
            dn[:] = [d for d in dn if d != "incoming"]     # P58: art waiting for the human gate is not an asset yet
        for f in sorted(fn):
            if f.endswith(SKIP_SUFFIX):
                continue
            p = os.path.join(dp, f)
            rel = os.path.relpath(p, GAME).replace(os.sep, "/")
            if rel == OUT_REL:
                continue
            files.append(rel)
    files.sort()
    by_path = set(files)
    by_name = defaultdict(list)
    by_stem = defaultdict(list)
    for r in files:
        by_name[os.path.basename(r)].append(r)
        by_stem[os.path.splitext(os.path.basename(r))[0]].append(r)

    # ---- static reference graph
    refs = defaultdict(set)
    src_files = []
    for dp, dn, fn in os.walk(GAME):
        dn[:] = [d for d in dn if d not in (".godot", ".git", "assets")]
        for f in fn:
            if f.endswith(CODE):
                src_files.append(os.path.join(dp, f))
    # data / script files inside assets (json etc.) also count as referrers
    for dp, dn, fn in os.walk(ASSETS):
        for f in fn:
            if f.endswith((".json", ".tsv", ".tscn", ".tres", ".gd")) and \
                    os.path.relpath(os.path.join(dp, f), GAME).replace(os.sep, "/") != OUT_REL:
                src_files.append(os.path.join(dp, f))
    str_re = re.compile(r'"((?:[^"\\\n]|\\.){1,300})"|\'((?:[^\'\\\n]|\\.){1,300})\'')
    all_by_dir = defaultdict(list)
    for r in files:
        all_by_dir[os.path.dirname(r)].append(r)
    for sp in sorted(src_files):
        srel = os.path.relpath(sp, GAME).replace(os.sep, "/")
        try:
            t = open(sp, encoding="utf-8", errors="replace").read()
        except Exception:
            continue
        strs = [m.group(1) or m.group(2) for m in str_re.finditer(t)]
        sset = set(strs)
        dirs = set()
        for s in strs:
            s0 = s[len("res://"):] if s.startswith("res://") else s
            if not s0.startswith("assets/"):
                continue
            if "%" in s0 or "*" in s0:
                pat = re.sub(r"%[-+ 0#]*\d*(?:\.\d+)?[sdfxXc]", "*", s0)
                for r in files:
                    if fnmatch.fnmatchcase(r, pat) or (not os.path.splitext(pat)[1] and fnmatch.fnmatchcase(os.path.splitext(r)[0], pat)):
                        refs[r].add(srel)
                continue
            if s0 in by_path:
                refs[s0].add(srel)
            else:
                d = s0.rstrip("/")
                if d in all_by_dir or s0.endswith("/") or not os.path.splitext(d)[1]:
                    dirs.add(d)
                # extension-less base path (res://assets/hero/mc) -> any file with that stem
                for r in files:
                    if os.path.splitext(r)[0] == d:
                        refs[r].add(srel)
        for d in dirs:
            for r in files:
                if r.startswith(d + "/"):
                    name = os.path.basename(r)
                    stem = os.path.splitext(name)[0]
                    if name in sset or stem in sset or (r[len(d) + 1:] in sset):
                        refs[r].add(srel)
        # data files: bare file names / relative paths
        if srel.endswith((".json", ".tsv")):
            for s in sset:
                if s in by_path:
                    refs[s].add(srel)
                elif s.startswith("res://") and s[6:] in by_path:
                    refs[s[6:]].add(srel)

    # ---- manifest
    old = {}
    carry = []                       # P58: status=generated rows live in incoming/, not in the walk above: keep them verbatim
    if os.path.exists(a.out):
        try:
            for r in json.load(open(a.out, encoding="utf-8"))["assets"]:
                if r.get("status") == "generated" and r["path"][len("res://"):] not in by_path:
                    carry.append(r)
                else:
                    old[r["path"][len("res://"):]] = r
        except Exception:
            pass
    recs = []
    taken = set()
    first_md5 = {}
    for rel in files:
        p = os.path.join(GAME, rel)
        k, g = kind_group(rel)
        h = md5(p)
        rid = slug(rel, taken)
        taken.add(rid)
        st = "approved" if a.seed else (old.get(rel, {}).get("status") or ("approved" if not old else "pending"))
        rec = {
            "id": rid, "path": "res://" + rel, "kind": k, "group": g, "md5": h, "bytes": os.path.getsize(p),
            "px": px_of(p, k), "dup_of": first_md5.get(h), "status": st,
            "referenced_by": sorted(refs.get(rel, [])),
        }
        for kk, vv in old.get(rel, {}).items():      # P58: keep curated fields (approved_by, source, prompt_hash, watermark, note ...)
            if kk not in rec and kk != "src":
                rec[kk] = vv
        recs.append(rec)
        first_md5.setdefault(h, rid)
    for r in carry:
        recs.append(r)
    recs.sort(key=lambda r: r["path"])
    doc = {"schema": 1, "generator": "tools/assets/gen_manifest.py", "count": len(recs),
           "statuses": ["approved", "generated", "pending", "rejected"], "assets": recs}
    text = json.dumps(doc, ensure_ascii=False, indent=1) + "\n"
    if a.check:
        cur = open(a.out, encoding="utf-8").read() if os.path.exists(a.out) else ""
        sys.exit(0 if cur == text else 1)
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    open(a.out, "w", encoding="utf-8", newline="\n").write(text)
    unref = [r for r in recs if not r["referenced_by"]]
    print("manifest: %d assets, %.1f MB, %d duplicates, %d with no static reference (%.1f MB) -> %s"
          % (len(recs), sum(r["bytes"] for r in recs) / 1e6, sum(1 for r in recs if r["dup_of"]), len(unref),
             sum(r["bytes"] for r in unref) / 1e6, os.path.relpath(a.out, REPO)))
    cnt = defaultdict(int)
    for r in recs:
        cnt[r["status"]] += 1
    print("status:", dict(cnt))


if __name__ == "__main__":
    main()
