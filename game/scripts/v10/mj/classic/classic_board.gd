class_name V10MjClassicBoard
extends Node2D

# «Классика» table (MODES §4.1): a 3D stack of 72–144 Tile nodes (the game's own Tile class, V6TileLook dress).
# No tray: tap a free tile to lift it, tap a free tile of the same kind to take the pair. Flowers pair with any
# flower, seasons with any season. Unlimited undo and hint. No moves left -> automatic shuffle that keeps the table
# solvable (V10MjClassicGen.reshuffle). View «Объёмный» / «Плоский». Double tap on the cloth zooms to half the table,
# a pinch scales, one finger pans while zoomed.
#
# Rules state is per position: alive (PackedByteArray), faces (PackedInt32Array), keys — so undo restores it bit for
# bit (state() / the selftest). Tile nodes only show it.
#
# The board never talks to the heroine: it emits signals; the screen turns them into presence events.
#
# Tile look: opts.look is a V6TileLook dictionary (side, rim, tint). When it carries the look lane's "v10mj" block
# (V10MjTileMaterial.look_dict) and that lane is in the tree, every tile is dressed in the material (porcelain, jade,
# bone, ice, amber, lacquer): the shader then breathes free tiles itself and shades closed ones.
# Приёмы (MODES §5.5, «Классика»): ult_take(n) — n pairs of the live certificate; ult_deep() — the deepest pair
# (even a covered one) that keeps a certificate; show_path() — a pair that is still closed and what keeps it closed;
# show_pairs(t) — every free pair for t seconds.

signal picked(t: Tile, pos: Vector2)
signal denied(t: Tile)
signal paired(a: Tile, b: Tile, pos: Vector2, key: int, face: int)
signal shuffled(auto: bool)
signal cleared
signal changed

const UX: = Tile.TW * 0.5 + 1.0
const UY: = Tile.TH * 0.5 + 1.0
const DZ3: = Vector2(-6.0, -12.0)
const DZF: = Vector2(-2.0, -3.5)
const ZOOM_MAX: = 2.6
const DOUBLE_T: = 0.32
const LOOK_LIB: = "res://scripts/v10/mj/look/tile_material.gd"
const JADE: = Color("4fe0b0")
const GOLD: = Color("f1d9a0")

var form: = {}
var deal: = {}
var geo: V10MjClassicGen.Geo
var alive: = PackedByteArray()
var faces: = PackedInt32Array()
var keys: = PackedInt32Array()
var cert: = PackedInt32Array()     # live certificate (flat pairs, placement order) or empty if lost
var base_order: = PackedInt32Array()
var tiles: Array = []              # per position (Tile)
var history: Array = []
var sel: = -1
var moves: = 0
var hints: = 0
var shuffles: = 0
var auto_shuffles: = 0              # «Ходов нет — перемешала»: free, never costs a star (MODES §4.1)
var undos: = 0
var input_on: = true
var view: = "3d"
var light: = true                 # first 7 days: closed tiles dimmed strongly
var accent: = Color("ff8fb8")
var look: = {}
var tile_layer: Node2D
var marks: = {}                    # position -> group mark node
var bounds: = Rect2()
var field: = Rect2()               # the clip rect (parent space)
var base_scale: = 1.0
var base_pos: = Vector2.ZERO
var zoom: = 1.0
var fx_min: = false
var _anim: = {}
var _hinted: = PackedInt32Array()
var _t: = 0.0
var _touch: = {}
var _press_pos: = Vector2.ZERO
var _press_tile: = -1
var _dragging: = false
var _pinch: = false
var _pinch_d0: = 1.0
var _pinch_z0: = 1.0
var _last_empty_tap: = -10.0
var _last_empty_pos: = Vector2.ZERO
var _zoom_tw: Tween
var _ghost: Node2D
var dressed: = false               # tiles wear the look lane's material (V10MjTileMaterial)
var _tm = null                     # the V10MjTileMaterial script when dressed
var _lights: Array = []            # tiles lit by show_path / show_pairs (cleared on the next move)
var _light_tw: SceneTreeTimer


func _ready() -> void:
	set_meta("v9_feel", true)
	if tile_layer == null:
		tile_layer = Node2D.new()
		tile_layer.name = "Tiles"
		add_child(tile_layer)


# opts: look (tile look dict), view ("3d" | "flat"), light (bool), accent (Color), deal (pre-made deal to reuse)
func setup(f: Dictionary, seed_: int, diff: = "normal", opts: = {}) -> void:
	if tile_layer == null:
		_ready()
	for t in tiles:
		if is_instance_valid(t):
			t.queue_free()
	tiles.clear()
	marks.clear()
	history.clear()
	_anim.clear()
	form = f
	look = opts.get("look", {})
	if look.is_empty():
		var tree: = Engine.get_main_loop() as SceneTree
		var g = tree.root.get_node_or_null("G") if tree else null
		look = g.skin_look() if g else {"side": Color("e8789f"), "rim": Color("f6dfe6"), "tint": Color.WHITE}
	dressed = false
	_tm = null
	if look.has("v10mj") and ResourceLoader.exists(LOOK_LIB):
		_tm = load(LOOK_LIB)
		dressed = _tm != null
	view = String(opts.get("view", "3d"))
	light = bool(opts.get("light", true))
	accent = opts.get("accent", accent)
	fx_min = String(opts.get("fx", "full")) == "min"
	deal = opts.get("deal", {})
	if deal.is_empty():
		deal = V10MjClassicGen.generate(f, seed_, diff)
	geo = deal.geo
	faces = PackedInt32Array(deal.faces)
	keys = PackedInt32Array(deal.keys)
	alive = V10MjClassicGen.ones(geo.n)
	cert = PackedInt32Array(deal.order)
	base_order = PackedInt32Array(deal.order)
	sel = -1
	moves = 0
	hints = 0
	shuffles = 0
	auto_shuffles = 0
	undos = 0
	# draw order: layer, then row, then column (upper layers last, lower rows over upper rows)
	var idx: Array = range(geo.n)
	idx.sort_custom(func(a, b):
		var pa: Vector3i = geo.pos[a]
		var pb: Vector3i = geo.pos[b]
		return pa.z * 1000000 + pa.y * 1000 + pa.x < pb.z * 1000000 + pb.y * 1000 + pb.x)
	tiles.resize(geo.n)
	for i in idx:
		var p: Vector3i = geo.pos[i]
		var t: = Tile.new()
		t.gx = p.x
		t.gy = p.y
		t.gz = p.z
		t.face = faces[i]
		t.set_meta("pi", i)
		tiles[i] = t
		tile_layer.add_child(t)
		t.build(look)
		if dressed:
			_tm.dress(t, look, _light_dict())
		_mark(i)
	_layout_tiles()
	for i in geo.n:
		_set_free(i, geo.free_in(i, alive), false)
	changed.emit()


# the deal: layer by layer the tiles settle onto the cloth (≤ 1.1 s); a tap during it lands everything at once
var _deal_tws: Array = []
var dealing: = false

func deal_in(instant: = false) -> void:
	if instant or geo == null:
		return
	dealing = true
	input_on = false
	var maxz: = 0
	for i in geo.n:
		maxz = maxi(maxz, geo.pos[i].z)
	for i in geo.n:
		var t: Tile = tiles[i]
		var p: Vector3i = geo.pos[i]
		var d: = 0.1 + 0.16 * p.z + 0.012 * p.y + 0.004 * p.x
		t.position = t.home + Vector2(0, -26 - 10 * p.z)
		t.modulate.a = 0.0
		t.scale = Vector2(0.92, 0.92)
		var tw: = t.create_tween()
		tw.tween_interval(minf(d, 0.85))
		tw.tween_property(t, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(t, "position", t.home, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(t, "scale", Vector2.ONE, 0.22)
		_deal_tws.append(tw)
	for z in maxz + 1:
		var at: = minf(0.1 + 0.16 * z, 0.85) + 0.12
		get_tree().create_timer(at).timeout.connect(func():
			if dealing:
				V9Feel.sound("clack%d" % (z % 3), 0.9 + 0.06 * z, -8.0))
	get_tree().create_timer(1.15).timeout.connect(_end_deal)


func _end_deal() -> void:
	if not dealing:
		return
	dealing = false
	for tw in _deal_tws:
		if tw and tw.is_valid():
			tw.kill()
	_deal_tws.clear()
	for i in geo.n:
		var t: Tile = tiles[i]
		if alive[i]:
			t.position = t.home
			t.modulate.a = 1.0
			t.scale = Vector2.ONE
	input_on = true


func _home(i: int) -> Vector2:
	var p: Vector3i = geo.pos[i]
	var dz: = DZ3 if view == "3d" else DZF
	return Vector2(p.x * UX, p.y * UY) + dz * p.z


func _layout_tiles() -> void:
	var mn: = Vector2(INF, INF)
	var mx: = Vector2(-INF, -INF)
	for i in geo.n:
		var h: = _home(i)
		mn = Vector2(minf(mn.x, h.x), minf(mn.y, h.y))
		mx = Vector2(maxf(mx.x, h.x), maxf(mx.y, h.y))
	var c: = (mn + mx) * 0.5
	for i in geo.n:
		var t: Tile = tiles[i]
		t.home = _home(i) - c
		if not _anim.has(i):
			t.position = t.home
	bounds = Rect2(mn - c - Vector2(Tile.TW, Tile.TH) * 0.5 - Vector2(4, 4), (mx - mn) + Vector2(Tile.TW, Tile.TH) + Vector2(16, 22))


# fit into `r` (parent space): the whole form visible at zoom 1
func fit(r: Rect2) -> void:
	field = r
	var s: = minf(r.size.x / bounds.size.x, r.size.y / bounds.size.y)
	s = minf(s, 1.25)
	base_scale = s
	base_pos = r.get_center() - bounds.get_center() * s
	_apply_zoom(zoom, r.get_center(), false)
	_relight()


func _relight() -> void:
	V6TileLook.lamp = bounds.position + bounds.size * Vector2(0.3, 0.1)
	var arr: Array = tiles.filter(func(t): return t != null)
	V6TileLook.relight(arr)
	if dressed:
		var ld: = _light_dict()
		for t in arr:
			var m = (t as Tile).mat
			if m is ShaderMaterial:
				_tm.apply_light(m, ld)


# the table lamp for the look lane's material (the same lamp V6TileLook uses)
func _light_dict() -> Dictionary:
	return {"lamp": V6TileLook.lamp, "lamp_col": V6TileLook.lamp_col, "gloss": V6TileLook.gloss, "ambient": V6TileLook.ambient}


func tile_scale_px() -> float:
	return Tile.TW * base_scale * zoom


# ---- the group mark (flowers / seasons) ------------------------------------------------------------------------
class GroupMark:
	extends Node2D
	var kind: = 0  # 1 flower, 2 season
	func _draw() -> void:
		if kind == 0:
			return
		var c: = Vector2.ZERO
		draw_circle(c, 11.0, Color(0.11, 0.08, 0.1, 0.78))
		draw_arc(c, 11.0, 0, TAU, 24, Color("e8c47e"), 1.6, true)
		if kind == 1:
			for k in 5:
				var a: = -PI / 2 + TAU * k / 5.0
				draw_circle(c + Vector2(cos(a), sin(a)) * 4.6, 3.0, Color("f1d9a0"))
			draw_circle(c, 2.2, Color("d796a5"))
		else:
			for k in 4:
				var a2: = TAU * k / 4.0 + PI / 4
				draw_arc(c, 6.0, a2 - 0.6, a2 + 0.6, 8, Color("f1d9a0"), 2.4, true)
			draw_circle(c, 2.0, Color("a9d9c4"))


func _mark(i: int) -> void:
	var t: Tile = tiles[i]
	var m: GroupMark = marks.get(i)
	var k: = keys[i] if i < keys.size() else -1
	var kind: = 1 if k == V10MjClassicLayouts.KEY_FLOWER else (2 if k == V10MjClassicLayouts.KEY_SEASON else 0)
	if kind == 0:
		if m:
			m.visible = false
		return
	if m == null:
		m = GroupMark.new()
		m.position = Vector2(Tile.TW * 0.30, -Tile.TH * 0.33)
		t.add_child(m)
		marks[i] = m
	m.kind = kind
	m.visible = true
	m.queue_redraw()


# ---- a clear outline above the face: gold = lifted, jade = hint (the tile's own glow sits under its body) ----
class _Halo:
	extends Node2D
	var col: = Color("f1d9a0")
	var pulse: = false
	var t: = 0.0
	func _process(dt: float) -> void:
		t += dt
		if pulse:
			queue_redraw()
	func _draw() -> void:
		var k: = 0.65 + 0.35 * sin(t * 6.0) if pulse else 1.0
		var r: = Rect2(-Tile.TW * 0.5 - 3, -Tile.TH * 0.5 - 3, Tile.TW + 6, Tile.TH + 6)
		var sb: = StyleBoxFlat.new()
		sb.draw_center = false
		sb.set_corner_radius_all(12)
		sb.border_color = Color(col, 0.38 * k)
		sb.set_border_width_all(9)
		sb.anti_aliasing = true
		draw_style_box(sb, r.grow(4))
		var sb2: = StyleBoxFlat.new()
		sb2.draw_center = false
		sb2.set_corner_radius_all(10)
		sb2.border_color = Color(col, 0.95 * k)
		sb2.set_border_width_all(5)
		sb2.anti_aliasing = true
		draw_style_box(sb2, r)


func _halo(i: int, on: bool, col: = Color("f1d9a0"), pulse: = false) -> void:
	var t: Tile = tiles[i]
	var h: Node = t.get_node_or_null("Halo")
	if not on:
		if h:
			h.queue_free()
			h.name = "HaloGone"
		return
	if h == null:
		h = _Halo.new()
		h.name = "Halo"
		t.add_child(h)
	h.col = col
	h.pulse = pulse
	h.queue_redraw()


# ---- free / dim -----------------------------------------------------------------------------------------------
func _set_free(i: int, f: bool, animate: = true) -> void:
	var t: Tile = tiles[i]
	if t == null or t.mat == null:
		return
	var was: = t.free
	t.free = f
	var target: = 0.0 if f else (1.0 if light else 0.5)
	# closed tiles sit in shadow (the face a step darker), free ones are lit — «what can I take» at a glance
	var tint: = Color.WHITE if f else (Color(0.74, 0.72, 0.76) if light else Color(0.88, 0.87, 0.9))
	var from: float = t.mat.get_shader_parameter("dim") if t.mat.get_shader_parameter("dim") != null else target
	if dressed:
		# the material shades closed tiles itself (18 %) and breathes free ones; «light» adds the board's own dim
		_tm.tile_state(t, f, not f, i, accent)
		target = 0.0 if f else (0.55 if light else 0.0)
	if not animate or fx_min:
		t.mat.set_shader_parameter("dim", target)
		t.face_spr.modulate = tint
		return
	if absf(from - target) < 0.01:
		return
	var m: = t.mat
	var tw: = t.create_tween().set_parallel()
	tw.tween_method(func(v): m.set_shader_parameter("dim", v), from, target, 0.28)
	tw.tween_property(t.face_spr, "modulate", tint, 0.28)
	if f and not was:
		t.shine(0.05)


func _update_free(animate: = true) -> void:
	for i in geo.n:
		if alive[i]:
			_set_free(i, geo.free_in(i, alive), animate)


func remaining() -> int:
	return V10MjClassicGen.count_alive(alive)


func total() -> int:
	return geo.n if geo else 0


func is_free(i: int) -> bool:
	return alive[i] == 1 and geo.free_in(i, alive)


func pairs_now() -> Array:
	return V10MjClassicGen.available_pairs(geo, alive, keys)


func state() -> Dictionary:
	return {"alive": PackedByteArray(alive), "faces": PackedInt32Array(faces), "keys": PackedInt32Array(keys), "sel": sel,
		"moves": moves, "cert": PackedInt32Array(cert)}


# ---- breathing of free tiles (1.00–1.01), one slow wave across the table -------------------------------------
func _process(dt: float) -> void:
	_t += dt
	if fx_min or geo == null or dressed:
		return
	for i in geo.n:
		var t: Tile = tiles[i]
		if t == null or not alive[i] or i == sel or _anim.has(i) or _hinted.has(i):
			continue
		if t.free:
			var k: = 1.0 + 0.005 * (1.0 + sin(_t * 2.1 - (t.gx + t.gy) * 0.22))
			t.scale = Vector2(k, k)
		elif t.scale.x != 1.0:
			t.scale = Vector2.ONE


# ---- input ----------------------------------------------------------------------------------------------------
func tile_at(gp: Vector2) -> int:
	var lp: = tile_layer.to_local(gp)
	var kids: = tile_layer.get_children()
	for k in range(kids.size() - 1, -1, -1):
		var t = kids[k]
		if not t is Tile:
			continue
		var i: int = t.get_meta("pi", -1)
		if i < 0 or not alive[i] or _anim.has(i):
			continue
		var p: Vector2 = lp - t.home
		if absf(p.x) <= Tile.TW * 0.5 + 2 and absf(p.y) <= Tile.TH * 0.5 + 2:
			return i
	return -1


func _in_field(p: Vector2) -> bool:
	var par: = get_parent()
	if par is Control:
		return (par as Control).get_global_rect().has_point(p)
	return true


func _unhandled_input(e: InputEvent) -> void:
	if geo == null:
		return
	if dealing and e is InputEventScreenTouch and e.pressed and _in_field(e.position):
		_end_deal()
		get_viewport().set_input_as_handled()
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			if not _in_field(e.position):
				return
			_touch[e.index] = e.position
			if _touch.size() == 1:
				_press_pos = e.position
				_dragging = false
				_pinch = false
				_press_tile = tile_at(e.position) if input_on else -1
				if _press_tile >= 0:
					get_viewport().set_input_as_handled()
					if zoom <= 1.01:
						# no pan possible: answer on the very frame the finger lands
						var i: = _press_tile
						_press_tile = -1
						tap(i)
					else:
						(tiles[_press_tile] as Tile).press_glint()
			elif _touch.size() == 2:
				_pinch = true
				_press_tile = -1
				var ps: Array = _touch.values()
				_pinch_d0 = maxf(1.0, (ps[0] as Vector2).distance_to(ps[1]))
				_pinch_z0 = zoom
		else:
			if not _touch.has(e.index):
				return
			_touch.erase(e.index)
			if _touch.is_empty():
				if _press_tile >= 0 and not _dragging and not _pinch:
					var j: = _press_tile
					_press_tile = -1
					tap(j)
				elif not _dragging and not _pinch and _press_tile < 0 and tile_at(e.position) < 0:
					var now: = V10MjClassicStyle.now()
					if now - _last_empty_tap < DOUBLE_T and e.position.distance_to(_last_empty_pos) < 80.0:
						_last_empty_tap = -10.0
						zoom_to(1.0 if zoom > 1.3 else 2.0, e.position)
					else:
						_last_empty_tap = now
						_last_empty_pos = e.position
				_pinch = false
	elif e is InputEventScreenDrag:
		if not _touch.has(e.index):
			return
		_touch[e.index] = e.position
		if _pinch and _touch.size() >= 2:
			var ps2: Array = _touch.values()
			var d: = (ps2[0] as Vector2).distance_to(ps2[1])
			var mid: = ((ps2[0] as Vector2) + (ps2[1] as Vector2)) * 0.5
			_apply_zoom(clampf(_pinch_z0 * d / _pinch_d0, 1.0, ZOOM_MAX), mid, true)
			get_viewport().set_input_as_handled()
		elif zoom > 1.01:
			if not _dragging and e.position.distance_to(_press_pos) > 14.0:
				_dragging = true
				_press_tile = -1
			if _dragging:
				position += e.relative
				_clamp_pan()
				get_viewport().set_input_as_handled()
	elif e is InputEventMagnifyGesture:
		_apply_zoom(clampf(zoom * e.factor, 1.0, ZOOM_MAX), e.position, true)
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if _in_field(e.position):
			_apply_zoom(clampf(zoom * (1.12 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), 1.0, ZOOM_MAX), e.position, true)


func _apply_zoom(z: float, focus_global: Vector2, keep_focus: bool) -> void:
	var par: = get_parent() as CanvasItem
	var focus: = focus_global
	if par:
		focus = par.get_global_transform_with_canvas().affine_inverse() * focus_global
	var local: = (focus - position) / scale.x if scale.x > 0.0 else Vector2.ZERO
	zoom = z
	var s: = base_scale * zoom
	scale = Vector2(s, s)
	if zoom <= 1.001:
		position = base_pos
	elif keep_focus:
		position = focus - local * s
	_clamp_pan()


func zoom_to(z: float, focus_global: Vector2) -> void:
	if _zoom_tw and _zoom_tw.is_valid():
		_zoom_tw.kill()
	var z0: = zoom
	var par: = get_parent() as CanvasItem
	var focus: = focus_global
	if par:
		focus = par.get_global_transform_with_canvas().affine_inverse() * focus_global
	# keep the tapped point under the finger, and move it toward the field centre
	var local: = (focus - position) / scale.x
	var p0: = position
	_zoom_tw = create_tween()
	_zoom_tw.tween_method(func(v: float):
		zoom = lerpf(z0, z, v)
		var s: = base_scale * zoom
		scale = Vector2(s, s)
		var target: = field.get_center() - local * (base_scale * z) if z > 1.0 else base_pos
		var cur_keep: = focus - local * s
		position = cur_keep.lerp(target, v) if z > 1.0 else p0.lerp(base_pos, v)
		_clamp_pan(), 0.0, 1.0, 0.26).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	V9Feel.sound("whoosh", 1.3 if z > z0 else 1.1, -14.0)


func _clamp_pan() -> void:
	if zoom <= 1.001:
		position = base_pos
		return
	var s: = scale.x
	var b: = Rect2(bounds.position * s + position, bounds.size * s)
	var off: = Vector2.ZERO
	if b.size.x > field.size.x:
		if b.position.x > field.position.x:
			off.x = field.position.x - b.position.x
		elif b.end.x < field.end.x:
			off.x = field.end.x - b.end.x
	else:
		off.x = field.get_center().x - b.get_center().x
	if b.size.y > field.size.y:
		if b.position.y > field.position.y:
			off.y = field.position.y - b.position.y
		elif b.end.y < field.end.y:
			off.y = field.end.y - b.end.y
	else:
		off.y = field.get_center().y - b.get_center().y
	position += off


# ---- play -----------------------------------------------------------------------------------------------------
func tile_global(i: int) -> Vector2:
	var t: Tile = tiles[i]
	return t.get_global_transform_with_canvas().origin


func tap(i: int) -> void:
	if not input_on or i < 0 or not alive[i] or _anim.has(i):
		return
	var t: Tile = tiles[i]
	_clear_hint()
	if not geo.free_in(i, alive):
		t.deny()
		V9Feel.tile_tap(false)
		_show_blockers(i)
		denied.emit(t)
		return
	if sel == i:
		_select(-1)
		V9Feel.sound("tap", 0.9, -8.0)
		return
	if sel >= 0 and keys[sel] == keys[i]:
		take(sel, i)
		return
	t.press_glint()
	V9Feel.tile_tap(true)
	_select(i)
	picked.emit(t, tile_global(i))


func _select(i: int) -> void:
	if sel >= 0 and alive[sel]:
		var o: Tile = tiles[sel]
		o.set_selected(false)
		o.z_index = 0
		_halo(sel, false)
	sel = i
	if i >= 0:
		var t: Tile = tiles[i]
		t.scale = Vector2.ONE
		t.z_index = 50
		t.set_selected(true)
		_halo(i, true, Color("f1d9a0"))


# briefly light what keeps a closed tile closed (the tile on it, or both neighbours) — clarity for 45+
func _show_blockers(i: int) -> void:
	if fx_min:
		return
	for j in geo.blockers(i, alive):
		var b: Tile = tiles[j]
		if b.glow == null:
			continue
		b.glow.modulate = Color(V10MjClassicStyle.TOK.ember, 0.0)
		var tw: = b.create_tween()
		tw.tween_property(b.glow, "modulate:a", 0.75, 0.1)
		tw.tween_property(b.glow, "modulate:a", 0.0, 0.45)


# take a pair (both must be free and alike; `force` — a Приём may lift a covered pair); the rules state changes at
# once, the tiles animate after
var by_ult: = false                 # the pairs being taken now come from a Приём (the screen gives no charge for them)

func take(a: int, b: int, record: = true, force: = false) -> void:
	if a == b or not alive[a] or not alive[b] or keys[a] != keys[b]:
		return
	if not force and not (geo.free_in(a, alive) and geo.free_in(b, alive)):
		return
	_clear_lights()
	if record:
		history.append({"kind": "pair", "a": a, "b": b, "sel": sel, "cert": PackedInt32Array(cert)})
	if sel >= 0 and sel != a and sel != b:
		_select(-1)
	sel = -1
	alive[a] = 0
	alive[b] = 0
	moves += 1
	_repair_cert(a, b)
	var ta: Tile = tiles[a]
	var tb: Tile = tiles[b]
	var mid_l: = (ta.position + tb.position) * 0.5 + Vector2(0, -28)
	_fly_pair(a, b, mid_l)
	_update_free(true)
	var gp: = tile_layer.get_global_transform_with_canvas() * mid_l
	paired.emit(ta, tb, gp, keys[a], faces[a])
	changed.emit()
	if remaining() == 0:
		input_on = false
		get_tree().create_timer(0.42).timeout.connect(_emit_cleared)
	elif pairs_now().is_empty():
		input_on = false
		get_tree().create_timer(0.55).timeout.connect(auto_shuffle)


func _emit_cleared() -> void:
	cleared.emit()


# no pair is free: shuffle by itself (the screen shows «Ходов нет — перемешала» and she says it)
func auto_shuffle() -> void:
	if geo != null and remaining() > 0 and pairs_now().is_empty():
		shuffle(true)


func _fly_pair(a: int, b: int, mid: Vector2) -> void:
	var ta: Tile = tiles[a]
	var tb: Tile = tiles[b]
	for i in [a, b]:
		var t: Tile = tiles[i]
		_halo(i, false)
		t.selected = false
		if t.glow:
			t.glow.modulate.a = 0.0
		t.hint(false)
		t.kill_move()
		t.z_index = 300
		t.shadow.visible = false
	if fx_min:
		for i2 in [a, b]:
			(tiles[i2] as Tile).visible = false
		return
	var side: = Vector2(Tile.TW * 0.53, 0)
	var la: = mid - side if ta.position.x <= tb.position.x else mid + side
	var lb: = mid + side if ta.position.x <= tb.position.x else mid - side
	for pair in [[a, ta, la], [b, tb, lb]]:
		var i3: int = pair[0]
		var t3: Tile = pair[1]
		var dst: Vector2 = pair[2]
		var tw: = t3.create_tween()
		_anim[i3] = tw
		tw.tween_property(t3, "position", dst, 0.17).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(t3, "scale", Vector2(1.1, 1.1), 0.17)
		tw.tween_property(t3, "scale", Vector2(1.16, 0.9), 0.05)
		tw.tween_property(t3, "scale", Vector2(0.2, 0.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t3, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func():
			t3.visible = false
			_anim.erase(i3))
	var host: = tile_layer
	get_tree().create_timer(0.18).timeout.connect(func():
		if not is_instance_valid(host):
			return
		V9Feel.sound("clack%d" % (randi() % 3), randf_range(0.95, 1.08), -2.0)
		if V9Feel.can_fx():
			Fx.burst(host, mid, "sparkle", 10, accent.lightened(0.25), 0.8)
			Fx.ring(host, mid, accent, 1.2, 0.4))


func _repair_cert(a: int, b: int) -> void:
	cert = _repaired(cert, a, b, alive)


# the live certificate after the pair (a, b) left: their two partners pair up at one of the two old places, if the
# result still clears (alive_after has a and b gone). Empty when it does not (the hint then searches).
func _repaired(cc: PackedInt32Array, a: int, b: int, alive_after: PackedByteArray) -> PackedInt32Array:
	if cc.is_empty():
		return cc
	var m: = cc.size() / 2
	var ka: = -1
	var kb: = -1
	for k in m:
		if cc[2 * k] == a or cc[2 * k + 1] == a:
			ka = k
		if cc[2 * k] == b or cc[2 * k + 1] == b:
			kb = k
	if ka < 0 or kb < 0:
		return PackedInt32Array()
	if ka == kb:
		var c: = PackedInt32Array()
		for k in m:
			if k != ka:
				c.append(cc[2 * k])
				c.append(cc[2 * k + 1])
		return c
	var pa: int = cc[2 * ka + 1] if cc[2 * ka] == a else cc[2 * ka]
	var pb: int = cc[2 * kb + 1] if cc[2 * kb] == b else cc[2 * kb]
	for at in [ka, kb]:
		var c2: = PackedInt32Array()
		for k in m:
			if k == at:
				c2.append(pa)
				c2.append(pb)
			elif k != ka and k != kb:
				c2.append(cc[2 * k])
				c2.append(cc[2 * k + 1])
		if V10MjClassicGen.certify(geo, c2, keys, alive_after):
			return c2
	return PackedInt32Array()


func _restore_tile(i: int) -> void:
	var t: Tile = tiles[i]
	if _anim.has(i):
		var tw: Tween = _anim[i]
		if tw and tw.is_valid():
			tw.kill()
		_anim.erase(i)
	t.kill_move()
	_halo(i, false)
	t.visible = true
	t.modulate = Color.WHITE
	t.scale = Vector2.ONE
	t.position = t.home
	t.z_index = 0
	t.selected = false
	t.shadow.visible = true
	if t.mat:
		t.mat.set_shader_parameter("sel", 0.0)
	if t.glow:
		t.glow.modulate.a = 0.0


func undo() -> bool:
	if history.is_empty() or not _can_act():
		return false
	var h: Dictionary = history.pop_back()
	_clear_hint()
	if sel >= 0:
		_select(-1)
	if h.kind == "shuffle":
		_restore_snapshot(h)
		if h.get("auto", false) and not history.is_empty() and history[-1].kind == "pair":
			# the state before an automatic shuffle had no moves: go back past the pair that led there
			_undo_pair(history.pop_back())
	else:
		_undo_pair(h)
	undos += 1
	_update_free(true)
	input_on = true
	V9Feel.sound("whoosh", 0.9, -10.0)
	changed.emit()
	return true


func _undo_pair(h: Dictionary) -> void:
	var a: int = h.a
	var b: int = h.b
	alive[a] = 1
	alive[b] = 1
	moves -= 1
	cert = PackedInt32Array(h.cert)
	for i in [a, b]:
		_restore_tile(i)
		var t: Tile = tiles[i]
		if not fx_min:
			t.scale = Vector2(0.6, 0.6)
			t.modulate.a = 0.0
			var tw: = t.create_tween().set_parallel()
			tw.tween_property(t, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(t, "modulate:a", 1.0, 0.16)


func _snapshot(auto: bool) -> Dictionary:
	return {"kind": "shuffle", "auto": auto, "alive": PackedByteArray(alive), "faces": PackedInt32Array(faces),
		"keys": PackedInt32Array(keys), "cert": PackedInt32Array(cert), "shuffles": shuffles}


func _restore_snapshot(h: Dictionary) -> void:
	alive = PackedByteArray(h.alive)
	faces = PackedInt32Array(h.faces)
	keys = PackedInt32Array(h.keys)
	cert = PackedInt32Array(h.cert)
	for i in geo.n:
		var t: Tile = tiles[i]
		if alive[i]:
			_restore_tile(i)
			if t.face != faces[i]:
				t.set_face(faces[i])
		else:
			t.visible = false
		_mark(i)


func _can_act() -> bool:
	return geo != null and (input_on or (remaining() > 0 and pairs_now().is_empty()))


# shuffle the tiles left (button «Перемешать» or automatic when no pair is free): solvable by construction
func shuffle(auto: = false) -> void:
	if geo == null or remaining() == 0:
		return
	_clear_hint()
	if sel >= 0:
		_select(-1)
	history.append(_snapshot(auto))
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(deal.get("seed", 1)) * 7919 + moves * 131 + (shuffles + auto_shuffles) * 17 + 1
	var r: = V10MjClassicGen.reshuffle(geo, alive, faces, rng, base_order)
	var old_alive: = PackedByteArray(alive)
	alive = r.alive
	faces = r.faces
	keys = r.keys
	cert = r.order
	if auto:
		auto_shuffles += 1
	else:
		shuffles += 1
	input_on = false
	_shuffle_show(old_alive)
	shuffled.emit(auto)
	changed.emit()


func _shuffle_show(old_alive: PackedByteArray) -> void:
	var centre: = bounds.get_center()
	var maxd: = 1.0
	for i in geo.n:
		maxd = maxf(maxd, (tiles[i] as Tile).home.distance_to(centre))
	V9Feel.sound("whoosh", 0.8, -4.0)
	for i in geo.n:
		var t: Tile = tiles[i]
		if not alive[i]:
			if old_alive[i]:
				var tw0: = t.create_tween()
				tw0.tween_property(t, "modulate:a", 0.0, 0.25)
				tw0.tween_callback(func(): t.visible = false; t.modulate.a = 1.0)
			continue
		_restore_tile(i)
		_mark(i)
		var delay: = 0.25 * t.home.distance_to(centre) / maxd
		if fx_min:
			t.set_face(faces[i])
			continue
		if not old_alive[i]:
			t.modulate.a = 0.0
		var f: = faces[i]
		var tw: = t.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(t, "position", t.home + Vector2(0, -16), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(t, "modulate:a", 1.0, 0.12)
		tw.tween_property(t, "scale", Vector2(0.0, 1.08), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): t.set_face(f))
		tw.tween_property(t, "scale", Vector2(1.06, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(t, "position", t.home, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(t, "scale", Vector2.ONE, 0.14)
	_update_free(true)
	get_tree().create_timer(0.0 if fx_min else 0.85).timeout.connect(func():
		for i in geo.n:
			if alive[i] and (tiles[i] as Tile).face != faces[i]:
				(tiles[i] as Tile).set_face(faces[i])
		input_on = true
		V9Feel.sound("clack1", 1.15, -6.0))


# hint: the next pair of the live certificate, else a short search, else any pair
func hint_pair() -> Array:
	if not cert.is_empty() and V10MjClassicGen.certify(geo, cert, keys, alive):
		var m: = cert.size() / 2
		return [cert[2 * (m - 1)], cert[2 * (m - 1) + 1]]
	var path: = V10MjClassicGen.solve(geo, alive, keys, 500)
	if path.size() >= 2:
		return [path[0], path[1]]
	var ps: = pairs_now()
	return ps[0] if not ps.is_empty() else []


func hint() -> bool:
	if not input_on or geo == null:
		return false
	var p: = hint_pair()
	if p.is_empty():
		shuffle(true)
		return false
	hints += 1
	if sel >= 0:
		_select(-1)
	_clear_hint()
	for i in p:
		(tiles[i] as Tile).scale = Vector2.ONE
		(tiles[i] as Tile).hint(true)
		_halo(i, true, Color("4fe0b0"), true)
		_hinted.append(i)
	V9Feel.sound("sparkle", 1.2, -10.0)
	changed.emit()
	return true


func _clear_hint() -> void:
	for i in _hinted:
		if i < tiles.size() and tiles[i]:
			(tiles[i] as Tile).hint(false)
			if i != sel:
				_halo(i, false)
	_hinted.clear()
	_clear_lights()


func _clear_lights() -> void:
	for i in _lights:
		if i < tiles.size() and tiles[i] and i != sel and not _hinted.has(i):
			_halo(i, false)
	_lights.clear()


func _light(ids: Array, col: Color, pulse: bool, t: float) -> void:
	for i in ids:
		if alive[i]:
			_halo(i, true, col, pulse and not fx_min)
			_lights.append(i)
	var my: = _lights.duplicate()
	get_tree().create_timer(t).timeout.connect(func():
		if _lights == my:
			_clear_lights())


# ---- Приёмы (MODES §5.5) ---------------------------------------------------------------------------------------
# mc / hana: n pairs of the live certificate (the safest moves on the table). -> the pairs taken
func ult_take(n: int) -> Array:
	var out: = []
	by_ult = true
	for k in n:
		if remaining() == 0:
			break
		var p: = hint_pair()
		if p.size() < 2:
			break
		take(p[0], p[1])
		out.append(p)
	by_ult = false
	return out


# nova: the deepest pair on the table, even a covered one — the lowest layers first, then the most tiles lying on
# it — as long as the table keeps a certificate without it. -> the pairs taken
func ult_deep() -> Array:
	var by: = {}
	for i in geo.n:
		if alive[i]:
			if not by.has(keys[i]):
				by[keys[i]] = []
			by[keys[i]].append(i)
	var cands: = []
	for k in by:
		var l: Array = by[k]
		for x in l.size():
			for y in range(x + 1, l.size()):
				var a: int = l[x]
				var b: int = l[y]
				cands.append([float(geo.pos[a].z + geo.pos[b].z) * 10.0 - float(_on_top(a) + _on_top(b)), a, b])
	cands.sort_custom(func(p, q): return p[0] < q[0])
	var al: = PackedByteArray(alive)
	for c in cands.slice(0, 60):
		var a2: int = c[1]
		var b2: int = c[2]
		al[a2] = 0
		al[b2] = 0
		var ok: = remaining() == 2 or not _repaired(cert, a2, b2, al).is_empty()
		al[a2] = 1
		al[b2] = 1
		if ok:
			by_ult = true
			take(a2, b2, true, true)
			by_ult = false
			return [[a2, b2]]
	return ult_take(1)


func _on_top(i: int) -> int:
	var n: = 0
	for j in geo.cover[i]:
		n += alive[j]
	return n


# rin: a pair that is still closed (the next one of the certificate that cannot be taken yet) and the tiles that
# keep it closed — «the pair and the way to it», lit for t seconds. -> {pair, path}
func show_path(t: = 3.0) -> Dictionary:
	_clear_hint()
	var pair: Array = []
	if not cert.is_empty() and V10MjClassicGen.certify(geo, cert, keys, alive):
		var m: = cert.size() / 2
		for k in range(m - 1, -1, -1):
			var a: int = cert[2 * k]
			var b: int = cert[2 * k + 1]
			if not (geo.free_in(a, alive) and geo.free_in(b, alive)):
				pair = [a, b]
				break
	if pair.is_empty():
		pair = hint_pair()
	if pair.is_empty():
		return {}
	var path: = {}
	for i in pair:
		for j in geo.blockers(i, alive):
			path[j] = true
	_light(pair, JADE, true, t)
	_light(path.keys(), GOLD, false, t)
	V9Feel.sound("sparkle", 1.1, -8.0)
	return {"pair": pair, "path": path.keys()}


# yue: every free pair lit for t seconds. -> the pairs
func show_pairs(t: = 3.0) -> Array:
	_clear_hint()
	var ps: = pairs_now()
	var lit: = {}
	for p in ps:
		for i in p:
			lit[i] = true
	_light(lit.keys(), JADE, false, t)
	V9Feel.sound("sparkle", 1.3, -8.0)
	return ps


func set_view(v: String) -> void:
	if v == view:
		return
	view = v
	var old: = {}
	for i in geo.n:
		old[i] = (tiles[i] as Tile).home
	_layout_tiles()
	fit(field)
	for i in geo.n:
		var t: Tile = tiles[i]
		if not alive[i] or _anim.has(i) or fx_min:
			continue
		t.position = old[i] - (bounds.get_center() * 0.0)
		t.create_tween().tween_property(t, "position", t.home, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func set_light(on: bool) -> void:
	light = on
	_update_free(true)


# the win: the camera pulls back (zoom 1, then the whole form a little smaller, centred)
func pull_back() -> void:
	if geo == null:
		return
	if _zoom_tw and _zoom_tw.is_valid():
		_zoom_tw.kill()
	zoom = 1.0
	var s1: = base_scale * 0.9
	var p1: = field.get_center() - bounds.get_center() * s1
	if fx_min:
		scale = Vector2(s1, s1)
		position = p1
		return
	_zoom_tw = create_tween().set_parallel()
	_zoom_tw.tween_property(self, "scale", Vector2(s1, s1), 0.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_zoom_tw.tween_property(self, "position", p1, 0.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


# the win: the empty form flashes in her colour (MODES §4.1)
func flash_form(col: Color) -> void:
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	var g: = _FormGhost.new()
	g.board = self
	g.col = col
	tile_layer.add_child(g)
	_ghost = g
	if fx_min:
		g.k = 0.6
		g.queue_redraw()
		g.create_tween().tween_property(g, "k", 0.22, 0.12).set_delay(0.6)
		return
	var tw: = g.create_tween()
	tw.tween_property(g, "k", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(g, "k", 0.55, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(g, "k", 0.22, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)  # the empty form stays, faint


class _FormGhost:
	extends Node2D
	var board: V10MjClassicBoard
	var col: = Color.WHITE
	var k: = 0.0:
		set(v):
			k = v
			queue_redraw()

	func _draw() -> void:
		if k <= 0.001 or board == null:
			return
		var idx: Array = range(board.geo.n)
		idx.sort_custom(func(a, b): return board.geo.pos[a].z < board.geo.pos[b].z)
		for i in idx:
			var h: Vector2 = (board.tiles[i] as Tile).home
			var z: = float(board.geo.pos[i].z)
			var r: = Rect2(h - Vector2(Tile.TW, Tile.TH) * 0.5 + Vector2(3, 3), Vector2(Tile.TW, Tile.TH) - Vector2(6, 6))
			var c: = col.lightened(0.12 * z)
			draw_rect(r.grow(6.0 * k), Color(c, 0.10 * k))
			draw_rect(r, Color(c, 0.42 * k))
			draw_rect(r, Color(c.lightened(0.4), 0.8 * k), false, 2.0)
