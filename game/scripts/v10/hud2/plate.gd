class_name V10Plate
extends Control

# V10Plate — the ONE plate family of HUD v2 (docs/HUD_V2.md §2). Three sizes with a fixed height:
#   S «Метка» 48 · M «Строка» 80 · L «Карточка» 160. Widths only from the module list (V10DS.PLATE_WIDTHS).
# Surface (§2.2): night.800 fill (α 0.92 over art), lacquer gradient on the top 40 %, 1 px bottom tone, and
# exactly ONE hairline: 1 px gold.700 α 0.35 on the TOP edge, inset 12, fading out over 24 px at both ends.
# No border, no shadow, no corner ornaments. Text auto-fits by stepping down the role scale, then ellipsis;
# the plate never grows: _get_minimum_size() is (w, H) and any container stretch is clamped back.
#
#   var p := V10Plate.make("M", 328, "Подарок дня", "Загляни завтра", "120")
#   p.icon = "heart"; p.interactive = true; p.pressed.connect(...)
#   p.selected / p.disabled / p.focused
#   p.right_slot = some_control   # e.g. a 56-px «Касса» button (M) or a 120-px slot (L)

signal pressed

var size_class: = "M":
	set(v):
		size_class = v if v in ["S", "M", "L"] else "M"
		_relayout()
var plate_w: = 328:
	set(v):
		plate_w = V10DS.plate_width(size_class, v) if snap_width else int(v)
		_relayout()
var snap_width: = true
var title: = "":
	set(v):
		title = v
		_relayout()
var subtitle: = "":
	set(v):
		subtitle = v
		_relayout()
var value: = "":
	set(v):
		value = v
		_relayout()
var icon: = "":
	set(v):
		icon = v
		_relayout()
var icon_tex: Texture2D = null:
	set(v):
		icon_tex = v
		_relayout()
var on_art: = true:
	set(v):
		on_art = v
		queue_redraw()
var selected: = false:
	set(v):
		selected = v
		_relayout()
var disabled: = false:
	set(v):
		disabled = v
		_relayout()
var focused: = false:
	set(v):
		focused = v
		queue_redraw()
var interactive: = false:
	set(v):
		interactive = v
		mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE
var right_slot: Control = null:
	set(v):
		if right_slot and right_slot.get_parent() == self:
			remove_child(right_slot)
		right_slot = v
		if v:
			add_child(v)
		_relayout()

var _title_l: Label
var _sub_l: Label
var _val_l: Label
var _icon_v: Control
var _down: = false
var _flash: = -1.0  # «отклик линии»: light dot running along the hairline (§6), 0..1


static func height_of(sc: String) -> int:
	return int(V10DS.PLATE_H.get(sc, 80))


static func make(sc: String, w: int, t: = "", sub: = "", val: = "", icon_name: = "") -> V10Plate:
	var p: = V10Plate.new()
	p.size_class = sc
	p.plate_w = w
	p.title = t
	p.subtitle = sub
	p.value = val
	p.icon = icon_name
	return p


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_title_l = Label.new()
	_sub_l = Label.new()
	_val_l = Label.new()
	for l in [_title_l, _sub_l, _val_l]:
		l.label_settings = V10Type.settings("ui", 22, V10DS.PAPER_100)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(l)
	_val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _ready() -> void:
	_relayout()


func plate_h() -> int:
	return height_of(size_class)


func _get_minimum_size() -> Vector2:
	return Vector2(plate_w, plate_h())


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# the plate never sags: whatever a container asked for, height and width snap back
		var want: = Vector2(plate_w, plate_h())
		if size != want:
			set_deferred("size", want)
		_relayout()


func _has_point(p: Vector2) -> bool:
	# S is 48 tall but taps on an 80-high band (hit_pad 16 above and below)
	var pad: = maxf(0.0, (V10DS.HIT_MIN - plate_h()) * 0.5)
	return Rect2(Vector2(0, -pad), Vector2(size.x, size.y + pad * 2.0)).has_point(p)


func _relayout() -> void:
	if not is_instance_valid(_title_l):
		return
	update_minimum_size()
	var w: = float(plate_w)
	var h: = float(plate_h())
	var pad: = float(V10DS.PLATE_PAD[size_class])
	var x: = pad
	# icon
	if _icon_v and (_icon_v.get_meta("for", "") != icon + str(icon_tex) + size_class):
		_icon_v.queue_free()
		_icon_v = null
	var isz: = 24 if size_class == "S" else 48
	if (icon != "" or icon_tex != null) and _icon_v == null:
		if icon_tex:
			var tr: = TextureRect.new()
			tr.texture = icon_tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_icon_v = tr
		else:
			_icon_v = V10Icons.icon(icon, isz, V10DS.PAPER_500)
		_icon_v.set_meta("for", icon + str(icon_tex) + size_class)
		add_child(_icon_v)
	if _icon_v:
		_icon_v.size = Vector2(isz, isz)
		_icon_v.position = Vector2(x, (h - isz) * 0.5)
		if _icon_v is V10Icons.View:
			(_icon_v as V10Icons.View).set_color(V10DS.GOLD_300 if selected else V10DS.PAPER_500)
		x += isz + (8 if size_class == "S" else 16)
	# right slot
	var right: = w - pad
	if right_slot:
		var rs: = right_slot.get_combined_minimum_size()
		rs.x = minf(rs.x, 160.0 if size_class != "S" else 96.0)
		rs.y = minf(rs.y, h)
		right_slot.size = rs
		right_slot.position = Vector2(right - rs.x, (h - rs.y) * 0.5)
		right -= rs.x + 16
	var a: = 0.5 if disabled else 1.0
	var tcol: = Color(V10DS.GOLD_300 if selected else V10DS.PAPER_100, a)
	_val_l.visible = value != ""
	if value != "":
		var vmax: = 120.0 if size_class == "L" else (96.0 if size_class == "M" else 72.0)
		var key: = "value_s" if size_class == "S" else "value"
		var vs: = V10Type.fit(_val_l, value, key, vmax, 1, Color(V10DS.GOLD_300, a))
		var vw: = minf(vmax, V10Type.text_w(value, "num", vs))
		var vh: = float(V10Type.line_h(vs))
		_val_l.size = Vector2(vw + 2, vh)
		_val_l.position = Vector2(right - vw - 2, (h - vh) * 0.5)
		right -= vw + 16
	var tw: = maxf(8.0, right - x)
	match size_class:
		"S":
			_sub_l.visible = false
			V10Type.fit(_title_l, title, "title_sm", tw, 1, tcol)
			_title_l.position = Vector2(x, 0)
			_title_l.size = Vector2(tw, h)
		"M":
			_sub_l.visible = subtitle != ""
			V10Type.fit(_title_l, title, "title_sm", tw, 1, tcol)
			if subtitle != "":
				V10Type.fit(_sub_l, subtitle, "caption_m", tw, 1, Color(V10DS.PAPER_300, a))
				var top: = (h - 32.0 - 28.0) * 0.5
				_title_l.position = Vector2(x, top)
				_title_l.size = Vector2(tw, 32)
				_sub_l.position = Vector2(x, top + 32.0)
				_sub_l.size = Vector2(tw, 28)
			else:
				_title_l.position = Vector2(x, 0)
				_title_l.size = Vector2(tw, h)
		"L":
			_sub_l.visible = subtitle != ""
			V10Type.fit(_title_l, title, "title_l", tw, 1, tcol)
			var top_l: = (h - 40.0 - 64.0) * 0.5 if subtitle != "" else (h - 40.0) * 0.5
			_title_l.position = Vector2(x, top_l)
			_title_l.size = Vector2(tw, 40)
			if subtitle != "":
				var ss: = V10Type.fit(_sub_l, subtitle, "text_l", tw, 2, Color(V10DS.PAPER_300, a))
				_sub_l.position = Vector2(x, top_l + 40.0)
				_sub_l.size = Vector2(tw, V10Type.line_h(ss) * 2)
				_sub_l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	queue_redraw()


func ping() -> void:
	# §6 «Отклик плашки на изменение»: one light dot runs along the hairline in 360 ms (only on an event)
	if V10Hud2Util.fx_level() == "min":
		return
	var tw: = create_tween()
	tw.tween_method(func(v: float) -> void:
		_flash = v
		queue_redraw(), 0.0, 1.0, 0.36).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_flash = -1.0
		queue_redraw())


func _draw() -> void:
	draw_surface(self, Rect2(Vector2.ZERO, Vector2(plate_w, plate_h())), on_art, _down, selected, disabled, focused, _flash)


static func draw_surface(ci: CanvasItem, r: Rect2, over_art: = true, down: = false, sel: = false, dis: = false, foc: = false, flash: = -1.0, fill_override: = Color.TRANSPARENT) -> void:
	# §2.2 (Wave 2 «дорогой лак») — shared by the plate, the tray and sheets:
	# warm lacquer gradient, thin antique-gold rim with a bright inner highlight, champagne corner studs.
	var rad: = 10.0
	var a_fill: = V10DS.ON_ART_A if over_art else 1.0
	var top_c: Color = V10DS.PLATE_SEL_TOP if sel else V10DS.PLATE_TOP
	var bot_c: Color = V10DS.PLATE_SEL_BOT if sel else V10DS.PLATE_BOT
	if down:
		top_c = V10DS.NIGHT_600
		bot_c = V10DS.NIGHT_700
	if fill_override.a > 0.0:
		top_c = fill_override
		bot_c = fill_override.darkened(0.25)
	var op: = V10Button.rr_pts(r, rad, 8)
	var rim_a: = 0.2 if dis else (1.0 if (sel or foc) else (0.9 if down else 0.6))
	ci.draw_polygon(op, V10Button.grad_cols(op, r.position.y, r.end.y, [[0.0, Color(V10DS.PLATE_SPARK, rim_a)], [0.5, Color(V10DS.PLATE_RIM, rim_a)], [1.0, Color(V10DS.GOLD_700, rim_a)]]))
	var r2: = r.grow(-1.5)
	var ip: = V10Button.rr_pts(r2, rad - 1.5, 8)
	ci.draw_polygon(ip, V10Button.grad_cols(ip, r2.position.y, r2.end.y, [[0.0, Color(top_c, a_fill)], [1.0, Color(bot_c, a_fill)]]))
	# lacquer: warm sheen on the top 45 %
	var lh: = r.size.y * 0.45
	var lac: = Color(V10DS.PAPER_100, V10DS.LACQUER_A)
	var clear: = Color(V10DS.PAPER_100, 0.0)
	ci.draw_polygon(PackedVector2Array([r.position + Vector2(rad * 0.6, 2.5), r.position + Vector2(r.size.x - rad * 0.6, 2.5),
			r.position + Vector2(r.size.x - 3, lh), r.position + Vector2(3, lh)]),
			PackedColorArray([lac, lac, clear, clear]))
	# inner gold highlight line 4 px inside the rim
	var hp: = V10Button.rr_pts(r.grow(-4.0), rad - 4.0, 8)
	hp.append(hp[0])
	ci.draw_polyline(hp, Color(V10DS.GOLD_500, 0.10 if dis else 0.26), 1.0, true)
	ci.draw_line(r.position + Vector2(rad, r.size.y - 2.5), r.position + Vector2(r.size.x - rad, r.size.y - 2.5),
			Color(V10DS.NIGHT_900, V10DS.BOTTOM_TONE_A), 1.5)
	# champagne corner studs
	if not dis:
		for cxy in [Vector2(r.position.x + 7, r.position.y + 7), Vector2(r.end.x - 7, r.position.y + 7), Vector2(r.position.x + 7, r.end.y - 7), Vector2(r.end.x - 7, r.end.y - 7)]:
			ci.draw_colored_polygon(PackedVector2Array([cxy + Vector2(0, -2.6), cxy + Vector2(2.6, 0), cxy + Vector2(0, 2.6), cxy + Vector2(-2.6, 0)]), Color(V10DS.PLATE_SPARK, 0.8))
	# THE hairline (top only)
	var la: = V10DS.HAIR_A
	var lc: = V10DS.GOLD_700
	if dis:
		la = 0.15
	if down:
		lc = V10DS.GOLD_500
		la = 0.6
	if sel or foc:
		lc = V10DS.GOLD_500
		la = 1.0
	hairline(ci, r.position.x + V10DS.HAIR_INSET, r.end.x - V10DS.HAIR_INSET, r.position.y + 0.5, Color(lc, la))
	if foc:  # the only case with two lines (§2.2)
		hairline(ci, r.position.x + V10DS.HAIR_INSET, r.end.x - V10DS.HAIR_INSET, r.end.y - 1.5, Color(lc, la))
	if flash >= 0.0:
		var fx: = lerpf(r.position.x + V10DS.HAIR_INSET, r.end.x - V10DS.HAIR_INSET, flash)
		for i in 8:
			var k: = 1.0 - i / 8.0
			ci.draw_line(Vector2(fx - 32.0 * k, r.position.y + 0.5), Vector2(fx + 32.0 * k, r.position.y + 0.5),
					Color(V10DS.GOLD_300, 0.12), 1.0)


static func hairline(ci: CanvasItem, x0: float, x1: float, y: float, col: Color) -> void:
	var f: = minf(float(V10DS.HAIR_FADE), (x1 - x0) * 0.3)
	var c0: = Color(col, 0.0)
	ci.draw_polyline_colors(PackedVector2Array([Vector2(x0, y), Vector2(x0 + f, y), Vector2(x1 - f, y), Vector2(x1, y)]),
			PackedColorArray([c0, col, col, c0]), 1.0)


func _gui_input(e: InputEvent) -> void:
	if not interactive or disabled:
		return
	if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
		if e.pressed:
			_down = true
			pivot_offset = size * 0.5
			var tw: = create_tween()
			tw.tween_property(self, "scale", Vector2.ONE * 0.94, 0.06)
			queue_redraw()
		elif _down:
			_down = false
			var tw2: = create_tween()
			tw2.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			queue_redraw()
			if Rect2(Vector2.ZERO, size).grow(16).has_point(e.position):
				pressed.emit()
		accept_event()
