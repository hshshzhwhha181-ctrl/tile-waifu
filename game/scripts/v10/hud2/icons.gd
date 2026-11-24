class_name V10Icons
extends RefCounted

# V10Icons — monoline action icons of HUD v2 (docs/HUD_V2.md §4), drawn as vectors so the stroke is the same
# 2.5 px at every DPI: grid 48, live area 40, round ends and joins, no fill, paper.500 / active gold.300.
#
#   V10Icons.draw(ci, name, center, size, color)   -- call from any _draw()
#   V10Icons.NAMES                                  -- the v2 set
#   V10Icons.icon(name, size := 48, color := paper.500) -> V10Icons.View (a Control that draws one icon)
#
# Painted items (crystal, Moonstone, ticket, candle, lantern, gift, level star) are art, not icons; the only
# filled shape here is draw_star() for the level stars of the victory beat until their painted art lands.

const NAMES: = ["pause", "undo", "hint", "shuffle", "sound", "settings", "help", "close", "back", "more", "info",
		"phone", "avatar_ring", "tab_tea", "tab_heroines", "tab_tables", "tab_wishes", "tab_shop", "arrow_r", "heart",
		"lock_silhouette"]
const STROKE: = 2.5


class View:
	extends Control
	var icon_name: = "pause"
	var px: = 48
	var color: = V10DS.PAPER_500

	func _init(n: = "pause", size_px: = 48, c: = V10DS.PAPER_500) -> void:
		icon_name = n
		px = size_px
		color = c
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(px, px)
		size = Vector2(px, px)

	func set_color(c: Color) -> void:
		color = c
		queue_redraw()

	func _draw() -> void:
		V10Icons.draw(self, icon_name, size * 0.5, px, color)


static func icon(n: String, size_px: = 48, c: = V10DS.PAPER_500) -> View:
	return View.new(n, size_px, c)


static func _p(c: Vector2, s: float, x: float, y: float) -> Vector2:
	return c + Vector2(x - 24.0, y - 24.0) * s


static func _line(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	ci.draw_polyline(pts, col, w, true)
	# round caps
	ci.draw_circle(pts[0], w * 0.5, col, true, -1.0, true)
	ci.draw_circle(pts[pts.size() - 1], w * 0.5, col, true, -1.0, true)


static func _seg(ci: CanvasItem, c: Vector2, s: float, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	_line(ci, PackedVector2Array([_p(c, s, a.x, a.y), _p(c, s, b.x, b.y)]), col, w)


static func _poly(ci: CanvasItem, c: Vector2, s: float, pts: Array, col: Color, w: float, closed: = false) -> void:
	var out: = PackedVector2Array()
	for q in pts:
		out.append(_p(c, s, q.x, q.y))
	if closed:
		out.append(out[0])
		ci.draw_polyline(out, col, w, true)
	else:
		_line(ci, out, col, w)


static func _arc(ci: CanvasItem, c: Vector2, s: float, ctr: Vector2, r: float, a0: float, a1: float, col: Color, w: float, caps: = true) -> void:
	var cc: = _p(c, s, ctr.x, ctr.y)
	ci.draw_arc(cc, r * s, a0, a1, 40, col, w, true)
	if caps:
		ci.draw_circle(cc + Vector2(cos(a0), sin(a0)) * r * s, w * 0.5, col, true, -1.0, true)
		ci.draw_circle(cc + Vector2(cos(a1), sin(a1)) * r * s, w * 0.5, col, true, -1.0, true)


static func _bez(a: Vector2, b: Vector2, c1: Vector2, c2: Vector2, n: = 16) -> Array:
	var out: = []
	for i in n + 1:
		var t: = float(i) / n
		var u: = 1.0 - t
		out.append(a * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + b * t * t * t)
	return out


static func draw(ci: CanvasItem, n: String, c: Vector2, size_px: float, col: Color, stroke: = -1.0) -> void:
	var s: = size_px / 48.0
	var w: = stroke if stroke > 0.0 else (STROKE if size_px >= 28 else 2.0)
	match n:
		"pause":
			_seg(ci, c, s, Vector2(18, 13), Vector2(18, 35), col, w)
			_seg(ci, c, s, Vector2(30, 13), Vector2(30, 35), col, w)
		"undo":
			_poly(ci, c, s, [Vector2(18, 11), Vector2(11, 18), Vector2(18, 25)], col, w)
			_seg(ci, c, s, Vector2(11, 18), Vector2(27, 18), col, w)
			_arc(ci, c, s, Vector2(27, 27.5), 9.5, -PI * 0.5, PI * 0.5, col, w, false)
			_seg(ci, c, s, Vector2(27, 37), Vector2(17, 37), col, w)
		"hint":
			_arc(ci, c, s, Vector2(24, 19), 11.0, PI * 0.75, PI * 2.25, col, w, false)
			_poly(ci, c, s, [Vector2(16.2, 26.8), Vector2(19, 31), Vector2(29, 31), Vector2(31.8, 26.8)], col, w)
			_seg(ci, c, s, Vector2(20, 35), Vector2(28, 35), col, w)
			_seg(ci, c, s, Vector2(21.5, 39), Vector2(26.5, 39), col, w)
		"shuffle":
			_poly(ci, c, s, _bez(Vector2(9, 16), Vector2(37, 32), Vector2(24, 16), Vector2(22, 32)), col, w)
			_poly(ci, c, s, _bez(Vector2(9, 32), Vector2(37, 16), Vector2(24, 32), Vector2(22, 16)), col, w)
			_poly(ci, c, s, [Vector2(32, 11), Vector2(37, 16), Vector2(32, 21)], col, w)
			_poly(ci, c, s, [Vector2(32, 27), Vector2(37, 32), Vector2(32, 37)], col, w)
		"sound":
			_poly(ci, c, s, [Vector2(9, 20), Vector2(15, 20), Vector2(23, 13), Vector2(23, 35), Vector2(15, 28), Vector2(9, 28)], col, w, true)
			_arc(ci, c, s, Vector2(23, 24), 7.0, -0.8, 0.8, col, w)
			_arc(ci, c, s, Vector2(23, 24), 13.0, -0.85, 0.85, col, w)
		"settings":
			ci.draw_arc(_p(c, s, 24, 24), 5.5 * s, 0, TAU, 32, col, w, true)
			ci.draw_arc(_p(c, s, 24, 24), 12.5 * s, 0, TAU, 48, col, w, true)
			for i in 8:
				var a: = TAU * i / 8.0
				_seg(ci, c, s, Vector2(24, 24) + Vector2(cos(a), sin(a)) * 13.5, Vector2(24, 24) + Vector2(cos(a), sin(a)) * 17.5, col, w)
		"help":
			ci.draw_arc(_p(c, s, 24, 24), 17.0 * s, 0, TAU, 48, col, w, true)
			_arc(ci, c, s, Vector2(24, 19.5), 5.5, PI, PI * 2.35, col, w)
			_seg(ci, c, s, Vector2(24, 26.5), Vector2(24, 28.5), col, w)
			ci.draw_circle(_p(c, s, 24, 34), w * 0.7, col, true, -1.0, true)
		"close":
			_seg(ci, c, s, Vector2(14, 14), Vector2(34, 34), col, w)
			_seg(ci, c, s, Vector2(34, 14), Vector2(14, 34), col, w)
		"back":
			_poly(ci, c, s, [Vector2(29, 11), Vector2(16, 24), Vector2(29, 37)], col, w)
		"arrow_r":
			_seg(ci, c, s, Vector2(11, 24), Vector2(35, 24), col, w)
			_poly(ci, c, s, [Vector2(27, 16), Vector2(35, 24), Vector2(27, 32)], col, w)
		"more":
			for x in [13.0, 24.0, 35.0]:
				ci.draw_circle(_p(c, s, x, 24), 2.6 * s, col, true, -1.0, true)
		"info":
			ci.draw_arc(_p(c, s, 24, 24), 17.0 * s, 0, TAU, 48, col, w, true)
			ci.draw_circle(_p(c, s, 24, 16), w * 0.7, col, true, -1.0, true)
			_seg(ci, c, s, Vector2(24, 22), Vector2(24, 33), col, w)
		"phone":
			ci.draw_rect(Rect2(_p(c, s, 15, 7), Vector2(18, 34) * s), col, false, w, true)
			_seg(ci, c, s, Vector2(21, 35), Vector2(27, 35), col, w)
		"avatar_ring":
			ci.draw_arc(_p(c, s, 24, 24), 19.0 * s, 0, TAU, 56, col, w, true)
			ci.draw_arc(_p(c, s, 24, 19), 6.5 * s, 0, TAU, 32, col, w, true)
			_arc(ci, c, s, Vector2(24, 38), 11.0, PI * 1.15, PI * 1.85, col, w)
		"tab_tea":
			_seg(ci, c, s, Vector2(9, 19), Vector2(39, 19), col, w)
			_arc(ci, c, s, Vector2(24, 19), 15.0, 0.0, PI, col, w, false)
			_seg(ci, c, s, Vector2(15, 39), Vector2(33, 39), col, w)
			_poly(ci, c, s, _bez(Vector2(20, 13), Vector2(21, 6), Vector2(17, 11), Vector2(24, 9), 8), col, w)
			_poly(ci, c, s, _bez(Vector2(27, 13), Vector2(28, 6), Vector2(24, 11), Vector2(31, 9), 8), col, w)
		"tab_heroines":
			_arc(ci, c, s, Vector2(24, 38), 24.0, PI * 1.17, PI * 1.83, col, w)
			_seg(ci, c, s, Vector2(24, 38), Vector2(24, 38) + Vector2(cos(PI * 1.17), sin(PI * 1.17)) * 24.0, col, w)
			_seg(ci, c, s, Vector2(24, 38), Vector2(24, 38) + Vector2(cos(PI * 1.83), sin(PI * 1.83)) * 24.0, col, w)
			_seg(ci, c, s, Vector2(24, 38), Vector2(24, 14), col, w)
			_arc(ci, c, s, Vector2(24, 38), 9.0, PI * 1.17, PI * 1.83, col, w, false)
		"tab_tables":
			ci.draw_rect(Rect2(_p(c, s, 14, 8), Vector2(20, 30) * s), col, false, w, true)
			_seg(ci, c, s, Vector2(14, 41), Vector2(34, 41), col, w)
			ci.draw_arc(_p(c, s, 24, 23), 5.0 * s, 0, TAU, 32, col, w, true)
		"tab_wishes":
			_seg(ci, c, s, Vector2(19, 9), Vector2(29, 9), col, w)
			_poly(ci, c, s, [Vector2(19, 12), Vector2(13, 18), Vector2(13, 31), Vector2(19, 37), Vector2(29, 37), Vector2(35, 31), Vector2(35, 18), Vector2(29, 12)], col, w, true)
			_seg(ci, c, s, Vector2(24, 15), Vector2(24, 34), col, w * 0.8)
			_seg(ci, c, s, Vector2(24, 37), Vector2(24, 43), col, w)
		"tab_shop":
			_poly(ci, c, s, [Vector2(11, 18), Vector2(37, 18), Vector2(35, 40), Vector2(13, 40)], col, w, true)
			_arc(ci, c, s, Vector2(24, 18), 7.0, PI, TAU, col, w, false)
		"heart":
			var pts: = []
			for i in 33:
				var t: = TAU * i / 32.0
				var x: = 16.0 * pow(sin(t), 3)
				var y: = -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				pts.append(Vector2(24 + x * 0.95, 25 + y * 0.95))
			_poly(ci, c, s, pts, col, w, true)
		"lock_silhouette":
			ci.draw_rect(Rect2(_p(c, s, 13, 22), Vector2(22, 18) * s), col, false, w, true)
			_arc(ci, c, s, Vector2(24, 22), 7.0, PI, TAU, col, w, false)
		_:
			ci.draw_arc(c, 12.0 * s, 0, TAU, 32, col, w, true)


static func draw_star(ci: CanvasItem, c: Vector2, r: float, lit: bool) -> void:
	# level star (victory beat 1): filled, light from top-left, one spark; unlit = paper.700 outline
	var pts: = PackedVector2Array()
	for i in 10:
		var a: = -PI * 0.5 + PI * i / 5.0
		var rr: = r if i % 2 == 0 else r * 0.46
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	if not lit:
		var cl: = pts.duplicate()
		cl.append(pts[0])
		ci.draw_polyline(cl, V10DS.PAPER_700, 2.0, true)
		return
	var cols: = PackedColorArray()
	for p in pts:
		var k: = clampf(((p - c).dot(Vector2(-0.6, -0.8)) / r + 1.0) * 0.5, 0.0, 1.0)
		cols.append(V10DS.GOLD_700.lerp(V10DS.GOLD_300, k))
	ci.draw_polygon(pts, cols)
	var cl2: = pts.duplicate()
	cl2.append(pts[0])
	ci.draw_polyline(cl2, Color(V10DS.GOLD_300, 0.6), 1.0, true)
	ci.draw_circle(c + Vector2(-r * 0.22, -r * 0.3), r * 0.08, Color(V10DS.PAPER_100, 0.9), true, -1.0, true)
