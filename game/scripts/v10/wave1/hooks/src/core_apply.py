# Applies the wave-1 core hooks (exact old -> new) to a game dir copy; every replacement must match exactly once.
import sys, os
GAME = sys.argv[1]
H = []
def hook(f, old, new):
    H.append((f, old, new))

# H1 g.gd consts -> vars
hook("scripts/g.gd", 'const HEROES: = {\n', 'var HEROES: = {\n')
hook("scripts/g.gd", 'const HERO_ORDER: = ["mc", "rin", "hana", "yue", "nova"]', 'var HERO_ORDER: = ["mc", "rin", "hana", "yue", "nova"]')
hook("scripts/g.gd", 'const BASE_OUTFITS: = ["o_base", "r_base", "h_base", "y_base", "n_base"]', 'var BASE_OUTFITS: = ["o_base", "r_base", "h_base", "y_base", "n_base"]')
# H2 g.gd _ready: merge before the save is read; _migrate: drop stale pointers
hook("scripts/g.gd", '''			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	load_game()
''', '''			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	# 0.10 wave 1: the five goddesses join G only once released (V10Wave1), before the save is read, so a saved
	# partner / avatar of hers survives _ensure_profile()
	if V10Wave1.released():
		V10Wave1.apply(self)
	load_game()
''')
hook("scripts/g.gd", '''	_sync_v6_fx()
	_ensure_profile()
''', '''	_sync_v6_fx()
	V10W1Core.sanitize_save(S, HEROES)
	_ensure_profile()
''')
# H2b g.gd outfit art path
hook("scripts/g.gd", '		return load("res://assets/outfits/%s.webp" % item_img(it))', '		return load(V10W1Core.outfit_webp(item_img(it)))')
hook("scripts/g.gd", '		return load("res://assets/outfits/%s.webp" % it.alt)', '		return load(V10W1Core.outfit_webp(String(it.alt)))')
# H3 hero.gd
hook("scripts/hero.gd", 'const RIGS: = {\n', 'static var RIGS: = {\n')
hook("scripts/hero.gd", '	var tex: Texture2D = load("res://assets/hero/%s.png" % id)', '	var tex: Texture2D = load(V10W1Core.hero_png(id))')
# H4 V8Art
A = "scripts/v08/hud/art.gd"
hook(A, 'const EMO_FACE: = {\n', 'static var EMO_FACE: = {\n')
hook(A, 'const EMO_FACE_W: = {', 'static var EMO_FACE_W: = {')
hook(A, 'const RIG_FACE_W: = {', 'static var RIG_FACE_W: = {')
hook(A, '''		if Hero.RIGS.has(s) and ResourceLoader.exists("res://assets/hero/%s.png" % s):
			t = load("res://assets/hero/%s.png" % s)''', '''		if Hero.RIGS.has(s) and ResourceLoader.exists(V10W1Core.hero_png(s)):
			t = load(V10W1Core.hero_png(s))''')
hook(A, '''			var p: = "res://assets/outfits/%s.webp" % s
			if not ResourceLoader.exists(p):
				p = "res://assets/outfits/mc_base.webp"
			t = load(p)
			var fc: Array = V8Population.face(s)''', '''			var p: = V10W1Core.outfit_webp(s)
			if not ResourceLoader.exists(p):
				p = "res://assets/outfits/mc_base.webp"
			t = load(p)
			var fc: Array = V10W1Core.outfit_face(s) if V10W1Core.is_wave1_img(s) else V8Population.face(s)''')
hook(A, '''static func emo_hero(hero: String) -> String:
	if Hero.RIGS.has(hero):
		return hero
''', '''static func emo_hero(hero: String) -> String:
	if Hero.RIGS.has(hero):
		return hero
	if V10W1Core.is_wave1_img(hero):
		return V10W1Core.hero_of_img(hero)
''')
hook(A, '''static func emotion_path(hero: String, emo: String) -> String:
	return EMO_ROOT + "%s_%s.webp" % [emo_hero(hero), emo_name(emo)]''', '''static func emotion_path(hero: String, emo: String) -> String:
	return V10W1Core.emotion_webp(emo_hero(hero), emo_name(emo))''')
hook(A, '	return tex("res://assets/hero/%s.png" % h)', '	return tex(V10W1Core.hero_png(h))')
# H5 round portraits
hook("scripts/main.gd", '	var t: = UI.tex(load("res://assets/hero/%s.png" % hero), r, false)', '	var t: = UI.tex(load(V10W1Core.hero_png(hero)), r, false)')
hook("scripts/screens/common.gd", '	var t: = UI.tex(load("res://assets/hero/%s.png" % hero), Rect2(Vector2(5, 5), r.size - Vector2(10, 10)), false)', '	var t: = UI.tex(load(V10W1Core.hero_png(hero)), Rect2(Vector2(5, 5), r.size - Vector2(10, 10)), false)')
hook("scripts/tile.gd", '	at.atlas = load("res://assets/hero/%s.png" % h)', '	at.atlas = load(V10W1Core.hero_png(h))')
# H6 collection.gd
C = "scripts/screens/collection.gd"
hook(C, '	var bg: String = STAGE_BG[cur]\n', '	var bg: String = STAGE_BG[cur] if STAGE_BG.has(cur) else V10W1Core.stage_bg(cur)\n')
hook(C, '''	var x: = 24.0 + (112.0 - AV) * 0.5
	for h in G.HERO_ORDER:
		var on: bool = h == cur
		var unl: = _unlocked(h)
		var ring: = UI.rbox("pink" if on else ("gold" if unl else "plum"), Rect2(x, ROW_Y, AV, AV), AV * 0.5, 4, 10)
		stage.add_child(ring)
		var av: TextureRect = main._avatar(h, Rect2(x + 7, ROW_Y + 7, AV - 14, AV - 14))
		if not unl:
			(av.material as ShaderMaterial).set_shader_parameter("gray", 1.0)
		stage.add_child(av)
		if not unl:
			stage.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(x + AV * 0.5 - 18, ROW_Y + AV * 0.5 - 18, 36, 36)))
		var hh: String = h
		var hit: = Control.new()
		hit.position = Vector2(x, ROW_Y)
		hit.size = Vector2(AV, AV)''', '''	# 0.10 wave 1: more than five goddesses share the row — the step shrinks to fit the width, the circles with it
	# (five: the 0.9 row exactly — step 136, AV 104)
	var n_h: = G.HERO_ORDER.size()
	var step: = 136.0 if n_h <= 5 else floorf((W - 40.0) / n_h)
	var avd: = AV if n_h <= 5 else minf(AV, step - 6.0)
	var x: = 24.0 + (112.0 - AV) * 0.5 if n_h <= 5 else 20.0 + (step - avd) * 0.5
	var ry: = ROW_Y + (AV - avd) * 0.5
	for h in G.HERO_ORDER:
		var on: bool = h == cur
		var unl: = _unlocked(h)
		var ring: = UI.rbox("pink" if on else ("gold" if unl else "plum"), Rect2(x, ry, avd, avd), avd * 0.5, 4, 10)
		stage.add_child(ring)
		var ins: = 7.0 * avd / AV
		var av: TextureRect = main._avatar(h, Rect2(x + ins, ry + ins, avd - ins * 2.0, avd - ins * 2.0))
		if not unl:
			(av.material as ShaderMaterial).set_shader_parameter("gray", 1.0)
		stage.add_child(av)
		if not unl:
			var lk: = 36.0 * avd / AV
			stage.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(x + avd * 0.5 - lk * 0.5, ry + avd * 0.5 - lk * 0.5, lk, lk)))
		var hh: String = h
		var hit: = Control.new()
		hit.position = Vector2(x, ry)
		hit.size = Vector2(avd, avd)''')
hook(C, '''		if on:
			ring.pivot_offset = Vector2(AV, AV) * 0.5
			UI.punch(ring, 0.12)
		x += 136''', '''		if on:
			ring.pivot_offset = Vector2(avd, avd) * 0.5
			UI.punch(ring, 0.12)
		x += step''')
# H8 league population: the founders stay the league's goddesses (identical seed sequence), wave-1 art paths resolve
P = "scripts/v08/league/population.gd"
hook(P, '		var hero: String = G.HERO_ORDER[rng.randi() % G.HERO_ORDER.size()]', '		var hero: String = V10W1Core.FOUNDERS[rng.randi() % V10W1Core.FOUNDERS.size()]')
hook(P, '		var fav: = hero if rng.randf() < 0.7 else String(G.HERO_ORDER[rng.randi() % G.HERO_ORDER.size()])', '		var fav: = hero if rng.randf() < 0.7 else String(V10W1Core.FOUNDERS[rng.randi() % V10W1Core.FOUNDERS.size()])')
hook(P, '	var src: = img if ResourceLoader.exists("res://assets/outfits/%s.webp" % img) else (hero if G.HEROES.has(hero) else "mc")', '	var src: = img if ResourceLoader.exists(V10W1Core.outfit_webp(img)) else (hero if G.HEROES.has(hero) else "mc")')
hook("scripts/v08/league/league_selftest.gd", '	_check("all heroines used", heroes.size() == G.HERO_ORDER.size(), str(heroes))', '	_check("all heroines used", heroes.size() == V10W1Core.FOUNDERS.size(), str(heroes))')
# H9 auth nick ideas: only goddesses that have ideas (a wave-1 goddess without a list would index an empty array)
hook("scripts/v10/auth/auth_nicks.gd", '	var heroes: Array = G.HERO_ORDER.duplicate()', '	var heroes: Array = G.HERO_ORDER.filter(func(h): return not IDEAS.get(h, []).is_empty())')

ok = True
for f, old, new in H:
    p = os.path.join(GAME, f)
    s = open(p, encoding="utf-8").read()
    n = s.count(old)
    if n != 1:
        print("MISS %s (%d): %s" % (f, n, old.splitlines()[0][:90])); ok = False; continue
    s = s.replace(old, new)
    open(p, "w", encoding="utf-8").write(s)
print("hooks applied" if ok else "SOME HOOKS FAILED", len(H))
