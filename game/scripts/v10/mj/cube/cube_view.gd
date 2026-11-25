class_name V10MjCubeView
extends SubViewportContainer

# Куб в 3D (docs/MODES.md §4.4): SubViewport 720×720 (gl_compatibility, мобильный), одна направленная лампа без теней,
# все фишки — один MultiMeshInstance3D (символ, свобода, выбор/подсказка — в INSTANCE_CUSTOM), атлас лиц с fake-AO.
# Вращается фигура (камера и лампа стоят): свайп — рыскание/тангаж с инерцией, двойной тап — вид спереди (HOME).
# Выбор фишки — свой луч: экран → луч камеры → система фигуры → пересечение с кубиками (slab), ближний. Луч не зависит
# от рендера, самотест сверяет его с картинкой номеров инстансов (id_material).
#
#   setup(lv, rules, opts {hero, accent, look, fx_min, px, show_free})
#   pick(local_pos) -> int · face_point(i) -> Vector2 (точка видимой грани на экране) · screen_of_world(p) -> Vector2
#   drag(delta_px) · fling(vel_px_s) · stop() · home(animate) · aim_at(tiles) · set_view(yaw, pitch)
#   refresh_tile(i) · refresh_all() · set_selected(i, on) · set_hint(tiles) · fly_pair(a, b) · pop_in([a, b])
#   relic_rise() (await) · relic_screen_pos() · set_id_mode(on) · render_ms()
# Сигналы: spun(yaw_vel) — угловая скорость рыскания, рад/с (для шороха и наклона головы героини); knocked(local_pos)
# — две фишки пары стукнулись («ток-ток»); turned — поворот закончился.

signal spun(yaw_vel: float)
signal knocked(local_pos: Vector2)
signal turned

const HOME: = Vector2(-0.55, 0.42)
const FOV: = 32.0
const TILE: = 0.9
const PITCH_MAX: = 1.42
const K_DRAG: = 0.0062
const DAMP: = 3.0
const FLY_T: = 0.42
const KNOCK_AT: = 0.55

var vp: SubViewport
var cam: Camera3D
var lamp: DirectionalLight3D
var env: WorldEnvironment
var pivot: Node3D
var mm: MultiMesh
var mmi: MultiMeshInstance3D
var fx_mm: MultiMesh
var fx_mmi: MultiMeshInstance3D
var relic: V10MjCubeRelic
var rules: V10MjCubeRules
var lv: = {}
var center: = Vector3.ZERO
var radius: = 3.0
var mat: ShaderMaterial
var accent: = Color.WHITE
var hero: = "mc"
var fx_min: = false
var px: = 720

var yaw: = HOME.x
var pitch: = HOME.y
var vel: = Vector2.ZERO
var dragging: = false
var aiming: = false
var selected: = -1
var hinted: Array = []
var _lift: = {}          # i → [0…1, target]
var _pop: = {}           # i → t (undo pop-in)
var _fliers: Array = []  # {slot, from, to, t, face, knocked, meet}
var _flash: = {}         # i → hint/selection custom b
var _aim_tw: Tween
var _frame: = 0
var _idle_t: = 0.0
var id_mode: = false
var finale: = false


func setup(level: Dictionary, r: V10MjCubeRules, opts: = {}) -> void:
	lv = level
	rules = r
	hero = String(opts.get("hero", "mc"))
	accent = opts.get("accent", V10MjCubeRelic.COLORS.get(hero, Color.WHITE))
	fx_min = bool(opts.get("fx_min", false))
	px = int(opts.get("px", 720))
	var dims: Vector3i = level.dims
	center = Vector3(dims - Vector3i.ONE) * 0.5
	radius = Vector3(dims).length() * 0.5 * 0.94 + 0.35
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(px, px)
	custom_minimum_size = Vector2.ZERO
	vp = SubViewport.new()
	vp.name = "VP"
	vp.size = Vector2i(px, px)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_DISABLED if fx_min else Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.positional_shadow_atlas_size = 0
	vp.handle_input_locally = false
	vp.gui_disable_input = true
	add_child(vp)
	env = WorldEnvironment.new()
	var e: = Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff2e4").lerp(accent, 0.18)
	e.ambient_light_energy = 0.62
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	vp.add_child(env)
	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 0.1
	cam.far = 200.0
	var dist: = radius / sin(deg_to_rad(FOV * 0.5))
	cam.position = Vector3(0, 0, dist)
	vp.add_child(cam)
	cam.current = true
	lamp = DirectionalLight3D.new()
	lamp.shadow_enabled = false
	lamp.light_energy = 1.05
	lamp.light_specular = 0.55
	lamp.light_color = Color("fff1dc")
	vp.add_child(lamp)
	lamp.look_at_from_position(Vector3(-3.0, 5.5, 7.0), Vector3.ZERO, Vector3.UP)
	pivot = Node3D.new()
	pivot.name = "Figure"
	vp.add_child(pivot)
	var lk: Dictionary = opts.get("look_resolved", V10MjCubeAtlas.resolve_look(opts.get("look", {}), hero))
	mat = V10MjCubeAtlas.material(lk, accent, {"fx_min": fx_min, "show_free": opts.get("show_free", true)})
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = V10MjCubeAtlas.cube_mesh()
	mm.instance_count = r.cells.size()
	mmi = MultiMeshInstance3D.new()
	mmi.name = "Tiles"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(-Vector3.ONE * (radius + 2.0), Vector3.ONE * (radius + 2.0) * 2.0)
	pivot.add_child(mmi)
	fx_mm = MultiMesh.new()
	fx_mm.transform_format = MultiMesh.TRANSFORM_3D
	fx_mm.use_custom_data = true
	fx_mm.mesh = mm.mesh
	fx_mm.instance_count = 8
	fx_mmi = MultiMeshInstance3D.new()
	fx_mmi.name = "Fliers"
	fx_mmi.multimesh = fx_mm
	fx_mmi.material_override = mat
	fx_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_mmi.custom_aabb = mmi.custom_aabb
	pivot.add_child(fx_mmi)
	for k in 8:
		fx_mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		fx_mm.set_instance_custom_data(k, Color(0, 1, 0, 0))
	relic = V10MjCubeRelic.make(String(opts.get("relic", level.get("host", hero))))
	relic.position = Vector3(level.relic_at) - center
	var core_n: = (level.get("core", []) as Array).size()
	relic.scale = Vector3.ONE * clampf(0.75 + 0.18 * pow(float(core_n), 1.0 / 3.0), 0.8, 1.45)
	if fx_min:
		relic.spin = 0.0
	pivot.add_child(relic)
	refresh_all()
	_apply()


# ── state → instances ────────────────────────────────────────────────────────

func _pos(i: int) -> Vector3:
	return Vector3(rules.cells[i]) - center


func refresh_all() -> void:
	for i in rules.cells.size():
		refresh_tile(i)


func refresh_tile(i: int) -> void:
	if rules.present[i] != 1:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), _pos(i)))
		return
	var s: = TILE
	var p: = _pos(i)
	var lift: float = (_lift[i][0] if _lift.has(i) else 0.0)
	if lift > 0.0:
		s *= 1.0 + 0.06 * lift
		p += _cam_dir_local() * 0.14 * lift
	if _pop.has(i):
		s *= ease(clampf(float(_pop[i]) / 0.2, 0.0, 1.0), 0.4)
	mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), p))
	var b: = 0.0
	if i == selected:
		b = 1.0
	elif hinted.has(i):
		b = 0.5
	mm.set_instance_custom_data(i, Color(float(rules.face[i]) / 64.0, 1.0 if rules.is_free(i) else 0.0, b, 0.0))
	_dirty()


func set_selected(i: int, on: bool) -> void:
	var old: = selected
	if on:
		selected = i
		_lift[i] = [0.0 if not _lift.has(i) else float(_lift[i][0]), 1.0]
	elif selected == i:
		selected = -1
	if not on and i >= 0:
		_lift[i] = [float(_lift[i][0]) if _lift.has(i) else 0.0, 0.0]
	if old >= 0 and old != selected:
		_lift[old] = [float(_lift[old][0]) if _lift.has(old) else 0.0, 0.0]
		refresh_tile(old)
	if i >= 0:
		refresh_tile(i)
	if fx_min:
		for k in _lift:
			_lift[k][0] = _lift[k][1]


func set_hint(tiles: Array) -> void:
	var old: = hinted
	hinted = tiles.duplicate()
	for i in old:
		refresh_tile(int(i))
	for i in hinted:
		refresh_tile(int(i))


# ── camera / rotation ────────────────────────────────────────────────────────

func _apply() -> void:
	pivot.basis = Basis(Vector3.RIGHT, pitch) * Basis(Vector3.UP, yaw)
	_dirty()


func set_view(y: float, p: float) -> void:
	if _aim_tw and _aim_tw.is_valid():
		_aim_tw.kill()
	aiming = false
	yaw = y
	pitch = clampf(p, -PITCH_MAX, PITCH_MAX)
	vel = Vector2.ZERO
	_apply()
	_refresh_lifts()


func drag(delta_px: Vector2) -> void:
	if _aim_tw and _aim_tw.is_valid():
		_aim_tw.kill()
		aiming = false
	dragging = true
	var dy: = delta_px.x * K_DRAG
	yaw += dy
	pitch = clampf(pitch + delta_px.y * K_DRAG, -PITCH_MAX, PITCH_MAX)
	_apply()
	_refresh_lifts()
	spun.emit(dy / maxf(get_process_delta_time(), 1.0 / 120.0))


func fling(vel_px_s: Vector2) -> void:
	dragging = false
	vel = vel_px_s * K_DRAG
	if vel.length() > 9.0:
		vel = vel.normalized() * 9.0
	if fx_min:
		vel = Vector2.ZERO
	if vel.length() < 0.05:
		vel = Vector2.ZERO
		turned.emit()


func stop() -> void:
	dragging = false
	vel = Vector2.ZERO


func home(animate: = true) -> void:
	_turn_to(HOME.x, HOME.y, 0.5 if animate and not fx_min else 0.0)


# turn so that the pair (or one tile) faces the camera: the axis directions with a clear line of sight of both tiles
func aim_at(tiles: Array) -> void:
	var v: = Vector3.ZERO
	var dirs: Array = []
	for t in tiles:
		dirs.append(rules.exposed_dirs(int(t)))
	if dirs.size() == 2 and not (dirs[0] as Array).is_empty() and not (dirs[1] as Array).is_empty():
		var best: = -INF
		for da in dirs[0]:
			for db in dirs[1]:
				var dd: = Vector3(da).dot(Vector3(db))
				if dd > best:
					best = dd
					v = Vector3(da) + Vector3(db)
	elif dirs.size() >= 1 and not (dirs[0] as Array).is_empty():
		v = Vector3(dirs[0][0])
	var mid: = Vector3.ZERO
	for t in tiles:
		mid += _pos(int(t))
	if not tiles.is_empty():
		mid /= tiles.size()
	if v.length() < 0.01:
		v = mid
	if v.length() < 0.01:
		v = Vector3(0, 0, 1)
	v = v.normalized() * 1.0 + mid.normalized() * 0.35
	# a 3/4 look rather than a flat face-on view
	var ty: = atan2(-v.x, v.z)
	var h: = sqrt(v.x * v.x + v.z * v.z)
	var tp: = atan2(v.y, h)
	ty += 0.32 if fmod(ty + TAU * 4.0, TAU) < PI else -0.32
	tp = clampf(tp + (0.22 if tp >= 0.0 else -0.22), -PITCH_MAX, PITCH_MAX)
	_turn_to(ty, tp, 0.6 if not fx_min else 0.0)


func _turn_to(ty: float, tp: float, dur: float) -> void:
	vel = Vector2.ZERO
	while ty - yaw > PI:
		ty -= TAU
	while ty - yaw < -PI:
		ty += TAU
	if _aim_tw and _aim_tw.is_valid():
		_aim_tw.kill()
	if dur <= 0.0:
		yaw = ty
		pitch = tp
		_apply()
		_refresh_lifts()
		turned.emit()
		return
	aiming = true
	var y0: = yaw
	var p0: = pitch
	_aim_tw = create_tween()
	_aim_tw.tween_method(func(t: float):
		var prev: = yaw
		yaw = lerpf(y0, ty, t)
		pitch = lerpf(p0, tp, t)
		_apply()
		_refresh_lifts()
		spun.emit((yaw - prev) / maxf(get_process_delta_time(), 1.0 / 120.0)), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_aim_tw.tween_callback(func():
		aiming = false
		turned.emit())


# a full turn (Юэ «Лунный свет»: every free pair glows while the figure turns once)
func full_turn(dur: = 2.4) -> void:
	_turn_to(yaw + TAU * 0.999, pitch, dur if not fx_min else 0.0)


func _cam_dir_local() -> Vector3:
	if pivot == null:
		return Vector3(0, 0, 1)
	return (pivot.basis.inverse() * Vector3(0, 0, 1)).normalized()


func _cam_pos_local() -> Vector3:
	return pivot.global_transform.affine_inverse() * cam.global_position


func _refresh_lifts() -> void:
	for i in _lift:
		if float(_lift[i][0]) > 0.0:
			refresh_tile(int(i))


# ── picking ──────────────────────────────────────────────────────────────────

func _sz() -> Vector2:
	return Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))


func _to_vp(local: Vector2) -> Vector2:
	return local * (Vector2(vp.size) / _sz())


func pick(local: Vector2) -> int:
	var p: = _to_vp(local)
	var ro: = cam.project_ray_origin(p)
	var rd: = cam.project_ray_normal(p)
	var inv: = pivot.global_transform.affine_inverse()
	var o: = inv * ro
	var d: = (inv.basis * rd).normalized()
	return ray_pick(o, d)


# nearest present tile hit by a ray in figure space (axis-aligned cubes of TILE size)
func ray_pick(o: Vector3, d: Vector3) -> int:
	var best: = -1
	var bt: = INF
	var hs: = TILE * 0.5
	var inv_d: = Vector3(1.0 / d.x if absf(d.x) > 1e-9 else 1e9, 1.0 / d.y if absf(d.y) > 1e-9 else 1e9,
		1.0 / d.z if absf(d.z) > 1e-9 else 1e9)
	for i in rules.cells.size():
		if rules.present[i] != 1:
			continue
		var c: = _pos(i)
		var t1: = (c - Vector3.ONE * hs - o) * inv_d
		var t2: = (c + Vector3.ONE * hs - o) * inv_d
		var tmin: = maxf(maxf(minf(t1.x, t2.x), minf(t1.y, t2.y)), minf(t1.z, t2.z))
		var tmax: = minf(minf(maxf(t1.x, t2.x), maxf(t1.y, t2.y)), maxf(t1.z, t2.z))
		if tmax >= maxf(tmin, 0.0) and tmin < bt:
			bt = tmin
			best = i
	return best


# screen (container-local) position of a point in figure space
func screen_of_local(p: Vector3) -> Vector2:
	var w: = pivot.global_transform * p
	return cam.unproject_position(w) * (_sz() / Vector2(vp.size))


func tile_screen(i: int) -> Vector2:
	return screen_of_local(_pos(i))


# the centre of the tile face that looks most towards the camera (where a finger would tap it)
func face_point(i: int) -> Vector2:
	var cl: = _cam_pos_local()
	var best: = Vector3(0, 0, 1)
	var bs: = -INF
	for d in V10MjCubeRules.DIRS:
		var n: = Vector3(d)
		var s: = n.dot((cl - _pos(i)).normalized())
		if s > bs:
			bs = s
			best = n
	return screen_of_local(_pos(i) + best * TILE * 0.5)


# tile is in front of the camera and its centre ray is not blocked by another tile
func visible_tile(i: int) -> bool:
	if rules.present[i] != 1:
		return false
	return pick(face_point(i)) == i


# ── pair FX ──────────────────────────────────────────────────────────────────

# the pair leaves the figure: both cubes fly towards the camera, knock together («ток-ток»), flash and vanish
func fly_pair(a: int, b: int) -> Vector2:
	var pa: = _pos(a)
	var pb: = _pos(b)
	_lift.erase(a)
	_lift.erase(b)
	if selected == a or selected == b:
		selected = -1
	hinted.erase(a)
	hinted.erase(b)
	refresh_tile(a)
	refresh_tile(b)
	var cl: = _cam_pos_local()
	var mid: = (pa + pb) * 0.5
	var meet: = mid + (cl - mid).normalized() * minf(2.2, radius * 0.6)
	var right: = (pivot.basis.inverse() * Vector3(1, 0, 0)).normalized()
	var side: = 1.0 if (pa - pb).dot(right) >= 0.0 else -1.0
	var meet_pt: = screen_of_local(meet)
	if fx_min:
		knocked.emit(meet_pt)
		return meet_pt
	var lead: = true
	for pr in [[pa, side, rules.face[a]], [pb, -side, rules.face[b]]]:
		var slot: = _free_slot()
		if slot < 0:
			continue
		_fliers.append({"slot": slot, "from": pr[0], "to": meet + right * 0.47 * TILE * float(pr[1]), "t": 0.0,
			"face": int(pr[2]), "lead": lead})
		lead = false
	_dirty()
	return meet_pt


func _free_slot() -> int:
	var used: = {}
	for f in _fliers:
		used[int(f.slot)] = true
	for k in 8:
		if not used.has(k):
			return k
	return -1


func pop_in(tiles: Array) -> void:
	for t in tiles:
		if not fx_min:
			_pop[int(t)] = 0.0
		refresh_tile(int(t))


# ── frame ────────────────────────────────────────────────────────────────────

func _dirty() -> void:
	_idle_t = 0.0


func _process(dt: float) -> void:
	if pivot == null:
		return
	_frame += 1
	if not dragging and vel.length() > 0.0:
		yaw += vel.x * dt
		pitch = clampf(pitch + vel.y * dt, -PITCH_MAX, PITCH_MAX)
		vel *= exp(-DAMP * dt)
		_apply()
		_refresh_lifts()
		spun.emit(vel.x)
		if vel.length() < 0.04:
			vel = Vector2.ZERO
			turned.emit()
	for i in _lift.keys():
		var l: Array = _lift[i]
		if absf(float(l[0]) - float(l[1])) > 0.001:
			l[0] = move_toward(float(l[0]), float(l[1]), dt / 0.1)
			refresh_tile(int(i))
		elif float(l[1]) == 0.0:
			_lift.erase(i)
	for i in _pop.keys():
		_pop[i] = float(_pop[i]) + dt
		refresh_tile(int(i))
		if float(_pop[i]) >= 0.2:
			_pop.erase(i)
			refresh_tile(int(i))
	_step_fliers(dt)
	var active: = dragging or vel.length() > 0.0 or aiming or not _fliers.is_empty() or not _pop.is_empty() \
		or not hinted.is_empty() or finale or id_mode
	_idle_t += dt
	if active or _idle_t < 0.25:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		# nothing moves but the relic turning in the core: 20 frames a second are plenty (battery, Mali)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE if _frame % 3 == 0 else SubViewport.UPDATE_DISABLED


func _step_fliers(dt: float) -> void:
	var keep: = []
	for f in _fliers:
		f.t = float(f.t) + dt / FLY_T
		var t: float = f.t
		var slot: int = f.slot
		if t >= 1.0:
			fx_mm.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			continue
		var p: Vector3
		var s: float
		var flash: = 0.0
		if t < KNOCK_AT:
			var u: = ease(t / KNOCK_AT, 0.45)
			p = (f.from as Vector3).lerp(f.to, u)
			s = TILE * lerpf(1.0, 0.86, u)
		else:
			if not f.get("knocked", false):
				f.knocked = true
				if f.get("lead", false):
					knocked.emit(screen_of_local(f.to))
			var u: = (t - KNOCK_AT) / (1.0 - KNOCK_AT)
			p = (f.to as Vector3) + _cam_dir_local() * 0.25 * u
			s = TILE * 0.86 * (1.0 - ease(u, 2.2))
			flash = sin(u * PI) * 0.9 + 0.1
		var rot: = Basis(Vector3(0.3, 1, 0.2).normalized(), t * 1.4 * (1.0 if f.get("lead", false) else -1.0))
		fx_mm.set_instance_transform(slot, Transform3D(rot.scaled(Vector3.ONE * maxf(s, 0.0)), p))
		fx_mm.set_instance_custom_data(slot, Color(float(f.face) / 64.0, 1.0, 0.0, flash))
		keep.append(f)
	_fliers = keep


# ── finale: the relic rises out of the core and flashes in her colour ───────────

func relic_rise(dur: = 1.15) -> void:
	finale = true
	var from: = relic.position
	var to: = _cam_dir_local() * minf(2.4, radius * 0.55) + Vector3(0, 0.2, 0)
	var s0: = relic.scale
	relic.spin = 2.2 if not fx_min else 0.0
	if fx_min:
		relic.position = to
		relic.scale = s0 * 1.7
		relic.finale_glow(0.8)
		await get_tree().process_frame
		return
	var tw: = create_tween().set_parallel()
	tw.tween_property(relic, "position", to, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(relic, "scale", s0 * 1.8, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(relic.finale_glow, 0.0, 1.0, dur * 0.7).set_delay(dur * 0.3)
	await tw.finished
	var t2: = create_tween()
	t2.tween_method(relic.finale_glow, 1.0, 0.45, 0.35)
	await t2.finished


func relic_screen_pos() -> Vector2:
	return screen_of_local(relic.position)


func relic_leave(dur: = 0.35) -> void:
	if fx_min:
		relic.visible = false
		return
	var tw: = create_tween().set_parallel()
	tw.tween_property(relic, "scale", Vector3.ONE * 0.01, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(relic, "position", relic.position + Vector3(radius * 0.5, radius * 0.9, 0) * pivot.basis, dur)
	await tw.finished
	relic.visible = false
	finale = false


# ── selftest helpers ─────────────────────────────────────────────────────────

func set_id_mode(on: bool) -> void:
	id_mode = on
	mmi.material_override = V10MjCubeAtlas.id_material() if on else mat
	relic.visible = not on
	fx_mmi.visible = not on
	vp.msaa_3d = Viewport.MSAA_DISABLED if on else (Viewport.MSAA_DISABLED if fx_min else Viewport.MSAA_2X)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func measure(on: bool) -> void:
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), on)


func render_ms() -> Vector2:
	var rid: = vp.get_viewport_rid()
	return Vector2(RenderingServer.viewport_get_measured_render_time_cpu(rid),
		RenderingServer.viewport_get_measured_render_time_gpu(rid))
