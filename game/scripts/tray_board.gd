class_name TrayBoard
extends Node2D





signal matched(mid: Vector2, combo: int, gold: bool, shard: String)
signal denied(t: Tile)
signal tray_changed
signal failed
signal cleared

const UX: = Tile.TW * 0.5 + 1.0
const UY: = Tile.TH * 0.5 + 1.0
const DZ: = Vector2(-6.0, -13.0)
const SLOTS: = 4
var slots: = 4

var tiles: Array[Tile] = []
var tray: Array[Tile] = []
var history: Array[Tile] = []
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
var cov: = {}
var sides: = {}
var opened: = {}
const MAX_COLS: = 6
const MAX_ROWS: = 9

# 0.9: tap / match / tray feedback goes through V9Feel (one place for «всё приятно нажимается»): the select
# click and haptic, the deny, the combo pitch ladder with its haptic in step, the «one slot left» warning. The
# meta tells V7Haptics not to add its own board haptics on top.
func _ready() -> void :
	set_meta("v9_feel", true)
	failed.connect( func(): V9Feel.haptic("fail"))
	cleared.connect( func(): V9Feel.haptic("clear"))
	floor_layer = Node2D.new()
	tile_layer = Node2D.new()
	add_child(floor_layer)
	add_child(tile_layer)


static func shape_keep(shape: String, i: int, j: int, C: int, R: int) -> bool:

	var x: float = (2.0 * i / max(1, C - 1)) - 1.0
	var y: float = (2.0 * j / max(1, R - 1)) - 1.0
	var ax: = absf(x)
	match shape:
		"heart":
			return not (y > 0.25 and ax > 1.05 - (y - 0.25) * 1.25) and not (y < -0.8 and ax < 0.3)
		"diamond":
			return ax * 0.8 + absf(y) * 0.75 <= 1.12
		"butterfly":
			return not (ax < 0.3 and absf(y) > 0.4)
		"cross":
			return ax < 0.45 or absf(y) < 0.4
		"ring":
			return not (ax < 0.3 and absf(y) < 0.4)
		"pyramid":
			return ax <= (y + 1.0) * 0.5 + 0.25
		"towers":
			return ax > 0.3 or y > 0.6
	return V6Layouts.keep(shape, x, y)

static func gen_layout(cfg: Dictionary) -> Array:
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 1))
	var C: int = cfg.cols
	var R: int = cfg.rows
	var L: int = cfg.layers
	if C > MAX_COLS:
		R = mini(R + (C - MAX_COLS), MAX_ROWS)
		L += 1
		C = MAX_COLS
	var fill: float = cfg.get("fill", 0.65)
	if int(cfg.cols) > MAX_COLS:
		fill = minf(0.95, fill * 1.3)
	var shape: String = cfg.get("shape", "rect")
	var pos: = []
	var occ: = {}

	for i in C:
		for j in R:
			if not shape_keep(shape, i, j, C, R):
				continue
			var corner: = (i == 0 or i == C - 1) and (j == 0 or j == R - 1)
			if shape == "rect" and corner and L >= 3 and rng.randf() < 0.5:
				continue
			pos.append(Vector3i(2 * i, 2 * j, 0))
			occ[Vector3i(2 * i, 2 * j, 0)] = true

	for z in range(1, L):
		var xs: = range(z, 2 * (C - 1) - z + 1, 2)
		var ys: = range(z, 2 * (R - 1) - z + 1, 2)
		if xs.is_empty() or ys.is_empty():
			break
		var mid: float = (xs[0] + xs[xs.size() - 1]) * 0.5
		var keep: = {}
		var dens: = fill * pow(0.88, z - 1)
		for yy in ys:
			for xx in xs:
				if xx > mid:
					continue
				var sup: = 0
				for dx in [-1, 1]:
					for dy in [-1, 1]:
						if occ.has(Vector3i(xx + dx, yy + dy, z - 1)):
							sup += 1
				var mx: = int(round(2 * mid - xx))
				var sup_m: = 0
				for dx in [-1, 1]:
					for dy in [-1, 1]:
						if occ.has(Vector3i(mx + dx, yy + dy, z - 1)):
							sup_m += 1
				if sup < 3 or sup_m < 3:
					continue
				if rng.randf() < dens * V6Layouts.upper_w(cfg.get("upper", ""), xx, yy, z, xs, ys):
					keep[Vector2i(xx, yy)] = true
		for k in keep:
			pos.append(Vector3i(k.x, k.y, z))
			occ[Vector3i(k.x, k.y, z)] = true
			var mx: = int(round(2 * mid - k.x))
			if mx != k.x:
				pos.append(Vector3i(mx, k.y, z))
				occ[Vector3i(mx, k.y, z)] = true
	return pos

static func _covers(o: Vector3i, t: Vector3i) -> bool:
	return o.z > t.z and absi(o.x - t.x) < 2 and absi(o.y - t.y) < 2

func setup(cfg: Dictionary) -> void :
	for t in tiles:
		t.queue_free()
	tiles.clear()
	tray.clear()
	history.clear()
	display.clear()
	combo = 0
	var pos: Array = gen_layout(cfg)
	if pos.size() % 2 == 1:

		var top: = 0
		for i in pos.size():
			if pos[i].z > pos[top].z:
				top = i
		pos.remove_at(top)
	pos.sort_custom( func(a, b): return a.z * 100000 + a.y * 100 + a.x < b.z * 100000 + b.y * 100 + b.x)
	for p in pos:
		var t: = Tile.new()
		t.gx = p.x
		t.gy = p.y
		t.gz = p.z
		tiles.append(t)
	cov.clear()
	for t in tiles:
		var me: = Vector3i(t.gx, t.gy, t.gz)
		cov[t] = tiles.filter( func(o): return o != t and _covers(Vector3i(o.gx, o.gy, o.gz), me))

	sides.clear()
	opened.clear()
	for t in tiles:
		var l: = tiles.filter( func(o): return o.gz == t.gz and o.gx - t.gx == -2 and absi(o.gy - t.gy) < 2)
		var r: = tiles.filter( func(o): return o.gz == t.gz and o.gx - t.gx == 2 and absi(o.gy - t.gy) < 2)
		sides[t] = [l, r]
	_assign(cfg)

	var minx: = 999
	var miny: = 999
	var maxx: = -999
	var maxy: = -999
	var maxz: = 0
	for t in tiles:
		minx = mini(minx, t.gx)
		miny = mini(miny, t.gy)
		maxx = maxi(maxx, t.gx)
		maxy = maxi(maxy, t.gy)
		maxz = maxi(maxz, t.gz)
	var w: = (maxx - minx) * UX + Tile.TW
	var h: = (maxy - miny) * UY + Tile.TH
	var off: = Vector2( - w * 0.5 + Tile.TW * 0.5, - h * 0.5 + Tile.TH * 0.5) - DZ * maxz * 0.5
	for t in tiles:
		t.home = off + Vector2((t.gx - minx) * UX, (t.gy - miny) * UY) + DZ * t.gz
		t.position = t.home
		t.build(look)
		if t.shard != "":
			t.set_shard(t.shard)
		t.mat.set_shader_parameter("dim", 0.0)
		tile_layer.add_child(t)
		if t.gz == 0:
			var s: = Sprite2D.new()
			s.texture = G.fx("tile_shadow")
			s.scale = Vector2(Tile.S, Tile.S) * 1.25
			s.position = t.home + Vector2(16, 26)
			s.modulate = Color(0.35, 0.1, 0.25, 0.6)
			floor_layer.add_child(s)
	bounds = Rect2(off - Vector2(Tile.TW, Tile.TH) * 0.5 + DZ * maxz, Vector2(w, h) - DZ * maxz + Vector2(14, 22))

func _assign(cfg: Dictionary) -> void :

	var nf: int = cfg.faces
	var faces: = range(36)
	faces.shuffle()
	faces = faces.slice(0, nf)
	var left: Array = tiles.duplicate()
	var order: = []
	var gone: = {}
	while not left.is_empty():
		var fr: = left.filter( func(t): return _free_if(t, func(o): return not gone.has(o)))
		var pick: Tile = fr[randi() % fr.size()]
		order.append(pick)
		left.erase(pick)
		gone[pick] = true
	var npairs: = order.size() / 2
	for k in npairs:
		var a: Tile = order[2 * k]
		var b: Tile = order[2 * k + 1]
		a.face = faces[k % nf]
		b.face = a.face
		a.step = k
		b.step = k

	var sh: String = cfg.get("shard", "")
	if sh != "" and npairs > 4:
		var k: = npairs - 2 - randi() % 3
		order[2 * k].shard = sh
		order[2 * k + 1].shard = sh
		order[2 * k].face = 100
		order[2 * k + 1].face = 100
	var n_gold: int = cfg.get("gold", 0)
	if n_gold > 0:
		var cand: = range(npairs).filter( func(k): return order[2 * k].shard == "")
		cand.shuffle()
		for i in mini(n_gold / 2, cand.size()):
			order[2 * cand[i]].gold = true
			order[2 * cand[i] + 1].gold = true


	var n_ice: int = int(round(cfg.get("ice", 0) * 1.5))
	if n_ice > 0:
		var ic: = order.filter( func(t): return t.shard == "" and not t.gold)
		ic.shuffle()
		var top: = ic.filter( func(t): return cov[t].is_empty())
		var rest: = ic.filter( func(t): return not cov[t].is_empty())
		var n_top: = mini(top.size(), maxi(1, int(n_ice * 0.6)))
		for i in n_top:
			top[i].ice = 1
		rest.shuffle()
		for i in mini(n_ice - n_top, rest.size()):
			rest[i].ice = 1


	if cfg.get("hidden", false):
		for t in tiles:
			if not cov[t].is_empty() and t.shard == "" and t.ice == 0:
				t.secret = true

func fit_into(r: Rect2, max_scale: = 1.7) -> void :
	r = V6BoardTable.inset(r)
	var s: float = min(r.size.x / bounds.size.x, r.size.y / bounds.size.y, max_scale)
	scale = Vector2(s, s)
	position = r.get_center() - bounds.get_center() * s
	V6BoardTable.attach(self, r)


func on_board(t: Tile) -> bool:
	return t.alive and not tray.has(t)

func is_free(t: Tile) -> bool:
	return _free_if(t, on_board)


func _free_if(t: Tile, present: Callable) -> bool:
	if opened.has(t):
		return true
	for o in cov[t]:
		if present.call(o):
			return false
	var sd = sides.get(t)
	if sd == null:
		return true
	return not ((sd[0] as Array).any(present) and (sd[1] as Array).any(present))


func open_tile(t: Tile) -> void :
	opened[t] = true

func board_count() -> int:
	return tiles.filter( func(t): return on_board(t)).size()

func free_tiles() -> Array:
	return tiles.filter( func(t): return on_board(t) and is_free(t))

func tile_at(gp: Vector2) -> Tile:
	var lp: = tile_layer.to_local(gp)
	for i in range(tiles.size() - 1, -1, -1):
		var t: Tile = tiles[i]
		if on_board(t) and t.hit(lp):
			return t
	return null

var dealing: = false
var _deal_tws: Array[Tween] = []
var _deal_gen: = 0

func _unhandled_input(e: InputEvent) -> void :
	if not input_on:
		# 0.9: a tap on the table while the deal is still landing is never dropped: the tile under the finger
		# glints, a soft clack and a light tap haptic answer it, and the rest of the deal lands at once (skip_deal)
		# so the very next tap plays. The skipping tap itself is not played (a tile still in flight is no target).
		if dealing and e is InputEventScreenTouch and e.pressed and _deal_hit(e.position):
			var dt: = tile_at(e.position)
			if dt:
				dt.press_glint()
			V9Feel.haptic("tap")
			V9Feel.sound("clack%d" % (randi() % 3), randf_range(1.05, 1.15), -6.0)
			get_viewport().set_input_as_handled()
			skip_deal()
		return
	if e is InputEventScreenTouch and e.pressed:
		var t: = tile_at(e.position)
		if t:
			tap(t)
			get_viewport().set_input_as_handled()

func now() -> float:
	return G.time


func best_move() -> Tile:
	var fr: = free_tiles()
	for t in fr:
		for x in tray:
			if x.face == t.face:
				return t
	var by_face: = {}
	for t in fr:
		by_face[t.face] = by_face.get(t.face, []) + [t]
	for f in by_face:
		if by_face[f].size() >= 2:
			return by_face[f][0]

	var best: Tile = null
	var best_d: = 999
	for t in fr:
		for o in tiles:
			if o != t and on_board(o) and o.face == t.face:
				var d: = 0
				for c in cov[o]:
					if on_board(c):
						d += 1
				if d < best_d:
					best_d = d
					best = t
	return best if best else (fr[0] if fr.size() > 0 else null)


func solver_move() -> Tile:
	var fr: = free_tiles()

	for x in tray:
		for t in fr:
			if t.face == x.face and t.step == x.step:
				return t
	for x in tray:
		for t in fr:
			if t.face == x.face:
				return t
	var best: Tile = null
	for t in fr:
		if best == null or t.step < best.step:
			best = t
	return best

func tap(t: Tile) -> void :


	if not on_board(t) or t.pending or t.flipping:
		return
	if not is_free(t):
		t.deny()
		V9Feel.tile_tap(false)
		denied.emit(t)
		return
	if t.ice > 0:
		for x in tiles:
			x.hint(false)
		t.crack()
		cracks += 1
		Sfx.play("clack1", 1.3, -6)
		V9Feel.haptic("flip" if t.ice <= 0 else "select")
		tray_changed.emit()
		return
	for x in tiles:
		x.hint(false)
	t.press_glint()
	var twin: Tile = null
	for x in tray:
		if x.face == t.face:
			twin = x
			break
	t.z_index = 200 + display.size()
	t.shadow.visible = false
	if twin:

		tray.erase(twin)
		twin.pending = true
		t.pending = true
		t.alive = false
		twin.alive = false
		history.erase(twin)
		display.insert(display.find(twin) + 1, t)
	else:
		tray.append(t)
		history.append(t)
		display.append(t)
	max_tray = maxi(max_tray, tray.size())
	# the click and the haptic: a pair-to-be is a plain select (its chime follows in _match); one slot left warns
	if twin == null and slots >= 4 and tray.size() == slots - 1:
		V9Feel.sound("select", randf_range(0.96, 1.06))
		V9Feel.haptic("danger")
	else:
		V9Feel.tile_tap(true)
	_layout_tray(t)
	reveal_free()
	tray_changed.emit()
	if twin:
		_match_later(twin, t)
	elif tray.size() >= slots:
		input_on = false
		await get_tree().create_timer(0.45).timeout
		failed.emit()
	if tiles.all( func(x): return not x.alive):
		input_on = false


func reveal_free() -> void :
	for t in tiles:
		if on_board(t) and not t.pending:
			t.set_free(is_free(t))
		if t.secret and on_board(t) and is_free(t):
			t.reveal()
		if t.ice > 0 and on_board(t):
			t.set_flip_ready(is_free(t))

func _match_later(a: Tile, b: Tile) -> void :
	await get_tree().create_timer(0.24).timeout
	_match(a, b)

var display: Array[Tile] = []

func _slot_local(i: int) -> Vector2:
	return tile_layer.to_local(slot_pos[i])

func _slot_at(i: int, n: int) -> Vector2:

	if n <= slots:
		return _slot_local(i)
	var a: = _slot_local(0)
	var b: = _slot_local(slots - 1)
	return a.lerp(b, float(i) / float(n - 1))

func _tray_scale() -> float:
	return slot_size / (Tile.TW * scale.x)

func _layout_tray(arriving: Tile = null) -> void :
	var s: = _tray_scale()
	var n: = display.size()
	for i in n:
		var t: Tile = display[i]
		var target: = _slot_at(i, n)
		var sc: = s * (1.0 if n <= slots else float(slots) / n * 1.05)
		if t == arriving:
			t.fly_to(target, sc, 0.26, true)
		else:
			t.fly_to(target, sc, 0.16, false)

# glow tint for tiles removed without a tray match (ult / skill); warm gold by default
var vanish_tint: = Color(1.0, 0.8, 0.52)

func _match(a: Tile, b: Tile) -> void :
	var tnow: = now()
	combo = combo + 1 if tnow - last_match < combo_window else 1
	last_match = tnow
	var mid: = (a.position + b.position) * 0.5
	last_face = a.face
	last_gift = a.gift or b.gift
	for t in [a, b]:
		t.kill_move()
		var tw: Tween = t.create_tween()
		tw.tween_property(t, "position", mid + (t.position - mid).normalized() * 14.0, 0.08)
		tw.tween_method( func(v): t.mat.set_shader_parameter("flash", v), 0.0, 1.0, 0.05)
		tw.tween_property(t, "scale", t.scale * 1.25, 0.05)
		tw.tween_property(t, "scale", Vector2.ZERO, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "modulate:a", 0.0, 0.14)
		tw.tween_callback(t.hide)
	# 0.9: each pair of a combo chimes a semitone higher (Sfx.combo_step, up to an octave) with its haptic in step
	V9Feel.tile_match(combo, a.gold)
	if a.shard != "":
		V9Feel.haptic("reveal")
	Sfx.play("clack0", 1.15, -4)
	matched.emit(tile_layer.get_global_transform_with_canvas() * mid, combo, a.gold, a.shard)
	await get_tree().create_timer(0.2).timeout
	display.erase(a)
	display.erase(b)
	a.pending = false
	b.pending = false
	_layout_tray()
	tray_changed.emit()
	if tiles.all( func(t): return not t.alive) and display.is_empty():
		input_on = false
		cleared.emit()



func _vanish_pair(a: Tile, b: Tile) -> void :
	# 0.9: an ult's removal follows the cut-in palette (vanish_tint, set by V9UltCast); the shader caps the glow so the face stays readable
	for t in [a, b]:
		t.alive = false
		t.kill_move()
		t.z_index = 150
		if t.mat:
			t.mat.set_shader_parameter("flash_col", Vector3(vanish_tint.r, vanish_tint.g, vanish_tint.b))
		var tw: Tween = t.create_tween()
		tw.tween_property(t, "position", t.position + Vector2(0, -30), 0.15).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_method( func(v): t.mat.set_shader_parameter("flash", v), 0.0, 1.0, 0.15)
		tw.tween_property(t, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "modulate:a", 0.0, 0.18)
		tw.tween_callback(t.hide)
	last_face = a.face
	last_gift = false
	matched.emit(tile_layer.get_global_transform_with_canvas() * ((a.position + b.position) * 0.5), combo, a.gold, a.shard)
	reveal_free()

func _pairs_on_board() -> Array:


	var by: = {}
	for t in tiles:
		if on_board(t) and not t.pending and t.shard == "":
			by[t.step] = by.get(t.step, []) + [t]
	var out: = []
	var single: = {}
	for k in by:
		var g: Array = by[k]
		if g.size() == 2 and g[0].face == g[1].face:
			out.append(g)
		else:
			for t in g:
				single[t.face] = single.get(t.face, []) + [t]
	for f in single:
		var g: Array = single[f]
		for i in range(0, g.size() - 1, 2):
			out.append([g[i], g[i + 1]])
	out.sort_custom( func(x, y): return mini(x[0].step, x[1].step) < mini(y[0].step, y[1].step))
	return out

func auto_pairs(n: int) -> void :
	for i in n:
		var ps: = _pairs_on_board()
		if ps.is_empty():
			break
		_vanish_pair(ps[0][0], ps[0][1])
		await get_tree().create_timer(0.3).timeout
	_check_clear()

func moonlight() -> void :
	for t in tiles:
		if t.alive and t.secret:
			t.reveal()
		if t.alive and t.ice > 0:
			t.ice = 0
			t._update_ice()
	hint()

func hack_deepest() -> void :
	var ps: = _pairs_on_board()
	if ps.is_empty():
		return
	var best: Array = ps[-1]
	_vanish_pair(best[0], best[1])
	_check_clear()

func _check_clear() -> void :
	await get_tree().create_timer(0.3).timeout
	if tiles.all( func(t): return not t.alive) and display.is_empty():
		input_on = false
		cleared.emit()


func undo() -> bool:
	if history.is_empty():
		return false
	var t: Tile = history.pop_back()
	tray.erase(t)
	display.erase(t)
	_return(t)
	_layout_tray()
	reveal_free()
	tray_changed.emit()
	return true


func return_tray(n: = 3) -> void :
	for i in mini(n, tray.size()):
		var t: Tile = tray.pop_back()
		history.erase(t)
		display.erase(t)
		_return(t)
	_layout_tray()
	reveal_free()
	input_on = true
	tray_changed.emit()

func _return(t: Tile) -> void :
	t.kill_move()
	var tw: Tween = t.create_tween().set_parallel()
	tw.tween_property(t, "position", t.home, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "scale", Vector2.ONE, 0.28)
	tw.chain().tween_callback( func():
		t.z_index = 0
		t.shadow.visible = true)

func hint() -> bool:
	var t: = best_move()
	if t == null:
		return false
	t.hint(true)
	for o in free_tiles():
		if o != t and o.face == t.face:
			o.hint(true)
			break
	return true

func shuffle_board() -> void :
	var ts: = tiles.filter( func(t): return on_board(t) and t.shard == "")
	reassign_faces(ts)
	for i in ts.size():
		var t: Tile = ts[i]
		var tw: Tween = t.create_tween()
		tw.tween_property(t, "scale", Vector2(0.0, 1.0), 0.12).set_delay(randf() * 0.2)
		tw.tween_property(t, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh", 1.1)



func reassign_faces(ts: Array) -> void :
	if ts.is_empty():
		return
	var mine: = {}
	for t in ts:
		mine[t] = true
	var gone: = {}
	for t in tiles:
		if not on_board(t):
			gone[t] = true
	var left: Array = tiles.filter( func(t): return on_board(t))
	var order: = []
	while not left.is_empty():
		var fr: Array = left.filter( func(t): return _free_if(t, func(o): return not gone.has(o)))
		if fr.is_empty():
			fr = left
		var pick: Tile = fr[randi() % fr.size()]
		order.append(pick)
		left.erase(pick)
		gone[pick] = true
	var cnt: = {}
	for t in ts:
		cnt[t.face] = cnt.get(t.face, []) + [t.gold]
	var top_step: = 0
	for t in tiles:
		top_step = maxi(top_step, t.step)
	var plan: = []
	for x in tray:
		if cnt.has(x.face) and not (cnt[x.face] as Array).is_empty():
			plan.append([x.face, (cnt[x.face] as Array).pop_back(), x.step])
	var prs: = []
	var odd: = []
	for f in cnt:
		var gs: Array = cnt[f]
		while gs.size() >= 2:
			var g: bool = gs.pop_back() or gs.pop_back()
			prs.append([f, g])
		for g in gs:
			odd.append([f, g])
	prs.shuffle()
	for pr in prs:
		top_step += 1
		plan.append([pr[0], pr[1], top_step])
		plan.append([pr[0], pr[1], top_step])
	for o in odd:
		top_step += 1
		plan.append([o[0], o[1], top_step])
	var k: = 0
	for t in order:
		if not mine.has(t) or k >= plan.size():
			continue
		var p: Array = plan[k]
		k += 1
		t.set_face(p[0])
		t.gold = p[1]
		t.step = p[2]
		t.mat.set_shader_parameter("gold", 1.0 if t.gold else 0.0)
	reveal_free()

# the deal: every tile drops from 60 px above its home and fades in, lower layers first. fast = the luck-card deal
# (0.8: the whole table down in ~0.75 s). Input opens as the last tile lands, or at once when a tap skips the deal.
func deal(fast: = false) -> void :
	input_on = false
	dealing = true
	_deal_gen += 1
	var gen: = _deal_gen
	_deal_tws.clear()
	var order: = tiles.duplicate()
	var n: = order.size()
	var step: = minf(0.004, 0.32 / maxf(1.0, n)) if fast else 0.012
	var zk: = 0.05 if fast else 0.12
	var drop: = 0.26 if fast else 0.32
	var last: = 0.0
	for i in n:
		var t: Tile = order[i]
		t.position = t.home + Vector2(0, -60)
		t.modulate.a = 0.0
		var d: = step * i + t.gz * zk
		last = maxf(last, d)
		var tw: Tween = t.create_tween().set_parallel()
		tw.tween_property(t, "position", t.home, drop).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(d)
		tw.tween_property(t, "modulate:a", 1.0, drop * 0.56).set_delay(d)
		_deal_tws.append(tw)
		if i % (8 if fast else 6) == 0:
			get_tree().create_timer(d + drop * 0.62).timeout.connect( func():
				if gen == _deal_gen:
					Sfx.play("clack%d" % (randi() % 3), randf_range(0.9, 1.1), -8))
	# input opens as the last tile lands (its drop + a beat), not a fixed 0.9 s after the last start
	await get_tree().create_timer(last + drop + 0.12).timeout
	if gen == _deal_gen:
		_deal_done()

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
	for t in tiles:
		if not is_instance_valid(t) or not on_board(t):
			continue
		if t.position.is_equal_approx(t.home) and t.modulate.a >= 0.999:
			continue
		var tw: Tween = t.create_tween().set_parallel()
		tw.tween_property(t, "position", t.home, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(t, "modulate:a", 1.0, 0.1)
	await get_tree().create_timer(0.16).timeout
	if gen == _deal_gen:
		_deal_done()

func _deal_done() -> void :
	dealing = false
	_deal_tws.clear()
	input_on = true
	reveal_free()

# a deal-skipping tap must land on the table (its tile bounds + a margin), not anywhere on the screen
func _deal_hit(gp: Vector2) -> bool:
	if tile_layer == null:
		return false
	var lp: = tile_layer.to_local(gp)
	var r: = Rect2()
	var first: = true
	for t in tiles:
		if not on_board(t):
			continue
		var tr: = Rect2(t.home - Vector2(Tile.TW, Tile.TH) * 0.5, Vector2(Tile.TW, Tile.TH))
		r = tr if first else r.merge(tr)
		first = false
	return not first and r.grow(24.0).has_point(lp)
