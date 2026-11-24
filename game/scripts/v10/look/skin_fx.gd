class_name V10SkinFx
extends RefCounted

# V10SkinFx — each skin's own press and window-opening response (D7, UX §6.8 «Перо скина»).
#   five_winds: press = V9Feel spring only; open = «Шёлк» (12 px rise + fade, 0,22 с, QUINT_OUT)
#   zlata:      press = gold glint across the lacquer (0,36 с); open = the feather pen draws the gold frame (0,4 с),
#               along the inner scarlet line, its glow fading after. fx «минимум»: no glint, the window fades in 0,12 с.
# Never white: the glint and the pen are gold_300 / gold_500 of the active palette, the pen tip an ember glow.

const GLINT_T: = 0.36


static func press(node: Control, skin_id: String) -> void:
	if node == null or not node.is_inside_tree():
		return
	var fx: = String(V10HudSkinData.skin(skin_id).get("press_fx", "spring"))
	if fx != "glint" or V10HudSkin.fx_level() == "min":
		return
	var g: = _Glint.new()
	g.col = V10HudSkin.tok("gold_300", skin_id)
	g.size = node.size
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(g)


static func open(win: Control, skin_id: String) -> void:
	if win == null:
		return
	var lvl: = V10HudSkin.fx_level()
	var fx: = String(V10HudSkinData.skin(skin_id).get("open_fx", "silk"))
	if lvl == "min":
		# information stays, motion becomes a 0,12 с fade (UX §6.7)
		if win.is_inside_tree():
			win.modulate.a = 0.0
			win.create_tween().tween_property(win, "modulate:a", 1.0, 0.12)
		return
	if fx == "pen":
		var pen: = _Pen.new()
		pen.col = V10HudSkin.tok("gold_500", skin_id)
		pen.tip = V10HudSkin.tok("gold_300", skin_id)
		pen.size = win.size
		pen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pen.skin_id = skin_id
		win.add_child(pen)
		win.modulate.a = 0.0
		if win.is_inside_tree():
			win.create_tween().tween_property(win, "modulate:a", 1.0, 0.12)
		else:
			win.ready.connect(func(): win.create_tween().tween_property(win, "modulate:a", 1.0, 0.12), CONNECT_ONE_SHOT)
		return
	# silk
	var y0: = win.position.y
	win.position.y = y0 + 12.0
	win.modulate.a = 0.0
	var go: = func():
		var tw: = win.create_tween().set_parallel()
		tw.tween_property(win, "position:y", y0, V10HudSkin.T_SILK).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tw.tween_property(win, "modulate:a", 1.0, V10HudSkin.T_SILK).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	if win.is_inside_tree():
		go.call()
	else:
		win.ready.connect(go, CONNECT_ONE_SHOT)


class _Glint extends Control:
	var col: = Color.GOLD
	var k: = 0.0

	func _ready() -> void:
		clip_contents = true
		var mat: = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
		var tw: = create_tween()
		tw.tween_property(self, "k", 1.0, V10SkinFx.GLINT_T).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(queue_free)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var x: = lerpf(-size.y, size.x + size.y, k)
		var a: = sin(k * PI) * 0.55
		for i in 5:
			var off: = (i - 2) * 6.0
			var pts: = PackedVector2Array([Vector2(x + off - 10, size.y), Vector2(x + off + size.y * 0.36 - 10, 0),
				Vector2(x + off + size.y * 0.36 + 10, 0), Vector2(x + off + 10, size.y)])
			draw_colored_polygon(pts, Color(col, a * (0.35 - absf(i - 2) * 0.12)))


class _Pen extends Control:
	var col: = Color.GOLD
	var tip: = Color.WHITE
	var k: = 0.0
	var skin_id: = "zlata"
	var ember: = Color("ff7a2a")
	var _done: = false

	func _ready() -> void:
		var tw: = create_tween()
		tw.tween_property(self, "k", 1.0, V10HudSkin.T_PEN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(_finish)

	func _finish() -> void:
		_done = true
		var tw: = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.45)
		tw.tween_callback(queue_free)

	func _process(_d: float) -> void:
		queue_redraw()

	func _perim(t: float, r: Rect2) -> Vector2:
		var L: = 2.0 * (r.size.x + r.size.y)
		var d: = t * L
		if d < r.size.x:
			return r.position + Vector2(d, 0)
		d -= r.size.x
		if d < r.size.y:
			return r.position + Vector2(r.size.x, d)
		d -= r.size.y
		if d < r.size.x:
			return r.position + Vector2(r.size.x - d, r.size.y)
		d -= r.size.x
		return r.position + Vector2(0, r.size.y - d)

	func _draw() -> void:
		# along the inner scarlet line of the lacquer frame (texture margin 104 @2x -> ~44 px on screen)
		var ins: = 44.0 if size.x > 200.0 else 12.0
		var r: = Rect2(Vector2(ins, ins), size - Vector2(ins, ins) * 2.0)
		# two pens from the top-left corner, one clockwise, one counter-clockwise; they meet at the bottom-right
		for dir in [1.0, -1.0]:
			var pts: = PackedVector2Array()
			var n: = 48
			for i in n + 1:
				var tt: = k * 0.5 * i / n
				pts.append(_perim(tt if dir > 0 else fposmod(-tt, 1.0), r))
			if pts.size() >= 2:
				draw_polyline(pts, Color(ember, 0.40), 10.0, true)
				draw_polyline(pts, Color(col, 0.75), 5.0, true)
				draw_polyline(pts, Color(tip, 1.0), 2.0, true)
				if not _done:
					var p: = pts[pts.size() - 1]
					draw_circle(p, 18.0, Color(ember, 0.35), true, -1.0, true)
					draw_circle(p, 8.0, Color(tip, 0.7), true, -1.0, true)
					draw_circle(p, 2.5, Color(tip, 1.0), true, -1.0, true)
