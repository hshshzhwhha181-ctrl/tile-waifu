class_name V6SpecIcon
extends Node2D





const HW: = 42.0
const HH: = 43.6
const OUT: = Color(0.16, 0.06, 0.2)

var kind: = ""
var col: = Color("f6c453")
var n: = 0
var open_t: = 0.0
var _t: = 0.0
var _font: Font

static func group_color(g: int) -> Color:
	return [Color("f6c453"), Color("ff7fa8"), Color("5fd0c0")][g % 3]

func _init(k: String, c: = Color("f6c453"), count: = 0) -> void :
	kind = k
	col = c
	n = count
	pass

func _ready() -> void :
	_font = UI.font("body", 900)
	# 0.8 glyphs (icon/gift, icon/lock) are drawn small: sample their mipmaps
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_process(kind in ["joker", "bomb", "gift"])

func _process(dt: float) -> void :
	_t += dt
	queue_redraw()

func set_count(v: int) -> void :
	n = v
	queue_redraw()
	var tw: = create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func release(cb: = Callable()) -> void :
	set_process(true)
	var tw: = create_tween()
	tw.tween_property(self, "open_t", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.12)
	tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.16)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
	if cb.is_valid():
		tw.tween_callback(cb)
	tw.tween_callback(queue_free)


func _rrect(r: Rect2, rad: float, c: Color) -> void :
	var pts: = PackedVector2Array()
	var cs: = [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad), Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	var a0: = [ - PI * 0.5, 0.0, PI * 0.5, PI]
	for i in 4:
		for k in 7:
			var a: float = a0[i] + PI * 0.5 * k / 6.0
			pts.append(cs[i] + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, c)

func _star(c: Vector2, r_out: float, r_in: float, rot: float) -> PackedVector2Array:
	var pts: = PackedVector2Array()
	for i in 10:
		var a: = rot - PI * 0.5 + PI * i / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r_out if i % 2 == 0 else r_in))
	return pts

func _badge(c: Vector2, r: float, fill: Color) -> void :
	draw_circle(c + Vector2(0, 2.5), r + 2.5, Color(0, 0, 0, 0.35))
	draw_circle(c, r + 2.5, Color("ffe7a6"))
	draw_circle(c, r, fill)
	draw_arc(c, r - 3.0, PI * 1.1, PI * 1.9, 10, Color(1, 1, 1, 0.25), 2.5, true)

func _draw() -> void :
	match kind:
		"gift": _draw_gift()
		"key": _draw_key(Vector2(HW - 12, - HH + 10), 1.0)
		"lock": _draw_lock()
		"chain": _draw_chain()
		"joker": _draw_joker()
		"bomb": _draw_bomb()

func _draw_gift() -> void :
	# 0.8: the gold gift glyph (icon/gift) on the tile's top-left corner, rocking a little
	var tex: = V8Art.icon("gift")
	var c: = Vector2( - HW + 15, - HH + 15)
	var sz: = 36.0
	draw_set_transform(c, sin(_t * 3.0) * 0.08, Vector2.ONE)
	draw_circle(Vector2(0, 2), sz * 0.5 + 1.0, Color(0, 0, 0, 0.25))
	if tex:
		draw_texture_rect(tex, Rect2(Vector2(-sz, -sz) * 0.5, Vector2(sz, sz)), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var tw: = 0.5 + 0.5 * sin(_t * 4.0)
	draw_colored_polygon(_star(Vector2(HW - 10, HH - 12), 6.0 * tw + 1.0, 1.6, 0.0), Color(1, 0.95, 0.7, 0.9 * tw))

func _draw_key(c: Vector2, s: float) -> void :
	_badge(c, 14.0 * s, Color(0.27, 0.12, 0.32))
	var k: = col
	var kd: = col.darkened(0.45)
	var ring_c: = c + Vector2(-5, -5) * s
	var tip: = c + Vector2(7, 7) * s
	draw_line(ring_c, tip, kd, 5.5 * s, true)
	draw_line(ring_c, tip, k, 3.2 * s, true)
	draw_line(tip + Vector2(-3.5, 0.5) * s, tip + Vector2(-0.5, 3.5) * s + Vector2(-3.5, 0.5) * s, k, 3.0 * s, true)
	draw_line(tip + Vector2(-7, -2.5) * s, tip + Vector2(-7, -2.5) * s + Vector2(-2.5, 2.5) * s, k, 3.0 * s, true)
	draw_circle(ring_c, 6.0 * s, kd)
	draw_circle(ring_c, 4.6 * s, k)
	draw_circle(ring_c, 2.0 * s, Color(0.27, 0.12, 0.32))

func _draw_lock() -> void :
	# 0.8: the gold lock glyph (icon/lock) on a disc of the lock's group colour (its key has the same colour)
	var a: = 1.0 - open_t
	_rrect(Rect2( - HW + 3, - HH + 3, HW * 2 - 6, HH * 2 - 6), 9.0, Color(0.12, 0.05, 0.2, 0.5 * a + 0.05))
	var c: = Vector2(0, 2)
	_badge(c, 22.0, Color(col.darkened(0.35), 0.95))
	var tex: = V8Art.icon("lock")
	if tex:
		var sz: = 38.0
		var lift: = -10.0 * open_t
		draw_texture_rect(tex, Rect2(c + Vector2(-sz * 0.5, -sz * 0.5 + lift), Vector2(sz, sz)), false, Color(1, 1, 1, clampf(a * 1.4, 0.0, 1.0)))

func _draw_chain() -> void :
	var a: = 1.0 - open_t
	_rrect(Rect2( - HW + 3, - HH + 3, HW * 2 - 6, HH * 2 - 6), 9.0, Color(0.1, 0.08, 0.16, 0.32 * a))
	var steel: = Color("c9c4d6")
	var spread: = open_t * 18.0
	for d in [Vector2(1, 1), Vector2(1, -1)]:
		var dir: Vector2 = d.normalized()
		var nrm: = Vector2( - dir.y, dir.x)
		for i in range(-4, 5):
			var p: Vector2 = dir * (i * 11.0) + nrm * spread * (1 if i % 2 == 0 else -1)
			if absf(p.x) > HW - 4 or absf(p.y) > HH - 4:
				continue
			var horiz: = i % 2 == 0
			var ax: Vector2 = dir if horiz else nrm
			var pts: = PackedVector2Array()
			for k in 13:
				var t: = TAU * k / 12.0
				pts.append(p + ax * cos(t) * 7.0 + (nrm if horiz else dir) * sin(t) * 4.0)
			draw_polyline(pts, OUT, 4.5, true)
			draw_polyline(pts, steel, 2.4, true)
	if open_t < 0.3:
		_badge(Vector2(0, 0), 14.0, Color(0.32, 0.3, 0.42))
		var s: = str(n)
		var fs: = 20
		var w: = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(_font, Vector2( - w * 0.5, 7.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, OUT)
		draw_string(_font, Vector2( - w * 0.5, 7.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _draw_joker() -> void :
	_rrect(Rect2( - HW + 1, - HH + 1, HW * 2 - 2, HH * 2 - 2), 10.0, Color("fff3df"))
	_rrect(Rect2( - HW + 5, - HH + 5, HW * 2 - 10, HH * 2 - 10), 8.0, Color("2b1840"))

	for i in 8:
		var a: = _t * 0.6 + TAU * i / 8.0
		var c: = Color.from_hsv(fposmod(i / 8.0 + _t * 0.1, 1.0), 0.55, 1.0, 0.35)
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(cos(a - 0.18), sin(a - 0.18)) * 34, Vector2(cos(a + 0.18), sin(a + 0.18)) * 34]), c)
	var hue: = fposmod(_t * 0.15, 1.0)
	draw_colored_polygon(_star(Vector2(0, 1), 26, 11, sin(_t * 1.5) * 0.12), OUT)
	draw_colored_polygon(_star(Vector2(0, 1), 22, 9.5, sin(_t * 1.5) * 0.12), Color.from_hsv(hue, 0.5, 1.0))
	draw_colored_polygon(_star(Vector2(-2, -1), 11, 4.5, sin(_t * 1.5) * 0.12), Color(1, 1, 1, 0.6))
	for i in 3:
		var tw: = 0.5 + 0.5 * sin(_t * 3.0 + i * 2.1)
		var p: Vector2 = [Vector2(-28, -28), Vector2(27, -22), Vector2(22, 28)][i]
		draw_colored_polygon(_star(p, 5.0 * tw + 1.0, 1.5, 0.0), Color(1, 0.95, 0.7, tw))

func _draw_bomb() -> void :
	var c: = Vector2(HW - 13, - HH + 13)
	_badge(c, 14.0, Color(0.27, 0.12, 0.32))

	var rot: = -0.5
	var ax: = Vector2(cos(rot), sin(rot))
	var nr: = Vector2( - ax.y, ax.x)
	var body: = PackedVector2Array([c - ax * 9 - nr * 5, c + ax * 9 - nr * 5, c + ax * 9 + nr * 5, c - ax * 9 + nr * 5])
	draw_colored_polygon(body, Color("e8455f"))
	draw_polyline(body + PackedVector2Array([body[0]]), OUT, 2.0, true)
	draw_line(c - ax * 6 - nr * 5, c - ax * 6 + nr * 5, Color("f6c453"), 2.5, true)
	draw_line(c + ax * 6 - nr * 5, c + ax * 6 + nr * 5, Color("f6c453"), 2.5, true)

	var f0: = c + ax * 9
	var f1: = f0 + Vector2(4, -6)
	draw_line(f0, f1, Color("7a4a0c"), 2.0, true)
	var fl: = 0.6 + 0.4 * sin(_t * 23.0) * sin(_t * 7.0)
	draw_circle(f1, 4.5 * fl + 1.5, Color(1, 0.6, 0.2, 0.7))
	draw_circle(f1, 2.2 * fl + 0.8, Color(1, 0.95, 0.7))
	for i in 3:
		var a: = _t * 9.0 + TAU * i / 3.0
		draw_line(f1, f1 + Vector2(cos(a), sin(a)) * (6.0 * fl + 2.0), Color(1, 0.85, 0.4, 0.8), 1.4, true)
