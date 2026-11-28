class_name V10PathFx
extends RefCounted

# 0.10 Path effects. All gated by V9Feel (S.fx_level): «минимум» keeps the press/stamp motion, drops particles
# and fog drift. The interface never shakes (UX_RULES §6.7): the Peak drum and the summit stamp land with sound and
# haptics only; no white flashes (the chest glow is warm gold).
#   fog(parent, rect, density)              drifting fog layer (Peak card, locked Peak art)
#   peak_enter(parent, size, on_done)       0.8 s fog parts, low drum on the strong beat, heavy haptic, stone rim
#   summit_stamp(parent, size, summits, step)   «Вершин: 15» stamp slams in (+ «Восходящая» step every 10)
#   chest_open(chest_node, reward, parent)  spring + lid swap + petals + floating reward chips
#   unlock_burst(parent, pos, col)          a node opens: ring + sparkles + chime

const Rules = preload("res://core/path/path_rules.gd")
const FOG = preload("res://scripts/v10/path/path_fog.gdshader")


# drift = false: a still fog (on a card / window the one endless motion of the screen is «Играть»)
static func fog(parent: Control, r: Rect2, density: = 0.85, tint: = Color(0.86, 0.88, 0.96, 1.0), drift: = true) -> ColorRect:
	var f: = ColorRect.new()
	f.position = r.position
	f.size = r.size
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: = ShaderMaterial.new()
	m.shader = FOG
	m.set_shader_parameter("density", density)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("speed", 0.05 if (drift and V9Feel.can_fx()) else 0.0)
	f.material = m
	f.name = "PathFog"
	parent.add_child(f)
	return f


static func peak_enter(parent: Control, size: Vector2, on_done: = Callable()) -> Control:
	var root: = Control.new()
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.name = "PeakEnter"
	parent.add_child(root)
	var dim: = ColorRect.new()
	dim.size = size
	dim.color = Color(0.05, 0.05, 0.09, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var f: = fog(root, Rect2(Vector2.ZERO, size), 1.0, Color(0.9, 0.92, 1.0, 1.0))
	var m: ShaderMaterial = f.material
	# stone rim of the Peak HUD: a heavy grey-gold frame that lands on the beat
	var rim: = ReferenceRect.new()
	rim.border_color = Color("c9c2b0")
	rim.border_width = 10.0
	rim.editor_only = false
	rim.size = size - Vector2(24, 24)
	rim.position = Vector2(12, 12)
	rim.modulate.a = 0.0
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rim)
	var icon: = Rules.icon("peak")
	var ic: TextureRect = null
	if icon:
		ic = UI.tex(icon, Rect2(size * 0.5 - Vector2(110, 150), Vector2(220, 220)))
		ic.pivot_offset = Vector2(110, 110)
		ic.scale = Vector2(1.6, 1.6)
		ic.modulate.a = 0.0
		root.add_child(ic)
	# a night band under the words keeps them readable over the parting fog (UX_RULES §6.2 contrast)
	var band: = ColorRect.new()
	band.color = Color(Rules.C.night900, 0.72)
	band.position = Vector2(0, size.y * 0.5 + 74)
	band.size = Vector2(size.x, 120)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.modulate.a = 0.0
	root.add_child(band)
	var cap: = UI.center_label(UI.title("Пик", 64, Color("f2f4ff"), Color("2a2f48")), Rect2(0, size.y * 0.5 + 76, size.x, 76))
	cap.modulate.a = 0.0
	root.add_child(cap)
	var sub: = UI.center_label(UI.label("Только честная игра", UI.T_BODY, Rules.C.paper100, Color(0.08, 0.08, 0.14), 4), Rect2(0, size.y * 0.5 + 152, size.x, 34))
	sub.modulate.a = 0.0
	root.add_child(sub)
	var t: = root.create_tween()
	t.tween_interval(0.12)
	t.tween_callback(func():
		V9Feel.sound("summon_boom", 0.55, -2.0)
		V9Feel.haptic("clear"))
	t.tween_method(func(v): m.set_shader_parameter("open", v), 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(rim, "modulate:a", 1.0, 0.18)
	if ic:
		t.parallel().tween_property(ic, "modulate:a", 1.0, 0.25)
		t.parallel().tween_property(ic, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(band, "modulate:a", 1.0, 0.2).set_delay(0.15)
	t.parallel().tween_property(cap, "modulate:a", 1.0, 0.3).set_delay(0.2)
	t.parallel().tween_property(sub, "modulate:a", 1.0, 0.3).set_delay(0.35)
	t.tween_interval(0.35)
	t.tween_property(root, "modulate:a", 0.0, 0.3)
	t.tween_callback(func():
		root.queue_free()
		if on_done.is_valid():
			on_done.call())
	return root


static func summit_stamp(parent: Control, size: Vector2, summits: int, step: int) -> Control:
	var root: = Control.new()
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.name = "SummitStamp"
	parent.add_child(root)
	var dim: = ColorRect.new()
	dim.size = size
	dim.color = Color(0.03, 0.02, 0.05, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var td: = dim.create_tween()
	td.tween_property(dim, "color:a", 0.62, 0.2)
	td.tween_interval(2.4)
	td.tween_property(root, "modulate:a", 0.0, 0.35)
	td.tween_callback(root.queue_free)
	var c: = Vector2(size.x * 0.5, size.y * 0.42)
	var disc: = Control.new()
	disc.size = Vector2(300, 300)
	disc.position = c - Vector2(150, 150)
	disc.pivot_offset = Vector2(150, 150)
	root.add_child(disc)
	var ring: = UI.rbox("graphite", Rect2(Vector2.ZERO, Vector2(300, 300)), 150, 6, 10)
	ring.borders(Color("f2e3b5"), Color("9c7a3a"))
	disc.add_child(ring)
	var ic: = Rules.icon("peak")
	if ic:
		disc.add_child(UI.tex(ic, Rect2(40, 26, 220, 220)))
	var lbl: = UI.center_label(UI.label("Вершин: %d" % summits, UI.T_H2, Color("fff3d6"), Color(0.14, 0.08, 0.05), 6, "title", 900), Rect2(0, 228, 300, 50))
	disc.add_child(lbl)
	disc.scale = Vector2(2.4, 2.4)
	disc.rotation = -0.35
	disc.modulate.a = 0.0
	var t: = disc.create_tween()
	t.tween_property(disc, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(disc, "scale", Vector2(0.94, 0.94), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(disc, "rotation", -0.08, 0.22)
	t.tween_callback(func():
		V9Feel.sound("summon_boom", 0.8, -3.0)
		V9Feel.haptic("clear")
		Fx.burst(root, c, "sparkle", 30, Color(1.0, 0.92, 0.7), 1.2)
		Fx.ring(root, c, Color(1.0, 0.9, 0.6), 2.4, 0.5))
	t.tween_property(disc, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if step > 0:
		var cap: = UI.center_label(UI.label("Рамка «Восходящая» %s" % Rules.roman(step), UI.T_H3, Color("ffe7a6"), Color(0.12, 0.06, 0.04), 5, "title", 900),
			Rect2(0, c.y + 170, size.x, 44))
		cap.modulate.a = 0.0
		root.add_child(cap)
		t.tween_property(cap, "modulate:a", 1.0, 0.3)
		t.tween_callback(func(): V9Feel.success(cap, "sparkle"))
	return root


static func chest_open(chest: Control, reward: Dictionary, fx_parent: Control) -> void:
	if not is_instance_valid(chest):
		return
	chest.pivot_offset = chest.size * 0.5
	var c: Vector2 = chest.get_global_transform_with_canvas() * (chest.size * 0.5) - fx_parent.get_global_transform_with_canvas().origin
	var t: = chest.create_tween()
	t.tween_property(chest, "scale", Vector2(1.18, 0.86), 0.12).set_trans(Tween.TRANS_QUAD)
	t.tween_property(chest, "scale", Vector2(0.92, 1.12), 0.1)
	t.tween_callback(func():
		V9Feel.big(null, "reveal_sr")
		Fx.burst(fx_parent, c, "petal", 26, Color.WHITE, 1.1)
		Fx.burst(fx_parent, c, "sparkle", 22, Color(1.0, 0.9, 0.6), 1.0)
		Fx.flash_glow(fx_parent, c, Color(1.0, 0.76, 0.42), 2.2, 0.4)
		var k: = 0
		for key in reward:
			var txt: = "+%d %s" % [int(reward[key]), {"gems": "кристаллов", "coins": "монет", "petals": "Лепестков", "tickets": "билет"}.get(key, key)]
			var tx: = clampf(c.x, 190.0, fx_parent.size.x - 190.0)
			Fx.float_text(fx_parent, Vector2(tx, c.y - 60 - 46 * k), txt, Color("fff3d6"), UI.T_H3, Color(0.25, 0.1, 0.05))
			k += 1)
	t.tween_property(chest, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func unlock_burst(parent: Control, pos: Vector2, col: = Color(1.0, 0.9, 0.6)) -> void:
	Fx.ring(parent, pos, col, 1.8, 0.45)
	Fx.burst(parent, pos, "sparkle", 18, col, 0.8)
	V9Feel.sound("star1", 1.1, -2.0)
	V9Feel.haptic("match")
