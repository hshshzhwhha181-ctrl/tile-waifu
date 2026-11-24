class_name V10FrameView
extends Control

# V10FrameView — an avatar in a Profile 2.0 frame (V10ProfileCos kind "frame").
# Builds on the painted 0.8 avatar frames (V8Art.avatar: frame/avatar ring, frame/avatar_top winged) and adds:
#   * recolour of the painted gold / sakura / amethyst through frame_fx.gdshader (luminance-preserving),
#   * a code-drawn decoration layer (laurel, leaves, gems, pearls, stars, petals, frost, sun, moon, circuit,
#     flames, a text plate for roman numerals / seasons / years),
#   * a halo in the frame's glow colour, a slow sheen and living deco for animated frames.
# Animated frames are static at fx «минимум» and whenever `anim` is off (league rows, posters).
#
#   var f: = V10FrameView.make("fr_g_zlata", "mc_dragon", 200.0, {"anim": true})
#   parent.add_child(f)
#   f.flash()          one glint across the frame (tap feedback)
#   f.set_locked(true) grey preview for the editor's locked cells
# `src` is what V8Art.avatar takes: a hero id, an outfit image id or a Texture2D.

const SHADER: = preload("res://scripts/v10/profile/frame_fx.gdshader")

var frame_id: = ""
var look: = {}
var anim: = false
var art: Control
var frame_tex: TextureRect
var mat: ShaderMaterial
var deco_back: _Deco
var deco_front: _Deco
var glow: Sprite2D


static func col(v, fallback: = Color(0, 0, 0, 0)) -> Color:
	if v is Color:
		return v
	if v is String and v != "":
		return Color(v)
	return fallback


static func fx_on() -> bool:
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root.get_node_or_null("G") == null:
		return true
	return G.fx_level() != "min"


static func make(id: String, src, side: float, opts: = {}) -> V10FrameView:
	var f: = V10FrameView.new()
	f._build(id, src, side, opts)
	return f


func _build(id: String, src, side: float, opts: Dictionary) -> void:
	var e: = V10ProfileCos.entry(id)
	if e.is_empty() or String(e.kind) != "frame":
		e = V10ProfileCos.entry(V10ProfileCos.DEFAULT.frame)
	frame_id = String(e.id)
	look = e.look
	name = "V10Frame"
	size = Vector2(side, side)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anim = bool(look.get("anim", false)) and bool(opts.get("anim", true)) and fx_on()
	var top: = String(look.get("base", "ring")) == "wing"
	var gc: = col(look.get("glow", ""))
	if gc.a > 0.0 and bool(opts.get("glow", true)):
		glow = Sprite2D.new()
		glow.texture = G.fx("glow")
		glow.material = Fx.add_mat()
		glow.position = size * Vector2(0.5, 0.44)
		glow.scale = Vector2.ONE * side / 64.0
		glow.modulate = Color(gc.r, gc.g, gc.b, 0.42 if anim else 0.32)
		add_child(glow)
		if anim:
			var t: = glow.create_tween().set_loops()
			t.tween_property(glow, "modulate:a", 0.24, 1.6).set_trans(Tween.TRANS_SINE)
			t.tween_property(glow, "modulate:a", 0.46, 1.6).set_trans(Tween.TRANS_SINE)
	var deco: = String(look.get("deco", ""))
	if deco in ["laurel", "flames", "sun", "leaves"]:
		deco_back = _Deco.new()
		deco_back.setup(self, deco, true)
		add_child(deco_back)
	art = V8Art.avatar(self, src, Rect2(Vector2.ZERO, size), top)
	frame_tex = art.get_node_or_null("Frame") as TextureRect
	if frame_tex:
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		for k in ["metal", "petal", "violet"]:
			var c: = col(look.get(k, ""))
			mat.set_shader_parameter(k, c if c.a > 0.0 else Color(0, 0, 0, 0))
		mat.set_shader_parameter("sheen_speed", 0.16 if anim else 0.0)
		var sc: = col(look.get("glow", ""), Color("fff4dc"))
		mat.set_shader_parameter("sheen_color", sc.lerp(Color.WHITE, 0.55))
		frame_tex.material = mat
	if deco != "" and not (deco in ["laurel", "flames", "sun", "leaves"]) or String(look.get("text", "")) != "":
		deco_front = _Deco.new()
		deco_front.setup(self, deco if not (deco in ["laurel", "flames", "sun", "leaves"]) else "", false)
		add_child(deco_front)
	set_process(anim)


func _ready() -> void:
	# a script with _process is switched on at ready: keep static frames (rows, fx «минимум») idle
	set_process(anim)


func _process(_dt: float) -> void:
	if deco_back:
		deco_back.queue_redraw()
	if deco_front:
		deco_front.queue_redraw()


func flash() -> void:
	if mat == null:
		return
	var t: = create_tween()
	t.tween_method(func(v): mat.set_shader_parameter("flash", v), -0.3, 1.8, 0.55).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func(): mat.set_shader_parameter("flash", -1.0))


func set_locked(on: bool) -> void:
	if mat:
		mat.set_shader_parameter("desat", 0.85 if on else 0.0)
	var pic: = art.get_node_or_null("Pic") as CanvasItem if art else null
	if pic:
		pic.modulate = Color(0.55, 0.53, 0.58) if on else Color.WHITE
	for d in [deco_back, deco_front]:
		if d:
			d.modulate = Color(0.6, 0.6, 0.65, 0.7) if on else Color.WHITE
	if glow:
		glow.visible = not on


# ------------------------------------------------------------------------------------------------ decoration

class _Deco extends Control:
	var fv: V10FrameView
	var kind: = ""
	var back: = false
	var c0: Color
	var S: = 100.0
	var C: = Vector2.ZERO
	var R: = 40.0

	func setup(f: V10FrameView, k: String, is_back: bool) -> void:
		fv = f
		kind = k
		back = is_back
		size = f.size
		S = f.size.x
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		c0 = V10FrameView.col(f.look.get("deco_col", ""), Color("ffe08a"))
		var top: = String(f.look.get("base", "ring")) == "wing"
		var h: Dictionary = V8Art.HOLE[top]
		C = size * Vector2(h.c)
		R = S * (0.43 if not top else 0.36)

	func _t() -> float:
		return float(Time.get_ticks_msec()) / 1000.0 if fv.anim else 0.0

	func _draw() -> void:
		match kind:
			"laurel":
				_laurel()
			"leaves":
				_leaves()
			"gems":
				_gems()
			"pearls":
				_pearls()
			"stars":
				_stars()
			"petals":
				_petals()
			"frost":
				_frost()
			"sun":
				_sun()
			"moon":
				_moon()
			"circuit":
				_circuit()
			"flames":
				_flames()
		if not back and String(fv.look.get("text", "")) != "":
			_plate(String(fv.look.text))

	func _at(deg: float, r: float) -> Vector2:
		return C + Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg))) * r

	# filled polygon + antialiased rim (polygons have no AA of their own)
	func _poly(pts: PackedVector2Array, fill: Color, rim: Color, w: = 1.2) -> void:
		draw_colored_polygon(pts, fill)
		var loop: = pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, rim, w, true)

	func _ellipse(ctr: Vector2, rx: float, ry: float, rot: float, n: = 14) -> PackedVector2Array:
		var p: = PackedVector2Array()
		for i in n:
			var a: = TAU * i / n
			p.append(ctr + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
		return p

	func _leaf(base: Vector2, dir: float, l: float, w: float, fill: Color, rim: Color) -> void:
		var p: = PackedVector2Array()
		var n: = 12
		for i in n + 1:
			var k: = float(i) / n
			p.append(base + Vector2(k * l, sin(k * PI) * w).rotated(dir))
		for i in range(n - 1, 0, -1):
			var k: = float(i) / n
			p.append(base + Vector2(k * l, -sin(k * PI) * w).rotated(dir))
		_poly(p, fill, rim, 1.0)
		draw_line(base, base + Vector2(l * 0.85, 0).rotated(dir), rim.lightened(0.25), 1.0, true)

	func _laurel() -> void:
		var r: = R + S * 0.035
		var dark: = c0.darkened(0.45)
		for side: float in [-1.0, 1.0]:
			var pts: = PackedVector2Array()
			for i in 15:
				var a: = 90.0 + side * (24.0 + i * 8.6)
				pts.append(_at(a, r))
			draw_polyline(pts, dark, maxf(1.5, S * 0.012), true)
			for i in 9:
				var a: = 90.0 + side * (30.0 + i * 13.5)
				var p: = _at(a, r)
				var tang: = deg_to_rad(a + side * 90.0)
				var lf: = S * (0.085 - i * 0.0035)
				var fill: = c0.lerp(Color("fff3b0"), 0.18 * (i % 2))
				_leaf(p, tang - side * 0.75, lf, lf * 0.34, fill, dark)
				_leaf(p, tang + side * 0.55 + PI * 0.0, lf * 0.9, lf * 0.3, fill.darkened(0.12), dark)
			var tip: = _at(90.0 + side * 152.0, r)
			_leaf(tip, deg_to_rad(90.0 + side * 152.0 + side * 90.0), S * 0.06, S * 0.022, c0, dark)
		# ribbon knot at the bottom
		var b: = _at(90.0, r + S * 0.01)
		_poly(_ellipse(b, S * 0.035, S * 0.022, 0.0), Color("c0304a"), Color("5a0f1e"))

	func _leaves() -> void:
		var dark: = c0.darkened(0.5)
		for side: float in [-1.0, 1.0]:
			for i in 3:
				var a: = 90.0 + side * (58.0 + i * 16.0)
				var p: = _at(a, R + S * 0.005)
				var dir: = deg_to_rad(a) + side * 0.5
				_leaf(p, dir, S * (0.1 - i * 0.012), S * 0.026, c0.lightened(0.08 * i), dark)

	func _gem(p: Vector2, s: float, c: Color) -> void:
		var pts: = PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.72, 0), p + Vector2(0, s), p + Vector2(-s * 0.72, 0)])
		_poly(pts, c.darkened(0.15), Color("fff2c8"), maxf(1.2, s * 0.14))
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.72, 0), p, p + Vector2(-s * 0.72, 0)]), c.lightened(0.28))
		draw_circle(p + Vector2(-s * 0.18, -s * 0.38), s * 0.14, Color(1, 1, 1, 0.85), true, -1.0, true)

	func _gems() -> void:
		var pulse: = 1.0 + 0.06 * sin(_t() * 3.0)
		_gem(_at(-90.0, R + S * 0.01), S * 0.05 * pulse, c0)
		_gem(_at(180.0, R - S * 0.005), S * 0.038, c0)
		_gem(_at(0.0, R - S * 0.005), S * 0.038, c0)

	func _pearl(p: Vector2, r: float) -> void:
		draw_circle(p, r, c0.darkened(0.35), true, -1.0, true)
		draw_circle(p + Vector2(-r * 0.12, -r * 0.12), r * 0.84, c0, true, -1.0, true)
		draw_circle(p + Vector2(-r * 0.32, -r * 0.34), r * 0.32, Color(1, 1, 1, 0.95), true, -1.0, true)

	func _pearls() -> void:
		var n: = 15
		for i in n:
			var a: = 22.0 + (136.0 * i) / (n - 1)
			var sway: = sin(_t() * 1.4 + i * 0.5) * 0.6
			_pearl(_at(a + sway, R + S * 0.012), S * (0.019 if i % 2 == 0 else 0.014))

	func _sparkle(p: Vector2, s: float, c: Color) -> void:
		var pts: = PackedVector2Array()
		for i in 8:
			var a: = PI * 0.25 * i - PI * 0.5
			var r: = s if i % 2 == 0 else s * 0.28
			pts.append(p + Vector2(cos(a), sin(a)) * r)
		_poly(pts, c, c.lerp(Color.WHITE, 0.5), 1.0)
		draw_circle(p, s * 0.18, Color(1, 1, 1, 0.95), true, -1.0, true)

	func _stars() -> void:
		var t: = _t()
		var spots: = [[-90.0, 0.075, 0.0], [-118.0, 0.045, 1.3], [-62.0, 0.045, 2.1], [-146.0, 0.03, 0.7], [-34.0, 0.03, 2.9]]
		for sp in spots:
			var k: = 1.0 if not fv.anim else 0.75 + 0.25 * sin(t * 2.2 + float(sp[2]) * 2.0)
			_sparkle(_at(float(sp[0]), R + S * 0.045), S * float(sp[1]) * k, c0)

	func _flower(p: Vector2, s: float, rot: float, c: Color) -> void:
		for i in 5:
			var a: = rot + TAU * i / 5.0
			_poly(_ellipse(p + Vector2(cos(a), sin(a)) * s * 0.55, s * 0.5, s * 0.34, a), c, c.darkened(0.35), 1.0)
		draw_circle(p, s * 0.22, Color("ffe08a"), true, -1.0, true)

	func _petals() -> void:
		var t: = _t()
		_flower(_at(-128.0, R + S * 0.0), S * 0.07, t * 0.15, c0)
		_flower(_at(-148.0, R + S * 0.05), S * 0.045, 0.6 - t * 0.2, c0.lightened(0.15))
		_flower(_at(40.0, R + S * 0.01), S * 0.05, 1.1 + t * 0.12, c0)
		if fv.anim:
			for i in 3:
				var ph: = fmod(t * 0.22 + i * 0.33, 1.0)
				var p: = C + Vector2(S * (0.22 + 0.12 * i) - S * 0.5 + sin(ph * 6.0 + i) * S * 0.04, -S * 0.42 + ph * S * 0.95)
				var a: = 1.0 - absf(ph - 0.5) * 2.0
				draw_colored_polygon(_ellipse(p, S * 0.018, S * 0.011, ph * 7.0 + i), Color(c0.r, c0.g, c0.b, a * 0.9))

	func _flake(p: Vector2, s: float, rot: float, c: Color) -> void:
		for i in 6:
			var a: = rot + TAU * i / 6.0
			var d: = Vector2(cos(a), sin(a))
			draw_line(p, p + d * s, c, maxf(1.2, s * 0.12), true)
			for k: float in [0.45, 0.72]:
				var q: = p + d * s * k
				draw_line(q, q + d.rotated(0.8) * s * 0.28, c, maxf(1.0, s * 0.08), true)
				draw_line(q, q + d.rotated(-0.8) * s * 0.28, c, maxf(1.0, s * 0.08), true)
		draw_circle(p, s * 0.14, Color.WHITE, true, -1.0, true)

	func _frost() -> void:
		var t: = _t()
		_flake(_at(-132.0, R + S * 0.02), S * 0.075, t * 0.3, c0)
		_flake(_at(-48.0, R + S * 0.03), S * 0.055, -t * 0.25 + 0.4, c0)
		_flake(_at(150.0, R + S * 0.02), S * 0.04, t * 0.2, c0.lightened(0.2))
		_sparkle(_at(-90.0, R + S * 0.05), S * 0.035, Color(1, 1, 1, 0.9))

	func _sun() -> void:
		var t: = _t()
		var n: = 18
		for i in n:
			var a: = -90.0 + (i - n * 0.5 + 0.5) * 9.0 + sin(t * 0.8) * 1.5
			var l: = S * (0.07 if i % 2 == 0 else 0.045)
			var p0: = _at(a - 2.2, R - S * 0.01)
			var p1: = _at(a + 2.2, R - S * 0.01)
			var tip: = _at(a, R + l)
			draw_colored_polygon(PackedVector2Array([p0, tip, p1]), Color(c0.r, c0.g, c0.b, 0.9 - absf(i - n * 0.5) * 0.06))

	func _moon() -> void:
		var p: = _at(-50.0, R + S * 0.02)
		var r: = S * 0.075
		var pts: = PackedVector2Array()
		var rot: = deg_to_rad(-35.0)
		for i in 25:
			var a: = deg_to_rad(-90.0 - 180.0 * i / 24.0)
			pts.append(p + Vector2(cos(a) * r, sin(a) * r).rotated(rot))
		for i in range(23, 0, -1):
			var a: = deg_to_rad(-90.0 - 180.0 * i / 24.0)
			pts.append(p + Vector2(cos(a) * r * 0.42, sin(a) * r).rotated(rot))
		_poly(pts, c0, c0.darkened(0.4), 1.2)
		_sparkle(_at(-28.0, R + S * 0.06), S * 0.025, Color.WHITE)
		_sparkle(_at(-140.0, R + S * 0.04), S * 0.03, c0)

	func _circuit() -> void:
		var t: = _t()
		var glowc: = Color(c0.r, c0.g, c0.b, 0.85)
		for side: float in [-1.0, 1.0]:
			for k in 3:
				var a: = -90.0 + side * (40.0 + k * 22.0)
				var p0: = _at(a, R - S * 0.005)
				var p1: = _at(a, R + S * (0.05 + 0.015 * k))
				var p2: = p1 + Vector2(side * S * 0.05, 0)
				draw_polyline(PackedVector2Array([p0, p1, p2]), glowc, maxf(1.5, S * 0.012), true)
				var pulse: = 0.6 + 0.4 * sin(t * 4.0 + k + side)
				draw_circle(p2, S * 0.016, Color(1, 1, 1, pulse), true, -1.0, true)
				draw_circle(p2, S * 0.03, Color(c0.r, c0.g, c0.b, 0.25 * pulse), true, -1.0, true)

	func _flames() -> void:
		var t: = _t()
		var n: = 11
		for i in n:
			var a: = -90.0 + (i - (n - 1) * 0.5) * 14.0
			var h: = S * (0.12 - absf(i - (n - 1) * 0.5) * 0.012) * (1.0 + 0.18 * sin(t * 7.0 + i * 1.7))
			var b0: = _at(a - 6.0, R - S * 0.02)
			var b1: = _at(a + 6.0, R - S * 0.02)
			var tip: = _at(a + 3.0 * sin(t * 3.0 + i), R + h)
			var mid0: = _at(a - 4.0, R + h * 0.45)
			var mid1: = _at(a + 4.0, R + h * 0.45)
			var pts: = PackedVector2Array([b0, mid0, tip, mid1, b1])
			var cols: = PackedColorArray([Color("ffd24a"), Color("ff8a2a"), Color(1.0, 0.25, 0.1, 0.0), Color("ff8a2a"), Color("ffd24a")])
			draw_polygon(pts, cols)

	func _plate(text: String) -> void:
		var f: = UI.font("title" if S >= 150.0 else "body", 900)
		var fs: = maxi(11, int(S * 0.085))
		var tw: = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w: = maxf(S * 0.2, tw + S * 0.09)
		var h: = fs * 1.45
		var top: = String(fv.look.get("base", "ring")) == "wing"
		var cy: = S * (0.835 if not top else 0.86)
		var r: = Rect2(Vector2(S * 0.5 - w * 0.5, cy - h * 0.5), Vector2(w, h))
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.07, 0.09, 0.96)
		sb.border_color = c0.lerp(Color("ffe7a6"), 0.35)
		sb.set_border_width_all(maxi(1, int(S * 0.012)))
		sb.set_corner_radius_all(int(h * 0.5))
		sb.anti_aliasing = true
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = maxi(1, int(S * 0.015))
		draw_style_box(sb, r)
		# tiny diamonds on both ends
		for sx: float in [-1.0, 1.0]:
			var p: = Vector2(S * 0.5 + sx * (w * 0.5 + S * 0.012), cy)
			var d: = S * 0.02
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -d), p + Vector2(d * 0.8, 0), p + Vector2(0, d), p + Vector2(-d * 0.8, 0)]), c0.lerp(Color("ffe7a6"), 0.4))
		var asc: = f.get_ascent(fs)
		var desc: = f.get_descent(fs)
		draw_string_outline(f, Vector2(S * 0.5 - tw * 0.5, cy + (asc - desc) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.6))
		draw_string(f, Vector2(S * 0.5 - tw * 0.5, cy + (asc - desc) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c0.lerp(Color("fff4d6"), 0.55))
