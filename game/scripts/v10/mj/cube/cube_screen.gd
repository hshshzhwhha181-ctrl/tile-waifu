class_name V10MjCubeScreen
extends Control

# Экран партии Куба (docs/MODES.md §4.4, общий каркас §4; UX_RULES §6.6). Контракт §7.1:
#   setup(main, args) · сигнал finished(result) · args.presence (on/sacred) · args.look · награды не начисляет.
#
# args: level (1…40, иначе из сейва), hero (иначе партнёрша G.S.partner), presence, look, relic (чья реликвия в
#   сердцевине; по умолчанию — основательница главы), seed_k (вариант раскладки 0…4), start_sheet (true),
#   result_sheet (true), instant (без раздачи), fx_min, demo (без сейва), music (true: V10MjMusic.play("cube")).
#
# Зоны (720×1280; на 9:20 и длиннее лишняя высота уходит в её полосу — сцена над кубом):
#   0 … band_h        её полоса: пауза · «3 · Осталось 48» и тонкая полоса · арочное окно с кольцом Приёма
#   band_h … H−186    поле: SubViewport 720×720 по центру (святая зона), над ним место для «×2» и её реплики;
#                     свайп по пустому месту поля вращает куб с инерцией, двойной тап по пустому — вид спереди,
#                     тап по фишке выбирает её (и никогда не вращает)
#   H−186 … H−40      помощь: Подсказка · Отмена · Перемешать (число — сколько осталось)
# Бюджет партии: тапаемых ≤ 6 (пауза, окно-Приём, 3 помощи), слов ≤ 8, бейджей 0, валют 0.

signal finished(result: Dictionary)

const T: = V10MjCubeStyle.TOK
const HELP_ZONE: = 186.0
const TAP_SLOP: = 14.0
const TAP_SLOP_TILE: = 26.0
const DOUBLE_T: = 0.32
const IDLE_S: = 20.0
const FLY_WAIT: = 0.5
var main
var args: = {}
var level: = 1
var hero: = "mc"
var relic_hero: = "mc"
var lv: = {}
var rules: V10MjCubeRules
var view: V10MjCubeView
var sound: V10MjCubeSound
var presence                    # args.presence or the lite stub
var lite: V10MjCubePresence
var save_d: = {}
var demo: = false
var fx_min: = false

var vw: = Vector2(720, 1280)
var band_h: = 120.0
var field: = Rect2()
var view_rect: = Rect2()
var catcher: Control
var left_lbl: Label
var bar: Control
var motif_lbl: Label
var banner: Label
var help_btns: = {}
var help_left: = {}
var sheet_layer: Control
var fx_layer: Control

var selected: = -1
var charge: = 0
var need: = 6
var score: = 0
var t0: = 0.0
var ended: = false
var input_on: = false
var used_help: = false
var helps_used: = 0
var rng: = RandomNumberGenerator.new()
var result: = {}
var _press: = {}
var _last_tap_t: = -10.0
var _last_tap_pos: = Vector2.ZERO
var _vel_samples: Array = []
var _spin: = 0.0
var _idle: = 0.0
var _busy: = false
var _auto_shuffles: = 0


func build(m, a: Dictionary = {}) -> void:
	setup(m, a)


func setup(m, a: Dictionary = {}) -> void:
	main = m
	args = a
	demo = bool(a.get("demo", false))
	save_d = V10MjCubeSave.st() if not demo else V10MjCubeSave.DEFAULTS.duplicate(true)
	level = clampi(int(a.get("level", save_d.get("level", 1))), 1, V10MjCubeShapes.COUNT)
	var partner: String = String(G.S.get("partner", "")) if G.S is Dictionary else ""
	hero = String(a.get("hero", partner if partner != "" else V10MjCubeShapes.host_of(level)))
	if not V10MjCubeStyle.ACCENT.has(hero):
		hero = "mc"
	relic_hero = String(a.get("relic", V10MjCubeShapes.host_of(level)))
	if not V10MjCubeRelic.NAMES.has(relic_hero):
		relic_hero = V10MjCubeShapes.host_of(level)
	fx_min = bool(a.get("fx_min", false)) or V9Feel.level() == "min"
	rng.seed = int(a.get("seed_shuffle", level * 977 + 5))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if is_inside_tree() and view == null:
		_build()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not args.is_empty() and view == null:
		_build()


# ── build ────────────────────────────────────────────────────────────────────

func _build() -> void:
	vw = get_viewport_rect().size
	if vw.x <= 0.0:
		vw = Vector2(720, 1280)
	if anchor_right == 0.0:
		size = vw
	var extra: = maxf(0.0, vw.y - 1280.0)
	band_h = 120.0 + minf(extra, 330.0)
	var spare: = extra - minf(extra, 330.0)
	lv = V10MjCubeGen.build(level, int(args.get("seed_k", 0)))
	lv = V10MjCubeGen.with_signature(lv, int(V10MjCubeStyle.SIGNATURE.get(hero, -1)))
	rules = V10MjCubeRules.make(lv.cells, lv.faces)
	help_left = V10MjCubeSave.help_for(level)
	var aff: = 1
	if G.S is Dictionary and G.S.has("aff") and G.has_method("aff_level"):
		aff = G.aff_level(hero)
	need = V10MjCubeUlts.need(aff)
	charge = mini(need, V10MjCubeUlts.start_charge(hero))
	sound = V10MjCubeSound.new()
	sound.name = "Sound"
	add_child(sound)
	field = Rect2(0, band_h + spare * 0.5, vw.x, vw.y - HELP_ZONE - band_h - spare)
	var side: = minf(720.0, minf(vw.x, field.size.y - 24.0))
	view_rect = Rect2(Vector2((vw.x - side) * 0.5, field.get_center().y - side * 0.5 + 6.0), Vector2(side, side))
	_build_bg()
	_build_view(side)
	_build_catcher()
	_build_band()
	_build_help()
	fx_layer = Control.new()
	fx_layer.name = "Fx"
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
	if bool(args.get("music", true)) and not demo:
		var mu: = "res://scripts/v10/mj/look/music.gd"
		if ResourceLoader.exists(mu):
			var cls = load(mu)
			if cls and cls.has_method("play"):
				cls.play(String(V10MjCubeInfo.INFO.music))
	_warm_sounds()
	if bool(args.get("start_sheet", true)):
		_start_sheet()
	else:
		_start()


func _build_bg() -> void:
	var base: = TextureRect.new()
	base.name = "Bg"
	base.texture = V10MjCubeStyle.night_gradient(hero)
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_SCALE
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	var tt: = V10MjCubeStyle.table_tex(hero)
	if tt:
		var tr: = TextureRect.new()
		tr.name = "Table"
		tr.texture = tt
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.modulate = Color(0.62, 0.6, 0.66, 1.0)
		add_child(tr)
		# night veil: keeps text ≥ 4.5:1 and the cube the brightest thing on screen
		var veil: = TextureRect.new()
		var g: = Gradient.new()
		g.set_color(0, Color(T.night900, 0.82))
		g.set_color(1, Color(T.night900, 0.9))
		g.add_point(0.45, Color(T.night900, 0.42))
		var gt: = GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0.5, 0.0)
		gt.fill_to = Vector2(0.5, 1.0)
		gt.width = 8
		gt.height = 128
		veil.texture = gt
		veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		veil.stretch_mode = TextureRect.STRETCH_SCALE
		veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(veil)
	var pool: = TextureRect.new()
	pool.name = "Pool"
	pool.texture = V10MjCubeStyle.pool(relic_hero)
	pool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pool.stretch_mode = TextureRect.STRETCH_SCALE
	pool.position = view_rect.position - view_rect.size * 0.1
	pool.size = view_rect.size * 1.2
	pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pool)


func _build_view(side: float) -> void:
	view = V10MjCubeView.new()
	view.name = "CubeView"
	view.position = view_rect.position
	add_child(view)
	view.setup(lv, rules, {"hero": hero, "accent": V10MjCubeStyle.accent(hero)[0], "look": args.get("look", {}),
		"fx_min": fx_min, "px": int(round(side)), "relic": relic_hero})
	view.size = view_rect.size
	view.spun.connect(_on_spun)
	view.knocked.connect(_on_knocked)


# the input surface: the whole field (swipe on empty space rotates; a tap picks)
func _build_catcher() -> void:
	catcher = Control.new()
	catcher.name = "Field"
	catcher.position = field.position
	catcher.size = field.size
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_on_field_input)
	add_child(catcher)


func _build_band() -> void:
	var pause: = _icon_button("pause", Vector2(12, 18))
	pause.name = "Pause"
	pause.pressed.connect(_pause_sheet)
	add_child(pause)
	left_lbl = V10MjCubeStyle.label("", 22, T.paper100, "body", 800)
	left_lbl.name = "Left"
	left_lbl.position = Vector2(104, 28)
	left_lbl.size = Vector2(330, 32)
	add_child(left_lbl)
	bar = Control.new()
	bar.name = "Bar"
	bar.position = Vector2(104, 70)
	bar.size = Vector2(minf(300.0, vw.x - 104.0 - 180.0), 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var p: = 1.0 - float(rules.left()) / maxf(1.0, float(lv.n))
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(T.paper100, 0.12))
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * p, bar.size.y)), T.jade500))
	add_child(bar)
	motif_lbl = V10MjCubeStyle.label("×2", 60, T.gold300, "italic", 700)
	V10MjCubeStyle.shadow(motif_lbl)
	motif_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	motif_lbl.size = Vector2(200, 80)
	motif_lbl.pivot_offset = Vector2(100, 40)
	motif_lbl.position = Vector2(vw.x * 0.5 - 100.0, maxf(band_h + 2.0, view_rect.position.y - 92.0))
	motif_lbl.modulate.a = 0.0
	add_child(motif_lbl)
	banner = V10MjCubeStyle.label("", 44, T.paper100, "title", 700)
	V10MjCubeStyle.shadow(banner)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(vw.x, 60)
	banner.position = Vector2(0, view_rect.get_center().y - 30.0)
	banner.modulate.a = 0.0
	add_child(banner)


func _window_rect() -> Rect2:
	var h: = band_h - 14.0
	var w: = clampf(h * 0.72, 96.0, 300.0)
	if band_h <= 140.0:
		w = 104.0
		h = band_h - 8.0
	return Rect2(vw.x - w - 18.0, band_h - h - 2.0, w, h)


func _line_rect() -> Rect2:
	var gap: = view_rect.position.y - band_h
	var wr: = _window_rect()
	if gap >= 56.0:
		# between her band and the cube, under her window, right-aligned (at her shoulder)
		return Rect2(24, band_h + 6.0, vw.x - 48.0, minf(gap - 14.0, 76.0))
	return Rect2(104, 80, wr.position.x - 120.0, 36)


func _build_presence() -> void:
	lite = V10MjCubePresence.new()
	lite.attach(self, hero, {"fx": "min" if fx_min else (G.fx_level() if G.has_method("fx_level") else "full")})
	move_child(lite, fx_layer.get_index())
	lite.layout(Rect2(0, 0, vw.x, band_h), _window_rect(), _line_rect())
	lite.finale_field = field
	lite.portrait_tapped.connect(_try_ult)
	lite.finale_done.connect(_after_finale)
	var ext = args.get("presence")
	presence = ext if ext != null and ext.has_method("on") else lite
	if presence != lite:
		lite.visible = false
		if presence.has_signal("portrait_tapped"):
			presence.portrait_tapped.connect(_try_ult)
		if presence.has_signal("finale_done"):
			presence.finale_done.connect(_after_finale)
	for r in sacred_rects():
		lite.sacred(r)
		if presence != lite and presence.has_method("sacred"):
			presence.sacred(r)
	_sync_charge()


func sacred_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.append(view_rect)
	out.append(Rect2(0, vw.y - HELP_ZONE, vw.x, HELP_ZONE - 32.0))
	return out


func _icon_button(kind: String, pos: Vector2) -> Button:
	var b: = Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.size = Vector2(80, 80)
	b.custom_minimum_size = Vector2(80, 80)
	b.set_meta("ux_role", "tertiary")
	var ic: = V10MjCubeIcon.new(kind, T.paper300)
	ic.position = Vector2(16, 16)
	ic.size = Vector2(48, 48)
	b.add_child(ic)
	b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
	return b


func _build_help() -> void:
	var keys: Array = V10MjCubeSave.HELP
	var n: = keys.size()
	var y: = vw.y - HELP_ZONE + 20.0
	var gap: = 168.0
	var x0: = vw.x * 0.5 - (n - 1) * gap * 0.5
	for k in n:
		var key: String = keys[k]
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
		b.custom_minimum_size = Vector2(96, 96)
		b.set_meta("ux_role", "tertiary")
		b.draw.connect(func():
			var c: = Vector2(48, 48)
			var on: bool = int(help_left.get(key, 0)) > 0
			b.draw_circle(c, 46.0, T.night700)
			b.draw_arc(c, 46.0, 0, TAU, 48, Color(T.gold700, 0.35 if on else 0.2), 1.5, true)
			var nb: = Vector2(80, 80)
			b.draw_circle(nb, 15.0, T.night900)
			b.draw_arc(nb, 15.0, 0, TAU, 24, Color(T.gold500, 0.5 if on else 0.2), 1.2, true))
		var ic: = V10MjCubeIcon.new(key, T.gold300)
		ic.position = Vector2(24, 24)
		ic.size = Vector2(48, 48)
		b.add_child(ic)
		var num: = V10MjCubeStyle.label("1", 18, T.paper100, "body", 900)
		num.name = "Num"
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.size = Vector2(30, 26)
		num.position = Vector2(65, 66)
		b.add_child(num)
		root.add_child(b)
		var cap: = V10MjCubeStyle.label(V10MjCubeSave.NAMES[key], 18, T.paper500, "body", 700)
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
		if key == "undo":
			on = on and not rules.history.is_empty()
		(b.get_node("Num") as Label).text = str(left)
		b.modulate = Color(1, 1, 1, 1.0 if on else 0.45)
		b.queue_redraw()


func _warm_sounds() -> void:
	# synthesis is cached; spread the first takes over frames so the first pair never hitches
	for k in 3:
		await get_tree().process_frame
		V10MjCubeSound.toktok_wav(k)
	await get_tree().process_frame
	V10MjCubeSound.rustle_wav(0)
	V10MjCubeSound.tick_wav()
	V10MjCubeSound.deny_wav()


# ── flow ─────────────────────────────────────────────────────────────────────

func _start() -> void:
	t0 = Time.get_ticks_msec() / 1000.0
	input_on = true
	lite.input_on = true
	if not bool(args.get("instant", false)) and not fx_min:
		# the figure turns in from the side (≈ 0.6 s), input stays on
		view.set_view(V10MjCubeView.HOME.x - 1.2, V10MjCubeView.HOME.y - 0.25)
		view.home(true)
	_banner("%s · %d" % [V10MjCubeInfo.INFO.name, level])
	_emit("start", {})


# an event goes to the presence (ext or lite); the lite stub always hears it too (tilt, motes, audit)
func _emit(ev: String, data: Dictionary) -> void:
	if presence != lite and presence.has_method("on") and ev != "start":
		presence.on(ev, data)
	lite.on(ev, data)


func _banner(text: String, hold: = 0.42) -> void:
	banner.text = text
	var tw: = banner.create_tween()
	banner.modulate.a = 0.0
	tw.tween_property(banner, "modulate:a", 1.0, 0.18)
	tw.tween_interval(hold)
	tw.tween_property(banner, "modulate:a", 0.0, 0.2)


func _refresh() -> void:
	if rules == null or left_lbl == null:
		return
	left_lbl.text = "%d · Осталось %d" % [level, rules.left()]
	bar.queue_redraw()
	_refresh_help()


func _process(dt: float) -> void:
	if view == null:
		return
	if absf(_spin) > 0.01:
		sound.rustle(_spin, dt)
		_spin = lerpf(_spin, 0.0, 1.0 - exp(-dt * 8.0))
	if input_on and not ended:
		_idle += dt
		if _idle >= IDLE_S:
			_idle = -IDLE_S
			_emit("idle", {})
	lite.input_on = input_on and not ended


func _on_spun(yaw_vel: float) -> void:
	_spin = yaw_vel
	var deg: = clampf(yaw_vel * 1.6, -V10MjCubePresence.TILT_MAX, V10MjCubePresence.TILT_MAX)
	lite.tilt(deg)
	if presence != lite and presence.has_method("tilt"):
		presence.tilt(deg)


# ── input on the field ───────────────────────────────────────────────────────

func _on_field_input(e: InputEvent) -> void:
	if not input_on or ended or _busy:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		var gp: Vector2 = catcher.get_global_transform() * e.position
		if e.pressed:
			var hit: = -1
			if view_rect.has_point(gp):
				hit = view.pick(gp - view_rect.position)
			_press = {"pos": gp, "t": Time.get_ticks_msec() / 1000.0, "hit": hit, "moved": false, "last": gp}
			_vel_samples.clear()
			view.stop()
		elif not _press.is_empty():
			if _press.moved:
				view.fling(_fling_velocity())
			else:
				_tap(gp, int(_press.hit))
			_press = {}
	elif e is InputEventMouseMotion and not _press.is_empty():
		var gp: Vector2 = catcher.get_global_transform() * e.position
		var slop: = TAP_SLOP_TILE if int(_press.hit) >= 0 else TAP_SLOP
		if not _press.moved and gp.distance_to(_press.pos) > slop:
			_press.moved = true
			_press.last = gp
		if _press.moved:
			var d: Vector2 = gp - _press.last
			_press.last = gp
			view.drag(d)
			_idle = 0.0
			_vel_samples.append([Time.get_ticks_msec() / 1000.0, d])
			if _vel_samples.size() > 6:
				_vel_samples.pop_front()


func _fling_velocity() -> Vector2:
	if _vel_samples.size() < 2:
		return Vector2.ZERO
	var now: = Time.get_ticks_msec() / 1000.0
	var sum: = Vector2.ZERO
	var t_first: float = _vel_samples[0][0]
	if now - float(_vel_samples[_vel_samples.size() - 1][0]) > 0.08:
		return Vector2.ZERO
	for s in _vel_samples:
		sum += s[1]
	return sum / maxf(0.016, now - t_first)


# a tap at screen point gp; hit = the tile under the finger at touch-down (−1 = empty space)
func _tap(gp: Vector2, hit: int) -> void:
	_idle = 0.0
	if hit < 0:
		var now: = Time.get_ticks_msec() / 1000.0
		if now - _last_tap_t < DOUBLE_T and gp.distance_to(_last_tap_pos) < 60.0:
			_last_tap_t = -10.0
			view.home(true)
		else:
			_last_tap_t = now
			_last_tap_pos = gp
			if selected >= 0:
				_select(-1)
		return
	_last_tap_t = -10.0
	tap_tile(hit)


# select / pair logic for one tile (also the entry point of the demo and the selftest)
func tap_tile(i: int) -> void:
	if ended or not input_on or i < 0 or rules.present[i] != 1:
		return
	var gp: = view_rect.position + view.tile_screen(i)
	if not rules.is_free(i):
		sound.deny()
		_nudge(i)
		return
	_emit("pick", {"pos": gp})
	if selected < 0:
		_select(i)
		sound.pick()
	elif selected == i:
		_select(-1)
	elif rules.can_pair(selected, i):
		_take(selected, i, false)
	else:
		rules.miss()
		_select(i)
		sound.pick()


func _select(i: int) -> void:
	if selected >= 0:
		view.set_selected(selected, false)
	selected = i
	if i >= 0:
		view.set_selected(i, true)


func _nudge(i: int) -> void:
	# a blocked tile: a tiny hint glow for 0.25 s, no shake of the UI
	view.set_hint(view.hinted + [i])
	get_tree().create_timer(0.25).timeout.connect(func():
		if is_instance_valid(view):
			var h: Array = view.hinted.duplicate()
			h.erase(i)
			view.set_hint(h))


var _pending_knock: = {}


func _take(a: int, b: int, from_ult: bool) -> void:
	var face: = rules.face[a]
	var info: = rules.take(a, b, not from_ult)
	if not info.ok:
		sound.deny()
		return
	if selected == a or selected == b:
		selected = -1
	if view.hinted.has(a) or view.hinted.has(b):
		view.set_hint([])
	var mult: = 2.0 if info.bonus else 1.0
	var gain: = int(round(10.0 * (1.0 + 0.1 * float(mini(int(info.series) - 1, 10))) * mult))
	score += gain
	var meet: = view.fly_pair(a, b)
	_pending_knock = {"series": int(info.series), "motif": bool(info.motif), "face": face, "ult": from_ult,
		"pos": view_rect.position + meet}
	if fx_min:
		_on_knocked(meet)
	if info.motif:
		_show_motif()
		_emit("motif", {})
	if not from_ult and int(info.series) in [3, 5, 8, 12]:
		_emit("combo", {"n": int(info.series)})
	if rules.left() == 2:
		_emit("last_pair", {})
	_refresh()
	if rules.won:
		_on_win()
	else:
		_check_stuck()


func _on_knocked(local: Vector2) -> void:
	if _pending_knock.is_empty():
		return
	var k: = _pending_knock
	_pending_knock = {}
	sound.toktok(int(k.series), bool(k.motif))
	var gp: Vector2 = view_rect.position + local
	if bool(k.ult):
		_emit("pair", {"pos": gp})
		return
	var add: = 1
	if int(k.face) == int(V10MjCubeStyle.SIGNATURE.get(hero, -1)):
		add += 1
		_emit("signature", {})
	charge = mini(need, charge + add)
	_emit("pair", {"pos": gp, "charge": float(charge) / need, "need": need})
	_sync_charge()


func _sync_charge() -> void:
	lite.set_charge(float(charge) / maxf(1.0, need), charge >= need)


func _show_motif() -> void:
	motif_lbl.scale = Vector2(1.35, 1.35)
	motif_lbl.modulate.a = 1.0
	var tw: = motif_lbl.create_tween()
	tw.tween_property(motif_lbl, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.3)
	tw.tween_property(motif_lbl, "modulate:a", 0.0, 0.14)


# no tappable pair left: shuffle for free (it still costs moves), she says nothing — the banner explains
func _check_stuck() -> void:
	if not rules.free_pairs(true).is_empty() or rules.left() == 0:
		return
	_busy = true
	await get_tree().create_timer(0.5 if not fx_min else 0.05).timeout
	if not is_instance_valid(self) or ended:
		return
	_banner("Перемешиваю", 0.5)
	_do_shuffle()
	rules.moves += V10MjCubeRules.COST_SHUFFLE
	_auto_shuffles += 1
	_busy = false


func _do_shuffle() -> bool:
	_select(-1)
	view.set_hint([])
	var order: = rules.shuffle(rng)
	if order.is_empty():
		return false
	sound.shuffle()
	var all: = []
	for i in rules.cells.size():
		if rules.present[i] == 1:
			all.append(i)
	view.pop_in(all)
	_refresh()
	return true


# ── help & Приём ─────────────────────────────────────────────────────────────

func _use_help(key: String) -> void:
	if ended or not input_on or _busy or int(help_left.get(key, 0)) <= 0:
		sound.deny()
		return
	var ok: = false
	match key:
		"hint":
			var p: = rules.hint_pair()
			if not p.is_empty():
				_select(-1)
				view.set_hint(p)
				view.aim_at(p)
				rules.moves += V10MjCubeRules.COST_HINT
				rules.series = 0
				ok = true
		"undo":
			var ab: = rules.undo()
			if not ab.is_empty():
				_select(-1)
				view.set_hint([])
				view.pop_in(ab)
				ok = true
		"shuffle":
			ok = _do_shuffle()
			if ok:
				rules.moves += V10MjCubeRules.COST_SHUFFLE
	if ok:
		help_left[key] = int(help_left[key]) - 1
		used_help = true
		helps_used += 1
		_idle = 0.0
		_refresh()
	else:
		sound.deny()


func _try_ult() -> void:
	if ended or not input_on or _busy:
		return
	if charge < need:
		sound.deny()
		return
	var plan: = V10MjCubeUlts.plan(hero, rules, Vector3(lv.relic_at))
	if V10MjCubeUlts.empty(plan):
		sound.deny()
		return
	charge = 0
	_sync_charge()
	_busy = true
	_emit("ult", {})
	var nm: = V10MjCubeStyle.label(V10MjCubeUlts.ult_name(hero), 40, V10MjCubeStyle.accent(hero)[1], "italic", 700)
	V10MjCubeStyle.shadow(nm)
	nm.position = Vector2(24, band_h + 8.0)
	nm.size = Vector2(vw.x - 48.0, 56)
	nm.modulate.a = 0.0
	fx_layer.add_child(nm)
	var tw: = nm.create_tween()
	tw.tween_property(nm, "modulate:a", 1.0, 0.15)
	tw.tween_interval(0.7)
	tw.tween_property(nm, "modulate:a", 0.0, 0.25)
	tw.tween_callback(nm.queue_free)
	V9Feel.sound("summon_charge", 1.2, -6.0)
	await get_tree().create_timer(0.4 if not fx_min else 0.02).timeout
	if not (plan.show as Array).is_empty():
		view.set_hint(plan.show)
		view.aim_at(plan.show)
	if not (plan.glow as Array).is_empty():
		view.set_hint(plan.glow)
		view.full_turn(2.4)
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(view) and view.hinted == plan.glow:
				view.set_hint([]))
	for p in plan.pairs:
		if ended:
			break
		_select(-1)
		_take(int(p[0]), int(p[1]), true)
		await get_tree().create_timer(0.36 if not fx_min else 0.02).timeout
	_busy = false
	_refresh()


# ── finale ───────────────────────────────────────────────────────────────────

func _on_win() -> void:
	if ended:
		return
	ended = true
	input_on = false
	lite.input_on = false
	_select(-1)
	await get_tree().create_timer(FLY_WAIT if not fx_min else 0.05).timeout
	sound.relic(relic_hero)
	await view.relic_rise()
	# the relic flies into her hands (the window), then she comes out in her win pose
	var from: = view_rect.position + view.relic_screen_pos()
	var to: Vector2 = presence.window_center() if presence.has_method("window_center") else lite.window_center()
	view.relic_leave()
	await _relic_flight(from, to)
	_emit("win", {"relic": relic_hero})
	if not presence.has_signal("finale_done"):
		get_tree().create_timer(2.4).timeout.connect(_after_finale)


func _relic_flight(from: Vector2, to: Vector2) -> void:
	if fx_min:
		return
	var acc: Color = V10MjCubeRelic.COLORS[relic_hero]
	var s: = Sprite2D.new()
	s.texture = G.fx("glow")
	s.material = Fx.add_mat()
	s.modulate = Color(acc, 0.9)
	s.scale = Vector2.ONE * 0.7
	s.position = from
	fx_layer.add_child(s)
	var ic: = V10MjCubeIcon.new("relic", acc.lerp(Color.WHITE, 0.35))
	ic.size = Vector2(56, 56)
	ic.position = from - Vector2(28, 28)
	fx_layer.add_child(ic)
	var mid: = from.lerp(to, 0.5) + Vector2(-80, -60)
	var tw: = create_tween()
	tw.tween_method(func(v: float):
		var u: = 1.0 - v
		var p: = from * u * u + mid * 2.0 * u * v + to * v * v
		s.position = p
		s.scale = Vector2.ONE * lerpf(0.7, 0.3, v)
		ic.position = p - ic.size * 0.5
		ic.scale = Vector2.ONE * lerpf(1.0, 0.6, v), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		s.queue_free()
		ic.queue_free())
	await tw.finished


func _after_finale() -> void:
	if not result.is_empty() and result.has("action"):
		return
	_finish_result(true)
	if bool(args.get("result_sheet", true)):
		_win_sheet()
	else:
		finished.emit(result)


func _finish_result(win: bool) -> void:
	var moves: = rules.moves
	var stars: = V10MjCubeSave.stars_for(win, moves, int(lv.get("par3", 0)), int(lv.get("par2", 0)))
	var rec: = {"stars_gain": 0, "first_clear": false, "relic": "", "relic_new": false}
	if not demo and not result.has("record"):
		rec = V10MjCubeSave.record(save_d, level, win, stars, score, moves)
		if G.has_method("save"):
			G.save()
	elif result.has("record"):
		rec = result.record
	elif demo and win:
		rec.relic = V10MjCubeSave.relic_of(level)
		rec.relic_new = rec.relic != "" and not (save_d.relics as Array).has(rec.relic)
		rec.first_clear = V10MjCubeSave.stars_of(save_d, level) == 0
	result = {
		"mode": "cube", "win": win, "score": score, "stars": stars,
		"time_s": int(Time.get_ticks_msec() / 1000.0 - t0), "pairs": rules.pairs_taken,
		"hero": hero, "seed": int(lv.get("seed", 0)), "level": level, "moves": moves,
		"rewards": V10MjCubeSave.rewards(level, win, bool(rec.first_clear)),
		"relic": rec.relic, "relic_new": rec.relic_new, "stars_gain": rec.stars_gain,
		"helped": used_help, "motifs": rules.motifs, "auto_shuffles": _auto_shuffles, "record": rec,
	}


# ── sheets ───────────────────────────────────────────────────────────────────

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
	p.name = "Sheet"
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
	if fx_min:
		p.position.y = vw.y - height
		dim.color.a = 0.45
	else:
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
	b.name = "Primary"
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(maxf(440.0, w), 104)
	b.custom_minimum_size = b.size
	b.set_meta("ux_role", "primary")
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = T.rose700 if st == "pressed" else T.rose500
		sb.set_corner_radius_all(52)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_override("font", V10MjCubeStyle.font("title", 600))
	b.add_theme_font_size_override("font_size", 32)
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, T.night900)
	b.pivot_offset = b.size * 0.5
	b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
	if not fx_min:
		# «дыхание» главной кнопки — единственная бесконечная анимация UI (UX §6.7)
		var tw: = b.create_tween().set_loops()
		tw.tween_property(b, "scale", Vector2(0.985, 0.985), 1.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)
	return b


func _secondary(text: String) -> Button:
	var b: = Button.new()
	b.name = "Secondary"
	b.text = text + "  ›"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(320, 80)
	b.custom_minimum_size = Vector2(320, 80)
	b.set_meta("ux_role", "secondary")
	b.add_theme_font_override("font", V10MjCubeStyle.font("body", 800))
	b.add_theme_font_size_override("font_size", 22)
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, T.paper100)
	b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
	return b


func _stars_row(n: int, of: = 3, sz: = 44.0) -> Control:
	var row: = Control.new()
	row.size = Vector2(of * (sz + 10.0), sz)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in of:
		var ic: = V10MjCubeIcon.new("star", T.gold300 if k < n else Color(T.paper700, 0.6))
		ic.size = Vector2(sz, sz)
		ic.position = Vector2(k * (sz + 10.0), 0)
		row.add_child(ic)
	return row


static func moves_word(n: int) -> String:
	var m10: = n % 10
	var m100: = n % 100
	if m10 == 1 and m100 != 11:
		return "ход"
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return "хода"
	return "ходов"


func _start_sheet() -> void:
	input_on = false
	var p: = _sheet(500.0)
	var ch: = V10MjCubeShapes.chapter_of(level) + 1
	var over: = V10MjCubeStyle.label("КУБ · ГЛАВА %d" % ch, 15, T.gold500, "body", 900)
	over.position = Vector2(32, 32)
	p.add_child(over)
	var h1: = V10MjCubeStyle.label("Уровень %d" % level, 44, T.paper100, "title", 700)
	h1.position = Vector2(32, 58)
	p.add_child(h1)
	var dn: = V10MjCubeStyle.label("%s · %s" % [lv.name, V10MjCubeShapes.KIND_NAMES[lv.kind]], 18, T.paper500, "body", 700)
	dn.position = Vector2(34, 120)
	p.add_child(dn)
	var sr: = _stars_row(V10MjCubeSave.stars_of(save_d, level), 3, 34.0)
	sr.position = Vector2(vw.x - 116.0 - sr.size.x, 72)
	p.add_child(sr)
	var help_b: = _icon_button("help", Vector2(vw.x - 96.0, 20.0))
	help_b.name = "HelpBtn"
	help_b.pressed.connect(func(): _help_sheet(true))
	p.add_child(help_b)
	var row: = Control.new()
	row.position = Vector2(24, 168)
	row.size = Vector2(vw.x - 48.0, 88)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.draw.connect(func(): row.draw_rect(Rect2(Vector2.ZERO, row.size), T.night800))
	p.add_child(row)
	var ic: = V10MjCubeIcon.new("relic", V10MjCubeRelic.COLORS[relic_hero].lerp(T.gold300, 0.4))
	ic.position = Vector2(16, 20)
	ic.size = Vector2(48, 48)
	row.add_child(ic)
	var t1: = V10MjCubeStyle.label("Внутри — " + V10MjCubeRelic.lower_name(relic_hero), 22, T.paper100, "body", 800)
	t1.position = Vector2(80, 14)
	row.add_child(t1)
	var keep: = "в витрину за этот уровень" if V10MjCubeShapes.is_boss(level) and not (save_d.relics as Array).has(relic_hero) else "поднимется последней парой"
	var t2: = V10MjCubeStyle.label(keep, 18, T.paper500, "body", 700)
	t2.position = Vector2(80, 46)
	row.add_child(t2)
	var how: = V10MjCubeStyle.label("★★★ — до %d %s" % [int(lv.par3), moves_word(int(lv.par3))], 18, T.paper300, "body", 700)
	how.position = Vector2(32, 276)
	p.add_child(how)
	var play: = _primary("Играть")
	play.position = Vector2(vw.x * 0.5 - 280.0, 500.0 - 136.0)
	play.pressed.connect(func():
		_close_sheet()
		_start())
	p.add_child(play)


func _pause_sheet() -> void:
	if ended or sheet_layer.mouse_filter == Control.MOUSE_FILTER_STOP:
		return
	var was: = input_on
	input_on = false
	var p: = _sheet(560.0)
	var h: = V10MjCubeStyle.label("Пауза", 32, T.paper100, "title", 600)
	h.position = Vector2(32, 32)
	p.add_child(h)
	var help_b: = _icon_button("help", Vector2(vw.x - 96.0, 18.0))
	help_b.name = "HelpBtn"
	help_b.pressed.connect(func(): _help_sheet(false, was))
	p.add_child(help_b)
	for k in V10MjCubeInfo.HOW.size():
		var row: Array = V10MjCubeInfo.HOW[k]
		var ic: = V10MjCubeIcon.new(row[0], T.gold300)
		ic.position = Vector2(32, 92 + k * 62)
		ic.size = Vector2(44, 44)
		p.add_child(ic)
		var l: = V10MjCubeStyle.label(row[1], 20, T.paper300, "body", 700)
		l.position = Vector2(92, 100 + k * 62)
		l.size = Vector2(vw.x - 120, 40)
		p.add_child(l)
	var go_on: = _primary("Продолжить")
	go_on.position = Vector2(vw.x * 0.5 - 280.0, 316)
	go_on.pressed.connect(func():
		_close_sheet()
		input_on = was)
	p.add_child(go_on)
	var quit: = _secondary("Выйти")
	quit.position = Vector2(vw.x * 0.5 - 160.0, 440)
	quit.pressed.connect(func():
		_close_sheet()
		ended = true
		_finish_result(false)
		result["action"] = "exit"
		finished.emit(result))
	p.add_child(quit)


func open_help() -> void:
	_help_sheet(false, input_on)


func _help_sheet(from_start: bool, prev_input: bool = true) -> void:
	input_on = false
	var p: = _sheet(620.0)
	var h: = V10MjCubeStyle.label("Как играть", 36, T.paper100, "title", 700)
	h.position = Vector2(32, 28)
	p.add_child(h)
	for k in V10MjCubeInfo.HOW.size():
		var row: Array = V10MjCubeInfo.HOW[k]
		var ic: = V10MjCubeIcon.new(String(row[0]), T.gold300)
		ic.position = Vector2(32, 92 + k * 60)
		ic.size = Vector2(44, 44)
		p.add_child(ic)
		var l: = V10MjCubeStyle.label(String(row[1]), 20, T.paper300, "body", 700)
		l.position = Vector2(92, 100 + k * 60)
		l.size = Vector2(vw.x - 120.0, 40)
		p.add_child(l)
	var rule_l: = V10MjCubeStyle.label(V10MjCubeInfo.RULE, 18, T.paper500, "body", 600)
	rule_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_l.position = Vector2(32, 286)
	rule_l.size = Vector2(vw.x - 64.0, 56)
	p.add_child(rule_l)
	for s_i in V10MjCubeInfo.STARS_HOW.size():
		var sl: = V10MjCubeStyle.label(String(V10MjCubeInfo.STARS_HOW[s_i]), 18, T.gold300, "body", 700)
		sl.position = Vector2(32, 352 + s_i * 32)
		p.add_child(sl)
	var ok_b: = _primary("Понятно")
	ok_b.name = "OkBtn"
	ok_b.position = Vector2(vw.x * 0.5 - 280.0, 476)
	ok_b.pressed.connect(func():
		_close_sheet()
		if from_start:
			_start_sheet()
		else:
			input_on = prev_input)
	p.add_child(ok_b)


# ── бюджеты партии (для самотеста UX_RULES §6.6) ─────────────────────────────

func tappables() -> Array:
	var out: Array = []
	var pause_n: Node = get_node_or_null("Pause")
	if pause_n:
		out.append(pause_n)
	if lite and lite._win and lite.visible:
		out.append(lite._win)
	elif presence != lite and presence != null:
		out.append(presence)
	for k in help_btns:
		out.append(help_btns[k])
	return out


func words_in_play() -> int:
	var txt: = (left_lbl.text if left_lbl else "") + " " + " ".join(V10MjCubeSave.NAMES.values())
	var n: = 0
	for tok in txt.split(" ", false):
		var has_letter: = false
		for i in tok.length():
			var u: = tok.unicode_at(i)
			if (u >= 0x0400 and u <= 0x04FF) or (u >= 65 and u <= 122):
				has_letter = true
				break
		if has_letter:
			n += 1
	return n


func _win_sheet() -> void:
	var p: = _sheet(580.0)
	var h: = V10MjCubeStyle.label("Стол чист", 64, T.paper100, "title", 700)
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
		if fx_min:
			continue
		st.scale = Vector2.ZERO
		var tw: = st.create_tween()
		tw.tween_interval(0.15 + k * 0.14)
		tw.tween_property(st, "scale", Vector2(1.15, 0.9), 0.1)
		tw.tween_property(st, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if k < int(result.stars):
			tw.tween_callback(func(): sound.step_note(2 + k * 2))
	var mv: = int(result.moves)
	var sc: = V10MjCubeStyle.label("%d очков · %d %s" % [score, mv, moves_word(mv)], 22, T.paper300, "body", 800)
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
	if bool(result.get("relic_new", false)):
		tokens.append("%s — в витрину" % String(V10MjCubeRelic.SHORT[result.relic]).capitalize())
	var tw_x: = 220.0
	var tx: = vw.x * 0.5 - tokens.size() * tw_x * 0.5
	for k in tokens.size():
		var t: = V10MjCubeStyle.label(tokens[k], 18, T.gold300, "body", 800)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.size = Vector2(tw_x - 8.0, 30)
		t.position = Vector2(tx + k * tw_x, 250)
		p.add_child(t)
		if not fx_min:
			t.modulate.a = 0.0
			var tw: = t.create_tween()
			tw.tween_interval(0.6 + k * 0.08)
			tw.tween_property(t, "modulate:a", 1.0, 0.12)
	var nxt: = mini(level + 1, V10MjCubeShapes.COUNT)
	var prim: = _primary("Ещё уровень · %d" % nxt)
	prim.position = Vector2(vw.x * 0.5 - 280.0, 320)
	prim.pressed.connect(func():
		result["action"] = "next"
		finished.emit(result))
	p.add_child(prim)
	var sec: = _secondary("В Столы")
	sec.position = Vector2(vw.x * 0.5 - 160.0, 452)
	sec.pressed.connect(func():
		result["action"] = "exit"
		finished.emit(result))
	p.add_child(sec)
	lite.hide_finale()
