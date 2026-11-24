class_name V9Lantern
extends Control

# V9Lantern — the summon lantern (0.9 §E). Hangs on a gold cord from above the screen and sways around the cord's
# anchor. Art: res://assets/v09/summon/lantern_{r,sr,ssr}.png when present (V9Summon.lantern_tex), otherwise a
# lantern drawn in code in the same colours. Purely visual: mouse_filter IGNORE everywhere.
#
#   var l: = V9Lantern.new(); l.setup(height, "R"); parent.add_child(l)   unlit silhouette, `size` = (0.67h, h)
#   l.drop_in(from_y, to_y, dur)    falls in on its cord with a damped swing
#   l.light(dur)                    the dark lantern lights up in its current colour
#   l.morph(rar, dur)               cross-fades to another rarity's lantern (colour climb), with a punch
#   l.charge(on)                    SSR build-up: faster flicker and a trembling body (follows S.fx_level)
#   l.open(dur)                     swells, flares and fades out: the cards come out of it
#   l.centre() -> Vector2           the lantern body's centre in the parent's coordinates

const ASPECT: = 0.67
const UNLIT: = Color(0.2, 0.18, 0.26)
const CORD: = 900.0

var rar: = "R"
var lit: = 0.0
var code_only: = false
var inner: Control
var body: Control
var glow: Sprite2D
var flame: Sprite2D
var t: = 0.0
var swing: = 1.2
var swing_rest: = 1.2
var charging: = false
var h: = 460.0


func setup(height: float, start_rar: = "R", force_code: = false) -> V9Lantern:
	h = height
	rar = start_rar
	code_only = force_code
	size = Vector2(h * ASPECT, h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# swing around the cord's anchor far above the lantern, so the whole lantern moves like a pendulum
	pivot_offset = Vector2(size.x * 0.5, -CORD)
	glow = Sprite2D.new()
	glow.texture = G.fx("glow")
	glow.material = Fx.add_mat()
	glow.position = Vector2(size.x * 0.5, h * 0.48)
	glow.scale = Vector2.ONE * (h / 128.0) * 1.5
	glow.modulate = Color(V9Summon.COL[rar], 0.0)
	add_child(glow)
	inner = Control.new()
	inner.size = size
	inner.pivot_offset = Vector2(size.x * 0.5, h * 0.48)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inner)
	body = _make_body(rar)
	body.modulate = UNLIT
	inner.add_child(body)
	flame = Sprite2D.new()
	flame.texture = G.fx("glow")
	flame.material = Fx.add_mat()
	flame.position = Vector2(size.x * 0.5, h * 0.45)
	flame.scale = Vector2.ONE * (h / 128.0) * 0.55
	flame.modulate = Color(1, 0.95, 0.8, 0.0)
	inner.add_child(flame)
	return self


func uses_art() -> bool:
	return not code_only and V9Summon.lantern_tex(rar) != null


func centre() -> Vector2:
	return position + Vector2(size.x * 0.5, h * 0.48)


func _make_body(r: String) -> Control:
	var tex: Texture2D = null if code_only else V9Summon.lantern_tex(r)
	if tex:
		var tr: = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.size = size
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var c: = CodeLantern.new()
	c.size = size
	c.rar = r
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _draw() -> void :
	# the cord: from the anchor far above down to the lantern's ring
	var top: = Vector2(size.x * 0.5, 4.0)
	draw_line(top - Vector2(0, CORD), top, Color(0.42, 0.3, 0.12, 0.9), 5.0, true)
	draw_line(top - Vector2(1, CORD), top - Vector2(1, 0), Color(1.0, 0.86, 0.5, 0.85), 2.0, true)


func _process(dt: float) -> void :
	t += dt
	swing = lerpf(swing, swing_rest, minf(1.0, dt * 0.9))
	rotation = deg_to_rad(swing * sin(t * 1.7))
	if lit > 0.0:
		var fl: = 0.82 + 0.1 * sin(t * 7.3) + 0.08 * sin(t * 12.1 + 1.3)
		if charging:
			fl = 0.85 + 0.15 * sin(t * 26.0)
		# «минимум»: the lantern keeps its colour (it is the rarity tell), its halo is halved
		var k: = 1.0 if V9Feel.can_fx() else 0.5
		flame.modulate.a = lit * fl * (0.55 if uses_art() else 0.8) * k
		glow.modulate.a = lit * (0.55 + 0.12 * sin(t * 2.2)) * (1.25 if charging else 1.0) * k
		if charging and V9Feel.can_shake():
			inner.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.5
		elif inner.position != Vector2.ZERO:
			inner.position = Vector2.ZERO


func drop_in(from_y: float, to_y: float, dur: = 0.8) -> void :
	position.y = from_y
	swing = 7.0
	var tw: = create_tween()
	tw.tween_property(self, "position:y", to_y, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func light(dur: = 0.4) -> void :
	var tw: = create_tween().set_parallel()
	tw.tween_property(body, "modulate", Color.WHITE, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "lit", 1.0, dur)
	_punch(1.06)
	swing = maxf(swing, 3.0)


func morph(to: String, dur: = 0.35) -> void :
	if to == rar:
		return
	rar = to
	var old: = body
	body = _make_body(to)
	body.modulate = Color(1, 1, 1, 0)
	inner.add_child(body)
	inner.move_child(body, old.get_index() + 1)
	var tw: = create_tween().set_parallel()
	tw.tween_property(body, "modulate:a", 1.0, dur)
	tw.tween_property(old, "modulate:a", 0.0, dur)
	tw.tween_property(glow, "modulate", Color(V9Summon.COL[to], glow.modulate.a), dur)
	tw.chain().tween_callback(old.queue_free)
	_punch(1.12 if to == "SSR" else 1.08)
	swing = maxf(swing, 4.5)
	Fx.ring(get_parent(), centre(), V9Summon.COL[to], 2.6, 0.6)


func charge(on: bool) -> void :
	charging = on


func open(dur: = 0.4) -> void :
	charging = false
	var tw: = create_tween().set_parallel()
	tw.tween_property(inner, "scale", Vector2(1.3, 1.3), dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(inner, "modulate:a", 0.0, dur).set_delay(dur * 0.25)
	tw.tween_property(glow, "scale", glow.scale * 2.4, dur)
	tw.tween_property(glow, "modulate:a", 0.0, dur * 1.4)
	tw.tween_property(self, "modulate:a", 0.0, dur * 1.4).set_delay(dur * 0.2)


func _punch(k: float) -> void :
	inner.scale = Vector2.ONE
	var tw: = inner.create_tween()
	tw.tween_property(inner, "scale", Vector2(k, k), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(inner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# the fallback lantern: lacquered paper body in the rarity colour, gold ribs, caps, ring and a rose tassel
class CodeLantern extends Control:
	var rar: = "R"

	func _ell(c: Vector2, r: Vector2, n: = 48) -> PackedVector2Array:
		var pts: = PackedVector2Array()
		for i in n:
			var a: = TAU * i / n
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		return pts

	func _draw() -> void :
		var w: = size.x
		var hh: = size.y
		var col: Color = V9Summon.COL[rar]
		var gold: = Color("e9b949")
		var gold_d: = Color("8a5a16")
		var cx: = w * 0.5
		var c: = Vector2(cx, hh * 0.48)
		var r: = Vector2(w * 0.44, hh * 0.27)
		# ring + hook
		draw_arc(Vector2(cx, hh * 0.05), hh * 0.035, 0, TAU, 24, gold, hh * 0.012, true)
		draw_line(Vector2(cx, hh * 0.085), Vector2(cx, hh * 0.15), gold, hh * 0.012, true)
		# body: darker rim, colour, lit centre
		draw_colored_polygon(_ell(c, r + Vector2(4, 4)), col.darkened(0.55))
		draw_colored_polygon(_ell(c, r), col.darkened(0.12))
		draw_colored_polygon(_ell(c + Vector2(-r.x * 0.08, -r.y * 0.06), r * Vector2(0.72, 0.78)), col.lerp(Color.WHITE, 0.25))
		draw_colored_polygon(_ell(c + Vector2(-r.x * 0.12, -r.y * 0.1), r * Vector2(0.36, 0.42)), col.lerp(Color(1, 0.98, 0.9), 0.6))
		# gold ribs: vertical ellipse slices
		for k in [-0.72, -0.36, 0.0, 0.36, 0.72]:
			var rx: = absf(k) * r.x
			var pts: = PackedVector2Array()
			for i in 25:
				var a: = -PI * 0.5 + PI * i / 24.0
				pts.append(Vector2(cx + signf(k) * rx * cos(a) if k != 0.0 else cx, c.y + sin(a) * r.y))
			draw_polyline(pts, Color(gold, 0.85), hh * 0.007, true)
		# caps
		var cap_w: = w * 0.5
		draw_rect(Rect2(cx - cap_w * 0.5, c.y - r.y - hh * 0.05, cap_w, hh * 0.06), gold_d)
		draw_rect(Rect2(cx - cap_w * 0.5 + 3, c.y - r.y - hh * 0.05 + 3, cap_w - 6, hh * 0.06 - 6), gold)
		draw_rect(Rect2(cx - cap_w * 0.45, c.y + r.y - hh * 0.01, cap_w * 0.9, hh * 0.055), gold_d)
		draw_rect(Rect2(cx - cap_w * 0.45 + 3, c.y + r.y - hh * 0.01 + 3, cap_w * 0.9 - 6, hh * 0.055 - 6), gold)
		# tassel
		var ty: = c.y + r.y + hh * 0.045
		draw_line(Vector2(cx, ty), Vector2(cx, ty + hh * 0.06), gold, hh * 0.01, true)
		draw_circle(Vector2(cx, ty + hh * 0.07), hh * 0.018, gold)
		var rose: = Color("e88aa6")
		for i in 9:
			var dx: = (i - 4) * w * 0.014
			draw_line(Vector2(cx + dx * 0.4, ty + hh * 0.085), Vector2(cx + dx, ty + hh * 0.22), rose.darkened(0.1 * (i % 2)), hh * 0.009, true)
		draw_rect(Rect2(cx - w * 0.04, ty + hh * 0.08, w * 0.08, hh * 0.02), gold)
