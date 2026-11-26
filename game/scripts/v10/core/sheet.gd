class_name V10BottomSheet
extends Control

# V10BottomSheet — the ONE v2 bottom sheet of the W1 shell (HUD_V2 §2.1 «лист night.700», UX §3.7 «1 лист»):
# a dim over the screen, a night.700 sheet from the bottom with one hairline, H1 Display 32 on the left margin,
# a quiet «×» on the right. Body rows are placed by the caller in a 656-wide column. It never opens over another
# sheet or popup (П-6): open() closes what is up first. Android «назад» closes it (meta "popup" + "v8_back").
#
#   var sh := V10BottomSheet.open(main, "Сегодня"); sh.add_body(ctrl, y); sh.finish(body_h); sh.close()

const PAD_TOP: = 104.0  # title band
const PAD_BOTTOM: = 32.0

var main
var panel: Control
var body: Control
var title_l: Label
var close_b: V10Button
var _closing: = false
var _opened_ms: = 0


static func open(m, title: String) -> V10BottomSheet:
	for p in m.overlay.get_children():
		if p.has_meta("popup") or p.has_meta("v10_sheet"):
			p.queue_free()
	var s: = V10BottomSheet.new()
	s.main = m
	s.name = "V10BottomSheet"
	s.set_meta("popup", true)
	s.set_meta("v10_sheet", true)
	s.set_meta("v8_back", s.close)
	var vs: Vector2 = m.get_viewport_rect().size
	s.size = vs
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	m.overlay.add_child(s)
	s._build(vs, title)
	return s


func _build(vs: Vector2, title: String) -> void:
	_opened_ms = Time.get_ticks_msec()
	var dim: = ColorRect.new()
	dim.size = vs
	dim.color = Color(V10DS.NIGHT_900, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.6, V10DS.T_IN)
	panel = _Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var cx: = floorf(maxf(0.0, (vs.x - 720.0) * 0.5))
	title_l = V10Type.label(title, "display", 32, V10DS.PAPER_100)
	title_l.position = Vector2(cx + 32, 28)
	title_l.size = Vector2(560, 48)
	panel.add_child(title_l)
	close_b = V10Button.make("quiet", "", Vector2(80, 80))
	close_b.icon = "close"
	close_b.icon_color = V10DS.PAPER_300
	close_b.name = "Close"
	close_b.set_meta("ux_role", "tertiary")
	close_b.position = Vector2(cx + 624, 12)
	close_b.pressed.connect(close)
	panel.add_child(close_b)
	body = Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.position = Vector2(cx + 32, PAD_TOP)
	panel.add_child(body)


func add_body(c: Control, y: float, centre: = false) -> void:
	body.add_child(c)
	var w: = c.get_combined_minimum_size().x if c.get_combined_minimum_size().x > 0.0 else c.size.x
	c.position = Vector2((656.0 - w) * 0.5 if centre else 0.0, y)


func finish(body_h: float) -> void:
	var vs: = size
	var B: = float(main.safe_bottom) if "safe_bottom" in main else 0.0
	var h: = minf(vs.y * 0.86, PAD_TOP + body_h + PAD_BOTTOM + B)
	panel.size = Vector2(vs.x, h)
	panel.position = Vector2(0, vs.y)
	body.size = Vector2(656, body_h)
	var t: = panel.create_tween()
	t.tween_property(panel, "position:y", vs.y - h, V10DS.T_ROLL).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _gui_input(e: InputEvent) -> void:
	# a tap on the dim above the sheet closes it (ignore touch+emulated mouse right after open)
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		if Time.get_ticks_msec() - _opened_ms < 280:
			accept_event()
			return
		if panel and e.position.y < panel.position.y:
			close()
			accept_event()


func close() -> void:
	if _closing or not is_inside_tree():
		return
	_closing = true
	set_meta("closing", true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: = create_tween()
	t.tween_property(panel, "position:y", size.y, V10DS.T_OUT)
	t.parallel().tween_property(self, "modulate:a", 0.0, V10DS.T_OUT)
	t.tween_callback(queue_free)


class _Panel:
	extends Control

	func _draw() -> void:
		V10Plate.draw_surface(self, Rect2(Vector2.ZERO, size + Vector2(0, 8)), false, false, false, false, false, -1.0, V10DS.NIGHT_700)
