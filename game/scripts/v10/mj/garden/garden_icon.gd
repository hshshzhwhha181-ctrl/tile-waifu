class_name V10MjGardenIcon
extends Control

# Монолинейные иконки Сада кодом (UX_RULES §6.4: сетка 48, штрих 2,5, круглые окончания):
#   pause · hint (лампа-подсказка) · tap · pair · spill (лоток переливается) · moon (ночной стол) · sun (день) ·
#   rain · stream · bamboo (звук фона)

var kind: = "pause"
var col: = Color("F1D9A0")


func _init(k: = "pause", c: = Color("F1D9A0")) -> void:
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
	var w: = 2.5 * s
	var P: = func(x: float, y: float) -> Vector2: return Vector2(x, y) * s
	match kind:
		"pause":
			draw_line(P.call(18, 13), P.call(18, 35), col, w * 1.2, true)
			draw_line(P.call(30, 13), P.call(30, 35), col, w * 1.2, true)
		"hint":
			# лампа: колба, цоколь, лучики
			draw_arc(P.call(24, 20), 9.5 * s, PI * 0.78, PI * 2.22, 28, col, w, true)
			draw_line(P.call(17.5, 26.5), P.call(20, 31), col, w, true)
			draw_line(P.call(30.5, 26.5), P.call(28, 31), col, w, true)
			draw_line(P.call(20, 31), P.call(28, 31), col, w, true)
			draw_line(P.call(20.5, 35), P.call(27.5, 35), col, w, true)
			draw_line(P.call(22, 38.5), P.call(26, 38.5), col, w, true)
			for a in [-0.75, -0.25, 0.25, 0.75]:
				var d: = Vector2(sin(a * PI * 0.5), -cos(a * PI * 0.5))
				draw_line(P.call(24, 20) + d * 13.5 * s, P.call(24, 20) + d * 17.0 * s, col, w * 0.8, true)
		"tap":
			_tile(P.call(13, 10), Vector2(16, 21) * s, w)
			draw_arc(P.call(31, 31), 3.0 * s, 0, TAU, 16, col, w, true)
			draw_arc(P.call(31, 31), 7.5 * s, -PI * 0.9, -PI * 0.1, 16, col, w * 0.8, true)
		"pair":
			_tile(P.call(8, 14), Vector2(14, 19) * s, w)
			_tile(P.call(26, 14), Vector2(14, 19) * s, w)
			draw_arc(P.call(24, 15), 9.0 * s, -PI * 0.85, -PI * 0.15, 16, col, w, true)
		"spill":
			# лоток-чаша и капли через край
			draw_polyline(PackedVector2Array([P.call(9, 22), P.call(13, 35), P.call(35, 35), P.call(39, 22)]), col, w, true)
			draw_line(P.call(7, 22), P.call(41, 22), col, w, true)
			for d in [[16, 14], [24, 10], [32, 14]]:
				_drop(P.call(d[0], d[1]), 2.8 * s, w)
		"moon":
			_moon(P.call(24, 24), 13.0 * s, w)
		"sun":
			draw_arc(P.call(24, 24), 7.0 * s, 0, TAU, 24, col, w, true)
			for k in 8:
				var a: = TAU * k / 8.0
				var d: = Vector2(cos(a), sin(a))
				draw_line(P.call(24, 24) + d * 11.0 * s, P.call(24, 24) + d * 15.0 * s, col, w, true)
		"rain":
			for d in [[14, 14], [26, 10], [34, 20], [20, 26], [30, 32]]:
				draw_line(P.call(d[0], d[1]), P.call(d[0] - 3, d[1] + 8), col, w, true)
		"stream":
			for y in [16, 24, 32]:
				var pts: = PackedVector2Array()
				for i in 13:
					var x: = 8.0 + i * 2.67
					pts.append(P.call(x, y + sin(i * 0.9) * 2.4))
				draw_polyline(pts, col, w, true)
		"bamboo":
			draw_line(P.call(20, 8), P.call(20, 40), col, w, true)
			for y in [16, 26, 36]:
				draw_line(P.call(17, y), P.call(23, y), col, w, true)
			draw_polyline(PackedVector2Array([P.call(21, 14), P.call(29, 9), P.call(37, 11)]), col, w, true)
			draw_polyline(PackedVector2Array([P.call(21, 24), P.call(31, 22), P.call(38, 26)]), col, w, true)


func _tile(p: Vector2, sz: Vector2, w: float) -> void:
	var r: = 3.0 * size.x / 48.0
	var pts: = PackedVector2Array()
	var c: = [p + Vector2(r, r), p + Vector2(sz.x - r, r), p + Vector2(sz.x - r, sz.y - r), p + Vector2(r, sz.y - r)]
	var a0: = [PI, PI * 1.5, 0.0, PI * 0.5]
	for k in 4:
		for i in 5:
			var a: float = a0[k] + PI * 0.5 * i / 4.0
			pts.append(c[k] + Vector2(cos(a), sin(a)) * r)
	pts.append(pts[0])
	draw_polyline(pts, col, w, true)


func _drop(p: Vector2, r: float, w: float) -> void:
	draw_arc(p + Vector2(0, r), r, -PI * 0.1, PI * 1.1, 12, col, w, true)
	draw_line(p + Vector2(-r * 0.95, r * 0.8), p + Vector2(0, -r * 1.2), col, w, true)
	draw_line(p + Vector2(r * 0.95, r * 0.8), p + Vector2(0, -r * 1.2), col, w, true)


func _moon(c: Vector2, r: float, w: float) -> void:
	# серп: часть внешнего круга вне внутреннего + часть внутреннего круга внутри внешнего
	var c2: = c + Vector2(r * 0.5, -r * 0.22)
	var r2: = r * 0.82
	var outer: = PackedVector2Array()
	var inner: = PackedVector2Array()
	var n: = 64
	var a0: = (c2 - c).angle()
	for i in n + 1:
		var a: = a0 + TAU * i / n
		var p: = c + Vector2(cos(a), sin(a)) * r
		if p.distance_to(c2) >= r2:
			outer.append(p)
	for i in n + 1:
		var a2: = a0 + TAU * i / n
		var q: = c2 + Vector2(cos(a2), sin(a2)) * r2
		if q.distance_to(c) <= r:
			inner.append(q)
	if outer.size() > 1:
		draw_polyline(outer, col, w, true)
	if inner.size() > 1:
		draw_polyline(inner, col, w, true)
