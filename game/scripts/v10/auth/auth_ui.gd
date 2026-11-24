class_name V10AuthUI
extends RefCounted

# Shared widgets of the auth lane. Self-contained (no main.gd needed), built from the 0.8/0.9 kit:
# V8Art panel/ribbon nine-patches, JButton art buttons, V9Feel for every tap.
#   V10AuthUI.sheet(host, title, h)        -> {"root", "panel"}: dimmed modal with the gold-rim panel + ribbon
#   V10AuthUI.close(root)                    fade + free
#   V10AuthUI.provider_button(id, rect)      art button with the provider's mark on the left
#   V10AuthUI.checkbox(rect, text, on, cb)   tappable check row (cb(on: bool))
#   V10AuthUI.link(text, rect, cb)           underlined text link, pressed through V9Feel
#   V10AuthUI.toast(host, text, hero = "")   one-line pill at the top (optionally with a heroine avatar)
#   V10AuthUI.welcome(host, hero, name, line) the heroine greeting card after an automatic sign-in

const PW: = 660.0
const BRAND: = {
	"vkid": {"bg": Color("0077ff"), "fg": Color.WHITE, "mark": "VK", "round": 0.3},
	"yandex": {"bg": Color("fc3f1d"), "fg": Color.WHITE, "mark": "Я", "round": 0.5},
	"google": {"bg": Color("ffffff"), "fg": Color("4285f4"), "mark": "G", "round": 0.5},
	"yagames": {"bg": Color("ffcc00"), "fg": Color("1a1a1a"), "mark": "Я", "round": 0.3},
	"email": {"bg": Color("e8c47e"), "fg": Color("3a2410"), "mark": "@", "round": 0.5},
}


static func sheet(host: Control, title: String, h: float, w: = PW) -> Dictionary:
	var vs: = host.size
	var root: = Control.new()
	root.name = "V10AuthSheet"
	root.size = vs
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(root)
	var dim: = ColorRect.new()
	dim.size = vs
	dim.color = Color(0.03, 0.02, 0.035, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_meta("no_haptic", true)
	root.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.66, 0.25)
	var pw: = minf(w, vs.x - 32.0)
	var y: = clampf((vs.y - h) * 0.5 + 20.0, 90.0, maxf(90.0, vs.y - h - 40.0))
	var panel: = Control.new()
	panel.name = "Panel"
	panel.position = Vector2((vs.x - pw) * 0.5, y)
	panel.size = Vector2(pw, h)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("no_haptic", true)
	root.add_child(panel)
	var art: = V8Art.nine("panel", Rect2(Vector2.ZERO, panel.size))
	art.name = "PanelArt"
	panel.add_child(art)
	panel.pivot_offset = panel.size * 0.5
	UI.pop_in(panel, 0.02, 0.86)
	if title != "":
		var rib: = Common.ribbon(panel, title, Rect2(pw * 0.5 - 220, -38, 440, 72), "pink", 30)
		rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_meta("panel", panel)
	return {"root": root, "panel": panel}


static func close(root: Control, cb: Callable = Callable()) -> void :
	if root == null or not is_instance_valid(root) or root.has_meta("closing"):
		return
	root.set_meta("closing", true)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: = root.create_tween()
	t.tween_property(root, "modulate:a", 0.0, 0.2)
	t.tween_callback(func():
		if cb.is_valid():
			cb.call()
		root.queue_free())


# the provider's mark: a small brand tile (rounded square / circle) with its letters
static func mark(id: String, r: Rect2) -> Control:
	var b: Dictionary = BRAND.get(id, BRAND.email)
	var m: = Panel.new()
	m.position = r.position
	m.size = r.size
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: = StyleBoxFlat.new()
	sb.bg_color = b.bg
	var rad: = int(minf(r.size.x, r.size.y) * float(b.round))
	sb.set_corner_radius_all(rad)
	sb.anti_aliasing = true
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	m.add_theme_stylebox_override("panel", sb)
	var fs: = int(r.size.y * (0.46 if str(b.mark).length() > 1 else 0.62))
	var l: = UI.label(str(b.mark), fs, b.fg, Color(0, 0, 0, 0), 0, "body", 900)
	UI.center_label(l, Rect2(Vector2.ZERO, r.size))
	m.add_child(l)
	return m


static func provider_button(id: String, rect: Rect2, text: = "") -> JButton:
	if text == "":
		text = V10AuthText.s("login." + id)
	var b: = JButton.make(text, "glass", rect, null, 25)
	b.name = "Btn_" + id
	var s: = rect.size.y * 0.52
	var cr: = V8Art.nine_content("secondary", rect.size) if b.art else Rect2(Vector2(rect.size.y * 0.3, 0), rect.size)
	var ix: = maxf(cr.position.x - 6.0, rect.size.y * 0.32)
	var mk: = mark(id, Rect2(ix, (rect.size.y - s) * 0.5, s, s))
	mk.name = "Mark"
	b.add_child(mk)
	if b.lbl:
		var x0: = ix + s + 10.0
		var x1: = rect.size.x - cr.end.x if b.art else rect.size.y * 0.3
		UI.center_label(b.lbl, Rect2(x0, 0, rect.size.x - x0 - x1 - (s * 0.5), rect.size.y))
		b._fit_label(b.lbl.size.x)
	return b


class Check extends Control:
	signal toggled(on: bool)
	var on: = false
	var box: Panel
	var tick: Label
	var text_lbl: Label

	func setup(text: String, v: bool, fs: int) -> void :
		mouse_filter = Control.MOUSE_FILTER_STOP
		var s: = minf(44.0, size.y)
		box = Panel.new()
		box.position = Vector2(0, (size.y - s) * 0.5)
		box.size = Vector2(s, s)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		tick = UI.label("✓", int(s * 0.78), Color("3a2410"), Color(0, 0, 0, 0), 0, "body", 900)
		UI.center_label(tick, Rect2(Vector2(0, -2), Vector2(s, s)))
		box.add_child(tick)
		text_lbl = UI.label(text, fs, UI.INK, UI.DARK, 3, "body", 800)
		text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_lbl.position = Vector2(s + 14, 0)
		text_lbl.size = Vector2(size.x - s - 14, size.y)
		add_child(text_lbl)
		set_on(v, false)

	func set_on(v: bool, anim: = true) -> void :
		on = v
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color("e8c47e") if on else Color(0.1, 0.09, 0.11, 0.85)
		sb.border_color = Color("fff0b8") if on else Color("c58a2c")
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(10)
		sb.anti_aliasing = true
		box.add_theme_stylebox_override("panel", sb)
		tick.visible = on
		if anim:
			if on:
				V9Feel.success(box, "pop", 0.6)
			else:
				V9Feel.press(box, "tap", "tap")

	func _gui_input(e: InputEvent) -> void :
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			set_on(not on)
			toggled.emit(on)
			accept_event()

	func nudge() -> void :
		V9Feel.deny(self)
		var t: = box.create_tween()
		for i in 2:
			t.tween_property(box, "modulate", Color(1.8, 1.4, 0.8), 0.12)
			t.tween_property(box, "modulate", Color.WHITE, 0.35)


static func checkbox(rect: Rect2, text: String, on: bool, cb: Callable = Callable(), fs: = 18) -> Check:
	var c: = Check.new()
	c.position = rect.position
	c.size = rect.size
	c.setup(text, on, fs)
	if cb.is_valid():
		c.toggled.connect(cb)
	return c


class Link extends Label:
	signal pressed

	func _gui_input(e: InputEvent) -> void :
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			V9Feel.press(self, "tap", "tap")
			pressed.emit()
			accept_event()


static func link(text: String, rect: Rect2, cb: Callable, fs: = 18, col: = Color("f3d38f")) -> Label:
	var l: = Link.new()
	var src: = UI.label(text, fs, col, UI.DARK, 3, "body", 800)
	l.label_settings = src.label_settings
	l.text = text
	src.free()
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.pivot_offset = rect.size * 0.5
	# underline drawn under the text width
	var u: = ColorRect.new()
	var tw: = UI.font("body", 800).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	u.color = Color(col, 0.55)
	u.size = Vector2(minf(tw, rect.size.x), 2)
	u.position = Vector2((rect.size.x - u.size.x) * 0.5, rect.size.y * 0.5 + fs * 0.62)
	u.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_child(u)
	l.pressed.connect(cb)
	return l


static func toast(host: Control, text: String, hero: = "", y: = -1.0) -> Control:
	for c in host.get_children():
		if c.has_meta("v10_auth_toast"):
			c.queue_free()
	var w: = minf(620.0, host.size.x - 32.0)
	var th: = 78.0
	if y < 0.0:
		y = maxf(56.0, host.size.y * 0.045)
	var p: = UI.rbox("plum", Rect2((host.size.x - w) * 0.5, y, w, th), 36, 3, 12)
	p.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	p.set_meta("v10_auth_toast", true)
	p.name = "V10AuthToast"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 40
	host.add_child(p)
	var x0: = 22.0
	if hero != "" and G.HEROES.has(hero):
		var av: = Common.avatar(hero, Rect2(8, 7, 64, 64))
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(av)
		x0 = 80.0
	var fs: = 21 if UI.font("body", 800).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x < (w - x0 - 18) * 1.9 else 18
	var l: = UI.label(text, fs, Color.WHITE, Color(0.2, 0.05, 0.2), 3)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(x0, 0)
	l.size = Vector2(w - x0 - 18, th)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	UI.slide_in(p, Vector2(0, -50), 0.0, 0.32)
	var t: = p.create_tween()
	t.tween_interval(2.8)
	t.tween_property(p, "modulate:a", 0.0, 0.3)
	t.tween_callback(p.queue_free)
	return p


# The welcome card: heroine portrait in a gold ring, her name, the line with the player's name. Slides down from
# the top, a soft sparkle, then leaves by itself (3.6 s); a tap dismisses it early.
static func welcome(host: Control, hero: String, line: String, y: = -1.0) -> Control:
	for c in host.get_children():
		if c.has_meta("v10_auth_welcome"):
			c.queue_free()
	var w: = minf(640.0, host.size.x - 28.0)
	var hh: = 128.0
	if y < 0.0:
		y = maxf(96.0, host.size.y * 0.075)
	var root: = Control.new()
	root.name = "V10Welcome"
	root.set_meta("v10_auth_welcome", true)
	root.position = Vector2((host.size.x - w) * 0.5, y)
	root.size = Vector2(w, hh)
	root.z_index = 45
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(root)
	var bg: = UI.rbox("plum", Rect2(0, 10, w, hh - 10), 30, 3, 12)
	bg.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var col: Color = G.HEROES.get(hero, G.HEROES.mc).color
	# heroine-coloured light behind the avatar, fading out to the right (no hard edge across the text)
	var glow: = TextureRect.new()
	var gt: = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.14, 0.5)
	gt.fill_to = Vector2(0.86, 0.5)
	var gr: = Gradient.new()
	gr.set_color(0, Color(col, 0.30))
	gr.set_color(1, Color(col, 0.0))
	gt.gradient = gr
	glow.texture = gt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.position = Vector2(6, 6)
	glow.size = Vector2(w * 0.6, hh - 22)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(glow)
	var av: = Common.avatar(hero, Rect2(10, 0, 118, 118))
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(av)
	var nm: = UI.label(str(G.HEROES.get(hero, G.HEROES.mc).name), 22, col.lightened(0.35), UI.DARK, 4, "title", 900)
	nm.position = Vector2(140, 22)
	nm.size = Vector2(w - 160, 30)
	root.add_child(nm)
	var l: = UI.label(line, 22, UI.INK, UI.DARK, 3, "body", 800)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(140, 52)
	l.size = Vector2(w - 160, hh - 62)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	Common.fit_words(l, w - 160, 2, 17)
	root.add_child(l)
	l.visible_ratio = 0.0
	var tl: = root.create_tween()
	tl.tween_interval(0.25)
	tl.tween_property(l, "visible_ratio", 1.0, clampf(line.length() * 0.018, 0.4, 1.1))
	UI.slide_in(root, Vector2(0, -70), 0.0, 0.42)
	V9Feel.success(av, "sparkle", 0.8)
	if V9Feel.can_fx():
		bg.shine(0.35, 0.9)
	var gone: = [false]
	var leave: = func():
		if gone[0] or not is_instance_valid(root):
			return
		gone[0] = true
		var t2: = root.create_tween().set_parallel()
		t2.tween_property(root, "modulate:a", 0.0, 0.3)
		t2.tween_property(root, "position:y", root.position.y - 40.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t2.chain().tween_callback(root.queue_free)
	root.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			V9Feel.press(root, "tap", "tap")
			leave.call())
	# a tween owned by the card (not a SceneTree timer): if the card is freed early, nothing fires later
	root.create_tween().tween_interval(3.6).finished.connect(leave)
	return root
