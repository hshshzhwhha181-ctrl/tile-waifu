class_name V10GUI
extends RefCounted

# V10GUI — small kit of the gacha lane in «Тишина и лак» (UX_RULES §6): tokens, three voices of type, lacquer
# sheets with a 1 px gold line, thin bars, rarity pills, the hanko seal, the cascade of reward chips.
# Everything tappable goes through JButton / V9Feel (press spring, sound, haptic).

const NIGHT_900: = Color("121014")
const NIGHT_800: = Color("1b171c")
const NIGHT_700: = Color("26212a")
const NIGHT_600: = Color("332c36")
const PAPER_100: = Color("f5ead8")
const PAPER_300: = Color("ddd2c4")
const PAPER_500: = Color("b3a89c")
const PAPER_700: = Color("7e756d")
const GOLD_300: = Color("f1d9a0")
const GOLD_500: = Color("e8c47e")
const GOLD_700: = Color("a87b3a")
const ROSE_300: = Color("ecc0c9")
const ROSE_500: = Color("d796a5")
const JADE_300: = Color("a9d9c4")
const JADE_500: = Color("5b9580")
const CINNABAR: = Color("c8463c")
const LAV: = Color("c9b6ff")             # Созвездие ✦
const RAR: = {"A": Color("6fdcae"), "S": Color("c99bff"), "SSR": Color("ffcf4a")}
const RAR_NAME: = {"A": "A", "S": "S", "SSR": "SSR"}


static func lbl(text: String, size: int, col: Color = PAPER_100, kind: = "body", weight: = 800, outline: = Color(0, 0, 0, 0), osz: = 0) -> Label:
	var l: = UI.label(text, size, col, outline, osz, kind, weight)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func overline(text: String, col: Color = GOLD_500) -> Label:
	var l: = lbl(text.to_upper(), 15, col, "body", 900)
	var ls: LabelSettings = l.label_settings
	ls = ls.duplicate() as LabelSettings
	l.label_settings = ls
	l.text = _track(text.to_upper())
	return l


# letter-spacing +14 % for overlines (Label has no tracking: thin spaces)
static func _track(s: String) -> String:
	var out: = ""
	for i in s.length():
		out += s[i]
		if i < s.length() - 1 and s[i] != " ":
			out += " "
	return out


static func h1(text: String, size: = 56, col: = PAPER_100) -> Label:
	return lbl(text, size, col, "title", 700, Color(0.05, 0.03, 0.05, 0.55), 6)


static func shadowed(l: Label, a: = 0.6) -> Label:
	var ls: LabelSettings = l.label_settings.duplicate() as LabelSettings
	ls.shadow_color = Color(0, 0, 0, a)
	ls.shadow_size = 8
	ls.shadow_offset = Vector2(0, 2)
	l.label_settings = ls
	return l


static func sheet(rect: Rect2, a: = 0.88, gold_line: = true) -> Control:
	var p: = Panel.new()
	p.position = rect.position
	p.size = rect.size
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(NIGHT_800, a)
	sb.set_corner_radius_all(4)
	if gold_line:
		sb.border_color = Color(GOLD_700, 0.35)
		sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func line_bar(rect: Rect2, frac: float, col: = GOLD_500) -> Control:
	var root: = Control.new()
	root.position = rect.position
	root.size = rect.size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg: = ColorRect.new()
	bg.size = rect.size
	bg.color = Color(PAPER_700, 0.35)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var fg: = ColorRect.new()
	fg.name = "Fill"
	fg.size = Vector2(rect.size.x * clampf(frac, 0.0, 1.0), rect.size.y)
	fg.color = col
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fg)
	return root


static func set_bar(bar: Control, frac: float, dur: = 0.35) -> void:
	if not is_instance_valid(bar):
		return
	var fg: ColorRect = bar.get_node("Fill")
	bar.create_tween().tween_property(fg, "size:x", bar.size.x * clampf(frac, 0.0, 1.0), dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


static func rar_pill(rar: String, h: = 30.0) -> Control:
	var col: Color = RAR.get(rar, RAR.A)
	var t: String = RAR_NAME.get(rar, rar)
	var f: = UI.font("body", 900)
	var fs: = int(h * 0.62)
	var w: = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + h * 0.9
	var p: = Panel.new()
	p.size = Vector2(w, h)
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(NIGHT_900, 0.82)
	sb.set_corner_radius_all(int(h * 0.5))
	sb.border_color = col
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: = lbl(t, fs, col.lerp(Color.WHITE, 0.25), "body", 900)
	UI.center_label(l, Rect2(0, -1, w, h))
	p.add_child(l)
	return p


static func icon(tex: Texture2D, r: Rect2) -> TextureRect:
	var t: = UI.tex(tex, r)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return t


# a horizontal gradient band (magazine cover shade: dark on the left / bottom, clear toward the heroine)
static func shade(rect: Rect2, from: Color, to: Color, vertical: = false) -> TextureRect:
	var gt: = GradientTexture2D.new()
	var g: = Gradient.new()
	g.set_color(0, from)
	g.set_color(1, to)
	gt.gradient = g
	gt.width = 4 if vertical else 128
	gt.height = 128 if vertical else 4
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1) if vertical else Vector2(1, 0)
	var t: = TextureRect.new()
	t.texture = gt
	t.position = rect.position
	t.size = rect.size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# full-bleed «cover» image: fills rect, cropped around focus
static func cover(tex: Texture2D, rect: Rect2, focus: = Vector2(0.5, 0.5)) -> Control:
	var clip: = Control.new()
	clip.position = rect.position
	clip.size = rect.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex == null:
		return clip
	var ts: = Vector2(tex.get_width(), tex.get_height())
	var k: = maxf(rect.size.x / ts.x, rect.size.y / ts.y)
	var sz: = ts * k
	var t: = TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.size = sz
	t.position = Vector2((rect.size.x - sz.x) * focus.x, (rect.size.y - sz.y) * focus.y)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.name = "Img"
	clip.add_child(t)
	return clip


static func tex_or_null(path: String) -> Texture2D:
	return load(path) if path != "" and ResourceLoader.exists(path) else null


# Печать-ханко (UX_RULES §6.8): drops in 140 ms, one squash frame, a dull «тук», the cinnabar bleeds in 300 ms
static func hanko(parent: Control, center: Vector2, text: String, sz: = 132.0, rot: = -9.0) -> Control:
	var s: = HankoSeal.new()
	s.text = text
	s.size = Vector2(sz, sz)
	s.pivot_offset = s.size * 0.5
	s.position = center - s.size * 0.5
	s.rotation = deg_to_rad(rot)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)
	s.scale = Vector2(2.2, 2.2)
	s.modulate.a = 0.0
	var t: = s.create_tween()
	t.tween_property(s, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(s, "modulate:a", 1.0, 0.1)
	t.tween_property(s, "scale", Vector2(1.08, 0.9), 0.034)
	t.tween_callback(func():
		Sfx.play("clack0", 0.62, -2.0)
		V9Feel.haptic("tap"))
	t.tween_property(s, "scale", Vector2.ONE, 0.08)
	t.parallel().tween_property(s, "ink", 1.0, 0.3)
	return s


class HankoSeal extends Control:
	var text: = ""
	var ink: = 0.35:
		set(v):
			ink = v
			queue_redraw()

	func _draw() -> void:
		var c: = Color(V10GUI.CINNABAR, 0.55 + 0.4 * ink)
		var r: = Rect2(Vector2(6, 6), size - Vector2(12, 12))
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = c
		sb.set_border_width_all(int(size.x * 0.055))
		sb.set_corner_radius_all(int(size.x * 0.14))
		draw_style_box(sb, r)
		var inner: = r.grow(-size.x * 0.09)
		draw_rect(inner, Color(c, 0.12 + 0.1 * ink))
		var f: = UI.font("title", 900)
		var lines: = text.split("\n")
		var fs: = int(size.x * (0.2 if lines.size() > 1 else 0.24))
		var maxw: = 0.0
		for ln in lines:
			maxw = maxf(maxw, f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		while fs > 10 and maxw > size.x * 0.66:
			fs -= 1
			maxw = 0.0
			for ln in lines:
				maxw = maxf(maxw, f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var lh: = f.get_height(fs)
		var y0: = size.y * 0.5 - lh * lines.size() * 0.5 + f.get_ascent(fs)
		for i in lines.size():
			var w: = f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2((size.x - w) * 0.5, y0 + i * lh), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


# reward chips cascade (UX_RULES §6.7): 80 ms apart, each one a pentatonic note up
const PENTA: = [1.0, 1.122, 1.26, 1.498, 1.682, 2.0, 2.245]
static func cascade(nodes: Array, delay: = 0.0) -> void:
	for i in nodes.size():
		var n: Control = nodes[i]
		n.modulate.a = 0.0
		var p0: = n.position
		n.position = p0 + Vector2(0, 12)
		var t: = n.create_tween()
		t.tween_interval(delay + i * 0.08)
		t.tween_callback(func(): Sfx.play("star0", PENTA[i % PENTA.size()], -8.0))
		t.tween_property(n, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(n, "position", p0, 0.24).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


# Segmented control (UX_RULES §6.2: the chosen segment is gold.300 with a gold.500 underline, the rest paper.500).
# Every segment is a hit zone ≥ 80 px high (§6.1); the whole row is ONE control for the screen budget.
static func segment(labels: Array, sel: int, rect: Rect2, on_pick: Callable, fs: = 22) -> Control:
	var root: = Control.new()
	root.position = rect.position
	root.size = Vector2(rect.size.x, maxf(80.0, rect.size.y))
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_meta("ux_role", "secondary")
	var n: = labels.size()
	var w: = rect.size.x / maxf(1.0, n)
	var f: = UI.font("body", 900)
	var line: = ColorRect.new()
	line.color = Color(GOLD_700, 0.35)
	line.position = Vector2(0, root.size.y - 1)
	line.size = Vector2(rect.size.x, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(line)
	for i in n:
		var on: = i == sel
		var b: = Control.new()
		b.position = Vector2(i * w, 0)
		b.size = Vector2(w, root.size.y)
		b.pivot_offset = b.size * 0.5
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		var l: = lbl(String(labels[i]), fs, GOLD_300 if on else PAPER_500, "body", 900 if on else 800)
		UI.center_label(l, Rect2(0, 0, w, root.size.y - 6))
		b.add_child(l)
		if on:
			var tw: = f.get_string_size(String(labels[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var u: = ColorRect.new()
			u.color = GOLD_500
			u.size = Vector2(tw, 2)
			u.position = Vector2((w - tw) * 0.5, root.size.y - 14)
			u.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(u)
		var idx: = i
		b.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and idx != sel:
				V9Feel.press(b, "tap", "button")
				on_pick.call(idx))
		root.add_child(b)
	return root


# Quiet icon (UX_RULES §6.5 «Тихая»): a glyph in an 80 × 80 hit zone, no plate, no rim.
static func quiet_icon(glyph: String, pos: Vector2, on_tap: Callable, role: = "tertiary") -> Control:
	var b: = Control.new()
	b.position = pos
	b.size = Vector2(80, 80)
	b.pivot_offset = b.size * 0.5
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.set_meta("ux_role", role)
	var l: = lbl(glyph, 34, PAPER_300, "body", 800)
	UI.center_label(l, Rect2(Vector2.ZERO, b.size))
	b.add_child(l)
	b.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			V9Feel.press(b, "tap", "button")
			on_tap.call())
	return b


# A text link in an 80 px hit zone (tertiary): «ⓘ Шансы», «Отмена» on sheets
static func link(text: String, pos: Vector2, on_tap: Callable, col: = GOLD_500, fs: = 20, role: = "tertiary") -> Control:
	var f: = UI.font("body", 800)
	var b: = Control.new()
	b.position = pos
	b.size = Vector2(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 24.0, 80.0)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.set_meta("ux_role", role)
	var l: = lbl(text, fs, col, "body", 800)
	l.position = Vector2(12, (80.0 - l.get_minimum_size().y) * 0.5)
	b.add_child(l)
	b.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			V9Feel.press(b, "tap", "button")
			on_tap.call())
	return b


# «Касса» (UX_RULES §6.5, §5.3.7): any spend of Лунный камень or ₽. night.700, a gold.500 line, what you get on
# the left, the spend on the right (Nunito 900, gold.300), never rose.500. It is a JButton (pressed, gate, press
# spring, deny) whose plate is drawn here. `extra` is a second, quieter spend line («+ 900 кристаллов»).
# Narrow rects (< 360 px) stack the two sides: what you get on top, the spend under it.
static func kassa_button(left_t: String, right_t: String, rect: Rect2, extra: = "") -> JButton:
	var b: = JButton.make("", "graphite", rect, null, 24, 4.0, false)
	b.box.visible = false
	var plate: = Panel.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = NIGHT_700
	sb.border_color = GOLD_500
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	plate.add_theme_stylebox_override("panel", sb)
	plate.size = rect.size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.name = "Kassa"
	b.add_child(plate)
	b.move_child(plate, 0)
	var f: = UI.font("body", 900)
	if rect.size.x < 360.0:
		var lt: = lbl(left_t, 24, PAPER_100, "body", 900)
		UI.center_label(lt, Rect2(0, rect.size.y * 0.14, rect.size.x, rect.size.y * 0.4))
		plate.add_child(lt)
		var rt: = lbl(right_t, 18, GOLD_300, "body", 900)
		rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.center_label(rt, Rect2(8, rect.size.y * 0.52, rect.size.x - 16, rect.size.y * 0.4))
		plate.add_child(rt)
		return b
	var l: = lbl(left_t, 24, PAPER_100, "body", 900)
	var lw: = f.get_string_size(left_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	l.position = Vector2(20, (rect.size.y - l.get_minimum_size().y) * 0.5)
	plate.add_child(l)
	var cw: = rect.size.x - 20.0 - lw - 16.0 - 20.0
	var rs: = 24
	while rs > 18 and f.get_string_size(right_t, HORIZONTAL_ALIGNMENT_LEFT, -1, rs).x > cw:
		rs -= 1
	var rl: = lbl(right_t, rs, GOLD_300, "body", 900)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rl.size = Vector2(cw, 10)
	plate.add_child(rl)
	var hh: = rl.get_minimum_size().y
	var el: Label = null
	if extra != "":
		el = lbl(extra, 18, PAPER_300, "body", 800)
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		el.size = Vector2(cw, 10)
		plate.add_child(el)
		hh += el.get_minimum_size().y
	var y0: = (rect.size.y - hh) * 0.5
	rl.position = Vector2(rect.size.x - 20.0 - cw, y0)
	if el:
		el.position = Vector2(rect.size.x - 20.0 - cw, y0 + rl.get_minimum_size().y)
	return b


static func chip(text: String, tex: Texture2D, h: = 44.0, col: = PAPER_100) -> Control:
	var f: = UI.font("body", 900)
	var fs: = int(h * 0.46)
	var tw: = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var iw: = h * 0.8 if tex else 0.0
	var w: = tw + iw + h * 0.7
	var p: = sheet(Rect2(0, 0, w, h), 0.9)
	if tex:
		p.add_child(icon(tex, Rect2(h * 0.25, h * 0.1, iw, h * 0.8)))
	var l: = lbl(text, fs, col, "body", 900)
	UI.center_label(l, Rect2(iw + h * 0.3, 0, tw + h * 0.2, h))
	p.add_child(l)
	return p
