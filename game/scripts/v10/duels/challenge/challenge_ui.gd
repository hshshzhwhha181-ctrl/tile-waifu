class_name V10ChallengeUI
extends RefCounted

# «Вызов по коду»: the module's widgets in HUD v2 terms — V10Button classes with their ux_role meta and V9Feel.press
# on every tap, V10Type roles (Display · UI · Numerals), V10DS tokens only, and the one bottom sheet («Шёлк»
# 220 ms QUINT OUT; a 120 ms fade at fx «минимум»). A sheet never opens over another sheet (UX §3.7): opening one
# closes the one before.
#
#   btn(kind, text, size, on_press) -> V10Button          kind "play" (primary) | "secondary" | "quiet" (tertiary)
#   quiet(icon, on_press) -> V10Button                     80×80 hit zone
#   text(t, role, size, color, w := 0, lines := 1) -> Label
#   Stars.new(n, max, r)                                    painted level stars (V10Icons.draw_star)
#   Plate.new(fill, hair := true)                           night plate, radius 4, gold hairline α 0.35
#   Sheet.open(host, title, opts) -> Sheet                  .body (Control, 720 wide), .finish(h), .close(), closed
#   host_layer(node) -> Node                                main.overlay when there is one
#   caption(parent, text, color)                            one-line hint that fades in (errors, «скопировано»)

const U: = preload("res://scripts/v10/duels/challenge/challenge_util.gd")

const W: = 720.0
const M: = 24.0  # left / right margin of a 720 column
const ROLE_OF: = {"play": "primary", "secondary": "secondary", "quiet": "tertiary", "cash": "secondary"}
const SND_OF: = {"play": "pop", "secondary": "pop", "quiet": "pop"}


static func btn(kind: String, t: String, sz: Vector2, on_press: Callable) -> V10Button:
	var b: = V10Button.make(kind, t, sz)
	b.size = sz
	b.set_meta("ux_role", String(ROLE_OF.get(kind, "secondary")))
	b.name = "Btn_" + (t if t != "" else kind).validate_node_name().replace(" ", "_")
	b.pressed.connect(func():
		if b.has_meta("ch_off"):
			U.deny(b)
			return
		U.press(b, String(SND_OF.get(kind, "pop")))
		if on_press.is_valid():
			on_press.call())
	return b


static func quiet(icon: String, on_press: Callable, px: = 48) -> V10Button:
	var b: = btn("quiet", "", Vector2(80, 80), on_press)
	b.icon = icon
	b.icon_px = px
	b.icon_color = V10DS.PAPER_300
	b.name = "Quiet_" + icon
	return b


static func text(t: String, role: String, sz: int, color: Color, w: = 0.0, lines: = 1, on_art: = false) -> Label:
	var l: = V10Type.label(t, role, sz, color, on_art)
	if w > 0.0:
		l.size = Vector2(w, V10Type.line_h(sz) * lines)
		l.custom_minimum_size = Vector2(w, 0)
	if lines > 1:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = lines
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return l


# the column of a 720 layout on any screen width (tablets keep 720 in the middle, UX §2)
static func col_x(vs: Vector2) -> float:
	return floorf(maxf(0.0, (vs.x - W) * 0.5))


static func host_layer(node: Node) -> Node:
	if node == null:
		return null
	var m = node.get("main")
	if m == null and node.get("overlay") != null:
		m = node
	if m != null and m.get("overlay") != null and is_instance_valid(m.overlay):
		return m.overlay
	return node


# a hint line under a control: fades in, keeps its place (no toast stack); returns the label
static func caption(parent: Control, t: String, color: Color, at: Vector2, w: float) -> Label:
	var old: = parent.get_node_or_null("ChCaption")
	if old:
		old.free()
	var l: = text(t, "ui", 18, color, w, 2)
	l.name = "ChCaption"
	l.position = at
	parent.add_child(l)
	U.silk_in(l, Vector2(0, 6), 0.18)
	return l

# ---------------------------------------------------------------- painted pieces

class Stars:
	extends Control
	var n: = 0
	var of: = 3
	var r: = 16.0
	var gap: = 8.0

	func _init(lit: = 0, total: = 3, radius: = 16.0) -> void:
		n = lit
		of = total
		r = radius
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(of * r * 2.0 + (of - 1) * gap, r * 2.0)
		custom_minimum_size = size

	func _draw() -> void:
		for i in of:
			V10Icons.draw_star(self, Vector2(r + i * (r * 2.0 + gap), r), r, i < n)


class Plate:
	extends Control
	var fill: Color
	var hair: = true
	var accent: = Color(0, 0, 0, 0)  # optional 4 px left rule (a result colour)

	func _init(c: = V10DS.NIGHT_800, h: = true) -> void:
		fill = c
		hair = h
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = fill
		sb.set_corner_radius_all(V10DS.RADIUS)
		sb.anti_aliasing = true
		if hair:
			sb.set_border_width_all(1)
			sb.border_color = V10DS.hair()
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		# lacquer: paper α 0.05 on the top 40 %
		var lac: = Color(V10DS.PAPER_100, V10DS.LACQUER_A)
		var clr: = Color(V10DS.PAPER_100, 0.0)
		var h: = size.y * 0.4
		draw_polygon(PackedVector2Array([Vector2(2, 2), Vector2(size.x - 2, 2), Vector2(size.x - 2, h), Vector2(2, h)]),
			PackedColorArray([lac, lac, clr, clr]))
		if accent.a > 0.0:
			draw_rect(Rect2(0, 8, 4, size.y - 16), accent)


# a gold hairline that fades at both ends (HAIR_FADE)
class Hair:
	extends Control

	func _init(w: float) -> void:
		size = Vector2(w, 2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: = V10DS.hair()
		var c0: = Color(c, 0.0)
		var f: = float(V10DS.HAIR_FADE)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(f, 0), Vector2(f, 1), Vector2(0, 1)]), PackedColorArray([c0, c, c, c0]))
		draw_rect(Rect2(f, 0, size.x - 2.0 * f, 1), c)
		draw_polygon(PackedVector2Array([Vector2(size.x - f, 0), Vector2(size.x, 0), Vector2(size.x, 1), Vector2(size.x - f, 1)]), PackedColorArray([c, c0, c0, c]))

# ---------------------------------------------------------------- bottom sheet («Шёлк»)

class Sheet:
	extends Control
	signal closed

	static var current: Sheet = null

	var body: Control
	var panel: Plate
	var scrim: ColorRect
	var on_close: = Callable()
	var _h: = 0.0
	var _closing: = false
	var _cx: = 0.0

	static func open(host: Node, title: String, opts: = {}) -> Sheet:
		if current != null and is_instance_valid(current) and not current._closing:
			current.close(true)
		var layer: Node = V10ChallengeUI.host_layer(host)
		var s: = Sheet.new()
		s.name = "ChallengeSheet"
		s.z_index = int(opts.get("z", 60))
		s.set_meta("popup", true)
		layer.add_child(s)
		var vs: Vector2 = s.get_viewport().get_visible_rect().size
		if layer is Control:
			vs = (layer as Control).size if (layer as Control).size.x > 0 else vs
		s.position = Vector2.ZERO
		s.size = vs
		s.mouse_filter = Control.MOUSE_FILTER_STOP
		s._build(vs, title, opts)
		current = s
		return s

	func _build(vs: Vector2, title: String, opts: Dictionary) -> void:
		_cx = V10ChallengeUI.col_x(vs)
		scrim = ColorRect.new()
		scrim.color = Color(V10DS.NIGHT_900, 0.0)
		scrim.size = vs
		scrim.mouse_filter = Control.MOUSE_FILTER_STOP
		if bool(opts.get("tap_out", true)):
			scrim.gui_input.connect(func(e):
				if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
					close())
		add_child(scrim)
		scrim.create_tween().tween_property(scrim, "color:a", float(opts.get("dim", 0.62)), 0.2)
		panel = Plate.new(V10DS.NIGHT_800, false)
		panel.name = "SheetPanel"
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(panel)
		body = Control.new()
		body.name = "Body"
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.position = Vector2(_cx, 0)
		body.size = Vector2(V10ChallengeUI.W, 10)
		panel.add_child(body)
		# grab handle, the title on the left margin, a close icon on the right
		var grip: = ColorRect.new()
		grip.color = V10DS.NIGHT_600
		grip.size = Vector2(64, 5)
		grip.position = Vector2(V10ChallengeUI.W * 0.5 - 32, 12)
		grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(grip)
		if title != "":
			var tl: = V10ChallengeUI.text(title, "display", 32, V10DS.PAPER_100, V10ChallengeUI.W - 2 * V10ChallengeUI.M - 88)
			tl.name = "SheetTitle"
			tl.position = Vector2(V10ChallengeUI.M, 32)
			body.add_child(tl)
		if bool(opts.get("close_btn", true)):
			var x: = V10ChallengeUI.quiet("close", func(): close(), 32)
			x.position = Vector2(V10ChallengeUI.W - 8 - 80, 16)
			body.add_child(x)
		set_meta("v8_back", Callable(self, "close"))

	# call once the body is filled: h = the sheet height (content + bottom inset)
	func finish(h: float) -> void:
		var vs: = size
		var B: = float(V10Hud2Util.safe_insets(vs).bottom)
		_h = minf(h + B, vs.y - 40.0)
		panel.size = Vector2(vs.x, _h + 24.0)
		body.size.y = _h
		panel.queue_redraw()
		var y_to: = vs.y - _h
		if U.fx_min():
			panel.position = Vector2(0, y_to)
			panel.modulate.a = 0.0
			panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.12)
		else:
			panel.position = Vector2(0, vs.y)
			panel.create_tween().tween_property(panel, "position:y", y_to, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		U.sfx("page_turn")

	func top_y() -> float:
		return size.y - _h

	func close(instant: = false) -> void:
		if _closing:
			return
		_closing = true
		if current == self:
			current = null
		if on_close.is_valid():
			on_close.call()
		closed.emit()
		if instant or not is_inside_tree():
			queue_free()
			return
		var t: = create_tween()
		if U.fx_min():
			t.tween_property(self, "modulate:a", 0.0, 0.12)
		else:
			t.tween_property(panel, "position:y", size.y, 0.18).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(scrim, "color:a", 0.0, 0.18)
		t.tween_callback(queue_free)
