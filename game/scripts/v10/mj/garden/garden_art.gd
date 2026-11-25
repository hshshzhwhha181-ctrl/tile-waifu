class_name V10MjGardenArt
extends Control

# Иконка режима «Сад» кодом (без героини — символ, MODES §7.1 / задача дорожки): ночное лаковое небо, серп луны,
# косой дождь, две костяные фишки-пара падают в чайную чашку, вода в ней переливается через край каплями.
# Рисуется в любом размере; запекается в res://assets/v10/mj/garden/mode_icon.png (демо: --bake=1, под xvfb).

const T: = V10MjGardenLook.TOK

var night: = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s: = minf(size.x, size.y) / 512.0
	var o: = (size - Vector2(512, 512) * s) * 0.5
	var P: = func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	# фон: скруглённый квадрат, лаковая ночь (сверху индиго, снизу ночь 900)
	var top: = Color("2a2350") if night else Color("3b3f6a")
	var bot: = T.night900
	_round_rect(Rect2(P.call(0, 0), Vector2(512, 512) * s), 84.0 * s, top, bot)
	# дождь
	var rng: = RandomNumberGenerator.new()
	rng.seed = 77
	for k in 26:
		var x: = rng.randf_range(20, 500)
		var y: = rng.randf_range(20, 330)
		var l: = rng.randf_range(26, 52)
		draw_line(P.call(x, y), P.call(x - l * 0.28, y + l), Color(0.78, 0.82, 0.95, rng.randf_range(0.08, 0.2)), 2.0 * s, true)
	# луна: мягкое свечение и серп
	var mc: Vector2 = P.call(372, 132)
	for k in 6:
		draw_circle(mc, (70.0 + k * 14.0) * s, Color(0.93, 0.9, 1.0, 0.035))
	_crescent(mc, 52.0 * s, Color("f3ecff"))
	# пара фишек: падают в чашку, чуть повернуты
	_tile(P.call(196, 214), Vector2(92, 118) * s, -0.32, 0)
	_tile(P.call(306, 196), Vector2(92, 118) * s, 0.24, 1)
	# чашка
	var cx: = 256.0
	var cy: = 370.0
	var bowl: = PackedVector2Array()
	var cols: = PackedColorArray()
	var n: = 32
	for i in n + 1:
		var t: = float(i) / n
		var a: = PI * t
		bowl.append(P.call(cx - 150 * cos(a), cy + 96 * sin(a)))
		cols.append(Color("9a3b2f").lerp(Color("4a1712"), absf(0.5 - t) * 2.0))
	bowl.append(P.call(cx - 150, cy))
	cols.append(Color("9a3b2f"))
	draw_polygon(bowl, cols)
	# ножка
	draw_rect(Rect2(P.call(cx - 46, cy + 92), Vector2(92, 16) * s), Color("3a120e"))
	# вода: нефритовый эллипс и рябь
	_ellipse(P.call(cx, cy), Vector2(146, 26) * s, Color("3f8f78"))
	_ellipse(P.call(cx, cy + 2), Vector2(128, 19) * s, Color("5fb39a"))
	for k in 2:
		_ellipse_line(P.call(cx + 8, cy + 1), Vector2(60 + k * 38, 9 + k * 5) * s, Color(T.jade300, 0.55 - k * 0.2), 2.0 * s)
	# золотой ободок
	_ellipse_line(P.call(cx, cy), Vector2(150, 28) * s, T.gold500, 4.0 * s)
	# капли через край
	for d in [[112, 392, 9.0], [96, 428, 7.0], [404, 388, 8.0], [418, 424, 6.0]]:
		_drop(P.call(d[0], d[1]), d[2] * s, Color(T.jade300, 0.9))
	# тонкая рамка gold700 35 %
	_round_line(Rect2(P.call(6, 6), Vector2(500, 500) * s), 80.0 * s, Color(T.gold700, 0.5), 2.0 * s)


func _round_rect(r: Rect2, rad: float, c0: Color, c1: Color) -> void:
	var pts: = _round_pts(r, rad)
	var cols: = PackedColorArray()
	for p in pts:
		cols.append(c0.lerp(c1, clampf((p.y - r.position.y) / r.size.y, 0.0, 1.0)))
	draw_polygon(pts, cols)


func _round_line(r: Rect2, rad: float, c: Color, w: float) -> void:
	var pts: = _round_pts(r, rad)
	pts.append(pts[0])
	draw_polyline(pts, c, w, true)


static func _round_pts(r: Rect2, rad: float) -> PackedVector2Array:
	var pts: = PackedVector2Array()
	var cs: = [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad), r.end - Vector2(rad, rad), Vector2(r.position.x + rad, r.end.y - rad)]
	var a0: = [PI, PI * 1.5, 0.0, PI * 0.5]
	for k in 4:
		for i in 9:
			var a: float = a0[k] + PI * 0.5 * i / 8.0
			pts.append(cs[k] + Vector2(cos(a), sin(a)) * rad)
	return pts


func _crescent(c: Vector2, r: float, col: Color) -> void:
	var c2: = c + Vector2(r * 0.46, -r * 0.2)
	var r2: = r * 0.84
	var pts: = PackedVector2Array()
	var n: = 72
	var a0: = (c2 - c).angle()
	for i in n + 1:
		var p: = c + Vector2.from_angle(a0 + TAU * i / n) * r
		if p.distance_to(c2) >= r2:
			pts.append(p)
	var inner: = PackedVector2Array()
	for i in n + 1:
		var q: = c2 + Vector2.from_angle(a0 + TAU * i / n) * r2
		if q.distance_to(c) <= r:
			inner.append(q)
	inner.reverse()
	pts.append_array(inner)
	if pts.size() >= 3:
		draw_colored_polygon(pts, col)


func _tile(c: Vector2, sz: Vector2, rot: float, glyph: int) -> void:
	draw_set_transform(c, rot, Vector2.ONE)
	var h: = sz * 0.5
	# корпус (нефритовая спинка), лицо (слоновая кость), фаска
	_round_rect(Rect2(-h + Vector2(7, 10) * sz.x / 92.0, sz), 12.0 * sz.x / 92.0, Color("2f7a62"), Color("1d5444"))
	_round_rect(Rect2(-h, sz), 12.0 * sz.x / 92.0, Color("fbf6ec"), Color("e8dcc6"))
	_round_line(Rect2(-h + Vector2(3, 3), sz - Vector2(6, 6)), 10.0 * sz.x / 92.0, Color(T.gold500, 0.7), 2.0)
	var k: = sz.x / 92.0
	if glyph == 0:
		# «одна монета»: кольцо и точка (зелень и киноварь)
		draw_arc(Vector2.ZERO, 26.0 * k, 0, TAU, 40, Color("2f7a62"), 6.0 * k, true)
		draw_arc(Vector2.ZERO, 15.0 * k, 0, TAU, 32, Color("c8463c"), 4.0 * k, true)
		draw_circle(Vector2.ZERO, 6.0 * k, Color("2f7a62"))
	else:
		# «бамбук»: три коленца
		for x in [-18.0, 0.0, 18.0]:
			draw_line(Vector2(x, -34) * k, Vector2(x, 34) * k, Color("2f7a62"), 7.0 * k, true)
			for y in [-12.0, 12.0]:
				draw_line(Vector2(x - 5, y) * k, Vector2(x + 5, y) * k, Color("c8463c") if x == 0.0 else Color("1d5444"), 3.0 * k, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts: = PackedVector2Array()
	for i in 48:
		var a: = TAU * i / 48.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _ellipse_line(c: Vector2, r: Vector2, col: Color, w: float) -> void:
	var pts: = PackedVector2Array()
	for i in 49:
		var a: = TAU * i / 48.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_polyline(pts, col, w, true)


func _drop(p: Vector2, r: float, col: Color) -> void:
	var pts: = PackedVector2Array()
	pts.append(p + Vector2(0, -r * 2.2))
	for i in 13:
		var a: = -PI * 0.15 + PI * 1.3 * i / 12.0
		pts.append(p + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)


# запечь в PNG (нужен настоящий рендер: xvfb + opengl3)
static func bake(host: Node, path_abs: String, px: = 512) -> bool:
	var vp: = SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var art: = V10MjGardenArt.new()
	art.size = Vector2(px, px)
	vp.add_child(art)
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: = vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return false
	return img.save_png(path_abs) == OK
