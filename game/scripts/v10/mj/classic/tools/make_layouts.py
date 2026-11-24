#!/usr/bin/env python3
"""Builds game/data/mj/classic/layouts.json: 12 classic + 10 heroine-symbol forms for «Классика».

Coordinates are explicit half-cell units, exactly like TrayBoard / the Turtle: a tile is 2 units wide and 2 units
tall, (x, y, z) is the tile's top-left in half cells and its layer. A tile at x=7 sits half a tile to the right of
x=6 — that is how the Turtle's head and the pyramid layers are offset.

Portrait first: every form is drawn for a 720x1280 phone held upright (≤ 9 tiles wide, ≤ 15 tall), so a tile is
60–80 px on screen without zoom. Masks are ASCII ('#' = tile) for the ground layer; upper layers come from the
layer recipe: 'a' = aligned interior (a tile on every tile whose 4 neighbours exist), 'o' = offset interior (a tile
over every 2x2 block, half a cell right and down), 'c' = copy of the layer below, or an explicit ASCII mask
(prefix '=' aligned to the ground grid, '+' offset by half a cell).

Run: python3 make_layouts.py [--preview DIR]   (preview PNGs need Pillow)
"""
import json, math, os, sys

OUT = os.path.join(os.path.dirname(__file__), "../../../../../data/mj/classic/layouts.json")

def mask(txt):
    rows = [r for r in txt.strip("\n").split("\n")]
    pos = set()
    for j, r in enumerate(rows):
        for i, ch in enumerate(r.strip() if False else r):
            if ch == "#":
                pos.add((2 * i, 2 * j))
    return pos

def omask(txt):
    return {(x + 1, y + 1) for (x, y) in mask(txt)}

def fmask(cols, rows, fn):
    pos = set()
    for j in range(rows):
        for i in range(cols):
            u = (i - (cols - 1) / 2.0)
            v = (j - (rows - 1) / 2.0)
            if fn(u, v):
                pos.add((2 * i, 2 * j))
    return pos

def aligned(layer):
    return {(x, y) for (x, y) in layer if (x - 2, y) in layer and (x + 2, y) in layer and (x, y - 2) in layer and (x, y + 2) in layer}

def offset(layer):
    return {(x + 1, y + 1) for (x, y) in layer if (x + 2, y) in layer and (x, y + 2) in layer and (x + 2, y + 2) in layer}

def build(ground, recipe, cap=144):
    layers = [set(ground)]
    for step in recipe:
        below = layers[-1]
        if isinstance(step, set):
            nxt = set(step)
        elif step == "a":
            nxt = aligned(below)
        elif step == "o":
            nxt = offset(below)
        elif step == "c":
            nxt = set(below)
        elif step == "ah":  # aligned interior, horizontal only (thin bands)
            nxt = {(x, y) for (x, y) in below if (x - 2, y) in below and (x + 2, y) in below}
        elif step == "av":
            nxt = {(x, y) for (x, y) in below if (x, y - 2) in below and (x, y + 2) in below}
        else:
            raise ValueError(step)
        if not nxt:
            break
        layers.append(nxt)
    pos = []
    for z, L in enumerate(layers):
        for (x, y) in sorted(L, key=lambda p: (p[1], p[0])):
            pos.append([x, y, z])
    return pos

def supported(p, allpos):
    x, y, z = p
    if z == 0:
        return True
    return any(q[2] == z - 1 and abs(q[0] - x) < 2 and abs(q[1] - y) < 2 for q in allpos)

def trim(pos, target=None):
    """Even count, every upper tile on something; drop the highest, most central single tiles first."""
    pos = [p for p in pos]
    changed = True
    while changed:
        changed = False
        for p in list(pos):
            if not supported(p, pos):
                pos.remove(p)
                changed = True
    lim = target if target else (144 if len(pos) > 144 else len(pos) - (len(pos) % 2))
    lim = min(lim, 144)
    if not target:
        lim -= lim % 2
    xs = [p[0] for p in pos]
    ys = [p[1] for p in pos]
    cx = (min(xs) + max(xs)) / 2.0
    cy = (min(ys) + max(ys)) / 2.0
    while len(pos) > lim:
        # remove from the top layer: the tile farthest from the centre (keeps symmetry better in pairs)
        zt = max(p[2] for p in pos)
        top = [p for p in pos if p[2] == zt and not any(q[2] == zt + 1 for q in pos)]
        top.sort(key=lambda p: (-(abs(p[1] - cy) + abs(p[0] - cx)), p[1], p[0]))
        pos.remove(top[0])
    return pos

# ---------------------------------------------------------------------------------------------------------------
L = []

def add(id, name, kind, ground, recipe, hero="", color="", target=None, line=""):
    pos = trim(build(ground, recipe), target)
    L.append({"id": id, "name": name, "kind": kind, "hero": hero, "color": color, "line": line, "pos": pos})

# 1. Черепаха — the classic 144, turned head-up for a phone held upright (rows of the original become columns).
def turtle():
    widths = [12, 8, 10, 12, 12, 10, 8, 12]
    pos = []
    for r, w in enumerate(widths):
        c0 = (12 - w) // 2
        for c in range(c0, c0 + w):
            pos.append((c, r, 0))
    for c in range(3, 9):
        for r in range(1, 7):
            pos.append((c, r, 1))
    for c in range(4, 8):
        for r in range(2, 6):
            pos.append((c, r, 2))
    for c in range(5, 7):
        for r in range(3, 5):
            pos.append((c, r, 3))
    out = []
    for (c, r, z) in pos:
        out.append([2 * r, 2 * c + 2, z])
    out.append([7, 0, 0])            # head (half a tile between the two middle columns)
    out.append([7, 26, 0])           # tail
    out.append([7, 28, 0])
    out.append([7, 13, 4])           # the crown tile: half offset both ways, over the 2x2
    return out
L.append({"id": "turtle", "name": "Черепаха", "kind": "classic", "hero": "", "color": "#7fc8a9", "line": "", "pos": turtle()})

add("dragon", "Дракон", "classic", mask("""
..###....
.#####...
..#####..
...#####.
....####.
...#####.
..#####..
.#####...
.####....
.#####...
..#####..
...#####.
....###..
.....#...
"""), ["ah", "a", "o"], color="#e0705a")

add("cat", "Кошка", "classic", mask("""
#.....#..
##...##..
#######..
#######..
.#####...
..###....
.#####...
#######..
#######.#
#######.#
#######.#
.#####.##
..######.
"""), ["a", "o", "a"], color="#f2b880")

add("fortress", "Крепость", "classic", mask("""
###.#.###
###...###
#########
#.......#
#.#####.#
#.#####.#
#.#####.#
#.#####.#
#.......#
#########
###...###
###.#.###
"""), [mask("""
##.....##
##.....##
.........
.........
..#####..
..#####..
..#####..
..#####..
.........
.........
##.....##
##.....##
"""), "o", omask("""
.........
.........
.........
.........
...##....
...##....
.........
.........
.........
.........
.........
.........
""")], color="#c9a46a")

add("crab", "Краб", "classic", mask("""
##.....##
##.....##
.##...##.
..#...#..
.#######.
#########
#########
#########
#########
.#######.
#.#.#.#.#
#.......#
"""), ["a", "o", "a"], color="#ef7d6a")

add("spider", "Паук", "classic", mask("""
#.......#
.#.....#.
..#.#.#..
#..###..#
.#######.
..#####..
.#######.
.#######.
.#######.
#..###..#
..#...#..
.#.....#.
#.......#
"""), [mask("""
.........
.........
.........
...###...
..#####..
..#####..
..#####..
..#####..
..#####..
...###...
.........
.........
.........
"""), "o", "a", "o"], color="#9b8bd6")

add("bridge", "Мост", "classic", mask("""
#########
#########
..#####..
..#####..
..#####..
..#####..
..#####..
..#####..
..#####..
..#####..
..#####..
#########
#########
"""), [mask("""
#########
#########
.........
...###...
...###...
...###...
...###...
...###...
...###...
...###...
.........
#########
#########
"""), mask("""
.........
.........
.........
.........
...###...
...###...
...###...
...###...
...###...
.........
.........
.........
.........
"""), mask("""
.........
.........
.........
.........
.........
...###...
...###...
...###...
.........
.........
.........
.........
.........
""")], color="#8fb3d9")

# a stepped pyramid (aligned steps: every step's rim stays reachable; a half-offset pyramid would leave only the
# top tile free and could never start)
add("pyramid", "Пирамида", "classic", mask("""
#######
#######
#######
#######
#######
#######
#######
#######
#######
"""), ["a", "a", "a"], color="#e8c47e")

add("gate", "Врата", "classic", mask("""
#########
#########
.##...##.
#########
.##...##.
.##...##.
.##...##.
.##...##.
.##...##.
.##...##.
.##...##.
####.####
####.####
"""), [mask("""
#########
#########
.##...##.
#########
.##...##.
.##...##.
.##...##.
.##...##.
.##...##.
.##...##.
.##...##.
.........
.........
"""), mask("""
..#####..
.........
.........
.........
.........
.........
.........
.........
.........
.........
.........
.........
.........
""")], color="#c8463c")

add("fan", "Веер", "classic", mask("""
#.#.#.#.#
#########
#########
#########
.#######.
.#######.
..#####..
..#####..
...###...
...###...
....#....
....#....
"""), ["a", "o", "a", "o"], color="#d796a5")

add("butterfly", "Бабочка", "classic", mask("""
##.....##
###...###
####.####
####.####
#########
.#######.
..#####..
.#######.
#########
####.####
###...###
##.....##
"""), ["a", "o", "a"], color="#b48be0")

add("lotus", "Лотос", "classic", mask("""
....#....
...###...
#..###..#
##.###.##
###.#.###
#########
.#######.
#########
#########
.#######.
..#####..
...###...
"""), ["a", "o", "a", "o"], color="#f2a6c0")

# ---- heroine symbols (no body silhouettes) ---------------------------------------------------------------------
def disc(r, sx=1.0):
    return lambda u, v: (u * sx) ** 2 + v ** 2 <= r * r

add("h_mc", "Веер-уть", "hero", mask("""
..#####..
.#######.
#########
#########
#########
#########
#########
.#######.
..#####..
....#....
....#....
...###...
"""), ["a", "o", "a", "o"], hero="mc", color="#ff8fb8")

add("h_rin", "Чаша", "hero", mask("""
..#...#..
...#.#...
..#...#..
.........
#########
#########
#########
.#######.
.#######.
..#####..
...###...
..#####..
"""), ["a", "o", "a"], hero="rin", color="#4fbf9f")

add("h_hana", "Солнце", "hero", mask("""
#...#...#
.#.###.#.
..#####..
.#######.
.#######.
#########
.#######.
.#######.
..#####..
.#.###.#.
#...#...#
"""), ["a", "o", "a", "o"], hero="hana", color="#ffb35c")

add("h_yue", "Лунный серп", "hero", mask("""
...#####.
..####...
.####....
.####....
####.....
####.....
####.....
####.....
####.....
.####....
.####....
..####...
...#####.
"""), ["c", "a", "o"], hero="yue", color="#c8b6ff")

def crystal_fn(u, v):
    return abs(u) * 1.45 + abs(v) * (0.62 if v < 0 else 0.9) <= 5.6 and v > -6.1
add("h_nova", "Кристалл", "hero", fmask(9, 13, crystal_fn), ["a", "o", "a", "o"], hero="nova", color="#4fe3ff")

add("h_kohaku", "Лиса", "hero", mask("""
#.......#
##.....##
###...###
#########
#########
#########
.#######.
.#######.
..#####..
...###...
....#....
"""), ["a", "o", "a"], hero="kohaku", color="#ff9b54")

add("h_zlata", "Жар-птица", "hero", mask("""
...##....
..####...
...###...
..#####..
.#######.
#########
.#######.
..#####..
...###...
..#.#.#..
.#..#..#.
#...#...#
#...#...#
"""), ["a", "o", "a"], hero="zlata", color="#ff7a45")

add("h_minamo", "Жемчужина", "hero", mask("""
...###...
..#####..
..#####..
..#####..
...###...
.........
#.#.#.#.#
#########
#########
.#######.
..#####..
...###...
....#....
"""), ["a", "o", "a"], hero="minamo", color="#7fd3e6")

add("h_vesper", "Корона", "hero", mask("""
#...#...#
#...#...#
##.###.##
#########
#########
#########
#########
.........
#########
#########
"""), ["a", "o", "c"], hero="vesper", color="#b07cff")

add("h_sigrid", "Снежинка", "hero", mask("""
.#..#..#.
..#.#.#..
#..###..#
.#.###.#.
..#####..
#########
..#####..
.#.###.#.
#..###..#
..#.#.#..
.#..#..#.
"""), ["c", "a", "o", "c"], hero="sigrid", color="#a9d8ff")

# mc's own form keeps one plain name
for f in L:
    if f["id"] == "h_mc":
        f["name"] = "Круглый веер"

def stats(f):
    pos = f["pos"]
    xs = [p[0] for p in pos]; ys = [p[1] for p in pos]
    return len(pos), (max(xs) - min(xs)) // 2 + 1, (max(ys) - min(ys)) // 2 + 1, max(p[2] for p in pos) + 1

def normalize(f):
    xs = [p[0] for p in f["pos"]]; ys = [p[1] for p in f["pos"]]
    mx, my = min(xs), min(ys)
    f["pos"] = sorted([[p[0] - mx, p[1] - my, p[2]] for p in f["pos"]], key=lambda p: (p[2], p[1], p[0]))

ok = True
for f in L:
    normalize(f)
    n, w, h, d = stats(f)
    flag = "" if (72 <= n <= 144 and n % 2 == 0) else "  <-- BAD COUNT"
    if flag:
        ok = False
    print("%-10s %-14s n=%3d  %dx%d  layers=%d%s" % (f["id"], f["name"], n, w, h, d, flag))

HERO_ORDER = ["mc", "rin", "hana", "yue", "nova", "kohaku", "zlata", "minamo", "vesper", "sigrid"]
data = {"ver": 1, "unit": "half-cell", "note": "x,y in half tiles (2 = one tile), z = layer. Made by scripts/v10/mj/classic/tools/make_layouts.py",
        "forms": L}
with open(OUT, "w", encoding="utf-8") as fh:
    fh.write("{\n")
    fh.write('"ver": 1,\n"unit": "half-cell",\n"note": %s,\n"forms": [\n' % json.dumps(data["note"], ensure_ascii=False))
    for k, f in enumerate(L):
        head = {kk: f[kk] for kk in ("id", "name", "kind", "hero", "color")}
        s = json.dumps(head, ensure_ascii=False)[:-1]
        s += ', "pos": [' + ",".join("[%d,%d,%d]" % tuple(p) for p in f["pos"]) + "]}"
        fh.write(s + (",\n" if k < len(L) - 1 else "\n"))
    fh.write("]\n}\n")
print("written", os.path.normpath(OUT), "ok" if ok else "WITH ERRORS")

if "--preview" in sys.argv:
    from PIL import Image, ImageDraw
    d = sys.argv[sys.argv.index("--preview") + 1]
    os.makedirs(d, exist_ok=True)
    cell = 14
    sheet = Image.new("RGB", (6 * 220, 4 * 300), (27, 23, 28))
    for k, f in enumerate(L):
        im = Image.new("RGB", (220, 300), (27, 23, 28))
        dr = ImageDraw.Draw(im)
        dr.text((6, 4), f["id"] + " " + str(len(f["pos"])), fill=(240, 230, 210))
        for p in sorted(f["pos"], key=lambda p: (p[2], p[1], p[0])):
            x = 10 + p[0] * cell / 2 - p[2] * 2
            y = 22 + p[1] * cell / 2 - p[2] * 3
            c = 150 + 25 * p[2]
            dr.rectangle([x + 2, y + 2, x + cell + 1, y + cell + 1], fill=(60, 40, 50))
            dr.rectangle([x, y, x + cell - 1, y + cell - 1], fill=(min(255, c), min(255, c - 10), min(255, c - 30)), outline=(90, 60, 70))
        sheet.paste(im, ((k % 6) * 220, (k // 6) * 300))
    sheet.save(os.path.join(d, "layouts_preview.png"))
    print("preview", os.path.join(d, "layouts_preview.png"))
