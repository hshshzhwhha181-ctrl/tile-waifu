#!/usr/bin/env python3
"""P58: lossless metadata scrub for PNG / JPEG / WebP (EXIF, XMP, IPTC, text chunks, C2PA/JUMBF, comments, thumbnails).

The scrub works on the container, never on pixels: unwanted chunks/segments are dropped and everything else is copied
byte for byte, so the decoded pixels are bit-identical (SSIM 1.0 by construction; `verify_pixels` proves it).
Colour chunks that affect rendering (PNG sRGB/gAMA/cHRM/iCCP/pHYs/sBIT, JPEG ICC in APP2, JFIF/Adobe markers, WebP ICCP)
are kept: they carry no provenance.  Anything after the end of the image data (PNG IEND / JPEG EOI / RIFF size) is dropped.

usage: scrub_metadata.py [--check] [--in-place | -o OUT] FILE...
  --check     report only; exit 1 when any file still carries metadata
  --in-place  overwrite the file (only when something was removed)
  default     write FILE next to the input as FILE.scrubbed.EXT unless -o is given (single input)
Optional cross-check with exiftool when it is installed (`exiftool_findings`).
"""
import argparse, os, shutil, struct, subprocess, sys

PNG_SIG = b"\x89PNG\r\n\x1a\n"
PNG_KEEP = {b"IHDR", b"PLTE", b"IDAT", b"IEND", b"tRNS", b"gAMA", b"cHRM", b"sRGB", b"iCCP", b"sBIT", b"pHYs",
            b"bKGD", b"hIST", b"sPLT", b"acTL", b"fcTL", b"fdAT", b"cICP", b"mDCV", b"cLLI"}
PNG_META = {b"tEXt": "text", b"zTXt": "text", b"iTXt": "text", b"eXIf": "exif", b"tIME": "time",
            b"caBX": "c2pa", b"c2pa": "c2pa", b"jUMB": "c2pa", b"iDOT": "other"}
XMP_MAGIC = b"http://ns.adobe.com/xap/1.0/"
XMP_EXT = b"http://ns.adobe.com/xmp/extension/"
WEBP_KEEP = {b"VP8 ", b"VP8L", b"VP8X", b"ALPH", b"ANIM", b"ANMF", b"ICCP"}
WEBP_META = {b"EXIF": "exif", b"XMP ": "xmp", b"C2PA": "c2pa"}


def fmt_of(data):
    if data[:8] == PNG_SIG:
        return "png"
    if data[:3] == b"\xff\xd8\xff":
        return "jpeg"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "webp"
    return None


# ---------------------------------------------------------------- PNG
def _png_chunks(d):
    i = 8
    while i + 8 <= len(d):
        ln = struct.unpack(">I", d[i:i + 4])[0]
        typ = d[i + 4:i + 8]
        end = i + 12 + ln
        if end > len(d):
            raise ValueError("truncated PNG chunk %r" % typ)
        yield typ, d[i:end]
        i = end
        if typ == b"IEND":
            break
    return


def _png(d):
    keep, found = [PNG_SIG], []
    end = 8
    for typ, raw in _png_chunks(d):
        end += len(raw)
        if typ in PNG_KEEP:
            keep.append(raw)
        else:
            found.append(PNG_META.get(typ, "other:" + typ.decode("latin1")))
    if end < len(d):
        found.append("trailing:%d" % (len(d) - end))
    return b"".join(keep), found


# ---------------------------------------------------------------- JPEG
def _jpeg(d):
    out, found = [d[:2]], []
    i = 2
    n = len(d)
    while i < n:
        if d[i] != 0xFF:
            raise ValueError("bad JPEG marker at %d" % i)
        while i < n and d[i] == 0xFF:
            i += 1
        m = d[i]
        i += 1
        if m == 0xD9:                      # EOI
            out.append(b"\xff\xd9")
            i_end = i
            if i_end < n:
                found.append("trailing:%d" % (n - i_end))
            return b"".join(out), found
        if m == 0x01 or 0xD0 <= m <= 0xD7:  # standalone
            out.append(bytes([0xFF, m]))
            continue
        ln = struct.unpack(">H", d[i:i + 2])[0]
        seg = d[i + 2:i + ln]
        full = bytes([0xFF, m]) + d[i:i + ln]
        if m == 0xDA:                      # SOS: entropy data follows until the next real marker
            j = i + ln
            while j < n - 1:
                if d[j] == 0xFF and d[j + 1] != 0x00 and not (0xD0 <= d[j + 1] <= 0xD7):
                    break
                j += 1
            out.append(full + d[i + ln:j])
            i = j
            continue
        drop = None
        if m == 0xFE:
            drop = "comment"
        elif m == 0xE1:
            drop = "xmp" if seg.startswith((XMP_MAGIC, XMP_EXT)) else "exif"
        elif m == 0xEB:
            drop = "c2pa"                  # APP11 = JUMBF (C2PA manifest store)
        elif m == 0xED:
            drop = "iptc"                  # APP13 Photoshop / IPTC
        elif m == 0xE2 and not seg.startswith(b"ICC_PROFILE"):
            drop = "app2"
        elif m in (0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEC, 0xEF):
            drop = "app%d" % (m - 0xE0)
        elif m == 0xE0 and not seg.startswith((b"JFIF\0", b"JFXX\0")):
            drop = "app0"
        if drop:
            found.append(drop)
        else:
            out.append(full)
        i += ln
    return b"".join(out), found


# ---------------------------------------------------------------- WebP
def _webp(d):
    riff_len = struct.unpack("<I", d[4:8])[0]
    body_end = min(len(d), 8 + riff_len)
    found = []
    if body_end < len(d):
        found.append("trailing:%d" % (len(d) - body_end))
    i = 12
    chunks = []
    while i + 8 <= body_end:
        typ = d[i:i + 4]
        ln = struct.unpack("<I", d[i + 4:i + 8])[0]
        pad = ln & 1
        raw = d[i:i + 8 + ln + pad]
        if typ in WEBP_KEEP:
            chunks.append([typ, raw])
        else:
            found.append(WEBP_META.get(typ, "other:" + typ.decode("latin1")))
        i += 8 + ln + pad
    kept_types = {t for t, _ in chunks}
    out = []
    for typ, raw in chunks:
        if typ == b"VP8X":
            flags = raw[8]
            if b"EXIF" not in kept_types:
                flags &= ~0x08
            flags &= ~0x04                  # XMP flag off
            if b"ICCP" not in kept_types:
                flags &= ~0x20
            raw = raw[:8] + bytes([flags]) + raw[9:]
        out.append(raw)
    body = b"WEBP" + b"".join(out)
    return b"RIFF" + struct.pack("<I", len(body)) + body, found


def scrub_bytes(data):
    """-> (clean_bytes, findings, fmt).  findings = [] means the file was already clean."""
    f = fmt_of(data)
    if f == "png":
        out, found = _png(data)
    elif f == "jpeg":
        out, found = _jpeg(data)
    elif f == "webp":
        out, found = _webp(data)
    else:
        raise ValueError("unsupported format")
    return out, found, f


def scan_bytes(data):
    return scrub_bytes(data)[1]


def scan(path):
    with open(path, "rb") as fh:
        return scan_bytes(fh.read())


def scrub_file(src, dst=None):
    """Scrub src -> dst (default in place).  Returns the findings that were removed."""
    with open(src, "rb") as fh:
        data = fh.read()
    clean, found, _ = scrub_bytes(data)
    if dst is None:
        if not found:
            return found
        dst = src
    tmp = dst + ".tmp"
    with open(tmp, "wb") as fh:
        fh.write(clean)
    os.replace(tmp, dst)
    return found


def exiftool_findings(path):
    """Metadata tags exiftool reports beyond the file-system / structural groups; None when exiftool is not installed."""
    exe = shutil.which("exiftool")
    if not exe:
        return None
    r = subprocess.run([exe, "-s", "-G1", "-a", "-u", "-j", path], capture_output=True, text=True)
    import json
    try:
        tags = json.loads(r.stdout)[0]
    except Exception:
        return ["exiftool-unreadable"]
    bad = []
    for k in tags:
        grp = k.split(":")[0]
        if grp in ("ExifTool", "System", "File", "SourceFile", "PNG", "PNG-pHYs", "Composite", "JFIF", "RIFF", "VP8", "VP8L",
                   "ICC-header", "ICC_Profile", "ICC-view", "ICC-meas", "ICC-chrm", "Photoshop", "ICC-profile") and \
                not k.startswith(("PNG:Comment", "PNG:Software", "PNG:Description", "PNG:Parameters")):
            continue
        bad.append(k)
    return bad


def verify_pixels(path_a, path_b):
    """True when two images decode to identical RGBA pixels (PIL); also returns the SSIM (1.0 when identical)."""
    from PIL import Image
    import numpy as np
    a = np.asarray(Image.open(path_a).convert("RGBA"))
    b = np.asarray(Image.open(path_b).convert("RGBA"))
    if a.shape != b.shape:
        return False, 0.0
    same = bool((a == b).all())
    return same, (1.0 if same else ssim(a, b))


def ssim(a, b, win=8):
    """Plain block SSIM on luma (no scipy); 1.0 for identical arrays."""
    import numpy as np
    def luma(x):
        x = x.astype("float64")
        return 0.299 * x[..., 0] + 0.587 * x[..., 1] + 0.114 * x[..., 2]
    A, B = luma(a), luma(b)
    h, w = (A.shape[0] // win) * win, (A.shape[1] // win) * win
    A, B = A[:h, :w], B[:h, :w]
    def blocks(x):
        return x.reshape(h // win, win, w // win, win).transpose(0, 2, 1, 3).reshape(-1, win * win)
    A, B = blocks(A), blocks(B)
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    ma, mb = A.mean(1), B.mean(1)
    va, vb = A.var(1), B.var(1)
    cov = ((A - ma[:, None]) * (B - mb[:, None])).mean(1)
    s = ((2 * ma * mb + c1) * (2 * cov + c2)) / ((ma ** 2 + mb ** 2 + c1) * (va + vb + c2))
    return float(s.mean())


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--in-place", action="store_true")
    ap.add_argument("-o", "--out")
    a = ap.parse_args(argv)
    dirty = 0
    for f in a.files:
        try:
            found = scan(f)
        except ValueError as e:
            print("SKIP %s: %s" % (f, e))
            continue
        if found:
            dirty += 1
        if a.check:
            print("%s %s%s" % ("DIRTY" if found else "CLEAN", f, (" [" + ",".join(found) + "]") if found else ""))
            continue
        if a.in_place:
            scrub_file(f)
        else:
            dst = a.out if (a.out and len(a.files) == 1) else "%s.scrubbed%s" % os.path.splitext(f)
            scrub_file(f, dst)
        print("SCRUB %s removed=%s" % (f, ",".join(found) or "-"))
    if a.check and dirty:
        sys.exit(1)


if __name__ == "__main__":
    main()
