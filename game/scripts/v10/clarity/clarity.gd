class_name V10Clarity
extends RefCounted

# Entry points of the clarity lane (all hooks are one line each — see README.md):
#   attach_play(play)                     play.build, after _v9_dev(): tile bubble + lupa, the «Фишки» pill and the clear
#                                         goal plate, the one-time tips, dev flags
#   victory(play, plate, x, y, w, stars, reward) -> float   play._victory instead of _v8_yaku_chips
#   settings_hook(main, popup)            main.settings(), last line: the «Фишки и словарь» row
#   open_settings(host) / open_legend(host) / open_glossary(host, cat)
#
# Dev (with --screen=play):
#   --v10_open=legend|glossary|settings|bubble|lupa|why|card   opens it once the table is playable (why/card: on the victory)
#   --v10_marks=on|off|auto   --v10_big=1|0                    set the options for this run (not saved to a real save)
#   --v10_tab=<cat>                                            glossary section to open

static func _arg(name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return ""

static func _dev_opts() -> void:
	var m: = _arg("v10_marks")
	if m != "":
		V10ClarityState.st().marks = m
		V10ClarityState.st().asked = true
	var b: = _arg("v10_big")
	if b != "":
		V10ClarityState.st().big = b == "1"

static func attach_play(play) -> void:
	_dev_opts()
	var ti: = V10TileInfo.attach(play)
	_goal_plate(play)
	_tips(play, ti)
	var op: = _arg("v10_open")
	if op != "" and not op in ["why", "card"]:
		_dev_open(play, ti, op)
	if _arg("v10_tour") != "":
		V10ClarityTour.run(play, ti, _arg("v10_tour"))

static func open_legend(host: Node) -> void:
	V10Legend.open(host)

static func open_glossary(host: Node, cat: = "") -> void:
	V10GlossaryScreen.open(host, cat)

# ── the goal plate: «ФИШЕК 54» with a tile icon (not «ЦЕЛЬ» + sakura), and the «Фишки» pill → legend ───────────
static func _goal_plate(play) -> void:
	var gp: Control = null
	for c in play.get_children():
		if c is RBox:
			for l in c.get_children():
				if l is Label and l.text == V6Txt.s("play.goal"):
					gp = c
					l.text = "ФИШЕК НА СТОЛЕ"
					break
		if gp:
			break
	if gp == null:
		return
	for c in gp.get_children():
		if c is TextureRect and c.texture == G.tile_tex(0):
			var r: = Rect2(c.position, c.size)
			c.queue_free()
			var t: = V10ClarityIcon.make("state:back", r.size.x + 6, r.position - Vector2(3, 3))
			gp.add_child(t)
			break
	if String(play.mode) == "duel":
		return
	var pill: = UI.rbox("plum", Rect2(112, 58, 84, 40), 20, 2, 4)
	pill.borders(Color("ffe7a6"), Color("c58a2c"))
	pill.mouse_filter = Control.MOUSE_FILTER_STOP
	pill.name = "V10LegendPill"
	gp.add_child(pill)
	var q: = UI.rbox("gold", Rect2(5, 8, 24, 24), 12, 1, 2)
	pill.add_child(q)
	q.add_child(UI.center_label(UI.label("?", 17, Color("5a3208"), Color(0, 0, 0, 0), 0, "body", 900), Rect2(0, -1, 24, 24)))
	var l2: = UI.label("Фишки", 15, Color("ffe7a6"), UI.DARK, 2, "body", 900)
	l2.position = Vector2(32, 0)
	l2.size = Vector2(50, 40)
	l2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.add_child(l2)
	V10Breakdown._tappable(pill, func(): V10Legend.open(play))

# ── one-time tips: long press (heroine line), the marks question after table 10 ─────────────────────────────────
static func _tips(play, ti: V10TileInfo) -> void:
	var tut: bool = bool(play.get("tut"))
	if tut or String(play.mode) in ["duel", "blitz"]:
		return
	var tree: SceneTree = play.get_tree()
	var wait_ready: = func() -> bool:
		var guard: = 0
		while is_instance_valid(play) and play.is_inside_tree() and not play.board.input_on and guard < 400:
			guard += 1
			await tree.create_timer(0.1).timeout
		return is_instance_valid(play) and play.is_inside_tree()
	if V10ClarityState.ask_due(int(play.lvl)) and String(play.mode) == "":
		if await wait_ready.call():
			await tree.create_timer(1.2).timeout
			if is_instance_valid(play) and play.is_inside_tree():
				_ask_marks(play)
		return
	var said: = false
	if not V10ClarityState.tip_done("longpress") and int(play.lvl) >= 1:
		if await wait_ready.call():
			await tree.create_timer(2.5).timeout
			if is_instance_valid(play) and play.is_inside_tree() and play.has_method("_bubble"):
				V10ClarityState.mark_tip("longpress")
				play._bubble("Не знаешь, что за фишка? Подержи на ней палец — расскажу!")
				said = true
	# once, said aloud: the coloured corner is NOT the pair (players paired by colour / by the digit)
	if not V10ClarityState.tip_done("corner") and V10TileMarks.on():
		if await wait_ready.call():
			await tree.create_timer(11.0 if said else 2.5).timeout
			if is_instance_valid(play) and play.is_inside_tree() and play.has_method("_bubble"):
				V10ClarityState.mark_tip("corner")
				play._bubble("Цвет уголка — не пара! Пара — только одинаковая картинка.")

static func _ask_marks(play) -> void:
	var W: float = play.size.x
	var y: float = float(play.size.y) - 300.0
	var card: = UI.rbox("cream", Rect2(20, y, W - 40, 150), 26, 3, 8)
	card.borders(Color("ffe7a6"), Color("c58a2c"))
	card.z_index = 140
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	play.add_child(card)
	var holder: = Node2D.new()
	card.add_child(holder)
	var t: = V10ClarityIcon.mini_tile(17)
	t.position = Vector2(62, 62)
	holder.add_child(t)
	var l: = UI.label("Цветные уголки на фишках помогают видеть масти. Оставить их?", 19, UI.INK, UI.DARK, 2, "body", 900)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(120, 10)
	l.size = Vector2(W - 40 - 136, 60)
	card.add_child(l)
	var keep: = JButton.make("Оставить", "pink", Rect2(120, 78, 220, 60), null, 22)
	var drop: = JButton.make("Убрать", "glass", Rect2(352, 78, 180, 60), null, 22)
	card.add_child(keep)
	card.add_child(drop)
	var done: = func(v: bool):
		V10ClarityState.answer(v)
		V10TileMarks.refresh_all()
		if is_instance_valid(card):
			var tw: = card.create_tween()
			tw.tween_property(card, "modulate:a", 0.0, 0.2)
			tw.tween_callback(card.queue_free)
	keep.pressed.connect(done.bind(true))
	drop.pressed.connect(done.bind(false))
	UI.slide_in(card, Vector2(0, 40), 0.0, 0.35)

# ── victory ─────────────────────────────────────────────────────────────────────────────────────────────────────
static func victory(play, plate: Control, x: float, y: float, w: float, stars: int, reward: int) -> float:
	play.set_meta("v10_win", {"stars": stars, "reward": reward})
	_victory_words(play, plate)
	var yy: = V10Breakdown.build(play, plate, x, y, w, stars, reward)
	var op: = _arg("v10_open")
	if op in ["why", "card"]:
		var at: float = float(play.get("_v9_yaku_at")) + 2.6
		play.get_tree().create_timer(at).timeout.connect(func():
			if not is_instance_valid(play):
				return
			if op == "why":
				V10Breakdown.summary(play, stars, reward)
			else:
				var rows: = V10Breakdown.rows_for(play)
				var id: String = rows[1].id if rows.size() > 1 else "win.base"
				V10InfoCard.open(play, id, {"points": "+%d очка ранга" % V10Glossary.bonus_points(String(rows[1].yaku)) if rows.size() > 1 else "", "count": 1}))
	return yy

# the rank card and the weekly-race row above the bonuses: one word per system, and a tap explains it.
#   rank card «Нефрит I»  → the rank card «Ранг «Нефрит»: …» (it never falls; the league is separate)
#   «Лига Бамбука · #4 из 20» → «Гонка недели · #4 из 20 · лига Бамбука»; «Квартал: …» → «Сезон: …»; tap → both explained
static func _victory_words(play, plate: Control) -> void:
	for c in plate.get_children():
		if not (c is RBox):
			continue
		var box: = c as RBox
		if box.get_node_or_null("Em") != null and box.has_meta("bar"):
			var tier: = int(G.rank_of(int(G.S.rp)).tier)
			_help_dot(box, Vector2(box.size.x - 34, box.size.y - 34))
			box.mouse_filter = Control.MOUSE_FILTER_STOP
			V10Breakdown._tappable(box, func(): V10InfoCard.open(play, "rank.%d" % tier, {}))
			continue
		var league_lbl: Label = null
		var season_lbl: Label = null
		for l in box.get_children():
			if l is Label:
				var t: String = (l as Label).text
				if t.begins_with("Лига ") and " из " in t:
					league_lbl = l
				elif "вартал" in t:
					season_lbl = l
		if league_lbl == null:
			continue
		var t1: String = league_lbl.text
		var cut: = t1.find(" · ")
		if cut > 0:
			var lname: = "лига" + t1.substr(4, cut - 4)
			var nt: = "Гонка недели · " + t1.substr(cut + 3)
			var with_league: = nt + " · " + lname
			var fs: = league_lbl.get_theme_font_size("font_size") if league_lbl.label_settings == null else league_lbl.label_settings.font_size
			league_lbl.text = with_league if UI.font("body", 900).get_string_size(with_league, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x < league_lbl.size.x - 34.0 else nt
		if season_lbl:
			season_lbl.text = season_lbl.text.replace("Квартал", "Сезон").replace("квартала", "сезона").replace("квартал", "сезон")
		_help_dot(box, Vector2(box.size.x - 34, (box.size.y - 26) * 0.5))
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		V10Breakdown._tappable(box, func():
			var w: = V10Glossary.get_entry("win.week")
			var se: = V10Glossary.get_entry("win.season")
			V10InfoCard.open_text(play, "Гонка недели и сезон", "это не ранг", "league:0",
				[["Гонка недели", "%s. %s" % [w.why, w.how]], ["Сезон", "%s. %s" % [se.why, se.how]],
				["Ранг", V10Glossary.RANK_WHY]], "", false, "win"))

# a small gold «?» on anything that opens an explanation by a tap
static func _help_dot(parent: Control, at: Vector2) -> void:
	var q: = UI.rbox("gold", Rect2(at, Vector2(26, 26)), 13, 1, 2)
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(q)
	q.add_child(UI.center_label(UI.label("?", 17, Color("5a3208"), Color(0, 0, 0, 0), 0, "body", 900), Rect2(0, -1, 26, 26)))

# ── settings ────────────────────────────────────────────────────────────────────────────────────────────────────
const SETTINGS_EXTRA: = 84.0

# one line at the end of main.settings(): grows the popup and adds the «Фишки и словарь» row above the footer lines
static func settings_hook(main, p: Control) -> void:
	var y0: = 900.0
	for c in p.get_children():
		if c is Control and (c as Control).position.y >= y0 - 2.0 and c.name != "PanelArt":
			(c as Control).position.y += SETTINGS_EXTRA
	p.size.y += SETTINGS_EXTRA
	var root = p.get_meta("root") if p.has_meta("root") else null
	if root is Control and p.position.y + p.size.y > (root as Control).size.y - 10.0:
		p.position.y = maxf(20.0, (root as Control).size.y - 10.0 - p.size.y)
	var l: = UI.label("Фишки и словарь", 26, UI.INK, Color.WHITE, 3, "body", 900)
	l.position = Vector2(34, y0 + 2)
	p.add_child(l)
	var d: = UI.label("Цветной уголок, крупные символы, все названия", 17, Color("8a5a7a"))
	d.position = Vector2(34, y0 + 42)
	p.add_child(d)
	var b: = JButton.make("Открыть", "lav", Rect2(470, y0 + 8, 158, 64), null, 22)
	b.pressed.connect(func(): open_settings(main))
	p.add_child(b)

static func open_settings(host: Node) -> void:
	var m = host if host.get("overlay") != null else host.get("main")
	if m == null:
		return
	var p: = Common.popup(m, "Фишки и словарь", 880)
	var y: = 56.0
	# marks: 3-way
	var l: = UI.label("Цветной уголок на фишках", 25, UI.INK, Color.WHITE, 3, "body", 900)
	l.position = Vector2(34, y)
	p.add_child(l)
	var hint: = UI.label("", 17, Color("8a5a7a"))
	hint.position = Vector2(34, y + 104)
	hint.size = Vector2(592, 24)
	p.add_child(hint)
	var opts: = [["auto", "Авто"], ["on", "Вкл"], ["off", "Выкл"]]
	var hints: = {"auto": "Первые 10 столов включены, потом спрошу", "on": "Уголок масти на каждой фишке (пару он не задаёт)", "off": "Фишки без уголков"}
	var btns: = []
	var preview: = Node2D.new()
	var paint: = func():
		var cur: = V10ClarityState.marks_mode()
		for i in btns.size():
			Common.tab_paint(btns[i], opts[i][0] == cur)
		hint.text = hints.get(cur, "")
		V10TileMarks.refresh_all()
		for t in preview.get_children():
			var mk: = t.get_node_or_null("V10Marks")
			if mk:
				mk.always = V10ClarityState.marks_on()
				mk.queue_redraw()
	for i in opts.size():
		var b: = JButton.make(String(opts[i][1]), "glass", Rect2(34 + i * 200, y + 38, 188, 60), null, 22, -1.0, false)
		var k: String = opts[i][0]
		b.pressed.connect(func():
			V10ClarityState.set_marks(k)
			paint.call())
		p.add_child(b)
		btns.append(b)
	y += 146.0
	var l2: = UI.label("Крупные символы\nи контраст", 25, UI.INK, Color.WHITE, 3, "body", 900)
	l2.position = Vector2(34, y - 4)
	p.add_child(l2)
	var d2: = UI.label("Уголок вдвое крупнее, зажатые фишки темнее", 17, Color("8a5a7a"))
	d2.position = Vector2(34, y + 72)
	p.add_child(d2)
	var on: = V10ClarityState.big()
	var bb: = JButton.make(V6Txt.s("common.on") if on else V6Txt.s("common.off"), "mint" if on else "glass", Rect2(500, y + 14, 128, 64), null, 24)
	bb.pressed.connect(func():
		var v: = not V10ClarityState.big()
		V10ClarityState.set_big(v)
		bb.lbl.text = V6Txt.s("common.on") if v else V6Txt.s("common.off")
		bb.set_pal("mint" if v else "glass")
		paint.call())
	p.add_child(bb)
	y += 116.0
	# live preview: a free pair and a blocked tile
	var pv: = UI.rbox("glass", Rect2(34, y, 592, 150), 22, 2, 4)
	p.add_child(pv)
	pv.add_child(preview)
	var faces: = [[17, "free"], [17, "free"], [19, "blocked"], [25, "gold"], [0, "flip"]]
	for i in faces.size():
		var t: = V10ClarityIcon.mini_tile(int(faces[i][0]), String(faces[i][1]))
		t.position = Vector2(70 + i * 113, 75)
		preview.add_child(t)
	y += 170.0
	var b1: = JButton.make("Фишки: как читать", "pink", Rect2(34, y, 592, 84), null, 24)
	b1.pressed.connect(func(): V10Legend.open(m))
	p.add_child(b1)
	var b2: = JButton.make("Словарь: все названия", "lav", Rect2(34, y + 100, 592, 84), null, 24)
	b2.pressed.connect(func(): V10GlossaryScreen.open(m))
	p.add_child(b2)
	paint.call()

# ── dev ─────────────────────────────────────────────────────────────────────────────────────────────────────────
static func _dev_open(play, ti: V10TileInfo, op: String) -> void:
	var tree: SceneTree = play.get_tree()
	var guard: = 0
	while is_instance_valid(play) and play.is_inside_tree() and not play.board.input_on and guard < 300:
		guard += 1
		await tree.create_timer(0.1).timeout
	if not is_instance_valid(play) or not play.is_inside_tree():
		return
	await tree.create_timer(0.4).timeout
	match op:
		"legend":
			V10Legend.open(play)
		"glossary":
			V10GlossaryScreen.open(play, _arg("v10_tab"))
		"settings":
			open_settings(play)
		"lupa":
			ti.set_lupa(true)
		"bubble":
			# the most telling tile: a blocked one with a face, else any
			var pick: Tile = null
			for t in play.board.tiles:
				if play.board.on_board(t) and t.back_spr == null and t.shard == "" and not play.board.is_free(t) and t.face < 36:
					var visible_enough: = true
					for o in play.board.cov.get(t, []):
						if play.board.on_board(o):
							visible_enough = false
					if visible_enough:
						pick = t
						break
			if pick == null:
				for t in play.board.tiles:
					if play.board.on_board(t) and t.face < 36:
						pick = t
						break
			if pick:
				ti.show_for(pick)
