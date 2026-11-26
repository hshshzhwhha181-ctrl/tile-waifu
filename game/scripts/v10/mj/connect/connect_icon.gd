class_name V10MjConnectIcon
extends Control

# Монолинейные иконки Связей (UX_RULES §6.4: сетка 48, штрих 2,5, круглые окончания).

var kind: = "pause"
var col: = V10DS.GOLD_300


func _init(k: = "pause", c: = V10DS.GOLD_300) -> void:
	kind = k
	col = c
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48, 48)
	size = Vector2(48, 48)


func set_col(c: Color) -> void:
	col = c
	queue_redraw()


func _draw() -> void:
	var s: = size.x / 48.0
	var w: = maxf(2.0, 2.5 * s)
	var P: = func(x: float, y: float) -> Vector2: return Vector2(x, y) * s
	match kind:
		"pause":
			draw_line(P.call(18, 13), P.call(18, 35), col, w * 1.2, true)
			draw_line(P.call(30, 13), P.call(30, 35), col, w * 1.2, true)
		"help":
			draw_arc(P.call(24, 24), 15.0 * s, 0, TAU, 32, col, w, true)
			draw_arc(P.call(24, 20), 4.6 * s, PI, TAU + PI * 0.42, 16, col, w, true)
			draw_line(P.call(24, 24.5), P.call(24, 28), col, w, true)
			draw_circle(P.call(24, 33.5), w * 0.65, col)
		"back":
			draw_polyline(PackedVector2Array([P.call(29, 12), P.call(17, 24), P.call(29, 36)]), col, w, true)
		"hint":
			draw_arc(P.call(24, 20), 9.2 * s, PI * 0.78, PI * 2.22, 24, col, w, true)
			draw_line(P.call(18, 27), P.call(20, 32), col, w, true)
			draw_line(P.call(30, 27), P.call(28, 32), col, w, true)
			draw_line(P.call(20, 32), P.call(28, 32), col, w, true)
			draw_line(P.call(21, 36), P.call(27, 36), col, w, true)
		"undo":
			draw_arc(P.call(25, 25), 11.0 * s, -PI * 0.92, PI * 0.55, 24, col, w, true)
			var tip: Vector2 = (P.call(25, 25) as Vector2) + Vector2(cos(-PI * 0.92), sin(-PI * 0.92)) * 11.0 * s
			draw_line(tip, tip + Vector2(0, -7.5 * s), col, w, true)
			draw_line(tip, tip + Vector2(7.5 * s, 0), col, w, true)
		"shuffle":
			draw_polyline(PackedVector2Array([P.call(10, 17), P.call(21, 17), P.call(27, 31), P.call(38, 31)]), col, w, true)
			draw_polyline(PackedVector2Array([P.call(10, 31), P.call(21, 31), P.call(27, 17), P.call(38, 17)]), col, w, true)
			draw_polyline(PackedVector2Array([P.call(34, 13), P.call(38, 17), P.call(34, 21)]), col, w, true)
			draw_polyline(PackedVector2Array([P.call(34, 27), P.call(38, 31), P.call(34, 35)]), col, w, true)
		"tap":
			draw_rect(Rect2(P.call(11, 9), Vector2(16, 21) * s), col, false, w)
			draw_arc(P.call(30, 30), 5.5 * s, PI, TAU, 14, col, w, true)
			draw_line(P.call(24.5, 30), P.call(24.5, 39), col, w, true)
			draw_line(P.call(35.5, 30), P.call(35.5, 39), col, w, true)
		"thread":
			draw_circle(P.call(12, 34), 3.6 * s, col)
			draw_circle(P.call(36, 14), 3.6 * s, col)
			draw_polyline(PackedVector2Array([P.call(12, 34), P.call(12, 14), P.call(36, 14)]), col, w, true)
		"rain":
			for x in [15, 24, 33]:
				draw_line(P.call(x, 11), P.call(x, 33), col, w, true)
				draw_polyline(PackedVector2Array([P.call(x - 3.5, 29), P.call(x, 34), P.call(x + 3.5, 29)]), col, w, true)
		"shift":
			draw_line(P.call(9, 24), P.call(21, 24), col, w, true)
			draw_polyline(PackedVector2Array([P.call(17, 19), P.call(22, 24), P.call(17, 29)]), col, w, true)
			draw_line(P.call(39, 24), P.call(27, 24), col, w, true)
			draw_polyline(PackedVector2Array([P.call(31, 19), P.call(26, 24), P.call(31, 29)]), col, w, true)
		"star":
			var pts: = PackedVector2Array()
			for i in 10:
				var a: = -PI * 0.5 + PI * i / 5.0
				var r: = (16.0 if i % 2 == 0 else 7.0) * s
				pts.append(P.call(24, 24) + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, col)
