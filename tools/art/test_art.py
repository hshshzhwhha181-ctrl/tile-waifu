#!/usr/bin/env python3
"""P58 acceptance tests for the art-approval pipeline.  Prints marker lines; last line "ART_PIPELINE ok/total".

  python tools/art/test_art.py            all checks (about 40 s, pure Python: Pillow + numpy)
  python tools/art/test_art.py --quick    skips the slow watermark checks

Acceptance (backlog P58):
  A1  20 images: 0 EXIF/XMP/C2PA after the scrub, pixels identical (SSIM 1.0)         [+ exiftool when installed]
  A2  audit_crops on 1536x1536: >= 6 crops, contact sheet < 5 s
  A3  approve changes exactly one manifest row; release gate rejects non-approved files (3+ examples)
  watermark detector: marks flagged, clean art not flagged
"""
import io, json, os, shutil, struct, subprocess, sys, tempfile, time, zlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import artlib as A
import scrub_metadata as SM
import watermark_scan as WM
import audit_crops as AC
import check_release as CR

PY = sys.executable
OKS, TOTAL = [], []


def check(name, cond, detail=""):
    TOTAL.append(name)
    if cond:
        OKS.append(name)
    print("%s %s%s" % ("OK  " if cond else "FAIL", name, (" -- " + detail) if detail and not cond else ""))
    return cond


# ------------------------------------------------------------------ synthetic material
def soft_art(seed, w=256, h=256, alpha=False):
    r = np.random.RandomState(seed)
    yy, xx = np.mgrid[0:h, 0:w] / float(max(w, h))
    img = np.zeros((h, w, 3))
    for c in range(3):
        img[..., c] = 100 + 70 * np.sin(3 * xx + seed + c) * np.cos(2 * yy + c) + r.randn() * 8
    im = Image.fromarray(np.clip(img, 0, 255).astype("uint8"))
    d = ImageDraw.Draw(im)
    for _ in range(14):
        x, y = r.randint(0, w), r.randint(0, h)
        rad = r.randint(w // 10, w // 3)
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=tuple(int(v) for v in r.randint(30, 230, 3)))
    im = im.filter(ImageFilter.GaussianBlur(max(2, w // 170 * 4)))
    a = np.asarray(im).astype(float) + r.randn(h, w, 3) * 2.5
    im = Image.fromarray(np.clip(a, 0, 255).astype("uint8"))
    if alpha:
        m = Image.new("L", (w, h), 0)
        ImageDraw.Draw(m).ellipse([w * 0.2, h * 0.05, w * 0.8, h * 0.98], fill=255)
        im.putalpha(m.filter(ImageFilter.GaussianBlur(1.5)))
    return im


def _png_chunk(typ, data):
    return struct.pack(">I", len(data)) + typ + data + struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF)


def png_with_meta(im, variant):
    buf = io.BytesIO()
    im.save(buf, "PNG")
    d = buf.getvalue()
    iend = d.rindex(b"IEND") - 4
    extra = b""
    if variant % 4 == 0:
        extra += _png_chunk(b"tEXt", b"parameters\0prompt: a girl, seed 1234") + _png_chunk(b"tIME", struct.pack(">HBBBBB", 2026, 1, 2, 3, 4, 5))
    if variant % 4 == 1:
        extra += _png_chunk(b"iTXt", b"XML:com.adobe.xmp\0\0\0\0\0<x:xmpmeta xmlns:x='adobe:ns:meta/'/>")
        extra += _png_chunk(b"eXIf", b"MM\0*\0\0\0\x08\0\0")
    if variant % 4 == 2:
        extra += _png_chunk(b"caBX", b"\0\0\0\x20jumb\0\0\0\x18jumdc2pa\0\x11\x00\x10\x80\0\0\xaa\0\x38\x9b\x71")
        extra += _png_chunk(b"zTXt", b"Software\0\0" + zlib.compress(b"midjourney"))
    if variant % 4 == 3:
        extra += _png_chunk(b"tEXt", b"Comment\0made by tool") + _png_chunk(b"caBX", b"jumbc2pa")
    return d[:iend] + extra + d[iend:] + b"trailing-garbage-after-iend"


def jpeg_with_meta(im, variant):
    buf = io.BytesIO()
    im.convert("RGB").save(buf, "JPEG", quality=92)
    d = buf.getvalue()
    segs = b""

    def seg(m, payload):
        return bytes([0xFF, m]) + struct.pack(">H", len(payload) + 2) + payload
    segs += seg(0xE1, b"Exif\0\0MM\0*\0\0\0\x08\0\x01\x01\x0f\0\x02\0\0\0\x06\0\0\0\x1a\0\0\0\0Canon\0")
    if variant % 3 != 0:
        segs += seg(0xE1, b"http://ns.adobe.com/xap/1.0/\0<x:xmpmeta xmlns:x='adobe:ns:meta/'><rdf:RDF/></x:xmpmeta>")
    if variant % 3 == 1:
        segs += seg(0xEB, b"JP\x00\x01\0\0\0\x01jumb\0\0\0\x18jumdc2pa\0\x11")
    if variant % 3 == 2:
        segs += seg(0xED, b"Photoshop 3.0\x008BIM\x04\x04\0\0\0\0") + seg(0xFE, b"Created with GenAI")
    return d[:2] + segs + d[2:]


def webp_with_meta(im, variant, lossless):
    buf = io.BytesIO()
    kw = {"lossless": True} if lossless else {"quality": 85}
    kw["exif"] = b"Exif\0\0MM\0*\0\0\0\x08\0\0"
    if variant % 2 == 0:
        kw["xmp"] = b"<x:xmpmeta xmlns:x='adobe:ns:meta/'><rdf:RDF/></x:xmpmeta>"
    im.save(buf, "WEBP", **kw)
    d = bytearray(buf.getvalue())
    if variant % 2 == 1:   # add a C2PA chunk and fix the RIFF size
        c = b"C2PA" + struct.pack("<I", 12) + b"jumbc2pa0123"
        d += c
        d[4:8] = struct.pack("<I", len(d) - 8)
    return bytes(d)


def make_20(tmp):
    files = []
    for i in range(8):
        p = os.path.join(tmp, "t%02d.png" % i)
        open(p, "wb").write(png_with_meta(soft_art(i, alpha=(i % 2 == 1)), i))
        files.append(p)
    for i in range(6):
        p = os.path.join(tmp, "t%02d.jpg" % (8 + i))
        open(p, "wb").write(jpeg_with_meta(soft_art(20 + i), i))
        files.append(p)
    for i in range(6):
        p = os.path.join(tmp, "t%02d.webp" % (14 + i))
        open(p, "wb").write(webp_with_meta(soft_art(40 + i, alpha=(i % 3 == 0)), i, lossless=(i % 2 == 0)))
        files.append(p)
    return files


# ------------------------------------------------------------------ A1
def test_scrub(tmp):
    files = make_20(tmp)
    check("A1 twenty test images created", len(files) == 20)
    dirty = sum(1 for f in files if SM.scan(f))
    check("A1 all 20 carry EXIF/XMP/C2PA/text before the scrub", dirty == 20, "dirty=%d" % dirty)
    kinds = set()
    for f in files:
        kinds.update(x.split(":")[0] for x in SM.scan(f))
    for k in ("exif", "xmp", "c2pa", "text"):
        check("A1 detector sees %s" % k, k in kinds, str(sorted(kinds)))
    clean_dir = os.path.join(tmp, "clean")
    os.makedirs(clean_dir)
    bad_meta = bad_pix = 0
    min_ssim = 1.0
    for f in files:
        out = os.path.join(clean_dir, os.path.basename(f))
        SM.scrub_file(f, out)
        if SM.scan(out):
            bad_meta += 1
        ex = SM.exiftool_findings(out)
        if ex:
            bad_meta += 1
        same, s = SM.verify_pixels(f, out)
        min_ssim = min(min_ssim, s)
        if not same:
            bad_pix += 1
        with Image.open(out) as im:                      # still a valid file for the engine's decoder
            im.load()
            if im.info.get("exif") or im.info.get("xmp") or im.info.get("XML:com.adobe.xmp") or im.info.get("parameters"):
                bad_meta += 1
    check("A1 0 of 20 files keep metadata after the scrub%s" % ("" if SM.exiftool_findings(os.path.join(clean_dir, os.path.basename(files[0]))) is not None else " (own parser; exiftool absent)"),
          bad_meta == 0, "dirty=%d" % bad_meta)
    check("A1 pixels identical on 20/20 (SSIM %.4f)" % min_ssim, bad_pix == 0 and min_ssim == 1.0, "different=%d" % bad_pix)
    # idempotent and a no-op on clean input
    out = os.path.join(clean_dir, os.path.basename(files[0]))
    b1 = open(out, "rb").read()
    SM.scrub_file(out)
    check("A1 scrub of a clean file leaves it byte-identical", open(out, "rb").read() == b1)
    # real project asset: cutout PNG and lossy WebP survive
    real = [os.path.join(A.GAME, "assets", "hero", "mc.png")]
    for p in real:
        if os.path.exists(p):
            o = os.path.join(clean_dir, "real_" + os.path.basename(p))
            SM.scrub_file(p, o)
            same, _ = SM.verify_pixels(p, o)
            check("A1 real asset %s scrubs losslessly" % os.path.basename(p), same and not SM.scan(o))
    # colour chunks survive (they carry no provenance but change rendering)
    im = soft_art(99, 64, 64)
    b = io.BytesIO(); im.save(b, "PNG")
    d = b.getvalue(); k = d.index(b"IDAT") - 4
    d = d[:k] + _png_chunk(b"gAMA", struct.pack(">I", 45455)) + _png_chunk(b"sRGB", b"\0") + _png_chunk(b"pHYs", struct.pack(">IIB", 2835, 2835, 1)) + _png_chunk(b"tEXt", b"a\0b") + d[k:]
    clean, found, _ = SM.scrub_bytes(d)
    check("A1 PNG gAMA/sRGB/pHYs kept, tEXt dropped", all(t in clean for t in (b"gAMA", b"sRGB", b"pHYs")) and b"tEXt" not in clean and found == ["text"], str(found))
    jb = io.BytesIO(); im.convert("RGB").save(jb, "JPEG", icc_profile=b"ICC_PROFILE\0\x01\x01" + b"\0" * 20)
    clean, found, _ = SM.scrub_bytes(jb.getvalue())
    check("A1 JPEG ICC profile (APP2) kept", b"ICC_PROFILE" in clean and found == [], str(found))


# ------------------------------------------------------------------ A2
def test_audit(tmp):
    n = 1536
    fig = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(fig)
    d.ellipse([560, 80, 980, 480], fill=(240, 200, 190, 255))       # head
    d.rectangle([600, 480, 940, 1100], fill=(190, 120, 170, 255))    # body
    d.rectangle([600, 1100, 700, 1500], fill=(230, 200, 190, 255))   # legs
    d.rectangle([840, 1100, 940, 1500], fill=(230, 200, 190, 255))
    p = os.path.join(tmp, "fig1536.png")
    fig.save(p)
    out = os.path.join(tmp, "aud")
    t = time.time()
    m = AC.make_audit(p, out)
    dt = time.time() - t
    check("A2 audit_crops 1536x1536: %d crops (>= 6)" % len(m["crops"]), len(m["crops"]) >= 6)
    check("A2 contact sheet in %.2fs (< 5 s)" % dt, dt < 5.0 and os.path.getsize(m["contact_sheet"]) > 5000)
    parts = {c["part"] for c in m["crops"]}
    check("A2 hands, fingers and feet are all present", {"hand_l", "hand_r", "fingers_l", "fingers_r", "foot_l", "foot_r"} <= parts, str(sorted(parts)))
    bb = m["subject_bbox"]
    check("A2 subject bbox follows alpha", bb[1] < 120 and bb[3] > 1450 and 500 < bb[0] < 640, str(bb))
    # opaque image (no alpha), plain background
    op = Image.new("RGB", (n, n), (235, 235, 240))
    ImageDraw.Draw(op).rectangle([500, 100, 1000, 1450], fill=(150, 90, 120))
    p2 = os.path.join(tmp, "opaque1536.png")
    op.save(p2)
    m2 = AC.make_audit(p2, out)
    check("A2 opaque image: bbox from background difference", abs(m2["subject_bbox"][0] - 500) < 40 and abs(m2["subject_bbox"][3] - 1450) < 40, str(m2["subject_bbox"]))
    # landmarks override
    lm = os.path.join(tmp, "lm.json")
    json.dump({"hand_l": [300, 900], "foot_r": [900, 1450]}, open(lm, "w"))
    m3 = AC.make_audit(p, os.path.join(tmp, "aud_lm"), json.load(open(lm)))
    hl = [c for c in m3["crops"] if c["part"] == "hand_l"][0]["box"]
    check("A2 landmark replaces the prior window", abs((hl[0] + hl[2]) / 2 - 300) < 3 and abs((hl[1] + hl[3]) / 2 - 900) < 3, str(hl))


# ------------------------------------------------------------------ watermark detector
def _mark(im, kind, alpha):
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    n = im.size[0]
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", int(n * 0.03))
    except Exception:
        f = ImageFont.load_default()
    A_ = int(255 * alpha)
    if kind == "text":
        d.text((n - int(n * 0.30), n - int(n * 0.06)), "AI generated", font=f, fill=(255, 255, 255, A_))
    else:
        cx, cy, R = n - int(n * 0.06), n - int(n * 0.06), int(n * 0.03)
        d.polygon([(cx, cy - R), (cx + R // 5, cy - R // 5), (cx + R, cy), (cx + R // 5, cy + R // 5), (cx, cy + R),
                   (cx - R // 5, cy + R // 5), (cx - R, cy), (cx - R // 5, cy - R // 5)], fill=(255, 255, 255, A_))
    return Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB")


def test_watermark(tmp, quick):
    if quick:
        return
    n = 1536
    res = {"text": 0, "sparkle": 0}
    for kind in res:
        for s in range(3):
            p = os.path.join(tmp, "wm_%s_%d.png" % (kind, s))
            _mark(soft_art(s, n, n), kind, 0.5).save(p)
            res[kind] += int(WM.scan_image(p)["flagged"])
    check("WM text mark 'AI generated' (50%% alpha) flagged %d/3" % res["text"], res["text"] == 3)
    check("WM corner sparkle (50%% alpha) flagged %d/3" % res["sparkle"], res["sparkle"] == 3)
    fp = 0
    for s in range(4):
        p = os.path.join(tmp, "wm_clean_%d.png" % s)
        soft_art(60 + s, n, n).save(p)
        fp += int(WM.scan_image(p)["flagged"])
    check("WM clean art not flagged (%d/4 false positives)" % fp, fp == 0)
    # production art sample: false-positive rate on shipped files
    sample = [os.path.join(A.GAME, "assets", x) for x in
              ("hero/mc.png", "hero/rin.png", "hero/hana.png", "hero/nova.png", "hero/yue.png", "bg/bg_festival.webp",
               "bg/bg_street.webp", "bg/bg_palace.webp", "ui/banner_neon.webp", "bg/victory.webp")]
    sample = [p for p in sample if os.path.exists(p)]
    flagged = [os.path.basename(p) for p in sample if WM.scan_image(p)["flagged"]]
    check("WM shipped art sample: %d/%d flagged (<= 1 tolerated)" % (len(flagged), len(sample)), len(flagged) <= 1, str(flagged))
    # transparent cutout: silhouette edge is not a mark
    cut = soft_art(7, 768, 1024, alpha=True)
    p = os.path.join(tmp, "cutout.png")
    cut.save(p)
    check("WM transparent cut-out silhouette not flagged", not WM.scan_image(p)["flagged"])


# ------------------------------------------------------------------ A3 (approve + release gate)
def mk_game(tmp, name="g"):
    """Minimal game tree: manifest with approved rows, two presets (one with an exclude_filter)."""
    game = os.path.join(tmp, name, "game")
    os.makedirs(os.path.join(game, "assets", "manifest"))
    os.makedirs(os.path.join(game, "assets", "bg"))
    rows = []
    for i, nm in enumerate(("a", "b", "c")):
        p = os.path.join(game, "assets", "bg", nm + ".png")
        soft_art(i, 64, 64).save(p)
        rows.append({"id": "bg." + nm, "path": "res://assets/bg/%s.png" % nm, "kind": "image", "group": "art",
                     "md5": A.md5_file(p), "bytes": os.path.getsize(p), "px": "64x64", "dup_of": None,
                     "status": "approved", "referenced_by": []})
    doc = {"schema": 1, "generator": "t", "count": 3, "statuses": A.STATUSES, "assets": rows}
    mp = os.path.join(game, "assets", "manifest", "assets.json")
    A.save_manifest(doc, mp)
    open(os.path.join(game, "export_presets.cfg"), "w").write(
        '[preset.0]\n\nname="Android"\nexport_filter="all_resources"\nexclude_filter="assets/manifest/assets.json, assets/bg/excl_*"\n\n'
        '[preset.0.options]\n\nx=1\n\n'
        '[preset.1]\n\nname="Android-store"\nexport_filter="all_resources"\nexclude_filter="assets/manifest/assets.json, assets/bg/excl_*"\n\n[preset.1.options]\n\n')
    return game, mp


def run(args):
    r = subprocess.run([PY, os.path.join(HERE, args[0])] + args[1:], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def rows_changed(before_text, after_text):
    b, a = json.loads(before_text)["assets"], json.loads(after_text)["assets"]
    bm = {r["id"]: r for r in b}
    return [r["id"] for r in a if bm.get(r["id"]) != r] + [r["id"] for r in b if r["id"] not in {x["id"] for x in a}]


def test_gate(tmp):
    game, mp = mk_game(tmp)
    rc, out = run(["check_release.py", "--manifest", mp])
    check("A3 baseline tree passes the release gate", rc == 0, out)
    # --- register a generated image carrying metadata and a watermark-free body
    src = os.path.join(tmp, "gen_new.png")
    open(src, "wb").write(png_with_meta(soft_art(5, 256, 256), 2))
    t0 = open(mp).read()
    rc, out = run(["approve.py", "--manifest", mp, "register", src, "--dest", "res://assets/bg/new.png", "--source", "test-model", "--prompt-hash", "abc123"])
    check("A3 register -> status=generated", rc == 0 and "status=generated" in out, out)
    t1 = open(mp).read()
    doc = json.loads(t1)
    row = A.row_by_id(doc, "bg.new") or {}
    check("A3 register adds exactly one row, 3 old rows untouched", rows_changed(t0, t1) == ["bg.new"] and len(doc["assets"]) == 4)
    inc = os.path.join(game, "assets", "incoming")
    inc_files = [f for f in os.listdir(inc) if f != ".gdignore"]
    check("A3 file waits in incoming/ (with .gdignore), not at its final path",
          os.path.exists(os.path.join(inc, ".gdignore")) and len(inc_files) == 1 and not os.path.exists(os.path.join(game, "assets/bg/new.png")))
    check("A3 incoming file is already scrubbed (metadata removed: %s)" % ",".join(row.get("scrubbed", [])),
          not SM.scan(os.path.join(inc, inc_files[0])) and "c2pa" in ",".join(row.get("scrubbed", [])))
    check("A3 sorted by path as gen_manifest writes", [r["path"] for r in doc["assets"]] == sorted(r["path"] for r in doc["assets"]))
    rc, out = run(["check_release.py", "--manifest", mp])
    check("A3 example 1: generated art waiting in incoming/ -> gate OK", rc == 0, out)
    # --- approve gates
    rc, out = run(["approve.py", "--manifest", mp, "approve", "bg.new", "--by", "AD"])
    check("A3 approve without --audited is refused", rc != 0 and "--audited" in out, out)
    rc, out = run(["approve.py", "--manifest", mp, "audit", "bg.new", "-o", os.path.join(tmp, "aud_cli")])
    check("A3 audit CLI makes the contact sheet", rc == 0 and os.path.exists(os.path.join(tmp, "aud_cli", os.path.basename(inc_files[0]).rsplit(".", 1)[0], "contact_sheet.jpg")), out)
    # tamper -> md5 refusal
    tf = os.path.join(inc, inc_files[0])
    keep = open(tf, "rb").read()
    open(tf, "ab").write(b"x")
    rc, out = run(["approve.py", "--manifest", mp, "approve", "bg.new", "--by", "AD", "--audited"])
    check("A3 approve refuses a file modified after registration", rc != 0 and "md5" in out, out)
    open(tf, "wb").write(keep)
    t2 = open(mp).read()
    rc, out = run(["approve.py", "--manifest", mp, "approve", "bg.new", "--by", "AD", "--audited"])
    t3 = open(mp).read()
    check("A3 approve OK", rc == 0 and "APPROVED" in out, out)
    ch = rows_changed(t2, t3)
    check("A3 approve changes exactly ONE manifest row (%s)" % ch, ch == ["bg.new"])
    # one row, textual diff: only that row's lines differ
    import difflib
    d = [l for l in difflib.unified_diff(t2.splitlines(), t3.splitlines(), lineterm="", n=0) if l[:1] in "+-" and l[:3] not in ("+++", "---")]
    check("A3 text diff is confined to that row (%d lines)" % len(d), 0 < len(d) <= 8, "\n".join(d))
    doc3 = json.loads(t3)
    r3 = A.row_by_id(doc3, "bg.new")
    check("A3 row now approved, final path, no src, approver recorded", r3["status"] == "approved" and "src" not in r3 and r3.get("approved_by") == "AD")
    check("A3 file moved to its final path, incoming empty",
          os.path.exists(os.path.join(game, "assets/bg/new.png")) and not [f for f in os.listdir(inc) if f != ".gdignore"])
    rc, out = run(["check_release.py", "--manifest", mp])
    check("A3 gate OK after approval", rc == 0, out)
    rc, out = run(["approve.py", "--manifest", mp, "approve", "bg.new", "--by", "AD", "--audited"])
    check("A3 approving an approved row is refused", rc != 0)
    # --- watermark gate on approve
    wsrc = os.path.join(tmp, "gen_wm.png")
    _mark(soft_art(3, 1024, 1024), "text", 0.8).save(wsrc)
    rc, out = run(["approve.py", "--manifest", mp, "register", wsrc, "--dest", "res://assets/bg/wm.png"])
    check("A3 register records watermark=flagged", rc == 0 and "watermark=flagged" in out, out)
    rc, out = run(["approve.py", "--manifest", mp, "approve", "bg.wm", "--by", "AD", "--audited"])
    check("A3 approve refuses flagged watermark", rc != 0 and "watermark" in out, out)
    rc, out = run(["approve.py", "--manifest", mp, "reject", "bg.wm", "--reason", "watermark"])
    check("A3 reject keeps the row as record and deletes the incoming file",
          rc == 0 and A.row_by_id(A.load_manifest(mp), "bg.wm")["status"] == "rejected" and not [f for f in os.listdir(inc) if f != ".gdignore"], out)
    rc, out = run(["check_release.py", "--manifest", mp])
    check("A3 rejected row without a file -> gate OK", rc == 0, out)

    # --- release gate examples (3 required, more for coverage), each on a fresh tree
    def fresh(label):
        g, m = mk_game(tmp, label)
        return g, m

    # example 2: a pending row whose file sits at a shipped path
    g, m = fresh("ex2")
    doc = A.load_manifest(m); doc["assets"][1]["status"] = "pending"; A.save_manifest(doc, m)
    rc, out = run(["check_release.py", "--manifest", m])
    check("A3 example 2: status=pending file at a shipped path -> gate FAILS (R1)", rc == 1 and "R1" in out and "bg.b" in out, out)
    # example 3: same, but excluded from every preset by exclude_filter -> OK
    g, m = fresh("ex3")
    os.rename(os.path.join(g, "assets/bg/c.png"), os.path.join(g, "assets/bg/excl_c.png"))
    doc = A.load_manifest(m)
    doc["assets"][2]["path"] = "res://assets/bg/excl_c.png"
    doc["assets"][2]["status"] = "rejected"
    A.save_manifest(doc, m)
    rc, out = run(["check_release.py", "--manifest", m])
    check("A3 example 3: rejected file excluded in all presets -> gate OK", rc == 0, out)
    # example 4: excluded in only one preset
    g, m = fresh("ex4")
    cfg = open(os.path.join(g, "export_presets.cfg")).read().replace('exclude_filter="assets/manifest/assets.json, assets/bg/excl_*"\n\n[preset.1.options]', 'exclude_filter="assets/manifest/assets.json"\n\n[preset.1.options]')
    open(os.path.join(g, "export_presets.cfg"), "w").write(cfg)
    os.rename(os.path.join(g, "assets/bg/c.png"), os.path.join(g, "assets/bg/excl_c.png"))
    doc = A.load_manifest(m); doc["assets"][2]["path"] = "res://assets/bg/excl_c.png"; doc["assets"][2]["status"] = "rejected"; A.save_manifest(doc, m)
    rc, out = run(["check_release.py", "--manifest", m])
    check("A3 example 4: excluded from one preset only -> gate FAILS naming the other", rc == 1 and "Android-store" in out, out)
    # example 5: incoming without .gdignore
    g, m = fresh("ex5")
    s2 = os.path.join(tmp, "gen5.png"); open(s2, "wb").write(png_with_meta(soft_art(9, 128, 128), 0))
    run(["approve.py", "--manifest", m, "register", s2, "--dest", "res://assets/bg/five.png"])
    os.remove(os.path.join(g, "assets/incoming/.gdignore"))
    rc, out = run(["check_release.py", "--manifest", m])
    check("A3 example 5: incoming/ without .gdignore -> gate FAILS (R1/R5)", rc == 1 and "R5" in out and "R1" in out, out)
    # example 6: unregistered file in assets/ (directory inclusion)
    g, m = fresh("ex6")
    soft_art(1, 32, 32).save(os.path.join(g, "assets/bg/sneaky.png"))
    rc, out = run(["check_release.py", "--manifest", m])
    check("A3 example 6: unregistered art file in assets/ -> gate FAILS (R2)", rc == 1 and "R2" in out and "sneaky" in out, out)
    # example 7: include list with a generated id
    g, m = fresh("ex7")
    s3 = os.path.join(tmp, "gen7.png"); open(s3, "wb").write(png_with_meta(soft_art(11, 128, 128), 1))
    run(["approve.py", "--manifest", m, "register", s3, "--dest", "res://assets/bg/seven.png"])
    il = os.path.join(tmp, "include.txt"); open(il, "w").write("res://assets/bg/a.png\nres://assets/bg/seven.png\n")
    rc, out = run(["check_release.py", "--manifest", m, "--include-list", il])
    check("A3 example 7: release include list containing a generated asset -> gate FAILS (R6)", rc == 1 and "R6" in out, out)
    # example 8: approved row whose bytes changed
    g, m = fresh("ex8")
    open(os.path.join(g, "assets/bg/a.png"), "ab").write(b"0")
    rc, out = run(["check_release.py", "--manifest", m])
    check("A3 example 8: approved file changed behind the manifest -> gate FAILS (R3)", rc == 1 and "R3" in out, out)


def test_regen(tmp):
    """gen_manifest keeps status=generated rows (incoming/ is not walked) and stays in sync after approve."""
    game, mp = mk_game(tmp, "regen")
    root = os.path.dirname(game)
    os.makedirs(os.path.join(root, "tools", "assets"))
    shutil.copy(os.path.join(A.REPO, "tools", "assets", "gen_manifest.py"), os.path.join(root, "tools", "assets", "gen_manifest.py"))
    gm = os.path.join(root, "tools", "assets", "gen_manifest.py")
    def regen(*extra):
        r = subprocess.run([PY, gm] + list(extra), capture_output=True, text=True)
        return r.returncode, r.stdout + r.stderr
    rc, _ = regen()
    check("REGEN gen_manifest runs on the test tree", rc == 0)
    src = os.path.join(tmp, "gen_rg.png"); open(src, "wb").write(png_with_meta(soft_art(4, 128, 128), 0))
    run(["approve.py", "--manifest", mp, "register", src, "--dest", "res://assets/bg/rg.png"])
    before = open(mp).read()
    rc, out = regen()
    after = open(mp).read()
    check("REGEN regeneration keeps the generated row verbatim and does not re-register incoming/ files", rc == 0 and before == after, out)
    rc, out = regen("--check")
    check("REGEN --check passes with a generated row waiting", rc == 0, out)
    rc, out = run(["approve.py", "--manifest", mp, "approve", "bg.rg", "--by", "AD", "--audited"])
    rc2, out2 = regen("--check")
    st = A.row_by_id(A.load_manifest(mp), "bg.rg")
    # approve adds approved_by / watermark fields that the generator would not write: regeneration must keep them
    rc3, _ = regen()
    st2 = A.row_by_id(A.load_manifest(mp), "bg.rg")
    check("REGEN after approve: row stays approved at its path and keeps approved_by/watermark", rc == 0 and st2["status"] == "approved" and st2["path"] == "res://assets/bg/rg.png" and st2.get("approved_by") == "AD" and st2.get("watermark") == "clean", str(st2))
    check("REGEN --check passes after approve+regen", regen("--check")[0] == 0)


def test_repo(quick):
    rc, out = run(["check_release.py"])
    check("REPO real manifest: release gate OK (%s)" % out.strip().splitlines()[-1][:80], rc == 0, out[-400:])
    r = subprocess.run([PY, os.path.join(A.REPO, "tools", "assets", "gen_manifest.py"), "--check"], capture_output=True, text=True)
    check("REPO gen_manifest --check (manifest in sync, incoming/ skipped)", r.returncode == 0, r.stdout + r.stderr)


def main():
    quick = "--quick" in sys.argv
    tmp = tempfile.mkdtemp(prefix="p58_")
    t0 = time.time()
    try:
        test_scrub(tmp)
        test_audit(tmp)
        test_watermark(tmp, quick)
        test_gate(tmp)
        test_regen(tmp)
        test_repo(quick)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("ART_PIPELINE %d/%d (%.1fs)" % (len(OKS), len(TOTAL), time.time() - t0))
    sys.exit(0 if len(OKS) == len(TOTAL) else 1)


if __name__ == "__main__":
    main()
