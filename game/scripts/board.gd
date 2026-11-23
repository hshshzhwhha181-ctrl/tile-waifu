class_name Board
extends Node2D


signal matched(a: Tile, b: Tile, mid: Vector2, combo: int)
signal denied(t: Tile)
signal picked(t: Tile)
signal cleared
signal stuck
signal changed

const UX: = Tile.TW * 0.5 + 1.0
const UY: = Tile.TH * 0.5 + 1.0
const DZ: = Vector2(-5.0, -12.0)

var tiles: Array[Tile] = []
var selected: Tile = null
var undo_stack: = []
var combo: = 0
var last_match: = -10.0
var fever_until: = -10.0
var input_on: = false
var floor_layer: Node2D
var tile_layer: Node2D
var fx_parent: Node
var bounds: = Rect2()
var neon: = false
var combo_window: = 3.0
var melt_mult: = 1

static func rect(x0: int, y0: int, w: int, h: int, z: int) -> Array:
	var r: = []
	for i in w:
		for j in h:
			r.append(Vector3i(x0 + 2 * i, y0 + 2 * j, z))
	return r

static func rows(widths: Array, y0: int, cx: int, z: int) -> Array:
	var r: = []
	for k in widths.size():
		var w: int = widths[k]
		for i in w:
			r.append(Vector3i(cx - (w - 1) + 2 * i, y0 + 2 * k, z))
	return r

static func layout(name: String) -> Array:
	match name:
		"pyramid":
			return rect(0, 0, 6, 6, 0) + rect(2, 2, 4, 4, 1) + rect(3, 3, 3, 3, 2) + rect(4, 4, 2, 2, 3) + [Vector3i(5, 5, 4)]
		"butterfly":
			return rect(0, 1, 3, 5, 0) + rect(8, 1, 3, 5, 0) + rect(6, 0, 1, 7, 0) + rect(1, 2, 2, 4, 1) + rect(9, 2, 2, 4, 1) + rect(6, 1, 1, 6, 1)\
			+ rect(2, 3, 1, 3, 2) + rect(10, 3, 1, 3, 2) + [Vector3i(6, 5, 2)]
		"pagoda":
			return rect(0, 6, 6, 4, 0) + rect(2, 0, 4, 3, 0) + rect(1, 7, 5, 3, 1) + rect(3, 1, 3, 2, 1) + rect(2, 8, 4, 2, 2) + rect(4, 2, 2, 1, 2) + rect(3, 9, 3, 1, 3)
		"fortress":
			var l: = rect(0, 0, 6, 6, 0)
			l += rect(0, 0, 2, 2, 1) + rect(6, 0, 2, 2, 1) + rect(0, 6, 2, 2, 1) + rect(6, 6, 2, 2, 1)
			l += [Vector3i(4, 0, 1), Vector3i(4, 2, 1), Vector3i(4, 4, 1), Vector3i(4, 6, 1), Vector3i(4, 8, 1), Vector3i(0, 4, 1), Vector3i(2, 4, 1), Vector3i(6, 4, 1), Vector3i(8, 4, 1)]
			l += [Vector3i(1, 1, 2), Vector3i(7, 1, 2), Vector3i(1, 7, 2), Vector3i(7, 7, 2), Vector3i(4, 4, 2)]
			return l
		"star":
			return rows([2, 4, 6, 8, 6, 4, 2], 0, 7, 0) + rows([1, 3, 5, 5, 3, 1], 1, 7, 1) + rows([2, 4, 2], 4, 7, 2) + rows([1, 1], 5, 7, 3)
		"dragon":
			return rect(0, 0, 6, 7, 0) + rect(1, 1, 5, 6, 1) + rect(2, 3, 4, 4, 2)
	return rect(0, 0, 4, 4, 0)

func _ready() -> void :
	floor_layer = Node2D.new()
	tile_layer = Node2D.new()
	add_child(floor_layer)
	add_child(tile_layer)

func setup(cfg: Dictionary) -> void :
	for t in tiles:
		t.queue_free()
	for c in floor_layer.get_children():
		c.queue_free()
	tiles.clear()
	selected = null
	undo_stack.clear()
	combo = 0
	var pos: Array = layout(cfg.layout)
	if pos.size() % 2 == 1:
		pos.pop_back()
	pos.sort_custom( func(a, b): return a.z * 100000 + a.y * 100 + a.x < b.z * 100000 + b.y * 100 + b.x)
	for p in pos:
		var t: = Tile.new()
		t.gx = p.x
		t.gy = p.y
		t.gz = p.z
		tiles.append(t)
	assign_solvable(tiles, int(cfg.faces))
	var n_ice: int = cfg.get("ice", 0)
	if n_ice > 0:
		var cand: = tiles.filter( func(t): return t.step >= 2)
		cand.shuffle()
		for i in min(n_ice, cand.size()):
			cand[i].ice = clampi(1 + randi() % cand[i].step, 1, 3)
	var n_gold: int = cfg.get("gold", 0)
	if n_gold > 0:
		var faces: = {}
		for t in tiles:
			faces[t.face] = true
		var fl: = faces.keys()
		fl.shuffle()
		var chosen: = fl.slice(0, n_gold / 2)
		var used: = {}
		for t in tiles:
			if t.face in chosen and used.get(t.face, 0) < 2:
				t.gold = true
				used[t.face] = used.get(t.face, 0) + 1

	var minx: = 999
	var miny: = 999
	var maxx: = -999
	var maxy: = -999
	for t in tiles:
		minx = min(minx, t.gx)
		miny = min(miny, t.gy)
		maxx = max(maxx, t.gx)
		maxy = max(maxy, t.gy)
	var maxz: = 0
	for t in tiles:
		maxz = max(maxz, t.gz)
	var w: = (maxx - minx) * UX + Tile.TW
	var h: = (maxy - miny) * UY + Tile.TH
	var off: = Vector2( - w * 0.5 + Tile.TW * 0.5, - h * 0.5 + Tile.TH * 0.5) - DZ * maxz * 0.5
	for t in tiles:
		t.home = off + Vector2((t.gx - minx) * UX, (t.gy - miny) * UY) + DZ * t.gz
		t.position = t.home
		t.build(neon)
		tile_layer.add_child(t)

		if t.gz == 0:
			var s: = Sprite2D.new()
			s.texture = G.fx("tile_shadow")
			s.scale = Vector2(Tile.S, Tile.S) * 1.25
			s.position = t.home + Vector2(16, 26)
			s.modulate = Color(0.45, 0.15, 0.3, 0.55)
			floor_layer.add_child(s)
	bounds = Rect2(off - Vector2(Tile.TW, Tile.TH) * 0.5 + DZ * maxz, Vector2(w, h) - DZ * maxz + Vector2(12, 20))
	refresh(false)

func fit_into(r: Rect2, max_scale: = 1.35) -> void :
	var s: float = min(r.size.x / bounds.size.x, r.size.y / bounds.size.y, max_scale)
	scale = Vector2(s, s)
	position = r.get_center() - (bounds.get_center()) * s


func is_free(t: Tile, set: Array = tiles) -> bool:
	for o in set:
		if o == t or not o.alive:
			continue
		if o.gz == t.gz + 1 and abs(o.gx - t.gx) < 2 and abs(o.gy - t.gy) < 2:
			return false
	var left: = false
	var right: = false
	for o in set:
		if o == t or not o.alive or o.gz != t.gz or abs(o.gy - t.gy) >= 2:
			continue
		if o.gx == t.gx - 2:
			left = true
		if o.gx == t.gx + 2:
			right = true
	return not (left and right)

func selectable(t: Tile) -> bool:
	return t.alive and t.ice <= 0 and is_free(t)

func assign_solvable(list: Array, nfaces: int) -> bool:
	for attempt in 300:
		for t in list:
			t.alive = true
		var faces: = range(36)
		faces.shuffle()
		faces = faces.slice(0, nfaces)
		var ok: = true
		for k in list.size() / 2:
			var fr: = list.filter( func(t): return t.alive and is_free(t, list))
			if fr.size() < 2:
				ok = false
				break
			fr.shuffle()
			var a: Tile = fr[0]
			var b: Tile = fr[1]
			a.alive = false
			b.alive = false
			a.face = faces[k % faces.size()]
			b.face = a.face
			a.step = k
			b.step = k
		if ok:
			for t in list:
				t.alive = true
			return true
	for t in list:
		t.alive = true
	return false

func find_pair() -> Array:
	var fr: = tiles.filter(selectable)
	for i in fr.size():
		for j in range(i + 1, fr.size()):
			if fr[i].face == fr[j].face:
				return [fr[i], fr[j]]
	return []

func alive_count() -> int:
	return tiles.filter( func(t): return t.alive).size()

func refresh(animate: = true) -> void :
	for t in tiles:
		if t.alive:
			t.set_free(selectable(t), animate)


func tile_at(global_pt: Vector2) -> Tile:
	var lp: = tile_layer.get_global_transform_with_canvas().affine_inverse() * global_pt
	for i in range(tiles.size() - 1, -1, -1):
		var t: = tiles[i]
		if t.alive and t.hit(lp):
			return t
	return null

func _unhandled_input(e: InputEvent) -> void :
	if not input_on or not is_visible_in_tree():
		return
	if e is InputEventScreenTouch and e.pressed:
		var t: = tile_at(e.position)
		if t:
			tap(t)
			get_viewport().set_input_as_handled()

func now() -> float:
	return G.time

func tap(t: Tile) -> void :
	for x in tiles:
		x.hint(false)
	if not selectable(t):
		t.deny()
		Sfx.play("deny")
		denied.emit(t)
		return
	if selected == null:
		selected = t
		t.set_selected(true)
		Sfx.play("select", randf_range(0.96, 1.06))
		picked.emit(t)
		return
	if selected == t:
		t.set_selected(false)
		selected = null
		Sfx.play("clack%d" % (randi() % 3), 0.9)
		return
	if selected.face == t.face:
		_match(selected, t)
	else:
		selected.set_selected(false)
		selected = t
		t.set_selected(true)
		Sfx.play("select", randf_range(0.96, 1.06))
		picked.emit(t)

func _match(a: Tile, b: Tile) -> void :
	selected = null
	a.alive = false
	b.alive = false
	undo_stack.append({"pair": [a, b], "ice": tiles.map( func(x): return x.ice)})
	var tnow: = now()
	combo = combo + 1 if tnow - last_match < combo_window else 1
	last_match = tnow
	for x in tiles:
		if x.alive and x.ice > 0:
			for k in melt_mult:
				x.melt()

	var mid: = (a.home + b.home) * 0.5 + Vector2(0, -30)
	for t in [a, b]:
		t.z_index = 100
		var tw: Tween = t.create_tween()
		tw.tween_property(t, "position", t.home + Vector2(0, -26), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(t, "position", mid + (t.home - mid).normalized() * 30.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "rotation", deg_to_rad(8 if t == a else -8), 0.16)
		tw.tween_method( func(v): t.mat.set_shader_parameter("flash", v), 0.0, 1.0, 0.06)
		tw.tween_property(t, "scale", Vector2(1.3, 1.3), 0.06)
		tw.tween_property(t, "scale", Vector2(0.0, 0.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "modulate:a", 0.0, 0.14)
		tw.tween_callback(t.hide)
	await get_tree().create_timer(0.27).timeout
	Sfx.play("match%d" % clampi(combo - 1, 0, 7))
	Sfx.play("clack0", 1.15, -4)
	var gmid: = tile_layer.get_global_transform_with_canvas() * mid
	matched.emit(a, b, gmid, combo)
	refresh(true)
	changed.emit()
	await get_tree().create_timer(0.15).timeout
	if alive_count() == 0:
		input_on = false
		cleared.emit()
	elif find_pair().is_empty():
		stuck.emit()

func undo() -> bool:
	if undo_stack.is_empty():
		return false
	var u: Dictionary = undo_stack.pop_back()
	for i in tiles.size():
		tiles[i].ice = u.ice[i]
		tiles[i]._update_ice()
	for t in u.pair:
		t.alive = true
		t.show()
		t.rotation = 0
		t.z_index = 0
		t.modulate.a = 1
		t.scale = Vector2(0.2, 0.2)
		t.position = t.home + Vector2(0, -60)
		t.mat.set_shader_parameter("flash", 0.0)
		var tw: Tween = t.create_tween().set_parallel()
		tw.tween_property(t, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(t, "position", t.home, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if selected:
		selected.set_selected(false)
		selected = null
	combo = 0
	refresh(true)
	changed.emit()
	return true

func hint() -> bool:
	var p: = find_pair()
	if p.is_empty():
		return false
	for t in p:
		t.hint(true)
	return true

func shuffle_board() -> void :
	if selected:
		selected.set_selected(false)
		selected = null
	var alive: = tiles.filter( func(t): return t.alive)
	for t in alive:
		t.ice = 0
		t._update_ice()
	var faces: = alive.map( func(t): return t.face)
	assign_solvable(alive, 36)

	var pairs: = {}
	for t in alive:
		if not pairs.has(t.step):
			pairs[t.step] = []
		pairs[t.step].append(t)
	var fl: = []
	var counts: = {}
	for f in faces:
		counts[f] = counts.get(f, 0) + 1
	for f in counts:
		for i in counts[f] / 2:
			fl.append(f)
	fl.shuffle()
	var i: = 0
	for k in pairs:
		for t in pairs[k]:
			t.face = fl[i % fl.size()]
		i += 1
	var center: = Vector2.ZERO
	for t in alive:
		var tw: Tween = t.create_tween()
		tw.tween_property(t, "position", center + (t.home - center) * 0.15, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "rotation", randf_range(-0.6, 0.6), 0.25)
		tw.tween_callback(t.set_face.bind(t.face))
		tw.tween_property(t, "position", t.home, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(t, "rotation", 0.0, 0.4)
	Sfx.play("whoosh")
	await get_tree().create_timer(0.3).timeout
	Sfx.play("clack1")
	refresh(true)
	changed.emit()

func deal() -> void :
	input_on = false
	var order: = tiles.duplicate()
	var i: = 0
	for t in order:
		var d: float = 0.012 * i + t.gz * 0.12
		t.position = t.home + Vector2(0, -420 - t.gz * 80)
		t.modulate.a = 0.0
		t.scale = Vector2(0.7, 0.7)
		var tw: Tween = t.create_tween()
		tw.tween_interval(d)
		tw.tween_property(t, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(t, "position", t.home, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(t, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1
	for c in floor_layer.get_children():
		c.modulate.a = 0
		c.create_tween().tween_property(c, "modulate:a", 0.55, 0.8).set_delay(0.3)
	var total: = 0.012 * order.size() + 0.5
	var steps: = int(total / 0.07)
	for k in steps:
		Sfx.play("clack%d" % (k % 3), randf_range(0.9, 1.15), -8)
		await get_tree().create_timer(0.07).timeout
	await get_tree().create_timer(0.3).timeout
	input_on = true
