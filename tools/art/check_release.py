#!/usr/bin/env python3
"""P58: CI gate "release contains only approved art".

A file ships in a release export when it is under game/, not inside a directory carrying .gdignore, not under .godot,
and not matched by the preset's exclude_filter (the presets use export_filter=all_resources).  This check fails when

  R1  a manifest row with status != approved has a file that would ship (its path, or its incoming `src`)
  R2  a file under game/assets would ship but has no manifest row                        (directory inclusion)
  R3  an approved row's file is missing, or its md5 differs from the manifest
  R4  a generated row has no `src`, or the src file is missing
  R5  game/assets/incoming exists without .gdignore, or holds files that no generated row owns
  R6  --include-list FILE (future manifest-generated list of res:// paths): any listed path whose row is not approved

usage: check_release.py [--manifest PATH] [--presets PATH] [--include-list FILE] [--no-md5]   exit 1 on any violation
"""
import argparse, fnmatch, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A

SKIP_SUFFIX = (".import", ".uid")


def ignored_dirs(game):
    """Directories (rel to game/) that carry a .gdignore."""
    out = set()
    for dp, dn, fn in os.walk(game):
        dn[:] = [d for d in dn if d not in (".godot", ".git")]
        if ".gdignore" in fn:
            out.add(os.path.relpath(dp, game).replace(os.sep, "/"))
    return out


def is_ignored(rel, igd):
    parts = rel.split("/")
    return any("/".join(parts[:i]) in igd for i in range(1, len(parts)))


def excluded(rel, patterns):
    return any(fnmatch.fnmatchcase(rel, p) for p in patterns)


def check(manifest_path, presets_path=None, include_list=None, check_md5=True):
    game = A.game_root_of(manifest_path)
    doc = A.load_manifest(manifest_path)
    presets = {}
    pp = presets_path or os.path.join(game, "export_presets.cfg")
    if os.path.exists(pp):
        presets = A.parse_exclude_filters(open(pp, encoding="utf-8").read())
    if not presets:
        presets = {"(no presets file)": {"ex": [], "mode": "all_resources"}}
    igd = ignored_dirs(game)
    errs = []

    def ships_in(rel):
        """preset names that would ship this res-relative file"""
        if is_ignored(rel, igd) or rel.startswith(".godot/"):
            return []
        if not os.path.exists(os.path.join(game, rel)):
            return []
        return [n for n, v in presets.items() if not excluded(rel, v["ex"])]

    rows_by_path = {}
    for r in doc["assets"]:
        rows_by_path[r["path"][len("res://"):]] = r
    for r in doc["assets"]:
        rel = r["path"][len("res://"):]
        st = r["status"]
        if st != "approved":
            for cand in (rel, (r.get("src") or "")[len("res://"):] if r.get("src") else None):
                if cand and ships_in(cand):
                    errs.append("R1 %s (%s) status=%s would ship in %s" % (r["id"], cand, st, ",".join(ships_in(cand))))
        else:
            fs = os.path.join(game, rel)
            if not os.path.exists(fs):
                errs.append("R3 approved %s: file missing %s" % (r["id"], rel))
            elif check_md5 and r.get("md5") and A.md5_file(fs) != r["md5"]:
                errs.append("R3 approved %s: md5 differs from the manifest" % r["id"])
        if st == "generated":
            s = r.get("src")
            if not s:
                errs.append("R4 generated %s has no src" % r["id"])
            elif not os.path.exists(os.path.join(game, s[len("res://"):])):
                errs.append("R4 generated %s: src missing %s" % (r["id"], s))
    # R2: unregistered shipping files
    assets = os.path.join(game, "assets")
    for dp, dn, fn in os.walk(assets):
        for f in fn:
            if f.endswith(SKIP_SUFFIX) or f == ".gdignore":
                continue
            rel = os.path.relpath(os.path.join(dp, f), game).replace(os.sep, "/")
            if rel == "assets/manifest/assets.json" or rel in rows_by_path:
                continue
            if ships_in(rel):
                errs.append("R2 %s ships (%s) but has no manifest row" % (rel, ",".join(ships_in(rel))))
    # R5: incoming dir
    inc = os.path.join(game, A.INCOMING_REL)
    if os.path.isdir(inc):
        if not os.path.exists(os.path.join(inc, ".gdignore")):
            errs.append("R5 %s has no .gdignore: incoming art would be imported and exported" % A.INCOMING_REL)
        owned = {r["src"][len("res://"):] for r in doc["assets"] if r.get("src")}
        for f in os.listdir(inc):
            rel = A.INCOMING_REL + "/" + f
            if f != ".gdignore" and not f.endswith(SKIP_SUFFIX) and rel not in owned:
                errs.append("R5 orphan file in incoming/: %s (no generated row owns it)" % rel)
    # R6
    if include_list:
        for line in open(include_list, encoding="utf-8"):
            p = line.strip()
            if not p or p.startswith("#"):
                continue
            rel = p[len("res://"):] if p.startswith("res://") else p
            row = rows_by_path.get(rel)
            if row is None:
                errs.append("R6 include-list path %s is not in the manifest" % p)
            elif row["status"] != "approved":
                errs.append("R6 include-list path %s has status %s" % (p, row["status"]))
    return errs, doc


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--manifest", default=A.MANIFEST)
    ap.add_argument("--presets")
    ap.add_argument("--include-list")
    ap.add_argument("--no-md5", action="store_true")
    a = ap.parse_args(argv)
    errs, doc = check(os.path.abspath(a.manifest), a.presets, a.include_list, not a.no_md5)
    for e in errs:
        print("FAIL " + e)
    from collections import Counter
    print("RELEASE_GATE %s (%d rows, %s)" % ("FAIL" if errs else "OK", len(doc["assets"]),
                                             dict(Counter(r["status"] for r in doc["assets"]))))
    sys.exit(1 if errs else 0)


if __name__ == "__main__":
    main()
