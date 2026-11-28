class_name TWPlate
extends Control

# TWPlate (P28 / WP9b): THE plate family of v11 (ported from V10Plate; V10Plate is now a thin subclass). Three sizes with a fixed height
# (TWTokens.PLATE_H: S 48 / M 80 / L 160), widths only from the module list. Surface = TWDraw.plate_surface (night fill, lacquer top,
# ONE gold hairline). Text auto-fits by stepping down the closed type scale (TWTokens.TYPE_*), then ellipsis; the plate never grows.
#
#   var p := TWPlate.make("M", 328, "Подарок дня", "Загляни завтра", "120")
#   p.icon = "heart"; p.interactive = true; p.pressed.connect(...)
#   p.selected / p.disabled / p.focused ; p.right_slot = some_control ; p.ping()
# Tap: down 90 ms to 0.94, up 160 ms spring (same curve as TWButton). A small plate (S) is still tappable on a 96 px band (HIT_TARGET_MIN).

signal pressed

const WIDTHS: = {"S": [96, 144, 192, 216, 240, 288], "M": [200, 328, 656, 672], "L": [328, 656, 672]}
const PAD: = {"S": 16, "M": 24, "L": 24}

var size_class: = "M":
	set(v):
		size_class = v if v in ["S", "M", "L"] else "M"
		_relayout()
var plate_w: = 328:
	set(v):
		plate_w = snap_width_to_module(size_class, v) if snap_width else int(v)
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

var value_max_w: = 0.0   # >0: overrides the per-size value column width (TWCurrencyChip)

var _title_l: Label
var _sub_l: Label
var _val_l: Label
var _icon_v: Control
var _down: = false
var _flash: = -1.0
var _phase: = 0
var _t: = 0.0
var _from: = 1.0
var _flash_t: = -1.0


static func height_of(sc: String) -> int:
	return int(TWTokens.PLATE_H.get(sc, 80))


static func snap_width_to_module(sc: String, w: float) -> int:
	var mods: Array = WIDTHS[sc]
	var best: int = mods[0]
	for m in mods:
		if absf(m - w) < absf(best - w):
			best = m
	return best


static func make(sc: String, w: int, t: = "", sub: = "", val: = "", icon_name: = "") -> TWPlate:
	var p: = TWPlate.new()
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
		l.label_settings = TWDraw.settings("ui", TWTokens.TYPE_CAPTION, TWTokens.PAPER_100)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(l)
	_val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_to_group(TWSkin.GROUP)


func _ready() -> void:
	_relayout()
	set_process(false)


func _skin_changed() -> void:
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
	# S is 48 tall but taps on a 96-high band
	var pad: = maxf(0.0, (float(TWTokens.HIT_TARGET_MIN) - plate_h()) * 0.5)
	return Rect2(Vector2(0, -pad), Vector2(size.x, size.y + pad * 2.0)).has_point(p)


func _relayout() -> void:
	if not is_instance_valid(_title_l):
		return
	update_minimum_size()
	var w: = float(plate_w)
	var h: = float(plate_h())
	var pad: = float(PAD[size_class])
	var x: = pad
	var key: = icon + str(icon_tex) + size_class
	if _icon_v and (_icon_v.get_meta("for", "") != key):
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
			_icon_v = V10Icons.icon(icon, isz, TWSkin.c("PAPER_500"))
		_icon_v.set_meta("for", key)
		add_child(_icon_v)
	if _icon_v:
		_icon_v.size = Vector2(isz, isz)
		_icon_v.position = Vector2(x, (h - isz) * 0.5)
		if _icon_v is V10Icons.View:
			(_icon_v as V10Icons.View).set_color(TWSkin.c("GOLD_300") if selected else TWSkin.c("PAPER_500"))
		x += isz + (8 if size_class == "S" else 16)
	var right: = w - pad
	if right_slot:
		var rs: = right_slot.get_combined_minimum_size()
		rs.x = minf(rs.x, 160.0 if size_class != "S" else 96.0)
		rs.y = minf(rs.y, h)
		right_slot.size = rs
		right_slot.position = Vector2(right - rs.x, (h - rs.y) * 0.5)
		right -= rs.x + 16
	var a: = 0.5 if disabled else 1.0
	var tcol: = Color(TWSkin.c("GOLD_300") if selected else TWSkin.c("PAPER_100"), a)
	_val_l.visible = value != ""
	if value != "":
		var vmax: = 120.0 if size_class == "L" else (96.0 if size_class == "M" else 72.0)
		if value_max_w > 0.0:
			vmax = value_max_w
		var vsizes: Array = [TWTokens.TYPE_H2, TWTokens.TYPE_BODY, TWTokens.TYPE_CAPTION] if size_class != "S" else [TWTokens.TYPE_CAPTION]
		var vs: = TWDraw.fit(_val_l, value, "num", vsizes, vmax, Color(TWSkin.c("GOLD_300"), a))
		var vw: = minf(vmax, TWDraw.text_w(value, "num", vs))
		var vh: = TWDraw.label_h(_val_l, "num", vs)
		_val_l.size = Vector2(vw + 2, vh)
		_val_l.position = Vector2(right - vw - 2, (h - vh) * 0.5)
		right -= vw + 16
	var tw: = maxf(8.0, right - x)
	var cap_h: = 0.0
	match size_class:
		"S":
			_sub_l.visible = false
			TWDraw.fit(_title_l, title, "ui", [TWTokens.TYPE_CAPTION], tw, tcol)
			_title_l.position = Vector2(x, 0)
			_title_l.size = Vector2(tw, h)
		"M":
			_sub_l.visible = subtitle != ""
			var ts: = TWDraw.fit(_title_l, title, "ui", [TWTokens.TYPE_BODY, TWTokens.TYPE_CAPTION], tw, tcol)
			if subtitle != "":
				var ss: = TWDraw.fit(_sub_l, subtitle, "ui", [TWTokens.TYPE_CAPTION], tw, Color(TWSkin.c("PAPER_300"), a))
				cap_h = TWDraw.label_h(_sub_l, "ui", ss)
				var th: = TWDraw.label_h(_title_l, "ui", ts)
				var top: = (h - th - cap_h) * 0.5
				_title_l.position = Vector2(x, top)
				_title_l.size = Vector2(tw, th)
				_sub_l.position = Vector2(x, top + th)
				_sub_l.size = Vector2(tw, cap_h)
			else:
				_title_l.position = Vector2(x, 0)
				_title_l.size = Vector2(tw, h)
		"L":
			_sub_l.visible = subtitle != ""
			var ls: = TWDraw.fit(_title_l, title, "display", [TWTokens.TYPE_H2, TWTokens.TYPE_BODY, TWTokens.TYPE_CAPTION], tw, tcol)
			var lh: = TWDraw.label_h(_title_l, "display", ls)
			var sub_h: = 0.0
			if subtitle != "":
				var ss2: = TWDraw.fit(_sub_l, subtitle, "ui", [TWTokens.TYPE_BODY, TWTokens.TYPE_CAPTION], tw, Color(TWSkin.c("PAPER_300"), a), false, 2)
				sub_h = TWDraw.label_h(_sub_l, "ui", ss2, 2)
			var top_l: = (h - lh - sub_h) * 0.5
			_title_l.position = Vector2(x, top_l)
			_title_l.size = Vector2(tw, lh)
			if subtitle != "":
				_sub_l.position = Vector2(x, top_l + lh)
				_sub_l.size = Vector2(tw, sub_h)
				_sub_l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	queue_redraw()


func ping() -> void:
	# "plate changed" feedback: one light dot runs along the hairline in 360 ms (skipped at fx_level min)
	if TWDraw.fx_level() == "min":
		return
	_flash_t = 0.0
	_flash = 0.0
	set_process(true)
	queue_redraw()


func advance(dt: float) -> void:
	if _phase == 1:
		_t += dt
		scale = Vector2.ONE * TWButton.down_scale(_t)
		if _t >= TWButton.T_DOWN:
			_phase = 3
	elif _phase == 2:
		_t += dt
		scale = Vector2.ONE * TWButton.up_scale(_from, _t)
		if _t >= TWButton.T_UP:
			scale = Vector2.ONE
			_phase = 0
	if _flash_t >= 0.0:
		_flash_t += dt
		_flash = sin(clampf(_flash_t / 0.36, 0.0, 1.0) * PI * 0.5)
		if _flash_t >= 0.36:
			_flash_t = -1.0
			_flash = -1.0
		queue_redraw()
	if _phase == 0 or _phase == 3:
		if _flash_t < 0.0:
			set_process(false)


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	TWDraw.plate_surface(self, Rect2(Vector2.ZERO, Vector2(plate_w, plate_h())), on_art, _down, selected, disabled, focused, _flash)


func _gui_input(e: InputEvent) -> void:
	if not interactive:
		return
	if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
		if disabled:
			if e.pressed:
				TWDraw.feedback(self, true)
			accept_event()
			return
		if e.pressed:
			_down = true
			pivot_offset = size * 0.5
			_phase = 1
			_t = 0.0
			queue_redraw()
			set_process(true)
		elif _down:
			_down = false
			_phase = 2
			_t = 0.0
			_from = scale.x
			queue_redraw()
			set_process(true)
			if Rect2(Vector2.ZERO, size).grow(16).has_point(e.position):
				TWDraw.feedback(self, false)
				pressed.emit()
		accept_event()
