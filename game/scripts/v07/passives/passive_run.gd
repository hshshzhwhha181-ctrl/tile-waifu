class_name V7PassiveRun
extends Control





var play
var h: = "mc"
var d: Dictionary
var col: = Color.WHITE
var board: TrayBoard
var overlay: Node2D
var chip: Control
var chip_val: Label
var ring
var pairs: = 0
var cups: = 1
var hacked: Array = []
var seen_tray: Array = []
var dealt: = false
var relays: = 0
var since_relay: = 1
var auto: = false
var _auto_cd: = 1.0
var _poked: = false

class Overlay extends Node2D:
	var run
	func _brackets(r: Rect2, c: Color, w: float, l: float) -> void :
		for cx in [0, 1]:
			for cy in [0, 1]:
				var p: = r.position + Vector2(r.size.x * cx, r.size.y * cy)
				var sx: = 1.0 if cx == 0 else -1.0
				var sy: = 1.0 if cy == 0 else -1.0
				draw_line(p, p + Vector2(l * sx, 0), c, w)
				draw_line(p, p + Vector2(0, l * sy), c, w)
	func _draw() -> void :
		if run == null or run.board == null:
			return
		var b: TrayBoard = run.board
		var t0: float = G.time
		var sz: = Vector2(Tile.TW, Tile.TH)
		if run.h == "nova":
			var a: = 0.7 + 0.3 * sin(t0 * 6.0)
			var cy: = Color(0.3, 0.95, 1.0)
			for t in run.hacked:
				if is_instance_valid(t) and b.on_board(t) and not t.pending:
					var r: = Rect2(t.position - sz * 0.5 - Vector2(4, 4), sz + Vector2(8, 8))
					draw_rect(r.grow(8), Color(cy, a * 0.18), true)
					draw_rect(r, Color(cy, a * 0.22), true)
					var sl: = fmod(t0 * 60.0, r.size.y)
					draw_line(r.position + Vector2(0, sl), r.position + Vector2(r.size.x, sl), Color(cy, 0.6), 2.0)
					draw_rect(r, Color(cy, a), false, 3.0)
					_brackets(r.grow(7), Color(0.85, 1.0, 1.0, a), 5.0, 16.0)
					var c: = r.position + Vector2(r.size.x, 0)
					draw_circle(c, 13.0, Color(0.05, 0.25, 0.32))
					draw_circle(c, 11.0, cy)
					draw_line(c + Vector2(-5, 4), c + Vector2(5, 4), Color(0.05, 0.2, 0.3), 3.0)
					draw_arc(c + Vector2(-2, 0), 4.5, PI, TAU, 10, Color(0.05, 0.2, 0.3), 2.5)
		elif run.h == "yue":
			var a: = 0.75 + 0.25 * sin(t0 * 3.2)
			var want: = {}
			for x in b.tray:
				if not x.pending:
					want[x.face] = true
			if want.is_empty():
				return
			var mc: = Color(0.72, 0.84, 1.0)
			for t in b.tiles:
				if want.has(t.face) and b.on_board(t) and not t.pending:
					var r: = Rect2(t.position - sz * 0.5 - Vector2(3, 3), sz + Vector2(6, 6))
					draw_rect(r.grow(9), Color(mc, a * 0.22), true)
					draw_rect(r, Color(mc, a * 0.2), true)
					draw_rect(r.grow(4), Color(mc, a * 0.45), false, 4.0)
					draw_rect(r, Color(0.92, 0.96, 1.0, a), false, 4.0)
					var c: = r.position + Vector2(r.size.x, 0)
					draw_circle(c, 14.0, Color(0.14, 0.2, 0.45))
					draw_circle(c, 9.0, Color(1, 0.98, 0.88))
					draw_circle(c + Vector2(4.0, -3.0), 8.0, Color(0.14, 0.2, 0.45))

func setup(p) -> void :
	play = p
	h = String(p.partner)
	d = V7Passives.info(h)
	col = d.col
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2.ZERO
	auto = "--passives_auto=1" in OS.get_cmdline_user_args()
	_build_chip()
	_bind()
	_log("start partner=%s style=%s slots=%d hidden=%s ice=%s layers=%s" % [h, d.name, board.slots, p.cfg.get("hidden", false), p.cfg.get("ice", 0), p.cfg.get("layers", 0)])

func _log(s: String) -> void :
	if auto:
		print("PASSIVE %s" % s)


class Ring extends Control:

	var col: = Color.WHITE
	var frac: = 0.0
	var dots: = 0
	var lit: = 0
	var glow: = 0.0
	func _draw() -> void :
		var c: = size * 0.5
		var r: = size.x * 0.5 - 3.0
		draw_circle(c, r + 2.0, Color(0.07, 0.04, 0.12, 0.92))
		draw_arc(c, r, 0.0, TAU, 40, Color(0, 0, 0, 0.5), 5.0)
		if frac > 0.0:
			draw_arc(c, r, - PI * 0.5, - PI * 0.5 + TAU * frac, 40, col.lightened(0.3), 5.0)
		if glow > 0.0:
			draw_arc(c, r + 3.0, 0.0, TAU, 40, Color(col.lightened(0.5), glow), 3.0)
		for i in dots:
			var a: = PI * 0.5 + (float(i) - (dots - 1) * 0.5) * 0.42
			var p: = c + Vector2(cos(a), sin(a)) * (r + 1.0)
			draw_circle(p, 6.5, Color(0.07, 0.04, 0.12))
			draw_circle(p, 4.5, col.lightened(0.45) if i < lit else Color(0.3, 0.28, 0.35))



func _build_chip() -> void :
	var r: = Rect2(404, 120, 54, 54)
	chip = Control.new()
	chip.position = r.position
	chip.size = r.size
	chip.pivot_offset = r.size * 0.5
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.tooltip_text = d.name
	add_child(chip)
	ring = Ring.new()
	ring.col = col
	ring.size = r.size
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.dots = {"rin": V7Passives.RIN_MAX}.get(h, 0)
	chip.add_child(ring)
	var av: = Common.avatar(h, Rect2(6, 6, r.size.x - 12, r.size.y - 12), "gold")
	chip.add_child(av)
	chip_val = UI.label("", 16, Color.WHITE, col.darkened(0.6), 4, "body", 900)
	chip_val.position = Vector2(r.size.x - 22, -8)
	chip_val.size = Vector2(30, 22)
	chip_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(chip_val)
	# 0.8: 64×64 touch target around the 54 px badge (the badge art keeps its size)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hit: = Control.new()
	hit.name = "Hit"
	hit.position = Vector2(-5, -6)
	hit.size = Vector2(64, 64)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.tooltip_text = d.name
	chip.add_child(hit)
	hit.gui_input.connect( func(e):
		# left press only (a tap also arrives as an emulated ScreenTouch and fired twice)
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			hit.accept_event()
			V9Feel.press(chip)
			_pulse(d.name)
			if play.stage:
				play.stage.say_text(d.long, 4.5))
	_refresh_chip()

func _refresh_chip() -> void :
	if ring == null:
		return
	match h:
		"mc":
			chip_val.text = str(board.slots) if board else ""
			ring.frac = 1.0
		"hana":
			var on: = _hana_live()
			chip_val.text = "»" if on else ""
			ring.frac = 1.0 if on else 0.0
			ring.glow = 0.5 + 0.4 * sin(G.time * 8.0) if on else 0.0
		"rin":
			ring.lit = cups
			ring.frac = float(pairs % V7Passives.RIN_EVERY) / V7Passives.RIN_EVERY if cups < V7Passives.RIN_MAX else 1.0
			chip_val.text = str(cups)
		"yue":
			ring.frac = float(pairs % V7Passives.YUE_EVERY) / V7Passives.YUE_EVERY
		"nova":
			ring.frac = float(pairs % V7Passives.NOVA_EVERY) / V7Passives.NOVA_EVERY
	ring.queue_redraw()

func _pulse(text: String, at = null) -> void :
	UI.punch(chip, 0.16)
	var gp: Vector2 = at if at != null else chip.position + Vector2(chip.size.x * 0.5, 70)
	Fx.float_text(play.fx_layer if play.fx_layer else play, gp, text, col.lightened(0.55), 24, col.darkened(0.55))


func _bind() -> void :
	board = play.board
	hacked.clear()
	seen_tray = board.tray.duplicate()
	dealt = false
	board.matched.connect(_on_match)
	board.tray_changed.connect(_on_tray)
	overlay = Overlay.new()
	overlay.run = self
	overlay.z_index = 150
	board.tile_layer.add_child(overlay)

func _process(dt: float) -> void :
	if play == null or not is_instance_valid(play):
		return
	if play.board != board and is_instance_valid(play.board):
		_bind()
	if board == null or not is_instance_valid(board):
		return
	if not dealt and board.input_on:
		dealt = true
		_on_deal()
	if h == "nova":
		for t in hacked.duplicate():
			if not is_instance_valid(t) or not t.alive:
				hacked.erase(t)
			elif board.on_board(t) and not t.pending and not t.flipping and t.z_index < 120:
				t.z_index = 120
	if overlay and (h == "nova" or h == "yue"):
		overlay.queue_redraw()
	if h == "hana":
		_refresh_chip()
	if auto:
		_auto_step(dt)

func _on_deal() -> void :
	_refresh_chip()
	# 0.8: the style name sits in the note slot under the goal plate (ends left of the style chip, above the
	# tray), not as a float over the portrait card and the tray
	if play.has_method("v8_note"):
		UI.punch(chip, 0.16)
		play.v8_note("Стиль: %s" % d.name, col.lightened(0.55), 2.4)
	else:
		_pulse("Стиль: %s" % d.name, chip.position + Vector2(chip.size.x * 0.5, 130))
	if h == "yue":
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(board):
			_yue_reveal()
	if "--passives_now=1" in OS.get_cmdline_user_args() and h == "nova":
		_nova_hack()

func _on_match(_mid: Vector2, _combo: int, _gold: bool, _shard: String) -> void :
	# 0.9: pairs an ult removed (from_ult) do not feed the passive counters either
	if play and is_instance_valid(play) and play.get("v9_from_ult") == true:
		return
	pairs += 1
	since_relay += 1
	match h:
		"rin":
			if pairs % V7Passives.RIN_EVERY == 0 and cups < V7Passives.RIN_MAX:
				cups += 1
				_pulse("+1 чашка")
				Sfx.play("sparkle", 1.3, -8)
				_log("cup +1 -> %d" % cups)
		"yue":
			if pairs % V7Passives.YUE_EVERY == 0:
				_yue_reveal()
		"nova":
			if pairs % V7Passives.NOVA_EVERY == 0:
				_nova_hack()
	_refresh_chip()

func _on_tray() -> void :
	var fresh: Tile = null
	for t in board.tray:
		if not seen_tray.has(t):
			fresh = t
	seen_tray = board.tray.duplicate()
	if fresh and h == "hana":
		_hana_relay(fresh)

func _canvas_pos(t: Tile) -> Vector2:
	return board.tile_layer.get_global_transform_with_canvas() * t.position

func _takeable(t: Tile) -> bool:
	if not board.on_board(t) or t.pending or t.flipping:
		return false
	if board.has_method("takeable") and not board.takeable(t):
		return false
	return true


func _hana_live() -> bool:
	return board != null and board.combo >= V7Passives.HANA_COMBO and board.now() - board.last_match < board.combo_window and since_relay >= 2

func _hana_relay(t: Tile) -> void :
	if not _hana_live() or t.face == 300:
		return
	var best: Tile = null
	for o in board.tiles:
		if o != t and o.face == t.face and _takeable(o) and o.ice <= 0 and board.is_free(o):
			if best == null or (o.step == t.step and best.step != t.step):
				best = o
	if best == null:
		return
	relays += 1
	since_relay = 0
	var from: = _canvas_pos(best)
	Fx.ring(play.fx_layer, from, col, 1.2, 0.35)
	Fx.burst(play.fx_layer, from, "sparkle", 10, col.lightened(0.3), 0.8)
	_pulse("Эстафета!", from + Vector2(0, -30))
	_log("relay face=%d combo=%d" % [t.face, board.combo])

	board.tap(best)


func _rin_return(t: Tile) -> void :
	cups -= 1
	var from: = _canvas_pos(t)
	board.tray.erase(t)
	board.history.erase(t)
	board.display.erase(t)
	board._return(t)
	board._layout_tray()
	seen_tray = board.tray.duplicate()
	board.reveal_free()
	board.tray_changed.emit()
	Sfx.play("whoosh", 1.25, -4)
	Fx.ring(play.fx_layer, from, col, 1.0, 0.35)
	_pulse("Чайная пауза", from + Vector2(0, -40))
	_refresh_chip()
	_log("return face=%d cups=%d" % [t.face, cups])


func _yue_reveal() -> void :
	var want: = {}
	for x in board.tray:
		want[x.face] = true
	var best: Tile = null
	for t in board.tiles:
		if not board.on_board(t) or t.pending or t.flipping or not (t.secret or t.ice > 0):
			continue
		if best == null:
			best = t
			continue
		var tw: = want.has(t.face)
		var bw: = want.has(best.face)
		if (tw and not bw) or (tw == bw and t.step < best.step):
			best = t
	if best == null:
		return
	if best.secret:
		best.reveal()
	if best.ice > 0:
		best.ice = 0
		best._update_ice()
	var at: = _canvas_pos(best)
	Fx.ring(play.fx_layer, at, Color(0.8, 0.88, 1.0), 1.4, 0.5)
	Fx.burst(play.fx_layer, at, "sparkle", 14, Color(0.8, 0.88, 1.0), 0.9)
	_pulse("Лунный взгляд", at + Vector2(0, -40))
	_log("reveal face=%d step=%d" % [best.face, best.step])


func _nova_hack() -> void :
	var want: = {}
	for x in board.tray:
		want[x.face] = true
	var free_faces: = {}
	for t in board.free_tiles():
		free_faces[t.face] = true
	var best: Tile = null
	var best_s: = -1
	for t in board.tiles:
		if not _takeable(t) or board.is_free(t) or hacked.has(t):
			continue
		var s: = 0
		if want.has(t.face):
			s = 3
		elif free_faces.has(t.face):
			s = 2
		if best == null or s > best_s or (s == best_s and t.step < best.step):
			best = t
			best_s = s
	if best == null:
		return
	board.cov[best] = []
	if board.has_method("open_tile"):
		board.open_tile(best)
	hacked.append(best)
	best.z_index = 120
	board.reveal_free()
	var at: = _canvas_pos(best)
	Fx.ring(play.fx_layer, at, col, 1.4, 0.45)
	Fx.burst(play.fx_layer, at, "sparkle", 14, col, 0.9)
	Sfx.play("select", 1.5, -4)
	_pulse("Доступ открыт", at + Vector2(0, -40))
	_log("hack face=%d step=%d" % [best.face, best.step])



func _input(e: InputEvent) -> void :
	if board == null or not is_instance_valid(board) or not board.input_on:
		return
	if not (e is InputEventScreenTouch and e.pressed):
		return
	var lp: = board.tile_layer.to_local(e.position)
	if h == "nova":
		for i in range(hacked.size() - 1, -1, -1):
			var t: Tile = hacked[i]
			if is_instance_valid(t) and board.on_board(t) and _hit(t, lp, 1.0):
				get_viewport().set_input_as_handled()
				board.tap(t)
				_log("tap hacked face=%d" % t.face)
				return
	elif h == "rin" and cups > 0:
		for t in board.tray:
			if not t.pending and _hit(t, lp, t.scale.x):
				get_viewport().set_input_as_handled()
				_rin_return(t)
				return

func _hit(t: Tile, lp: Vector2, sc: float) -> bool:
	var p: = lp - t.position
	return absf(p.x) <= Tile.TW * 0.5 * sc + 4.0 and absf(p.y) <= Tile.TH * 0.5 * sc + 4.0


func _auto_step(dt: float) -> void :
	_auto_cd -= dt
	if _auto_cd > 0.0 or not board.input_on:
		return
	_auto_cd = 0.5

	if h == "rin" and not _poked and board.tray.size() >= 1 and cups > 0:
		_poked = true
		_log("poke tray at %s" % _canvas_pos(board.tray[0]))
		_touch(_canvas_pos(board.tray[0]))
		return
	if h == "nova" and hacked.size() > 0 and board.tray.size() < board.slots - 1:
		var t: Tile = hacked[0]
		if board.on_board(t):
			_touch(_canvas_pos(t))
			return
	var mv: Tile = board.solver_move()
	if mv:
		board.tap(mv)

func _touch(at: Vector2) -> void :
	var ev: = InputEventScreenTouch.new()
	ev.position = at
	ev.pressed = true
	get_viewport().push_input(ev, true)
	var up: = InputEventScreenTouch.new()
	up.position = at
	up.pressed = false
	get_viewport().push_input(up, true)
