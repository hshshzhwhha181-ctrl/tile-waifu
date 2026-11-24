class_name V10Header
extends Control

# V10Header — ONE header bar for sub-screens (docs/HUD_V2.md §8.6), replacing the double header
# (status ribbon from main.gd + V8Header plate). 88 px (+ top inset): «‹» quiet 48 · H1 Display 44 on the left
# margin · right: «?» quiet, or one S plate (e.g. the currency being spent: Numerals 22 + painted icon 32).
# No plate, no border, no nick/currency ribbon. Background: night.900 α 0.85 → 0, like the match top bar.
#
#   var h := V10Header.make(screen, "Режимы", main.back, _help)   # content starts at V10Header.content_y(vs)
#   h.set_title("…"); h.right_plate = V10Plate.make("S", 144, "1 980", "", "", "")

const HEIGHT: = 88.0

var back_btn: V10Button
var help_btn: V10Button
var title_lbl: Label
var right_plate: V10Plate = null:
	set(v):
		if right_plate:
			right_plate.queue_free()
		right_plate = v
		if v:
			add_child(v)
			_layout()


static func content_y(vs: Vector2) -> float:
	return float(V10Hud2Util.safe_insets(vs).top) + HEIGHT + 8.0


static func make(screen: Control, title: String, on_back: Callable, on_help: = Callable()) -> V10Header:
	var h: = V10Header.new()
	h.name = "V10Header"
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_preset(Control.PRESET_TOP_WIDE)
	if on_back.is_valid():
		h.back_btn = V10Button.make("quiet", "", Vector2(80, 80))
		h.back_btn.icon = "back"
		h.back_btn.icon_color = V10DS.PAPER_300
		h.back_btn.pressed.connect(on_back)
		h.add_child(h.back_btn)
		screen.set_meta("v8_back", on_back)  # same meta the Android back handler already reads
	if on_help.is_valid():
		h.help_btn = V10Button.make("quiet", "", Vector2(80, 80))
		h.help_btn.icon = "help"
		h.help_btn.icon_color = V10DS.PAPER_300
		h.help_btn.pressed.connect(on_help)
		h.add_child(h.help_btn)
	h.title_lbl = V10Type.label(title, "display", 44, V10DS.PAPER_100)
	h.add_child(h.title_lbl)
	screen.add_child(h)
	h.get_viewport().size_changed.connect(h._layout)
	h._layout()
	return h


func set_title(t: String) -> void:
	title_lbl.text = t
	_layout()


func _layout() -> void:
	var vs: = get_viewport_rect().size
	var T: = float(V10Hud2Util.safe_insets(vs).top)
	var cx: = floorf(maxf(0.0, (vs.x - 720.0) * 0.5))
	position = Vector2.ZERO
	size = Vector2(vs.x, T + HEIGHT)
	var x: = cx + 24.0
	if back_btn:
		back_btn.position = Vector2(cx + 8.0, T + 4.0)
		x = cx + 88.0
	var right: = cx + 696.0
	if help_btn:
		help_btn.position = Vector2(cx + 632.0, T + 4.0)
		right = cx + 632.0
	elif right_plate:
		right_plate.position = Vector2(cx + 696.0 - right_plate.plate_w, T + 20.0)
		right = right_plate.position.x - 16.0
	# Display 44, shrinks to 32 for long titles, then ellipsis — the bar never grows
	title_lbl.position = Vector2(x, T + 14.0)
	title_lbl.size = Vector2(right - x, 60)
	var s: = 44
	for k in [44, 32]:
		s = k
		if V10Type.text_w(title_lbl.text, "display", k) <= right - x:
			break
	title_lbl.label_settings = V10Type.settings("display", s, V10DS.PAPER_100)
	queue_redraw()


func _draw() -> void:
	var c0: = Color(V10DS.NIGHT_900, 0.85)
	var c1: = Color(V10DS.NIGHT_900, 0.0)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y + 16.0), Vector2(0, size.y + 16.0)]),
			PackedColorArray([c0, c0, c1, c1]))
