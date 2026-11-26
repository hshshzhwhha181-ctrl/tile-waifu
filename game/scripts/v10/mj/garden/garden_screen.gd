class_name V10MjGardenScreen
extends Control

# Экран партии Сада 2.0 (docs/MODES.md §4.9, §7.1; UX_RULES §6.6):
#   бесконечные волны, лоток на 6 с переливом 3 домой, «Ночной стол» (без музыки, лампа и дождь),
#   сохранение стола посреди волны, силуэт за сукном на рекорде недели, ASMR-колокольчики.

signal finished(result: Dictionary)

const T: = V10MjGardenLook.TOK
const HELP_ZONE: = 168.0
const TRAY_ZONE: = 132.0

var main
var args: = {}
var save_d: = {}
var demo: = false
var fx_min: = false
var hero: = "yue"
var night: = false
var ambient: = "rain"
var run_seed: = 1
var day_str: = ""
var rec_bar: = {"series": 0, "waves": 0}
var beat_series_shown: = false
var beat_waves_shown: = false
var t0: = 0.0
var ended: = false
var input_on: = false

var vw: = Vector2(720, 1280)
var safe_top: = 0.0
var safe_bottom: = 0.0
var band_h: = 120.0
var tray_rect: = Rect2()
var board_rect: = Rect2()
var help_rect: = Rect2()

var rules: V10MjGardenRules
var table_view: V10MjTableView
var silhouette: V10MjGardenSilhouette
var tray_frame: V10MjTrayFrame
var board: V10MjGardenBoard
var sound: V10MjGardenSound
var lite: V10MjGardenPresence
var presence
var hud_lbl: Label
var wave_bar: Control
var pause_btn: Button
var hint_btn: Button
var night_btn: Button
var sheet_layer: Control
var result: = {}


func build(m, a: Dictionary = {}) -> void:
	setup(m, a)


func setup(m, a: Dictionary = {}) -> void:
	main = m
	args = a
	demo = bool(a.get("demo", false))
	var ext_s = a.get("save_root", null)
	save_d = V10MjGardenSave.st(ext_s) if not demo else V10MjGardenSave.DEFAULTS.duplicate(true)
	var partner: String = String(G.S.get("partner", "")) if G.get("S") is Dictionary else ""
	hero = String(a.get("hero", partner if partner != "" else "yue"))
	if not V10MjGardenLook.ACCENT.has(hero):
		hero = "yue"
	night = bool(a.get("night", save_d.get("night", false)))
	ambient = String(a.get("ambient", save_d.get("ambient", "rain")))
	if not (ambient in V10MjGardenSave.AMBIENTS):
		ambient = "rain"
	save_d.night = night
	save_d.ambient = ambient
	fx_min = bool(a.get("fx_min", false)) or V9Feel.level() == "min"
	day_str = String(a.get("day", V10MjGardenSave.day_key()))
	rec_bar = V10MjGardenSave.record_bar(save_d, day_str)
	run_seed = int(a.get("seed", int(V10Meta.now_unix()) % 900000 + 101))
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	if is_inside_tree() and board == null:
		_build()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not args.is_empty() and board == null:
		_build()


func _build() -> void:
	vw = get_viewport_rect().size
	if vw.x <= 0.0:
		vw = Vector2(720, 1280)
	position = Vector2.ZERO
	size = vw
	var ins: = V10Layout.safe_insets(vw)
	safe_top = maxf(float(ins.get("top", 0.0)), float(main.safe_top) if main and main.get("safe_top") != null else 0.0)
	safe_bottom = maxf(float(ins.get("bottom", 0.0)), float(main.safe_bottom) if main and main.get("safe_bottom") != null else 0.0)
	var usable_h: = maxf(960.0, vw.y - safe_top - safe_bottom)
	var extra: = maxf(0.0, usable_h - 1280.0 * vw.x / 720.0)
	band_h = safe_top + 120.0 + minf(extra, 300.0)
	var spare: = maxf(0.0, extra - minf(extra, 300.0))
	var tray_w: = minf(vw.x - 48.0, 648.0)
	tray_rect = Rect2((vw.x - tray_w) * 0.5, band_h + 18.0, tray_w, 108.0)
	help_rect = Rect2(0.0, vw.y - safe_bottom - HELP_ZONE, vw.x, HELP_ZONE - 32.0)
	var b_top: = tray_rect.end.y + 18.0 + spare * 0.35
	var b_bot: = help_rect.position.y - 18.0 - spare * 0.65
	board_rect = Rect2(36.0, b_top, vw.x - 72.0, maxf(360.0, b_bot - b_top))

	var th: = V10MjGardenLook.theme(hero, night)
	var sacred_u: = tray_rect.merge(board_rect).merge(help_rect)
	table_view = V10MjTableView.make(self, th, board_rect, sacred_u, vw)
	silhouette = V10MjGardenSilhouette.make(table_view, hero, board_rect)
	tray_frame = V10MjTrayFrame.make(self, tray_rect, th, V10MjGardenRules.SLOTS)

	board = V10MjGardenBoard.new()
	board.name = "Board"
	board.fx_min = fx_min
	board.accent = V10MjGardenLook.accent(hero)[0]
	add_child(board)
	board.fit_into(board_rect.grow(-16.0))
	var centers: Array = []
	for i in V10MjGardenRules.SLOTS:
		centers.append(tray_frame.slot_center(i))
	var cell_w: = minf(tray_frame.well_rect(0).size.x - 4.0, 86.0)
	board.set_tray(centers, cell_w)

	if table_view.front:
		table_view.attach_front(self)

	sound = V10MjGardenSound.new()
	sound.name = "Sound"
	sound.mute = bool(args.get("mute", false))
	add_child(sound)
	sound.start(night, ambient)

	_build_band()
	_build_help()
	_build_presence()

	sheet_layer = Control.new()
	sheet_layer.name = "Sheets"
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sheet_layer)

	_init_rules(th)
	board.picked.connect(_on_picked)
	board.placed.connect(func(_id): sound.place(String(th.get("material", "bamboo"))))
	board.paired.connect(_on_paired)
	board.spilled.connect(_on_spilled)
	board.denied.connect(func(_id): sound.deny())
	board.tray_changed.connect(_on_tray_changed)

	t0 = Time.get_ticks_msec() / 1000.0
	input_on = true
	board.input_on = true
	lite.input_on = true
	_refresh_hud()


func _init_rules(th: Dictionary) -> void:
	var lt: = V10MjGardenLook.light(th, board_rect, night)
	var base_look: Dictionary = args.get("look", {}).duplicate() if args.get("look") is Dictionary else {}
	if base_look.is_empty():
		base_look = G.skin_look() if G.has_method("skin_look") else {}
	var loaded: V10MjGardenRules = null
	if not demo and bool(args.get("resume", true)):
		loaded = V10MjGardenSave.load_run(save_d)
	if loaded != null:
		rules = loaded
		board.load_rules(rules, base_look, lt)
		tray_frame.set_fill(rules.tray.size())
	else:
		rules = V10MjGardenRules.make(run_seed)
		board.load_rules(rules, base_look, lt)
		var w1: = V10MjGardenGen.make_wave(rules)
		board.pour(w1, not bool(args.get("instant", false)))
		if bool(args.get("instant", false)):
			board.land_now()
		if not demo:
			V10MjGardenSave.save_run(save_d, rules)


func _window_rect() -> Rect2:
	var bh: = band_h - safe_top
	var h: = bh - 14.0
	var w: = clampf(h * 0.72, 96.0, 280.0)
	if bh <= 140.0:
		w = 104.0
		h = bh - 8.0
	return Rect2(vw.x - w - 18.0, band_h - h - 2.0, w, h)


func _build_band() -> void:
	pause_btn = _icon_btn("pause", Vector2(12, safe_top + 18.0))
	pause_btn.name = "Pause"
	pause_btn.pressed.connect(_pause_sheet)
	add_child(pause_btn)

	hud_lbl = V10MjGardenLook.label("", 22, T.paper100, "body", 800)
	hud_lbl.name = "HudLbl"
	hud_lbl.position = Vector2(104, safe_top + 28.0)
	hud_lbl.size = Vector2(320, 32)
	add_child(hud_lbl)

	wave_bar = Control.new()
	wave_bar.name = "WaveBar"
	wave_bar.position = Vector2(104, safe_top + 70.0)
	wave_bar.size = Vector2(minf(280.0, vw.x - 290.0), 4)
	wave_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_bar.draw.connect(func():
		var left_n: = float(rules.left_of_wave()) if rules else 0.0
		var p: = clampf(1.0 - left_n / 36.0, 0.0, 1.0)
		wave_bar.draw_rect(Rect2(Vector2.ZERO, wave_bar.size), Color(T.paper100, 0.12))
		wave_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(wave_bar.size.x * p, wave_bar.size.y)), T.jade500))
	add_child(wave_bar)


func _build_help() -> void:
	var y: = vw.y - safe_bottom - HELP_ZONE + 24.0
	hint_btn = _pill_btn("hint", "Подсказка", Vector2(vw.x * 0.5 - 248.0, y), 232.0)
	hint_btn.name = "HintBtn"
	hint_btn.pressed.connect(use_hint)
	add_child(hint_btn)

	night_btn = _pill_btn("moon", "Ночной стол", Vector2(vw.x * 0.5 + 16.0, y), 232.0)
	night_btn.name = "NightBtn"
	night_btn.pressed.connect(func(): set_night(not night))
	add_child(night_btn)
	_sync_night_btn()


func _build_presence() -> void:
	lite = V10MjGardenPresence.new()
	lite.attach(self, hero, {"fx_min": fx_min})
	lite.layout(Rect2(0, 0, vw.x, band_h), _window_rect(), 280.0)
	lite.wants_block.connect(func(sec: float): board.block(sec))
	var ext = args.get("presence")
	presence = ext if ext != null and ext.has_method("on") else lite
	if presence != lite:
		lite.visible = false
	for r in sacred_rects():
		lite.sacred(r)
		if presence != lite and presence.has_method("sacred"):
			presence.sacred(r)


func sacred_rects() -> Array[Rect2]:
	return [tray_rect, board_rect, help_rect]


func _emit(ev: String, data: Dictionary = {}) -> void:
	if presence != lite and presence.has_method("on"):
		presence.on(ev, data)
	lite.on(ev, data)


func _on_picked(_id: int, gp: Vector2) -> void:
	sound.pick()
	_emit("pick", {"pos": gp})
	_after_move()


func _on_paired(_a: int, _b: int, gp: Vector2, series: int, _gain: int) -> void:
	sound.pair(series, "bamboo")
	_emit("pair", {"pos": gp})
	if not demo:
		V10MjGardenSave.note_series(save_d, series, day_str)
	if int(rec_bar.series) > 0 and series > int(rec_bar.series) and not beat_series_shown:
		beat_series_shown = true
		trigger_record()
	_refresh_hud()


func _on_spilled(_back: Array) -> void:
	sound.overflow()
	_refresh_hud()


func _on_tray_changed() -> void:
	tray_frame.set_fill(rules.tray.size())
	_refresh_hud()


func _after_move() -> void:
	tray_frame.set_fill(rules.tray.size())
	if rules.need_pour():
		_pour_next_wave()
	if not demo:
		V10MjGardenSave.save_run(save_d, rules)
	_refresh_hud()


func _pour_next_wave() -> void:
	if not demo:
		V10MjGardenSave.wave_done(save_d, day_str)
	var nx: = V10MjGardenGen.make_wave(rules)
	board.pour(nx, not bool(args.get("instant", false)))
	if bool(args.get("instant", false)):
		board.land_now()
	sound.wave()
	_emit("wave", {"wave": rules.wave})
	if int(rec_bar.waves) > 0 and rules.wave > int(rec_bar.waves) and not beat_waves_shown:
		beat_waves_shown = true
		trigger_record()


func trigger_record() -> void:
	silhouette.play(fx_min)
	sound.record()


func use_hint() -> bool:
	if ended or not input_on:
		return false
	var ids: = rules.hint()
	if ids.is_empty():
		return false
	board.show_hint(ids)
	return true


func set_night(on: bool) -> void:
	night = on
	save_d.night = night
	var th: = V10MjGardenLook.theme(hero, night)
	var sacred_u: = tray_rect.merge(board_rect).merge(help_rect)
	table_view.setup(th, board_rect, sacred_u)
	silhouette = V10MjGardenSilhouette.make(table_view, hero, board_rect)
	tray_frame.th_data = th
	tray_frame.queue_redraw()
	board.set_light(V10MjGardenLook.light(th, board_rect, night), 1.0 if night else 0.0)
	sound.set_night(night)
	_sync_night_btn()


func set_ambient(amb: String) -> void:
	if not (amb in V10MjGardenSave.AMBIENTS):
		return
	ambient = amb
	save_d.ambient = ambient
	sound.set_ambient(ambient)


func _sync_night_btn() -> void:
	if night_btn == null:
		return
	var ic: V10MjGardenIcon = night_btn.get_node("Icon")
	var lb: Label = night_btn.get_node("Lbl")
	ic.kind = "moon" if night else "sun"
	ic.set_col(T.gold300 if night else T.paper300)
	lb.label_settings.font_color = T.gold300 if night else T.paper300


func _refresh_hud() -> void:
	if hud_lbl == null or rules == null:
		return
	hud_lbl.text = "Волна %d · ×%d" % [rules.wave, rules.mult()]
	wave_bar.queue_redraw()


# ── кнопки, пауза, «?», выход ────────────────────────────────────────────────

func _icon_btn(kind: String, pos: Vector2) -> Button:
	var b: = Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.size = Vector2(80, 80)
	b.custom_minimum_size = Vector2(80, 80)
	b.set_meta("ux_role", "tertiary")
	var ic: = V10MjGardenIcon.new(kind, T.paper300)
	ic.position = Vector2(16, 16)
	b.add_child(ic)
	b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
	return b


func _pill_btn(kind: String, txt: String, pos: Vector2, w: float) -> Button:
	var b: = Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.size = Vector2(w, 88)
	b.custom_minimum_size = Vector2(w, 88)
	b.set_meta("ux_role", "tertiary")
	b.draw.connect(func():
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color(T.night700, 0.92)
		sb.set_corner_radius_all(44)
		sb.border_color = V10DS.hair()
		sb.set_border_width_all(1)
		b.draw_style_box(sb, Rect2(Vector2.ZERO, b.size)))
	var ic: = V10MjGardenIcon.new(kind, T.paper300)
	ic.name = "Icon"
	ic.position = Vector2(16, 20)
	b.add_child(ic)
	var lb: = V10MjGardenLook.label(txt, 20, T.paper300, "body", 700)
	lb.name = "Lbl"
	lb.position = Vector2(72, 29)
	b.add_child(lb)
	b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
	return b


func _primary(txt: String, w: = 520.0) -> Button:
	var b: = Button.new()
	b.name = "Primary"
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(maxf(440.0, w), 104)
	b.custom_minimum_size = b.size
	b.set_meta("ux_role", "primary")
	for st_k in ["normal", "hover", "pressed", "focus"]:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = T.rose700 if st_k == "pressed" else T.rose500
		sb.set_corner_radius_all(52)
		b.add_theme_stylebox_override(st_k, sb)
	b.add_theme_font_override("font", V10MjGardenLook.font("title", 600))
	b.add_theme_font_size_override("font_size", 32)
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, T.night900)
	b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
	return b


func _secondary(txt: String) -> Button:
	var b: = Button.new()
	b.name = "Secondary"
	b.text = txt + "  ›"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(320, 80)
	b.custom_minimum_size = Vector2(320, 80)
	b.set_meta("ux_role", "secondary")
	b.add_theme_font_override("font", V10MjGardenLook.font("body", 800))
	b.add_theme_font_size_override("font_size", 22)
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, T.paper100)
	b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
	return b


func _sheet(h: float) -> Control:
	for c in sheet_layer.get_children():
		c.queue_free()
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: = ColorRect.new()
	dim.color = Color(T.night900, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet_layer.add_child(dim)
	var p: = Panel.new()
	p.name = "Sheet"
	var sb: = StyleBoxFlat.new()
	sb.bg_color = T.night700
	sb.corner_radius_top_left = V10DS.RADIUS
	sb.corner_radius_top_right = V10DS.RADIUS
	sb.border_color = V10DS.hair()
	sb.border_width_top = 1
	p.add_theme_stylebox_override("panel", sb)
	var total_h: = h + safe_bottom
	p.size = Vector2(vw.x, total_h + 120.0)
	p.position = Vector2(0.0, vw.y - total_h)
	sheet_layer.add_child(p)
	return p


func _close_sheet() -> void:
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in sheet_layer.get_children():
		c.queue_free()


func _pause_sheet() -> void:
	if ended:
		return
	input_on = false
	board.input_on = false
	var p: = _sheet(640.0)
	var h: = V10MjGardenLook.label("Сад", 36, T.paper100, "title", 700)
	h.position = Vector2(32, 24)
	p.add_child(h)
	var hb: = _icon_btn("help", Vector2(vw.x - 96.0, 14.0))
	hb.name = "HelpBtn"
	hb.pressed.connect(func(): _help_sheet(true))
	p.add_child(hb)
	for k in V10MjGardenInfo.HOW.size():
		var row: Array = V10MjGardenInfo.HOW[k]
		var ic: = V10MjGardenIcon.new(String(row[0]), T.gold300)
		ic.position = Vector2(32, 86 + k * 56)
		ic.size = Vector2(44, 44)
		p.add_child(ic)
		var l: = V10MjGardenLook.label(String(row[1]), 20, T.paper300, "body", 700)
		l.position = Vector2(92, 94 + k * 56)
		p.add_child(l)
	var amb_n: = V10MjGardenSave.AMBIENTS.size()
	var amb_w: = 180.0
	var amb_gap: = 32.0
	var amb_x0: = (vw.x - (amb_w * amb_n + amb_gap * maxf(0.0, amb_n - 1))) * 0.5
	for i in amb_n:
		var ak: String = V10MjGardenSave.AMBIENTS[i]
		var ab: = Button.new()
		ab.name = "Amb_" + ak
		ab.flat = true
		ab.focus_mode = Control.FOCUS_NONE
		ab.size = Vector2(amb_w, 80)
		ab.custom_minimum_size = Vector2(amb_w, 80)
		ab.position = Vector2(amb_x0 + i * (amb_w + amb_gap), 266)
		ab.set_meta("ux_role", "tertiary")
		ab.text = V10MjGardenSave.AMB_NAMES[ak]
		ab.add_theme_font_override("font", V10MjGardenLook.font("body", 700))
		ab.add_theme_font_size_override("font_size", 20)
		var sel: = (ak == "rain") if night else (ambient == ak)
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			ab.add_theme_color_override(cn, T.gold300 if sel else T.paper500)
		ab.pressed.connect(func():
			set_ambient(ak)
			_pause_sheet())
		p.add_child(ab)
	var go: = _primary("Продолжить")
	go.position = Vector2(vw.x * 0.5 - 260.0, 368)
	go.pressed.connect(func():
		_close_sheet()
		input_on = true
		board.input_on = true)
	p.add_child(go)
	var ex: = _secondary("Выйти")
	ex.name = "ExitBtn"
	ex.position = Vector2(vw.x * 0.5 - 160.0, 492)
	ex.pressed.connect(func():
		_close_sheet()
		exit_garden("exit"))
	p.add_child(ex)


func open_help() -> void:
	_help_sheet(false)


func dev_act(a: String) -> void:
	if a == "pause":
		_pause_sheet()
	elif a == "help":
		_help_sheet(false)


func _help_sheet(from_pause: bool) -> void:
	input_on = false
	board.input_on = false
	var p: = _sheet(640.0)
	var h: = V10MjGardenLook.label("Как играть", 36, T.paper100, "title", 700)
	h.position = Vector2(32, 24)
	p.add_child(h)
	for k in V10MjGardenInfo.HOW.size():
		var row: Array = V10MjGardenInfo.HOW[k]
		var ic: = V10MjGardenIcon.new(String(row[0]), T.gold300)
		ic.position = Vector2(32, 86 + k * 56)
		ic.size = Vector2(44, 44)
		p.add_child(ic)
		var l: = V10MjGardenLook.label(String(row[1]), 20, T.paper300, "body", 700)
		l.position = Vector2(92, 94 + k * 56)
		p.add_child(l)
	for m_i in V10MjGardenInfo.MORE.size():
		var ml: = V10MjGardenLook.label(String(V10MjGardenInfo.MORE[m_i]), 18, T.paper500, "body", 600)
		ml.position = Vector2(32, 272 + m_i * 42)
		p.add_child(ml)
	var ok_b: = _primary("Понятно")
	ok_b.name = "OkBtn"
	ok_b.position = Vector2(vw.x * 0.5 - 260.0, 468)
	ok_b.pressed.connect(func():
		if from_pause:
			_pause_sheet()
		else:
			_close_sheet()
			input_on = true
			board.input_on = true)
	p.add_child(ok_b)


func exit_garden(act: String = "exit") -> Dictionary:
	if ended:
		return result
	ended = true
	input_on = false
	board.input_on = false
	sound.stop()
	var pend: = {"rewards": {"coins": 0, "gems": 0, "petals": 0, "aff": 0}, "events": [], "waves": 0}
	if not demo:
		V10MjGardenSave.save_run(save_d, rules)
		V10MjGardenSave.record_visit(save_d, rules.wave, rules.pairs, rules.score, day_str)
		pend = V10MjGardenSave.take_pending(save_d)
		if G.has_method("save"):
			G.save()
	var stars_v: = clampi((1 if rules.wave >= 2 else 0) + (1 if rules.wave >= 4 else 0) + (1 if rules.best_series >= 9 else 0), 0, 3)
	result = {
		"mode": "garden",
		"win": true,
		"score": rules.score,
		"stars": stars_v,
		"time_s": maxi(1, int(Time.get_ticks_msec() / 1000.0 - t0)),
		"pairs": rules.pairs,
		"hero": hero,
		"seed": rules.run_seed,
		"level": rules.wave,
		"rewards": pend.rewards,
		"events": pend.events,
		"waves": rules.wave,
		"best_series": rules.best_series,
		"night": night,
		"action": act,
	}
	finished.emit(result)
	return result


func tappables() -> Array:
	var out: Array = []
	for b in [pause_btn, hint_btn, night_btn]:
		if b != null:
			out.append(b)
	return out


func words_in_play() -> int:
	var txt: = (hud_lbl.text if hud_lbl else "") + " Подсказка Ночной стол"
	var n: = 0
	for tok in txt.split(" ", false):
		var has_l: = false
		for i in tok.length():
			var u: = tok.unicode_at(i)
			if (u >= 0x0400 and u <= 0x04FF) or (u >= 65 and u <= 122):
				has_l = true
				break
		if has_l:
			n += 1
	return n
