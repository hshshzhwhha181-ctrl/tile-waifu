extends Control

# Standalone runner of the v10 «look» lane (M5: kits, fonts on moments, tile themes and tables, HUD skins, Profile 2.0
# with the kit). Launched as its own scene, so no hot file is touched:
#
#   godot --headless --path game res://scripts/v10/look/look_runner.tscn -- --look_selftest=1
#   xvfb-run -a godot --path game --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 \
#       res://scripts/v10/look/look_runner.tscn -- --look_shots=/abs/dir [--views=home,match,...] [--skin=zlata] [--fx=min]
#
# Views: tiles, ranked, match, home, window, kit, style, picker, fonts, card, assemble, preview, loading
# --fx=min: shots with «Эффекты: минимум» (in memory only, the save is not written): no wave, no pen, no breathing.
# The home / match / window views are SKIN SPECIMENS laid out by UX §3.3 / §6.6 / §5.3 (the real screens are the
# integrator's): they never show what those rules forbid (prices or currencies on Чайная, a style chip in the match).

const ALL_VIEWS: = ["tiles", "ranked", "match", "home", "window", "kit", "style", "picker", "fonts", "card", "assemble", "preview", "loading"]

var args: = {}
var stage: Control
var out_dir: = ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s: = String(a).trim_prefix("--")
		var kv: = s.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("skin"):
		V10Look.dev_reveal[String(args.skin)] = true
	if args.has("fx"):
		G.S["fx_level"] = String(args.fx)
		V10TileTheme.anim_on = String(args.fx) != "min"
	# the scene's root is anchored full-rect, so it already spans the viewport (no size write: no anchor warning)
	if args.has("look_selftest"):
		await get_tree().process_frame
		var fails: int = await V10LookSelftest.run(self)
		get_tree().quit(fails)
		return
	if args.has("look_shots"):
		out_dir = String(args.look_shots)
		DirAccess.make_dir_recursive_absolute(out_dir)
		V10Look.dev_reveal["zlata"] = true
		var views: Array = ALL_VIEWS if not args.has("views") else Array(String(args.views).split(","))
		for v in views:
			await call("_view_" + String(v))
		get_tree().quit(0)
		return
	# interactive: home in the requested skin
	V10Look.dev_reveal["zlata"] = true
	await _view_home()


# ------------------------------------------------------------------------------------------------- helpers

func _clear() -> void:
	if stage and is_instance_valid(stage):
		stage.free()
	V10HudSkin.use("five_winds")
	V10Look._preview = {}
	stage = Control.new()
	stage.size = get_viewport_rect().size
	stage.clip_contents = true
	add_child(stage)


func _shot(name: String, frames: = 6) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	var vs: = get_viewport_rect().size
	var p: = out_dir.path_join("%s_%dx%d.png" % [name, int(vs.x), int(vs.y)])
	img.save_png(p)
	print("SHOT ", p)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


static func save_for(partner: String, outfit: = "", owned: = []) -> Dictionary:
	var S: Dictionary = G.S.duplicate(true)
	S["partner"] = partner
	var of: Dictionary = S.get("outfit", {}).duplicate()
	if outfit != "":
		of[partner] = outfit
	S["outfit"] = of
	var ow: Dictionary = S.get("owned", {}).duplicate()
	for id in owned:
		ow[id] = true
	if outfit != "":
		ow[outfit] = true
	S["owned"] = ow
	S.erase("look")
	return S


func _bg(path: String, tint: = Color(0.62, 0.58, 0.64)) -> void:
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if t == null:
		var cr: = ColorRect.new()
		cr.color = V10HudSkin.tok("night_900")
		cr.size = stage.size
		stage.add_child(cr)
		return
	var c: = V10HudSkin._Cover.new()
	c.texture = t
	c.size = stage.size
	c.modulate = tint
	stage.add_child(c)


func _hero_art(hero: String, outfit: String) -> Texture2D:
	if hero == "zlata":
		return load("res://assets/v10/look/zlata/loading.webp")
	var it: Dictionary = G.ITEM.get(outfit, G.ITEM.get(["o_base", "r_base", "h_base", "y_base", "n_base"][["mc", "rin", "hana", "yue", "nova"].find(hero)], {}))
	return G.item_tex(it) if not it.is_empty() else null


func _label(t: String, sz: int, col: Color, pos: Vector2, w: float, kind: = "ui") -> Label:
	var l: = V10HudSkin.label(t, sz, col, kind, w)
	l.position = pos
	l.size = Vector2(w, sz * 1.5)
	stage.add_child(l)
	return l


# ------------------------------------------------------------------------------------------------- views

func _view_tiles() -> void:
	_clear()
	_bg("", Color.WHITE)
	_label("Темы фишек и столы", 44, V10HudSkin.tok("paper_100"), Vector2(24, 20), 672, "display")
	var ids: = V10TileTheme.ids()
	var cw: = 328.0
	var ch: = 226.0
	for i in ids.size():
		var id: String = ids[i]
		var th: = V10TileTheme.theme(id)
		var pos: = Vector2(24 + (i % 2) * (cw + 16), 92 + (i / 2) * (ch + 10))
		var b: = V10LookBoard.make(id, String(th.get("table", "")), Rect2(pos, Vector2(cw, ch - 40)), {"pad": 16.0, "burst": i % 3 == 0})
		stage.add_child(b)
		_label("%s · %s" % [th.name, th.tier], 18, V10HudSkin.tok("paper_100"), pos + Vector2(4, ch - 38), cw)
	await _shot("tiles_all", 12)


func _view_ranked() -> void:
	_clear()
	_bg("", Color.WHITE)
	_label("Рейтинг: лица стандартные, стол статичный", 26, V10HudSkin.tok("paper_100"), Vector2(24, 20), 672)
	var ids: = ["s_lacquer", "s_gold", "s_neon"]
	for i in ids.size():
		var th: = V10TileTheme.theme(ids[i])
		for r in 2:
			var pos: = Vector2(24 + r * 344, 80 + i * 390)
			var b: = V10LookBoard.make(ids[i], String(th.get("table", "")), Rect2(pos, Vector2(328, 330)), {"ranked": r == 1, "cols": 3, "rows": 3})
			stage.add_child(b)
			_label("%s · %s" % [th.name, "рейтинг" if r == 1 else "обычная"], 18, V10HudSkin.tok("paper_300"), pos + Vector2(0, 334), 328)
	await _shot("tiles_ranked", 10)


func _match(theme_id: String, skin: String, hero: String, outfit: String, tag: String) -> void:
	_clear()
	V10HudSkin.use(skin, "")
	var th: = V10TileTheme.theme(theme_id)
	var tb: = String(th.get("table", ""))
	# the match keeps the location's background in every skin: a HUD skin changes only the header, the tray frame
	# and the help discs (UX §6.6)
	_bg("res://assets/bg/bg_teahouse_blur.webp", Color(0.55, 0.52, 0.58))
	var W: = stage.size.x
	var H: = stage.size.y
	var top: = 0.0
	# header: pause · «1-2 · Осталось 30» · heroine in the arch window (HUD_V2 §8.1 simplified); in a skin the match
	# header is plain lacquer — no ornament strip (UX §3.7: 0 gold ornaments in the match but the tray frame)
	var hd: = V10HudSkin.header(stage, "", W, top, true)
	var lv: = V10HudSkin.label("1-2 · Осталось 30", 22, V10HudSkin.tok("paper_100"))
	lv.position = Vector2(80, top + 40)
	lv.size = Vector2(360, 32)
	stage.add_child(lv)
	var prog_bg: = ColorRect.new()
	prog_bg.color = V10HudSkin.tok("night_600")
	prog_bg.position = Vector2(80, lv.position.y + 38)
	prog_bg.size = Vector2(320, 2)
	stage.add_child(prog_bg)
	var prog: = ColorRect.new()
	prog.color = V10HudSkin.tok("jade_300")
	prog.position = prog_bg.position
	prog.size = Vector2(320 * 0.42, 2)
	stage.add_child(prog)
	var art: = _hero_art(hero, outfit)
	if art:
		var win: = _Arch.new()
		win.tex = art
		win.ring = V10Look.resolve(hero, outfit).accent.col
		win.size = Vector2(132, 132)
		win.position = Vector2(W - 156, top + 104)
		stage.add_child(win)
	var board_h: = H - 520.0
	var cols: = 6
	var rows: = int(clampf(board_h / 116.0, 5, 9))
	var b: = V10LookBoard.make(theme_id, tb, Rect2(24, top + 250, W - 48, board_h), {"cols": cols, "rows": rows, "burst": true, "pad": 26.0,
		"faces": [int(th.sig), 7, 0, 21, 24, 33, 12, 3, 25, 9, 11, 13, 5, 1, 2, 4, 6, 8, 10, 14, 15, 16, 17, 18, 19, 20, 22, 23, 26, 27]})
	stage.add_child(b)
	# tray: plate L lacquer with 7 cells, the last one in ember
	var tray_y: = H - 248.0
	var tray: = Control.new()
	tray.position = Vector2(24, tray_y)
	tray.size = Vector2(W - 48, 104)
	tray.add_child(V10HudSkin.nine("plate_m", Vector2(W - 48, 104)))
	stage.add_child(tray)
	for i in 7:
		var cell: = ColorRect.new()
		cell.color = Color(V10HudSkin.tok("night_900"), 0.55) if i < 6 else Color(V10HudSkin.tok("ember"), 0.16)
		var cw: = (W - 48 - 64) / 7.0
		cell.position = Vector2(32 + i * cw + 2, 14)
		cell.size = Vector2(cw - 4, 76)
		tray.add_child(cell)
	# help discs
	var names: = ["Отмена", "Подсказка", "Перемешать"]
	for i in 3:
		var bx: = V10HudSkin.button("quiet", names[i], Rect2(W * 0.5 - 240 + i * 160, H - 134, 160, 116))
		stage.add_child(bx)
		var n: = V10HudSkin.label(str(3 - i), 22, V10HudSkin.tok("paper_100"), "num")
		n.position = bx.position + Vector2(126, 30)
		n.size = Vector2(30, 30)
		stage.add_child(n)
	await _wait(0.25)
	await _shot("match_%s" % tag, 4)


func _view_match() -> void:
	var cases: = [["s_sakura", "five_winds", "mc", "o_base"], ["s_gold", "five_winds", "mc", "o_dragon"],
		["s_jade_frost", "five_winds", "rin", "r_agent"], ["s_finish", "five_winds", "hana", "h_gym"],
		["s_night", "five_winds", "yue", "y_queen"], ["s_neon", "five_winds", "nova", "n_ssr"], ["s_lacquer", "zlata", "zlata", "zl_base"]]
	for c in cases:
		await _match(c[0], c[1], c[2], c[3], c[0])


func _home(skin: String, pal: String, hero: String, outfit: String, tag: String) -> void:
	_clear()
	V10HudSkin.use(skin, pal)
	var W: = stage.size.x
	var H: = stage.size.y
	if skin == "five_winds":
		_bg("res://assets/bg/bg_teahouse.webp", Color(0.6, 0.56, 0.6))
	else:
		V10HudSkin.menu_bg(stage, Rect2(Vector2.ZERO, stage.size))
	# heroine: magazine cover — she leaves past the right edge (UX §6.8)
	var art: = _hero_art(hero, outfit)
	if art:
		var tr: = TextureRect.new()
		tr.texture = art
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var hh: = H * 0.74
		tr.size = Vector2(hh * art.get_width() / art.get_height(), hh)
		tr.position = Vector2(W - tr.size.x * 0.86, H * 0.08)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fm: = ShaderMaterial.new()
		fm.shader = preload("res://scripts/v10/look/art_fade.gdshader")
		fm.set_shader_parameter("top", 0.04)
		tr.material = fm
		stage.add_child(tr)
	var shade: = _Shade.new()
	shade.col = V10HudSkin.tok("night_900")
	shade.size = stage.size
	stage.add_child(shade)
	# status (UX §3.3, 0–88): avatar in the kit frame + nick on the left. No currencies on Чайная.
	var cur: = V10Look.resolve(hero, outfit)
	var fr: = V10FrameView.make(String(cur.frame), hero if V10ProfileCos.released(hero) else "mc", 72.0, {"anim": false})
	fr.position = Vector2(24, 12)
	stage.add_child(fr)
	_label("Лунный Лис", 22, V10HudSkin.tok("paper_100"), Vector2(108, 34), 260)
	# spine
	var sp: = V10HudSkin.label("ЧАЙНАЯ · ВЕЧЕР · 21:40", 15, Color(V10HudSkin.tok("paper_100"), 0.4))
	sp.rotation = -PI * 0.5
	sp.position = Vector2(12, H * 0.62)
	sp.size = Vector2(360, 20)
	stage.add_child(sp)
	# overline + display title (magazine cover)
	_label("СЕГОДНЯ В ЧАЙНОЙ", 15, V10HudSkin.tok("gold_500"), Vector2(40, H * 0.2), 300)
	var t: = _label(V10ProfileCos.hero_name(hero), 64, V10HudSkin.tok("paper_100"), Vector2(40, H * 0.2 + 26), 380, "display")
	t.size.y = 90
	_label(String(cur.kit_name), 22, V10HudSkin.tok("paper_300"), Vector2(40, H * 0.2 + 116), 360)
	# action (UX §3.3): partner plate 200 px on the left, ★ «Играть · 1-4» 440×104 on the right with its overline;
	# the extra height of 9:20 goes into the scene, so the action zone is anchored to the navbar
	var nav_h: = 112.0
	var ay: = H - nav_h - 24.0 - 104.0
	var pm: = V10HudSkin.plate("M", V10ProfileCos.hero_name(hero), "Партнёр", Rect2(32, ay + 12, 200, 80))
	pm.set_meta("ux_role", "secondary")
	stage.add_child(pm)
	_label("ПУТЬ · ЧАЙНЫЙ САД", 15, V10HudSkin.tok("gold_500"), Vector2(W - 32 - 440, ay - 26), 440).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(V10HudSkin.button("play", "Играть · 1-4", Rect2(W - 32 - 440, ay, 440, 104)))
	V10HudSkin.tabs(stage, ["Чайная", "Героини", "Столы", "Желания", "Лавка"], 0, Rect2(0, H - nav_h, W, nav_h))
	await _wait(0.2)
	await _shot("home_%s" % tag, 4)


func _view_home() -> void:
	await _home("five_winds", "", "mc", "o_base", "five_winds")
	await _home("zlata", "firebird", "zlata", "zl_base", "zlata")
	await _home("zlata", "ember", "zlata", "zl_ember", "zlata_ember")
	await _home("zlata", "dawn", "zlata", "zl_vow", "zlata_dawn")


# the one window template every skin dresses: the confirmation sheet of UX §5.3 (Касса is its primary)
func _view_window() -> void:
	for skin in ["five_winds", "zlata"]:
		_clear()
		V10HudSkin.use(skin, "")
		_bg("res://assets/bg/bg_teahouse_blur.webp", Color(0.5, 0.48, 0.52))
		var W: = stage.size.x
		var H: = stage.size.y
		var wh: = 820.0
		var w: = V10HudSkin.window(stage, "Набор первого гостя", Rect2(32, (H - wh) * 0.5, W - 64, wh))
		var inset: = 56.0 if V10HudSkin.skinned() else 32.0
		var iw: = w.size.x - inset * 2.0
		var y: = inset + 70.0
		var cap: = V10HudSkin.label("ТЫ ПОЛУЧИШЬ", 15, V10HudSkin.tok("gold_500"))
		cap.position = Vector2(inset, y)
		cap.size = Vector2(iw, 20)
		w.add_child(cap)
		y += 28.0
		for row in [["300 Лунного камня", "= 2 желания"], ["Рамка «Первый гость»", ""]]:
			var p: = V10HudSkin.plate("S", row[0], "", Rect2(inset, y, iw, 48))
			w.add_child(p)
			if row[1] != "":
				var n: = V10HudSkin.label(row[1], 22, V10HudSkin.tok("paper_300"))
				n.position = Vector2(iw - 196, 6)
				n.size = Vector2(180, 36)
				n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				p.add_child(n)
			y += 60.0
		y += 12.0
		var price: = V10HudSkin.label("149 ₽", 40, V10HudSkin.tok("gold_300"), "num")
		price.position = Vector2(inset, y)
		price.size = Vector2(200, 48)
		w.add_child(price)
		var rate: = V10HudSkin.label("≈ 74 ₽ за желание", 22, V10HudSkin.tok("paper_300"))
		rate.position = Vector2(inset + iw - 260, y + 10)
		rate.size = Vector2(260, 32)
		rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		w.add_child(rate)
		y += 56.0
		var spent: = V10HudSkin.label("Потрачено за 30 дней: 528 ₽ из 3 000", 18, V10HudSkin.tok("paper_500"))
		spent.position = Vector2(inset, y)
		spent.size = Vector2(iw, 26)
		w.add_child(spent)
		var pay: = V10HudSkin.button("cash", "Оплатить · 149 ₽", Rect2(inset, w.size.y - inset - 236, iw, 88))
		pay.set_meta("ux_role", "primary")
		w.add_child(pay)
		w.add_child(V10HudSkin.button("secondary", "Отмена", Rect2(inset, w.size.y - inset - 136, iw, 80)))
		var foot: = V10HudSkin.label("Оферта · Покупка окончательна после зачисления", 18, V10HudSkin.tok("paper_500"))
		foot.position = Vector2(inset, w.size.y - inset - 44)
		foot.size = Vector2(iw, 26)
		foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		w.add_child(foot)
		await _wait(0.2)
		await _shot("window_%s_open" % skin, 1)
		await _wait(0.8)
		await _shot("window_%s" % skin, 2)


func _view_kit() -> void:
	_clear()
	_bg("", Color.WHITE)
	_label("Набор героини", 44, V10HudSkin.tok("paper_100"), Vector2(24, 20), 672, "display")
	var cases: = [["mc", "o_base"], ["mc", "o_dragon"], ["rin", "r_agent"], ["hana", "h_gym"], ["yue", "y_queen"], ["nova", "n_ssr"], ["zlata", "zl_base"]]
	var y: = 96.0
	for c in cases:
		var r: = V10Look.resolve(c[0], c[1])
		_label("%s · %s · набор %s" % [V10ProfileCos.hero_name(c[0]), V10KitData.outfit_name(c[1]), r.rank], 18, V10HudSkin.tok("paper_300"), Vector2(24, y), 672)
		var s: = V10KitStrip.make(c[0], c[1], 672)
		s.position = Vector2(24, y + 26)
		stage.add_child(s)
		y += 164
	await _shot("kit_strips", 8)


func _view_style() -> void:
	_clear()
	var S: = save_for("mc", "o_dragon", ["s_night", "s_mint", "r_agent", "y_queen"])
	var p: = V10StylePicker.make(S, stage.size)
	stage.add_child(p)
	await _shot("style_picker", 10)


func _view_picker() -> void:
	_clear()
	var S: = save_for("rin", "r_agent", ["o_dragon", "s_night", "s_neon", "h_gym", "y_queen", "n_ssr"])
	stage.add_child(V10TilePicker.make(S, stage.size))
	await _shot("tile_picker", 10)
	_clear()
	stage.add_child(V10TilePicker.make(S, stage.size, {"ranked": true}))
	await _shot("tile_picker_ranked", 10)


func _view_fonts() -> void:
	_clear()
	_bg("", Color.WHITE)
	_label("Шрифты героинь на моментах", 44, V10HudSkin.tok("paper_100"), Vector2(24, 16), 672, "display")
	var skins: = ["", "zlata", "minamo", "kira", "vesper", "sigrid"]
	var y: = 84.0
	for sk in skins:
		var look: = {"font": sk}
		var who: String = "Базовый (Playfair)" if sk == "" else V10ProfileCos.hero_name(sk)
		_label(who.to_upper(), 15, V10HudSkin.tok("gold_500"), Vector2(24, y), 400)
		# line 1: screen title at its real 600 px budget; line 2: ult name + «Победа!»; line 3: signature + price
		_font_line(V10LookFonts.fit("screen_title", "Шансы и правила", 600, look), "Шансы и правила", 40, V10HudSkin.tok("paper_100"), Vector2(24, y + 18))
		_font_line(V10LookFonts.fit("ult_name", "Огненный шлейф", 420, look), "Огненный шлейф", 34, V10HudSkin.tok("rose_300"), Vector2(24, y + 70))
		_font_line(V10LookFonts.fit("victory", "Победа!", 220, look), "Победа!", 40, V10HudSkin.tok("gold_300"), Vector2(470, y + 64))
		var sign: String = "— твоя %s" % ("Маджонг-тян" if sk == "" else who)
		_font_line(V10LookFonts.fit("letter_sign", sign, 400, look), sign, 30, V10HudSkin.tok("paper_300"), Vector2(24, y + 120))
		# a price is always Nunito, in real units (UX §5.2 п. 2)
		var pr: = Label.new()
		pr.text = "≈ 164 ₽ за желание"
		var pls: = LabelSettings.new()
		pls.font = V10LookFonts.price_font()
		pls.font_size = 22
		pls.font_color = V10HudSkin.tok("gold_300")
		pr.label_settings = pls
		pr.position = Vector2(stage.size.x - 24 - 240, y + 128)
		pr.size = Vector2(240, 30)
		pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stage.add_child(pr)
		y += 196
	await _shot("fonts_moments", 6)


func _font_line(f: Dictionary, text: String, cap: int, col: Color, pos: Vector2) -> void:
	var l: = Label.new()
	l.text = text
	var ls: = LabelSettings.new()
	ls.font = f.font
	ls.font_size = mini(int(f.size), cap)
	ls.font_color = col
	l.label_settings = ls
	l.position = pos
	stage.add_child(l)


func _view_card() -> void:
	_clear()
	_bg("res://assets/bg/bg_palace_blur.webp", Color(0.45, 0.42, 0.5))
	var S: = save_for("yue", "y_queen", ["s_night"])
	var prof: Dictionary = S.get("profile", {}).duplicate()
	prof["nick"] = "Лунный Лис"
	S["profile"] = prof
	var p: = V10LookCard.payload(S, {"league": 3, "games_week": 41})
	print("CARD validate: '", V10LookCard.validate(p), "' bytes ", V10CardPayload.size_bytes(p))
	var cv: = V10LookCard.view(p, Rect2(30, 120, 660, 880), "other")
	stage.add_child(cv)
	await _wait(1.6)
	await _shot("card_other", 4)
	_clear()
	_bg("", Color.WHITE)
	_label("Лига · строки (рубашка темы)", 26, V10HudSkin.tok("paper_100"), Vector2(24, 24), 672)
	var rng: = RandomNumberGenerator.new()
	rng.seed = 7
	var mine: = V10LookCard.payload(save_for("mc", "o_dragon"), {"league": 2})
	mine["pts"] = 1880
	mine["me"] = true
	var y: = 80.0
	for i in 8:
		var q: = mine if i == 2 else V10LookCard.sim(rng, 2)
		if i != 2:
			q["pts"] = 2400 - i * 90
		var row: = V10LookCard.view(q, Rect2(24, y, 672, 84), "row")
		stage.add_child(row)
		y += 92
	await _wait(0.4)
	await _shot("league_rows", 4)


func _view_assemble() -> void:
	_clear()
	await _home("zlata", "firebird", "zlata", "zl_base", "zlata_pre")
	var home: = stage
	V10HudSkin.reset_sting()
	var a: = V10SkinAssemble.play(self, home, "zlata")
	await _wait(0.28)
	await _shot("assemble_zlata_mid", 1)
	await _wait(0.7)
	await _shot("assemble_zlata", 2)
	a.queue_free()


func _view_preview() -> void:
	await _home("zlata", "firebird", "zlata", "zl_base", "zlata_tryon_base")
	# right under the status row (UX §3.3, 0–88), clear of her face
	V10PreviewBar.open(stage, "zlata", "zl_base", Callable(), 92)
	await _shot("preview_bar", 6)
	V10Look.end_preview()


func _view_loading() -> void:
	_clear()
	V10HudSkin.use("zlata")
	V10HudSkin.loading(stage, Rect2(Vector2.ZERO, stage.size))
	var shade: = _Shade.new()
	shade.col = V10HudSkin.tok("night_900")
	shade.size = stage.size
	shade.bottom_only = true
	stage.add_child(shade)
	var W: = stage.size.x
	var H: = stage.size.y
	var bar: = Control.new()
	bar.position = Vector2(64, H - 120)
	bar.size = Vector2(W - 128, 56)
	bar.add_child(V10HudSkin.nine("currency", bar.size))
	stage.add_child(bar)
	_label("Весна идёт…", 22, V10HudSkin.tok("paper_100"), Vector2(64, H - 180), W - 128).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	await _shot("loading_zlata", 6)


# ------------------------------------------------------------------------------------------------- drawables

class _Shade extends Control:
	var col: = Color.BLACK
	var bottom_only: = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_grad(Vector2(0, 0.5), Vector2(0, 1), Color(col, 0.0), Color(col, 0.88), Rect2(0, size.y * 0.5, size.x, size.y * 0.5)))
		if not bottom_only:
			add_child(_grad(Vector2(0, 0), Vector2(1, 0), Color(col, 0.62), Color(col, 0.0), Rect2(0, 0, size.x * 0.62, size.y)))

	func _grad(a: Vector2, b: Vector2, c0: Color, c1: Color, r: Rect2) -> TextureRect:
		var g: = Gradient.new()
		g.set_color(0, c0)
		g.set_color(1, c1)
		var gt: = GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0, 0) if a.y == 0.5 else a
		gt.fill_to = Vector2(0, 1) if b == Vector2(0, 1) else b
		gt.width = 64
		gt.height = 64
		var tr: = TextureRect.new()
		tr.texture = gt
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.position = r.position
		tr.size = r.size
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr


class _Arch extends Control:
	var tex: Texture2D
	var ring: = Color.WHITE

	func _draw() -> void:
		var c: = size * 0.5
		var r: = size.x * 0.5
		draw_circle(c, r, Color(0.07, 0.06, 0.07, 0.9), true, -1.0, true)
		if tex:
			# head-and-shoulders crop from the top centre of the art
			var tw: = float(tex.get_width())
			var th: = float(tex.get_height())
			var src: = Rect2(tw * 0.28, th * 0.04, tw * 0.44, tw * 0.44)
			var pts: = PackedVector2Array()
			var uvs: = PackedVector2Array()
			for i in 48:
				var a: = TAU * i / 48.0
				var p: = c + Vector2(cos(a), sin(a)) * (r - 4)
				pts.append(p)
				uvs.append((src.position + (p / size) * src.size) / Vector2(tw, th))
			draw_colored_polygon(pts, Color.WHITE, uvs, tex)
		draw_arc(c, r - 2, -PI * 0.5, -PI * 0.5 + TAU * 0.72, 64, ring, 4.0, true)
