class_name V10Button
extends Control

# V10Button — luxury AAA lacquer buttons in HUD v2 metrics (Wave 2 overhaul).
#   "play"      crimson-sakura lacquer gradient, double gold bevel border, subtle top glass sheen,
#               flanking gold diamonds, luminous ivory Display text with crisp wine backdrop; ZERO idle jitter
#   "cash"      obsidian-plum lacquer, double gold rim, luminous gold Numerals 28
#   "secondary" deep plum lacquer, warm gold bevel border, UI 22 paper.100 + gold arrow_r
#   "quiet"     icon only (48, or 32 inside the top bar) in an 80x80 hit zone

signal pressed

var kind: = "play"
var text: = "":
	set(v):
		text = v
		_relayout()
var overline: = "":
	set(v):
		overline = v
		_relayout()
var icon: = "":
	set(v):
		icon = v
		queue_redraw()
var icon_px: = 48
var icon_color: = V10DS.PAPER_500
var breathing: = false
var sheen: = false
var btn_size: = Vector2(560, 104):
	set(v):
		btn_size = v
		_relayout()

var _l: Label
var _ov: Label
var _down: = false


static func make(k: String, t: String, sz: Vector2) -> V10Button:
	var b: = V10Button.new()
	b.kind = k
	b.btn_size = sz
	b.text = t
	b.breathing = false
	b.sheen = false
	return b


static func rr_pts(r: Rect2, rad: float, segs: = 8) -> PackedVector2Array:
	var rr: = clampf(rad, 0.0, minf(r.size.x, r.size.y) * 0.5)
	var pts: = PackedVector2Array()
	var corners: = [
		[Vector2(r.end.x - rr, r.position.y + rr), -PI * 0.5, 0.0],
		[Vector2(r.end.x - rr, r.end.y - rr), 0.0, PI * 0.5],
		[Vector2(r.position.x + rr, r.end.y - rr), PI * 0.5, PI],
		[Vector2(r.position.x + rr, r.position.y + rr), PI, PI * 1.5],
	]
	for c in corners:
		var ctr: Vector2 = c[0]
		var a0: float = c[1]
		var a1: float = c[2]
		for i in segs + 1:
			var a: = lerpf(a0, a1, float(i) / float(segs))
			pts.append(ctr + Vector2(cos(a), sin(a)) * rr)
	return pts


static func grad_cols(pts: PackedVector2Array, y0: float, y1: float, stops: Array) -> PackedColorArray:
	var out: = PackedColorArray()
	var span: = maxf(0.001, y1 - y0)
	var last: = stops.size() - 1
	for p in pts:
		var t: = clampf((p.y - y0) / span, 0.0, 1.0)
		var col: Color = stops[last][1]
		if t <= float(stops[0][0]):
			col = stops[0][1]
		else:
			for i in last:
				var t0: float = stops[i][0]
				var t1: float = stops[i + 1][0]
				if t <= t1:
					var k: = clampf((t - t0) / maxf(0.0001, t1 - t0), 0.0, 1.0)
					col = (stops[i][1] as Color).lerp(stops[i + 1][1] as Color, k)
					break
		out.append(col)
	return out


static func lacquer(ci: CanvasItem, r: Rect2, rad: float, c_top: Color, c_mid: Color, c_bot: Color, rim_a: = 1.0, sheen_col: = V10DS.PAPER_100, sheen_a: = 0.16) -> void:
	var rr: = clampf(rad, 4.0, minf(r.size.x, r.size.y) * 0.5)
	# soft drop shadow
	ci.draw_colored_polygon(rr_pts(Rect2(r.position + Vector2(0, 5), r.size).grow(1.5), rr + 1.5, 8), Color(V10DS.NIGHT_900, 0.52 * rim_a))
	# outer gold metallic bezel
	var op: = rr_pts(r, rr, 10)
	ci.draw_polygon(op, grad_cols(op, r.position.y, r.end.y, [
		[0.0, Color(V10DS.PLATE_SPARK, rim_a)],
		[0.45, Color(V10DS.GOLD_500, rim_a)],
		[1.0, Color(V10DS.GOLD_700, rim_a)],
	]))
	# dark lacquer inset groove
	var r2: = r.grow(-2.5)
	ci.draw_colored_polygon(rr_pts(r2, maxf(2.0, rr - 2.5), 10), V10DS.NIGHT_900)
	# rich 3-stop vertical lacquer body
	var r3: = r.grow(-3.8)
	var p3: = rr_pts(r3, maxf(2.0, rr - 3.8), 10)
	ci.draw_polygon(p3, grad_cols(p3, r3.position.y, r3.end.y, [
		[0.0, c_top],
		[0.5, c_mid],
		[1.0, c_bot],
	]))
	# subtle top glass specular sheen
	var sr: = Rect2(r3.position.x + 4.0, r3.position.y + 1.5, r3.size.x - 8.0, r3.size.y * 0.44)
	if sr.size.x > 8.0 and sr.size.y > 4.0:
		var sp: = rr_pts(sr, maxf(2.0, rr - 5.5), 8)
		ci.draw_polygon(sp, grad_cols(sp, sr.position.y, sr.end.y, [
			[0.0, Color(sheen_col, sheen_a)],
			[1.0, Color(sheen_col, 0.0)],
		]))
	# second inner filigree gold rim
	var r4: = r.grow(-6.5)
	var p4: = rr_pts(r4, maxf(2.0, rr - 6.5), 10)
	p4.append(p4[0])
	ci.draw_polyline(p4, Color(V10DS.GOLD_300, 0.55 * rim_a), 1.2, true)
	# champagne top-edge gleam
	V10Plate.hairline(ci, r.position.x + rr + 4.0, r.end.x - rr - 4.0, r.position.y + 1.2, Color(V10DS.PLATE_SPARK, 0.85 * rim_a))


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_l = Label.new()
	_l.label_settings = V10Type.settings("ui", 22, V10DS.PAPER_100, true)
	_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_l.clip_text = true
	_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_l)
	_ov = Label.new()
	_ov.label_settings = V10Type.settings("overline", 18, V10DS.GOLD_300, true)
	_ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ov)


func _ready() -> void:
	_relayout()
	set_process(false)


func _get_minimum_size() -> Vector2:
	return btn_size


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(_l):
		if size != btn_size:
			set_deferred("size", btn_size)
		pivot_offset = btn_size * 0.5


func _relayout() -> void:
	if not is_instance_valid(_l):
		return
	update_minimum_size()
	pivot_offset = btn_size * 0.5
	match kind:
		"play":
			V10Type.fit(_l, text, "button_play", btn_size.x - 88.0, 1, V10DS.BTN_PLAY_TEXT, true)
			_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_l.position = Vector2(44, 0)
			_l.size = Vector2(btn_size.x - 88.0, btn_size.y)
		"cash":
			_l.label_settings = V10Type.settings("num", 28, V10DS.GOLD_300, true)
			_l.text = text
			_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_l.position = Vector2(12, 0)
			_l.size = Vector2(btn_size.x - 24.0, btn_size.y)
		"secondary":
			V10Type.fit(_l, text, "button_ui", btn_size.x - 64.0, 1, V10DS.PAPER_100, true)
			var tw: = minf(btn_size.x - 64.0, V10Type.text_w(text, "ui", _l.label_settings.font_size))
			_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_l.size = Vector2(tw + 6.0, btn_size.y)
			_l.position = Vector2((btn_size.x - tw - 42.0) * 0.5, 0)
		_:
			_l.text = ""
	_ov.visible = overline != ""
	if overline != "":
		_ov.label_settings = V10Type.settings("overline", 18, V10DS.GOLD_300, true)
		_ov.text = overline.to_upper()
		_ov.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ov.position = Vector2(0, -30)
		_ov.size = Vector2(btn_size.x, 24)
	queue_redraw()


func _draw_diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)
	]), col)


func _draw() -> void:
	var r: = Rect2(Vector2.ZERO, btn_size)
	match kind:
		"play":
			var rad: = minf(26.0, btn_size.y * 0.32)
			var ct: = V10DS.BTN_PLAY_DOWN_TOP if _down else V10DS.BTN_PLAY_TOP
			var cm: = V10DS.BTN_PLAY_DOWN_BOT if _down else V10DS.BTN_PLAY_MID
			var cb: = V10DS.BTN_PLAY_DOWN_BOT if _down else V10DS.BTN_PLAY_BOT
			lacquer(self, r, rad, ct, cm, cb, 0.85 if _down else 1.0, V10DS.BTN_PLAY_GLOW, 0.18 if _down else 0.30)
			# Flanking gold diamond ornaments
			var dc: = Color(V10DS.PLATE_SPARK, 0.75 if _down else 0.95)
			var yc: = btn_size.y * 0.5
			_draw_diamond(Vector2(26.0, yc), 5.5, dc)
			_draw_diamond(Vector2(btn_size.x - 26.0, yc), 5.5, dc)
			# Crisp dark wine outline/drop behind ivory label (keeps Label outline_size == 0 for hud2_selftest)
			if is_instance_valid(_l) and _l.text != "" and _l.label_settings != null:
				var f: Font = _l.label_settings.font
				var fs: int = _l.label_settings.font_size
				var tw: = f.get_string_size(_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				if tw <= _l.size.x + 2.0:
					var bx: = _l.position.x + (_l.size.x - tw) * 0.5
					var by: = _l.position.y + (_l.size.y - f.get_height(fs)) * 0.5 + f.get_ascent(fs)
					var oc: = Color(V10DS.BTN_PLAY_OUTLINE, 0.82)
					for off in [Vector2(-1.6, 0), Vector2(1.6, 0), Vector2(0, -1.6), Vector2(0, 1.6), Vector2(0, 3.2)]:
						draw_string(f, Vector2(bx, by) + off, _l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, oc)
			# Decorative flanking gold hairlines on overline
			if overline != "":
				var ow: = V10Type.text_w(overline.to_upper(), "overline", 18)
				var mid: = btn_size.x * 0.5
				var g0: = maxf(16.0, mid - ow * 0.5 - 48.0)
				var g1: = mid - ow * 0.5 - 12.0
				if g1 - g0 > 12.0:
					V10Plate.hairline(self, g0, g1, -18.0, Color(V10DS.GOLD_500, 0.72))
					V10Plate.hairline(self, mid + ow * 0.5 + 12.0, minf(btn_size.x - 16.0, mid + ow * 0.5 + 48.0), -18.0, Color(V10DS.GOLD_500, 0.72))
		"cash":
			var ct2: = V10DS.NIGHT_600 if _down else V10DS.BTN_CASH_TOP
			var cb2: = V10DS.NIGHT_700 if _down else V10DS.BTN_CASH_BOT
			lacquer(self, r, 12.0, ct2, ct2.lerp(cb2, 0.5), cb2, 0.95, V10DS.PAPER_100, 0.14)
		"secondary":
			var st: = V10DS.BTN_SEC_DOWN_TOP if _down else V10DS.BTN_SEC_TOP
			var sb_bot: = V10DS.BTN_SEC_DOWN_BOT if _down else V10DS.BTN_SEC_BOT
			lacquer(self, r, 16.0, st, st.lerp(sb_bot, 0.55), sb_bot, 0.9 if _down else 0.85, V10DS.PAPER_100, 0.14)
			if text != "":
				var tw2: = _l.size.x
				V10Icons.draw(self, "arrow_r", Vector2(_l.position.x + tw2 + 20.0, btn_size.y * 0.5), 24, V10DS.GOLD_300)
		"quiet":
			if _down:
				draw_circle(btn_size * 0.5, minf(btn_size.x, btn_size.y) * 0.42, Color(V10DS.NIGHT_600, 0.6), true, -1.0, true)
			if icon != "":
				V10Icons.draw(self, icon, btn_size * 0.5, icon_px, icon_color)


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
		if e.pressed:
			_down = true
			scale = Vector2.ONE * 0.96
			queue_redraw()
		elif _down:
			_down = false
			var tw: = create_tween()
			tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			queue_redraw()
			if Rect2(Vector2.ZERO, size).grow(16).has_point(e.position):
				pressed.emit()
		accept_event()
