class_name V10MjClassicScreen
extends Control

# «Классика» match screen (MODES §4 frame + §4.1). Contract MODES §7.1:
#   setup(main, args) — args: form (id), variant ("free" | "daily"), diff, seed, hero, presence, look, view, fx,
#                       date (daily, MSK), no_save (demo / selftest)
#   signal finished(result) — {mode, variant, form, win, score, stars, time_s, pairs, moves, hints, shuffles, hero,
#                              seed, diff, rewards:{coins, gems, petals, aff}, rank_up, gifts, next: "again" | "exit"}
# Rewards are computed by V10MjClassicData.record() and returned, never credited here (the integrator does it).
#
# Layout (720 wide, any height): her band on top (120 px + the extra height of tall phones, capped), the table, the
# help row (3 round buttons: Подсказка ∞ · Отмена ∞ · Перемешать ∞). Budget in play: 5 tappables (pause, 3 help,
# her window), ≤ 8 words, 0 badges, 1 progress bar.

signal finished(result: Dictionary)

const BAND_MIN: = 120.0
const BAND_MAX: = 380.0
const HELP_H: = 150.0
const IDLE_S: = 20.0
const COMBO_WINDOW: = 4.0

var main: Node
var args: = {}
var form: = {}
var variant: = "free"
var diff: = "normal"
var hero: = "mc"
var seed_: = 1
var date: = ""
var board: V10MjClassicBoard
var presence: Object
var field: Control
var table: ColorRect
var bg: TextureRect
var shade: ColorRect
var pause_btn: V10MjClassicStyle.Btn
var goal: Label
var bar: Control
var help: Array = []
var combo_lbl: Label
var banner: Label
var sheet: Control
var time_s: = 0.0
var running: = false
var paused: = false
var combo: = 0
var last_pair_t: = -100.0
var last_key: = -1
var idle_t: = 0.0
var note_t: = 0.0
var band_h: = BAND_MIN
var fx: = "full"
var result: = {}
var no_save: = false
var _bar_k: = 0.0


func setup(main_: Node, a: Dictionary) -> void:
	main = main_
	args = a
	variant = String(a.get("variant", "free"))
	date = String(a.get("date", V10MjClassicData.msk_date()))
	var fid: String = String(a.get("form", ""))
	if variant == "daily":
		fid = V10MjClassicData.daily_form(date)
	if fid == "" or V10MjClassicLayouts.get_form(fid).is_empty():
		fid = "turtle"
	form = V10MjClassicLayouts.get_form(fid)
	diff = String(a.get("diff", "normal"))
	if variant == "daily":
		diff = "normal"
	seed_ = int(a.get("seed", V10MjClassicData.date_seed(date) if variant == "daily" else randi() % 1000000 + 1))
	hero = String(a.get("hero", _partner()))
	fx = String(a.get("fx", G.fx_level() if G.has_method("fx_level") else "full"))
	no_save = bool(a.get("no_save", false))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if is_inside_tree() and board == null:
		_build()


func _ready() -> void:
	if not form.is_empty() and board == null:
		_build()


func _partner() -> String:
	var p: = "mc"
	if G.get("S") is Dictionary:
		p = String(G.S.get("partner", "mc"))
	return p if V10MjClassicStyle.HERO_ACCENT.has(p) else "mc"


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var T: = V10MjClassicStyle.TOK
	var acc: = V10MjClassicStyle.accent(hero)
	# her salon zone, blurred and lowered (70 % night)
	bg = TextureRect.new()
	var bgp: = "res://assets/bg/%s.webp" % V10MjClassicStyle.HERO_BG.get(hero, "menu_blur")
	if ResourceLoader.exists(bgp):
		bg.texture = load(bgp)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	shade = ColorRect.new()
	shade.color = Color(T.night900, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	table = ColorRect.new()
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(table)
	field = Control.new()
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)
	board = V10MjClassicBoard.new()
	field.add_child(board)
	var d: = V10MjClassicData.st()
	board.setup(form, seed_, diff, {"look": args.get("look", {}), "view": String(args.get("view", d.view)),
		"light": V10MjClassicData.light_free() if not no_save else true, "accent": acc, "fx": fx})
	board.picked.connect(_on_pick)
	board.paired.connect(_on_pair)
	board.shuffled.connect(_on_shuffle)
	board.cleared.connect(_on_clear)
	board.changed.connect(_refresh)
	board.denied.connect(func(_t): idle_t = 0.0)
	# band
	pause_btn = V10MjClassicStyle.Btn.new("quiet", "", "pause")
	pause_btn.size = Vector2(80, 80)
	pause_btn.pressed.connect(open_pause)
	add_child(pause_btn)
	goal = V10MjClassicStyle.label("", 24, T.paper100, "body", 800)
	V10MjClassicStyle.shadow(goal, 0.5)
	add_child(goal)
	bar = V10MjClassicStyle.Paint.new(_draw_bar)
	add_child(bar)
	# help row
	for spec in [["hint", "Подсказка"], ["undo", "Отмена"], ["shuffle", "Перемешать"]]:
		var b: = V10MjClassicStyle.Btn.new("help", spec[1], spec[0])
		b.count = "∞"
		b.size = Vector2(120, 132)
		add_child(b)
		help.append(b)
	help[0].pressed.connect(func():
		idle_t = 0.0
		board.hint())
	help[1].pressed.connect(func():
		idle_t = 0.0
		if not board.undo():
			V9Feel.deny(help[1]))
	help[2].pressed.connect(func():
		idle_t = 0.0
		if board.input_on:
			board.shuffle(false))
	combo_lbl = V10MjClassicStyle.label("", 52, T.gold300, "title", 700)
	combo_lbl.label_settings.font = load("res://assets/fonts/playfair-i-cyr.woff2")
	V10MjClassicStyle.shadow(combo_lbl, 0.7)
	combo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_lbl.modulate.a = 0.0
	combo_lbl.z_index = 400
	add_child(combo_lbl)
	banner = V10MjClassicStyle.label(form.name, 44, T.paper100, "title", 700)
	V10MjClassicStyle.shadow(banner, 0.8)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0
	banner.z_index = 400
	add_child(banner)
	_layout()
	# her: the passed director, or the stage lane's, or the classic fallback
	presence = args.get("presence", null)
	if presence == null:
		presence = V10MjClassicPresence.make(self, hero, {"avoid": [pause_btn.get_rect(), goal.get_rect()], "board": board,
			"charge_need": 12, "z": 400, "band_rect": Rect2(0, 0, size.x, band_h), "fx": fx})
	_sacred()
	get_viewport().size_changed.connect(_on_resize)
	_refresh()
	_start()


func _on_resize() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout()


func _layout() -> void:
	var vs: = get_viewport_rect().size
	if vs.x <= 0.0:
		return
	var extra: = maxf(0.0, vs.y - 1280.0 * vs.x / 720.0)
	band_h = clampf(BAND_MIN + extra, BAND_MIN, BAND_MAX)
	bg.position = Vector2.ZERO
	bg.size = vs
	shade.position = Vector2.ZERO
	shade.size = vs
	var help_top: = vs.y - HELP_H - 24.0
	var fr: = Rect2(12, band_h + 14, vs.x - 24, help_top - band_h - 24)
	field.position = fr.position
	field.size = fr.size
	_table(fr.grow(10))
	board.fit(Rect2(Vector2(10, 10), fr.size - Vector2(20, 20)))
	pause_btn.position = Vector2(14, (band_h - 80) * 0.5 if band_h <= 140 else 20)
	goal.position = Vector2(104, pause_btn.position.y + 12)
	goal.size = Vector2(vs.x * 0.5, 34)
	bar.position = Vector2(106, goal.position.y + 42)
	bar.size = Vector2(minf(260.0, vs.x * 0.4), 6)
	var gap: = (vs.x - 3 * 120.0) / 4.0
	for i in help.size():
		var b: Control = help[i]
		b.position = Vector2(gap + i * (120.0 + gap), help_top + 6)
	combo_lbl.position = Vector2(0, fr.position.y + 4)
	combo_lbl.size = Vector2(vs.x, 64)
	banner.position = Vector2(0, fr.get_center().y - 40)
	banner.size = Vector2(vs.x, 64)
	if presence and presence.has_method("set_band"):
		presence.set_band(Rect2(0, 0, vs.x, band_h))
	if presence:
		_sacred()


func _sacred() -> void:
	if presence == null:
		return
	if presence.has_method("clear_sacred"):
		presence.clear_sacred()
	presence.sacred(field.get_global_rect())
	var hr: = Rect2()
	for b in help:
		hr = (b as Control).get_global_rect() if hr.size == Vector2.ZERO else hr.merge((b as Control).get_global_rect())
	presence.sacred(hr)


func help_rect() -> Rect2:
	var hr: = Rect2()
	for b in help:
		hr = (b as Control).get_global_rect() if hr.size == Vector2.ZERO else hr.merge((b as Control).get_global_rect())
	return hr


func _table(r: Rect2) -> void:
	var th: Dictionary = V6BoardTable.theme_for(String(V10MjClassicStyle.HERO_TABLE.get(hero, "default")))
	var margin: = 30.0
	table.position = r.position - Vector2(margin, margin)
	table.size = r.size + Vector2(margin, margin) * 2.0
	var mat: = ShaderMaterial.new()
	mat.shader = V6BoardTable.SHADER
	mat.set_shader_parameter("size", table.size)
	mat.set_shader_parameter("margin", margin)
	mat.set_shader_parameter("frame_w", 14.0)
	mat.set_shader_parameter("noise", load("res://assets/v06/board/table_noise.png"))
	for key in ["frame_a", "frame_b", "trim", "mat_a", "mat_b", "pat_col"]:
		mat.set_shader_parameter(key, th[key])
	mat.set_shader_parameter("pat_alpha", th.pat_alpha)
	mat.set_shader_parameter("pattern", th.pattern)
	mat.set_shader_parameter("pat_scale", th.pat_scale)
	mat.set_shader_parameter("fibre", th.fibre)
	mat.set_shader_parameter("neon", th.get("neon", 0.0))
	var lc: Color = th.lamp_col
	mat.set_shader_parameter("lamp_col", Vector3(lc.r, lc.g, lc.b))
	mat.set_shader_parameter("lamp_k", th.lamp_k)
	table.material = mat
	V6TileLook.lamp_col = lc
	V6TileLook.gloss = th.gloss
	V6TileLook.ambient = th.ambient
	V6TileLook.shadow_col = th.shadow


func _start() -> void:
	running = true
	time_s = 0.0
	# the form's name over the table (not over the band), gone in 0.8 s
	if fx != "min":
		var tw: = banner.create_tween()
		tw.tween_property(banner, "modulate:a", 1.0, 0.2)
		tw.tween_interval(0.4)
		tw.tween_property(banner, "modulate:a", 0.0, 0.2)
	board.deal_in(fx == "min")
	if variant == "daily":
		get_tree().create_timer(1.0).timeout.connect(func():
			if presence:
				presence.on("idle", {"kind": "daily", "text": "Сегодня у всех «%s». Посмотрим, кто быстрее?" % form.name}))


func _process(dt: float) -> void:
	if not running or paused:
		return
	time_s += dt
	idle_t += dt
	if idle_t >= IDLE_S:
		idle_t = 0.0
		if presence:
			presence.on("idle", {"kind": "wait"})
	if note_t > 0.0:
		note_t -= dt
		if note_t <= 0.0:
			_refresh()
	if presence and "input_on" in presence:
		presence.input_on = board.input_on and sheet == null


func _refresh() -> void:
	if note_t > 0.0:
		return
	goal.text = "Осталось %d · ходов %d" % [board.remaining(), board.moves]
	_bar_k = 1.0 - float(board.remaining()) / maxf(1.0, float(board.total()))
	bar.queue_redraw()


func _draw_bar(c: Control) -> void:
	var T: = V10MjClassicStyle.TOK
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(T.night600, 0.9))
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(c.size.x * _bar_k, c.size.y)), T.jade300)


func _note(text: String, t: = 2.2) -> void:
	goal.text = text
	note_t = t


# ---- board events -> her ------------------------------------------------------------------------------------
func _on_pick(_t: Tile, pos: Vector2) -> void:
	idle_t = 0.0
	if presence:
		presence.on("pick", {"pos": pos})


func _on_pair(_a: Tile, _b: Tile, pos: Vector2, key: int, face: int) -> void:
	idle_t = 0.0
	var now: = V10MjClassicStyle.now()
	combo = combo + 1 if now - last_pair_t < COMBO_WINDOW else 1
	last_pair_t = now
	V9Feel.tile_match(combo)
	if presence:
		presence.on("pair", {"pos": pos, "charge": clampf(float(board.moves) / 12.0 - floorf(float(board.moves) / 12.0), 0.0, 1.0)})
		if combo in [3, 5, 8, 12]:
			presence.on("combo", {"n": combo})
		if key == last_key:
			presence.on("motif", {})
		if V10MjClassicLayouts.SIGNATURE.get(hero, -1) == face:
			presence.on("signature", {})
		if board.remaining() == 2:
			presence.on("last_pair", {})
	last_key = key
	if combo >= 3:
		_show_combo(combo)


func _show_combo(n: int) -> void:
	combo_lbl.text = "×%d" % n
	if fx == "min":
		combo_lbl.modulate.a = 1.0
		get_tree().create_timer(0.6).timeout.connect(func(): combo_lbl.modulate.a = 0.0)
		return
	combo_lbl.pivot_offset = combo_lbl.size * 0.5
	var tw: = combo_lbl.create_tween()
	combo_lbl.scale = Vector2(0.8, 0.8)
	tw.tween_property(combo_lbl, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(combo_lbl, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.3)
	tw.tween_property(combo_lbl, "modulate:a", 0.0, 0.22)


func _on_shuffle(auto: bool) -> void:
	if auto:
		_note("Ходов нет — перемешала")
		if presence:
			presence.on("idle", {"kind": "shuffle"})


func _on_clear() -> void:
	running = false
	if board.zoom > 1.01:
		board.zoom_to(1.0, field.get_global_rect().get_center())
	board.flash_form(form.get("color", Color("e8c47e")))
	if presence:
		presence.on("win", {})
	var stars: = V10MjClassicData.stars_of(true, board.hints, board.shuffles)
	result = {"mode": "classic", "variant": variant, "form": form.id, "win": true, "score": board.moves * 10 + stars * 100,
		"stars": stars, "time_s": int(round(time_s)), "pairs": board.total() / 2, "moves": board.moves, "hints": board.hints,
		"shuffles": board.shuffles, "undos": board.undos, "hero": hero, "seed": seed_, "diff": diff,
		"rewards": {"coins": 0, "gems": 0, "petals": 0, "aff": 0}}
	if variant == "daily":
		result["faster"] = V10MjClassicData.faster_than(result.time_s, result.pairs, date)
	if not no_save:
		var rec: = V10MjClassicData.record(result)
		result.rewards = rec.rewards
		result["rank_up"] = rec.rank_up
		result["gifts"] = rec.gifts
		result["new_best"] = rec.new_best
	get_tree().create_timer(0.3 if fx == "min" else 1.7).timeout.connect(show_result)


# ---- sheets -----------------------------------------------------------------------------------------------------
func open_pause() -> void:
	if sheet != null or not running:
		return
	paused = true
	board.input_on = false
	var T: = V10MjClassicStyle.TOK
	sheet = V10MjClassicStyle.sheet(self, 520)
	var p: Control = sheet.get_meta("panel")
	var t: = V10MjClassicStyle.label("Пауза", 32, T.paper100, "title", 600)
	t.position = Vector2(32, 28)
	p.add_child(t)
	var view_btn: = V10MjClassicStyle.Btn.new("quiet", "Объёмный" if board.view == "3d" else "Плоский", "view3d" if board.view == "3d" else "viewflat")
	view_btn.size = Vector2(120, 96)
	view_btn.position = Vector2(p.size.x - 140, 14)
	view_btn.pressed.connect(func():
		var v: = "flat" if board.view == "3d" else "3d"
		board.set_view(v)
		if not no_save:
			V10MjClassicData.st().view = v
			V10MjClassicData.save()
		view_btn.text = "Объёмный" if v == "3d" else "Плоский"
		view_btn.icon = "view3d" if v == "3d" else "viewflat"
		view_btn.queue_redraw())
	p.add_child(view_btn)
	var play: = V10MjClassicStyle.Btn.new("play", "Продолжить")
	play.size = Vector2(560, 104)
	play.position = Vector2((p.size.x - 560) * 0.5, 150)
	play.breathe = true
	play.pressed.connect(close_pause)
	p.add_child(play)
	var again: = V10MjClassicStyle.Btn.new("second", "Заново")
	again.size = Vector2(272, 84)
	again.position = Vector2((p.size.x - 560) * 0.5, 290)
	again.pressed.connect(func(): _leave("again", false))
	p.add_child(again)
	var out: = V10MjClassicStyle.Btn.new("second", "Выйти")
	out.size = Vector2(272, 84)
	out.position = Vector2((p.size.x - 560) * 0.5 + 288, 290)
	out.pressed.connect(func(): _leave("exit", false))
	p.add_child(out)


func close_pause() -> void:
	if sheet == null:
		return
	V10MjClassicStyle.close_sheet(sheet)
	sheet = null
	paused = false
	board.input_on = true


func _leave(next: String, win: bool) -> void:
	if not win:
		result = {"mode": "classic", "variant": variant, "form": form.id, "win": false, "score": 0, "stars": 0,
			"time_s": int(round(time_s)), "pairs": board.total() / 2, "moves": board.moves, "hints": board.hints,
			"shuffles": board.shuffles, "hero": hero, "seed": seed_, "diff": diff,
			"rewards": {"coins": 0, "gems": 0, "petals": 0, "aff": 0}}
		if not no_save:
			V10MjClassicData.record(result)
	result["next"] = next
	if sheet:
		V10MjClassicStyle.close_sheet(sheet)
		sheet = null
	finished.emit(result)


func show_result() -> void:
	if sheet != null:
		return
	var T: = V10MjClassicStyle.TOK
	sheet = V10MjClassicStyle.sheet(self, 640)
	var p: Control = sheet.get_meta("panel")
	var t: = V10MjClassicStyle.label("Стол чист", 44, T.paper100, "title", 700)
	t.position = Vector2(32, 26)
	p.add_child(t)
	var sub: = V10MjClassicStyle.label(form.name, 22, T.paper500, "body", 800)
	sub.position = Vector2(34, 84)
	p.add_child(sub)
	# stars: a cascade of 80 ms steps, each a pentatonic note up
	var stars: = int(result.get("stars", 0))
	var srow: = V10MjClassicStyle.Paint.new(func(c: Control):
		for k in 3:
			var lit: bool = k < int(c.get_meta("lit", 0))
			V10MjClassicStyle.glyph(c, "star_on" if lit else "star", Vector2(32 + k * 64, 32), 26, T.gold300 if lit else T.paper700))
	srow.position = Vector2(p.size.x - 32 - 3 * 64, 30)
	srow.size = Vector2(3 * 64, 64)
	srow.set_meta("lit", 0)
	p.add_child(srow)
	for k in stars:
		get_tree().create_timer(0.35 + 0.08 * k).timeout.connect(func():
			srow.set_meta("lit", k + 1)
			srow.queue_redraw()
			V9Feel.sound("star%d" % mini(k, 2), 1.0, -4.0))
	var lines: Array = []
	var ts: = int(result.get("time_s", 0))
	lines.append("Время %d:%02d · ходов %d" % [ts / 60, ts % 60, int(result.get("moves", 0))])
	if result.has("faster"):
		lines.append("Ты быстрее %d%% игроков" % int(result.faster))
	var why: = ""
	if stars == 3:
		why = "Чистая игра — без подсказок"
	elif stars == 2:
		why = "Без подсказок будет ★★★"
	else:
		why = "Без перемешиваний будет ★★"
	lines.append(why)
	var rw: Dictionary = result.get("rewards", {})
	var rparts: = []
	if int(rw.get("coins", 0)) > 0:
		rparts.append("+%d монет" % int(rw.coins))
	if int(rw.get("aff", 0)) > 0:
		rparts.append("+%d симпатия" % int(rw.aff))
	if int(rw.get("gems", 0)) > 0:
		rparts.append("+%d кристаллов" % int(rw.gems))
	var y: = 130.0
	for ln in lines:
		var l: = V10MjClassicStyle.label(ln, 22, T.paper300, "body", 700)
		l.position = Vector2(34, y)
		p.add_child(l)
		y += 36
	if not rparts.is_empty():
		var rl: = V10MjClassicStyle.label(" · ".join(rparts), 26, T.gold300, "body", 900)
		rl.position = Vector2(34, y + 4)
		p.add_child(rl)
		y += 44
	# mastery: one bar
	var pr: = V10MjClassicData.rank_progress() if not no_save else {"rank": 0, "have": stars, "need": 5}
	var ml: = V10MjClassicStyle.label("%s · %d из %d ★" % [V10MjClassicData.rank_text(int(pr.rank)) if int(pr.rank) > 0 else "Знак Классики", int(pr.have), int(pr.need)], 18, T.paper500, "body", 800)
	ml.position = Vector2(34, y + 6)
	p.add_child(ml)
	var kk: = clampf(float(pr.have) / maxf(1.0, float(pr.need)), 0.0, 1.0)
	var mb: = V10MjClassicStyle.Paint.new(func(c: Control):
		c.draw_rect(Rect2(Vector2.ZERO, c.size), T.night600)
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(c.size.x * kk, c.size.y)), T.gold500))
	mb.position = Vector2(34, y + 36)
	mb.size = Vector2(p.size.x - 68, 6)
	p.add_child(mb)
	if int(result.get("rank_up", 0)) > 0:
		var gl: Array = result.get("gifts", [])
		var txt: = "Новый знак: %s" % V10MjClassicData.RANK_NAMES[int(result.rank_up) - 1]
		if not gl.is_empty():
			txt += " · " + String(V10MjClassicData.GIFT_NAMES.get(gl[0], ""))
		var ul: = V10MjClassicStyle.label(txt, 22, T.gold300, "body", 800)
		ul.position = Vector2(34, y + 52)
		p.add_child(ul)
	var play: = V10MjClassicStyle.Btn.new("play", "Играть ещё")
	play.size = Vector2(560, 104)
	play.position = Vector2((p.size.x - 560) * 0.5, p.size.y - 220)
	play.breathe = true
	play.pressed.connect(func(): _leave("again", true))
	p.add_child(play)
	var out: = V10MjClassicStyle.Btn.new("second", "К формам", "next")
	out.size = Vector2(300, 80)
	out.position = Vector2((p.size.x - 300) * 0.5, p.size.y - 104)
	out.pressed.connect(func(): _leave("exit", true))
	p.add_child(out)


# rects the UX self-check / presence audit uses
func hud_rects() -> Array:
	return [pause_btn.get_global_rect(), goal.get_global_rect()]
