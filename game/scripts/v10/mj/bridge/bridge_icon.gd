class_name V10MjBridgeIcon
extends Control

# Монолинейные иконки моста кодом (UX_RULES §6.4: сетка 48, штрих 2,5, круглые окончания) и две иконки режимов
# для карточек хаба (предметы, без героинь): «Задача дня» — веер из трёх фишек, средняя поднята над прудом,
# золотая стрелка «сбросить»; «Собери руку» — пирамидка фишек и под ней сложенный ряд с лаковой скобой.
#   kinds: pause back star tap drop wait set full reset share eye school mode_daily mode_hand

const W: = 2.5

var kind: = "pause"
var col: = Color.WHITE


func _init(k: = "pause", c: = Color.WHITE) -> void:
	kind = k
	col = c
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s: = minf(size.x, size.y) / 48.0
	var o: = (size - Vector2(48, 48) * s) * 0.5
	var P: = func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var w: = W * s
	match kind:
		"pause":
			draw_line(P.call(18, 13), P.call(18, 35), col, w * 1.2, true)
			draw_line(P.call(30, 13), P.call(30, 35), col, w * 1.2, true)
		"back":
			draw_polyline(PackedVector2Array([P.call(28, 12), P.call(16, 24), P.call(28, 36)]), col, w * 1.2, true)
		"help":
			draw_arc(P.call(24, 24), 15.0 * s, 0, TAU, 32, col, w, true)
			draw_arc(P.call(24, 20), 4.6 * s, PI, TAU + PI * 0.42, 16, col, w, true)
			draw_line(P.call(24, 24.5), P.call(24, 28), col, w, true)
			draw_circle(P.call(24, 33.5), w * 0.65, col)
		"star":
			var pts: = PackedVector2Array()
			for k in 10:
				var a: = -PI / 2 + k * PI / 5
				var r: = 21.0 if k % 2 == 0 else 9.0
				pts.append(P.call(24 + cos(a) * r, 25 + sin(a) * r))
			draw_colored_polygon(pts, col)
		"tap":
			_tile(P.call(14, 8), 20 * s, w)
			draw_circle(P.call(30, 34), 6 * s, Color(col, 0.0))
			draw_arc(P.call(30, 34), 6 * s, 0, TAU, 24, col, w, true)
			draw_arc(P.call(30, 34), 11 * s, -2.4, -0.7, 16, Color(col, 0.6), w * 0.8, true)
		"drop":
			_tile(P.call(16, 4), 16 * s, w)
			draw_line(P.call(24, 30), P.call(24, 42), col, w, true)
			draw_polyline(PackedVector2Array([P.call(18, 36), P.call(24, 42), P.call(30, 36)]), col, w, true)
		"wait":
			for k in 3:
				var x: = 8.0 + k * 12.0
				draw_rect(Rect2(P.call(x, 30 - k * 8), Vector2(8, 10 + k * 8) * s), Color(col, 0.35 + k * 0.3))
			draw_line(P.call(6, 41), P.call(42, 41), col, w, true)
		"set":
			for k in 3:
				_tile(P.call(4 + k * 14, 10), 13 * s, w * 0.8)
			draw_line(P.call(6, 40), P.call(42, 40), col, w, true)
		"full":
			for k in 4:
				draw_rect(Rect2(P.call(5 + k * 10, 16), Vector2(8, 16) * s), Color(col, 0.0), false, w * 0.7)
				draw_rect(Rect2(P.call(5 + k * 10, 16), Vector2(8, 16) * s), col, false, w * 0.7)
			draw_line(P.call(40, 12), P.call(46, 36), col, w, true)
		"reset":
			# фишка уходит на край: дуга со стрелкой вниз-влево
			_tile(P.call(24, 6), 14 * s, w * 0.9)
			draw_arc(P.call(24, 30), 12 * s, PI * 0.05, PI * 0.95, 20, col, w, true)
			draw_polyline(PackedVector2Array([P.call(7, 26), P.call(12, 33), P.call(18, 27)]), col, w, true)
			draw_line(P.call(6, 43), P.call(42, 43), Color(col, 0.6), w * 0.8, true)
		"share":
			draw_circle(P.call(12, 24), 4.5 * s, col)
			draw_circle(P.call(35, 12), 4.5 * s, col)
			draw_circle(P.call(35, 36), 4.5 * s, col)
			draw_line(P.call(12, 24), P.call(35, 12), col, w, true)
			draw_line(P.call(12, 24), P.call(35, 36), col, w, true)
		"eye":
			var pts2: = PackedVector2Array()
			for k in 25:
				var t: = float(k) / 24.0
				pts2.append(P.call(6 + t * 36, 24 - sin(t * PI) * 11))
			for k in 25:
				var t2: = float(k) / 24.0
				pts2.append(P.call(42 - t2 * 36, 24 + sin(t2 * PI) * 11))
			draw_polyline(pts2, col, w, true)
			draw_circle(P.call(24, 24), 5 * s, col)
		"school":
			draw_colored_polygon(PackedVector2Array([P.call(4, 18), P.call(24, 9), P.call(44, 18), P.call(24, 27)]), col)
			draw_polyline(PackedVector2Array([P.call(12, 22), P.call(12, 32), P.call(24, 37), P.call(36, 32), P.call(36, 22)]), col, w, true)
		"mode_daily":
			_mode_daily()
		"mode_hand":
			_mode_hand()


func _tile(p: Vector2, wpx: float, lw: float) -> void:
	var h: = wpx * 1.38
	var r: = Rect2(p, Vector2(wpx, h))
	draw_rect(r, col, false, lw)
	draw_line(r.position + Vector2(0, h * 0.82), r.position + Vector2(wpx, h * 0.82), Color(col, 0.5), lw * 0.7, true)


# ── иконки режимов (карточка хаба 200×268; сюда — квадрат, хаб кладёт его на свою фишку-форму) ──────────────

func _bg_card() -> Rect2:
	var r: = Rect2(Vector2.ZERO, size)
	var sb: = StyleBoxFlat.new()
	sb.bg_color = V10MjBridgeLook.TOK.night800
	sb.set_corner_radius_all(int(size.x * 0.06))
	sb.border_color = Color(V10MjBridgeLook.TOK.gold700, 0.35)
	sb.set_border_width_all(maxi(1, int(size.x / 256.0)))
	draw_style_box(sb, r)
	# лампа сверху
	for k in 8:
		draw_circle(Vector2(size.x * 0.5, size.y * 0.05), size.x * (0.62 - k * 0.05), Color(1, 0.9, 0.75, 0.025))
	return r


func _riichi(k: int, c: Vector2, w: float, rot: float, lift: = 0.0, glow: = false) -> void:
	var t: = V10MjBridgeTiles.tex(k)
	var h: = w * 200.0 / 144.0
	draw_set_transform(c + Vector2(0, -lift), rot, Vector2.ONE)
	draw_rect(Rect2(Vector2(-w * 0.5 + w * 0.05, -h * 0.5 + h * 0.06), Vector2(w, h)), Color(0, 0, 0, 0.35))
	if glow:
		draw_rect(Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)).grow(w * 0.06), Color(V10MjBridgeLook.TOK.gold300, 0.55), false, w * 0.035)
	if t:
		draw_texture_rect(t, Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _mode_daily() -> void:
	_bg_card()
	var S: = size.x
	var w: = S * 0.27
	# пруд: тёмный овал внизу
	draw_set_transform(Vector2(S * 0.5, S * 0.82), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, S * 0.3, Color(V10MjBridgeLook.TOK.night900, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_riichi(3, Vector2(S * 0.27, S * 0.47), w, -0.28)
	_riichi(16, Vector2(S * 0.73, S * 0.47), w, 0.28)
	_riichi(8, Vector2(S * 0.5, S * 0.42), w, 0.0, S * 0.07, true)
	var g: = V10MjBridgeLook.TOK.gold300
	var lw: = maxf(2.0, S * 0.018)
	draw_line(Vector2(S * 0.5, S * 0.66), Vector2(S * 0.5, S * 0.8), g, lw, true)
	draw_polyline(PackedVector2Array([Vector2(S * 0.44, S * 0.75), Vector2(S * 0.5, S * 0.81), Vector2(S * 0.56, S * 0.75)]), g, lw, true)


func _mode_hand() -> void:
	_bg_card()
	var S: = size.x
	var w: = S * 0.17
	var h: = w * 200.0 / 144.0
	# пирамидка 3 + 2 сверху
	for k in 3:
		_riichi([31, 27, 33][k], Vector2(S * 0.3 + k * w * 1.02, S * 0.34), w, 0.0)
	for k in 2:
		_riichi([29, 32][k], Vector2(S * 0.3 + w * 0.51 + k * w * 1.02, S * 0.34 - h * 0.18), w, 0.0, h * 0.06)
	# сложенный ряд 4-5-6 пин и лаковая скоба
	for k in 3:
		_riichi(12 + k, Vector2(S * 0.32 + k * w * 0.98, S * 0.72), w, 0.0)
	var a: Color = V10MjBridgeLook.accent("hana")[0]
	var lw: = maxf(2.0, S * 0.016)
	var y: = S * 0.72 + h * 0.58
	draw_line(Vector2(S * 0.32 - w * 0.5, y), Vector2(S * 0.32 + w * 2.46, y), a, lw, true)
	draw_line(Vector2(S * 0.32 - w * 0.5, y), Vector2(S * 0.32 - w * 0.5, y - h * 0.18), a, lw, true)
	draw_line(Vector2(S * 0.32 + w * 2.46, y), Vector2(S * 0.32 + w * 2.46, y - h * 0.18), a, lw, true)
