class_name V10ShopW
extends RefCounted

# V10ShopW — the small controls of Лавка 2. All taps: 0.94 dip + spring (UX §6.7 «Касание») and V10ShopKit.press.
#
#   Cash      «Касса» (UX §6.5): night.700, 1.5 px gold.500 border; left «что получу» (optional), right price in
#             Numerals; states: normal / down / loading (spinner, taps ignored) / disabled. Never rose.
#   Chip      crystal/petal price: painted icon 32 + Numerals 22 on night.700, no gold border (not money).
#   Tap       any tappable rect (cards, rows, links); emits pressed; ux_role meta for the budget selftest;
#             hit zone = visible rect grown to ≥ 80 px high (UX §6.1, HUD_V2 §2.1: visible 56–64, hit 80)
#   Panel     a lacquer surface (V10Plate.draw_surface) of any size, optional art inset and «скос 12» corner
#   Seg       segmented control: S plates 48 high, selected = gold.500 line under the text (2 px)
#   Dots      carousel dots (no autoplay)
#   Spin      a 2.5 px arc spinner

class Tap:
	extends Control
	signal pressed
	const HIT_MIN: = 80.0
	var enabled: = true
	var _down: = false
	var dip: = true
	var strong: = false
	var hit_pad: = -1.0      # extra px above and below; -1 = auto (grow to HIT_MIN), 0 = exactly the visible rect

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_meta("v10_tap", true)

	func pad_y() -> float:
		return hit_pad if hit_pad >= 0.0 else maxf(0.0, (HIT_MIN - size.y) * 0.5)

	# the touch rect (local): never smaller than 80 px high, the visible plate keeps its 56–64
	func hit_rect() -> Rect2:
		var p: = pad_y()
		return Rect2(Vector2(0, -p), size + Vector2(0, p * 2.0))

	func _has_point(pt: Vector2) -> bool:
		return hit_rect().has_point(pt)

	func _gui_input(e: InputEvent) -> void:
		if not ((e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch):
			return
		if e.pressed:
			_down = true
			pivot_offset = size * 0.5
			if dip and enabled:
				var tw: = create_tween()
				tw.tween_property(self, "scale", Vector2.ONE * 0.94, 0.06)
			queue_redraw()
		elif _down:
			_down = false
			if dip:
				var tw2: = create_tween()
				tw2.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			queue_redraw()
			if hit_rect().grow(16).has_point(e.position):
				if enabled:
					V10ShopKit.press(self, strong)
					pressed.emit()
				else:
					V10ShopKit.deny(self)
		accept_event()

	func fire() -> void:   # selftests / demo scripts
		if enabled:
			pressed.emit()


class Cash:
	extends Tap
	var price: = ""
	var what: = ""
	var loading: = false:
		set(v):
			loading = v
			set_process(v)
			queue_redraw()
	var _t: = 0.0
	var _pl: Label
	var _wl: Label

	func _init() -> void:
		super._init()
		set_meta("v10_cash", true)
		set_meta("ux_role", "cash")
		_pl = V10ShopKit.lbl("", "num", 28, V10DS.PAPER_100)
		_wl = V10ShopKit.lbl("", "ui", 22, V10DS.PAPER_300)
		add_child(_pl)
		add_child(_wl)
		set_process(false)

	func setup(p: String, w: = "", sz: = Vector2(200, 64)) -> Cash:
		price = p
		what = w
		size = sz
		custom_minimum_size = sz
		_lay()
		return self

	func _lay() -> void:
		_pl.text = price
		_wl.text = what
		_wl.visible = what != ""
		var ps: = 28 if size.y >= 64 else 22
		_pl.label_settings = V10Type.settings("num", ps, V10DS.PAPER_100 if enabled else V10DS.PAPER_700)
		if what != "":
			var pw: = V10Type.text_w(price, "num", ps) + 8.0
			_wl.position = Vector2(20, 0)
			_wl.size = Vector2(maxf(0.0, size.x - pw - 52.0), size.y)
			_pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_pl.position = Vector2(size.x - 20 - pw, 0)
			_pl.size = Vector2(pw, size.y)
		else:
			_pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_pl.position = Vector2(8, 0)
			_pl.size = Vector2(size.x - 16, size.y)

	func _notification(w: int) -> void:
		if w == NOTIFICATION_RESIZED and is_instance_valid(_pl):
			_lay()

	func _gui_input(e: InputEvent) -> void:
		if loading:
			accept_event()
			return
		super._gui_input(e)

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = V10DS.NIGHT_600 if _down else V10DS.NIGHT_700
		sb.set_corner_radius_all(V10DS.RADIUS)
		sb.set_border_width_all(2)
		sb.border_color = V10DS.GOLD_500 if enabled else Color(V10DS.GOLD_700, 0.35)
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		_pl.visible = not loading
		_wl.visible = what != "" and not loading
		if loading:
			var c: = size * 0.5
			draw_arc(c, 14, _t * 6.0, _t * 6.0 + PI * 1.4, 24, V10DS.GOLD_300, 2.5, true)


class Chip:
	extends Tap
	var icon: Texture2D
	var text: = ""
	var _l: Label

	func setup(t: Texture2D, txt: String, sz: = Vector2(168, 56)) -> Chip:
		icon = t
		text = txt
		size = sz
		custom_minimum_size = sz
		_l = V10ShopKit.lbl(txt, "num", 22, V10DS.PAPER_100)
		_l.position = Vector2(52, 0)
		_l.size = Vector2(sz.x - 64, sz.y)
		add_child(_l)
		set_meta("ux_role", "secondary")
		return self

	func _draw() -> void:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = V10DS.NIGHT_600 if _down else V10DS.NIGHT_700
		sb.set_corner_radius_all(V10DS.RADIUS)
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if icon:
			var s: = 36.0
			var a: = icon.get_size()
			var k: = s / maxf(a.x, a.y)
			draw_texture_rect(icon, Rect2(Vector2(10, (size.y - a.y * k) * 0.5), a * k), false)


class Lac:
	extends Control
	var over_art: = true
	var fill: = Color.TRANSPARENT
	var bevel: = 0.0          # «скос 12» on the top-right corner (fishka-card language)
	var selected: = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		V10Plate.draw_surface(self, r, over_art, false, selected, false, false, -1.0, fill)
		if bevel > 0.0:
			draw_colored_polygon(PackedVector2Array([Vector2(size.x - bevel, 0), Vector2(size.x, 0), Vector2(size.x, bevel)]),
				V10DS.NIGHT_900)
			draw_line(Vector2(size.x - bevel, 0.5), Vector2(size.x - 0.5, bevel), Color(V10DS.GOLD_700, V10DS.HAIR_A), 1.0, true)


class Seg:
	extends Control
	signal changed(i: int)
	var items: Array = []
	var current: = 0
	var taps: Array = []
	var _ls: Array = []

	func setup(names: Array, sel: int, w: float) -> Seg:
		items = names
		current = sel
		size = Vector2(w, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cw: = w / float(names.size())
		for i in names.size():
			var t: = Tap.new()
			t.dip = false
			t.position = Vector2(i * cw, 0)
			t.size = Vector2(cw, 80)       # hit zone 80 (visible line 56)
			t.position.y = -12
			t.set_meta("ux_role", "segment")      # a segmented control is navigation (like the navbar), not an action
			var l: = V10ShopKit.lbl(String(names[i]), "ui", 22, V10DS.PAPER_100 if i == sel else V10DS.PAPER_500)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.position = Vector2(0, 12)
			l.size = Vector2(cw, 48)
			t.add_child(l)
			_ls.append(l)
			var idx: = i
			t.pressed.connect(func():
				if idx != current:
					V10Hud2Util.sfx("tab_switch")
					select(idx)
					changed.emit(idx))
			add_child(t)
			taps.append(t)
		return self

	func select(i: int) -> void:
		current = i
		for k in _ls.size():
			(_ls[k] as Label).label_settings = V10Type.settings("ui", 22, V10DS.PAPER_100 if k == i else V10DS.PAPER_500)
		queue_redraw()

	func _draw() -> void:
		var cw: = size.x / float(items.size())
		V10Plate.hairline(self, 0, size.x, size.y - 0.5, Color(V10DS.GOLD_700, V10DS.HAIR_A))
		draw_rect(Rect2(current * cw + 16, size.y - 2, cw - 32, 2), V10DS.GOLD_500)
		for i in range(1, items.size()):
			draw_line(Vector2(i * cw, 16), Vector2(i * cw, size.y - 16), Color(V10DS.GOLD_700, V10DS.HAIR_A), 1.0)


class Dots:
	extends Control
	var n: = 3
	var cur: = 0

	func _draw() -> void:
		var w: = (n - 1) * 20.0
		for i in n:
			var c: = Vector2(size.x * 0.5 - w * 0.5 + i * 20.0, size.y * 0.5)
			if i == cur:
				draw_circle(c, 4.0, V10DS.GOLD_500, true, -1.0, true)
			else:
				draw_circle(c, 3.5, Color(V10DS.PAPER_500, 0.6), false, 1.5, true)


class Pill:
	extends Control
	var text: = "S"
	var col: = V10DS.PAPER_300

	func setup(t: String, c: Color) -> Pill:
		text = t
		col = c
		size = Vector2(16 + V10Type.text_w(t, "overline", 15) + 16, 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l: = V10ShopKit.lbl(t, "overline", 15, V10DS.NIGHT_900)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = size
		add_child(l)
		return self

	func _draw() -> void:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(14)
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2.ZERO, size))


class Bar:
	extends Control
	var k: = 0.0

	func _draw() -> void:
		draw_rect(Rect2(0, size.y * 0.5 - 2, size.x, 4), V10DS.NIGHT_600)
		draw_rect(Rect2(0, size.y * 0.5 - 2, size.x * clampf(k, 0, 1), 4), V10DS.JADE_300)
