class_name V10MjTriplesScreen
extends Control

# Экран партии Троек (docs/MODES.md §4.2, общий каркас §4; UX_RULES §6.6). Контракт §7.1:
#   setup(main, args) · сигнал finished(result) · args.presence (on/sacred) · args.look · награды не начисляет.
#
# args: level (1…120, иначе из сейва), hero (иначе партнёрша G.S.partner), presence, look {tray}, magnet (bool, если
#   стартовый лист выключен), start_sheet (true), result_sheet (true), seed_shuffle, fx_min, demo (без сейва).
#
# Зоны (720×1280; на 9:20 и длиннее лишняя высота уходит в её полосу — сцена над лотком):
#   0 … band_h        её полоса: пауза · «14 · Осталось 60» и тонкая полоса · арочное окно с кольцом Приёма
#   band_h … +180     лоток 7 ячеек в её рамке, «×4» над лотком (Playfair Italic, 600 мс), последняя ячейка — ember
#   … H−186           стол (святая зона)
#   H−186 … H−40      помощь: Вернуть 3 · +1 ячейка · Перемешать (только открытые; число — сколько осталось)
# Бюджет партии: тапаемых ≤ 6 (пауза, окно-Приём, ≤ 3 помощи), слов ≤ 8, бейджей 0, валют 0.

signal finished(result: Dictionary)

const T: = V10MjTriplesLook.TOK
const HELP: = ["return3", "slot", "shuffle"]
const TRAY_ZONE: = 180.0
const HELP_ZONE: = 186.0

var main
var args: = {}
var level: = 1
var hero: = "hana"
var lv: = {}
var cfg: = {"bg": "default"}          # V6BoardTable читает тему стола отсюда
var board: V10MjTriplesBoard
var presence                          # внешний (args.presence) или V10MjTriplesPresence
var lite: V10MjTriplesPresence
var sound: V10MjTriplesSound
var save_d: = {}
var demo: = false

var vw: = Vector2(720, 1280)
var band_h: = 120.0
var tray_def: = {}
var tray_fit: = {}
var tray_center: = Vector2.ZERO
var tray_frame: Control
var cells_ctl: Control
var combo_lbl: Label
var left_lbl: Label
var bar: Control
var help_btns: = {}
var help_left: = {}
var sheet_layer: Control
var fx_layer: Control
var banner: Label

var charge: = 0
var need: = 6
var score: = 0
var t0: = 0.0
var used_help: = false
var magnet_on: = false
var ended: = false
var blessing: = false
var rng: = RandomNumberGenerator.new()
var _danger: = false
var _last_cell_pulse: = 0.0
var result: = {}


func setup(m, a: Dictionary) -> void:
	main = m
	args = a
	demo = bool(a.get("demo", false))
	save_d = V10MjTriplesSave.st() if not demo else V10MjTriplesSave.DEFAULTS.duplicate(true)
	level = clampi(int(a.get("level", save_d.get("level", 1))), 1, V10MjTriplesGen.COUNT)
	var partner: String = String(G.S.get("partner", "")) if G.S is Dictionary else ""
	hero = String(a.get("hero", partner if partner != "" else V10MjTriplesGen.CHAPTER_HOST[V10MjTriplesGen.chapter_of(level)]))
	if not V10MjTriplesLook.ACCENT.has(hero):
		hero = "mc"
	rng.seed = int(a.get("seed_shuffle", level * 977 + 3))
	if is_inside_tree():
		_build()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not args.is_empty() and board == null:
		_build()


# ── сборка ───────────────────────────────────────────────────────────────────

func _build() -> void:
	vw = get_viewport_rect().size
	size = vw
	var extra: = maxf(0.0, vw.y - 1280.0)
	band_h = 120.0 + minf(extra, 330.0)
	var spare: = extra - minf(extra, 330.0)
	cfg.bg = V10MjTriplesLook.HERO_TABLE.get(hero, "default")
	lv = V10MjTriplesGen.build(level)
	need = V10MjTriplesUlts.need(G.aff_level(hero) if G.S is Dictionary and G.S.has("aff") else 1)
	charge = mini(need, V10MjTriplesUlts.start_charge(hero))
	sound = V10MjTriplesSound.new()
	sound.name = "Sound"
	add_child(sound)
	_build_bg()
	_build_tray()
	_build_board(spare)
	_build_band()
	_build_help()
	fx_layer = Control.new()
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fx_layer)
	_build_presence()
	sheet_layer = Control.new()
	sheet_layer.name = "Sheets"
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sheet_layer)
	_refresh()
	if bool(args.get("start_sheet", true)):
		board.finish_deal_now()
		board.input_on = false
		_start_sheet()
	else:
		magnet_on = bool(args.get("magnet", false))
		_start()


func _build_bg() -> void:
	var bg: = TextureRect.new()
	bg.name = "Bg"
	var g: = Gradient.new()
	var a: Array = V10MjTriplesLook.accent(hero)
	g.set_color(0, Color(a[2]).darkened(0.55).lerp(T.night900, 0.35))
	g.set_color(1, T.night900)
	g.add_point(0.22, T.night800)
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.8, 0.0)
	gt.fill_to = Vector2(0.4, 1.0)
	gt.width = 64
	gt.height = 128
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _tray_cells(slots: int) -> Array:
	tray_fit = V10MjTriplesLook.fit(tray_def, minf(vw.x - 8.0, 760.0), slots, 88.0)
	var well: Rect2 = tray_fit.well
	var out: = []
	var pitch: float = tray_fit.pitch
	for k in slots:
		out.append(tray_center + Vector2(well.position.x + 6.0 + pitch * (k + 0.5), well.get_center().y))
	return out


func _build_tray() -> void:
	tray_def = V10MjTriplesLook.tray_def(args, hero)
	tray_center = Vector2(vw.x * 0.5, band_h + 104.0)
	_tray_cells(V10MjTriplesRules.SLOTS)
	tray_frame = Control.new()
	tray_frame.name = "TrayFrame"
	tray_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_frame.position = tray_center
	add_child(tray_frame)
	tray_frame.add_child(V10MjTriplesLook.make_frame(tray_def, tray_fit))
	cells_ctl = Control.new()
	cells_ctl.name = "Cells"
	cells_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cells_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	cells_ctl.draw.connect(_draw_cells)
	add_child(cells_ctl)
	combo_lbl = V10MjTriplesLook.label("", 60, T.gold300, "italic", 700)
	combo_lbl.label_settings.shadow_color = Color(0, 0, 0, 0.6)
	combo_lbl.label_settings.shadow_size = 8
	combo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_lbl.size = Vector2(240, 80)
	combo_lbl.pivot_offset = Vector2(120, 40)
	combo_lbl.position = Vector2(vw.x * 0.5 - 120.0, tray_center.y + (tray_fit.frame as Rect2).position.y - 66.0)
	combo_lbl.modulate.a = 0.0
	add_child(combo_lbl)


func _draw_cells() -> void:
	if board == null:
		return
	var n: = board.cells.size()
	var used: = board.rules.tray.size()
	var cw: float = tray_fit.pitch - 6.0
	var ch: float = cw * Tile.TH / Tile.TW
	for k in n:
		var c: Vector2 = board.cells[k]
		var r: = Rect2(c - Vector2(cw, ch) * 0.5, Vector2(cw, ch))
		cells_ctl.draw_rect(r, Color(T.night900, 0.28), true)
		var last: = k == n - 1
		if last:
			# последняя ячейка — ember: тихо всегда, ярко и с пульсом, когда она последняя свободная (6/7)
			var hot: = used >= n - 1
			var a: = 0.3
			if hot:
				var p: = absf(sin(_last_cell_pulse * PI))
				a = 0.6 + 0.35 * p
				cells_ctl.draw_rect(r, Color(T.ember, 0.14 + 0.16 * p), true)
			cells_ctl.draw_rect(r.grow(1.0), Color(T.ember, a), false, 3.0 if hot else 1.5)
		else:
			cells_ctl.draw_rect(r, Color(T.paper100, 0.06), false, 1.0)


func _build_board(spare: float) -> void:
	board = V10MjTriplesBoard.new()
	board.name = "Board"
	board.accent = V10MjTriplesLook.accent(hero)[0]
	board.fx_min = V9Feel.level() == "min" or bool(args.get("fx_min", false))
	add_child(board)
	board.setup(lv, args.get("look", {}).get("tiles", {}) if args.get("look", {}) is Dictionary else {})
	var top: = band_h + TRAY_ZONE + spare * 0.5
	var bot: = vw.y - HELP_ZONE - spare * 0.5
	var r: = Rect2(16, top, vw.x - 32, bot - top)
	board.fit_into(V6BoardTable.inset(r), 1.3)
	V6BoardTable.attach(board, r)
	board.set_tray(_tray_cells(V10MjTriplesRules.SLOTS), tray_fit.tile_w)
	board.picked.connect(_on_picked)
	board.placed.connect(_on_placed)
	board.tripled.connect(_on_tripled)
	board.tray_changed.connect(_refresh)
	board.lost.connect(_on_lost)
	board.cleared.connect(_on_cleared)
	board.denied.connect(func(_i): sound.deny())
	board.set_meta("table_rect", r)


func _build_band() -> void:
	var pause: = _icon_button("pause", Vector2(12, 18), "")
	pause.name = "Pause"
	pause.pressed.connect(_pause_sheet)
	add_child(pause)
	left_lbl = V10MjTriplesLook.label("", 22, T.paper100, "body", 800)
	left_lbl.position = Vector2(104, 28)
	left_lbl.size = Vector2(330, 32)
	add_child(left_lbl)
	bar = Control.new()
	bar.position = Vector2(104, 70)
	bar.size = Vector2(minf(300.0, vw.x - 104.0 - 180.0), 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var p: = 1.0 - float(board.rules.board_count()) / maxf(1.0, float(lv.n))
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(T.paper100, 0.12))
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * p, bar.size.y)), T.jade500))
	add_child(bar)
	banner = V10MjTriplesLook.label("", 44, T.paper100, "title", 700)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(vw.x, 60)
	banner.modulate.a = 0.0
	add_child(banner)


func _window_rect() -> Rect2:
	var h: = band_h - 14.0
	var w: = clampf(h * 0.72, 96.0, 300.0)
	if band_h <= 140.0:
		w = 104.0
		h = band_h - 8.0
	return Rect2(vw.x - w - 18.0, band_h - h - 2.0, w, h)


func _build_presence() -> void:
	var ext = args.get("presence")
	lite = V10MjTriplesPresence.new()
	lite.attach(self, hero, {"sound": sound, "fx_min": board.fx_min, "mode": args.get("hero_mode", "")} if args.has("hero_mode") else {"sound": sound, "fx_min": board.fx_min})
	move_child(lite, fx_layer.get_index())
	lite.layout(Rect2(0, 0, vw.x, band_h), _window_rect(), vw)
	lite.yield_nodes = [left_lbl, bar]
	lite.portrait_tapped.connect(_try_ult)
	lite.finale_done.connect(_after_finale)
	presence = ext if ext != null and ext.has_method("on") else lite
	if presence != lite:
		lite.visible = false
	for r in sacred_rects():
		presence.sacred(r)
		if presence != lite:
			lite.sacred(r)
	_sync_charge()


func sacred_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.append(board.get_meta("table_rect"))
	out.append(Rect2(tray_center + (tray_fit.frame as Rect2).position, (tray_fit.frame as Rect2).size))
	out.append(Rect2(0, vw.y - HELP_ZONE, vw.x, HELP_ZONE - 32.0))
	return out


func _icon_button(kind: String, pos: Vector2, caption: String) -> Button:
	var b: = Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.size = Vector2(80, 80)
	b.custom_minimum_size = Vector2(80, 80)
	var ic: = V10MjTriplesIcon.new(kind, T.paper300)
	ic.position = Vector2(16, 16)
	ic.size = Vector2(48, 48)
	b.add_child(ic)
	b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
	return b


func _build_help() -> void:
	var open: Array = V10MjTriplesSave.open_for(level)
	var shown: = HELP.filter(func(k): return open.has(k))
	var n: = shown.size()
	var y: = vw.y - HELP_ZONE + 20.0
	var gap: = 168.0
	var x0: = vw.x * 0.5 - (n - 1) * gap * 0.5
	for k in n:
		var key: String = shown[k]
		help_left[key] = 2 if V10MjTriplesGen.is_boss(level) and key != "slot" else 1
		var root: = Control.new()
		root.name = "Help_" + key
		root.position = Vector2(x0 + k * gap - 60.0, y)
		root.size = Vector2(120, 140)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(root)
		var b: = Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(12, 0)
		b.size = Vector2(96, 96)
		b.draw.connect(func():
			var c: = Vector2(48, 48)
			var on: bool = int(help_left.get(key, 0)) > 0
			b.draw_circle(c, 46.0, T.night700)
			b.draw_arc(c, 46.0, 0, TAU, 48, Color(T.gold700, 0.35 if on else 0.2), 1.5, true)
			var nb: = Vector2(80, 80)
			b.draw_circle(nb, 15.0, T.night900)
			b.draw_arc(nb, 15.0, 0, TAU, 24, Color(T.gold500, 0.5 if on else 0.2), 1.2, true))
		var ic: = V10MjTriplesIcon.new(key, T.gold300)
		ic.position = Vector2(24, 24)
		ic.size = Vector2(48, 48)
		b.add_child(ic)
		var num: = V10MjTriplesLook.label("1", 18, T.paper100, "body", 900)
		num.name = "Num"
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.size = Vector2(30, 26)
		num.position = Vector2(65, 66)
		b.add_child(num)
		root.add_child(b)
		var cap: = V10MjTriplesLook.label(V10MjTriplesSave.NAMES[key], 18, T.paper500, "body", 700)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.size = Vector2(160, 26)
		cap.position = Vector2(-20, 102)
		root.add_child(cap)
		b.button_down.connect(func(): V9Feel.press(b, "", "button"))
		b.pressed.connect(_use_help.bind(key))
		help_btns[key] = b
	_refresh_help()


func _refresh_help() -> void:
	for key in help_btns:
		var b: Button = help_btns[key]
		var left: = int(help_left.get(key, 0))
		var on: = left > 0
		if key == "slot":
			on = on and board.rules.slots < V10MjTriplesRules.SLOTS_MAX
		(b.get_node("Num") as Label).text = str(left)
		b.modulate = Color(1, 1, 1, 1.0 if on else 0.45)
		b.queue_redraw()


# ── поток партии ─────────────────────────────────────────────────────────────

func _start() -> void:
	t0 = Time.get_ticks_msec() / 1000.0
	board.deal()
	if bool(args.get("instant", false)):
		board.finish_deal_now()
		board.input_on = true
	_banner("%s · %d" % [V10MjTriplesInfo.INFO.name, level])
	presence.on("start", {})
	if magnet_on:
		used_help = true
		await get_tree().create_timer(0.9 if not bool(args.get("instant", false)) else 0.05).timeout
		var groups: = V10MjTriplesGen.magnet_groups(lv, 3)
		board.magnet(groups, _presence_target())
		_refresh()
	var nb: = V10MjTriplesSave.new_at(level)
	if nb != "" and nb != "magnet" and help_btns.has(nb):
		presence.on("booster", {})
		var b: Button = help_btns[nb]
		var tw: = b.create_tween()
		for k in 2:
			tw.tween_property(b, "scale", Vector2(1.12, 1.12), 0.22).set_trans(Tween.TRANS_SINE)
			tw.tween_property(b, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_SINE)


func _banner(text: String) -> void:
	banner.text = text
	var tr: Rect2 = board.get_meta("table_rect")
	banner.position = Vector2(0, tr.get_center().y - 30.0)
	var tw: = banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.18)
	tw.tween_interval(0.42)
	tw.tween_property(banner, "modulate:a", 0.0, 0.2)


func _presence_target() -> Vector2:
	if presence != null and presence.has_method("window_center"):
		return presence.window_center()
	return lite.window_center()


func _on_picked(i: int, gp: Vector2) -> void:
	presence.on("pick", {"pos": gp})
	if lite != presence:
		lite.on("pick", {"pos": gp})


func _on_placed(i: int, face: int) -> void:
	sound.place(face)


func _on_tripled(face: int, gp: Vector2, combo: int, from_ult: bool) -> void:
	sound.triple(face, combo if not from_ult else 1)
	var k: = 1.0 + 0.25 * (combo - 1)
	score += int(round(30.0 * k * (2.0 if blessing else 1.0)))
	if not from_ult:
		_sparks(gp, func():
			var add: = 1
			if face == int(V10MjTriplesPresence.SIGNATURE.get(hero, -1)):
				add += 1
				presence.on("signature", {})
			charge = mini(need, charge + add)
			presence.on("pair", {"pos": gp, "charge": float(charge) / need})
			_sync_charge())
		if combo >= 2:
			_show_combo(combo)
		if combo >= 3:
			presence.on("combo", {"n": combo})
	if board.rules.board_count() + board.rules.tray.size() == 3 and not board.rules.won:
		presence.on("last_pair", {})


func _sync_charge() -> void:
	var rdy: = charge >= need
	lite.set_charge(float(charge) / need, rdy)


# ≤ 8 искр (fx_scale), альфа ≤ 0,6, полёт ≤ 0,45 с по кратчайшему пути вверх, без остановок
func _sparks(from: Vector2, done: Callable) -> void:
	var to: = _presence_target()
	var n: = int(round(8 * V9Feel.fx_scale())) if not board.fx_min else 0
	var acc: Array = V10MjTriplesLook.accent(hero)
	if n <= 0:
		done.call()
		return
	for k in n:
		var s: = Sprite2D.new()
		s.texture = G.fx("glow")
		s.material = Fx.add_mat()
		s.modulate = Color(acc[1] if k % 2 == 0 else acc[0], 0.6)
		s.scale = Vector2.ONE * randf_range(0.10, 0.18)
		s.position = from + Vector2(randf_range(-30, 30), randf_range(-12, 12))
		fx_layer.add_child(s)
		var mid: = s.position.lerp(to, 0.5) + Vector2(randf_range(-60, 60), -40)
		var p0: = s.position
		var tw: = s.create_tween()
		var dur: = randf_range(0.34, 0.45)
		tw.tween_method(func(v: float):
			var u: = 1.0 - v
			s.position = p0 * u * u + mid * 2.0 * u * v + to * v * v
			s.modulate.a = 0.6 * (1.0 - v * 0.5), 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(s.queue_free)
	get_tree().create_timer(0.45).timeout.connect(done)


func _show_combo(n: int) -> void:
	combo_lbl.text = "×%d" % n
	combo_lbl.scale = Vector2(1.35, 1.35)
	combo_lbl.modulate.a = 1.0
	var tw: = combo_lbl.create_tween()
	tw.tween_property(combo_lbl, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.3)
	tw.tween_property(combo_lbl, "modulate:a", 0.0, 0.14)


func _refresh() -> void:
	if board == null or left_lbl == null:
		return
	var left: = board.rules.board_count() + board.rules.tray.size()
	left_lbl.text = "%d · Осталось %d" % [level, left]
	bar.queue_redraw()
	var d: = board.rules.tray.size() >= board.rules.slots - 1 and not board.rules.won
	if d != _danger:
		_danger = d
		presence.on("danger", {"on": d})
		if lite != presence:
			lite.on("danger", {"on": d})
	cells_ctl.queue_redraw()
	_refresh_help()
	if not ended and not blessing and board.input_on and not board.busy():
		_check_bless()


func _process(dt: float) -> void:
	if _danger and cells_ctl:
		_last_cell_pulse += dt
		cells_ctl.queue_redraw()
	if lite:
		lite.input_on = board != null and board.input_on and not ended
	if not ended and not blessing and board and board.input_on and not board.busy() and board.rules.board_count() > 0:
		_check_bless()


func _check_bless() -> void:
	var order: = board.rules.auto_finish_order()
	if order.is_empty() or order.size() > 18 and board.rules.board_count() > 15:
		return
	blessing = true
	board.bless(order, func(k): sound.bless(k + 4))


func _on_lost() -> void:
	if ended:
		return
	presence.on("lose", {})
	if lite != presence:
		lite.on("lose", {})
	await get_tree().create_timer(1.0).timeout
	_lose_sheet()


func _on_cleared() -> void:
	if ended:
		return
	ended = true
	sound.win_chord()
	presence.on("win", {})
	if presence != lite:
		lite.on("win", {})


func _after_finale() -> void:
	_finish_result(true)
	if bool(args.get("result_sheet", true)):
		_win_sheet()


# ── помощь и Приём ───────────────────────────────────────────────────────────

func _use_help(key: String) -> void:
	if ended or blessing or int(help_left.get(key, 0)) <= 0 or board.busy() and key != "return3":
		sound.deny()
		return
	var ok: = false
	match key:
		"return3":
			ok = not board.return_last(3).is_empty()
		"slot":
			ok = board.add_slot(_tray_cells(board.rules.slots + 1), tray_fit.tile_w)
			if ok:
				_rebuild_frame()
		"shuffle":
			ok = board.input_on and board.reshuffle(rng)
			if ok:
				V9Feel.sound("whoosh", 1.1)
	if ok:
		help_left[key] = int(help_left[key]) - 1
		used_help = true
		_refresh()
	else:
		sound.deny()


func _rebuild_frame() -> void:
	for c in tray_frame.get_children():
		c.queue_free()
	tray_frame.add_child(V10MjTriplesLook.make_frame(tray_def, tray_fit))


func _try_ult() -> void:
	if ended or blessing or not board.input_on or board.busy():
		return
	if charge < need:
		lite._bounce(1.02, 0.2)
		return
	var plan: = V10MjTriplesUlts.plan(hero, board.rules)
	if int(plan.get("return", 0)) == 0 and (plan.triples as Array).is_empty():
		sound.deny()
		return
	charge = 0
	_sync_charge()
	board.input_on = false
	presence.on("ult", {})
	if presence != lite:
		lite.on("ult", {})
	var nm: = V10MjTriplesLook.label(V10MjTriplesUlts.ult_name(hero), 40, V10MjTriplesLook.accent(hero)[1], "italic", 700)
	nm.label_settings.shadow_color = Color(0, 0, 0, 0.6)
	nm.label_settings.shadow_size = 8
	nm.position = Vector2(24, band_h - 60.0)
	nm.size = Vector2(vw.x - 160.0, 56)
	nm.modulate.a = 0.0
	fx_layer.add_child(nm)
	var tw: = nm.create_tween()
	tw.tween_property(nm, "modulate:a", 1.0, 0.15)
	tw.tween_interval(0.7)
	tw.tween_property(nm, "modulate:a", 0.0, 0.25)
	tw.tween_callback(nm.queue_free)
	V9Feel.sound("summon_charge", 1.2, -6.0)
	await get_tree().create_timer(0.45).timeout
	board.cast(plan, _presence_target())
	await get_tree().create_timer(0.55).timeout
	if not ended and not board.rules.lost:
		board.input_on = true
	_refresh()


# ── листы ────────────────────────────────────────────────────────────────────

func _sheet(height: float) -> Control:
	for c in sheet_layer.get_children():
		c.queue_free()
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: = ColorRect.new()
	dim.color = Color(T.night900, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet_layer.add_child(dim)
	var p: = Panel.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = T.night700
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.border_color = Color(T.gold700, 0.35)
	sb.border_width_top = 1
	p.add_theme_stylebox_override("panel", sb)
	p.size = Vector2(vw.x, height)
	p.position = Vector2(0, vw.y)
	sheet_layer.add_child(p)
	var tw: = p.create_tween().set_parallel()
	tw.tween_property(p, "position:y", vw.y - height, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(dim, "color:a", 0.45, 0.22)
	return p


func _close_sheet() -> void:
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in sheet_layer.get_children():
		c.queue_free()


func _primary(text: String, w: = 560.0) -> Button:
	var b: = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(w, 104)
	b.custom_minimum_size = b.size
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = T.rose700 if st == "pressed" else T.rose500
		sb.set_corner_radius_all(52)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_override("font", V10MjTriplesLook.font("title", 600))
	b.add_theme_font_size_override("font_size", 32)
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, T.night900)
	b.pivot_offset = b.size * 0.5
	b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
	# «дыхание» главной кнопки — единственная бесконечная анимация UI (UX §6.7)
	var tw: = b.create_tween().set_loops()
	tw.tween_property(b, "scale", Vector2(0.985, 0.985), 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)
	return b


func _secondary(text: String) -> Button:
	var b: = Button.new()
	b.text = text + "  ›"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(320, 80)
	b.add_theme_font_override("font", V10MjTriplesLook.font("body", 800))
	b.add_theme_font_size_override("font_size", 22)
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, T.paper100)
	b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
	return b


func _stars_row(n: int, of: = 3, size: = 44.0) -> Control:
	var row: = Control.new()
	row.size = Vector2(of * (size + 10.0), size)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in of:
		var ic: = V10MjTriplesIcon.new("star", T.gold300 if k < n else Color(T.paper700, 0.6))
		ic.size = Vector2(size, size)
		ic.position = Vector2(k * (size + 10.0), 0)
		row.add_child(ic)
	return row


func _start_sheet() -> void:
	var p: = _sheet(470.0)
	var ch: = V10MjTriplesGen.chapter_of(level) + 1
	var over: = V10MjTriplesLook.label("ТРОЙКИ · ГЛАВА %d" % ch, 15, T.gold500, "body", 900)
	over.position = Vector2(32, 32)
	p.add_child(over)
	var h1: = V10MjTriplesLook.label("Уровень %d" % level, 44, T.paper100, "title", 700)
	h1.position = Vector2(32, 58)
	p.add_child(h1)
	var dn: = V10MjTriplesLook.label(V10MjTriplesGen.difficulty_name(level), 18, T.paper500, "body", 700)
	dn.position = Vector2(34, 120)
	p.add_child(dn)
	var sr: = _stars_row(V10MjTriplesSave.stars_of(save_d, level), 3, 34.0)
	sr.position = Vector2(vw.x - 32.0 - sr.size.x, 72)
	p.add_child(sr)
	var y: = 172.0
	if V10MjTriplesSave.open_for(level).has("magnet"):
		var row: = Button.new()
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		row.position = Vector2(24, y)
		row.size = Vector2(vw.x - 48.0, 88)
		row.draw.connect(func():
			row.draw_rect(Rect2(Vector2.ZERO, row.size), Color(T.night800, 1.0))
			var c: = Vector2(row.size.x - 56, 44)
			row.draw_rect(Rect2(c - Vector2(30, 16), Vector2(60, 32)), T.jade500 if magnet_on else T.night600)
			row.draw_circle(c + Vector2(14 if magnet_on else -14, 0), 13.0, T.paper100))
		var ic: = V10MjTriplesIcon.new("magnet", T.gold300)
		ic.position = Vector2(16, 20)
		ic.size = Vector2(48, 48)
		row.add_child(ic)
		var t1: = V10MjTriplesLook.label("Магнит", 22, T.paper100, "body", 800)
		t1.position = Vector2(80, 14)
		row.add_child(t1)
		var t2: = V10MjTriplesLook.label("снимет 3 тройки до старта", 18, T.paper500, "body", 700)
		t2.position = Vector2(80, 46)
		row.add_child(t2)
		row.pressed.connect(func():
			magnet_on = not magnet_on
			V9Feel.press(row, "pop", "button")
			row.queue_redraw())
		row.name = "MagnetRow"
		p.add_child(row)
		y += 104.0
	var how: = V10MjTriplesLook.label(V10MjTriplesInfo.INFO.line, 18, T.paper500, "body", 700)
	how.position = Vector2(32, y + 4)
	p.add_child(how)
	var play: = _primary("Играть")
	play.name = "Play"
	play.position = Vector2(vw.x * 0.5 - 280.0, 470.0 - 136.0)
	play.pressed.connect(func():
		_close_sheet()
		_start())
	p.add_child(play)


func _pause_sheet() -> void:
	if ended:
		return
	var was: = board.input_on
	board.input_on = false
	var p: = _sheet(520.0)
	var h: = V10MjTriplesLook.label("Пауза", 32, T.paper100, "title", 600)
	h.position = Vector2(32, 32)
	p.add_child(h)
	for k in V10MjTriplesInfo.HOW.size():
		var row: Array = V10MjTriplesInfo.HOW[k]
		var ic: = V10MjTriplesIcon.new(row[0], T.gold300)
		ic.position = Vector2(32, 96 + k * 64)
		ic.size = Vector2(44, 44)
		p.add_child(ic)
		var l: = V10MjTriplesLook.label(row[1], 20, T.paper300, "body", 700)
		l.position = Vector2(92, 104 + k * 64)
		l.size = Vector2(vw.x - 120, 40)
		p.add_child(l)
	var go_on: = _primary("Продолжить")
	go_on.position = Vector2(vw.x * 0.5 - 280.0, 300)
	go_on.pressed.connect(func():
		_close_sheet()
		board.input_on = was)
	p.add_child(go_on)
	var quit: = _secondary("Выйти")
	quit.position = Vector2(vw.x * 0.5 - 160.0, 420)
	quit.pressed.connect(func():
		_close_sheet()
		_finish_result(false)
		result["action"] = "exit"
		finished.emit(result))
	p.add_child(quit)


func _lose_sheet() -> void:
	var p: = _sheet(430.0)
	var h: = V10MjTriplesLook.label("Почти!", 44, T.paper100, "title", 700)
	h.position = Vector2(32, 36)
	p.add_child(h)
	var left: = board.rules.board_count() + board.rules.tray.size()
	var c: = V10MjTriplesLook.label("Лоток полон. Осталось %d фишек" % left, 22, T.paper300, "body", 700)
	c.position = Vector2(34, 104)
	p.add_child(c)
	var revive: = ""
	for k in ["return3", "slot"]:
		if int(help_left.get(k, 0)) > 0 and not (k == "slot" and board.rules.slots >= V10MjTriplesRules.SLOTS_MAX):
			revive = k
			break
	var prim: Button
	if revive != "":
		prim = _primary("Вернуть 3 и играть" if revive == "return3" else "+1 ячейка и играть")
		prim.pressed.connect(func():
			_close_sheet()
			_use_help(revive))
	else:
		prim = _primary("Ещё раз")
		prim.pressed.connect(func():
			_close_sheet()
			ended = true
			_finish_result(false)
			result["action"] = "retry"
			finished.emit(result))
	prim.name = "Primary"
	prim.position = Vector2(vw.x * 0.5 - 280.0, 190)
	p.add_child(prim)
	var sec: = _secondary("В Столы")
	sec.position = Vector2(vw.x * 0.5 - 160.0, 320)
	sec.pressed.connect(func():
		_close_sheet()
		ended = true
		_finish_result(false)
		result["action"] = "exit"
		finished.emit(result))
	p.add_child(sec)


func _finish_result(win: bool) -> void:
	var stars: = V10MjTriplesSave.stars_for(win, used_help, board.max_tray)
	var rec: = {"stars_gain": 0, "salon_stars": 0.0, "first_clear": false, "opened": []}
	if not demo and result.is_empty():
		rec = V10MjTriplesSave.record(save_d, level, win, stars, score)
		if G.has_method("save"):
			G.save()
	elif result.has("record"):
		rec = result.record
	var first: bool = rec.first_clear if not demo else V10MjTriplesSave.stars_of(save_d, level) == 0
	result = {
		"mode": "triples", "win": win, "score": score, "stars": stars,
		"time_s": int(Time.get_ticks_msec() / 1000.0 - t0), "pairs": board.rules.triples,
		"hero": hero, "seed": int(lv.get("seed", 0)), "level": level,
		"rewards": V10MjTriplesSave.rewards(level, win, first),
		"salon_stars": rec.salon_stars, "stars_gain": rec.stars_gain, "opened": rec.opened,
		"helped": used_help, "max_tray": board.max_tray, "record": rec,
	}


func _win_sheet() -> void:
	var p: = _sheet(560.0)
	var h: = V10MjTriplesLook.label("Стол чист", 64, T.paper100, "title", 700)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.size = Vector2(vw.x, 80)
	h.position = Vector2(0, 28)
	p.add_child(h)
	var sr: = _stars_row(int(result.stars), 3, 56.0)
	sr.position = Vector2(vw.x * 0.5 - sr.size.x * 0.5, 124)
	p.add_child(sr)
	for k in sr.get_child_count():
		var st: Control = sr.get_child(k)
		st.pivot_offset = st.size * 0.5
		st.scale = Vector2.ZERO
		var tw: = st.create_tween()
		tw.tween_interval(0.15 + k * 0.14)
		tw.tween_property(st, "scale", Vector2(1.15, 0.9), 0.1)
		tw.tween_property(st, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if k < int(result.stars):
			tw.tween_callback(func(): sound.bless(6 + k * 2))
	var sc: = V10MjTriplesLook.label("%d очков" % score, 22, T.paper300, "body", 800)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sc.size = Vector2(vw.x, 32)
	sc.position = Vector2(0, 196)
	p.add_child(sc)
	# ≤ 3 жетона наград, каскадом 80 мс
	var rw: Dictionary = result.rewards
	var tokens: = []
	if int(rw.get("coins", 0)) > 0:
		tokens.append("+%d монет" % int(rw.coins))
	if int(rw.get("aff", 0)) > 0:
		tokens.append("+%d симпатии" % int(rw.aff))
	if float(result.get("salon_stars", 0.0)) > 0.0:
		tokens.append("+%s в Салон" % str(snappedf(float(result.salon_stars), 0.5)).trim_suffix(".0"))
	var tx: = vw.x * 0.5 - tokens.size() * 100.0
	for k in tokens.size():
		var t: = V10MjTriplesLook.label(tokens[k], 18, T.gold300, "body", 800)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.size = Vector2(196, 30)
		t.position = Vector2(tx + k * 200.0, 248)
		t.modulate.a = 0.0
		p.add_child(t)
		var tw: = t.create_tween()
		tw.tween_interval(0.6 + k * 0.08)
		tw.tween_property(t, "modulate:a", 1.0, 0.12)
	var nxt: = mini(level + 1, V10MjTriplesGen.COUNT)
	var prim: = _primary("Ещё уровень · %d" % nxt)
	prim.name = "Primary"
	prim.position = Vector2(vw.x * 0.5 - 280.0, 316)
	prim.pressed.connect(func():
		result["action"] = "next"
		finished.emit(result))
	p.add_child(prim)
	var sec: = _secondary("В Столы")
	sec.position = Vector2(vw.x * 0.5 - 160.0, 446)
	sec.pressed.connect(func():
		result["action"] = "exit"
		finished.emit(result))
	p.add_child(sec)
	lite.hide_finale()
