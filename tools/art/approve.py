#!/usr/bin/env python3
"""P58: art approval gate.  Generated art never reaches a release by directory inclusion: it is registered in the manifest
as status=generated, lives in game/assets/incoming/ (a .gdignore directory: not imported, not exported), and only a human
`approve` call moves it to its final path and flips ONE manifest row to status=approved.

  register FILE... --dest res://assets/x/y.webp [--source MODEL] [--prompt-hash H] [--note TEXT]
        copy FILE into incoming/, scrub EXIF/XMP/C2PA losslessly, run the watermark scan, add a row
        {id, path=<final path>, src=<incoming path>, status=generated, ...}.  One FILE per --dest.
  audit ID [-o DIR]       contact sheet of hands / fingers / feet / legs / face crops for the anatomy audit
  approve ID --by NAME --audited [--force-watermark REASON]
        gates: file present + md5 as registered, 0 metadata, watermark scan clean (or --force-watermark REASON, recorded),
        --audited = "I looked at the contact sheet" (the human gate).  Moves incoming -> final path, sets status=approved,
        drops `src`.  Exactly one manifest row changes (checked before writing).
  reject ID --reason TEXT   status=rejected, file deleted from incoming/ (row kept as the record)
  list [--status S]         rows by status
  global: --manifest PATH (default game/assets/manifest/assets.json), --dry-run
"""
import argparse, json, os, shutil, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A
import scrub_metadata as SM
import watermark_scan as WM
import audit_crops as AC


def _die(msg, code=2):
    print("ERROR: " + msg)
    sys.exit(code)


def _ctx(a):
    mp = os.path.abspath(a.manifest)
    return mp, A.game_root_of(mp), A.load_manifest(mp)


def _ensure_incoming(game):
    d = os.path.join(game, A.INCOMING_REL)
    os.makedirs(d, exist_ok=True)
    g = os.path.join(d, ".gdignore")
    if not os.path.exists(g):
        open(g, "w").close()
    return d


def _px(p):
    from PIL import Image
    with Image.open(p) as im:
        return "%dx%d" % im.size


def cmd_register(a):
    mp, game, doc = _ctx(a)
    if len(a.files) != 1 or not a.dest:
        _die("register takes exactly one FILE and --dest res://assets/...")
    src_file, dest = a.files[0], a.dest
    if not dest.startswith("res://assets/") or dest.startswith("res://assets/incoming/") or ".." in dest:
        _die("--dest must be res://assets/<path> outside incoming/")
    if not dest.lower().endswith(A.IMG_EXT):
        _die("only %s images go through the art gate" % "/".join(A.IMG_EXT))
    if any(r["path"] == dest for r in doc["assets"]) or os.path.exists(A.res_to_fs(dest, game)):
        _die("%s already exists (new assets only; retire the old id instead of overwriting)" % dest)
    taken = {r["id"] for r in doc["assets"]}
    rid = A.slug(dest, taken)
    if rid in taken:
        _die("id %s taken" % rid)
    inc_dir = _ensure_incoming(game)
    inc_name = rid.replace("/", "_") + os.path.splitext(dest)[1].lower()
    inc_fs = os.path.join(inc_dir, inc_name)
    if os.path.exists(inc_fs):
        _die("incoming file exists: " + inc_fs)
    if a.dry_run:
        print("DRY register %s -> %s (id %s)" % (src_file, dest, rid))
        return
    shutil.copyfile(src_file, inc_fs)
    removed = SM.scrub_file(inc_fs)
    ok, ssim = SM.verify_pixels(src_file, inc_fs)
    if not ok:
        os.remove(inc_fs)
        _die("scrub changed pixels (ssim %.5f): aborted" % ssim)
    wm = WM.scan_image(inc_fs)
    h = A.md5_file(inc_fs)
    first = next((r["id"] for r in doc["assets"] if r["md5"] == h), None)
    row = {"id": rid, "path": dest, "kind": "image", "group": "art", "md5": h, "bytes": os.path.getsize(inc_fs),
           "px": _px(inc_fs), "dup_of": first, "status": "generated", "referenced_by": [],
           "src": "res://%s/%s" % (A.INCOMING_REL, inc_name)}
    if a.source:
        row["source"] = a.source
    if a.prompt_hash:
        row["prompt_hash"] = a.prompt_hash
    if a.note:
        row["note"] = a.note
    row["scrubbed"] = removed or []
    row["watermark"] = "flagged" if wm["flagged"] else "clean"
    A.insert_sorted(doc, row)
    A.save_manifest(doc, mp)
    print("REGISTER %s status=generated path=%s src=%s scrubbed=%s watermark=%s%s" % (
        rid, dest, row["src"], ",".join(removed) or "-", row["watermark"], " DUPLICATE_OF=" + first if first else ""))


def cmd_audit(a):
    mp, game, doc = _ctx(a)
    r = A.row_by_id(doc, a.id) or _die("unknown id " + a.id)
    fs = A.res_to_fs(r.get("src") or r["path"], game)
    lm = json.load(open(a.landmarks)) if a.landmarks else None
    m = AC.make_audit(fs, a.out, lm)
    print("AUDIT %s %d crops, sheet: %s (%.2fs)" % (a.id, len(m["crops"]), m["contact_sheet"], m["seconds"]))


def cmd_approve(a):
    mp, game, doc = _ctx(a)
    r = A.row_by_id(doc, a.id) or _die("unknown id " + a.id)
    if r["status"] not in ("generated", "pending"):
        _die("%s is %s: only generated/pending rows can be approved" % (a.id, r["status"]))
    if not a.by:
        _die("--by NAME (the human art director) is required")
    if not a.audited:
        _die("--audited is required: open `approve.py audit %s`, look at hands/fingers/feet/legs/face, then approve" % a.id)
    src_res = r.get("src") or r["path"]
    src_fs = A.res_to_fs(src_res, game)
    dst_fs = A.res_to_fs(r["path"], game)
    if not os.path.exists(src_fs):
        _die("file missing: " + src_fs)
    if A.md5_file(src_fs) != r["md5"]:
        _die("md5 differs from the registered one: file was modified after registration; re-register")
    meta = SM.scan(src_fs)
    if meta:
        _die("file still carries metadata %s: run scrub_metadata.py --in-place and re-register" % meta)
    wm = WM.scan_image(src_fs)
    if wm["flagged"] and not a.force_watermark:
        _die("watermark scan flagged %s: inspect, then pass --force-watermark 'reason' if it is a false positive"
             % ", ".join("%s/%s" % (z["zone"], z["kind"]) for z in wm["zones"]))
    if src_fs != dst_fs and os.path.exists(dst_fs):
        _die("destination exists: " + dst_fs)
    before = json.loads(json.dumps(doc))
    r["status"] = "approved"
    r.pop("src", None)
    r["approved_by"] = a.by
    if a.force_watermark:
        r["watermark"] = "waived: " + a.force_watermark
    else:
        r["watermark"] = "clean"
    changed = [x["id"] for x, y in zip(before["assets"], doc["assets"]) if x != y]
    if changed != [a.id] or len(before["assets"]) != len(doc["assets"]):
        _die("internal: more than one row would change: %s" % changed)
    if a.dry_run:
        print("DRY approve %s: %s -> %s" % (a.id, src_res, r["path"]))
        return
    if src_fs != dst_fs:
        os.makedirs(os.path.dirname(dst_fs), exist_ok=True)
        shutil.move(src_fs, dst_fs)
    A.save_manifest(doc, mp)
    print("APPROVED %s by %s: %s -> %s (1 manifest row changed)" % (a.id, a.by, src_res, r["path"]))


def cmd_reject(a):
    mp, game, doc = _ctx(a)
    r = A.row_by_id(doc, a.id) or _die("unknown id " + a.id)
    if r["status"] == "approved":
        _die("approved asset: retire it through the manifest owner, not reject")
    if not a.reason:
        _die("--reason required")
    r["status"] = "rejected"
    r["note"] = a.reason
    if r.get("src"):
        fs = A.res_to_fs(r.pop("src"), game)
        if os.path.exists(fs) and not a.dry_run:
            os.remove(fs)
    if not a.dry_run:
        A.save_manifest(doc, mp)
    print("REJECTED %s: %s" % (a.id, a.reason))


def cmd_list(a):
    mp, game, doc = _ctx(a)
    n = 0
    for r in doc["assets"]:
        if a.status and r["status"] != a.status:
            continue
        if not a.status and r["status"] == "approved":
            continue
        n += 1
        print("%-10s %-40s %s%s" % (r["status"], r["id"], r["path"], ("  <- " + r["src"]) if r.get("src") else ""))
    print("%d rows" % n)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--manifest", default=A.MANIFEST)
    ap.add_argument("--dry-run", action="store_true")
    sp = ap.add_subparsers(dest="cmd", required=True)
    p = sp.add_parser("register"); p.add_argument("files", nargs="+"); p.add_argument("--dest")
    p.add_argument("--source"); p.add_argument("--prompt-hash"); p.add_argument("--note"); p.set_defaults(fn=cmd_register)
    p = sp.add_parser("audit"); p.add_argument("id"); p.add_argument("-o", "--out", default="audit_out")
    p.add_argument("--landmarks"); p.set_defaults(fn=cmd_audit)
    p = sp.add_parser("approve"); p.add_argument("id"); p.add_argument("--by"); p.add_argument("--audited", action="store_true")
    p.add_argument("--force-watermark"); p.set_defaults(fn=cmd_approve)
    p = sp.add_parser("reject"); p.add_argument("id"); p.add_argument("--reason"); p.set_defaults(fn=cmd_reject)
    p = sp.add_parser("list"); p.add_argument("--status"); p.set_defaults(fn=cmd_list)
    a = ap.parse_args(argv)
    a.fn(a)


if __name__ == "__main__":
    main()
