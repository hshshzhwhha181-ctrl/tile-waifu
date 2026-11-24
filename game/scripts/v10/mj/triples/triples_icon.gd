class_name V10MjTriplesIcon
extends Control

# Монолинейные иконки Троек (UX_RULES §6.4: сетка 48, штрих 2,5, круглые окончания; активная gold300, неактивная
# paper500). Рисуются кодом — без кредитов и без размытия на любом DPI.
#   return3 — дуга-стрелка назад к ячейке; magnet — подкова-магнит; slot — ячейка с плюсом; shuffle — две
#   перекрёстные стрелки; pause — две черты; three — три фишки веером; tap — палец-точка; full — полный лоток

var kind: = "return3"
var color: = Color("F1D9A0")
var stroke: = 2.5


func _init(k: = "return3", c: = Color("F1D9A0")) -> void:
	kind = k
	color = c
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48, 48)


func _draw() -> void:
	var s: = minf(size.x, size.y) / 48.0
	var o: = (size - Vector2(48, 48) * s) * 0.5
	var w: = stroke * s * 1.15
	var P: = func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	match kind:
		"return3":
			# ячейка снизу и дуга-стрелка, возвращающая фишку вверх-влево
			_rr(P.call(26, 24), P.call(40, 40), w)
			var pts: = PackedVector2Array()
			for k in 13:
				var a: = lerpf(PI * 0.05, PI * 1.05, k / 12.0)
				pts.append(P.call(22, 26) + Vector2(cos(a), -sin(a)) * 12.0 * s)
			draw_polyline(pts, color, w, true)
			var tip: Vector2 = pts[pts.size() - 1]
			draw_line(tip, tip + Vector2(-4, -6) * s, color, w, true)
			draw_line(tip, tip + Vector2(6, -3) * s, color, w, true)
			for p in [tip, tip + Vector2(-4, -6) * s, tip + Vector2(6, -3) * s]:
				draw_circle(p, w * 0.5, color)
		"magnet":
			var pts: = PackedVector2Array()
			for k in 17:
				var a: = lerpf(0.0, PI, k / 16.0)
				pts.append(P.call(24, 22) + Vector2(cos(a), sin(a)) * 13.0 * s)
			var arc: = PackedVector2Array([P.call(37, 8)])
			arc.append_array(pts)
			arc.append(P.call(11, 8))
			draw_polyline(arc, color, w, true)
			draw_line(P.call(31, 8), P.call(31, 22), color, w * 0.8, true)
			draw_line(P.call(17, 8), P.call(17, 22), color, w * 0.8, true)
			draw_line(P.call(31, 14), P.call(37, 14), color, w, true)
			draw_line(P.call(11, 14), P.call(17, 14), color, w, true)
		"slot":
			_rr(P.call(10, 10), P.call(38, 38), w)
			draw_line(P.call(24, 17), P.call(24, 31), color, w, true)
			draw_line(P.call(17, 24), P.call(31, 24), color, w, true)
		"shuffle":
			_bez(P.call(8, 14), P.call(24, 14), P.call(24, 34), P.call(40, 34), w)
			_bez(P.call(8, 34), P.call(24, 34), P.call(24, 14), P.call(40, 14), w)
			for t in [P.call(40, 34), P.call(40, 14)]:
				draw_line(t, t + Vector2(-6, -5) * s, color, w, true)
				draw_line(t, t + Vector2(-6, 5) * s, color, w, true)
		"pause":
			draw_line(P.call(18, 13), P.call(18, 35), color, w * 1.2, true)
			draw_line(P.call(30, 13), P.call(30, 35), color, w * 1.2, true)
		"three":
			for k in 3:
				var c: = P.call(14 + k * 10, 26 - absi(k - 1) * -3)
				var r: = Rect2(c - Vector2(7, 10) * s, Vector2(14, 20) * s)
				draw_set_transform(c, (k - 1) * 0.25, Vector2.ONE)
				_rr(r.position - c, r.end - c, w)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"tap":
			_rr(P.call(16, 18), P.call(32, 40), w)
			draw_arc(P.call(24, 10), 6.0 * s, 0, TAU, 24, color, w, true)
			draw_line(P.call(24, 4), P.call(24, 16), color, w * 0.8, true)
		"full":
			_rr(P.call(4, 18), P.call(44, 34), w)
			for k in 6:
				draw_line(P.call(9.5 + k * 5.8, 22), P.call(9.5 + k * 5.8, 30), color, w * 0.9, true)
		"star":
			var pts: = PackedVector2Array()
			for k in 11:
				var a: = -PI / 2 + k * TAU / 10.0
				var r: = 17.0 if k % 2 == 0 else 7.5
				pts.append(P.call(24, 25) + Vector2(cos(a), sin(a)) * r * s)
			draw_colored_polygon(pts, color)


func _rr(a: Vector2, b: Vector2, w: float) -> void:
	var r: = minf(5.0 * w / 2.5, (b - a).x * 0.3)
	var pts: = PackedVector2Array()
	var cs: = [[Vector2(b.x - r, a.y + r), -PI / 2], [Vector2(b.x - r, b.y - r), 0.0], [Vector2(a.x + r, b.y - r), PI / 2], [Vector2(a.x + r, a.y + r), PI]]
	for c in cs:
		for k in 5:
			var an: float = c[1] + k * (PI / 2) / 4.0
			pts.append(c[0] + Vector2(cos(an), sin(an)) * r)
	pts.append(pts[0])
	draw_polyline(pts, color, w, true)


func _bez(a: Vector2, b: Vector2, c: Vector2, d: Vector2, w: float) -> void:
	var pts: = PackedVector2Array()
	for k in 17:
		var t: = k / 16.0
		var u: = 1.0 - t
		pts.append(a * u * u * u + b * 3 * u * u * t + c * 3 * u * t * t + d * t * t * t)
	draw_polyline(pts, color, w, true)
