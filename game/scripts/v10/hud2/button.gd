class_name V10Button
extends Control

# V10Button — the four button classes of UX §6.5 in HUD v2 metrics (docs/HUD_V2.md §2.5).
#   "play"      pill rose.500, Display 32→26 night.900, 560x104 / 440x104, breathing 0.985↔1.0 per 3.2 s,
#               one sheen per 2.8 s (the screen's only one); overline (Overline 15 gold.500) ABOVE the pill
#   "cash"      night.700, 1.5 px gold.500 border (the only border in the HUD), Numerals 28 + «₽»
#   "secondary" no fill, UI 22 paper.100 + monoline arrow 24, height 80
#   "quiet"     icon only (48, or 32 inside the top bar) in an 80x80 hit zone
#
#   var b := V10Button.make("play", "Ещё уровень · 5", Vector2(560, 104)); b.overline = "ПУТЬ · ЧАЙНЫЙ САД"
#   var q := V10Button.make("quiet", "", Vector2(80, 80)); q.icon = "pause"; q.icon_px = 32

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
var breathing: = true
var sheen: = true
var btn_size: = Vector2(560, 104):
	set(v):
		btn_size = v
		_relayout()

var _l: Label
var _ov: Label
var _down: = false
var _t: = 0.0
var _sheen_x: = -1.0


static func make(k: String, t: String, sz: Vector2) -> V10Button:
	var b: = V10Button.new()
	b.kind = k
	b.btn_size = sz
	b.text = t
	if k != "play":
		b.breathing = false
		b.sheen = false
	return b


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_l = Label.new()
	_l.label_settings = V10Type.settings("ui", 22, V10DS.PAPER_100)
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
	set_process(kind == "play")


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
			V10Type.fit(_l, text, "button_play", btn_size.x - 64.0, 1, V10DS.NIGHT_900)
			_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_l.position = Vector2(32, 0)
			_l.size = Vector2(btn_size.x - 64.0, btn_size.y)
		"cash":
			_l.label_settings = V10Type.settings("num", 28, V10DS.PAPER_100)
			_l.text = text
			_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_l.position = Vector2(8, 0)
			_l.size = Vector2(btn_size.x - 16.0, btn_size.y)
		"secondary":
			V10Type.fit(_l, text, "button_ui", btn_size.x - 48.0, 1, V10DS.PAPER_100)
			var tw: = minf(btn_size.x - 48.0, V10Type.text_w(text, "ui", _l.label_settings.font_size))
			_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_l.size = Vector2(tw + 4.0, btn_size.y)
			_l.position = Vector2((btn_size.x - tw - 40.0) * 0.5, 0)
		_:
			_l.text = ""
	_ov.visible = overline != ""
	if overline != "":
		_ov.label_settings = V10Type.settings("overline", 15, V10DS.GOLD_500, true)
		_ov.text = overline.to_upper()
		_ov.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ov.position = Vector2(0, -26)
		_ov.size = Vector2(btn_size.x, 20)
	queue_redraw()


func _process(delta: float) -> void:
	if kind != "play":
		return
	_t += delta
	var fx: = V10Hud2Util.fx_level() != "min"
	if breathing and fx and not _down:
		var k: = 0.9925 + 0.0075 * cos(_t * TAU / 3.2)
		scale = Vector2.ONE * k
	if sheen and fx:
		var ph: = fmod(_t, 2.8)
		_sheen_x = ph / 0.36 if ph < 0.36 else -1.0
		queue_redraw()


func _draw() -> void:
	var r: = Rect2(Vector2.ZERO, btn_size)
	match kind:
		"play":
			var sb: = StyleBoxFlat.new()
			sb.bg_color = V10DS.ROSE_700 if _down else V10DS.ROSE_500
			sb.set_corner_radius_all(int(btn_size.y * 0.5))
			sb.anti_aliasing = true
			draw_style_box(sb, r)
			# lacquer tone on the top half — same language as the plates
			var lac: = Color(V10DS.PAPER_100, 0.10)
			var clr: = Color(V10DS.PAPER_100, 0.0)
			var rr: = btn_size.y * 0.5
			draw_polygon(PackedVector2Array([Vector2(rr * 0.6, 3), Vector2(btn_size.x - rr * 0.6, 3), Vector2(btn_size.x - rr * 0.3, btn_size.y * 0.45), Vector2(rr * 0.3, btn_size.y * 0.45)]),
					PackedColorArray([lac, lac, clr, clr]))
			if _sheen_x >= 0.0:  # one band 48 px at 20°, α 0.25
				var x: = lerpf(-60.0, btn_size.x + 60.0, ease(_sheen_x, -1.6))
				var sk: = tan(deg_to_rad(20.0)) * btn_size.y
				var c: = Color(V10DS.PAPER_100, 0.25)
				var c0: = Color(V10DS.PAPER_100, 0.0)
				var pts: = PackedVector2Array([Vector2(x, 0), Vector2(x + 24, 0), Vector2(x + 48, 0), Vector2(x + 48 - sk, btn_size.y), Vector2(x + 24 - sk, btn_size.y), Vector2(x - sk, btn_size.y)])
				# clip to the pill: draw only inside by intersecting with the rect (pill ends are rounded; band is faint)
				draw_polygon(PackedVector2Array([pts[0], pts[1], pts[4], pts[5]]), PackedColorArray([c0, c, c, c0]))
				draw_polygon(PackedVector2Array([pts[1], pts[2], pts[3], pts[4]]), PackedColorArray([c, c0, c0, c]))
		"cash":
			var sb2: = StyleBoxFlat.new()
			sb2.bg_color = V10DS.NIGHT_600 if _down else V10DS.NIGHT_700
			sb2.set_corner_radius_all(V10DS.RADIUS)
			sb2.set_border_width_all(2)  # 1.5 px at @1x base → 2 px after AA
			sb2.border_color = V10DS.GOLD_500
			sb2.anti_aliasing = true
			draw_style_box(sb2, r)
		"secondary":
			if text != "":
				var tw: = _l.size.x
				V10Icons.draw(self, "arrow_r", Vector2(_l.position.x + tw + 20.0, btn_size.y * 0.5), 24, V10DS.PAPER_100)
		"quiet":
			if _down:
				draw_circle(btn_size * 0.5, minf(btn_size.x, btn_size.y) * 0.42, Color(V10DS.NIGHT_600, 0.6), true, -1.0, true)
			if icon != "":
				V10Icons.draw(self, icon, btn_size * 0.5, icon_px, icon_color)


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
		if e.pressed:
			_down = true
			scale = Vector2.ONE * 0.94
			queue_redraw()
		elif _down:
			_down = false
			var tw: = create_tween()
			tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			queue_redraw()
			if Rect2(Vector2.ZERO, size).grow(16).has_point(e.position):
				pressed.emit()
		accept_event()
