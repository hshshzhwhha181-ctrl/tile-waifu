class_name V10MjCubeIcon
extends Control

# Монолинейные иконки Куба (UX_RULES §6.4: сетка 48, штрих 2,5, круглые окончания; активная gold300, неактивная
# paper500). Рисуются кодом — без кредитов и чёткие на любом DPI.
#   hint — лампа-подсказка; undo — стрелка назад; shuffle — две перекрёстные стрелки; pause — две черты;
#   star — звезда (только звёзды уровней); rotate — кубик и дуга-стрелка вокруг (вращай свайпом); tap — палец;
#   pair — два одинаковых кубика; cube — изометрический кубик 3×3 (знак режима); relic — искра в сердцевине

var kind: = "hint"
var color: = V10DS.GOLD_300
var stroke: = 2.5


func _init(k: = "hint", c: = V10DS.GOLD_300) -> void:
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
		"hint":
			# bulb: circle top, neck, two base lines, three rays
			var pts: = PackedVector2Array()
			for k in 25:
				var a: = lerpf(PI * 0.78, PI * 2.22, k / 24.0)
				pts.append(P.call(24, 20) + Vector2(cos(a), sin(a)) * 10.5 * s)
			draw_polyline(pts, color, w, true)
			draw_line(P.call(19, 29), P.call(19, 33), color, w, true)
			draw_line(P.call(29, 29), P.call(29, 33), color, w, true)
			draw_line(P.call(18.5, 34), P.call(29.5, 34), color, w, true)
			draw_line(P.call(20.5, 39), P.call(27.5, 39), color, w, true)
			for r in [[24, 4, 24, 1], [9, 10, 7, 8], [39, 10, 41, 8]]:
				draw_line(P.call(r[0], r[1]), P.call(r[2], r[3]), color, w, true)
		"undo":
			var pts: = PackedVector2Array()
			for k in 17:
				var a: = lerpf(PI * 1.05, PI * 2.25, k / 16.0)
				pts.append(P.call(25, 27) + Vector2(cos(a), -sin(a)) * 12.0 * s)
			draw_polyline(pts, color, w, true)
			var tip: Vector2 = pts[0]
			draw_line(tip, tip + Vector2(-1, -8) * s, color, w, true)
			draw_line(tip, tip + Vector2(7, -3) * s, color, w, true)
			var end: Vector2 = pts[pts.size() - 1]
			draw_line(end, end + Vector2(-6, 8) * s, color, w, true)
		"shuffle":
			_bez(P.call(8, 14), P.call(24, 14), P.call(24, 34), P.call(40, 34), w)
			_bez(P.call(8, 34), P.call(24, 34), P.call(24, 14), P.call(40, 14), w)
			for t in [P.call(40, 34), P.call(40, 14)]:
				draw_line(t, t + Vector2(-6, -5) * s, color, w, true)
				draw_line(t, t + Vector2(-6, 5) * s, color, w, true)
		"pause":
			draw_line(P.call(18, 13), P.call(18, 35), color, w * 1.2, true)
			draw_line(P.call(30, 13), P.call(30, 35), color, w * 1.2, true)
		"help":
			draw_arc(P.call(24, 24), 15.0 * s, 0, TAU, 32, color, w, true)
			draw_arc(P.call(24, 20), 4.6 * s, PI, TAU + PI * 0.42, 16, color, w, true)
			draw_line(P.call(24, 24.5), P.call(24, 28), color, w, true)
			draw_circle(P.call(24, 33.5), w * 0.65, color)
		"back":
			draw_polyline(PackedVector2Array([P.call(29, 12), P.call(17, 24), P.call(29, 36)]), color, w, true)
		"star":
			var pts: = PackedVector2Array()
			for k in 11:
				var a: = -PI / 2 + k * TAU / 10.0
				var r: = 17.0 if k % 2 == 0 else 7.5
				pts.append(P.call(24, 25) + Vector2(cos(a), sin(a)) * r * s)
			draw_colored_polygon(pts, color)
		"rotate":
			_iso(P.call(24, 25), 9.0 * s, w, 1)
			var pts: = PackedVector2Array()
			for k in 21:
				var a: = lerpf(PI * 0.15, PI * 1.25, k / 20.0)
				pts.append(P.call(24, 25) + Vector2(cos(a) * 19.0, sin(a) * 9.0) * s)
			draw_polyline(pts, color, w * 0.9, true)
			var tip: Vector2 = pts[pts.size() - 1]
			draw_line(tip, tip + Vector2(1, -7) * s, color, w * 0.9, true)
			draw_line(tip, tip + Vector2(7, 1) * s, color, w * 0.9, true)
		"tap":
			_iso(P.call(17, 22), 8.0 * s, w, 1)
			draw_arc(P.call(33, 30), 4.0 * s, 0, TAU, 20, color, w, true)
			draw_arc(P.call(33, 30), 9.0 * s, -2.4, -0.7, 12, color, w * 0.8, true)
		"pair":
			_iso(P.call(15, 26), 8.5 * s, w, 1)
			_iso(P.call(33, 26), 8.5 * s, w, 1)
			draw_line(P.call(22, 12), P.call(26, 8), color, w * 0.8, true)
			draw_line(P.call(26, 12), P.call(22, 8), color, w * 0.8, true)
		"cube":
			_iso(P.call(24, 25), 17.0 * s, w, 3)
		"relic":
			_iso(P.call(24, 25), 15.0 * s, w * 0.8, 1)
			var pts: = PackedVector2Array()
			for k in 9:
				var a: = -PI / 2 + k * TAU / 8.0
				var r: = 7.0 if k % 2 == 0 else 2.4
				pts.append(P.call(24, 25) + Vector2(cos(a), sin(a)) * r * s)
			draw_colored_polygon(pts, color)


# isometric cube of half-width r centred at c; n×n grid lines on each face
func _iso(c: Vector2, r: float, w: float, n: int) -> void:
	var h: = r * 0.5
	var top: = c + Vector2(0, -r)
	var lt: = c + Vector2(-r * 0.87, -h)
	var rt: = c + Vector2(r * 0.87, -h)
	var lb: = c + Vector2(-r * 0.87, h)
	var rb: = c + Vector2(r * 0.87, h)
	var bot: = c + Vector2(0, r)
	draw_polyline(PackedVector2Array([top, rt, rb, bot, lb, lt, top]), color, w, true)
	draw_line(lt, c, color, w, true)
	draw_line(rt, c, color, w, true)
	draw_line(c, bot, color, w, true)
	if n > 1:
		var w2: = w * 0.6
		for k in range(1, n):
			var t: = float(k) / n
			# top face
			draw_line(lt.lerp(top, t), c.lerp(rt, t), color, w2, true)
			draw_line(lt.lerp(c, t), top.lerp(rt, t), color, w2, true)
			# left face
			draw_line(lt.lerp(lb, t), c.lerp(bot, t), color, w2, true)
			draw_line(lt.lerp(c, t), lb.lerp(bot, t), color, w2, true)
			# right face
			draw_line(c.lerp(bot, t), rt.lerp(rb, t), color, w2, true)
			draw_line(c.lerp(rt, t), bot.lerp(rb, t), color, w2, true)


func _bez(a: Vector2, b: Vector2, c: Vector2, d: Vector2, w: float) -> void:
	var pts: = PackedVector2Array()
	for k in 17:
		var t: = k / 16.0
		var u: = 1.0 - t
		pts.append(a * u * u * u + b * 3 * u * u * t + c * 3 * u * t * t + d * t * t * t)
	draw_polyline(pts, color, w, true)
