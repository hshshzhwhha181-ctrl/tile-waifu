class_name V10MjConnectScreen
extends Control

# Экран партии «Связи» (Шисэн-сё, docs/MODES.md §4.3, каркас §4, контракт §7.1; UX_RULES §6.6).
#   setup(main, args) / build(main, args)
#   signal finished(result) — {mode, win, score, stars, time_s, pairs, hero, seed, level, rewards, ...}
# Награды экран не начисляет — передаёт в result.rewards.

signal finished(result: Dictionary)

const T: = V10MjConnectLook.TOK
const HELP_ZONE: = 186.0
const COMBO_WINDOW: = 6.0
const TIMED_SECS: = 180.0
const STAGE_PATH: = "res://scripts/v10/mj/stage/presence.gd"
const TABLE_VIEW_PATH: = "res://scripts/v10/mj/look/table_view.gd"
const MUSIC_PATH: = "res://scripts/v10/mj/look/music.gd"

var main: Node
var args: = {}
var level: = 1
var hero: = "rin"
var seed_: = 0
var big_tiles: = false
var timed: = false
var demo: = false
var fx_min: = false
var save_d: = {}
var payload: = {}
var board: V10MjConnectBoard
var sound: V10MjConnectSound
var presence: Object
var lite: V10MjConnectPresence

var vw: = Vector2(720, 1280)
var band_h: = 120.0
var field_rect: = Rect2()
var help_rect_v: = Rect2()
var cell_size: = Vector2(56, 68)
var grid_origin: = Vector2.ZERO
var border_pad: = 20.0

var table_view: Control
var board_root: Control
var tile_nodes: = {}       # t -> _TileNode
var thread_layer: _ThreadLayer
var left_lbl: Label
var bar: Control
var combo_lbl: Label
var banner: Label
var pause_btn: Button
var help_btns: = {}
var sheet_layer: Control
var fx_layer: Control

var selected: = -1
var hinted_pair: Array = []
var hinted_path: Array = []
var show_all_until: = 0.0
var show_all_ids: = {}

var input_on: = false
var ended: = false
var paused: = false
var busy: = false
var time_s: = 0.0
var time_left: = TIMED_SECS
var idle_t: = 0.0
var score: = 0
var moves_count: = 0
var hints_used: = 0
var manual_shuffles: = 0
var auto_shuffles: = 0
var ults_used: = 0
var charge: = 0
var need: = 6
var combo: = 0
var pair_times: Array = []
var last_face: = -1
var motif_next: = false
var rng: = RandomNumberGenerator.new()
var result: = {}


func build(m, a: Dictionary = {}) -> void:
	setup(m, a)


func setup(m, a: Dictionary) -> void:
	main = m
	args = a
	demo = bool(a.get("demo", false)) or bool(a.get("no_save", false))
	save_d = V10MjConnectSave.st() if not demo else V10MjConnectSave.DEFAULTS.duplicate(true)
	level = clampi(int(a.get("level", save_d.get("level", 1))), 1, V10MjConnectGen.COUNT)
	var ch: = (level - 1) / V10MjConnectGen.PER
	var partner: = ""
	if G.get("S") is Dictionary:
		partner = String(G.S.get("partner", ""))
	hero = String(a.get("hero", partner if partner != "" else V10MjConnectLook.CHAPTER_HOST[ch]))
	if not V10MjConnectLook.ACCENT.has(hero) and not (G.get("HEROES") is Dictionary and (G.HEROES as Dictionary).has(hero)):
		hero = "rin"
	seed_ = int(a.get("seed", 0))
	big_tiles = bool(a.get("big", _clarity_big()))
	timed = bool(a.get("timed", false))
	fx_min = bool(a.get("fx_min", false)) or String(a.get("fx", "")) == "min" or V9Feel.level() == "min"
	rng.seed = int(a.get("seed_shuffle", level * 1319 + seed_ * 37 + 11))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if is_inside_tree() and board == null:
		_build()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not args.is_empty() and board == null:
		_build()


static func _clarity_big() -> bool:
	if G.get("S") is Dictionary and G.S.get("v10_clarity") is Dictionary:
		return bool(G.S.v10_clarity.get("big", false))
	return false


func _build() -> void:
	vw = get_viewport_rect().size
	if vw.x <= 0.0:
		vw = Vector2(720, 1280)
	if anchor_right == 0.0:
		size = vw
	var extra: = maxf(0.0, vw.y - 1280.0 * vw.x / 720.0)
	band_h = 120.0 + minf(extra, 330.0)
	var spare: = maxf(0.0, extra - minf(extra, 330.0))
	payload = V10MjConnectGen.build(level - 1, seed_, big_tiles)
	board = V10MjConnectBoard.new().load_payload(payload)
	var aff: = 1
	if G.get("S") is Dictionary and G.S.has("aff") and G.has_method("aff_level"):
		aff = int(G.aff_level(hero))
	need = int(args.get("need", V10MjConnectUlts.need(aff)))
	sound = V10MjConnectSound.new()
	sound.name = "Sound"
	sound.hero = hero
	sound.mute = bool(args.get("mute", false))
	if args.get("look") is Dictionary and (args.look as Dictionary).has("material"):
		sound.material = String(args.look.material)
	add_child(sound)
	var top: = band_h + 16.0 + spare * 0.5
	var bot: = vw.y - HELP_ZONE - spare * 0.5
	field_rect = Rect2(24.0, top, vw.x - 48.0, bot - top)
	help_rect_v = Rect2(0.0, vw.y - HELP_ZONE, vw.x, HELP_ZONE - 32.0)
	_build_bg()
	_build_field()
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
	if bool(args.get("music", false)) and not demo and ResourceLoader.exists(MUSIC_PATH):
		load(MUSIC_PATH).play("connect")
	if bool(args.get("start_sheet", true)):
		_start_sheet()
	else:
		_start()


func _build_bg() -> void:
	var bg: = TextureRect.new()
	bg.name = "Bg"
	var g: = Gradient.new()
	var acc: Array = V10MjConnectLook.accent(hero)
	g.set_color(0, Color(acc[2]).darkened(0.55).lerp(T.night900, 0.35))
	g.set_color(1, T.night900)
	g.add_point(0.24, T.night800)
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.8, 0.0)
	gt.fill_to = Vector2(0.35, 1.0)
	gt.width = 64
	gt.height = 128
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var th_arg = args.get("table")
	if th_arg is Dictionary and not (th_arg as Dictionary).is_empty() and ResourceLoader.exists(TABLE_VIEW_PATH):
		table_view = load(TABLE_VIEW_PATH).make(self, th_arg, field_rect, field_rect, vw)
	else:
		var felt: = Panel.new()
		felt.name = "Felt"
		var sb: = StyleBoxFlat.new()
		sb.bg_color = T.night800.lerp(acc[2], 0.16)
		sb.set_corner_radius_all(4)
		sb.border_color = V10DS.hair()
		sb.set_border_width_all(1)
		felt.add_theme_stylebox_override("panel", sb)
		felt.position = field_rect.position
		felt.size = field_rect.size
		felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(felt)


func _compute_grid() -> void:
	border_pad = 18.0
	var inner_w: = field_rect.size.x - border_pad * 2.0
	var inner_h: = field_rect.size.y - border_pad * 2.0
	var cw: = floorf(inner_w / float(board.w))
	var ch: = floorf(inner_h / float(board.h))
	var aspect: = clampf(ch / maxf(1.0, cw), 1.18, 1.34)
	if cw * aspect <= ch:
		ch = floorf(cw * aspect)
	else:
		cw = floorf(ch / aspect)
	cw = maxf(48.0, cw)
	ch = maxf(64.0, ch)
	if cw * board.w > inner_w:
		cw = maxf(48.0, inner_w / float(board.w))
	if ch * board.h > inner_h:
		ch = maxf(64.0, inner_h / float(board.h))
	cell_size = Vector2(cw, ch)
	var gw: = cw * board.w
	var gh: = ch * board.h
	grid_origin = field_rect.position + Vector2((field_rect.size.x - gw) * 0.5, (field_rect.size.y - gh) * 0.5)


# Координата центра клетки (включая пустую рамку 0 и w+1 / h+1) в экранных px
func cell_center(c: Vector2i) -> Vector2:
	var x: float
	if c.x <= 0:
		x = maxf(field_rect.position.x + 8.0, grid_origin.x - border_pad * 0.55)
	elif c.x > board.w:
		x = minf(field_rect.end.x - 8.0, grid_origin.x + board.w * cell_size.x + border_pad * 0.55)
	else:
		x = grid_origin.x + (float(c.x) - 0.5) * cell_size.x
	var y: float
	if c.y <= 0:
		y = maxf(field_rect.position.y + 8.0, grid_origin.y - border_pad * 0.55)
	elif c.y > board.h:
		y = minf(field_rect.end.y - 8.0, grid_origin.y + board.h * cell_size.y + border_pad * 0.55)
	else:
		y = grid_origin.y + (float(c.y) - 0.5) * cell_size.y
	return Vector2(x, y)


func _build_field() -> void:
	_compute_grid()
	board_root = Control.new()
	board_root.name = "Board"
	board_root.position = Vector2.ZERO
	board_root.size = vw
	board_root.mouse_filter = Control.MOUSE_FILTER_STOP
	board_root.gui_input.connect(_on_board_input)
	add_child(board_root)
	var tint: = Color.WHITE
	if args.get("look") is Dictionary and (args.look as Dictionary).has("tint"):
		tint = args.look.tint
	var acc: Color = V10MjConnectLook.accent(hero)[0]
	for t in board.n_tiles:
		var tn: = _TileNode.new()
		tn.tid = t
		tn.tile_size = cell_size - Vector2(3.0, 3.0)
		tn.face_tint = tint
		tn.accent = acc
		tn.position = cell_center(board.pos[t]) - tn.tile_size * 0.5
		tn.size = tn.tile_size
		board_root.add_child(tn)
		tile_nodes[t] = tn
	_sync_tiles()
	thread_layer = _ThreadLayer.new()
	thread_layer.name = "ThreadLayer"
	thread_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	thread_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(thread_layer)


func _sync_tiles() -> void:
	var now: = Time.get_ticks_msec() / 1000.0
	var show_all: = now < show_all_until
	for t in board.n_tiles:
		var tn: _TileNode = tile_nodes.get(t)
		if tn == null:
			continue
		tn.visible = board.alive[t] == 1
		if not tn.visible:
			continue
		tn.face = board.face[t]
		tn.lock_left = maxi(0, board.lock[t] - board.removed_pairs)
		tn.iced = board.ice[t] == 1
		tn.is_sel = selected == t
		tn.is_hint = (t in hinted_pair) or (show_all and show_all_ids.has(t))
		tn.queue_redraw()
	if thread_layer:
		var pts: Array[Vector2] = []
		for c in hinted_path:
			pts.append(cell_center(c))
		thread_layer.set_hint(pts, V10MjConnectLook.thread_for(hero).line)


func _build_band() -> void:
	pause_btn = V10MjConnectLook.icon_button("pause", Vector2(12, 18))
	pause_btn.name = "Pause"
	pause_btn.pressed.connect(open_pause)
	add_child(pause_btn)
	left_lbl = V10MjConnectLook.label("", 22, T.paper100, "body", 800)
	left_lbl.position = Vector2(104, 28)
	left_lbl.size = Vector2(360, 32)
	add_child(left_lbl)
	bar = Control.new()
	bar.name = "Bar"
	bar.position = Vector2(104, 70)
	bar.size = Vector2(minf(280.0, vw.x - 290.0), 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var p: = 1.0 - float(board.left()) / maxf(1.0, float(board.n_tiles))
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(T.night600, 0.9))
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * p, bar.size.y)), T.jade300))
	add_child(bar)
	combo_lbl = V10MjConnectLook.label("", 64, T.gold300, "italic", 700)
	V10MjConnectLook.shadow(combo_lbl, 0.65)
	combo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_lbl.size = Vector2(220, 76)
	combo_lbl.pivot_offset = Vector2(110, 38)
	combo_lbl.position = Vector2(24, field_rect.position.y + 4)
	combo_lbl.modulate.a = 0.0
	add_child(combo_lbl)
	banner = V10MjConnectLook.label("", 44, T.paper100, "title", 700)
	V10MjConnectLook.shadow(banner, 0.7)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(vw.x, 60)
	banner.position = Vector2(0, field_rect.get_center().y - 30.0)
	banner.modulate.a = 0.0
	add_child(banner)


func _window_rect() -> Rect2:
	var h: = band_h - 14.0
	var w: = clampf(h * 0.72, 96.0, 280.0)
	if band_h <= 140.0:
		w = 104.0
		h = band_h - 8.0
	return Rect2(vw.x - w - 18.0, band_h - h - 2.0, w, h)


func _build_presence() -> void:
	lite = V10MjConnectPresence.new()
	lite.attach(self, hero, {"fx_min": fx_min, "mode": args.get("hero_mode", "")} if args.has("hero_mode") else {"fx_min": fx_min})
	move_child(lite, fx_layer.get_index())
	lite.layout(Rect2(0, 0, vw.x, band_h), _window_rect())
	lite.portrait_tapped.connect(try_ult)
	lite.finale_done.connect(_after_finale)
	var ext = args.get("presence")
	if ext is String and ext == "stage" and ResourceLoader.exists(STAGE_PATH):
		var stg = load(STAGE_PATH).new()
		ext = stg.attach(self, hero, {"avoid": hud_rects(), "charge_need": need, "band_rect": Rect2(0, 0, vw.x, band_h)})
	presence = ext if ext != null and ext is Object and ext.has_method("on") else lite
	if presence != lite:
		lite.visible = false
		if presence.has_signal("portrait_tapped"):
			presence.connect("portrait_tapped", try_ult)
		if presence.has_signal("finale_done"):
			presence.connect("finale_done", _after_finale)
	for r in sacred_rects():
		lite.sacred(r)
		if presence != lite and presence.has_method("sacred"):
			presence.sacred(r)
	_sync_charge()


func sacred_rects() -> Array[Rect2]:
	var out: Array[Rect2] = [field_rect, help_rect_v]
	return out


func hud_rects() -> Array:
	return [pause_btn.get_global_rect(), Rect2(left_lbl.position, left_lbl.size + Vector2(0, 24))]


func _build_help() -> void:
	var keys: Array = V10MjConnectSave.HELP
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
		b.pivot_offset = Vector2(48, 48)
		b.set_meta("ux_role", "tertiary")
		b.draw.connect(func():
			var c: = Vector2(48, 48)
			b.draw_circle(c, 46.0, T.night700)
			b.draw_arc(c, 46.0, 0, TAU, 48, V10DS.hair(), 1.5, true))
		var ic: = V10MjConnectIcon.new(key, T.gold300)
		ic.position = Vector2(24, 24)
		ic.size = Vector2(48, 48)
		b.add_child(ic)
		root.add_child(b)
		var cap: = V10MjConnectLook.label(V10MjConnectSave.HELP_NAMES[key], 18, T.paper500, "body", 700)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.size = Vector2(160, 26)
		cap.position = Vector2(-20, 102)
		root.add_child(cap)
		b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
		b.pressed.connect(_use_help.bind(key))
		help_btns[key] = b


func _start() -> void:
	time_s = 0.0
	time_left = TIMED_SECS
	ended = false
	paused = false
	if presence == lite:
		lite.on("start", {})
	elif String(payload.get("intro", "")) != "":
		presence.on("mech_intro", {})
	if bool(args.get("instant", false)) or fx_min:
		input_on = true
	else:
		for t in tile_nodes:
			var tn: _TileNode = tile_nodes[t]
			if not tn.visible:
				continue
			tn.modulate.a = 0.0
			var tw: = tn.create_tween()
			tw.tween_interval(0.015 * float(board.pos[t].y + board.pos[t].x % 3))
			tw.tween_property(tn, "modulate:a", 1.0, 0.16)
		get_tree().create_timer(0.32).timeout.connect(func():
			if not ended and not paused:
				input_on = true)
	_show_banner("%s · %d" % [V10MjConnectInfo.INFO.name, level])
	_ensure_move()


func _show_banner(txt: String) -> void:
	banner.text = txt
	if fx_min:
		return
	var tw: = banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.18)
	tw.tween_interval(0.42)
	tw.tween_property(banner, "modulate:a", 0.0, 0.2)


func _process(dt: float) -> void:
	if lite:
		lite.input_on = input_on and not ended and not paused and sheet_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE
	if presence and presence != lite and "input_on" in presence:
		presence.input_on = lite.input_on
	if not input_on or ended or paused:
		return
	time_s += dt
	idle_t += dt
	if idle_t >= 20.0:
		idle_t = 0.0
		presence.on("idle", {})
	if show_all_until > 0.0 and Time.get_ticks_msec() / 1000.0 >= show_all_until:
		show_all_until = 0.0
		show_all_ids.clear()
		_sync_tiles()
	if timed:
		var prev_sec: = int(ceilf(time_left))
		time_left = maxf(0.0, time_left - dt)
		if int(ceilf(time_left)) != prev_sec:
			_refresh()
		if time_left <= 0.0:
			_on_timeout()


func goal_text() -> String:
	if timed:
		var s: = maxi(0, int(ceilf(time_left)))
		return "Осталось %d · %d:%02d" % [board.left(), s / 60, s % 60]
	return "%d · Осталось %d" % [level, board.left()]


func _refresh() -> void:
	if left_lbl == null or board == null:
		return
	left_lbl.text = goal_text()
	bar.queue_redraw()
	_sync_tiles()


func _on_board_input(e: InputEvent) -> void:
	if not input_on or ended or paused or busy:
		return
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		var pos: Vector2 = e.position
		for t in tile_nodes:
			var tn: _TileNode = tile_nodes[t]
			if tn.visible and Rect2(tn.position, tn.size).has_point(pos):
				tap_tile(t)
				return


func tap_tile(t: int) -> bool:
	if not input_on or ended or paused or busy:
		return false
	idle_t = 0.0
	if not board.selectable(t):
		sound.deny()
		var tn0: _TileNode = tile_nodes.get(t)
		if tn0:
			V9Feel.deny(tn0)
		return false
	var gp: = cell_center(board.pos[t])
	presence.on("pick", {"pos": gp})
	if selected < 0:
		selected = t
		sound.pick()
		_sync_tiles()
		return true
	if selected == t:
		selected = -1
		_sync_tiles()
		return true
	var p: = board.path_for(selected, t)
	if p.is_empty():
		if board.face[selected] != board.face[t]:
			selected = t
			sound.pick()
			_sync_tiles()
			return true
		sound.deny()
		selected = t
		_sync_tiles()
		return false
	var a: = selected
	selected = -1
	_take_pair(a, t, p, false)
	return true


func _take_pair(a: int, b: int, path: Array, from_ult: bool) -> void:
	hinted_pair.clear()
	hinted_path.clear()
	var face_id: int = board.face[a]
	var res: = board.remove(a, b, path)
	if res.is_empty():
		return
	moves_count += 1
	var now: = Time.get_ticks_msec() / 1000.0
	pair_times.append(now)
	while pair_times.size() > 0 and now - float(pair_times[0]) > COMBO_WINDOW:
		pair_times.pop_front()
	if pair_times.size() >= 3:
		combo = pair_times.size()
	elif pair_times.size() == 1:
		combo = 1
	else:
		combo = 2
	var motif_mul: = 2 if motif_next else 1
	motif_next = (face_id == last_face)
	last_face = face_id
	score += (20 + 5 * mini(combo, 8)) * motif_mul
	sound.thread_pair(combo)
	var pts: Array[Vector2] = []
	for c in path:
		pts.append(cell_center(c))
	var th_def: = V10MjConnectLook.thread_for(hero)
	var wisp_from: = _presence_center()
	thread_layer.play_thread(pts, th_def.line, th_def.glow, wisp_from, 0.04 if fx_min else 0.25)
	if not from_ult:
		var sig: = face_id == int(V10MjConnectLook.SIGNATURE.get(hero, -1))
		var add: = 1 + (maxi(1, int(round(need * 0.25))) if sig else 0)
		charge = mini(need, charge + add)
		_sync_charge()
		var mid: = (pts[0] + pts[pts.size() - 1]) * 0.5
		presence.on("pair", {"pos": mid, "charge": float(charge) / float(need)})
		if sig:
			presence.on("signature", {})
		if motif_next:
			presence.on("motif", {})
		if combo >= 3:
			_show_combo(combo)
			presence.on("combo", {"n": combo})
	if board.left() == 2:
		presence.on("last_pair", {})
	_animate_moves(res.get("moves", []))
	_refresh()
	if board.left() == 0:
		_on_cleared()
	else:
		_ensure_move()


func _animate_moves(mv: Array) -> void:
	for item in mv:
		var tid: int = item[0]
		var to_c: Vector2i = item[2]
		var tn: _TileNode = tile_nodes.get(tid)
		if tn == null:
			continue
		var target_pos: = cell_center(to_c) - tn.tile_size * 0.5
		if fx_min or bool(args.get("instant", false)):
			tn.position = target_pos
		else:
			var tw: = tn.create_tween()
			tw.tween_property(tn, "position", target_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _ensure_move() -> void:
	if board.left() <= 0 or board.any_move():
		return
	auto_shuffles += 1
	board.shuffle(rng)
	_sync_tiles()
	_show_banner("Ходов нет — перемешала")
	if lite:
		lite.say(V10MjConnectPresence.LINES.shuffle, true)


func _show_combo(n: int) -> void:
	combo_lbl.text = "×%d" % n
	if fx_min:
		combo_lbl.modulate.a = 1.0
		get_tree().create_timer(0.45).timeout.connect(func():
			if is_instance_valid(combo_lbl):
				combo_lbl.modulate.a = 0.0)
		return
	combo_lbl.scale = Vector2(1.18, 1.18)
	combo_lbl.modulate.a = 1.0
	var tw: = combo_lbl.create_tween()
	tw.tween_property(combo_lbl, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.32)
	tw.tween_property(combo_lbl, "modulate:a", 0.0, 0.14)


func _sync_charge() -> void:
	if lite:
		lite.set_charge(float(charge) / maxf(1.0, float(need)), charge >= need)


func _presence_center() -> Vector2:
	if presence and presence.has_method("window_center"):
		return presence.window_center()
	return lite.window_center() if lite else Vector2(vw.x - 70.0, 60.0)


func _use_help(key: String) -> bool:
	if not input_on or ended or paused or busy:
		sound.deny()
		return false
	idle_t = 0.0
	selected = -1
	match key:
		"hint":
			var h: = board.hint()
			if h.is_empty():
				sound.deny()
				return false
			hints_used += 1
			hinted_pair = [int(h.a), int(h.b)]
			hinted_path = h.path
			_sync_tiles()
			return true
		"undo":
			if not board.undo():
				sound.deny()
				return false
			hinted_pair.clear()
			hinted_path.clear()
			for t in board.n_tiles:
				var tn: _TileNode = tile_nodes.get(t)
				if tn:
					tn.position = cell_center(board.pos[t]) - tn.tile_size * 0.5
			_refresh()
			return true
		"shuffle":
			manual_shuffles += 1
			hinted_pair.clear()
			hinted_path.clear()
			board.shuffle(rng)
			_refresh()
			return true
	return false


func try_ult() -> bool:
	if not input_on or ended or paused or busy:
		return false
	if charge < need:
		if lite:
			lite.bounce()
		return false
	var pl: = V10MjConnectUlts.plan(hero, board)
	charge = 0
	ults_used += 1
	_sync_charge()
	presence.on("ult", {"charge": 0.0})
	_show_banner(V10MjConnectUlts.ult_name(hero))
	match String(pl.get("kind", "take")):
		"take":
			var cnt: = int(pl.get("count", 1))
			for k in cnt:
				if board.left() <= 0:
					break
				var mv: = board.moves(1)
				if mv.is_empty():
					board.shuffle(rng)
					mv = board.moves(1)
				if mv.is_empty():
					break
				var p: = board.path_for(int(mv[0][0]), int(mv[0][1]))
				_take_pair(int(mv[0][0]), int(mv[0][1]), p, true)
		"rin_shuffle_hint":
			board.shuffle(rng)
			var h: = board.hint()
			if not h.is_empty():
				hinted_pair = [int(h.a), int(h.b)]
				hinted_path = h.path
			_refresh()
		"show_all":
			show_all_ids.clear()
			for t in pl.get("tiles", []):
				show_all_ids[int(t)] = true
			show_all_until = Time.get_ticks_msec() / 1000.0 + float(pl.get("sec", 3.0))
			_sync_tiles()
		"longest":
			var pr: Array = pl.get("pair", [])
			if pr.size() == 3:
				_take_pair(int(pr[0]), int(pr[1]), pr[2], true)
	return true


func _on_cleared() -> void:
	if ended:
		return
	ended = true
	input_on = false
	sound.win()
	var th_def: = V10MjConnectLook.thread_for(hero)
	thread_layer.weave_emblem(field_rect, String(th_def.kind), th_def.line, th_def.glow, fx_min)
	presence.on("win", {})
	if presence != lite and not presence.has_signal("finale_done"):
		get_tree().create_timer(0.1 if fx_min else 1.2).timeout.connect(_after_finale)


func _on_timeout() -> void:
	if ended:
		return
	ended = true
	input_on = false
	presence.on("lose", {})
	get_tree().create_timer(0.08 if fx_min else 0.9).timeout.connect(_lose_sheet)


func _after_finale() -> void:
	if result.has("action"):
		return
	_finish_result(true)
	if bool(args.get("result_sheet", true)):
		_win_sheet()
	else:
		finished.emit(result)


func _finish_result(win: bool) -> void:
	var sh_total: = manual_shuffles + auto_shuffles
	var par_s: = int(payload.get("par_s", 120))
	var ts: = maxi(1, int(round(time_s)))
	var stars: = V10MjConnectSave.stars_for(win, sh_total, ts, par_s)
	var rec: = {"stars_gain": 0, "salon_stars": 0.0, "first_clear": false, "rank_up": 0, "gifts": [], "gems": 0}
	if not demo and not result.has("record"):
		rec = V10MjConnectSave.record(save_d, level, win, stars, score, ts)
		if G.has_method("save"):
			G.save()
	elif demo:
		rec.first_clear = V10MjConnectSave.stars_of(save_d, level) == 0
	result = {
		"mode": "connect",
		"variant": "timed" if timed else board.variant,
		"win": win,
		"score": score if win else 0,
		"stars": stars,
		"time_s": ts,
		"pairs": board.removed_pairs,
		"moves": moves_count,
		"hints": hints_used,
		"shuffles": manual_shuffles,
		"auto_shuffles": auto_shuffles,
		"ults": ults_used,
		"hero": hero,
		"seed": seed_,
		"level": level,
		"rewards": V10MjConnectSave.rewards(level, win, bool(rec.first_clear), int(rec.gems)),
		"salon_stars": float(rec.salon_stars),
		"stars_gain": int(rec.stars_gain),
		"rank_up": int(rec.rank_up),
		"gifts": rec.gifts,
		"record": rec,
	}


# ── Листы ───────────────────────────────────────────────────────────────────

func _stars_row(n: int, sz: = 44.0) -> Control:
	var row: = Control.new()
	row.size = Vector2(3 * (sz + 10.0), sz)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in 3:
		var ic: = V10MjConnectIcon.new("star", T.gold300 if k < n else Color(T.paper700, 0.55))
		ic.size = Vector2(sz, sz)
		ic.position = Vector2(k * (sz + 10.0), 0)
		row.add_child(ic)
	return row


func _start_sheet() -> void:
	input_on = false
	var L: = V10MjConnectGen.level(level - 1)
	var p: = V10MjConnectLook.sheet(sheet_layer, vw, 480.0, fx_min)
	var over: = V10MjConnectLook.label("СВЯЗИ · ГЛАВА %d" % (int(L.chapter) + 1), 15, T.gold500, "body", 900)
	over.position = Vector2(32, 30)
	p.add_child(over)
	var h1: = V10MjConnectLook.label("Уровень %d" % level, 44, T.paper100, "title", 700)
	h1.position = Vector2(32, 56)
	p.add_child(h1)
	var vname: String = V10MjConnectInfo.VARIANT_NAMES.get("timed" if timed else String(L.variant), "Поле")
	var sub: = V10MjConnectLook.label("%s · %s" % [String(L.tier_name), vname], 18, T.paper500, "body", 700)
	sub.position = Vector2(34, 118)
	p.add_child(sub)
	var sr: = _stars_row(V10MjConnectSave.stars_of(save_d, level), 32.0)
	sr.position = Vector2(vw.x - 116.0 - sr.size.x, 68)
	p.add_child(sr)
	var help_b: = V10MjConnectLook.icon_button("help", Vector2(vw.x - 96.0, 20.0))
	help_b.name = "HelpBtn"
	help_b.pressed.connect(func(): _help_sheet(true))
	p.add_child(help_b)
	var th_def: = V10MjConnectLook.thread_for(hero)
	var row: = Control.new()
	row.position = Vector2(24, 168)
	row.size = Vector2(vw.x - 48.0, 80)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.draw.connect(func():
		row.draw_rect(Rect2(Vector2.ZERO, row.size), T.night800)
		row.draw_line(Vector2(12, 0), Vector2(row.size.x - 12, 0), V10DS.hair(), 1.0))
	p.add_child(row)
	var ic: = V10MjConnectIcon.new("thread", th_def.line)
	ic.position = Vector2(16, 16)
	row.add_child(ic)
	var t1: = V10MjConnectLook.label(String(th_def.name), 22, T.paper100, "body", 800)
	t1.position = Vector2(80, 12)
	row.add_child(t1)
	var t2: = V10MjConnectLook.label(V10MjConnectInfo.INFO.line, 18, T.paper500, "body", 700)
	t2.position = Vector2(80, 44)
	row.add_child(t2)
	var play: = V10MjConnectLook.primary("Играть", 560.0, fx_min)
	play.name = "Play"
	play.position = Vector2(vw.x * 0.5 - 280.0, 480.0 - 136.0)
	play.pressed.connect(func():
		V10MjConnectLook.close_sheet(sheet_layer)
		_start())
	p.add_child(play)


func open_help() -> void:
	_help_sheet(false)


func _help_sheet(from_start: bool) -> void:
	var was: = input_on
	input_on = false
	var p: = V10MjConnectLook.sheet(sheet_layer, vw, 520.0, fx_min)
	var h: = V10MjConnectLook.label("Как играть", 32, T.paper100, "title", 600)
	h.position = Vector2(32, 28)
	p.add_child(h)
	for k in V10MjConnectInfo.HOW.size():
		var row: Array = V10MjConnectInfo.HOW[k]
		var ic: = V10MjConnectIcon.new(row[0], T.gold300)
		ic.position = Vector2(32, 90 + k * 66)
		ic.size = Vector2(44, 44)
		p.add_child(ic)
		var l: = V10MjConnectLook.label(row[1], 20, T.paper300, "body", 700)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = Vector2(92, 92 + k * 66)
		l.size = Vector2(vw.x - 124, 56)
		p.add_child(l)
	for s_i in V10MjConnectInfo.STARS_HOW.size():
		var sl: = V10MjConnectLook.label(V10MjConnectInfo.STARS_HOW[s_i], 18, T.paper500, "body", 700)
		sl.position = Vector2(32, 294 + s_i * 26)
		p.add_child(sl)
	var ok_b: = V10MjConnectLook.primary("Понятно", 560.0, fx_min)
	ok_b.name = "OkBtn"
	ok_b.position = Vector2(vw.x * 0.5 - 280.0, 520.0 - 128.0)
	ok_b.pressed.connect(func():
		if from_start:
			_start_sheet()
		else:
			V10MjConnectLook.close_sheet(sheet_layer)
			input_on = was)
	p.add_child(ok_b)


func open_pause() -> void:
	if ended or sheet_layer.mouse_filter == Control.MOUSE_FILTER_STOP:
		return
	var was: = input_on
	paused = true
	input_on = false
	var p: = V10MjConnectLook.sheet(sheet_layer, vw, 580.0, fx_min)
	var h: = V10MjConnectLook.label("Пауза", 32, T.paper100, "title", 600)
	h.position = Vector2(32, 28)
	p.add_child(h)
	for k in V10MjConnectInfo.HOW.size():
		var row: Array = V10MjConnectInfo.HOW[k]
		var ic: = V10MjConnectIcon.new(row[0], T.gold300)
		ic.position = Vector2(32, 90 + k * 60)
		ic.size = Vector2(44, 44)
		p.add_child(ic)
		var l: = V10MjConnectLook.label(row[1], 18, T.paper300, "body", 700)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = Vector2(92, 92 + k * 60)
		l.size = Vector2(vw.x - 124, 52)
		p.add_child(l)
	var go_on: = V10MjConnectLook.primary("Продолжить", 560.0, fx_min)
	go_on.name = "Resume"
	go_on.position = Vector2(vw.x * 0.5 - 280.0, 310.0)
	go_on.pressed.connect(func():
		V10MjConnectLook.close_sheet(sheet_layer)
		paused = false
		input_on = was)
	p.add_child(go_on)
	var retry: = V10MjConnectLook.secondary("Заново", 260.0, false)
	retry.position = Vector2(vw.x * 0.5 - 270.0, 444.0)
	retry.pressed.connect(func():
		V10MjConnectLook.close_sheet(sheet_layer)
		ended = true
		_finish_result(false)
		result["action"] = "retry"
		finished.emit(result))
	p.add_child(retry)
	var quit: = V10MjConnectLook.secondary("Выйти", 260.0, true)
	quit.position = Vector2(vw.x * 0.5 + 10.0, 444.0)
	quit.pressed.connect(func():
		V10MjConnectLook.close_sheet(sheet_layer)
		ended = true
		_finish_result(false)
		result["action"] = "exit"
		finished.emit(result))
	p.add_child(quit)


func _lose_sheet() -> void:
	var p: = V10MjConnectLook.sheet(sheet_layer, vw, 430.0, fx_min)
	var h: = V10MjConnectLook.label("Почти!", 44, T.paper100, "title", 700)
	h.position = Vector2(32, 36)
	p.add_child(h)
	var c: = V10MjConnectLook.label("Время вышло. Осталось %d фишек" % board.left(), 22, T.paper300, "body", 700)
	c.position = Vector2(34, 104)
	p.add_child(c)
	var prim: = V10MjConnectLook.primary("Ещё раз", 560.0, fx_min)
	prim.name = "Primary"
	prim.position = Vector2(vw.x * 0.5 - 280.0, 190)
	prim.pressed.connect(func():
		V10MjConnectLook.close_sheet(sheet_layer)
		_finish_result(false)
		result["action"] = "retry"
		finished.emit(result))
	p.add_child(prim)
	var sec: = V10MjConnectLook.secondary("В Столы")
	sec.position = Vector2(vw.x * 0.5 - 160.0, 318)
	sec.pressed.connect(func():
		V10MjConnectLook.close_sheet(sheet_layer)
		_finish_result(false)
		result["action"] = "exit"
		finished.emit(result))
	p.add_child(sec)


func _win_sheet() -> void:
	if lite:
		lite.hide_finale()
	var p: = V10MjConnectLook.sheet(sheet_layer, vw, 580.0, fx_min)
	var h: = V10MjConnectLook.label("Стол чист", 64, T.paper100, "title", 700)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.size = Vector2(vw.x, 78)
	h.position = Vector2(0, 24)
	p.add_child(h)
	var sr: = _stars_row(int(result.get("stars", 0)), 52.0)
	sr.position = Vector2(vw.x * 0.5 - sr.size.x * 0.5, 118)
	p.add_child(sr)
	var sc: = V10MjConnectLook.label("%d очков · %d:%02d" % [int(result.score), int(result.time_s) / 60, int(result.time_s) % 60], 22, T.paper300, "body", 800)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sc.size = Vector2(vw.x, 32)
	sc.position = Vector2(0, 186)
	p.add_child(sc)
	var rw: Dictionary = result.get("rewards", {})
	var tokens: = []
	if int(rw.get("coins", 0)) > 0:
		tokens.append("+%d монет" % int(rw.coins))
	if int(rw.get("aff", 0)) > 0:
		tokens.append("+%d симпатии" % int(rw.aff))
	if int(rw.get("gems", 0)) > 0:
		tokens.append("+%d кристаллов" % int(rw.gems))
	elif float(result.get("salon_stars", 0.0)) > 0.0:
		tokens.append("+%s в Салон" % str(snappedf(float(result.salon_stars), 0.5)).trim_suffix(".0"))
	var tx: = vw.x * 0.5 - tokens.size() * 100.0
	for k in tokens.size():
		var tl: = V10MjConnectLook.label(tokens[k], 18, T.gold300, "body", 800)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.size = Vector2(196, 28)
		tl.position = Vector2(tx + k * 200.0, 232)
		p.add_child(tl)
	var pr: = V10MjConnectSave.rank_progress(save_d)
	var ml: = V10MjConnectLook.label("%s · %d из %d ★" % [V10MjConnectSave.rank_text(int(pr.rank)), int(pr.have), int(pr.need)], 18, T.paper500, "body", 700)
	ml.position = Vector2(40, 274)
	p.add_child(ml)
	var mb: = Control.new()
	mb.position = Vector2(40, 304)
	mb.size = Vector2(vw.x - 80.0, 6)
	mb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kk: = clampf(float(pr.have) / maxf(1.0, float(pr.need)), 0.0, 1.0)
	mb.draw.connect(func():
		mb.draw_rect(Rect2(Vector2.ZERO, mb.size), T.night600)
		mb.draw_rect(Rect2(Vector2.ZERO, Vector2(mb.size.x * kk, mb.size.y)), T.gold500))
	p.add_child(mb)
	var nxt: = mini(level + 1, V10MjConnectGen.COUNT)
	var prim: = V10MjConnectLook.primary("Ещё уровень · %d" % nxt, 560.0, fx_min)
	prim.name = "Primary"
	prim.position = Vector2(vw.x * 0.5 - 280.0, 336)
	prim.pressed.connect(func():
		result["action"] = "next"
		finished.emit(result))
	p.add_child(prim)
	var sec: = V10MjConnectLook.secondary("В Столы")
	sec.position = Vector2(vw.x * 0.5 - 160.0, 464)
	sec.pressed.connect(func():
		result["action"] = "exit"
		finished.emit(result))
	p.add_child(sec)


func tappables() -> Array:
	var out: Array = [pause_btn]
	for k in help_btns:
		out.append(help_btns[k])
	out.append("hero_window")
	return out


func words_in_play() -> int:
	var n: = 0
	for w in goal_text().split(" ", false):
		if not w.is_valid_int() and w != "·" and not (":" in w):
			n += 1
	for k in V10MjConnectSave.HELP:
		n += String(V10MjConnectSave.HELP_NAMES[k]).split(" ", false).size()
	return n


# ── Внутренние узлы фишки и нити ────────────────────────────────────────────

class _TileNode:
	extends Control
	var tid: = 0
	var face: = 0
	var tile_size: = Vector2(52, 66)
	var face_tint: = Color.WHITE
	var accent: = V10DS.HEROES.rin.accent
	var lock_left: = 0
	var iced: = false
	var is_sel: = false
	var is_hint: = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var lift: = Vector2(0, -4) if is_sel else Vector2.ZERO
		var r: = Rect2(lift, tile_size)
		# кромка 2 слоя (MODES §4.3)
		var base2: = StyleBoxFlat.new()
		base2.bg_color = V10DS.NIGHT_600
		base2.set_corner_radius_all(6)
		draw_style_box(base2, Rect2(r.position + Vector2(0, 4), r.size))
		var base1: = StyleBoxFlat.new()
		base1.bg_color = V10DS.GOLD_700.lerp(V10DS.PAPER_500, 0.45)
		base1.set_corner_radius_all(6)
		draw_style_box(base1, Rect2(r.position + Vector2(0, 2), r.size))
		var top_sb: = StyleBoxFlat.new()
		top_sb.bg_color = Color("#F7EFE2") * face_tint
		top_sb.set_corner_radius_all(6)
		top_sb.border_color = accent if is_sel else (V10DS.GOLD_300 if is_hint else Color(V10DS.GOLD_700, 0.45))
		top_sb.set_border_width_all(3 if (is_sel or is_hint) else 1)
		draw_style_box(top_sb, r)
		var tree: = Engine.get_main_loop() as SceneTree
		var g = tree.root.get_node_or_null("G") if tree and tree.root else null
		if g and g.has_method("tile_tex"):
			var tex: Texture2D = g.tile_tex(face)
			if tex:
				var pad: = r.size * 0.08
				draw_texture_rect(tex, Rect2(r.position + pad, r.size - pad * 2.0), false)
		if iced:
			draw_rect(r, Color(V10DS.HEROES.nova.glow, 0.34), true)
			draw_rect(r.grow(-2.0), Color(V10DS.HEROES.nova.accent, 0.85), false, 2.0)
		if lock_left > 0:
			draw_rect(r, Color(V10DS.NIGHT_900, 0.56), true)
			for gx in [0.33, 0.66]:
				draw_line(r.position + Vector2(r.size.x * gx, 4), r.position + Vector2(r.size.x * gx, r.size.y - 4), Color(V10DS.GOLD_500, 0.65), 1.5)
			for gy in [0.33, 0.66]:
				draw_line(r.position + Vector2(4, r.size.y * gy), r.position + Vector2(r.size.x - 4, r.size.y * gy), Color(V10DS.GOLD_500, 0.65), 1.5)
			var f: = UI.font("body", 900)
			var s: = str(lock_left)
			draw_circle(r.get_center(), 12.0, V10DS.NIGHT_800)
			draw_string(f, r.get_center() + Vector2(-5, 6), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, V10DS.GOLD_300)


class _ThreadLayer:
	extends Control
	var active_threads: Array = []   # [{pts, line, glow, wisp, a}]
	var hint_pts: Array[Vector2] = []
	var hint_col: = V10DS.GOLD_300
	var emblem: = {}                 # {rect, kind, line, glow, a}

	func set_hint(pts: Array[Vector2], col: Color) -> void:
		hint_pts = pts
		hint_col = col
		queue_redraw()

	func play_thread(pts: Array[Vector2], line_c: Color, glow_c: Color, wisp_from: Vector2, dur: float) -> void:
		var d: = {"pts": pts, "line": line_c, "glow": glow_c, "wisp": wisp_from, "a": 1.0}
		active_threads.append(d)
		queue_redraw()
		var tw: = create_tween()
		tw.tween_method(func(v: float):
			d.a = v
			queue_redraw(), 1.0, 0.0, dur)
		tw.tween_callback(func():
			active_threads.erase(d)
			queue_redraw())

	func weave_emblem(r: Rect2, kind: String, line_c: Color, glow_c: Color, fx_min: bool) -> void:
		emblem = {"rect": r, "kind": kind, "line": line_c, "glow": glow_c, "a": 1.0 if fx_min else 0.0}
		queue_redraw()
		if fx_min:
			return
		var tw: = create_tween()
		tw.tween_method(func(v: float):
			emblem.a = v
			queue_redraw(), 0.0, 1.0, 0.35)
		tw.tween_interval(0.55)
		tw.tween_method(func(v: float):
			emblem.a = v
			queue_redraw(), 1.0, 0.0, 0.25)

	func _draw() -> void:
		if hint_pts.size() >= 2:
			for i in range(1, hint_pts.size()):
				var a: Vector2 = hint_pts[i - 1]
				var b: Vector2 = hint_pts[i]
				var dist: = a.distance_to(b)
				var dir: = (b - a) / maxf(1.0, dist)
				var d0: = 0.0
				while d0 < dist:
					draw_line(a + dir * d0, a + dir * minf(d0 + 8.0, dist), Color(hint_col, 0.85), 3.0, true)
					d0 += 16.0
		for t in active_threads:
			var pts: PackedVector2Array = PackedVector2Array(t.pts)
			var a: float = float(t.a)
			if pts.size() >= 2:
				draw_polyline(pts, Color(t.glow, 0.38 * a), 12.0, true)
				draw_polyline(pts, Color(t.line, 0.95 * a), 4.5, true)
				draw_circle(pts[0], 6.0, Color(t.glow, 0.9 * a))
				draw_circle(pts[pts.size() - 1], 6.0, Color(t.glow, 0.9 * a))
		if not emblem.is_empty() and float(emblem.get("a", 0.0)) > 0.01:
			var r: Rect2 = emblem.rect
			var c: = r.get_center()
			var rad: = minf(r.size.x, r.size.y) * 0.26
			var ea: float = emblem.a
			var pts2: = PackedVector2Array()
			for k in 9:
				var ang: = -PI * 0.5 + TAU * float(k) / 8.0
				var rk: = rad if k % 2 == 0 else rad * 0.48
				pts2.append(c + Vector2(cos(ang), sin(ang)) * rk)
			draw_polyline(pts2, Color(emblem.glow, 0.35 * ea), 10.0, true)
			draw_polyline(pts2, Color(emblem.line, 0.9 * ea), 3.5, true)
