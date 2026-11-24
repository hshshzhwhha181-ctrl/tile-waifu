#!/usr/bin/env python3
"""Rebuild game/assets/v10/fonts/ from raw google/fonts files.

Usage (from anywhere; needs `pip install fonttools brotli`):
    python3 -I build_fonts.py <download_dir> <game/assets/v10/fonts>

<download_dir> holds google/fonts `ofl/<dir>/` folders exactly as on GitHub
(https://raw.githubusercontent.com/google/fonts/main/ofl/<dir>/<file>), see FONTS below.

Rules (docs/0.10-spec.md D2):
  * OFL.txt is copied next to every font.
  * A font whose OFL.txt declares a Reserved Font Name is shipped byte-for-byte (no subset,
    no format change), because a modified copy may not carry the reserved name.
  * Every other font is pinned to one weight (variable -> static instance), subset to
    Latin-1 + Cyrillic + typographic punctuation + №/₽, all OpenType layout features kept,
    and written as WOFF2.
"""
import os, re, shutil, sys

from fontTools.ttLib import TTFont
from fontTools import subset
from fontTools.varLib import instancer

# out_dir, google dir, source file, out name, wght (None = static), extra axes
FONTS = [
    ("ruslan_display", "ruslandisplay", "RuslanDisplay-Regular.ttf", None, None, {}),
    ("kurale", "kurale", "Kurale-Regular.ttf", "kurale.woff2", None, {}),
    ("cormorant_infant", "cormorantinfant", "CormorantInfant-Italic[wght].ttf", "cormorant-infant-i600.woff2", 600, {}),
    ("great_vibes", "greatvibes", "GreatVibes-Regular.ttf", "great-vibes.woff2", None, {}),
    ("russo_one", "russoone", "RussoOne-Regular.ttf", None, None, {}),
    ("exo2", "exo2", "Exo2[wght].ttf", "exo2-600.woff2", 600, {}),
    ("yeseva_one", "yesevaone", "YesevaOne-Regular.ttf", None, None, {}),
    ("cormorant_garamond", "cormorantgaramond", "CormorantGaramond-Italic[wght].ttf", "cormorant-garamond-i500.woff2", 500, {}),
    ("philosopher", "philosopher", "Philosopher-Bold.ttf", "philosopher-700.woff2", None, {}),
    ("jura", "jura", "Jura[wght].ttf", "jura-600.woff2", 600, {}),
    ("caveat", "caveat", "Caveat[wght].ttf", "caveat-600.woff2", 600, {}),
    ("neucha", "neucha", "Neucha.ttf", "neucha.woff2", None, {}),
    ("tenor_sans", "tenorsans", "TenorSans-Regular.ttf", None, None, {}),
    ("unbounded", "unbounded", "Unbounded[wght].ttf", "unbounded-700.woff2", 700, {}),
    # The 0.8 nunito-cyr/-lat subsets have no ₽ (U+20BD): a tiny variable Nunito with just the
    # price symbols closes every fallback chain (wght axis kept so 800/900 still match).
    ("nunito_sym", "nunito", "Nunito[wght].ttf", "nunito-sym.woff2", "var", {}),
]
SYM_UNICODES = "U+0020,U+00A0,U+00D7,U+2116,U+20BD,U+20AC,U+2212,U+2009,U+202F"
# Existing res://assets/fonts/*.woff2 (0.8) only get their licence copied.
LICENCE_ONLY = [("nunito", "nunito"), ("playfair_display", "playfairdisplay")]

UNICODES = (
    "U+0020-007E,U+00A0-00FF,U+0131,U+0152-0153,U+02C6,U+02DA,U+02DC,"
    "U+0400-045F,U+0490-0491,U+2010-2027,U+2030-203A,U+2044,U+20AC,U+20BD,"
    "U+2116,U+2122,U+2190-2193,U+2212,U+2215,U+2605-2606,U+2665,U+2661"
)


def has_rfn(ofl_path: str) -> bool:
    # the copyright header says «with Reserved Font Name "X"»; the licence body always mentions the
    # term itself, so only the header form counts
    head = open(ofl_path, encoding="utf-8", errors="replace").read(1200)
    return re.search(r"with\s+Reserved\s+Font\s+Names?", head, re.I) is not None


def main(src: str, dst: str) -> None:
    os.makedirs(dst, exist_ok=True)
    for out_dir, gdir, fname, out_name, wght, axes in FONTS:
        sdir = os.path.join(src, gdir)
        odir = os.path.join(dst, out_dir)
        os.makedirs(odir, exist_ok=True)
        ofl = os.path.join(sdir, "OFL.txt")
        shutil.copyfile(ofl, os.path.join(odir, "OFL.txt"))
        sp = os.path.join(sdir, fname)
        if has_rfn(ofl):
            if out_name:
                raise SystemExit(f"{fname}: Reserved Font Name -> must ship unmodified, set out_name None")
            shutil.copyfile(sp, os.path.join(odir, fname))
            print(f"RFN  {out_dir}/{fname} {os.path.getsize(sp)}")
            continue
        f = TTFont(sp)
        if "fvar" in f and wght != "var":
            loc = dict(axes)
            for a in f["fvar"].axes:
                if a.axisTag == "wght":
                    loc["wght"] = wght if wght else a.defaultValue
                elif a.axisTag not in loc:
                    loc[a.axisTag] = a.defaultValue
            f = instancer.instantiateVariableFont(f, loc, updateFontNames=False)
        opts = subset.Options()
        opts.layout_features = ["*"]
        opts.name_IDs = ["*"]
        opts.name_languages = ["*"]
        opts.notdef_outline = True
        opts.glyph_names = False
        opts.hinting = False
        opts.flavor = "woff2"
        sub = subset.Subsetter(opts)
        sub.populate(unicodes=subset.parse_unicodes(SYM_UNICODES if wght == "var" else UNICODES))
        sub.subset(f)
        op = os.path.join(odir, out_name)
        subset.save_font(f, op, opts)
        print(f"SUB  {out_dir}/{out_name} {os.path.getsize(sp)} -> {os.path.getsize(op)}")
    lic = os.path.join(dst, "licenses")
    os.makedirs(lic, exist_ok=True)
    for name, gdir in LICENCE_ONLY:
        shutil.copyfile(os.path.join(src, gdir, "OFL.txt"), os.path.join(lic, f"{name}_OFL.txt"))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
