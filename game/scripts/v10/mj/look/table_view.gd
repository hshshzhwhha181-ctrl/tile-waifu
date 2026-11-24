class_name V10MjTableView
extends Control

# V10MjTableView — the heroine's table behind any mahjong board (docs/MODES.md §3.1, §3.4; UX_RULES §6, §7.3).
#   back (this node):  far parallax layer (her Salon zone) · her cloth on a lacquered frame with her lamp pool ·
#                      ambient particles (petals, tea leaves, sparks, fireflies, rain …) outside the sacred zone
#   front (.front):    near out-of-focus layer (lanterns, wisteria, cables …), masked off the sacred zone; add it
#                      ABOVE the board with attach_front(parent)
#
#   var tv := V10MjTableView.make(parent, th_data, board_rect, sacred_rect)   # th_data = V10MjTables.theme_for(...)
#   tv.attach_front(hud_parent)            # near layer above the board, below the HUD
#   tv.set_parallax(Vector2)               # -1..1 (board pan, cube rotation, device tilt) → far 10 px, near 26 px
#   tv.light() -> Dictionary               # lamp for V10MjTileMaterial / V10MjTileView
#   tv.set_sacred(rect)                    # update when the board moves
# Budgets (§3.3): ≤ 18 particles at fx full, 8 at mid, 0 at min; at min there is no drift, no flicker.

const CLOTH_SHADER: = preload("res://shaders/v10/mj/look/table_cloth.gdshader")
const LAYER_SHADER: = preload("res://shaders/v10/mj/look/parallax_layer.gdshader")
const MARGIN: = 36.0
const FRAME_W: = 14.0
const FAR_PX: = 10.0
const NEAR_PX: = 26.0
const PARTICLES: = {"full": 18, "mid": 8, "min": 0}

var th_data: = {}
var board_rect: = Rect2()
var sacred: = Rect2()
var far_layer: Control
var cloth_rect: ColorRect
var cloth_mat: ShaderMaterial
var fx_layer: Node2D
var front: Control
var _par: = Vector2.ZERO
var _par_target: = Vector2.ZERO
var _t: = 0.0
var _parts: Array = []
var fx_level: = "full"


static func make(parent: Node, th: Dictionary, board: Rect2, sacred_rect: = Rect2(), size_px: = Vector2.ZERO) -> V10MjTableView:
	var tv: = V10MjTableView.new()
	tv.name = "V10MjTable"
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size_px == Vector2.ZERO and parent is Control:
		size_px = (parent as Control).size
	if size_px == Vector2.ZERO:
		size_px = parent.get_viewport().get_visible_rect().size if parent.is_inside_tree() else Vector2(720, 1280)
	tv.size = size_px
	tv.setup(th, board, sacred_rect if sacred_rect.size != Vector2.ZERO else board)
	parent.add_child(tv)
	return tv


func setup(th: Dictionary, board: Rect2, sacred_rect: Rect2) -> void:
	th_data = th
	board_rect = board
	sacred = sacred_rect.grow(8.0)
	fx_level = V10MjTileMaterial.fx_level()
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	far_layer = _Layer.new()
	far_layer.view = self
	far_layer.kind = 0
	far_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	far_layer.size = size
	var fm: = ShaderMaterial.new()
	fm.shader = LAYER_SHADER
	fm.set_shader_parameter("mode", 0)
	fm.set_shader_parameter("rect_size", size)
	fm.set_shader_parameter("dark_from", clampf((board_rect.position.y - 40.0) / maxf(size.y, 1.0), 0.05, 0.6))
	fm.set_shader_parameter("dark_k", 0.62)
	far_layer.material = fm
	far_layer.tex = _load(String(th_data.bg.far))
	add_child(far_layer)

	cloth_rect = ColorRect.new()
	cloth_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r: = board_rect.grow(MARGIN + FRAME_W)
	cloth_rect.position = r.position
	cloth_rect.size = r.size
	cloth_mat = ShaderMaterial.new()
	cloth_mat.shader = CLOTH_SHADER
	cloth_mat.set_shader_parameter("size", r.size)
	cloth_mat.set_shader_parameter("margin", MARGIN)
	cloth_mat.set_shader_parameter("frame_w", FRAME_W)
	var ctex: = _load(String(th_data.cloth.tex))
	if ctex:
		cloth_mat.set_shader_parameter("cloth", ctex)
	cloth_mat.set_shader_parameter("cloth_scale", float(th_data.cloth.get("scale", 340.0)))
	cloth_mat.set_shader_parameter("cloth_tint", th_data.cloth.get("tint", Color.WHITE))
	cloth_mat.set_shader_parameter("frame_a", th_data.tray.a)
	cloth_mat.set_shader_parameter("frame_b", th_data.tray.b)
	cloth_mat.set_shader_parameter("trim", th_data.tray.trim)
	cloth_mat.set_shader_parameter("lamp_uv", th_data.lamp.uv)
	cloth_mat.set_shader_parameter("lamp_col", th_data.lamp.col)
	cloth_mat.set_shader_parameter("lamp_k", float(th_data.lamp.k))
	cloth_rect.material = cloth_mat
	add_child(cloth_rect)

	fx_layer = _Fx.new()
	fx_layer.view = self
	add_child(fx_layer)
	_spawn_particles()

	front = _Layer.new()
	front.view = self
	front.kind = 1
	front.name = "V10MjTableFront"
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.size = size
	var nm: = ShaderMaterial.new()
	nm.shader = LAYER_SHADER
	nm.set_shader_parameter("mode", 1)
	nm.set_shader_parameter("rect_size", size)
	nm.set_shader_parameter("alpha_k", 0.82)
	front.material = nm
	front.tex = _load(String(th_data.bg.get("near", "")))
	front.visible = front.tex != null
	_push_sacred()


static func _load(p: String) -> Texture2D:
	if p == "" or not ResourceLoader.exists(p):
		return null
	return load(p)


func attach_front(parent: Node) -> void:
	if front.get_parent():
		front.get_parent().remove_child(front)
	parent.add_child(front)
	# the front layer lives in another parent: keep its local px aligned with ours
	front.global_position = global_position if is_inside_tree() else position


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(front) and front.get_parent() == null:
		front.free()


func _exit_tree() -> void:
	if is_instance_valid(front) and front.get_parent() and front.get_parent() != self:
		front.queue_free()


func set_sacred(r: Rect2) -> void:
	sacred = r.grow(8.0)
	_push_sacred()


func _push_sacred() -> void:
	if front and front.material:
		front.material.set_shader_parameter("sacred", Vector4(sacred.position.x, sacred.position.y, sacred.size.x, sacred.size.y))
		front.material.set_shader_parameter("pad", 0.0)


func set_parallax(v: Vector2) -> void:
	_par_target = v.clamp(Vector2(-1, -1), Vector2(1, 1))


func light() -> Dictionary:
	return V10MjTables.light(th_data, board_rect)


func particle_budget() -> int:
	return int(PARTICLES.get(fx_level, 18))


func _process(delta: float) -> void:
	_t += delta
	if fx_level == "min":
		return
	var drift: = Vector2(sin(_t * 0.11), cos(_t * 0.083)) * 0.35
	var tilt: = Vector2.ZERO
	if OS.has_feature("mobile"):
		var g: = Input.get_gravity()
		if g.length() > 0.1:
			tilt = Vector2(clampf(g.x / 4.0, -1, 1), clampf((g.y + 7.0) / 4.0, -1, 1)) * 0.6
	var want: = _par_target + drift + tilt
	_par = _par.lerp(want, clampf(delta * 2.5, 0, 1))
	far_layer.queue_redraw()
	if front.visible:
		front.queue_redraw()
	# warm lanterns breathe a little (≤ ±5%), never flash
	if cloth_mat:
		cloth_mat.set_shader_parameter("lamp_k", float(th_data.lamp.k) * (1.0 + 0.05 * sin(_t * 1.7) * sin(_t * 0.63)))
	_step_particles(delta)


# ── particles: only in the free areas (her band above the board, side gutters) ────────────────────────────────

func _spawn_particles() -> void:
	_parts.clear()
	var n: = particle_budget()
	for i in n:
		_parts.append(_new_particle(true))


func _free_point(any_y: bool) -> Vector2:
	# 80% in the band above the sacred zone, 20% in the side gutters (if wider than 24 px)
	var top: = maxf(sacred.position.y - 4.0, 24.0)
	var gl: = sacred.position.x
	var gr: = size.x - sacred.end.x
	if randf() < 0.8 or (gl < 24.0 and gr < 24.0):
		return Vector2(randf_range(0, size.x), randf_range(0, top) if any_y else -10.0)
	if gl >= gr:
		return Vector2(randf_range(0, gl), randf_range(sacred.position.y, sacred.end.y))
	return Vector2(randf_range(sacred.end.x, size.x), randf_range(sacred.position.y, sacred.end.y))


func _new_particle(any_y: bool) -> Dictionary:
	var kind: = String(th_data.amb.get("fx", "dust"))
	var p: = {"pos": _free_point(any_y), "life": randf_range(4.0, 9.0), "age": 0.0, "rot": randf() * TAU,
		"spin": randf_range(-1.2, 1.2), "size": randf_range(3.0, 7.0), "seed": randf() * 100.0}
	match kind:
		"petals", "feathers", "leaves":
			p.vel = Vector2(randf_range(8, 22), randf_range(14, 30))
		"sparks", "foxfire":
			p.vel = Vector2(randf_range(-6, 6), randf_range(-26, -12))
			p.size = randf_range(1.6, 3.2)
		"fireflies", "bubbles":
			p.vel = Vector2(randf_range(-6, 6), randf_range(-8, 4))
			p.size = randf_range(2.0, 3.6)
		"rain", "spray":
			p.vel = Vector2(-18, randf_range(260, 340))
			p.life = randf_range(1.0, 2.0)
			p.size = randf_range(10.0, 18.0)
		"snow":
			p.vel = Vector2(randf_range(-6, 6), randf_range(10, 22))
		_:
			p.vel = Vector2(randf_range(-4, 4), randf_range(-3, 5))
			p.size = randf_range(1.4, 2.6)
	return p


func _step_particles(dt: float) -> void:
	for i in _parts.size():
		var p: Dictionary = _parts[i]
		p.age += dt
		p.rot += p.spin * dt
		var wob: = Vector2(sin(_t * 1.3 + p.seed) * 6.0, 0.0)
		p.pos += (p.vel + wob) * dt
		if p.age > p.life or p.pos.y > size.y + 20 or p.pos.x > size.x + 20 or p.pos.x < -20 or p.pos.y < -30:
			_parts[i] = _new_particle(false)
	fx_layer.queue_redraw()


# alpha of a particle at a point: 0 inside the sacred zone (+8 px), soft 16 px fade outside it
func particle_alpha(pt: Vector2) -> float:
	var dx: = maxf(maxf(sacred.position.x - pt.x, pt.x - sacred.end.x), 0.0)
	var dy: = maxf(maxf(sacred.position.y - pt.y, pt.y - sacred.end.y), 0.0)
	var inside: = pt.x > sacred.position.x and pt.x < sacred.end.x and pt.y > sacred.position.y and pt.y < sacred.end.y
	if inside:
		return 0.0
	return clampf(maxf(dx, dy) / 16.0, 0.0, 1.0)


# the parts of `full` outside `hole` (up to 4 rects: top, bottom, left, right)
static func ring_parts(full: Rect2, hole: Rect2) -> Array:
	var h: = hole.intersection(full)
	if h.size.x <= 0.0 or h.size.y <= 0.0:
		return [full]
	var out: = []
	if h.position.y > full.position.y:
		out.append(Rect2(full.position, Vector2(full.size.x, h.position.y - full.position.y)))
	if h.end.y < full.end.y:
		out.append(Rect2(Vector2(full.position.x, h.end.y), Vector2(full.size.x, full.end.y - h.end.y)))
	if h.position.x > full.position.x:
		out.append(Rect2(Vector2(full.position.x, h.position.y), Vector2(h.position.x - full.position.x, h.size.y)))
	if h.end.x < full.end.x:
		out.append(Rect2(Vector2(h.end.x, h.position.y), Vector2(full.end.x - h.end.x, h.size.y)))
	return out


class _Layer extends Control:
	var view
	var kind: = 0
	var tex: Texture2D

	func _draw() -> void:
		if tex == null or view == null:
			return
		var s: Vector2 = view.size
		var ts: = tex.get_size()
		var k: = maxf(s.x / ts.x, s.y / ts.y) * (1.04 if kind == 0 else 1.0)
		var ds: = ts * k
		var amt: float = FAR_PX if kind == 0 else NEAR_PX
		var off: Vector2 = (s - ds) * 0.5 + view._par * amt
		if kind == 0:
			off.y = minf(off.y, 0.0) + view._par.y * amt * 0.5
		var dst: = Rect2(off, ds)
		# draw only what can be seen: the far layer is hidden under the cloth, the near layer is masked off the
		# sacred zone — skipping those parts saves most of the fill (≈ 60% of two full-screen layers)
		var hole: Rect2 = view.cloth_rect.get_rect().grow(-(MARGIN + 8.0)) if kind == 0 else view.sacred
		for part in V10MjTableView.ring_parts(Rect2(Vector2.ZERO, s), hole):
			var src: = Rect2((part.position - dst.position) / k, part.size / k)
			draw_texture_rect_region(tex, part, src)


class _Fx extends Node2D:
	var view

	func _draw() -> void:
		if view == null:
			return
		var col: Color = view.th_data.amb.get("fx_col", Color(1, 1, 1))
		var kind: = String(view.th_data.amb.get("fx", "dust"))
		for p in view._parts:
			var a: float = view.particle_alpha(p.pos)
			var life_a: float = clampf(p.age / 0.8, 0, 1) * clampf((p.life - p.age) / 0.8, 0, 1)
			a *= life_a
			if a <= 0.01:
				continue
			var c: = Color(col.r, col.g, col.b, a * 0.75)
			match kind:
				"petals", "feathers", "leaves":
					draw_set_transform(p.pos, p.rot, Vector2(1.0, 0.55))
					draw_circle(Vector2.ZERO, p.size, c)
					draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
				"tea":
					draw_set_transform(p.pos, p.rot, Vector2(1.0, 0.35))
					draw_circle(Vector2.ZERO, p.size * 0.8, c)
					draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
				"rain", "spray":
					draw_line(p.pos, p.pos + Vector2(-0.6, p.size), Color(c.r, c.g, c.b, c.a * 0.6), 1.2, true)
				"sparks", "foxfire", "fireflies", "bubbles":
					var fl: float = 0.6 + 0.4 * sin(view._t * 5.0 + p.seed)
					draw_circle(p.pos, p.size * 2.6, Color(c.r, c.g, c.b, c.a * 0.18 * fl))
					draw_circle(p.pos, p.size, Color(c.r, c.g, c.b, c.a * fl))
				_:
					draw_circle(p.pos, p.size, Color(c.r, c.g, c.b, c.a * 0.6))
