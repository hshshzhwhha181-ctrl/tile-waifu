class_name V10MjGardenBoard
extends Node2D

# V10MjGardenBoard — стол Сада 2.0 (docs/MODES.md §4.9). Фишки — обычные Tile (материал и свет дорожки look через
# V10MjTileMaterial.dress), правила — V10MjGardenRules (одна правда с ботом и самотестом). TrayBoard не меняется
# и не наследуется: от него только формы раскладок и шаг сетки.
#
# Ощущение:
#   тап по свободной фишке — блик и «тук», полёт в лоток по дуге 0,26 с, посадка со сжатием; такая же в лотке —
#   фишка встаёт рядом с ней, обе поднимаются и тают тёплым светом (сигнал paired);
#   6/6 без пары — «чашка переливается»: лоток вздрагивает, три последние фишки по дуге возвращаются на свои места
#   (сигнал spilled); закрытая фишка — короткое «нет» и «дерево»;
#   новая волна «доливается» с краёв: левая половина въезжает слева, правая — справа, лесенкой ≤ 0,35 с, каждая
#   фишка едет 0,45 с; пока фишка едет, её нельзя взять (старые фишки берутся сразу после блока ввода ≤ 0,3 с).
# Блок ввода (только когда героиня-заглушка выходит на волне): ранние тапы не теряются — встают в очередь и
# исполняются по окончании блока (MODES §3.2: ввод ≤ 0,3 с, ранние тапы в очереди).

signal picked(id: int, gpos: Vector2)
signal placed(id: int)
signal paired(a: int, b: int, gpos: Vector2, series: int, gain: int)
signal spilled(back: Array)
signal poured(ids: Array)
signal denied(id: int)
signal tray_changed

const UX: = Tile.TW * 0.5 + 1.0
const UY: = Tile.TH * 0.5 + 1.0
const DZ: = Vector2(-6.0, -13.0)
const FLY: = 0.26
const SHIFT: = 0.12
const SLIDE: = 0.45
const STAGGER: = 0.35
const MAX_BLOCK: = 0.3
const FIELD_Z: = 3

var rules: V10MjGardenRules
var tiles: = {}                 # id -> Tile
var tile_layer: Node2D
var bounds: = Rect2()           # поле в локальных координатах (вся сетка 7 × 7 × 3 — одинаково для всех волн)
var cells: Array[Vector2] = []  # центры ячеек лотка (экран)
var tile_w: = 84.0
var display: Array[int] = []    # порядок фишек в лотке на экране
var vanishing: = {}
var flying: = {}
var landing: = {}               # id -> true, пока фишка волны въезжает
var input_on: = false
var look: = {}
var light: = {}
var accent: = Color("c8b6ff")
var fx_min: = false
var warm: = 0.0                 # 0 — день, 1 — ночь: тёплый блик фишек (лампа над столом)
var max_tray: = 0
var _block_until: = 0.0
var _block_from: = 0.0
var max_block_seen: = 0.0
var queued: Array[int] = []     # id, тапнутые во время блока
var queued_total: = 0
var replayed_total: = 0
var _gen: = 0


func _ready() -> void:
	set_meta("v9_feel", true)
	tile_layer = Node2D.new()
	tile_layer.name = "Tiles"
	add_child(tile_layer)
	var maxx: = V10MjGardenRules.FIELD_X
	var maxy: = V10MjGardenRules.FIELD_Y
	var w: = maxx * UX + Tile.TW
	var h: = maxy * UY + Tile.TH
	bounds = Rect2(Vector2(-Tile.TW * 0.5, -Tile.TH * 0.5) + DZ * FIELD_Z, Vector2(w, h) - DZ * FIELD_Z + Vector2(10, 16))


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


static func home_of(p: Vector3i) -> Vector2:
	return Vector2(p.x * UX, p.y * UY) + DZ * p.z


func fit_into(r: Rect2, max_scale: = 1.3) -> void:
	var s: float = minf(minf(r.size.x / bounds.size.x, r.size.y / bounds.size.y), max_scale)
	scale = Vector2(s, s)
	position = r.get_center() - bounds.get_center() * s


func screen_rect() -> Rect2:
	return Rect2(position + bounds.position * scale.x, bounds.size * scale.x)


func set_tray(centers: Array, tw: float) -> void:
	cells.clear()
	for c in centers:
		cells.append(c)
	tile_w = tw
	_layout_tray()


# ── сборка ───────────────────────────────────────────────────────────────────

func load_rules(r: V10MjGardenRules, lk: Dictionary, lt: Dictionary) -> void:
	_gen += 1
	for id in tiles:
		(tiles[id] as Tile).queue_free()
	tiles.clear()
	display.clear()
	vanishing.clear()
	flying.clear()
	landing.clear()
	rules = r
	look = lk
	light = lt
	for id in r.board_ids():
		_make_tile(id)
	for id in r.tray:
		var t: = _make_tile(id)
		t.shadow.visible = false
		t.z_index = 200 + display.size()
		display.append(id)
	_sort()
	_layout_tray(-1, true)
	reveal_free(false)


func _make_tile(id: int) -> Tile:
	var p: Vector3i = rules.at[id]
	var t: = Tile.new()
	t.gx = p.x
	t.gy = p.y
	t.gz = p.z
	t.face = int(rules.face[id])
	t.home = home_of(p)
	t.position = t.home
	var base: Dictionary = look if not look.is_empty() else G.skin_look()
	t.build(base)
	if base.has("v10mj"):
		V10MjTileMaterial.dress(t, base, light)
	if t.mat:
		t.mat.set_shader_parameter("dim", 0.0)
	V10TileMarks.attach(t)
	tile_layer.add_child(t)
	tiles[id] = t
	t.set_meta("id", id)
	return t


# порядок отрисовки: нижний ярус раньше, дальний ряд раньше
func _sort() -> void:
	var ids: = tiles.keys()
	ids.sort_custom(func(a, b):
		var pa: Vector3i = rules.at.get(a, Vector3i.ZERO)
		var pb: Vector3i = rules.at.get(b, Vector3i.ZERO)
		return pa.z * 100000 + pa.y * 100 + pa.x < pb.z * 100000 + pb.y * 100 + pb.x)
	for k in ids.size():
		tile_layer.move_child(tiles[ids[k]], k)


func set_light(lt: Dictionary, warm_k: float) -> void:
	light = lt
	warm = warm_k
	for id in tiles:
		var t: Tile = tiles[id]
		if t.mat:
			V10MjTileMaterial.apply_light(t.mat, lt)
		if t.side_j and t.side_j.material is ShaderMaterial:
			V10MjTileMaterial.apply_light(t.side_j.material, lt)


func reveal_free(animate: = true) -> void:
	for id in tiles:
		if not rules.on_board(id) or landing.has(id):
			continue
		var t: Tile = tiles[id]
		var f: = rules.is_free(id)
		t.set_free(f, animate)
		if t.side_j and t.side_j.material is ShaderMaterial:
			V10MjTileMaterial.tile_state(t, f, not f, int(id), accent)


func tile_at(gp: Vector2) -> int:
	var lp: = tile_layer.get_global_transform_with_canvas().affine_inverse() * gp
	var best: = -1
	var best_key: = -1
	for id in tiles:
		if not rules.on_board(id) or landing.has(id) or flying.has(id):
			continue
		var t: Tile = tiles[id]
		if t.hit(lp):
			var p: Vector3i = rules.at[id]
			var key: = p.z * 100000 + p.y * 100 + p.x
			if key > best_key:
				best_key = key
				best = id
	return best


func gpos(id: int) -> Vector2:
	return tile_layer.get_global_transform_with_canvas() * (tiles[id] as Tile).position


# ── ввод ─────────────────────────────────────────────────────────────────────

func block(seconds: float) -> void:
	var t: = now()
	if not is_blocked():
		_block_from = t
	_block_until = minf(maxf(_block_until, t + seconds), _block_from + MAX_BLOCK)
	max_block_seen = maxf(max_block_seen, _block_until - _block_from)


func is_blocked() -> bool:
	return now() < _block_until


func _process(_dt: float) -> void:
	if not queued.is_empty() and not is_blocked():
		var q: = queued.duplicate()
		queued.clear()
		for id in q:
			replayed_total += 1
			tap(id)


func _unhandled_input(e: InputEvent) -> void:
	if not input_on:
		return
	if e is InputEventScreenTouch and e.pressed:
		var id: = tile_at(e.position)
		if id >= 0:
			get_viewport().set_input_as_handled()
			if is_blocked():
				queued.append(id)
				queued_total += 1
			else:
				tap(id)


# ── ход ──────────────────────────────────────────────────────────────────────

func tap(id: int) -> bool:
	if not tiles.has(id) or not rules.on_board(id) or landing.has(id):
		return false
	var t: Tile = tiles[id]
	if not rules.is_free(id):
		t.deny()
		denied.emit(id)
		return false
	picked.emit(id, gpos(id))
	var res: = rules.pick(id)
	if not res.ok:
		return false
	t.press_glint()
	t.kill_move()
	t.hint(false)
	t.shadow.visible = false
	t.z_index = 200 + display.size()
	_display_insert(id, res.pair)
	max_tray = maxi(max_tray, display.size() - vanishing.size())
	flying[id] = true
	_layout_tray(id)
	reveal_free()
	tray_changed.emit()
	var gen: = _gen
	var pair: Array = res.pair
	var back: Array = res.back
	var series: int = res.series
	var gain: int = res.gain
	get_tree().create_timer(FLY).timeout.connect(func():
		if gen != _gen:
			return
		flying.erase(id)
		placed.emit(id)
		if not pair.is_empty():
			_vanish_pair(pair, series, gain)
		elif not back.is_empty():
			_spill(back))
	return true


func _display_insert(id: int, pair: Array) -> void:
	if not pair.is_empty():
		var twin: int = pair[0]
		var at: = display.find(twin)
		vanishing[twin] = true
		vanishing[id] = true
		if at >= 0:
			display.insert(at + 1, id)
			return
	display.append(id)


func _tray_scale() -> float:
	return tile_w / (Tile.TW * scale.x)


func _cell_local(k: int, n: int) -> Vector2:
	var cnt: = cells.size()
	if cnt == 0:
		return Vector2.ZERO
	var g: Vector2
	if n <= cnt:
		g = cells[clampi(k, 0, cnt - 1)]
	else:
		g = (cells[0] as Vector2).lerp(cells[cnt - 1], float(k) / float(n - 1))
	return tile_layer.get_global_transform_with_canvas().affine_inverse() * g


func _tw(t: Tile) -> Tween:
	t.kill_move()
	var old = t.get_meta("tw") if t.has_meta("tw") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw: = t.create_tween()
	t.set_meta("tw", tw)
	return tw


func _layout_tray(arriving: = -1, instant: = false) -> void:
	var n: = display.size()
	var sc: = _tray_scale() * (1.0 if n <= cells.size() else float(cells.size()) / n * 1.04)
	for k in n:
		var id: = display[k]
		if not tiles.has(id):
			continue
		var t: Tile = tiles[id]
		var target: = _cell_local(k, n)
		if instant:
			t.position = target
			t.scale = Vector2(sc, sc)
			continue
		if id == arriving:
			_fly(t, target, sc)
		elif t.has_meta("fading"):
			continue
		elif flying.has(id):
			t.set_meta("target", target)
		else:
			var tw: = _tw(t).set_parallel()
			tw.tween_property(t, "position", target, SHIFT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(t, "scale", Vector2(sc, sc), SHIFT)


# полёт в лоток: квадратичная Безье, на посадке сжатие и отскок
func _fly(t: Tile, target: Vector2, sc: float) -> void:
	var from: = t.position
	var s0: = t.scale.x
	var lift: = 60.0 / maxf(0.3, scale.x)
	var ctrl: = Vector2(lerpf(from.x, target.x, 0.35), minf(from.y, target.y) - lift)
	t.set_meta("target", target)
	var tw: = _tw(t)
	if fx_min:
		tw.tween_property(t, "position", target, 0.12)
		tw.parallel().tween_property(t, "scale", Vector2(sc, sc), 0.12)
		return
	tw.tween_method(func(v: float):
		var u: = 1.0 - v
		var tg: Vector2 = t.get_meta("target", target)
		t.position = from * u * u + ctrl * 2.0 * u * v + tg * v * v
		var k: = lerpf(s0, sc, v) * (1.0 + 0.1 * sin(v * PI))
		t.scale = Vector2(k, k)
		t.rotation = sin(v * PI) * 0.05 * signf(target.x - from.x), 0.0, 1.0, FLY).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(t, "scale", Vector2(sc * 1.05, sc * 0.92), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "scale", Vector2(sc, sc), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# пара: обе фишки чуть поднимаются, вспыхивают тёплым светом и тают
func _vanish_pair(pair: Array, series: int, gain: int) -> void:
	var a: int = pair[0]
	var b: int = pair[1]
	var mid: = Vector2.ZERO
	var ts: Array[Tile] = []
	for id in pair:
		if tiles.has(id):
			ts.append(tiles[id])
			mid += (tiles[id] as Tile).position
	if ts.is_empty():
		return
	mid /= float(ts.size())
	for k in ts.size():
		var t: Tile = ts[k]
		t.set_meta("fading", true)
		t.z_index = 320
		if t.mat:
			t.mat.set_shader_parameter("flash_col", Vector3(accent.r, accent.g, accent.b))
		var tw: = _tw(t)
		var side: = -1.0 if k == 0 else 1.0
		if not fx_min:
			tw.tween_property(t, "position", t.position + Vector2(side * 6.0, -14.0) / scale.x, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(t, "rotation", side * 0.12, 0.12)
		if t.mat:
			tw.parallel().tween_method(func(v): t.mat.set_shader_parameter("flash", v), 0.0, 0.65, 0.12)
		tw.tween_property(t, "position", mid + Vector2(0, -30.0) / scale.x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "scale", t.scale * 0.6, 0.18)
		tw.parallel().tween_property(t, "modulate:a", 0.0, 0.18)
		tw.tween_callback(t.hide)
	var g: = tile_layer.get_global_transform_with_canvas() * mid
	paired.emit(a, b, g, series, gain)
	var gen: = _gen
	get_tree().create_timer(0.32).timeout.connect(func():
		if gen != _gen:
			return
		for id in pair:
			display.erase(id)
			vanishing.erase(id)
			if tiles.has(id):
				(tiles[id] as Tile).queue_free()
				tiles.erase(id)
		_layout_tray()
		tray_changed.emit())


# перелив: лоток вздрагивает, три последние по дуге — домой
func _spill(back: Array) -> void:
	for id in display:
		if not tiles.has(id) or back.has(id):
			continue
		var t: Tile = tiles[id]
		var p: = t.position
		var tw: = _tw(t)
		for k in 3:
			tw.tween_property(t, "position", p + Vector2(0, (5.0 if k % 2 == 0 else -3.0)) / scale.x, 0.06)
		tw.tween_property(t, "position", p, 0.06)
	spilled.emit(back)
	var k: = 0
	for id in back:
		display.erase(id)
		if tiles.has(id):
			_home_fly(tiles[id], 0.08 + k * 0.07)
		k += 1
	_layout_tray()
	var gen: = _gen
	get_tree().create_timer(0.5).timeout.connect(func():
		if gen != _gen:
			return
		_sort()
		reveal_free()
		tray_changed.emit())


func _home_fly(t: Tile, delay: = 0.0) -> void:
	var from: = t.position
	var to: = t.home
	var ctrl: = (from + to) * 0.5 + Vector2(0, -70.0 / scale.x)
	var s0: = t.scale.x
	t.remove_meta("target")
	var id: int = t.get_meta("id", -1)
	flying[id] = true
	var tw: = _tw(t)
	tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		var u: = 1.0 - v
		t.position = from * u * u + ctrl * 2.0 * u * v + to * v * v
		t.scale = Vector2.ONE * lerpf(s0, 1.0, v)
		t.rotation = sin(v * PI) * 0.18, 0.0, 1.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		flying.erase(id)
		t.rotation = 0.0
		t.z_index = 0
		t.shadow.visible = true)


func busy() -> bool:
	return not flying.is_empty() or not vanishing.is_empty() or not landing.is_empty()


# ── волна ────────────────────────────────────────────────────────────────────

# долить волну (позиции и лица генератора уже согласованы с rules): фишки въезжают с краёв
func pour(wave: Dictionary, animate: = true) -> Array[int]:
	var ids: = rules.pour(wave.pos, wave.faces)
	var mid_x: = V10MjGardenRules.FIELD_X * 0.5
	var travel: = bounds.size.x * 0.75
	var last: = 0.0
	for id in ids:
		var t: = _make_tile(id)
		if not animate or fx_min:
			if fx_min and animate:
				t.modulate.a = 0.0
				t.create_tween().tween_property(t, "modulate:a", 1.0, 0.12)
			continue
		var p: Vector3i = rules.at[id]
		var from_left: = float(p.x) < mid_x or (is_equal_approx(float(p.x), mid_x) and p.y % 4 == 0)
		var dist: = (float(p.x) / mid_x) if from_left else ((V10MjGardenRules.FIELD_X - float(p.x)) / mid_x)
		var delay: = clampf(dist * STAGGER * 0.6 + p.z * 0.06 + (p.y % 3) * 0.02, 0.0, STAGGER)
		last = maxf(last, delay)
		t.position = t.home + Vector2(-travel if from_left else travel, 0)
		t.modulate.a = 0.0
		landing[id] = true
		var tw: = t.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(t, "modulate:a", 1.0, 0.16)
		tw.parallel().tween_property(t, "position", t.home, SLIDE).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		var gen: = _gen
		var tid: = id
		tw.tween_callback(func():
			if gen != _gen:
				return
			landing.erase(tid)
			reveal_free())
	_sort()
	reveal_free(false)
	poured.emit(ids)
	return ids


func land_now() -> void:
	for id in landing.keys():
		if tiles.has(id):
			var t: Tile = tiles[id]
			t.kill_move()
			t.position = t.home
			t.modulate.a = 1.0
	landing.clear()
	reveal_free(false)


# подсказка: подсветить фишки на 2,5 с
func show_hint(ids: Array) -> void:
	for id in ids:
		if tiles.has(id) and rules.on_board(id):
			var t: Tile = tiles[id]
			t.hint(true)
			get_tree().create_timer(2.5).timeout.connect(func():
				if is_instance_valid(t):
					t.hint(false))
