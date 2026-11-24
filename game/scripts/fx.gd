class_name Fx
extends RefCounted

# Fx — one-shot particles, rings, glows and floating text (static).
# 0.9 (spec §A, «Эффекты»): every decorative effect here follows S.fx_level through V9Feel:
#   burst / ambient   particle count × V9Feel.fx_scale() (full 1.0, mid 0.55, min — none)
#   ring / flash_glow decor: skipped at «минимум»
#   float_text        information («+12», «−10 с»): always shown
#   shake             a node shake used as fail feedback: kept at every level, but at «минимум» it is halved


static var _add: CanvasItemMaterial

static func add_mat() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add

static func _curve(points: Array) -> Curve:
	var c: = Curve.new()
	for p in points:
		c.add_point(p)
	return c

static func _grad(cols: Array) -> Gradient:
	var g: = Gradient.new()
	var offs: = PackedFloat32Array()
	for i in cols.size():
		offs.append(float(i) / max(1, cols.size() - 1))
	g.offsets = offs
	g.colors = PackedColorArray(cols)
	return g

static func particles(tex: String, amount: int, lifetime: float) -> CPUParticles2D:
	var p: = CPUParticles2D.new()
	p.texture = G.fx(tex)
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	return p

# particle count after the «Эффекты» level (0 = skip the emitter)
static func scaled(count: int) -> int:
	var k: = V9Feel.fx_scale()
	if k <= 0.0 or count <= 0:
		return 0
	return maxi(1, int(round(count * k)))

static func burst(parent: Node, pos: Vector2, kind: = "sparkle", count: = 24, color: = Color(1, 0.9, 0.6), power: = 1.0) -> void :
	count = scaled(count)
	if count <= 0 or parent == null or not is_instance_valid(parent):
		return
	var p: CPUParticles2D
	match kind:
		"sparkle":
			p = particles("sparkle", count, 0.7)
			p.material = add_mat()
			p.spread = 180
			p.initial_velocity_min = 160 * power
			p.initial_velocity_max = 520 * power
			p.damping_min = 300
			p.damping_max = 600
			p.scale_amount_min = 0.12
			p.scale_amount_max = 0.42
			p.angular_velocity_min = -300
			p.angular_velocity_max = 300
			p.color = color
			p.scale_amount_curve = _curve([Vector2(0, 0.3), Vector2(0.15, 1), Vector2(1, 0)])
		"petal":
			p = particles("petal", count, 1.6)
			p.spread = 180
			p.initial_velocity_min = 120 * power
			p.initial_velocity_max = 420 * power
			p.damping_min = 200
			p.damping_max = 400
			p.gravity = Vector2(0, 260)
			p.scale_amount_min = 0.35
			p.scale_amount_max = 0.7
			p.angle_min = 0
			p.angle_max = 360
			p.angular_velocity_min = -360
			p.angular_velocity_max = 360
			p.color_ramp = _grad([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		"confetti":
			p = particles("confetti", count, 2.6)
			p.spread = 50
			p.direction = Vector2(0, -1)
			p.initial_velocity_min = 500 * power
			p.initial_velocity_max = 1000 * power
			p.damping_min = 250
			p.damping_max = 450
			p.gravity = Vector2(0, 520)
			p.angle_max = 360
			p.angular_velocity_min = -720
			p.angular_velocity_max = 720
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.1
			p.hue_variation_min = -1
			p.hue_variation_max = 1
			p.color = Color(1, 0.6, 0.75)
			p.color_ramp = _grad([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		"heart":
			p = particles("heart", count, 1.2)
			p.direction = Vector2(0, -1)
			p.spread = 70
			p.initial_velocity_min = 140
			p.initial_velocity_max = 320
			p.gravity = Vector2(0, -60)
			p.scale_amount_min = 0.35
			p.scale_amount_max = 0.7
			p.color = Color("ff7fa8")
			p.color_ramp = _grad([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		"glow":
			p = particles("glow", count, 0.9)
			p.material = add_mat()
			p.spread = 180
			p.initial_velocity_min = 60 * power
			p.initial_velocity_max = 300 * power
			p.damping_min = 100
			p.damping_max = 300
			p.scale_amount_min = 0.1
			p.scale_amount_max = 0.35
			p.color = color
			p.color_ramp = _grad([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		"firework":
			p = particles("glow", count, 1.3)
			p.material = add_mat()
			p.spread = 180
			p.initial_velocity_min = 380 * power
			p.initial_velocity_max = 420 * power
			p.damping_min = 280
			p.damping_max = 300
			p.gravity = Vector2(0, 120)
			p.scale_amount_min = 0.08
			p.scale_amount_max = 0.14
			p.color = color
			p.color_ramp = _grad([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	p.one_shot = true
	p.explosiveness = 0.92
	p.position = pos
	p.emitting = true
	parent.add_child(p)
	p.finished.connect(p.queue_free)

static func ring(parent: Node, pos: Vector2, color: = Color(1, 0.9, 0.6), size: = 1.6, dur: = 0.5) -> void :
	if not V9Feel.can_fx() or parent == null or not is_instance_valid(parent):
		return
	var s: = Sprite2D.new()
	s.texture = G.fx("ring")
	s.material = add_mat()
	s.position = pos
	s.modulate = color
	s.scale = Vector2(0.15, 0.15)
	parent.add_child(s)
	var t: Tween = s.create_tween().set_parallel()
	t.tween_property(s, "scale", Vector2(size, size), dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(s.queue_free)

static func flash_glow(parent: Node, pos: Vector2, color: = Color(1, 1, 0.9), size: = 2.0, dur: = 0.35) -> void :
	if not V9Feel.can_fx() or parent == null or not is_instance_valid(parent):
		return
	var s: = Sprite2D.new()
	s.texture = G.fx("glow")
	s.material = add_mat()
	s.position = pos
	s.modulate = color
	s.scale = Vector2(size * 0.4, size * 0.4)
	parent.add_child(s)
	var t: Tween = s.create_tween().set_parallel()
	t.tween_property(s, "scale", Vector2(size, size), dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, dur)
	t.chain().tween_callback(s.queue_free)

static func float_text(parent: Node, pos: Vector2, text: String, color: = Color.WHITE, size: = 34, outline: = Color("b8406c")) -> Label:
	var l: = UI.label(text, size, color, outline, 8, "body", 900)
	l.position = pos - Vector2(150, 30)
	l.size = Vector2(300, 60)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(150, 30)
	l.scale = Vector2(0.3, 0.3)
	parent.add_child(l)
	var t: Tween = l.create_tween()
	t.tween_property(l, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "scale", Vector2.ONE, 0.1)
	t.parallel().tween_property(l, "position:y", l.position.y - 70, 0.9).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.25)
	t.tween_callback(l.queue_free)
	return l

static func shake(n: Node, amount: = 10.0, dur: = 0.3) -> void :
	if V9Feel.level() == "min":
		amount *= 0.5
	var base: Vector2 = n.get_meta("shake_base", n.position)
	n.set_meta("shake_base", base)
	var t: Tween = n.create_tween()
	var steps: = int(dur / 0.03)
	for i in steps:
		var k: = 1.0 - float(i) / steps
		t.tween_property(n, "position", base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount * k, 0.03)
	t.tween_property(n, "position", base, 0.03)


static func ambient(parent: Node, kind: String, area: Vector2) -> Node2D:
	var root: = Node2D.new()
	parent.add_child(root)
	# «минимум»: no ambient particles (the root stays, callers keep and free it as before)
	if V9Feel.fx_scale() <= 0.0:
		return root
	match kind:
		"petals":
			var p: = particles("petal", 26, 9.0)
			p.position = Vector2(area.x * 0.5, -40)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(area.x * 0.7, 10)
			p.direction = Vector2(-0.3, 1)
			p.spread = 25
			p.gravity = Vector2(-10, 30)
			p.initial_velocity_min = 60
			p.initial_velocity_max = 120
			p.angle_max = 360
			p.angular_velocity_min = -90
			p.angular_velocity_max = 90
			p.scale_amount_min = 0.25
			p.scale_amount_max = 0.55
			p.orbit_velocity_min = 0
			p.preprocess = 9.0
			p.color_ramp = _grad([Color(1, 1, 1, 0), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0)])
			root.add_child(p)
		"snow":
			var p: = particles("glow", 60, 10.0)
			p.material = add_mat()
			p.position = Vector2(area.x * 0.5, -30)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(area.x * 0.6, 10)
			p.direction = Vector2(0.1, 1)
			p.spread = 15
			p.initial_velocity_min = 50
			p.initial_velocity_max = 110
			p.scale_amount_min = 0.05
			p.scale_amount_max = 0.14
			p.preprocess = 10.0
			p.color = Color(0.85, 0.95, 1.0, 0.85)
			root.add_child(p)
		"lanterns":
			var p: = particles("glow", 24, 12.0)
			p.material = add_mat()
			p.position = Vector2(area.x * 0.5, area.y + 40)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(area.x * 0.6, 10)
			p.direction = Vector2(0, -1)
			p.spread = 10
			p.initial_velocity_min = 50
			p.initial_velocity_max = 100
			p.scale_amount_min = 0.18
			p.scale_amount_max = 0.42
			p.preprocess = 12.0
			p.color = Color(1.0, 0.6, 0.3, 0.75)
			p.color_ramp = _grad([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
			root.add_child(p)
		"fireflies":
			var p: = particles("sparkle", 36, 5.0)
			p.material = add_mat()
			p.position = area * 0.5
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = area * 0.5
			p.spread = 180
			p.initial_velocity_min = 5
			p.initial_velocity_max = 25
			p.scale_amount_min = 0.12
			p.scale_amount_max = 0.3
			p.preprocess = 5.0
			p.angular_velocity_min = -40
			p.angular_velocity_max = 40
			p.color = Color(0.85, 0.85, 1.0, 1.0)
			p.color_ramp = _grad([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
			root.add_child(p)
		"mist":
			var p: = particles("glow", 14, 14.0)
			p.position = Vector2(-120, area.y * 0.7)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(20, area.y * 0.35)
			p.direction = Vector2(1, 0)
			p.spread = 5
			p.initial_velocity_min = 50
			p.initial_velocity_max = 80
			p.scale_amount_min = 3.0
			p.scale_amount_max = 5.0
			p.preprocess = 14.0
			p.color = Color(1.0, 0.85, 0.92, 0.22)
			p.color_ramp = _grad([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
			root.add_child(p)
			var g: = particles("sparkle", 20, 6.0)
			g.material = add_mat()
			g.position = Vector2(area.x * 0.5, area.y)
			g.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			g.emission_rect_extents = Vector2(area.x * 0.5, 20)
			g.direction = Vector2(0, -1)
			g.spread = 20
			g.initial_velocity_min = 40
			g.initial_velocity_max = 90
			g.scale_amount_min = 0.1
			g.scale_amount_max = 0.22
			g.preprocess = 6.0
			g.color = Color(1.0, 0.85, 0.45)
			g.color_ramp = _grad([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
			root.add_child(g)
		"rain":
			var p: = particles("confetti", 90, 1.1)
			p.material = add_mat()
			p.position = Vector2(area.x * 0.5, -40)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(area.x * 0.7, 10)
			p.direction = Vector2(-0.18, 1)
			p.spread = 2
			p.initial_velocity_min = 1300
			p.initial_velocity_max = 1600
			p.angle_min = 10
			p.angle_max = 10
			p.scale_amount_min = 0.12
			p.scale_amount_max = 0.2
			p.preprocess = 1.0
			p.color = Color(0.55, 0.85, 1.0, 0.35)
			root.add_child(p)
			var n: = particles("glow", 16, 6.0)
			n.material = add_mat()
			n.position = area * 0.5
			n.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			n.emission_rect_extents = area * 0.5
			n.initial_velocity_max = 10
			n.scale_amount_min = 0.6
			n.scale_amount_max = 1.4
			n.preprocess = 6.0
			n.color = Color(1.0, 0.3, 0.8, 0.18)
			n.hue_variation_min = -0.3
			n.hue_variation_max = 0.3
			n.color_ramp = _grad([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
			root.add_child(n)
		"embers":
			var p: = particles("glow", 40, 3.0)
			p.material = add_mat()
			p.position = Vector2(area.x * 0.5, area.y + 20)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(area.x * 0.55, 10)
			p.direction = Vector2(0, -1)
			p.spread = 15
			p.initial_velocity_min = 260
			p.initial_velocity_max = 520
			p.scale_amount_min = 0.06
			p.scale_amount_max = 0.16
			p.color = Color(1.0, 0.65, 0.3)
			p.color_ramp = _grad([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
			root.add_child(p)
		"stars":
			var p: = particles("sparkle", 40, 3.0)
			p.material = add_mat()
			p.position = area * 0.5
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = area * 0.5
			p.initial_velocity_max = 4
			p.scale_amount_min = 0.08
			p.scale_amount_max = 0.25
			p.preprocess = 3.0
			p.color = Color(1, 0.95, 0.85)
			p.color_ramp = _grad([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
			root.add_child(p)
	if V9Feel.fx_scale() < 1.0:
		for c in root.get_children():
			if c is CPUParticles2D:
				(c as CPUParticles2D).amount = scaled((c as CPUParticles2D).amount)
	return root
