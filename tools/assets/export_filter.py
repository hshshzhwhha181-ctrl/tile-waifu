#!/usr/bin/env python3
"""Tile Waifu asset slimming, stage 5: compute a SAFE exclude_filter for export_presets.cfg.

Candidates = test / demo / selftest / runner / shots / dev-tool files outside game/assets (scripts, scenes, py, md).
A candidate is only excluded when nothing that ships can statically need it.  "Needs" =
  * a class_name declared in the candidate is used (identifier match) by a shipped .gd   (parse-time dependency!)
  * preload("res://...") / `extends "res://..."` / .tscn|.tres ext_resource / [autoload] / run/main_scene
    of a shipped file points at the candidate
The check is iterated to a fixed point (a candidate pulled in by a shipped file becomes shipped itself and may pull more).
Plain load("res://...") / string references from shipped code are SOFT (runtime, only fail when that code path runs);
they are listed as warnings for review but do not pin the candidate (they are the dev/test flag dispatchers).

  export_filter.py                 report: exclude list, pinned list (with the reason), soft-reference warnings
  export_filter.py --apply         writes exclude_filter=... into all [preset.N] of game/export_presets.cfg
  export_filter.py --check         exit 1 if export_presets.cfg differs from the computed filter (CI guard)
export_filter value is a comma separated list of exact res-relative paths (Godot globs would also work, but explicit paths
make a missed dependency impossible to hide behind a wildcard).
"""
import argparse, os, re, sys
from collections import defaultdict

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GAME = os.path.join(REPO, "game")

CAND_RE = re.compile(
    r"(selftest|_demo\b|\bdemo_|/demo/|_runner\b|\brunner_|/tools/|/shots/|_shot_runner|_cli\b|bench\.(gd|tscn)|fuzz\.gd|story_test|"
    r"/devtools/|rig_demo|demo_host|(^|/)tests?/|_tests?\.(gd|tscn)$|/pipeline/|\.(py|md|sh)$)")
SKIP_ASSETS = "assets/"
TEXT_EXT = (".gd", ".tscn", ".tres", ".cfg", ".godot", ".gdshader")
# Never excluded even when they match: the gate in HANDOFF (--export-pack + `--main-pack x.pck --pt=fresh` => PT OK)
# needs the playtest, and it is class_name-referenced from main/g anyway; kept explicit for readability.
NEVER = ("scripts/v08/devtools/playtest.gd",)


def read(p):
    return open(os.path.join(GAME, p), encoding="utf-8", errors="replace").read()


def strip_comments(t):
    return re.sub(r"(?m)^\s*#.*$", "", t)


def all_files():
    out = []
    for dp, dn, fn in os.walk(GAME):
        dn[:] = [d for d in dn if d not in (".godot", ".git")]
        if os.path.exists(os.path.join(dp, ".gdignore")):
            dn[:] = []
            continue
        for f in fn:
            out.append(os.path.relpath(os.path.join(dp, f), GAME).replace(os.sep, "/"))
    return sorted(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()

    files = all_files()
    code = [f for f in files if f.endswith(TEXT_EXT) and not f.startswith("export_presets")]
    # under assets/ only code/doc files are candidates (media and OFL.txt licences must never match)
    cands = {f for f in files if CAND_RE.search(f) and f not in NEVER and not f.endswith((".import", ".jpg", ".png"))
             and (not f.startswith(SKIP_ASSETS) or f.endswith((".gd", ".tscn", ".py", ".md", ".sh")))}
    # companions: .uid next to excluded scripts
    class_of = {}
    texts = {}
    for f in code:
        t = read(f)
        texts[f] = t
        if f.endswith(".gd"):
            m = re.search(r"(?m)^class_name\s+(\w+)", t)
            if m:
                class_of[f] = m.group(1)

    # references per file (hard)
    def hard_refs(f):
        t = texts[f]
        refs = set()
        for m in re.finditer(r'(?:preload\(|extends\s+)"res://([^"]+)"', t):
            refs.add(m.group(1))
        if f.endswith((".tscn", ".tres")):
            for m in re.finditer(r'path="res://([^"]+)"', t):
                refs.add(m.group(1))
        if f == "project.godot":
            for m in re.finditer(r'"\*?res://([^"]+)"', t):
                refs.add(m.group(1))
        return refs

    hard = {f: hard_refs(f) for f in code}
    shipped = set(f for f in code) - cands
    cls_users = {}  # class name -> regex
    cls_re = {c: re.compile(r"\b%s\b" % c) for c in class_of.values()}
    stripped = {f: strip_comments(texts[f]) for f in code if f.endswith(".gd")}
    pinned = {}  # file -> reason
    changed = True
    while changed:
        changed = False
        for c in sorted(cands - set(pinned)):
            reason = None
            cn = class_of.get(c)
            base = os.path.splitext(c)[0]
            for s in sorted(shipped):
                if c in hard.get(s, ()):
                    reason = "%s (preload/ext_resource/extends)" % s
                    break
                if cn and s.endswith(".gd") and s != c and cls_re[cn].search(stripped[s]):
                    reason = "%s (class_name %s)" % (s, cn)
                    break
                # a .gd and the .tscn that instances it travel together
                if s != c and os.path.splitext(s)[0] == base and s in pinned:
                    reason = "pair of " + s
                    break
            if reason:
                pinned[c] = reason
                shipped.add(c)
                changed = True
    excl = sorted(cands - set(pinned))
    # soft refs from shipped code to excluded files
    soft = defaultdict(list)
    ex_set = set(excl)
    for s in sorted(shipped):
        if s not in texts:
            continue
        for m in re.finditer(r'res://([A-Za-z0-9_./\-]+)', texts[s]):
            p = m.group(1)
            if p in ex_set:
                soft[s].append(p)
    # companions to exclude: .uid files of excluded scripts, and non-code candidates (py/md/json/jpg in /tools/ etc.)
    # the asset manifest is a build-time/QA artefact (nothing reads it at runtime): ~0.6 MB saved
    excl = sorted(set(excl) | {f for f in files if f == "assets/manifest/assets.json"})
    uid = [e + ".uid" for e in excl if os.path.exists(os.path.join(GAME, e + ".uid"))]
    final = sorted(set(excl + uid))
    print("== candidates %d | pinned (shipped) %d | excluded %d (+%d .uid)" % (len(cands), len(pinned), len(excl), len(uid)))
    byext = defaultdict(int)
    for e in excl:
        byext[os.path.splitext(e)[1]] += 1
    print("   excluded by type:", dict(byext))
    print("-- pinned (not excluded), reason:")
    for p, r in sorted(pinned.items()):
        print("   %-62s <- %s" % (p, r))
    print("-- soft references from shipped code to excluded files (runtime literal; fine only if behind a dev/test flag):")
    for s, ps in soft.items():
        print("   %s -> %s" % (s, ", ".join(sorted(set(ps)))))
    val = ", ".join(final)
    if a.apply or a.check:
        cfg = open(os.path.join(GAME, "export_presets.cfg"), encoding="utf-8").read()
        new = re.sub(r'(?m)^exclude_filter=.*$', lambda m: 'exclude_filter="%s"' % val, cfg)
        if a.check:
            sys.exit(0 if new == cfg else 1)
        open(os.path.join(GAME, "export_presets.cfg"), "w", encoding="utf-8", newline="\n").write(new)
        print("wrote exclude_filter (%d entries) into %d presets" % (len(final), len(re.findall(r"(?m)^exclude_filter=", cfg))))
    else:
        print("(dry-run) exclude_filter would have %d entries; use --apply" % len(final))


if __name__ == "__main__":
    main()
