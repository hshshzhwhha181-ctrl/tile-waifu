import sys, re
root = sys.argv[1]

def patch(path, const, comment):
    src = open(path, encoding="utf-8").read()
    head = "const %s: = {" % const
    assert src.count(head) == 1, (path, const)
    i = src.index(head)
    # find the matching closing brace of the dict literal
    j = src.index("{", i); depth = 0; k = j
    while True:
        c = src[k]
        if c == "{": depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0: break
        k += 1
    end = src.index("\n", k) + 1
    src = src[:i] + "const %s_BASE: = {" % const + src[i + len(head):end] + \
        "%s\nstatic var %s: Dictionary = %s_BASE.duplicate(true)\n" % (comment, const, const) + src[end:]
    open(path, "w", encoding="utf-8").write(src)

c = "# wave releases overlay full kits / themes here (V10W1Look.install() when V10Wave1.released())"
patch(root + "/look/kit_data.gd", "KITS", c)
patch(root + "/look/kit_data.gd", "EXTRA_OUTFITS", c)
patch(root + "/look/tile_themes.gd", "THEMES", c)
patch(root + "/look/tile_themes.gd", "TABLES", c)
patch(root + "/hud2/tokens.gd", "HEROES", c)
patch(root + "/hud2/combo_showcase.gd", "LINES", c)

p = root + "/hud2/combo_showcase.gd"
src = open(p, encoding="utf-8").read()
old = """			if ResourceLoader.exists(cand):
				return cand
	return ""
"""
new = """			if ResourceLoader.exists(cand):
				return cand
	return V10W1Look.combo_sprite(h, o, t) if V10Wave1.released() else ""
"""
assert src.count(old) == 1
src = src.replace(old, new)
old2 = """	var key: = path.get_file().get_basename()
	return _meta.get(key, {})
"""
new2 = """	var key: = path.get_file().get_basename()
	if not _meta.has(key) and V10Wave1.released():
		return V10W1Look.combo_meta(path)
	return _meta.get(key, {})
"""
assert src.count(old2) == 1
src = src.replace(old2, new2)
open(p, "w", encoding="utf-8").write(src)
print("patched")
