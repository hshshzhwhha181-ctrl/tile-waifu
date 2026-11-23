class_name V6HeroStage
extends Control






signal pressed

const POP: = 64.0
const COUNTER_H: = 58.0

var hero_id: = "mc"
var hero: Hero
var compact: = false
var col: = Color.WHITE
var halo: Sprite2D
var back: RBox
var counter: RBox
var gauge: RBox
var gauge_w: = 100.0
var gauge_lbl: Label
var emote_layer: Node2D
var bubble_node: Control
var charge: = 0
var need: = 8
var is_ready: = false
var _ready_tw: Tween
var _ring: = 0.0
var _sparks: CPUParticles2D
var cast_fx: Node
static var _shared_bubble: Control

func setup(id: String, rect: Rect2, opts: = {}) -> V6HeroStage:
	hero_id = id
	position = rect.position
	size = rect.size
	compact = opts.get("compact", false)
	col = G.HEROES[id].color
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * Vector2(0.5, 0.7)
	if compact:
		_build_compact(opts)
	else:
		_build_full(opts)
	emote_layer = Node2D.new()
	emote_layer.z_index = 5
	add_child(emote_layer)
	gui_input.connect( func(e):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			accept_event()
			pressed.emit())
	return self

func _build_full(opts: Dictionary) -> void :
	back = UI.rbox("glass", Rect2(Vector2.ZERO, size), 26, 3, 10)
	back.colors(Color(col.r * 0.42 + 0.05, col.g * 0.3 + 0.04, col.b * 0.45 + 0.08, 0.92), Color(0.07, 0.04, 0.14, 0.96))
	back.borders(col.lightened(0.45), Color("c58a2c"))
	add_child(back)
	var rig: Dictionary = Hero.RIGS[hero_id]
	var head_top: float = rig.head_c.y - rig.head_r * 1.05
	var waist: float = rig.waist_y
	var vis_h: = size.y - COUNTER_H * 0.45 + 40.0
	var s: float = vis_h / (waist - head_top)
	var clip: = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = Vector2(3, - POP)
	clip.size = Vector2(size.x - 6, size.y + POP - 3)
	add_child(clip)
	halo = Sprite2D.new()
	halo.texture = G.fx("glow")
	halo.material = Fx.add_mat()
	halo.modulate = Color(col.r, col.g, col.b, 0.5)
	clip.add_child(halo)
	hero = Hero.new().setup(hero_id, s * 1160.0)
	hero.interactive = false
	var cx: float = (rig.head_c.x * 0.6 + rig.chest_c.x * 0.4)
	hero.position = Vector2(clip.size.x * 0.5 - (cx - rig.feet.x) * s, POP - 40.0 + (rig.feet.y - head_top) * s)
	clip.add_child(hero)
	halo.position = hero.position + (rig.head_c - rig.feet) * s
	halo.scale = Vector2(3.0, 3.0) * s / 0.42

	counter = UI.rbox("plum", Rect2(-2, size.y - COUNTER_H, size.x + 4, COUNTER_H + 4), 20, 3, 8)
	counter.colors(Color(0.2, 0.1, 0.24, 0.97), Color(0.1, 0.05, 0.14, 0.98)).borders(Color("ffe7a6"), Color("c58a2c"))
	add_child(counter)
	var nm: = UI.label(G.HEROES[hero_id].name, 17, Color.WHITE, Color(0.2, 0.05, 0.2), 3, "body", 900)
	nm.position = Vector2(12, 2)
	nm.size = Vector2(size.x - 70, 24)
	nm.clip_text = true
	counter.add_child(nm)
	var tag: String = opts.get("tag", "")
	if tag != "":
		var tl: = UI.label(tag, 12, Color("ffd98a"), Color(0.1, 0.05, 0.2), 2, "body", 900)
		tl.position = Vector2(size.x - 120, 6)
		tl.size = Vector2(110, 20)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		counter.add_child(tl)
	var gb: = UI.rbox("plum", Rect2(12, 32, size.x - 24, 16), 8, 1, 2)
	gb.colors(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.35)).set_param("shadow_color", Color(0, 0, 0, 0))
	counter.add_child(gb)
	gauge_w = gb.size.x - 4
	gauge = UI.rbox("gold", Rect2(2, 2, 8, 12), 6, 0, 2)
	gauge.colors(Color("fff0b8"), col).set_param("shadow_color", Color(0, 0, 0, 0))
	gb.add_child(gauge)
	gauge_lbl = UI.label("", 12, Color.WHITE, Color(0.1, 0.03, 0.12), 3, "body", 900)
	gauge_lbl.size = gb.size
	gauge_lbl.position = Vector2(0, -3)
	gauge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gb.add_child(gauge_lbl)
	_sparks = Fx.particles("sparkle", 14, 1.0)
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparks.emission_rect_extents = Vector2(size.x * 0.45, size.y * 0.4)
	_sparks.position = size * Vector2(0.5, 0.45)
	_sparks.direction = Vector2(0, -1)
	_sparks.spread = 30
	_sparks.gravity = Vector2(0, -40)
	_sparks.initial_velocity_min = 10
	_sparks.initial_velocity_max = 40
	_sparks.scale_amount_min = 0.15
	_sparks.scale_amount_max = 0.35
	_sparks.color = col.lightened(0.5)
	_sparks.emitting = false
	_sparks.one_shot = false
	_sparks.explosiveness = 0.0
	add_child(_sparks)

func _build_compact(_opts: Dictionary) -> void :
	add_child(Common.avatar(hero_id, Rect2(Vector2(6, 6), size - Vector2(12, 12)), "pink"))

func _draw() -> void :
	if not compact:
		return
	var c: = size * 0.5
	var r: = size.x * 0.5 - 2.0
	draw_arc(c, r, 0, TAU, 48, Color(0, 0, 0, 0.55), 6.0, true)
	if _ring > 0.0:
		draw_arc(c, r, - PI * 0.5, - PI * 0.5 + TAU * _ring, 48, Color("ffe7a6") if is_ready else col.lightened(0.2), 6.0, true)


func head_pos() -> Vector2:

	if hero:
		return get_parent().get_global_transform_with_canvas().affine_inverse() * hero.get_global_transform_with_canvas() * (hero.sprite.position + Hero.RIGS[hero_id].head_c * hero.sprite.scale.x)
	return position + Vector2(size.x * 0.5, 8)

func hand_pos() -> Vector2:
	return position + Vector2(size.x * 0.3, size.y * 0.55) if not compact else position + size * 0.5


func set_charge(cur: int, total: int) -> void :
	charge = cur
	need = maxi(1, total)
	var f: = clampf(float(cur) / need, 0.0, 1.0)
	if compact:
		_ring = f
		queue_redraw()
	elif gauge:
		gauge.create_tween().tween_property(gauge, "size:x", maxf(8.0, gauge_w * f), 0.25).set_trans(Tween.TRANS_QUAD)
		gauge_lbl.text = "КОСНИСЬ: УМЕНИЕ" if cur >= need else "умение %d/%d" % [cur, need]
	if cur >= need and not is_ready:
		_set_ready(true)
	elif cur < need and is_ready:
		_set_ready(false)

func _set_ready(on: bool) -> void :
	is_ready = on
	if _ready_tw:
		_ready_tw.kill()
		_ready_tw = null
	if _sparks:
		_sparks.emitting = on
	if back:
		back.set_param("glow", 1.0 if on else 0.0).set_param("glow_color", col.lightened(0.3))
	if on:
		_ready_tw = create_tween().set_loops()
		if halo:
			_ready_tw.tween_property(halo, "modulate:a", 0.95, 0.45).set_trans(Tween.TRANS_SINE)
			_ready_tw.tween_property(halo, "modulate:a", 0.45, 0.45).set_trans(Tween.TRANS_SINE)
		else:
			_ready_tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.4).set_trans(Tween.TRANS_SINE)
			_ready_tw.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)
		if gauge:
			gauge.set_param("glow", 1.0)
		emote("star")
	else:
		scale = Vector2.ONE
		if halo:
			halo.modulate.a = 0.5
		if gauge:
			gauge.set_param("glow", 0.0)
	queue_redraw()


func absorb(from: Vector2) -> void :
	var p: = get_parent()
	if p == null:
		return
	var s: = Sprite2D.new()
	s.texture = G.fx("sparkle")
	s.material = Fx.add_mat()
	s.modulate = col.lightened(0.4)
	s.scale = Vector2(0.35, 0.35)
	s.z_index = 41
	s.position = from
	p.add_child(s)
	var to: = position + (Vector2(size.x * 0.5, size.y - COUNTER_H * 0.45) if not compact else size * 0.5)
	var ctrl: = from.lerp(to, 0.5) + Vector2(60, -80)
	var t: = s.create_tween()
	t.tween_method( func(v: float): s.position = from.lerp(ctrl, v).lerp(ctrl.lerp(to, v), v), 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(s, "rotation", 4.0, 0.42)
	t.tween_callback(s.queue_free)


func react(kind: String) -> void :
	match kind:
		"match":
			if hero:
				hero.react("tap")
		"combo":
			if hero:
				hero.react("happy")
			if randf() < 0.5:
				emote("star")
		"big":
			if hero:
				hero.react("big")
				hero.flash(0.35)
			emote("heart")
		"deny":
			if hero:
				hero.react("sad")
			emote("sweat")
		"danger":
			emote("bang")
			Fx.shake(self, 4, 0.25)
		"fail":
			if hero:
				hero.react("sad")
			emote("dots")
		"anger":
			if hero:
				hero.react("tap")
			emote("anger")
			Fx.shake(self, 6, 0.3)
		"smug":
			if hero:
				hero.react("happy")
			emote("star")
		"win":
			if hero:
				hero.react("big")
			emote("heart")
	if compact or hero == null:
		UI.punch(self, 0.12 if kind == "match" else 0.25)

func emote(kind: String) -> void :
	var hp: = head_pos() - position
	var at: = hp + Vector2( - size.x * 0.28, -40) if not compact else Vector2(size.x * 0.85, 0)
	var n: = Node2D.new()
	n.position = at
	emote_layer.add_child(n)
	match kind:
		"heart":
			for i in 3:
				var h: = Sprite2D.new()
				h.texture = G.fx("heart")
				h.scale = Vector2(0.28, 0.28) * (1.0 - i * 0.2)
				h.position = Vector2(i * 22 - 10, i * 10)
				h.modulate = Color("ff7fa8")
				n.add_child(h)
		"star":
			for i in 3:
				var h: = Sprite2D.new()
				h.texture = G.fx("sparkle")
				h.material = Fx.add_mat()
				h.scale = Vector2(0.4, 0.4) * (1.0 - i * 0.25)
				h.position = Vector2(i * 24 - 12, - i * 14)
				h.modulate = Color("fff0b8")
				n.add_child(h)
		"sweat":
			var d: = Polygon2D.new()
			var pts: = PackedVector2Array()
			pts.append(Vector2(0, -22))
			for i in range(1, 16):
				var a: = TAU * i / 16.0
				pts.append(Vector2(sin(a) * 9.0, - cos(a) * 9.0))
			d.polygon = pts
			d.color = Color("9fd8ff")
			n.add_child(d)
			var hl: = Polygon2D.new()
			hl.polygon = PackedVector2Array([Vector2(-3, -4), Vector2(0, -10), Vector2(2, -3)])
			hl.color = Color(1, 1, 1, 0.9)
			n.add_child(hl)
			n.position += Vector2(size.x * 0.4 if not compact else 0, 20)
		"bang":
			var l: = UI.label("!", 46, Color("ffd34d"), Color(0.35, 0.05, 0.1), 6, "title", 900)
			l.position = Vector2(-12, -40)
			n.add_child(l)
		"dots":
			var l: = UI.label("...", 34, Color.WHITE, Color(0.2, 0.05, 0.2), 5, "body", 900)
			l.position = Vector2(-20, -36)
			n.add_child(l)
		"anger":
			for i in 4:
				var ln: = Line2D.new()
				ln.width = 5
				ln.default_color = Color("ff4d6a")
				var a: = PI * 0.5 * i + PI * 0.25
				var d2: = Vector2(cos(a), sin(a))
				ln.points = PackedVector2Array([d2 * 6, d2 * 16 + d2.orthogonal() * 4])
				n.add_child(ln)
	n.scale = Vector2(0.3, 0.3)
	var t: = n.create_tween()
	t.tween_property(n, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(n, "position:y", n.position.y - 16, 0.9)
	t.tween_interval(0.3)
	t.tween_property(n, "modulate:a", 0.0, 0.3)
	t.tween_callback(n.queue_free)


func say_text(text: String, dur: = 2.6, talk: = true) -> void :
	if text == "":
		return
	var p: Control = get_parent()
	if _shared_bubble and is_instance_valid(_shared_bubble):
		_shared_bubble.queue_free()
	var w: = 300.0
	var left_side: = position.x > p.size.x * 0.5
	bubble_node = Common.bubble(p, text, Vector2.ZERO, w, not left_side)
	bubble_node.z_index = 42
	var hp: = head_pos()
	var bx: = position.x - w + 36.0 if left_side else position.x + size.x - 30.0
	bubble_node.position = Vector2(clampf(bx, 6.0, p.size.x - w - 6.0), clampf(hp.y - bubble_node.size.y - 4.0, 4.0, 400.0))
	if compact:
		bubble_node.position = Vector2(position.x + size.x * 0.6, position.y + 2.0)
	_shared_bubble = bubble_node
	var b: = bubble_node
	var t: Tween = b.create_tween()
	t.tween_interval(dur)
	t.tween_property(b, "modulate:a", 0.0, 0.3)
	t.tween_callback(b.queue_free)
	if talk:
		Sfx.voice_started.emit(hero_id, text, minf(dur * 0.6, 0.35 + text.length() * 0.05))


func say(kind: String) -> String:
	var line: = Sfx.say(hero_id, kind)
	say_text(line, 2.6, false)
	return line




func cast(title: String, targets: Array, sub: = "") -> void :
	var p: Control = get_parent()
	var layer: Node = cast_fx if cast_fx else p
	if hero:
		hero.react("big")
		hero.flash(0.8)
	UI.punch(self, 0.3)
	Sfx.play("fever", 1.3)
	_cutin(p, title, sub)
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return
	var from: = hand_pos()
	var last: = 0.0
	for i in targets.size():
		var d: = 0.07 * i
		last = d
		_orb(layer, from, targets[i], d)
	await get_tree().create_timer(last + 0.48).timeout

func _orb(layer: Node, from: Vector2, to: Vector2, delay: float) -> void :
	var o: = Node2D.new()
	o.z_index = 160
	o.position = from
	layer.add_child(o)
	var g: = Sprite2D.new()
	g.texture = G.fx("glow")
	g.material = Fx.add_mat()
	g.modulate = Color(col.r, col.g, col.b, 0.95)
	g.scale = Vector2(0.9, 0.9)
	o.add_child(g)
	var c: = Sprite2D.new()
	c.texture = G.fx("sparkle")
	c.material = Fx.add_mat()
	c.scale = Vector2(0.45, 0.45)
	o.add_child(c)
	var tr: = Fx.particles("sparkle", 24, 0.4)
	tr.local_coords = false
	tr.initial_velocity_min = 0
	tr.initial_velocity_max = 20
	tr.scale_amount_min = 0.1
	tr.scale_amount_max = 0.25
	tr.color = col.lightened(0.5)
	tr.emitting = true
	o.add_child(tr)
	o.modulate.a = 0.0
	var ctrl: = from.lerp(to, 0.5) + Vector2(-140 if to.x < from.x else 140, -160)
	var t: = o.create_tween()
	t.tween_interval(delay)
	t.tween_property(o, "modulate:a", 1.0, 0.05)
	t.tween_method( func(v: float):
		o.position = from.lerp(ctrl, v).lerp(ctrl.lerp(to, v), v)
		c.rotation = v * 8.0, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback( func():
		Fx.flash_glow(layer, to, col.lightened(0.4), 2.2, 0.3)
		Fx.burst(layer, to, "sparkle", 18, col.lightened(0.3), 1.1)
		Sfx.play("pop", 1.3, -6)
		tr.emitting = false
		g.visible = false
		c.visible = false)
	t.tween_interval(0.45)
	t.tween_callback(o.queue_free)

func _cutin(p: Control, title: String, sub: String) -> void :
	var W: = p.size.x
	var y0: = 150.0
	var h: = 120.0
	var root: = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 45
	root.position = Vector2(W, y0)
	root.size = Vector2(W, h)
	p.add_child(root)
	var band: = Polygon2D.new()
	band.polygon = PackedVector2Array([Vector2(40, 0), Vector2(W + 40, 0), Vector2(W - 40, h), Vector2(-40, h)])
	var c0: = Color(col.r * 0.55, col.g * 0.35, col.b * 0.6, 0.96)
	var c1: = Color(0.08, 0.04, 0.14, 0.96)
	band.vertex_colors = PackedColorArray([c0, c1, c1, c0])
	root.add_child(band)
	for yy in [2.0, h - 4.0]:
		var ln: = Line2D.new()
		ln.width = 3
		ln.default_color = Color("ffe7a6")
		ln.points = PackedVector2Array([Vector2(40 - 80 * yy / h, yy), Vector2(W + 40 - 80 * yy / h, yy)])
		root.add_child(ln)

	var face: = UI.tex(load("res://assets/hero/%s.png" % hero_id), Rect2(W - 300, -40, 280, h + 40), false)
	var m: = ShaderMaterial.new()
	m.shader = preload("res://shaders/card.gdshader")
	var rig: Dictionary = Hero.RIGS[hero_id]
	m.set_shader_parameter("size", face.size)
	m.set_shader_parameter("radius", 0.0)
	m.set_shader_parameter("tex_size", Vector2(848, 1264))
	m.set_shader_parameter("focus", Vector2(rig.head_c.x / 848.0, (rig.head_c.y + 40) / 1264.0))
	m.set_shader_parameter("zoom", 2.2)
	m.set_shader_parameter("bottom_shade", 0.0)
	face.material = m
	root.add_child(face)
	var tl: = UI.title(title, 40, Color("ffe7a6"), Color(0.25, 0.04, 0.16))
	tl.position = Vector2(40, 16)
	tl.size = Vector2(W - 340, 56)
	root.add_child(tl)
	if sub != "":
		var sl: = UI.label(sub, 18, Color.WHITE, Color(0.1, 0.03, 0.12), 3, "body", 900)
		sl.position = Vector2(44, 72)
		sl.size = Vector2(W - 350, 30)
		sl.clip_text = true
		root.add_child(sl)
	var t: = root.create_tween()
	t.tween_property(root, "position:x", 0.0, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(root, "position:x", -30.0, 0.7)
	t.tween_property(root, "position:x", - W, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(root, "modulate:a", 0.0, 0.16)
	t.tween_callback(root.queue_free)
