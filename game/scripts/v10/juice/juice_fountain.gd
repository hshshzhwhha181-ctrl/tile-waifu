class_name V10JuiceFountain
extends Node2D

# V10JuiceFountain — reward fountain: coins / gems spout up from a point, hang at the top of their arc, then
# home one by one into the counter (a Control, tracked live) with a tick that climbs in pitch, a bump of the
# counter and a sparkle; the last one lands with a warm glow. One node drives every icon (one _process).

const ICON: = 46.0
const UP: = 0.42
const HOME: = 0.42

var items: Array = []   # {spr, halo, vel, delay, phase, t, p0, ctrl}
var from: = Vector2.ZERO
var to_node: Control
var to_pos: = Vector2.ZERO
var kind: = "coin"
var on_each: Callable
var on_done: Callable
var arrived: = 0
var total: = 0
var tex: Texture2D


func start(p_from: Vector2, to, p_kind: String, count: int, each: Callable, done: Callable) -> void:
	from = p_from
	kind = p_kind
	on_each = each
	on_done = done
	total = count
	if to is Control:
		to_node = to
	else:
		to_pos = to
	tex = V10Juice.icon_tex(kind)
	var sc: = ICON / maxf(1.0, float(tex.get_width()))
	var halo_col: = Color(1.0, 0.82, 0.45, 0.55) if kind != "gem" else Color(0.7, 0.75, 1.0, 0.55)
	for i in count:
		var halo: = Sprite2D.new()
		halo.texture = V10JuiceTex.get_tex("dot")
		halo.material = V10Juice.add_mat()
		halo.modulate = halo_col
		halo.scale = Vector2.ONE * 2.2
		halo.visible = false
		add_child(halo)
		var s: = Sprite2D.new()
		s.texture = tex
		s.scale = Vector2.ONE * sc * 0.3
		s.position = from
		s.visible = false
		add_child(s)
		var ang: = randf_range(-0.55, 0.55)
		var sp: = randf_range(520.0, 780.0)
		items.append({"spr": s, "halo": halo, "vel": Vector2(sin(ang) * sp * 0.75, -cos(ang) * sp), "delay": i * 0.035,
			"phase": 0, "t": 0.0, "p0": from, "ctrl": Vector2.ZERO, "sc": sc})
	V10Juice.sound("chest_open" if count >= 12 else "gold_ripple", 1.12, -12.0)
	V10Juice.burst(self, from, "star4", 10, Color(1, 0.9, 0.65), 1.1)
	V10Juice.glow(self, from, Color(1.0, 0.82, 0.5), 1.6, 0.3, 0.55)


func _target() -> Vector2:
	if to_node != null and is_instance_valid(to_node):
		return to_node.get_global_rect().get_center()
	return to_pos


func _process(dt: float) -> void:
	var tgt: = _target()
	for it in items:
		if it.phase == 3:
			continue
		var s: Sprite2D = it.spr
		var h: Sprite2D = it.halo
		if it.delay > 0.0:
			it.delay -= dt
			continue
		it.t += dt
		match it.phase:
			0:
				s.visible = true
				h.visible = true
				it.phase = 1
				it.t = 0.0
			1:
				it.vel = it.vel * exp(-dt * 2.2) + Vector2(0, 1500.0 * dt)
				s.position += it.vel * dt
				var k: float = clampf(it.t / 0.16, 0.0, 1.0)
				s.scale = Vector2.ONE * it.sc * lerpf(0.3, 1.05, k)
				s.rotation = sin(it.t * 9.0) * 0.25
				if it.t >= UP:
					it.phase = 2
					it.t = 0.0
					it.p0 = s.position
					it.ctrl = it.p0.lerp(tgt, 0.35) + Vector2(randf_range(-80, 80), -150)
			2:
				var u: float = clampf(it.t / HOME, 0.0, 1.0)
				var e: = u * u * (1.6 - 0.6 * u)
				var a: Vector2 = it.p0.lerp(it.ctrl, e)
				var b: Vector2 = it.ctrl.lerp(tgt, e)
				s.position = a.lerp(b, e)
				s.scale = Vector2.ONE * it.sc * lerpf(1.05, 0.62, u)
				s.rotation = lerpf(s.rotation, 0.0, 0.2)
				if u >= 1.0:
					it.phase = 3
					s.queue_free()
					h.queue_free()
					_arrive(tgt)
					continue
		h.position = s.position
		h.scale = s.scale / it.sc * 1.6 * (1.0 if it.phase != 2 else 1.25)
	if arrived >= total:
		queue_free()


func _arrive(at: Vector2) -> void:
	var i: = arrived
	arrived += 1
	V10Juice.sound("coin_tick" if kind != "gem" else "gem_tick", 1.0 + minf(i, 12) * 0.045, -11.0)
	V10Juice.burst(null, at, "star4", 3, Color(1, 0.92, 0.7), 0.6)
	if to_node != null and is_instance_valid(to_node):
		V10Juice.bounce(to_node, 0.1 + (0.08 if arrived == total else 0.0), 0.3)
	if on_each.is_valid():
		on_each.call(i)
	if arrived == total:
		V10Juice.glow(null, at, Color(1.0, 0.82, 0.5), 1.4, 0.32, 0.6)
		V10Juice.burst(null, at, "star4", 8, Color(1, 0.88, 0.6), 1.0)
		V9Feel.haptic("match")
		if on_done.is_valid():
			on_done.call()
