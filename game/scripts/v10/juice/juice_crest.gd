class_name V10JuiceCrest
extends Control

# V10JuiceCrest — rank-up crest reveal (2.5 s + hold): the screen dims to night (not white), god-rays turn
# behind the crest, the crest materialises through a warm dissolve edge while it drops from 1.5× and lands
# (gong, ring, sparks, a light shake), the rank name stamps in, a glint crosses the crest, then its outline
# breathes. Tap (after the landing) or `hold` seconds closes it.

var scrim: ColorRect
var rays: ColorRect
var crest: TextureRect
var title_l: Label
var sub_l: Label
var hint_l: Label
var can_close: = false
var closing: = false
var done_cb: Callable
var col: = Color(1.0, 0.8, 0.4)
var hold_left: = 0.0


static func make(parent: Node, tex: Texture2D, title: String, subtitle: String, color: Color, hold: float, on_done: Callable) -> V10JuiceCrest:
	var c: = V10JuiceCrest.new()
	c.done_cb = on_done
	c.col = color
	parent.add_child(c)
	c._build(tex, title, subtitle, hold)
	return c


func _build(tex: Texture2D, title: String, subtitle: String, hold: float) -> void:
	var vs: = V10Juice.vp_size()
	size = vs
	mouse_filter = Control.MOUSE_FILTER_STOP
	var full: = V10Juice.can_fx()
	var cc: = Vector2(vs.x * 0.5, vs.y * 0.4)
	hold_left = hold + 1.3

	scrim = ColorRect.new()
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.size = vs
	scrim.color = Color(0.035, 0.028, 0.045, 0.0)
	add_child(scrim)
	var ts: = create_tween()
	ts.tween_property(scrim, "color:a", 0.72, 0.28)

	if full:
		var rs: = vs.x * 1.5
		rays = ColorRect.new()
		rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rays.position = cc - Vector2(rs, rs) * 0.5
		rays.size = Vector2(rs, rs)
		rays.material = V10Juice.mat("juice_godrays", {"color": col, "intensity": 0.0, "count": 10.0, "speed": 0.05, "falloff": 1.6})
		add_child(rays)
		var tr: = rays.create_tween()
		tr.tween_interval(0.25)
		tr.tween_method(func(v): V10Juice.param(rays, "intensity", v), 0.0, 0.7, 0.6).set_trans(Tween.TRANS_SINE)

	crest = TextureRect.new()
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest.texture = tex
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.size = Vector2(320, 320)
	crest.position = cc - crest.size * 0.5
	crest.pivot_offset = crest.size * 0.5
	add_child(crest)
	crest.scale = Vector2(1.5, 1.5)
	crest.modulate.a = 0.0 if not full else 1.0
	var tc: = create_tween()
	tc.tween_interval(0.12)
	if full:
		var dm: = V10Juice.mat("juice_dissolve", {"amount": 1.0, "edge_color": col.lerp(Color(0.95, 0.5, 0.25), 0.5), "edge_core": col, "scale": 5.0, "seed": randf() * 10.0})
		crest.material = dm
		tc.tween_method(func(v): dm.set_shader_parameter("amount", v), 1.0, 0.0, 0.5).set_trans(Tween.TRANS_SINE)
		tc.parallel().tween_property(crest, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tc.tween_property(crest, "modulate:a", 1.0, 0.2)
		tc.parallel().tween_property(crest, "scale", Vector2.ONE, 0.25)
	tc.tween_callback(_land.bind(cc, full))

	title_l = UI.label(title, 54, Color("f6e2b0"), Color(0.12, 0.06, 0.03), 8, "title", 900)
	title_l.size = Vector2(vs.x - 40, 80)
	title_l.position = Vector2(20, cc.y + 190)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.pivot_offset = title_l.size * 0.5
	title_l.modulate.a = 0.0
	add_child(title_l)
	sub_l = UI.label(subtitle, 24, Color("ddd2c4"), Color(0.05, 0.04, 0.05), 4)
	sub_l.size = Vector2(vs.x - 60, 40)
	sub_l.position = Vector2(30, cc.y + 272)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_l.modulate.a = 0.0
	add_child(sub_l)
	hint_l = UI.label("Коснитесь, чтобы продолжить", 18, Color("b3a89c"), Color(0, 0, 0, 0), 0)
	hint_l.size = Vector2(vs.x, 30)
	hint_l.position = Vector2(0, vs.y * 0.86)
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_l.modulate.a = 0.0
	add_child(hint_l)


func _land(cc: Vector2, full: bool) -> void:
	can_close = true
	V10Juice.sound("rank_gong", 1.0, -3.0)
	V10Juice.haptic("ssr")
	if full:
		crest.material = V10Juice.mat("juice_glint", {"color": Color(1.0, 0.88, 0.6), "pos": -0.4, "amount": 0.6, "max_add": 0.3})
		var gm: = crest.material as ShaderMaterial
		var tg: = create_tween()
		tg.tween_interval(0.25)
		tg.tween_method(func(v): gm.set_shader_parameter("pos", v), -0.4, 1.4, 0.6).set_trans(Tween.TRANS_SINE)
		tg.tween_callback(func():
			if is_instance_valid(crest):
				crest.material = V10Juice.mat("juice_outline_glow", {"glow_color": col, "radius": 9.0, "strength": 0.9, "pulse": 1.0, "pulse_speed": 0.7}))
		V10Juice.ripple(self, cc, col, 300.0, 0.7, 0.05)
		V10Juice.ripple(self, cc, col.lerp(Color(1, 0.6, 0.4), 0.5), 200.0, 0.5, 0.04)
		V10Juice.burst(self, cc, "spark", 26, col.lightened(0.15), 1.3)
		V10Juice.burst(self, cc, "star4", 14, Color(1, 0.92, 0.72), 1.5)
		V10Juice.burst(self, cc + Vector2(0, 40), "confetti_gold", 30, col, 1.2)
		V10Juice.shake(0.3)
	# title stamp
	title_l.scale = Vector2(1.8, 1.8)
	var tt: = create_tween().set_parallel()
	tt.tween_property(title_l, "modulate:a", 1.0, 0.14).set_delay(0.12)
	tt.tween_property(title_l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.12)
	var sp: = sub_l.position
	sub_l.position = sp + Vector2(0, 16)
	tt.tween_property(sub_l, "modulate:a", 1.0, 0.3).set_delay(0.4)
	tt.tween_property(sub_l, "position", sp, 0.4).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT).set_delay(0.4)
	tt.tween_property(hint_l, "modulate:a", 0.8, 0.4).set_delay(1.1)
	tt.chain().tween_callback(func():
		if is_instance_valid(title_l):
			V10Juice.sheen(title_l, Color(1, 0.86, 0.55), 0.6, 0.5))


func _process(dt: float) -> void:
	if not can_close or closing:
		return
	hold_left -= dt
	if hold_left <= 0.0:
		close()


func _gui_input(e: InputEvent) -> void:
	if can_close and ((e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)):
		accept_event()
		close()


func close() -> void:
	if closing:
		return
	closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(func():
		if done_cb.is_valid():
			done_cb.call()
		queue_free())
