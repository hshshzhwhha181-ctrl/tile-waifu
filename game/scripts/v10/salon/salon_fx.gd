class_name V10SalonFx
extends RefCounted

# Salon effects, all in code (spec §Р1 «Туман, пыль, блик, волна, бирки, полёт звёзд — кодом»), all through the
# effect gates: «Минимум» keeps the information (numbers, reveal) and drops particles; no white flashes, the
# light is warm amber/gold (UX §6.7). One burst never has more than MAX_PARTICLES (UX §8.5: ≤ 18 at «full»).

const MAX_PARTICLES: = 18

static var _soft: Texture2D
static var _spark: Texture2D


static func soft_tex() -> Texture2D:
	if _soft == null:
		V10SalonUI.arm_cleanup()
		var g: = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t: = GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft


static func spark_tex() -> Texture2D:
	if _spark == null:
		V10SalonUI.arm_cleanup()
		var img: = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var dx: = absf(x - 15.5) / 15.5
				var dy: = absf(y - 15.5) / 15.5
				var v: = maxf(pow(maxf(0.0, 1.0 - dx), 6.0) * pow(maxf(0.0, 1.0 - dy * 4.0), 2.0),
					pow(maxf(0.0, 1.0 - dy), 6.0) * pow(maxf(0.0, 1.0 - dx * 4.0), 2.0))
				v = maxf(v, pow(maxf(0.0, 1.0 - Vector2(dx, dy).length()), 3.0))
				img.set_pixel(x, y, Color(1, 1, 1, clampf(v, 0.0, 1.0)))
		_spark = ImageTexture.create_from_image(img)
	return _spark


# a cloud of dust puffing out of a restored object (grey-beige, slow, settles)
static func dust(parent: Node, pos: Vector2, radius: float) -> void:
	if not V10SalonUI.can_fx():
		return
	var p: = CPUParticles2D.new()
	p.texture = soft_tex()
	p.position = pos
	p.amount = maxi(6, int(MAX_PARTICLES * V9Feel.fx_scale()))
	p.one_shot = true
	p.explosiveness = 0.92
	p.lifetime = 1.1
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.45
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = radius * 0.6
	p.initial_velocity_max = radius * 1.5
	p.damping_min = 90.0
	p.damping_max = 160.0
	p.gravity = Vector2(0, 26)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	var sc: = Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(1, 1.4))
	p.scale_amount_curve = sc
	var ramp: = Gradient.new()
	ramp.set_color(0, Color(0.86, 0.8, 0.72, 0.55))
	ramp.set_color(1, Color(0.7, 0.66, 0.62, 0.0))
	p.color_ramp = ramp
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


# warm sparkles over a rect (after the reveal; also the jade finish in green-gold)
static func sparkle(parent: Node, r: Rect2, col: Color = Color(1.0, 0.86, 0.55), n: = 22) -> void:
	if not V10SalonUI.can_fx():
		return
	var p: = CPUParticles2D.new()
	p.texture = spark_tex()
	p.position = r.get_center()
	p.amount = clampi(int(n * maxf(0.5, V9Feel.fx_scale())), 6, MAX_PARTICLES)
	p.one_shot = true
	p.explosiveness = 0.55
	p.lifetime = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = r.size * 0.45
	p.direction = Vector2(0, -1)
	p.spread = 40.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 50.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.9
	var ramp: = Gradient.new()
	ramp.set_color(0, Color(col, 0.0))
	ramp.add_point(0.2, Color(col, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(col, 0.0))
	p.color_ramp = ramp
	var mat: = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


# Stars fly from the bank to a task, one every 60 ms along a Bezier arc, pitch rising (star0..star2 up the
# pentatonic). `on_each(i)` fires as each star lands (the bank counter ticks down), `on_done` after the last.
static func star_flight(parent: Control, from: Vector2, to: Vector2, n: int, on_each: Callable, on_done: Callable) -> void:
	var count: = clampi(n, 1, 12)
	var fx: = V10SalonUI.can_fx()
	var landed: = [0]
	for i in count:
		var s: = Control.new()
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.size = Vector2(30, 30)
		s.pivot_offset = Vector2(15, 15)
		s.z_index = 50
		var glow: = TextureRect.new()
		glow.texture = soft_tex()
		glow.size = Vector2(54, 54)
		glow.position = Vector2(-12, -12)
		glow.modulate = Color(1.0, 0.8, 0.45, 0.55)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.add_child(glow)
		s.draw.connect(func(): s.draw_colored_polygon(V10SalonUI.star_points(Vector2(15, 15), 13.0), V10SalonUI.GOLD_300))
		s.position = from - Vector2(15, 15)
		s.modulate.a = 0.0
		parent.add_child(s)
		var side: = -1.0 if i % 2 == 0 else 1.0
		var ctrl: = (from + to) * 0.5 + Vector2(side * (90.0 + 14.0 * i), -160.0 - 10.0 * i)
		var dur: = 0.52 if fx else 0.3
		var t: = s.create_tween()
		t.tween_interval(0.06 * i)
		t.tween_property(s, "modulate:a", 1.0, 0.06)
		t.parallel().tween_method(func(v: float):
			var a: = from.lerp(ctrl, v)
			var b: = ctrl.lerp(to, v)
			s.position = a.lerp(b, v) - Vector2(15, 15)
			s.rotation = v * TAU * 0.75
			s.scale = Vector2.ONE * lerpf(1.0, 0.7, v), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		var idx: = i
		t.tween_callback(func():
			V10SalonUI.sound("star%d" % mini(idx * 3 / maxi(1, count), 2), 1.0 + 0.06 * idx, -4.0)
			V10SalonUI.haptic("tap")
			landed[0] += 1
			if on_each.is_valid():
				on_each.call(idx)
			if landed[0] == count and on_done.is_valid():
				on_done.call())
		t.tween_property(s, "scale", Vector2.ONE * 1.6, 0.12)
		t.parallel().tween_property(s, "modulate:a", 0.0, 0.12)
		t.tween_callback(s.queue_free)


# rolling number: a label counts from a to b
static func roll(l: Label, a: int, b: int, dur: = 0.5, fmt: = "%d") -> void:
	var t: = l.create_tween()
	t.tween_method(func(v: float): l.text = fmt % int(round(v)), float(a), float(b), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# «тук-тук-туууук» (V7Haptics "clear" is exactly that rhythm: 30·30·90 ms)
static func zone_haptic() -> void:
	V10SalonUI.haptic("clear")
