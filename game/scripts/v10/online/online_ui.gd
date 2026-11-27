class_name V10OnlineUi
extends RefCounted

# V10OnlineUi — shared imperial plum-and-gold lacquer kit of the 0.12.0 online screens (account, PvP).
# Text 20–28 px, everything placed in absolute rects of the 720 px column (no containers → no overlaps by surprise).

const PLUM: = Color(0.10, 0.04, 0.14, 0.94)
const PLUM_HI: = Color(0.20, 0.08, 0.26, 0.96)
const PLUM_LO: = Color(0.06, 0.02, 0.09, 0.92)
const GOLD: = Color("#E8C47E")
const GOLD_HI: = Color("#FFE6A8")
const CREAM: = Color("#F6E7CC")
const MUTED: = Color("#C9B49A")
const INK: = Color(0.07, 0.02, 0.10)
const GREEN: = Color("#7FE3A0")
const RED: = Color("#FF7A7A")
const BRAND: = {
	"yandex": {"bg": Color("#FC3F1D"), "fg": Color.WHITE, "mark": "Я"},
	"google": {"bg": Color("#FFFFFF"), "fg": Color("#1F1F1F"), "mark": "G"},
	"vk": {"bg": Color("#0077FF"), "fg": Color.WHITE, "mark": "VK"},
	"telegram": {"bg": Color("#2AABEE"), "fg": Color.WHITE, "mark": "✈"},
}


static func panel(r: Rect2, bg: = PLUM, border: = GOLD, rad: = 18, bw: = 2) -> Panel:
	var p: = Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(rad)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func label(txt: String, r: Rect2, px: = 22, col: = CREAM, align: = HORIZONTAL_ALIGNMENT_LEFT, weight: = 800) -> Label:
	var l: = UI.label(txt, px, col, INK, 4, "body", weight)
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func set_text(l: Label, txt: String) -> void:
	if l != null and is_instance_valid(l):
		l.text = txt


# a wrapped paragraph that keeps its rect (autowrap before sizing, so it never grows to the text width)
static func para(txt: String, r: Rect2, px: = 22, col: = CREAM, align: = HORIZONTAL_ALIGNMENT_LEFT, lines: = 2) -> Label:
	var l: = UI.label(txt, px, col, INK, 4, "body", 800)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = lines
	l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(r.size.x, 0)
	l.position = r.position
	l.size = r.size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# a tappable lacquer pill: returns the Panel (meta "label" -> its Label). cb() runs on press.
static func button(txt: String, r: Rect2, cb: Callable, bg: = PLUM_HI, fg: = GOLD_HI, px: = 24, border: = GOLD) -> Panel:
	var p: = panel(r, bg, border, int(minf(r.size.y * 0.5, 26.0)), 2)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var l: = label(txt, Rect2(Vector2(10, 0), r.size - Vector2(20, 0)), px, fg, HORIZONTAL_ALIGNMENT_CENTER, 900)
	p.add_child(l)
	p.set_meta("label", l)
	p.gui_input.connect(func(e: InputEvent) -> void:
		var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
		if tap:
			p.accept_event()
			if p.has_meta("disabled") and bool(p.get_meta("disabled")):
				return
			var tw: = p.create_tween()
			p.pivot_offset = p.size * 0.5
			tw.tween_property(p, "scale", Vector2(0.95, 0.95), 0.06)
			tw.tween_property(p, "scale", Vector2.ONE, 0.10)
			Sfx.play("tap", 1.0, -6)
			cb.call())
	return p


static func button_text(b: Panel, txt: String) -> void:
	if b != null and is_instance_valid(b) and b.has_meta("label"):
		(b.get_meta("label") as Label).text = txt


static func line_edit(r: Rect2, placeholder: String, txt: = "", secret: = false, px: = 22) -> LineEdit:
	var e: = LineEdit.new()
	e.position = r.position
	e.size = r.size
	e.placeholder_text = placeholder
	e.text = txt
	e.secret = secret
	e.add_theme_font_override("font", UI.font("body", 800))
	e.add_theme_font_size_override("font_size", px)
	e.add_theme_color_override("font_color", CREAM)
	e.add_theme_color_override("font_placeholder_color", Color(MUTED, 0.7))
	e.add_theme_color_override("caret_color", GOLD_HI)
	for st in ["normal", "focus", "read_only"]:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = PLUM_LO
		sb.border_color = GOLD if st == "focus" else Color(GOLD, 0.55)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		e.add_theme_stylebox_override(st, sb)
	return e


static func bar(r: Rect2, frac: float, col: Color) -> Panel:
	var back: = panel(r, PLUM_LO, Color(GOLD, 0.6), int(r.size.y * 0.5), 2)
	var fill: = Panel.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	fill.add_theme_stylebox_override("panel", sb)
	fill.position = Vector2(3, 3)
	fill.size = Vector2(maxf(r.size.y - 6.0, (r.size.x - 6.0) * clampf(frac, 0.0, 1.0)), r.size.y - 6.0)
	back.add_child(fill)
	return back


static func set_bar(b: Panel, frac: float) -> void:
	if b == null or not is_instance_valid(b) or not b.has_node("Fill"):
		return
	var fill: Panel = b.get_node("Fill")
	var w: = maxf(b.size.y - 6.0, (b.size.x - 6.0) * clampf(frac, 0.0, 1.0))
	fill.create_tween().tween_property(fill, "size:x", w, 0.25)


static func backdrop(host: Control, bg: String, W: float, H: float) -> void:
	var name_ok: = ResourceLoader.exists("res://assets/bg/%s.webp" % bg)
	Common.backdrop(host, bg if name_ok else "bg_palace", Vector2(W, H), 1.0, 0.75)
	var br: = V10Layout.bleed_rect(host)
	var shade: = ColorRect.new()
	shade.color = Color(0.09, 0.03, 0.12, 0.62)
	shade.position = br.position
	shade.size = br.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(shade)


static func status_chip(r: Rect2, is_online: bool) -> Panel:
	var col: = GREEN if is_online else Color("#F2B36B")
	var p: = panel(r, PLUM_LO, Color(col, 0.8), int(r.size.y * 0.5), 2)
	p.name = "StatusChip"
	var dot: = Panel.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(7)
	dot.add_theme_stylebox_override("panel", sb)
	dot.position = Vector2(14, r.size.y * 0.5 - 7)
	dot.size = Vector2(14, 14)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(dot)
	var l: = label("Онлайн · SQLite" if is_online else "Офлайн-режим", Rect2(34, 0, r.size.x - 42, r.size.y), 20, col, HORIZONTAL_ALIGNMENT_LEFT, 900)
	l.name = "Text"
	p.add_child(l)
	return p


static func set_status(chip: Panel, is_online: bool) -> void:
	if chip == null or not is_instance_valid(chip):
		return
	var col: = GREEN if is_online else Color("#F2B36B")
	var l: Label = chip.get_node("Text")
	l.text = "Онлайн · SQLite" if is_online else "Офлайн-режим"
	l.label_settings = l.label_settings.duplicate()
	l.label_settings.font_color = col
	var sb: StyleBoxFlat = (chip.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	sb.border_color = Color(col, 0.8)
	chip.add_theme_stylebox_override("panel", sb)
	var dot: Panel = chip.get_child(0)
	var dsb: StyleBoxFlat = (dot.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	dsb.bg_color = col
	dot.add_theme_stylebox_override("panel", dsb)


static func toast(host: Control, txt: String, W: float, y: float, col: = GOLD_HI) -> void:
	var p: = panel(Rect2(40, y, W - 80, 64), Color(0.08, 0.03, 0.11, 0.97), GOLD, 22, 2)
	p.z_index = 300
	p.add_child(label(txt, Rect2(16, 0, W - 112, 64), 22, col, HORIZONTAL_ALIGNMENT_CENTER, 900))
	host.add_child(p)
	p.modulate.a = 0.0
	var tw: = p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_interval(1.9)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)
