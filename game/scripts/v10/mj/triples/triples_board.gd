class_name V10MjTriplesBoard
extends Node2D

# V10MjTriplesBoard — стол Троек (docs/MODES.md §4.2). Фишки — обычные Tile (материал, кромка, свет V6TileLook),
# раскладка — TWFree.gen_layout через V10MjTriplesGen; правила — V10MjTriplesRules (одна правда с ботом и
# самотестом). TrayBoard не меняется и не наследуется.
#
# Ощущение (всё по таймингам спеки):
#   тап по свободной фишке — мгновенный блик и «тук», полёт в лоток по дуге Безье 0,28 с, на посадке сжатие 0,9 →
#   отскок 1,05 → 1,0; одинаковые встают рядом — соседи раздвигаются за 0,12 с; три одинаковые раскрываются веером
#   (±0,22 рад, ×1,1, тёплый блик) и схлопываются — сигнал tripled (экран шлёт presence.pair и частицы в её окно);
#   закрытая фишка — короткое «нет» и «дерево»; 7/7 без тройки — лоток вздрагивает, сигнал lost.
#
# Помощь и Приёмы — визуальные двойники методов правил: return_last, add_slot, reshuffle, magnet, vanish, bless.

signal picked(i: int, gpos: Vector2)
signal placed(i: int, face: int)
signal tripled(face: int, gpos: Vector2, combo: int, from_ult: bool)
signal tray_changed
signal lost
signal cleared
signal denied(i: int)

const UX: = Tile.TW * 0.5 + 1.0
const UY: = Tile.TH * 0.5 + 1.0
const DZ: = Vector2(-6.0, -13.0)
const FLY: = 0.28
const SHIFT: = 0.12
const COMBO_WINDOW: = 4.0

var rules: V10MjTriplesRules
var lv: = {}
var tiles: Array[Tile] = []
var tile_layer: Node2D
var bounds: = Rect2()
var cells: Array[Vector2] = []     # центры ячеек лотка в координатах экрана
var tile_w: = 82.0
var display: Array[int] = []
var collapsing: = {}
var flying: = {}
var input_on: = false
var dealing: = false
var combo: = 0
var last_triple_t: = -99.0
var helped: = false
var max_tray: = 0
var accent: = Color("ff8fb8")
var fx_min: = false
var signature_face: = -1
var _gen: = 0


func _ready() -> void:
	set_meta("v9_feel", true)
	tile_layer = Node2D.new()
	tile_layer.name = "Tiles"
	add_child(tile_layer)


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func setup(level: Dictionary, look: Dictionary = {}) -> void:
	lv = level
	for t in tiles:
		t.queue_free()
	tiles.clear()
	display.clear()
	collapsing.clear()
	flying.clear()
	combo = 0
	helped = false
	max_tray = 0
	rules = V10MjTriplesRules.make(level.pos, level.faces)
	var lk: = look if not look.is_empty() else G.skin_look()
	var minx: = 999
	var miny: = 999
	var maxx: = -999
	var maxy: = -999
	var maxz: = 0
	for p in level.pos:
		minx = mini(minx, p.x)
		miny = mini(miny, p.y)
		maxx = maxi(maxx, p.x)
		maxy = maxi(maxy, p.y)
		maxz = maxi(maxz, p.z)
	var w: = (maxx - minx) * UX + Tile.TW
	var h: = (maxy - miny) * UY + Tile.TH
	var off: = Vector2(-w * 0.5 + Tile.TW * 0.5, -h * 0.5 + Tile.TH * 0.5) - DZ * maxz * 0.5
	for i in level.pos.size():
		var p: Vector3i = level.pos[i]
		var t: = Tile.new()
		t.gx = p.x
		t.gy = p.y
		t.gz = p.z
		t.face = int(level.faces[i])
		t.secret = bool(level.get("hidden", false)) and rules.cnt[i] > 0
		t.home = off + Vector2((p.x - minx) * UX, (p.y - miny) * UY) + DZ * p.z
		t.position = t.home
		t.build(lk)
		t.mat.set_shader_parameter("dim", 0.0)
		tile_layer.add_child(t)
		tiles.append(t)
	bounds = Rect2(off - Vector2(Tile.TW, Tile.TH) * 0.5 + DZ * maxz, Vector2(w, h) - DZ * maxz + Vector2(14, 22))
	reveal_free(false)


func fit_into(r: Rect2, max_scale: = 1.25) -> void:
	var s: float = minf(minf(r.size.x / bounds.size.x, r.size.y / bounds.size.y), max_scale)
	scale = Vector2(s, s)
	position = r.get_center() - bounds.get_center() * s


# rect стола на экране (для святой зоны)
func screen_rect() -> Rect2:
	return Rect2(position + bounds.position * scale.x, bounds.size * scale.x)


func set_tray(centers: Array, tw: float) -> void:
	cells.clear()
	for c in centers:
		cells.append(c)
	tile_w = tw
	_layout_tray()


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


func is_free(i: int) -> bool:
	return rules.is_free(i)


func reveal_free(animate: = true) -> void:
	for i in tiles.size():
		var t: Tile = tiles[i]
		if rules.present[i] == 1:
			var f: = rules.is_free(i)
			t.set_free(f, animate)
			if f and t.secret:
				t.reveal()


func tile_at(gp: Vector2) -> int:
	var lp: = tile_layer.get_global_transform_with_canvas().affine_inverse() * gp
	for i in range(tiles.size() - 1, -1, -1):
		if rules.present[i] == 1 and tiles[i].hit(lp):
			return i
	return -1


func _unhandled_input(e: InputEvent) -> void:
	if not input_on:
		return
	if e is InputEventScreenTouch and e.pressed:
		var i: = tile_at(e.position)
		if i >= 0:
			tap(i)
			get_viewport().set_input_as_handled()


func gpos(i: int) -> Vector2:
	return tile_layer.get_global_transform_with_canvas() * tiles[i].position


# ── ход ──────────────────────────────────────────────────────────────────────

func tap(i: int) -> bool:
	if i < 0 or i >= tiles.size() or rules.present[i] == 0 or rules.lost or rules.won:
		return false
	var t: Tile = tiles[i]
	if not rules.is_free(i):
		t.deny()
		denied.emit(i)
		return false
	picked.emit(i, gpos(i))
	_pick(i, false)
	return true


func _display_insert(i: int) -> void:
	var f: = rules.face[i]
	var at: = -1
	for k in display.size():
		var d: = display[k]
		if rules.face[d] == f and not collapsing.has(d):
			at = k
	if at < 0:
		display.append(i)
	else:
		display.insert(at + 1, i)


func _pick(i: int, auto: bool) -> Dictionary:
	var t: Tile = tiles[i]
	var res: = rules.pick(i)
	if not res.ok:
		return res
	t.press_glint()
	t.kill_move()
	t.hint(false)
	t.shadow.visible = false
	t.z_index = 200 + display.size()
	_display_insert(i)
	max_tray = maxi(max_tray, rules.tray.size())
	var tri: Array = res.triple
	for x in tri:
		collapsing[x] = true
	flying[i] = true
	_layout_tray(i)
	reveal_free()
	tray_changed.emit()
	var gen: = _gen
	get_tree().create_timer(FLY).timeout.connect(func():
		if gen != _gen:
			return
		flying.erase(i)
		placed.emit(i, rules.face[i])
		if not tri.is_empty():
			_collapse(tri, false)
		elif res.lost:
			_lose_shake())
	if res.lost:
		input_on = false
	return res


func _layout_tray(arriving: = -1) -> void:
	var n: = display.size()
	var sc: = _tray_scale() * (1.0 if n <= cells.size() else float(cells.size()) / n * 1.04)
	for k in n:
		var idx: = display[k]
		var t: Tile = tiles[idx]
		var target: = _cell_local(k, n)
		if idx == arriving:
			_fly(t, target, sc)
		elif t.has_meta("fanning"):
			continue
		elif flying.has(idx):
			# ещё в полёте: только поправить цель (дуга сохраняется)
			t.set_meta("target", target)
		else:
			var tw: = _tw(t).set_parallel()
			tw.tween_property(t, "position", target, SHIFT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(t, "scale", Vector2(sc, sc), SHIFT)


# полёт в лоток: квадратичная Безье 0,28 с, на посадке сжатие 0,9 → отскок 1,05 → 1,0
func _tw(t: Tile) -> Tween:
	t.kill_move()
	var old = t.get_meta("tw") if t.has_meta("tw") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw: = t.create_tween()
	t.set_meta("tw", tw)
	return tw


func _fly(t: Tile, target: Vector2, sc: float) -> void:
	var from: = t.position
	var s0: = t.scale.x
	var lift: = 70.0 / maxf(0.3, scale.x)
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
		var k: = lerpf(s0, sc, v) * (1.0 + 0.12 * sin(v * PI))
		t.scale = Vector2(k, k)
		t.rotation = sin(v * PI) * 0.06 * signf(target.x - from.x), 0.0, 1.0, FLY).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(t, "scale", Vector2(sc * 1.06, sc * 0.9), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "scale", Vector2(sc * 0.98, sc * 1.05), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "scale", Vector2(sc, sc), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# тройка: веер и схлопывание
func _collapse(tri: Array, from_ult: bool) -> void:
	var tnow: = now()
	if not from_ult:
		combo = combo + 1 if tnow - last_triple_t < COMBO_WINDOW else 1
		last_triple_t = tnow
	var ts: Array[Tile] = []
	var mid: = Vector2.ZERO
	for x in tri:
		ts.append(tiles[x])
		mid += tiles[x].position
	mid /= 3.0
	var f: = rules.face[tri[0]]
	var c: = accent
	for k in 3:
		var t: Tile = ts[k]
		t.set_meta("fanning", true)
		t.z_index = 320
		var side: = float(k - 1)
		var tw: = _tw(t)
		if t.mat:
			t.mat.set_shader_parameter("flash_col", Vector3(c.r, c.g, c.b))
		if not fx_min:
			tw.tween_property(t, "position", mid + Vector2(side * 18.0 / scale.x, -10.0 / scale.x), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(t, "rotation", side * 0.22, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(t, "scale", t.scale * 1.1, 0.12)
		if t.mat:
			tw.parallel().tween_method(func(v): t.mat.set_shader_parameter("flash", v), 0.0, 0.7, 0.12)
		tw.tween_interval(0.05)
		tw.tween_property(t, "position", mid + Vector2(0, -22.0 / scale.x), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "scale", Vector2.ZERO, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "modulate:a", 0.0, 0.14)
		tw.tween_callback(t.hide)
	var g: = tile_layer.get_global_transform_with_canvas() * mid
	tripled.emit(f, g, combo, from_ult)
	var gen: = _gen
	get_tree().create_timer(0.3).timeout.connect(func():
		if gen != _gen:
			return
		for x in tri:
			display.erase(x)
			collapsing.erase(x)
		_layout_tray()
		tray_changed.emit()
		if rules.won and display.is_empty():
			input_on = false
			cleared.emit())


func _lose_shake() -> void:
	for idx in display:
		var t: Tile = tiles[idx]
		var p: = t.position
		var tw: = _tw(t)
		for k in 4:
			tw.tween_property(t, "position", p + Vector2(6.0 if k % 2 == 0 else -6.0, 0) / scale.x, 0.05)
		tw.tween_property(t, "position", p, 0.05)
	get_tree().create_timer(0.3).timeout.connect(func(): lost.emit())


func busy() -> bool:
	return not flying.is_empty() or not collapsing.is_empty()


# ── раздача ─────────────────────────────────────────────────────────────────

func deal() -> void:
	input_on = false
	dealing = true
	_gen += 1
	var gen: = _gen
	var last: = 0.0
	for i in tiles.size():
		var t: Tile = tiles[i]
		if rules.present[i] == 0:
			continue
		t.position = t.home + Vector2(0, -60)
		t.modulate.a = 0.0
		var d: = 0.01 * i + t.gz * 0.1
		last = maxf(last, d)
		var tw: = t.create_tween().set_parallel()
		tw.tween_property(t, "position", t.home, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(d)
		tw.tween_property(t, "modulate:a", 1.0, 0.18).set_delay(d)
	await get_tree().create_timer(last + 0.42).timeout
	if gen == _gen:
		dealing = false
		input_on = true
		reveal_free()


func finish_deal_now() -> void:
	_gen += 1
	dealing = false
	for i in tiles.size():
		var t: Tile = tiles[i]
		if rules.present[i] == 1:
			t.position = t.home
			t.modulate.a = 1.0
	reveal_free(false)


# ── помощь ───────────────────────────────────────────────────────────────────

func _home_fly(t: Tile) -> void:
	var from: = t.position
	var to: = t.home
	var ctrl: = (from + to) * 0.5 + Vector2(0, -60.0 / scale.x)
	var s0: = t.scale.x
	t.remove_meta("target")
	var tw: = _tw(t)
	tw.tween_method(func(v: float):
		var u: = 1.0 - v
		t.position = from * u * u + ctrl * 2.0 * u * v + to * v * v
		t.scale = Vector2.ONE * lerpf(s0, 1.0, v), 0.0, 1.0, FLY).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		t.rotation = 0.0
		t.z_index = 0
		t.shadow.visible = true)


func return_last(n: = 3) -> Array[int]:
	var back: = rules.return_last(n)
	for i in back:
		display.erase(i)
		_home_fly(tiles[i])
	_layout_tray()
	reveal_free()
	tray_changed.emit()
	if not back.is_empty():
		input_on = true
	return back


func add_slot(new_cells: Array, tw: float) -> bool:
	if not rules.add_slot():
		return false
	set_tray(new_cells, tw)
	input_on = true
	tray_changed.emit()
	return true


func reshuffle(rng: RandomNumberGenerator) -> bool:
	var before: = rules.face.duplicate()
	if not rules.reshuffle(rng):
		return false
	for i in tiles.size():
		if rules.present[i] == 1 and before[i] != rules.face[i]:
			var t: Tile = tiles[i]
			var nf: = rules.face[i]
			var tw: = t.create_tween()
			tw.tween_interval(randf() * 0.18)
			tw.tween_property(t, "scale:x", 0.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func(): t.set_face(nf))
			tw.tween_property(t, "scale:x", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return true


# снять фишки мимо лотка (Магнит, Приёмы): подъём, блик цвета героини, исчезновение к её окну
func vanish(ids: Array, target_g: Vector2, delay: = 0.0) -> void:
	var to: = tile_layer.get_global_transform_with_canvas().affine_inverse() * target_g
	var k: = 0
	for i in ids:
		var t: Tile = tiles[i]
		display.erase(i)
		t.z_index = 330
		if t.mat:
			t.mat.set_shader_parameter("flash_col", Vector3(accent.r, accent.g, accent.b))
		var tw: = _tw(t)
		tw.tween_interval(delay + k * 0.05)
		tw.tween_property(t, "position", t.position + Vector2(0, -26.0 / scale.x), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if t.mat:
			tw.parallel().tween_method(func(v): t.mat.set_shader_parameter("flash", v), 0.0, 0.7, 0.14)
		tw.tween_property(t, "position", to, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "scale", Vector2.ONE * 0.2, 0.32)
		tw.parallel().tween_property(t, "modulate:a", 0.0, 0.32)
		tw.tween_callback(t.hide)
		k += 1


func magnet(groups: Array, target_g: Vector2) -> void:
	var ids: Array = []
	for g in groups:
		ids.append_array(g)
	rules.remove(ids)
	vanish(ids, target_g)
	reveal_free()


# Приём: применяет план V10MjTriplesUlts к правилам и показывает
func cast(plan: Dictionary, target_g: Vector2) -> Dictionary:
	if bool(plan.get("reveal_all", false)):
		for t in tiles:
			if t.secret and t.visible:
				t.reveal()
	var res: = V10MjTriplesUlts.apply(plan, rules)
	var gone: Array = res.gone
	vanish(gone, target_g)
	for i in res.back:
		display.erase(i)
		_home_fly(tiles[i])
	for tri in plan.get("triples", []):
		tripled.emit(rules.face[tri[0]], target_g, combo, true)
	for i in plan.get("mod_ids", []):
		if rules.present[i] == 1:
			tiles[i].hint(true)
			var t: Tile = tiles[i]
			get_tree().create_timer(3.0).timeout.connect(func(): t.hint(false))
	_layout_tray()
	reveal_free()
	tray_changed.emit()
	if rules.won:
		get_tree().create_timer(0.7).timeout.connect(func():
			input_on = false
			cleared.emit())
	return res


# «Благословение стола»: оставшиеся тройки слетаются сами, всё быстрее, тон растёт (звук — через сигнал placed)
func bless(order: Array, step_cb: Callable = Callable()) -> void:
	input_on = false
	var dt: = 0.2
	var k: = 0
	for i in order:
		if rules.present[i] == 0:
			continue
		_pick(int(i), true)
		if step_cb.is_valid():
			step_cb.call(k)
		k += 1
		await get_tree().create_timer(dt).timeout
		dt = maxf(0.075, dt * 0.86)
