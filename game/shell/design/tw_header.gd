class_name TWHeader
extends Control

# TWHeader (P28 / WP9b): ONE header bar for sub-screens. HEIGHT 104 (+ top safe inset): «‹» quiet button 96 on the left margin, H1 title,
# on the right «?» quiet or one S plate / TWCurrencyChip. Background: night.900 α 0.85 -> 0. The content column is 720 wide and centred
# on wider screens; nothing leaves the safe area.
#   var h := TWHeader.make(screen, "Режимы", main.back, _help)   # content starts at TWHeader.content_y(vs)
#   TWHeader.compute(vs, insets) -> {bar, back, help, title_x, title_right, plate_y, cx, cw}   (pure, used by the selftest)

const HEIGHT: = 104.0
const BTN: = 96.0

var back_btn: TWButton
var help_btn: TWButton
var title_lbl: Label
var viewport_override: = Vector2.ZERO    # tests: lay out for this viewport instead of the real one
var right_plate: TWPlate = null:
	set(v):
		if right_plate:
			right_plate.queue_free()
		right_plate = v
		if v:
			add_child(v)
			_layout()


static func content_y(vs: Vector2, insets: Dictionary = {}) -> float:
	var ins: Dictionary = insets if not insets.is_empty() else TWDraw.safe_insets(vs)
	return float(ins.top) + HEIGHT + float(TWTokens.S1)


static func compute(vs: Vector2, insets: Dictionary, has_back: = true, has_help: = true, plate_w: = 0) -> Dictionary:
	var T: = float(insets.top)
	var cw: = minf(vs.x, float(TWTokens.BASE_WIDTH))
	var cx: = floorf(maxf(0.0, (vs.x - cw) * 0.5))
	var back: = Rect2(cx + float(TWTokens.S1), T + 4.0, BTN, BTN)
	var help: = Rect2(cx + cw - float(TWTokens.S1) - BTN, T + 4.0, BTN, BTN)
	var x: = cx + float(TWTokens.SAFE_MARGIN)
	if has_back:
		x = back.end.x + float(TWTokens.S1)
	var right: = cx + cw - float(TWTokens.SAFE_MARGIN)
	var plate: = Rect2()
	if has_help:
		right = help.position.x
	elif plate_w > 0:
		plate = Rect2(cx + cw - float(TWTokens.SAFE_MARGIN) - plate_w, T + (HEIGHT - float(TWTokens.PLATE_H.S)) * 0.5, plate_w, TWTokens.PLATE_H.S)
		right = plate.position.x - float(TWTokens.GUTTER)
	return {"bar": Rect2(0, 0, vs.x, T + HEIGHT), "back": back if has_back else Rect2(), "help": help if has_help else Rect2(),
			"plate": plate, "title_x": x, "title_right": right, "cx": cx, "cw": cw}


static func make(screen: Control, title: String, on_back: Callable, on_help: = Callable()) -> TWHeader:
	var h: = TWHeader.new()
	h.name = "TWHeader"
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_preset(Control.PRESET_TOP_WIDE)
	if on_back.is_valid():
		h.back_btn = TWButton.make("quiet", "", Vector2(BTN, BTN))
		h.back_btn.icon = "back"
		h.back_btn.icon_color = TWTokens.PAPER_300
		h.back_btn.pressed.connect(on_back)
		h.add_child(h.back_btn)
		screen.set_meta("v8_back", on_back)  # the meta the legacy Android back handler reads
	if on_help.is_valid():
		h.help_btn = TWButton.make("quiet", "", Vector2(BTN, BTN))
		h.help_btn.icon = "help"
		h.help_btn.icon_color = TWTokens.PAPER_300
		h.help_btn.pressed.connect(on_help)
		h.add_child(h.help_btn)
	h.title_lbl = TWDraw.label(title, "display", TWTokens.TYPE_H1, TWTokens.PAPER_100)
	h.add_child(h.title_lbl)
	screen.add_child(h)
	h.get_viewport().size_changed.connect(h._layout)
	h._layout()
	return h


func set_title(t: String) -> void:
	title_lbl.text = t
	_layout()


func _layout() -> void:
	var vs: = viewport_override if viewport_override != Vector2.ZERO else (get_viewport_rect().size if is_inside_tree() else Vector2(TWTokens.BASE_WIDTH, 1280))
	var ins: = TWDraw.safe_insets(vs)
	var g: = compute(vs, ins, back_btn != null, help_btn != null, right_plate.plate_w if right_plate else 0)
	position = Vector2.ZERO
	size = (g.bar as Rect2).size
	if back_btn:
		back_btn.position = (g.back as Rect2).position
	if help_btn:
		help_btn.position = (g.help as Rect2).position
	if right_plate:
		right_plate.position = (g.plate as Rect2).position
	var x: float = g.title_x
	var rw: float = float(g.title_right) - x
	var lh: = TWDraw.label_h(title_lbl, "display", TWTokens.TYPE_H1)
	title_lbl.position = Vector2(x, float(ins.top) + (HEIGHT - lh) * 0.5)
	title_lbl.size = Vector2(rw, lh)
	TWDraw.fit(title_lbl, title_lbl.text, "display", [TWTokens.TYPE_H1, TWTokens.TYPE_H2], rw, TWSkin.c("PAPER_100"))
	queue_redraw()


func _draw() -> void:
	var c0: = Color(TWSkin.c("NIGHT_900"), 0.85)
	var c1: = Color(TWSkin.c("NIGHT_900"), 0.0)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y + 16.0), Vector2(0, size.y + 16.0)]),
			PackedColorArray([c0, c0, c1, c1]))
