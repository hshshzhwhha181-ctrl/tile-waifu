class_name TrayBoard
extends Node2D

# The tray board as a VIEW (P18 / WP5). The rules are TWBoard (game/core/rules): every rule operation here is
#   _sync()  (the tiles as they are now -> TWBoard)  ->  core.op()  ->  the events it returns, which this node animates.
# The Tile nodes stay the place other code reads and writes (skills, ults, the special / level / hand boards), so every
# operation starts from them. No rule lives here and no rule path waits on a timer: the delays only sequence the pictures
# (a pair settles 0.24 s after the tap, a full tray calls the loss 0.45 s later), the state is final at once.

signal matched(mid: Vector2, combo: int, gold: bool, shard: String)
signal denied(t: Tile)
signal tray_changed
signal failed
signal cleared

const E = preload("res://core/rules/tw_events_board.gd")
const UX: = Tile.TW * 0.5 + 1.0
const UY: = Tile.TH * 0.5 + 1.0
const DZ: = Vector2(-6.0, -13.0)
const SLOTS: = 4
const MAX_COLS: = TWFree.MAX_COLS
const MAX_ROWS: = TWFree.MAX_ROWS
var slots: = 4

var tiles: Array[Tile] = []
var tray: Array[Tile] = []
var history: Array[Tile] = []
var display: Array[Tile] = []
var slot_pos: Array[Vector2] = []
var slot_size: = 100.0
var combo: = 0
var last_match: = -10.0
var combo_window: = 5.0
var input_on: = false
var busy: = 0
var tile_layer: Node2D
var floor_layer: Node2D
var bounds: = Rect2()
var neon: = false
var look: = {}
var max_tray: = 0
var cracks: = 0
var last_face: = -1
var last_gift: = false
var cov: = {}      # Tile -> the tiles lying on it (read-only view of the topology)
var sides: = {}    # Tile -> [left neighbours, right neighbours]
var opened: = {}   # Tile -> true: forced free
var vanish_tint: = Color(1.0, 0.8, 0.52)   # glow of tiles removed without a tray match (ult / skill)
var dealing: = false
var core: TWBoard
var _ix: = {}      # Tile -> tile id
var _topo: = {}
var _deal_tws: Array[Tween] = []
var _deal_gen: = 0

# 0.9: tap / match / tray feedback goes through V9Feel; the meta tells V7Haptics not to add its own board haptics.
func _ready() -> void :
	set_meta("v9_feel", true)
	failed.connect( func(): V9Feel.haptic("fail"))
	cleared.connect( func(): V9Feel.haptic("clear"))
	floor_layer = Node2D.new()
	tile_layer = Node2D.new()
	add_child(floor_layer)
	add_child(tile_layer)


# one delayed picture step (never a rule): runs fn after sec seconds
func _after(sec: float, fn: Callable) -> void :
	get_tree().create_timer(sec).timeout.connect(fn)


# ---------------------------------------------------------------- table: tiles, the deal, the tile nodes

func setup(cfg: Dictionary) -> void :
	for t in tiles:
		t.queue_free()
	tiles.clear()
	tray.clear()
	history.clear()
	display.clear()
	combo = 0
	var pos: Array = TWFree.positions(cfg)
	core = TWBoard.from_positions(pos, slots)
	core.reset()
	_topo = {"cov_by": core.cov_by, "lft": core.lft, "rgt": core.rgt}
	_ix.clear()
	for p in pos:
		var t: = Tile.new()
		t.gx = p.x
		t.gy = p.y
		t.gz = p.z
		_ix[t] = tiles.size()
		tiles.append(t)
	opened.clear()
	TrayBridge.topology(self)
	_assign(cfg)
	bounds = TrayFx.dress(self)


# the deal: TWBoard deals the faces / steps / gold / ice / secret / shard (a fresh deal each play unless cfg.deal_seed says
# otherwise); the tiles take them. Special, level and hand boards override this with their own payload.
func _assign(cfg: Dictionary) -> void :
	var c: = cfg.duplicate()
	c.erase("plan")
	c.erase("v10_plan")
	c["deal_seed"] = int(cfg.get("deal_seed", randi()))
	core.deal(c, false)
	TrayBridge.take_deal(self, str(cfg.get("shard", "")))


func fit_into(r: Rect2, max_scale: = 1.7) -> void :
	r = V6BoardTable.inset(r)
	var s: float = min(r.size.x / bounds.size.x, r.size.y / bounds.size.y, max_scale)
	scale = Vector2(s, s)
	position = r.get_center() - bounds.get_center() * s
	V6BoardTable.attach(self, r)


# ---------------------------------------------------------------- the bridge to TWBoard

func _ids(ts: Array) -> PackedInt32Array:
	var out: = PackedInt32Array()
	for t in ts:
		out.append(_ix[t])
	return out


func _sync() -> void :
	TrayBridge.load(self)

func _pull() -> void :
	TrayBridge.pull(self)


# ---------------------------------------------------------------- queries (rules in TWFree / TWBoard)

func now() -> float:
	return G.time

func on_board(t: Tile) -> bool:
	return t.alive and not tray.has(t)

func is_free(t: Tile) -> bool:
	return _free_if(t, on_board)

func _free_if(t: Tile, present: Callable) -> bool:
	return opened.has(t) or TWFree.is_free(_ix[t], _topo, func(j): return present.call(tiles[j]))

func open_tile(t: Tile) -> void :
	opened[t] = true

func board_count() -> int:
	return tiles.filter( func(t): return on_board(t)).size()

func free_tiles() -> Array:
	return tiles.filter( func(t): return on_board(t) and is_free(t))

func best_move() -> Tile:
	_sync()
	var i: = core.best_move_from(_ids(free_tiles()))
	return tiles[i] if i >= 0 else null

func solver_move() -> Tile:
	_sync()
	var i: = core.solver_move_from(_ids(free_tiles()), false)
	return tiles[i] if i >= 0 else null

func _pairs_on_board() -> Array:
	_sync()
	return core.pairs_on_board().map( func(p): return [tiles[p[0]], tiles[p[1]]])

func hint() -> bool:
	_sync()
	var h: = core.hint_from(_ids(free_tiles()))
	for i in h:
		tiles[i].hint(true)
	return not h.is_empty()

func tile_at(gp: Vector2) -> Tile:
	var lp: = tile_layer.to_local(gp)
	for i in range(tiles.size() - 1, -1, -1):
		var t: Tile = tiles[i]
		if on_board(t) and t.hit(lp):
			return t
	return null


# ---------------------------------------------------------------- input and tap

func _unhandled_input(e: InputEvent) -> void :
	if not input_on:
		# 0.9: a tap while the deal is still landing is never dropped (glint, clack, haptic), the rest of the deal lands at once
		if dealing and e is InputEventScreenTouch and e.pressed and TrayFx.deal_tap(self, e.position):
			get_viewport().set_input_as_handled()
			skip_deal()
		return
	if e is InputEventScreenTouch and e.pressed:
		if V10TileInfo.intercept(self, e):  # v10-clarity hook: long press / lupa / close the tile bubble
			get_viewport().set_input_as_handled()
			return
		var t: = tile_at(e.position)
		if t:
			tap(t)
			get_viewport().set_input_as_handled()


func tap(t: Tile) -> void :
	if not on_board(t) or t.pending or t.flipping:
		return
	_sync()
	var ev: Array = core.tap(_ix[t])
	if E.has(ev, E.DENY):
		t.deny()
		V9Feel.tile_tap(false)
		denied.emit(t)
		return
	for x in tiles:
		x.hint(false)
	if E.has(ev, E.ICE_CRACK):
		t.crack()
		cracks = core.cracks
		Sfx.play("clack1", 1.3, -6)
		V9Feel.haptic("flip" if t.ice <= 0 else "select")
		tray_changed.emit()
		return
	t.press_glint()
	var mt: Array = E.of_type(ev, E.MATCH)
	var twin: Tile = tiles[int(mt[0].a)] if not mt.is_empty() else null
	t.z_index = 200 + display.size()
	t.shadow.visible = false
	if twin:
		twin.pending = true
		t.pending = true
		t.alive = false
		twin.alive = false
		display.insert(display.find(twin) + 1, t)
	else:
		display.append(t)
	_pull()
	# the click and the haptic: a pair-to-be is a plain select (its chime follows in _match); one slot left warns
	if E.has(ev, E.TRAY_WARN):
		V9Feel.sound("select", randf_range(0.96, 1.06))
		V9Feel.haptic("danger")
	else:
		V9Feel.tile_tap(true)
	_layout_tray(t)
	reveal_free()
	tray_changed.emit()
	if twin:
		_after(0.24, func(): _match(twin, t))
	elif E.has(ev, E.TRAY_FULL):
		input_on = false
		_after(0.45, func(): failed.emit())
	if tiles.all( func(x): return not x.alive):
		input_on = false


# secret tiles that became free turn over; every free tile is lit, a flip-ready ice tile glows
func reveal_free() -> void :
	_sync()
	for e in core.reveal_events():
		tiles[int(e.id)].reveal()
	for i in tiles.size():
		var t: Tile = tiles[i]
		if not on_board(t):
			continue
		var f: = core.is_free(i)
		if not t.pending:
			t.set_free(f)
		if t.ice > 0:
			t.set_flip_ready(f)


# ---------------------------------------------------------------- tray and pair pictures

func _slot_local(i: int) -> Vector2:
	return tile_layer.to_local(slot_pos[i])

func _slot_at(i: int, n: int) -> Vector2:
	return TrayFx.slot_at(self, i, n)

func _tray_scale() -> float:
	return slot_size / (Tile.TW * scale.x)

func _layout_tray(arriving: Tile = null) -> void :
	TrayFx.layout_tray(self, arriving)


# a pair of the tray settles: the combo counts, the two tiles merge and pop, 0.2 s later the tray closes the gap
func _match(a: Tile, b: Tile) -> void :
	var tnow: = now()
	combo = TWBoard.next_combo(combo, last_match, tnow, combo_window)
	last_match = tnow
	var mid: = (a.position + b.position) * 0.5
	last_face = a.face
	last_gift = a.gift or b.gift
	TrayFx.pair_pop(a, b)
	# 0.9: each pair of a combo chimes a semitone higher (Sfx.combo_step, up to an octave) with its haptic in step
	V9Feel.tile_match(combo, a.gold)
	if a.shard != "":
		V9Feel.haptic("reveal")
	Sfx.play("clack0", 1.15, -4)
	matched.emit(tile_layer.get_global_transform_with_canvas() * mid, combo, a.gold, a.shard)
	_after(0.2, func():
		display.erase(a)
		display.erase(b)
		a.pending = false
		b.pending = false
		_layout_tray()
		tray_changed.emit()
		_clear_if_done())


# an ult's removal follows the cut-in palette (vanish_tint, set by V9UltCast); the shader caps the glow so the face stays readable
func _vanish_pair(a: Tile, b: Tile) -> void :
	a.alive = false
	b.alive = false
	TrayFx.vanish(a, b, vanish_tint)
	last_face = a.face
	last_gift = false
	matched.emit(tile_layer.get_global_transform_with_canvas() * ((a.position + b.position) * 0.5), combo, a.gold, a.shard)
	reveal_free()


# ---------------------------------------------------------------- ults and skills (the picks are TWBoard's)

func auto_pairs(n: int, k: int = 0) -> void :
	if k < n:
		var ps: = _pairs_on_board()
		if not ps.is_empty():
			_vanish_pair(ps[0][0], ps[0][1])
			_after(0.3, func(): auto_pairs(n, k + 1))
			return
	_check_clear()

func hack_deepest() -> void :
	var ps: = _pairs_on_board()
	if ps.is_empty():
		return
	_vanish_pair(ps[-1][0], ps[-1][1])
	_check_clear()

func moonlight() -> void :
	_sync()
	var m: Dictionary = core.moonlight()[0]
	for t in tiles:
		var i: int = _ix[t]
		if (m.revealed as Array).has(i):
			t.reveal()
		if (m.thawed as Array).has(i):
			t.ice = 0
			t._update_ice()
	hint()

func _check_clear() -> void :
	_after(0.3, _clear_if_done)

func _clear_if_done() -> void :
	if tiles.all( func(t): return not t.alive) and display.is_empty():
		input_on = false
		cleared.emit()


# ---------------------------------------------------------------- undo, rescue, shuffle

func undo() -> bool:
	if history.is_empty():
		return false
	_sync()
	var ev: Array = core.undo()
	if ev.is_empty():
		return false
	var t: Tile = tiles[int(ev[0].id)]
	_pull()
	display.erase(t)
	TrayFx.fly_home(t)
	_layout_tray()
	reveal_free()
	tray_changed.emit()
	return true

func return_tray(n: = 3) -> void :
	_sync()
	var ev: Array = core.return_tray(n)
	_pull()
	for i in (ev[0].ids if not ev.is_empty() else []):
		display.erase(tiles[int(i)])
		TrayFx.fly_home(tiles[int(i)])
	_layout_tray()
	reveal_free()
	input_on = true
	tray_changed.emit()

func _return(t: Tile) -> void :
	TrayFx.fly_home(t)

func shuffle_board() -> void :
	var ts: = tiles.filter( func(t): return on_board(t) and t.shard == "")
	reassign_faces(ts)
	TrayFx.shuffle_wave(ts)

# the faces of these tiles are dealt again (TWBoard.reassign: solvable from the current table, tray tiles keep a twin)
func reassign_faces(ts: Array) -> void :
	if ts.is_empty():
		return
	_sync()
	core.reassign(Array(_ids(ts)))
	for t in ts:
		var i: int = _ix[t]
		if t.face != core.face[i]:
			t.set_face(core.face[i])
		t.gold = core.gold[i] == 1
		t.step = core.step[i]
		t.mat.set_shader_parameter("gold", 1.0 if t.gold else 0.0)
	reveal_free()


# ---------------------------------------------------------------- the deal picture

# the table drops in (fast = the luck-card deal); input opens as the last tile lands, or at once when a tap skips the deal
func deal(fast: = false) -> void :
	input_on = false
	dealing = true
	_deal_gen += 1
	var gen: = _deal_gen
	_deal_tws.clear()
	_after(TrayFx.deal_in(self, fast, gen, _deal_tws), func():
		if gen == _deal_gen:
			_deal_done())

# 0.9: a tap during the deal lands every tile still in flight in 0.14 s and opens the table right after
func skip_deal() -> void :
	if not dealing:
		return
	_deal_gen += 1
	var gen: = _deal_gen
	for tw in _deal_tws:
		if tw and tw.is_valid():
			tw.kill()
	_deal_tws.clear()
	TrayFx.deal_land(self)
	_after(0.16, func():
		if gen == _deal_gen:
			_deal_done())

func _deal_done() -> void :
	dealing = false
	_deal_tws.clear()
	input_on = true
	reveal_free()
