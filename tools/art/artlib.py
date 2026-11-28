"""Shared helpers of the P58 art-approval pipeline: manifest I/O in the exact format of tools/assets/gen_manifest.py,
paths, id slugs.  Standard library only."""
import json, os, re, hashlib

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GAME = os.path.join(REPO, "game")
MANIFEST = os.path.join(GAME, "assets", "manifest", "assets.json")
INCOMING_REL = "assets/incoming"            # res://assets/incoming  (carries a .gdignore: never imported, never exported)
STATUSES = ["approved", "generated", "pending", "rejected"]
# generated = produced by a model, waiting in incoming/ for the human art gate;   approved = may ship;
# pending = existing file under review;   rejected = must never ship
IMG_EXT = (".png", ".webp", ".jpg", ".jpeg")


def md5_file(p):
    h = hashlib.md5()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def load_manifest(path=MANIFEST):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def dumps(doc):
    return json.dumps(doc, ensure_ascii=False, indent=1) + "\n"


def save_manifest(doc, path=MANIFEST):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        f.write(dumps(doc))
    os.replace(tmp, path)


def game_root_of(manifest_path):
    """game/ directory that belongs to a manifest at game/assets/manifest/assets.json."""
    return os.path.abspath(os.path.join(os.path.dirname(manifest_path), "..", ".."))


def res_to_fs(res, game):
    assert res.startswith("res://"), res
    return os.path.join(game, res[len("res://"):])


def slug(res_path, taken):
    rel = res_path[len("res://assets/"):]
    base = os.path.splitext(rel)[0].replace("/", ".")
    if base not in taken:
        return base
    return rel.replace("/", ".")


def row_by_id(doc, rid):
    for r in doc["assets"]:
        if r["id"] == rid:
            return r
    return None


def insert_sorted(doc, row):
    """Keep rows ordered by path (the order gen_manifest writes)."""
    rows = doc["assets"]
    i = 0
    while i < len(rows) and rows[i]["path"] < row["path"]:
        i += 1
    rows.insert(i, row)
    doc["count"] = len(rows)


def parse_exclude_filters(cfg_text):
    """-> {preset_name: [glob, ...]} from a Godot export_presets.cfg (exclude_filter entries)."""
    out, cur = {}, None
    for line in cfg_text.splitlines():
        m = re.match(r"\[preset\.(\d+)\]\s*$", line)
        if m:
            cur = {"name": None, "ex": [], "mode": ""}
            out[int(m.group(1))] = cur
            continue
        if cur is None or line.startswith("["):
            if line.startswith("[") and not re.match(r"\[preset\.\d+\]", line):
                cur = None
            continue
        if line.startswith("name="):
            cur["name"] = line.split("=", 1)[1].strip().strip('"')
        elif line.startswith("exclude_filter="):
            v = line.split("=", 1)[1].strip().strip('"')
            cur["ex"] = [x.strip() for x in v.split(",") if x.strip()]
        elif line.startswith("export_filter="):
            cur["mode"] = line.split("=", 1)[1].strip().strip('"')
    return {(v["name"] or str(k)): v for k, v in out.items()}
