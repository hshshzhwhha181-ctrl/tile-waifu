class_name V10LookSelftest
extends RefCounted

# `--look_selftest=1` — kit_selftest + tiles_selftest + skin_selftest + fonts-on-moments + cosmetics/card checks of
# docs/0.10-spec.md D1/D2/D3/D5/D6/D7 for the «look» lane. Prints LOOK_SELFTEST ok/total, returns the fail count.

static var ok: = 0
static var total: = 0
static var fails: = []


static func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		print("LOOK FAIL: ", what)


static func _save(partner: String, outfit: = "", owned: = []) -> Dictionary:
	var S: Dictionary = G.S.duplicate(true)
	S["partner"] = partner
	var of: Dictionary = (S.get("outfit", {}) as Dictionary).duplicate()
	if outfit != "":
		of[partner] = outfit
	S["outfit"] = of
	var ow: = {"o_base": true, "s_sakura": true}
	for id in owned:
		ow[id] = true
	S["owned"] = ow
	S["shards"] = {}
	S["skin"] = "s_sakura"
	S.erase("look")
	S.erase("v10_heroes")
	S["profile"] = {}
	return S


static func run(host: Node) -> int:
	ok = 0
	total = 0
	fails = []
	V10Look.dev_reveal = {}
	V10Look._preview = {}
	V10HudSkin.use("five_winds")
	_kit()
	_tiles(host)
	_skins(host)
	await _skin_runtime(host)
	_fonts()
	_cos_card()
	V10Look.dev_reveal = {}
	if V10Look._hub and is_instance_valid(V10Look._hub) and not V10Look._hub.is_inside_tree():
		V10Look._hub.free()
	print("LOOK_SELFTEST %d/%d %s" % [ok, total, "OK" if ok == total else "FAIL"])
	return total - ok


# ------------------------------------------------------------------------------------------------- D1 kit

static func _kit() -> void:
	check(V10KitData.KITS.size() == 20, "20 goddess kits (%d)" % V10KitData.KITS.size())
	for h in V10KitData.KITS:
		var k: Dictionary = V10KitData.KITS[h]
		check(String(k.get("rank", "")) in V10KitData.RANKS, "kit %s has a rank" % h)
		check(String(k.get("accent", {}).get("particles", "")) in V10KitData.PARTICLES, "kit %s accent particles" % h)
		check(V10ProfileCos.has(String(k.get("frame", "")), "frame"), "kit %s frame in V10ProfileCos" % h)
		var sig: = int(k.get("sig", -1))
		check(sig >= 0 and sig < 36, "kit %s signature face" % h)
		check(V10ProfileCos.ROSTER.has(h) and String(V10ProfileCos.ROSTER[h][2]) == String(k.rank), "kit %s rank matches ROSTER" % h)
	for h in ["mc", "rin", "hana", "yue", "nova"]:
		check(not bool(V10KitData.KITS[h].get("hidden", false)), "founder %s kit is filled (not hidden)" % h)
	check(bool(V10KitData.KITS.zlata.get("hidden", false)), "zlata hidden until her banner")
	# resolve table (spec D1 selftest)
	var r: = V10Look.resolve("mc", "o_base")
	check(r.rank == "A" and r.open.frame and r.open.accent and not r.open.tile and r.hud == "five_winds", "mc/o_base -> A, frame+accent, base HUD")
	check(r.tile == "s_sakura" and r.table == "", "mc/o_base -> accent skin, location table")
	r = V10Look.resolve("mc", "o_dragon")
	check(r.rank == "S" and r.tile == "s_gold" and r.table == "tb_dragon" and r.hud == "five_winds", "mc/o_dragon -> S + s_gold + t_dragon, no HUD")
	r = V10Look.resolve("mc", "o_cafe")
	check(r.rank == "A", "mc/o_cafe (S outfit) stays A")
	r = V10Look.resolve("rin", "r_agent")
	check(r.rank == "S" and r.tile == "s_jade_frost" and r.table == "tb_ice_pavilion", "rin/r_agent -> «Нефрит и иней»")
	r = V10Look.resolve("rin", "r_idol")
	check(r.tile == "s_jade_frost", "rin/r_idol -> «Нефрит и иней»")
	r = V10Look.resolve("hana", "h_gym")
	check(r.rank == "S" and r.tile == "s_finish" and r.table == "tb_stadium", "hana/h_gym -> «Финишная лента»")
	r = V10Look.resolve("yue", "y_queen")
	check(r.rank == "S" and r.tile == "s_night" and r.table == "tb_palace" and not r.open.hud, "yue/y_queen -> S (SSR outfit never lifts past S)")
	r = V10Look.resolve("nova", "n_base")
	check(r.rank == "S" and r.tile == "s_neon" and r.table == "tb_neon", "nova -> «Неон»")
	r = V10Look.resolve("zlata", "zl_base")
	check(r.rank == "SSR" and r.hud == "zlata" and r.font == "zlata" and r.sting == "zlata" and r.tile == "s_lacquer" and r.palette == "firebird", "zlata -> full SSR kit")
	check(V10Look.resolve("zlata", "zl_ember").palette == "ember" and V10Look.resolve("zlata", "zl_vow").palette == "dawn", "SSR outfits of an SSR goddess -> HUD palette")
	# ranked -> standard faces
	var S: = _save("mc", "o_dragon", ["o_dragon"])
	var lk: = V10Look.tile_look(S, {"ranked": true})
	check(lk.ranked and lk.tint == Color.WHITE and not lk.has("face_rim"), "ranked: standard faces (no tint, no kromka)")
	lk = V10Look.tile_look(S)
	check(lk.v10 == "s_gold" and lk.has("face_rim"), "unranked: s_gold with kromka")
	# override to an element not owned -> auto
	S = _save("mc", "o_base")
	check(V10Look.set_choice(S, "tile", "s_gold") != "", "set_choice refuses an unowned theme")
	S["look"] = {"frame": "auto", "tile": "s_gold", "table": "tb_neon", "hud": "zlata"}
	var cur: = V10Look.current(S)
	check(cur.tile == "s_sakura" and cur.table == "" and cur.hud == "five_winds", "tampered unowned choices fall back to auto")
	S = _save("mc", "o_dragon", ["o_dragon", "s_night"])
	check(V10Look.set_choice(S, "tile", "s_night") == "" and V10Look.current(S).tile == "s_night", "owned legacy skin can be picked by hand")
	check(String(S.skin) == "s_night", "legacy pick mirrors S.skin for 0.9 readers")
	check(V10Look.set_choice(S, "table", "base") == "" and V10Look.current(S).table == "", "base table = location table")
	check(V10Look.set_choice(S, "tile", "auto") == "" and V10Look.current(S).tile == "s_gold", "auto returns to the kit")
	# migration
	S = _save("mc")
	S["skin"] = "s_night"
	S["profile"] = {"frame": "fr_rank_2"}
	check(V10Look.migrate(S) and S.look.tile == "s_night" and S.look.frame == "fr_rank_2", "migrate: S.skin -> look.tile, profile.frame -> look.frame")
	var snap: Dictionary = S.look.duplicate()
	check(not V10Look.migrate(S) and S.look == snap, "migrate is idempotent")
	S = _save("mc")
	V10Look.migrate(S)
	check(S.look == V10Look.DEFAULT_LOOK, "fresh save migrates to all-auto")
	# preview never writes S.look
	S = _save("mc")
	V10Look.migrate(S)
	var before: Dictionary = S.look.duplicate()
	V10Look.preview("zlata", "zl_base")
	var pv: = V10Look.current(S)
	check(pv.hud == "zlata" and pv.get("preview", false), "try-on shows the whole kit")
	V10Look.end_preview()
	check(S.look == before and V10Look.current(S).hud == "five_winds", "try-on does not write S.look")
	# ownership
	S = _save("mc", "o_dragon", ["o_dragon"])
	var own: = V10Look.owned_elements(S)
	check("s_gold" in own.tile and "tb_dragon" in own.table and "fr_g_mc" in own.frame, "o_dragon owns «Золото дракона» + table")
	check(not ("s_lacquer" in own.tile) and not ("zlata" in own.hud), "unreleased zlata is not owned")
	V10Look.dev_reveal["zlata"] = true
	own = V10Look.owned_elements(S)
	check("zlata" in own.hud and "s_lacquer" in own.tile, "--skin=zlata reveals her kit for review")
	V10Look.dev_reveal = {}


# ------------------------------------------------------------------------------------------------- D3 tiles

static func _tiles(host: Node) -> void:
	var ink: = Color("3b2a2f")
	for id in V10TileTheme.THEMES:
		var th: Dictionary = V10TileTheme.THEMES[id]
		for k in ["side", "rim", "tint", "back2", "line", "pattern", "accent", "particles", "sig", "name", "owner", "tier"]:
			check(th.has(k), "theme %s has %s" % [id, k])
		check(int(th.sig) >= 0 and int(th.sig) < 36, "theme %s sig face 0..35" % id)
		check(String(th.particles) in V10KitData.PARTICLES, "theme %s particles preset" % id)
		if th.has("emblem"):
			check(ResourceLoader.exists(String(th.emblem)), "theme %s emblem art exists" % id)
		var face: = V10TileTheme.IVORY * Color(th.tint)
		check(V10HudSkin.contrast(face, ink) >= 4.5, "theme %s face contrast with tint ≥ 4.5 (%.2f)" % [id, V10HudSkin.contrast(face, ink)])
		var rl: = V10TileTheme.look(id, {"ranked": true})
		check(rl.tint == Color.WHITE and not rl.has("face_rim"), "theme %s ranked: no tint, no kromka" % id)
		var big: = V10TileTheme.look(id, {"big_symbols": true})
		check(big.tint == Color.WHITE, "theme %s «Крупные символы» drop the tint" % id)
		if String(th.get("table", "")) != "":
			check(V10TileTheme.has_table(String(th.table)), "theme %s table exists" % id)
	# legacy ids unchanged
	for id in G.SKIN_LOOK:
		var lg: Dictionary = G.SKIN_LOOK[id]
		var lk: = V10TileTheme.look(id)
		check(V10TileTheme.has(id) and lk.side == lg.side and lk.rim == lg.rim, "legacy %s keeps side/rim" % id)
		check(lk.tint == lg.get("tint", Color.WHITE) and bool(lk.neon) == bool(lg.get("neon", false)), "legacy %s keeps tint/neon" % id)
	for id in V10TileTheme.TABLES:
		var tb: Dictionary = V10TileTheme.TABLES[id]
		for k in ["frame_a", "frame_b", "trim", "mat_a", "mat_b", "pat_col", "pat_alpha", "pattern", "pat_scale", "fibre", "lamp_col", "lamp_k", "gloss", "shadow", "ambient", "name", "owner"]:
			check(tb.has(k), "table %s has %s" % [id, k])
		if tb.has("tex"):
			check(ResourceLoader.exists(String(tb.tex)), "table %s texture exists" % id)
	# particles cap
	check(V10PairFx.cap("full") == 18 and V10PairFx.cap("mid") == 8 and V10PairFx.cap("min") == 0, "pair particles cap 18/8/0")
	var lkp: = V10TileTheme.look("s_lacquer")
	check(V10PairFx.burst(host, Vector2.ZERO, lkp, "min") == null, "fx min: no pair particles")
	var fx: = V10PairFx.burst(host, Vector2.ZERO, lkp, "full")
	check(fx != null and fx.parts.size() == 18 and fx.kind == "feathers", "full burst: 18 feathers")
	var fx2: = V10PairFx.burst(host, Vector2.ZERO, V10TileTheme.look("s_mint"), "mid")
	check(fx2 != null and fx2.parts.size() == 8, "mid burst: 8")
	if fx:
		fx.free()
	if fx2:
		fx2.free()
	# shared body material: one per theme, every tile the same instance; fuzz build/dress/free on 3 themes
	V10TileTheme._mats.clear()
	for id in ["s_gold", "s_jade_frost", "s_lacquer"]:
		var holder: = Node2D.new()
		host.add_child(holder)
		var mats: = {}
		var lk2: = V10TileTheme.look(id)
		for i in 60:
			var t: = Tile.new()
			t.face = i % 36
			holder.add_child(t)
			t.build(lk2)
			V10TileTheme.dress(t)
			mats[t.side_j.material.get_instance_id()] = true
			if i == int(lk2.sig):
				check(t.get_node_or_null("V10Sig") != null, "theme %s signature face glows" % id)
			if i == 0:
				check(t.get_node_or_null("V10Rim") != null, "theme %s face kromka sprite" % id)
		check(mats.size() == 1, "theme %s: 60 tiles share ONE body material" % id)
		holder.free()
	check(V10TileTheme.mat_count() == 3, "3 themes -> 3 cached materials (%d)" % V10TileTheme.mat_count())
	# ranked tiles: no kromka, no signature
	var hr: = Node2D.new()
	host.add_child(hr)
	var rt: = Tile.new()
	rt.face = 12
	hr.add_child(rt)
	rt.build(V10TileTheme.look("s_lacquer", {"ranked": true}))
	V10TileTheme.dress(rt)
	check(rt.get_node_or_null("V10Rim") == null and rt.get_node_or_null("V10Sig") == null, "ranked tile: standard face, no glow")
	check(float(rt.side_j.material.get_shader_parameter("anim")) == 0.0, "ranked tile body static")
	hr.free()
	# apply_table on a real V6BoardTable
	var tbn: = V6BoardTable.new()
	host.add_child(tbn)
	tbn.mat.shader = load("res://shaders/v06/board/table.gdshader")
	check(V10TileTheme.apply_table(tbn, "tb_lacquer_box") and tbn.mat.shader == V10TileTheme.TABLE_SHADER, "apply_table re-dresses a V6BoardTable")
	check(float(tbn.mat.get_shader_parameter("mat_tex_on")) == 1.0, "lacquer box mat texture on")
	V10TileTheme.apply_table(tbn, "tb_palace", {"static": true})
	check(float(tbn.mat.get_shader_parameter("anim")) == 0.0, "static table for ranked")
	tbn.free()


# ------------------------------------------------------------------------------------------------- D7 skins

static func _skins(host: Node) -> void:
	for sid in V10HudSkinData.SKINS:
		var sk: Dictionary = V10HudSkinData.SKINS[sid]
		var nine: Dictionary = sk.get("nine", {})
		check(V10HudSkinData.NINE_ROLES.size() == 11, "11 nine roles defined")
		for role in V10HudSkinData.NINE_ROLES:
			check(nine.has(role), "skin %s has role %s" % [sid, role])
			var d: Dictionary = nine.get(role, {})
			if d.has("tex"):
				check(ResourceLoader.exists(String(d.tex)), "skin %s role %s texture" % [sid, role])
			var fill: = V10HudSkin.role_fill(sid, role)
			var tx: Color = V10HudSkinData.tokens(sid).get(String(V10HudSkinData.TEXT_ON[role]), Color.MAGENTA)
			var cr: = V10HudSkin.contrast(tx, fill)
			check(cr >= 4.5, "skin %s role %s text contrast ≥ 4.5 (%.2f)" % [sid, role, cr])
		for cls in V10HudSkinData.BUTTON_CLASSES:
			check(nine.has(V10HudSkinData.BUTTON_CLASSES[cls]), "skin %s defines button class %s" % [sid, cls])
		for p in sk.get("palettes", {}):
			var toks: = V10HudSkinData.tokens(sid, p)
			check(V10HudSkin.contrast(toks.text_on_primary, toks.rose_500) >= 4.5, "skin %s palette %s «Игра» contrast" % [sid, p])
			check(V10HudSkin.contrast(toks.paper_100, toks.night_800) >= 4.5, "skin %s palette %s body contrast" % [sid, p])
		for k in ["press_fx", "open_fx", "sfx", "menu_bg", "loading", "sting"]:
			check(sk.has(k), "skin %s has %s" % [sid, k])
		for path_key in ["menu_bg", "loading", "corner"]:
			var pth: = String(sk.get(path_key, ""))
			if pth != "":
				check(ResourceLoader.exists(pth), "skin %s %s exists" % [sid, path_key])
	# five_winds is a no-op: snapshot of a tree before/after decorating every role is identical
	V10HudSkin.use("five_winds")
	var root: = Control.new()
	root.size = Vector2(720, 1280)
	host.add_child(root)
	for i in 6:
		var c: = Control.new()
		c.position = Vector2(10 * i, 20 * i)
		c.size = Vector2(100 + i, 50)
		c.modulate = Color(1, 1, 1, 0.9)
		root.add_child(c)
	var snap0: = _snap(root)
	var noop: = true
	for c in root.get_children():
		for role in V10HudSkinData.NINE_ROLES:
			if V10HudSkin.decorate(c, role) != null:
				noop = false
	check(noop, "five_winds decorate() is a no-op for all 11 roles")
	check(_snap(root) == snap0, "five_winds changes no Rect, colour or child of the tree")
	# zlata decorates, and every skin node ignores input
	V10HudSkin.use("zlata")
	var bg: = V10HudSkin.decorate(root.get_child(0), "plate_m")
	check(bg != null and _all_ignore(bg), "zlata decorate adds a background that never catches taps")
	for role in V10HudSkinData.NINE_ROLES:
		var n: = V10HudSkin.nine(role, Vector2(200, 80))
		check(_all_ignore(n), "zlata nine %s ignores input" % role)
		n.free()
	V10HudSkin.use("five_winds")
	root.free()
	# stings: ≤ once per 600 s
	V10HudSkin.use("zlata")
	V10HudSkin.reset_sting()
	check(V10HudSkin.sting(false, 1000), "first sting plays")
	check(not V10HudSkin.sting(false, 1000 + 599000), "no second sting within 600 s")
	check(V10HudSkin.sting(true, 1000 + 600001), "sting again after 600 s")
	V10HudSkin.use("five_winds")
	V10HudSkin.reset_sting()
	check(not V10HudSkin.sting(false, 5000), "five_winds has no sting")
	# match layout: skin nodes stay off the board (header bottom < board top; tray below the board)
	var hd_h: = 120.0
	for vs in [Vector2(720, 1280), Vector2(720, 1600), Vector2(720, 1680), Vector2(960, 1280)]:
		var board_top: = 250.0
		var board_bot: float = board_top + (vs.y - 520.0)
		var tray_top: float = vs.y - 248.0
		check(hd_h <= board_top and board_bot <= tray_top, "match %dx%d: header and tray off the board" % [vs.x, vs.y])


static func _skin_runtime(host: Node) -> void:
	# assembly time ≤ 0,65 s at full, 0 tweens at min; try-on never writes S.look
	check(V10SkinAssemble.assemble_time("full") <= 0.65 and V10SkinAssemble.assemble_time("min") == 0.0, "assembly ≤ 0,65 s full, instant at min")
	var root: = Control.new()
	root.size = Vector2(720, 1280)
	host.add_child(root)
	var home: = Control.new()
	home.size = root.size
	root.add_child(home)
	for i in 5:
		var c: = ColorRect.new()
		c.size = Vector2(100, 100)
		c.position = Vector2(100 * i, 200 * i)
		home.add_child(c)
	V10HudSkin.use("zlata")
	V10HudSkin.reset_sting()
	var t0: = Time.get_ticks_msec()
	var a: = V10SkinAssemble.play(root, home, "zlata", Callable(), Callable(), "min")
	check(a.tweens_made == 0, "min: assembly makes 0 tweens")
	check(Time.get_ticks_msec() - t0 < 650, "assembly builds in < 0,65 s")
	a.free()
	V10HudSkin.reset_sting()
	var b: = V10SkinAssemble.play(root, home, "zlata", Callable(), Callable(), "full")
	check(b.tweens_made >= 5, "full: children assemble from the centre")
	await host.get_tree().create_timer(0.7).timeout
	var all_in: = true
	for c in home.get_children():
		if (c as Control).modulate.a < 0.99:
			all_in = false
	check(all_in, "after 0,6 с every block is in place")
	b.free()
	# window opening per skin + fuzz: build each skin's pieces at random sizes
	var rng: = RandomNumberGenerator.new()
	rng.seed = 42
	for sid in V10HudSkinData.SKINS:
		V10HudSkin.use(sid)
		var errs: = 0
		for i in 25:
			var w: = rng.randf_range(200, 700)
			var h: = rng.randf_range(160, 900)
			var win: = V10HudSkin.window(root, "Окно %d" % i, Rect2(0, 0, w, h))
			var p: = V10HudSkin.plate(["S", "M", "L"][i % 3], "Очень длинный заголовок плашки номер %d" % i, "подпись", Rect2(0, 0, w, 80))
			var bt: = V10HudSkin.button(["play", "cash", "secondary", "quiet"][i % 4], "Кнопка", Rect2(0, 0, w, 80))
			if win.size.x <= 0 or p.size.y != float(V10HudSkinData.ROLE_H["plate_" + ["s", "m", "l"][i % 3]]):
				errs += 1
			win.free()
			p.free()
			bt.free()
		check(errs == 0, "fuzz skin %s: 25 windows/plates/buttons, fixed plate heights" % sid)
	V10HudSkin.use("five_winds")
	root.free()


static func _snap(n: Node) -> Array:
	var out: = []
	var stack: = [n]
	while not stack.is_empty():
		var x: Node = stack.pop_front()
		if x is Control:
			out.append([x.name, (x as Control).get_rect(), (x as Control).modulate, x.get_child_count()])
		for c in x.get_children():
			stack.append(c)
	return out


static func _all_ignore(n: Node) -> bool:
	if n is Control and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for c in n.get_children():
		if not _all_ignore(c):
			return false
	return true


# ------------------------------------------------------------------------------------------------- D2 fonts on moments

static func _fonts() -> void:
	var z: = {"font": "zlata"}
	check(V10LookFonts.fit("screen_title", "Чайная", 600, z).id == "zlata_title", "zlata: screen title in Ruslan Display")
	check(V10LookFonts.fit("ult_name", "Огненный шлейф", 600, z).id == "zlata_title", "zlata: ult name in her font")
	check(V10LookFonts.fit("victory", "Победа!", 600, z).id == "zlata_title", "zlata: «Победа!» in her font")
	check(V10LookFonts.fit("letter_sign", "Злата", 600, z).id == "zlata_text", "zlata: letter signature in Kurale")
	check(V10LookFonts.fit("letter_sign", "Маджонг-тян", 600, {"font": ""}).id == "hand", "founders sign in Caveat")
	check(V10LookFonts.fit("screen_title", "Чайная", 600, {"font": ""}).id == "ui_display", "no SSR partner: Playfair")
	check(V10LookFonts.price_font() == V10Fonts.font("ui_body", 900), "prices always Nunito")
	V10Fonts.deco = false
	check(V10LookFonts.fit("screen_title", "Чайная", 600, z).id == "ui_display", "decorative fonts off -> Playfair")
	V10Fonts.deco = true
	for sk in ["zlata", "minamo", "kira", "vesper", "sigrid"]:
		for t in ["Карточка игрока", "Шансы и правила", "Мастерство наряда"]:
			var f: = V10LookFonts.fit("screen_title", t, 600, {"font": sk})
			check(V10Fonts.width(f.font, t, int(f.size)) <= 600.0, "%s: «%s» fits 600 px" % [sk, t])
	# mc/yue/nova never get a decorative font from the kit (only SSR goddesses)
	for h in ["mc", "rin", "hana", "yue", "nova"]:
		check(V10Look.resolve(h, "").font == "", "%s kit carries no display font" % h)


# ------------------------------------------------------------------------------------------------- D5/D6 cosmetics + card

static func _cos_card() -> void:
	var errs: = V10LookCos.validate_all()
	check(errs.is_empty(), "unified cosmetics registry valid %s" % str(errs.slice(0, 3)))
	for kind in V10LookCos.KINDS:
		check(not V10LookCos.all(kind, true).is_empty(), "registry has kind %s" % kind)
	for e in V10LookCos.all("", true):
		if String(e.kind) in ["title", "badge"] + V10LookCos.LOOK_KINDS:
			check(not bool(e.get("sold", false)), "%s never sold" % e.id)
	check(V10LookCos.kit_line("zlata") == "Набор: рамка · акцент · тема фишек · стол · HUD · стинг · шрифт", "banner kit line for SSR")
	check(V10LookCos.kit_line("mc") == "Набор: рамка · акцент", "kit line for A")
	# card payload with the look
	var S: = _save("yue", "y_queen", ["y_queen"])
	S["profile"] = {"nick": "Лунный Лис"}
	var p: = V10LookCard.payload(S, {"league": 2, "games_week": 12})
	check(V10LookCard.validate(p) == "", "own card with look validates (%s)" % V10LookCard.validate(p))
	check(p.tile == "s_night" and p.table == "tb_palace" and p.frame == "fr_g_yue", "card shows the kit theme, table and frame")
	check(V10CardPayload.size_bytes(p) <= 2048, "card payload ≤ 2 KB")
	check(not p.has("spent") and not p.has("moon"), "no spends on the card")
	var rng: = RandomNumberGenerator.new()
	rng.seed = 2026
	var bad: = 0
	for i in 1000:
		var q: = V10LookCard.sim(rng, i % 6)
		if V10LookCard.validate(q) != "":
			bad += 1
	check(bad == 0, "1000 simulated cards: no SSR goddess/outfit/theme/table, no paid frames (%d bad)" % bad)
	var q2: = V10LookCard.sim(rng, 3)
	q2.tile = "s_lacquer"
	check(V10LookCard.validate(q2) != "", "sim with an SSR theme is rejected")
