extends Control

# stage_demo — a dummy match (TrayBoard 6×8, tray 4, help row) with a bot that plays and sends the presence
# events, laid out by the common match frame of docs/MODES.md §4 (band 0–120 + extra height, tray 120–300,
# field 300…H−186, help H−186…H−40). It is the integration example too: see _build() and _wire().
#
#   godot --path game res://scripts/v10/mj/stage/stage_demo.tscn -- [--hero=mc] [--mode=live|quiet|finish_only]
#         [--fx=full|mid|min] [--shots=<dir>]   --shots: 720×1280 and 1080×2400 runs save <W>x<H>_<moment>.png at
#         pair, combo5, danger, wave, win (run once per --resolution), print the sacred-zone audit and quit.

const BAND_H: = 120.0
const TRAY_H: = 180.0
const HELP_H: = 146.0
const BOTTOM: = 40.0

var hero: = "mc"
var board: TrayBoard
var presence: V10MjPresence
var shots: = ""
var tray_rect: = Rect2()
var field_rect: = Rect2()
var help_rect: = Rect2()
var slot_rects: Array = []
var hud_rects: Array = []
var left_lbl: Label
var _clock_off: = 0.0
var _danger: = false
var audit_bad: = 0


func _ready() -> void:
	var mode: = "live"
	var fx: = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hero="):
			hero = a.substr(7)
		elif a.begins_with("--mode="):
			mode = a.substr(7)
		elif a.begins_with("--fx="):
			fx = a.substr(5)
		elif a.begins_with("--shots="):
			shots = a.substr(8)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	var o: = {"mode": mode, "avoid": hud_rects, "board": board, "seed": 11,
		"clock": func(): return Time.get_ticks_msec() / 1000.0 + _clock_off}
	if fx != "":
		o["fx"] = fx
	presence = V10MjPresence.new().attach(self, hero, o)
	presence.sacred(field_rect)
	presence.sacred(tray_rect)
	presence.sacred(help_rect)
	_wire()
	board.deal()
	_bot()


func _build() -> void:
	var S: = get_viewport_rect().size
	var extra: = maxf(0.0, S.y - S.x * 16.0 / 9.0)
	var bg: = TextureRect.new()
	bg.texture = load("res://assets/bg/bg_teahouse.webp") if ResourceLoader.exists("res://assets/bg/bg_teahouse.webp") \
		else load("res://assets/bg/bg_palace_blur.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.42, 0.38, 0.45)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var top: = BAND_H + extra
	tray_rect = Rect2(24, top, S.x - 48, TRAY_H)
	help_rect = Rect2(0, S.y - HELP_H - BOTTOM, S.x, HELP_H)
	field_rect = Rect2(8, tray_rect.end.y, S.x - 16, help_rect.position.y - tray_rect.end.y)
	# band backdrop: the host's strip (night 900 → transparent), its pause and «1-2 · Осталось N»
	var strip: = ColorRect.new()
	strip.color = Color(V10MjStageData.TOK.night900, 0.72)
	strip.position = Vector2.ZERO
	strip.size = Vector2(S.x, top)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	var pause: = Button.new()
	pause.text = "❚❚"
	pause.flat = true
	pause.position = Vector2(12, top - 100)
	pause.size = Vector2(80, 80)
	pause.add_theme_font_size_override("font_size", 26)
	pause.add_theme_color_override("font_color", V10MjStageData.TOK.paper300)
	add_child(pause)
	left_lbl = Label.new()
	left_lbl.position = Vector2(96, top - 84)
	left_lbl.size = Vector2(250, 36)
	left_lbl.add_theme_font_size_override("font_size", 22)
	left_lbl.add_theme_color_override("font_color", V10MjStageData.TOK.paper100)
	add_child(left_lbl)
	hud_rects = [Rect2(pause.position, pause.size), Rect2(96, top - 88, 250, 56)]
	# tray: 4 slots
	var tray_bg: = _Panel.new()
	tray_bg.position = tray_rect.position + Vector2(40, 34)
	tray_bg.size = Vector2(tray_rect.size.x - 80, tray_rect.size.y - 68)
	add_child(tray_bg)
	slot_rects.clear()
	var sw: = (tray_bg.size.x - 40) / 4.0
	for i in 4:
		var r: = Rect2(tray_bg.position + Vector2(20 + sw * i + 6, 12), Vector2(sw - 12, tray_bg.size.y - 24))
		slot_rects.append(r)
		var sl: = _Panel.new()
		sl.slot = true
		sl.position = r.position
		sl.size = r.size
		add_child(sl)
	# help row: three circles with a number (Подсказка, Отмена, Перемешать)
	var names: = ["Подсказка", "Отмена", "Перемешать"]
	for i in 3:
		var c: = _Help.new()
		c.title = names[i]
		c.num = [3, 2, 1][i]
		c.position = Vector2(S.x * (0.22 + 0.28 * i) - 48, help_rect.position.y + 10)
		c.size = Vector2(96, 126)
		add_child(c)
	board = TrayBoard.new()
	board.slots = 4
	add_child(board)
	board.setup({"cols": 6, "rows": 8, "layers": 2, "faces": 12, "shape": "rect", "seed": 7, "fill": 0.55, "gold": 0})
	board.fit_into(field_rect)
	board.slot_pos.clear()
	for r in slot_rects:
		board.slot_pos.append((r as Rect2).get_center())
	board.slot_size = (slot_rects[0] as Rect2).size.x * 0.92
	_left()


func _left() -> void:
	left_lbl.text = "1-2 · Осталось %d" % board.board_count()


# the five integration points (what play.gd does through V10Rules): pick, pair, overflow (danger), end, wave
func _wire() -> void:
	board.matched.connect(func(mid: Vector2, combo: int, _gold, _shard):
		presence.on("pair", {"pos": mid})
		if combo >= 3:
			presence.on("combo", {"n": combo})
		_left()
		if board.board_count() == 2:
			presence.on("last_pair"))
	board.tray_changed.connect(func():
		var near: = board.tray.size() >= board.slots - 1
		if near != _danger:
			_danger = near
			presence.on("danger", {"on": near})
		_left())
	board.cleared.connect(func(): presence.on("win"))
	board.failed.connect(func(): presence.on("lose"))


func tap(t: Tile) -> void:
	presence.on("pick", {"pos": t.get_global_transform_with_canvas().origin})
	board.tap(t)


# V6Fx (0.6 autoload) tints the WHOLE screen red when a tray is nearly full; MODES §3.2 wants a warm screen
# edge, not a red field. The presence draws that edge, so the integrator turns the 0.6 tint off for screens with
# a presence (README «Хуки», V6Fx). The demo does the same by hand.
func _quiet_v6_tint() -> void:
	var v6 = get_tree().root.get_node_or_null("V6Fx")
	if v6 and v6.has_method("set_danger"):
		v6.set_danger(false)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(moment: String) -> void:
	var bad: = presence.sacred_hits()
	audit_bad += bad.size() if presence.is_input_on() else 0
	print("STAGE_DEMO shot %s input_on=%s hits=%d motes=%d text='%s'" % [moment, presence.is_input_on(), bad.size(),
		presence.trail.alive(), presence.barks.last_text if presence.barks.is_showing() else ""])
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shots)
	var S: = DisplayServer.window_get_size()
	img.save_png("%s/%dx%d_%s.png" % [shots, S.x, S.y, moment])


func _next_beat() -> void:
	# the budget's clock jumps 30 s between scripted beats, so each beat may speak (as in a real match)
	_clock_off += 30.0


func _pair_move() -> bool:
	var t: = board.solver_move()
	if t == null:
		t = board.best_move()
	if t == null:
		return false
	tap(t)
	return true


func _bot() -> void:
	while not board.input_on:
		await _wait(0.1)
	await _wait(0.6)
	# beat 1: a pair (two taps of twins); shot while the motes fly to her window
	_next_beat()
	var guard: = 0
	var pairs0: = board.board_count()
	while board.board_count() == pairs0 and guard < 12:
		_pair_move()
		guard += 1
		for k in 8:
			if presence.trail.alive() > 0:
				break
			await _wait(0.04)
		if presence.trail.alive() > 0:
			break
	# the motes are in the air, half-way to her window
	await _wait(0.14)
	await _shot("pair")
	await _wait(0.9)
	# beat 2: a run of pairs → ×5
	_next_beat()
	for i in 4:
		var before: = board.board_count()
		guard = 0
		while board.board_count() == before and guard < 10:
			_pair_move()
			guard += 1
			await _wait(0.22)
	presence.on("combo", {"n": 5})
	await _wait(0.6)
	await _shot("combo5")
	await _wait(1.0)
	# beat 3: danger — three free tiles of different faces in the tray (no twin), then take them back
	_next_beat()
	var used: = {}
	for t in board.free_tiles():
		if board.tray.size() >= board.slots - 1:
			break
		if used.has(t.face) or board.tray.any(func(x): return x.face == t.face):
			continue
		if board.free_tiles().filter(func(o): return o != t and o.face == t.face).size() > 0:
			continue
		used[t.face] = true
		tap(t)
		await _wait(0.25)
	await _wait(0.6)
	_quiet_v6_tint()
	await _wait(0.4)
	await _shot("danger")
	board.return_tray(3)
	await _wait(0.6)
	# beat 4: a wave (new tiles) — she steps out from behind the table's top edge
	_next_beat()
	presence.on("wave", {"wave": 2})
	await _wait(0.55)
	await _shot("wave")
	await _wait(1.6)
	# beat 5: the table is clear
	_next_beat()
	board.input_on = false
	for t in board.tiles:
		t.alive = false
		t.hide()
	for t in board.tray:
		t.hide()
	board.tray.clear()
	_left()
	presence.on("win")
	await _wait(0.6)
	await _shot("win")
	await _wait(2.0)
	print("STAGE_DEMO done audit_bad=%d voice=%d peek=%d" % [audit_bad, presence.counts.voice, presence.counts.peek])
	if shots != "":
		get_tree().quit(0 if audit_bad == 0 else 1)


class _Panel extends Control:
	var slot: = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color(V10MjStageData.TOK.night800, 0.86) if not slot else Color(V10MjStageData.TOK.night600, 0.7)
		sb.set_corner_radius_all(12 if not slot else 10)
		sb.border_color = Color(V10MjStageData.TOK.gold700, 0.35)
		sb.set_border_width_all(1)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))


class _Help extends Control:
	var title: = ""
	var num: = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: = Vector2(size.x * 0.5, 44)
		draw_circle(c, 40, Color(V10MjStageData.TOK.night700, 0.92))
		draw_arc(c, 40, 0, TAU, 48, Color(V10MjStageData.TOK.gold700, 0.5), 1.5, true)
		var f: = ThemeDB.fallback_font
		draw_string(f, Vector2(0, 54), str(num), HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, V10MjStageData.TOK.gold300)
		draw_string(f, Vector2(-20, 112), title, HORIZONTAL_ALIGNMENT_CENTER, size.x + 40, 18, V10MjStageData.TOK.paper300)
