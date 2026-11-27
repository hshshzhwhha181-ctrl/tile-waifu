class_name V10Button
extends Control

# V10Button — crisp vector lacquer buttons in HUD v2 metrics ("Тишина и лак").
#   "play"      refined dusty-rose / velvet-sakura pill (ROSE_500 subtle gradient + 1px champagne-gold top sheen),
#               crisp NIGHT_900 Playfair Display text, NO AI swirls, NO heavy outline
#   "cash"      matte obsidian lacquer (NIGHT_700), crisp 1.5px GOLD_500 hairline border, radius 6, PAPER_100 numerals
#   "secondary" matte NIGHT_800 at alpha 0.92, single 1px top gold hairline (GOLD_700 at alpha 0.45), radius 6
#   "quiet"     clean icon in subtle translucent circle inside an 80x80 hit zone

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

static func _hf_tex(_is_buy: bool) -> Texture2D:
	# Disabled: HUD v2 buttons are crisp vector lacquer, never AI swirl textures.
	return null


static func draw_hf_pill(ci: CanvasItem, tex: Texture2D, r: Rect2, src: Rect2, src_cap: float, mod: Color) -> void:
	var rad: = minf(26.0, r.size.y * 0.46)
	ci.draw_colored_polygon(rr_pts(Rect2(r.position + Vector2(0, 4), r.size), rad, 8), Color(V10DS.NIGHT_900, 0.48))
	var dcap: = minf(r.size.x * 0.46, src_cap * (r.size.y / maxf(1.0, src.size.y)))
	ci.draw_texture_rect_region(tex, Rect2(r.position.x, r.position.y, dcap, r.size.y),
		Rect2(src.position.x, src.position.y, src_cap, src.size.y), mod)
	var mw: = r.size.x - dcap * 2.0
	if mw > 0.5:
		ci.draw_texture_rect_region(tex, Rect2(r.position.x + dcap, r.position.y, mw, r.size.y),
			Rect2(src.position.x + src_cap, src.position.y, src.size.x - src_cap * 2.0, src.size.y), mod)
	ci.draw_texture_rect_region(tex, Rect2(r.end.x - dcap, r.position.y, dcap, r.size.y),
		Rect2(src.end.x - src_cap, src.position.y, src_cap, src.size.y), mod)


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
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_l = Label.new()
	_l.label_settings = V10Type.settings("ui", 22, V10DS.PAPER_100, false)
	_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_l.clip_text = true
	_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_l)
	_ov = Label.new()
	_ov.label_settings = V10Type.settings("overline", 15, V10DS.GOLD_500, true)
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
		"play", "primary":
			V10Type.fit(_l, text, "button_play", btn_size.x - 64.0, 1, V10DS.NIGHT_900, false)
			_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_l.position = Vector2(32.0, 0.0)
			_l.size = Vector2(btn_size.x - 64.0, btn_size.y)
		"cash":
			_l.label_settings = V10Type.settings("num", 28, V10DS.PAPER_100, false)
			_l.text = text
			_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_l.position = Vector2(12.0, 0.0)
			_l.size = Vector2(btn_size.x - 24.0, btn_size.y)
		"secondary":
			V10Type.fit(_l, text, "button_ui", btn_size.x - 64.0, 1, V10DS.PAPER_100, false)
			var tw: = minf(btn_size.x - 64.0, V10Type.text_w(text, "ui", _l.label_settings.font_size))
			_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_l.size = Vector2(tw + 6.0, btn_size.y)
			_l.position = Vector2((btn_size.x - tw - 36.0) * 0.5, 0.0)
		_:
			_l.text = ""
	_ov.visible = overline != ""
	if overline != "":
		_ov.label_settings = V10Type.settings("overline", 15, V10DS.GOLD_500, true)
		_ov.text = overline.to_upper()
		_ov.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ov.position = Vector2(0.0, -26.0)
		_ov.size = Vector2(btn_size.x, 22.0)
	queue_redraw()


func _draw() -> void:
	var r: = Rect2(Vector2.ZERO, btn_size)
	match kind:
		"play", "primary":
			var rad: = btn_size.y * 0.5
			# gentle grounding shadow under the pill
			draw_colored_polygon(rr_pts(Rect2(r.position + Vector2(0.0, 3.0), r.size), rad, 12), Color(V10DS.NIGHT_900, 0.34))
			# refined dusty-rose / velvet-sakura vertical tone gradient
			var ct: = V10DS.ROSE_700.lightened(0.06) if _down else V10DS.ROSE_500.lightened(0.06)
			var cm: = V10DS.ROSE_700 if _down else V10DS.ROSE_500
			var cb: = V10DS.ROSE_700.darkened(0.08) if _down else V10DS.ROSE_500.lerp(V10DS.ROSE_700, 0.22)
			var body_pts: = rr_pts(r, rad, 14)
			draw_polygon(body_pts, grad_cols(body_pts, r.position.y, r.end.y, [
				[0.0, ct],
				[0.52, cm],
				[1.0, cb],
			]))
			# soft velvet top sheen inside the pill
			var sr: = Rect2(r.position.x + 2.0, r.position.y + 1.5, r.size.x - 4.0, r.size.y * 0.44)
			if sr.size.x > 8.0 and sr.size.y > 4.0:
				var sp: = rr_pts(sr, minf(rad - 2.0, sr.size.y * 0.48), 10)
				draw_polygon(sp, grad_cols(sp, sr.position.y, sr.end.y, [
					[0.0, Color(V10DS.PAPER_100, 0.06 if _down else 0.13)],
					[1.0, Color(V10DS.PAPER_100, 0.0)],
				]))
			# 1px champagne-gold top hairline sheen + subtle bottom velvet depth
			var inset: = minf(rad * 0.72, btn_size.x * 0.25)
			V10Plate.hairline(self, inset, btn_size.x - inset, 1.0, Color(V10DS.PLATE_SPARK, 0.42 if _down else 0.76))
			V10Plate.hairline(self, inset, btn_size.x - inset, btn_size.y - 1.2, Color(V10DS.ROSE_700, 0.45))
		"cash":
			var rad2: = 6.0
			var bg: = V10DS.NIGHT_600 if _down else V10DS.NIGHT_700
			var pts2: = rr_pts(r, rad2, 8)
			draw_polygon(pts2, grad_cols(pts2, r.position.y, r.end.y, [
				[0.0, bg.lightened(0.03)],
				[1.0, bg],
			]))
			# subtle lacquer top gradient
			var lh2: = r.size.y * 0.42
			var lac2: = Color(V10DS.PAPER_100, 0.05)
			var clr2: = Color(V10DS.PAPER_100, 0.0)
			draw_polygon(PackedVector2Array([
				Vector2(rad2 * 0.5, 1.5), Vector2(r.size.x - rad2 * 0.5, 1.5),
				Vector2(r.size.x - 2.0, lh2), Vector2(2.0, lh2),
			]), PackedColorArray([lac2, lac2, clr2, clr2]))
			# crisp 1.5px GOLD_500 hairline border
			var bp: = rr_pts(r.grow(-0.75), maxf(2.0, rad2 - 0.75), 8)
			bp.append(bp[0])
			draw_polyline(bp, V10DS.GOLD_300 if _down else V10DS.GOLD_500, 1.5, true)
		"secondary":
			var rad3: = 6.0
			var bg3: = Color(V10DS.NIGHT_600, 0.96) if _down else Color(V10DS.NIGHT_800, 0.92)
			draw_colored_polygon(rr_pts(r, rad3, 8), bg3)
			# subtle lacquer top tone + 1px bottom tone
			var lh3: = r.size.y * 0.40
			var lac3: = Color(V10DS.PAPER_100, 0.05)
			var clr3: = Color(V10DS.PAPER_100, 0.0)
			draw_polygon(PackedVector2Array([
				Vector2(rad3 * 0.5, 1.0), Vector2(r.size.x - rad3 * 0.5, 1.0),
				Vector2(r.size.x - 1.5, lh3), Vector2(1.5, lh3),
			]), PackedColorArray([lac3, lac3, clr3, clr3]))
			draw_line(Vector2(rad3, r.size.y - 1.0), Vector2(r.size.x - rad3, r.size.y - 1.0), Color(V10DS.NIGHT_900, 0.65), 1.0)
			# single 1px top gold hairline (GOLD_700 at alpha 0.45)
			V10Plate.hairline(self, 12.0, btn_size.x - 12.0, 0.8, Color(V10DS.GOLD_500 if _down else V10DS.GOLD_700, 0.65 if _down else 0.45))
			if text != "":
				var tw2: = _l.size.x
				V10Icons.draw(self, "arrow_r", Vector2(_l.position.x + tw2 + 18.0, btn_size.y * 0.5), 24, V10DS.GOLD_300)
		"quiet":
			var ctr: = btn_size * 0.5
			var dr: = minf(btn_size.x, btn_size.y) * 0.36
			draw_circle(ctr, dr, Color(V10DS.NIGHT_600, 0.72) if _down else Color(V10DS.NIGHT_800, 0.44), true, -1.0, true)
			draw_arc(ctr, dr, 0.0, TAU, 48, Color(V10DS.GOLD_500, 0.60) if _down else Color(V10DS.GOLD_700, 0.34), 1.0, true)
			if icon != "":
				V10Icons.draw(self, icon, ctr, icon_px, icon_color)


func _tap_feedback(denied: = false) -> void:
	if not is_inside_tree():
		return
	var tree: = get_tree()
	if tree == null or tree.root == null:
		return
	var sfx: = tree.root.get_node_or_null("Sfx")
	if sfx != null and sfx.has_method("play"):
		if denied:
			sfx.call("play", "deny", 1.0, -4.0)
		else:
			sfx.call("play", "tap", randf_range(0.96, 1.04), -4.0)
	var feel: = V10Hud2Util.opt_class("V9Feel")
	if feel != null:
		feel.call("haptic", "deny" if denied else "button")
	else:
		var hp: = tree.root.get_node_or_null("V7Haptics")
		if hp != null and hp.has_method("kind"):
			hp.call("kind", "deny" if denied else "button")


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
				_tap_feedback(false)
				pressed.emit()
		accept_event()
