class_name Common
extends RefCounted


static func backdrop(parent: Control, bg: String, size: Vector2, blur: = 0.0, bright: = 1.0, tint: = Color.WHITE, focus: = Vector2(0.5, 0.5)) -> TextureRect:
	var path: = "res://assets/bg/%s.webp" % bg
	if blur > 0.0 and ResourceLoader.exists("res://assets/bg/%s_blur.webp" % bg):
		path = "res://assets/bg/%s_blur.webp" % bg
		blur = 0.0
	var tex: Texture2D = load(path)
	var r: = UI.tex(tex, Rect2(Vector2.ZERO, size), false)
	var m: = ShaderMaterial.new()
	m.shader = preload("res://shaders/blurbg.gdshader")
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("tex_size", Vector2(tex.get_width(), tex.get_height()))
	m.set_shader_parameter("blur", blur)
	m.set_shader_parameter("bright", bright)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("focus", focus)
	m.set_shader_parameter("zoom", 1.04)
	m.set_shader_parameter("drift", Vector2(1, 1))
	r.material = m
	parent.add_child(r)
	return r

static func vignette(parent: Control, size: Vector2, color: = Color(0.55, 0.2, 0.35, 1.0), amount: = 0.35) -> ColorRect:
	var c: = ColorRect.new()
	c.size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: = ShaderMaterial.new()
	m.shader = preload("res://shaders/overlay.gdshader")
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("vignette", amount)
	c.material = m
	parent.add_child(c)
	return c

static func rays(parent: Node, pos: Vector2, size: float, color: Color, count: = 12.0, speed: = 0.05, intensity: = 0.5) -> ColorRect:
	var c: = ColorRect.new()
	c.size = Vector2(size, size)
	c.position = pos - c.size * 0.5
	c.pivot_offset = c.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: = ShaderMaterial.new()
	m.shader = preload("res://shaders/rays.gdshader")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("count", count)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("intensity", intensity)
	c.material = m
	parent.add_child(c)
	return c

static func card_art(tex: Texture2D, r: Rect2, focus: = Vector2(0.5, 0.3), zoom: = 1.0, radius: = 16.0) -> TextureRect:
	var t: = UI.tex(tex, r, false)
	# outfit / hero art is 700…1300 px and drawn at 40…340 px: sample the mipmaps or the outlines stair-step
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var m: = ShaderMaterial.new()
	m.shader = preload("res://shaders/card.gdshader")
	m.set_shader_parameter("size", r.size)
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("tex_size", Vector2(tex.get_width(), tex.get_height()))
	m.set_shader_parameter("focus", focus)
	m.set_shader_parameter("zoom", zoom)
	t.material = m
	return t

static func bubble(parent: Control, text: String, pos: Vector2, width: = 300.0, tail_left: = true) -> Control:
	var root: = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = pos
	var l: = UI.label(text, 22, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = Vector2(width - 36, 0)
	l.custom_minimum_size = Vector2(width - 36, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 0.8: size the bubble from the wrapped text (same font, weight and width as the label), not a width guess
	var th: float = UI.font("body", 800).get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width - 40, 22, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y
	var h: float = maxf(56.0, 30.0 + th)
	var tail: = Polygon2D.new()
	tail.color = Color(0.12, 0.11, 0.13, 0.97)
	tail.polygon = PackedVector2Array([Vector2(40, h - 6), Vector2(80, h - 6), Vector2(30, h + 22)]) if tail_left else PackedVector2Array([Vector2(width - 80, h - 6), Vector2(width - 40, h - 6), Vector2(width - 30, h + 22)])
	root.add_child(tail)
	var b: = UI.rbox("cream", Rect2(0, 0, width, h), 24, 3, 12)
	b.set_param("border_top", Color("e8c9a0")).set_param("border_bottom", Color("a8697a"))
	root.add_child(b)
	l.position = Vector2(18, 12)
	l.size = Vector2(width - 36, h - 24)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(l)
	root.size = Vector2(width, h)
	root.pivot_offset = Vector2(width * 0.3, h)
	parent.add_child(root)
	root.scale = Vector2(0.4, 0.4)
	root.modulate.a = 0
	var t: Tween = root.create_tween().set_parallel()
	t.tween_property(root, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(root, "modulate:a", 1.0, 0.15)
	return root

# 0.8: the ribbon is the btn/ribbon art (V8Art.nine). The returned RBox is only a holder (its own drawing is hidden)
# so callers that tween / reposition it keep working; other palettes tint the pink ribbon.
const RIBBON_TINT: = {"gold": Color(1.0, 0.9, 0.66), "red": Color(1.0, 0.74, 0.74), "lav": Color(0.84, 0.8, 1.0),
	"mint": Color(0.78, 1.0, 0.88), "sky": Color(0.8, 0.9, 1.0)}

static func ribbon(parent: Control, text: String, rect: Rect2, pal: = "pink", size: = 34) -> RBox:
	var b: = UI.rbox(pal, rect, 18, 4, 12)
	b.cr.visible = false
	parent.add_child(b)
	var art: = V8Art.nine("ribbon", Rect2(Vector2.ZERO, rect.size))
	art.name = "Art"
	if RIBBON_TINT.has(pal):
		art.modulate = RIBBON_TINT[pal]
	b.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cr: = V8Art.nine_content("ribbon", rect.size)
	# the caption fits the band: shrink (not below 16 px), never spill over the flowers
	var fs: = mini(size, int(cr.size.y * 1.05))
	while fs > 16 and UI.font_for("title", fs, 900).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 0.4 > cr.size.x:
		fs -= 1
	var l: = UI.center_label(UI.title(text, fs, Color("fff6ea"), UI.PAL.get(pal, UI.PAL.pink)[2]), cr)
	l.name = "L"
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_child(l)
	return b

# width a ribbon needs so `text` at `size` px sits on the band between the flower caps
static func ribbon_w(text: String, h: float, size: int) -> float:
	var k: = h / 121.0
	return UI.font_for("title", size, 900).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size * 1.2 + 2.0 * 164.0 * k * 0.85

# 0.8 card frames (frame/card_r|sr|ssr, 344×512) as a nine-patch: corners, crest and flowers keep their shape,
# only the straight side bars stretch. Margins (L, T, R, B) measured on the PNGs in source px. The patch is laid out
# at source scale and the node scaled down by k, so the mipmapped texture stays crisp on small cards.
const CARD_NINE: = {"R": [48, 56, 48, 48], "SR": [84, 136, 84, 112], "SSR": [110, 160, 110, 84]}
# inner edge of the frame's rim in source px (art underneath should reach at least this far)
# (L, T, R, B) — the top bar sits lower than the crest above it
const CARD_RIM: = {"R": [5, 22, 5, 6], "SR": [6, 26, 6, 8], "SSR": [10, 60, 10, 14]}

static func card_rar(rar: String) -> String:
	var k: = rar.to_upper()
	return k if CARD_NINE.has(k) else "R"

static func card_scale(rar: String, size: Vector2) -> float:
	var m: Array = CARD_NINE[card_rar(rar)]
	return minf(size.x / 344.0, (size.y - 2.0) / float(m[1] + m[3]))

static func card_frame(parent: Control, rar: String, r: Rect2) -> NinePatchRect:
	var key: = card_rar(rar)
	var m: Array = CARD_NINE[key]
	var k: = maxf(0.05, card_scale(key, r.size))
	var np: = NinePatchRect.new()
	np.texture = V8Art.frame(key)
	np.patch_margin_left = m[0]
	np.patch_margin_top = m[1]
	np.patch_margin_right = m[2]
	np.patch_margin_bottom = m[3]
	np.position = r.position
	np.size = r.size / k
	np.scale = Vector2(k, k)
	np.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	np.name = "CardFrame"
	if parent != null:
		parent.add_child(np)
	return np

# rect for the card picture under a frame of `size` (inset just under the rim) and its corner radius
static func card_inner(rar: String, size: Vector2) -> Rect2:
	var k: = card_scale(rar, size)
	var m: Array = CARD_RIM[card_rar(rar)]
	return Rect2(m[0] * k, m[1] * k, size.x - (m[0] + m[2]) * k, size.y - (m[1] + m[3]) * k)

static func card_radius(rar: String, size: Vector2) -> float:
	return 34.0 * card_scale(rar, size)

# 0.8: one-line caption that fits `width`: shrink the font (not below min_fs), then trim with «…»
static func fit_line(l: Label, width: float, min_fs: = 16) -> Label:
	var ls: LabelSettings = l.label_settings
	var fs: = ls.font_size
	var kind: = "body" if ls.font == UI.font("body", 900) or ls.font == UI.font("body", 800) else "title"
	var pad: = ls.outline_size * 1.0
	while fs > min_fs and ls.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad > width:
		fs -= 1
		if kind == "title" and fs < UI.TITLE_MIN:
			# Playfair is only for 24 px and up
			ls.font = UI.font("body", 900)
			kind = "body"
	ls.font_size = fs
	l.size.x = width
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l

# 0.8: wrapped caption that breaks only between words: shrink until the longest word fits on a line and the text
# takes at most `lines` lines (not below min_fs). A word still too wide at min_fs is drawn a little lighter, and
# as the last resort ends in «…» — a word is never split over two lines.
static func fit_words(l: Label, width: float, lines: = 2, min_fs: = 16) -> Label:
	var ls: LabelSettings = l.label_settings
	var fs: = ls.font_size
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	# the outline reaches about half its size past the glyphs on each side
	var pad: = ls.outline_size * 1.0
	var text: = l.text
	while true:
		var lw: = _longest_word(text, ls.font, fs)
		var h: = ls.font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width - pad, fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y
		if fs <= min_fs or (lw + pad <= width and h <= ls.font.get_height(fs) * lines + 1.0):
			break
		fs -= 1
	for wt in [700, 600]:
		if _longest_word(text, ls.font, fs) + pad > width:
			ls.font = UI.font("body", wt)
			ls.outline_size = mini(ls.outline_size, 3 if wt == 700 else 2)
			pad = ls.outline_size * 1.0
	if _longest_word(text, ls.font, fs) + pad > width:
		# a word still wider than the box is hyphenated across two lines («Импера-» / «трица») while the
		# line budget allows it; only past that it is trimmed with «…»
		var hy: = _hyphenate(text, ls.font, fs, width - pad)
		if hy != text and ls.font.get_multiline_string_size(hy, HORIZONTAL_ALIGNMENT_LEFT, width - pad, fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y <= ls.font.get_height(fs) * lines + 1.0:
			text = hy
	if _longest_word(text, ls.font, fs) + pad > width:
		var words: = text.split(" ", false)
		for k in words.size():
			var w: String = words[k]
			while w.length() > 2 and ls.font.get_string_size(w + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad > width:
				w = w.left(-1)
			if w != words[k]:
				words[k] = w + "…"
		text = " ".join(words)
	l.text = text
	ls.font_size = fs
	l.size.x = width
	l.custom_minimum_size.x = width
	l.max_lines_visible = lines
	return l

const _VOWELS: = "аеёиоуыэюяaeiouy"

# Splits every word wider than `width` once: the longest head that fits with a «-» (at least 3 letters, at
# least 2 left over, preferably right after a vowel and never before ь/ъ/й) goes on its own line.
static func _hyphenate(text: String, f: Font, fs: int, width: float) -> String:
	var out: = []
	for w in text.split(" ", false):
		if f.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width or w.length() < 6:
			out.append(w)
			continue
		var best: = -1
		var any: = -1
		for k in range(w.length() - 2, 2, -1):
			if f.get_string_size(w.left(k) + "-", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
				continue
			if w[k].to_lower() in ["ь", "ъ", "й"]:
				continue
			if any < 0:
				any = k
			if _VOWELS.contains(w[k - 1].to_lower()) and not _VOWELS.contains(w[k].to_lower()):
				best = k
				break
		var k2: = best if best > 0 else any
		if k2 < 0:
			out.append(w)
		else:
			out.append(w.left(k2) + "-\n" + w.substr(k2))
	return " ".join(out).replace("\n ", "\n")

static func _longest_word(text: String, f: Font, fs: int) -> float:
	var m: = 0.0
	for w in text.replace("\n", " ").split(" ", false):
		m = maxf(m, f.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return m

# 0.8 art for an icon name used by the old G.icon calls: currencies -> cur/*, navbar glyphs -> nav/*, the rest icon/*
static func ui_icon(name: String) -> Texture2D:
	if name in ["gem", "gems", "coin", "coins", "ticket", "tickets"]:
		return V8Art.cur(name)
	if name in ["home", "play", "wardrobe", "wishes", "shop"]:
		return V8Art.nav(name)
	return V8Art.icon(name)

static func icon_button(parent: Control, icon: String, text: String, rect: Rect2, cb: Callable, badge: = false, fsize: = 16) -> Control:
	var c: = Control.new()
	c.position = rect.position
	c.size = rect.size
	c.pivot_offset = rect.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_STOP

	# 0.8: the round icon art carries its own disc
	c.add_child(V8Art.rect(ui_icon(icon), Rect2(rect.size.x * 0.06, rect.size.x * 0.05, rect.size.x * 0.88, rect.size.x * 0.88)))
	if text != "":
		c.add_child(UI.center_label(UI.label(text, fsize, UI.INK, UI.DARK, 4, "body", 900 if fsize > 16 else 800), Rect2(-24, rect.size.x - 10, rect.size.x + 48, fsize + 8)))
	if badge:
		var d: = UI.rbox("gold", Rect2(rect.size.x - 18, 2, 14, 14), 7, 1, 3)
		d.colors(Color("ffe7a6"), Color("ff8fb0"))
		c.add_child(d)
		var t: Tween = d.create_tween().set_loops()
		d.pivot_offset = Vector2(7, 7)
		t.tween_property(d, "scale", Vector2(1.2, 1.2), 0.45).set_trans(Tween.TRANS_SINE)
		t.tween_property(d, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	c.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("pop")
			UI.punch(c, 0.15)
			cb.call())
	parent.add_child(c)
	return c

static func progress_bar(parent: Control, rect: Rect2, frac: float, pal: = "mint") -> RBox:
	var bg: = UI.rbox("cream", rect, rect.size.y * 0.5, 2, 6)
	bg.colors(Color(0.04, 0.035, 0.045, 0.55), Color(0.1, 0.09, 0.11, 0.65))
	bg.set_param("shadow_color", Color(0, 0, 0, 0))
	parent.add_child(bg)
	var w: float = max(rect.size.y, (rect.size.x - 6) * clamp(frac, 0.0, 1.0))
	var fg: = UI.rbox(pal, Rect2(3, 3, w, rect.size.y - 6), (rect.size.y - 6) * 0.5, 0, 4)
	fg.set_param("shadow_color", Color(0, 0, 0, 0))
	bg.add_child(fg)
	return fg


static func popup(main, title: String, h: float, pal: = "cream", w: = 660.0, closable: = true) -> RBox:
	var vs: Vector2 = main.get_viewport_rect().size
	var root: = Control.new()
	root.size = vs
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_meta("popup", true)
	root.set_meta("closable", closable)
	main.overlay.add_child(root)
	var dim: = ColorRect.new()
	dim.size = vs
	dim.color = Color(0.03, 0.02, 0.035, 0.0)
	root.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.72, 0.25)
	var y: float = max(150.0, (vs.y - h) * 0.5)
	var p: = UI.rbox(pal, Rect2((vs.x - w) * 0.5, y, w, h), 34, 5, 16)
	p.set_param("pattern", 1.0)
	# 0.8: the btn/panel art (graphite, gold rim, sakura corners); the RBox stays as the holder callers expect
	p.cr.visible = false
	var art: = V8Art.nine("panel", Rect2(Vector2.ZERO, Vector2(w, h)))
	art.name = "PanelArt"
	p.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(p)
	p.set_meta("root", root)
	p.pivot_offset = p.size * 0.5
	UI.pop_in(p, 0.0, 0.85)
	if title != "":
		var rh: = 72.0
		var rw: = clampf(ribbon_w(title, rh, 30), 400.0, w - 120.0)
		var rib: = ribbon(p, title, Rect2((w - rw) * 0.5, -38, rw, rh), "pink", 30)
		rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not closable:
		return p
	var x: = JButton.make("", "graphite", Rect2(w - 54, -20, 64, 64), null, 30)
	if x.box:
		x.box.borders(Color("ffe7a6"), Color("a8742a"))
	x.add_child(V8Art.rect(V8Art.icon("close"), Rect2(15, 15, 34, 34)))
	x.pressed.connect( func(): close_popup(p))
	p.add_child(x)
	dim.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			close_popup(p))
	return p

static func close_popup(p: Control) -> void :
	if not is_instance_valid(p) or not p.has_meta("root"):
		return
	var root: Control = p.get_meta("root")
	if root.has_meta("closing"):
		return
	root.set_meta("closing", true)
	Sfx.play("tap")
	var t: Tween = root.create_tween()
	t.tween_property(root, "modulate:a", 0.0, 0.18)
	t.tween_callback(root.queue_free)
	if root.has_meta("on_close"):
		(root.get_meta("on_close") as Callable).call()

static func chip(parent: Control, icon: Texture2D, text: String, rect: Rect2, pal: = "plum", fsize: = 20) -> RBox:
	var b: = UI.rbox(pal, rect, rect.size.y * 0.5, 3, 8)
	if pal == "plum":
		b.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	parent.add_child(b)
	var x0: = 14.0
	if icon:
		b.add_child(V8Art.rect(icon, Rect2(-6, -8, rect.size.y + 16, rect.size.y + 16)))
		x0 = rect.size.y + 8
	# 0.8: shrink a long line to fit the pill (down to 16 px), then trim; never run past its border
	var avail: = rect.size.x - x0 - 12.0
	var fnt: = UI.font("body", 900)
	while fsize > 16 and fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > avail:
		fsize -= 1
	var l: = UI.label(text, fsize, Color.WHITE if pal in ["plum", "pink", "lav", "red"] else UI.INK, Color(0.2, 0.05, 0.2, 0.9) if pal in ["plum", "pink", "lav", "red"] else Color.WHITE, 3, "body", 900)
	l.position = Vector2(x0, 0)
	l.size = Vector2(rect.size.x - x0 - 10, rect.size.y)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.name = "L"
	b.add_child(l)
	return b

static func badge(parent: Control, n: int, pos: Vector2) -> Control:
	var d: = UI.rbox("red", Rect2(pos, Vector2(30, 30)), 15, 2, 4)
	parent.add_child(d)
	if n > 0:
		d.add_child(UI.center_label(UI.label(str(n), 17, Color.WHITE, Color("6a1020"), 3, "body", 900), Rect2(0, 0, 30, 30)))
	d.pivot_offset = Vector2(15, 15)
	var t: Tween = d.create_tween().set_loops()
	t.tween_property(d, "scale", Vector2(1.18, 1.18), 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_property(d, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	return d

static func avatar(hero: String, r: Rect2, ring_pal: = "gold") -> Control:
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(UI.rbox(ring_pal, Rect2(Vector2.ZERO, r.size), r.size.x * 0.5, 3, 8))
	var t: = UI.tex(load("res://assets/hero/%s.png" % hero), Rect2(Vector2(5, 5), r.size - Vector2(10, 10)), false)
	var m: = ShaderMaterial.new()
	m.shader = preload("res://shaders/card.gdshader")
	var rig: Dictionary = Hero.RIGS[hero]
	m.set_shader_parameter("size", t.size)
	m.set_shader_parameter("radius", t.size.x * 0.5)
	m.set_shader_parameter("tex_size", Vector2(848, 1264))
	m.set_shader_parameter("focus", Vector2(rig.head_c.x / 848.0, (rig.head_c.y + 15) / 1264.0))
	m.set_shader_parameter("zoom", 4.6)
	m.set_shader_parameter("bottom_shade", 0.0)
	t.material = m
	t.name = "Pic"
	c.add_child(t)
	return c


static func rank_emblem(parent: Control, r: Rect2, tier: int, sub: int) -> Control:
	# 0.8: the rank medallion art (V8Art.rank); the sub-rank sits on a small graphite tag at the lower right
	# (roman I/II/III, or the Celestial number). Tiny emblems (< 56 px) show three pips instead of text.
	tier = clampi(tier, 0, G.RANKS.size() - 1)
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.name = "RankEmblem"
	parent.add_child(c)
	var rk: Dictionary = G.RANKS[tier]
	var glow: = Sprite2D.new()
	glow.texture = G.fx("glow")
	glow.material = Fx.add_mat()
	glow.position = r.size * Vector2(0.5, 0.42)
	glow.scale = Vector2.ONE * r.size.x / 80.0
	glow.modulate = Color(rk.color.r, rk.color.g, rk.color.b, 0.35)
	c.add_child(glow)
	var art: = V8Art.rect(V8Art.rank(tier), Rect2(Vector2.ZERO, r.size))
	art.name = "Art"
	c.add_child(art)
	var last: = tier == G.RANKS.size() - 1
	var w: = minf(r.size.x, r.size.y)
	if w < 56.0 and not last:
		var pd: = maxf(5.0, w * 0.13)
		var gap: = pd * 0.45
		var x0: = (r.size.x - (pd * 3.0 + gap * 2.0)) * 0.5
		# one node as the last child, so callers can still hide the sub-rank with get_child(-1).visible = false
		var pips: = Control.new()
		pips.size = r.size
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.name = "Sub"
		c.add_child(pips)
		for k in 3:
			var on: = k <= sub
			var pip: = UI.rbox("gold", Rect2(x0 + k * (pd + gap), r.size.y - pd - 1.0, pd, pd), pd * 0.5, 1, 2)
			if on:
				pip.colors(Color("fff1c2"), Color("e0a43a")).borders(Color(1, 1, 1, 0.8), Color("6a4210"))
			else:
				pip.colors(Color(0.16, 0.14, 0.18, 0.95), Color(0.08, 0.07, 0.09, 0.95)).borders(Color("c9a25a"), Color("5a3a10"))
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pips.add_child(pip)
		return c
	var txt: String = str(sub + 1) if last else G.ROMAN[clampi(sub, 0, 2)]
	var fs: = maxi(16, int(w * 0.17))
	var tw: = UI.font("body", 900).get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 0.9
	var th: = fs * 1.35
	var tag: = UI.rbox("graphite", Rect2(minf(r.size.x - tw, r.size.x * 0.8 - tw * 0.5), r.size.y * 0.84 - th, tw, th), th * 0.5, 2, 4)
	tag.colors(Color(0.15, 0.13, 0.17, 0.96), Color(0.07, 0.06, 0.08, 0.96)).borders(Color("ffe7a6"), Color("a8742a"))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.name = "Sub"
	c.add_child(tag)
	tag.add_child(UI.center_label(UI.label(txt, fs, Color("fff1c2"), Color(0, 0, 0, 0.6), 2, "title" if fs >= UI.TITLE_MIN else "body", 900), Rect2(0, -1, tw, th)))
	return c


static func league_emblem(parent: Control, r: Rect2, tier: int) -> Control:
	# 0.8: weekly league crest («фишка в фонаре», V8Art.league) — not the rank medallion
	tier = clampi(tier, 0, G.RANKS.size() - 1)
	var c: = Control.new()
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.name = "LeagueEmblem"
	parent.add_child(c)
	var rk: Dictionary = G.RANKS[tier]
	var glow: = Sprite2D.new()
	glow.texture = G.fx("glow")
	glow.material = Fx.add_mat()
	glow.position = r.size * Vector2(0.5, 0.45)
	glow.scale = Vector2.ONE * r.size.x / 80.0
	glow.modulate = Color(rk.color.r, rk.color.g, rk.color.b, 0.3)
	c.add_child(glow)
	var art: = V8Art.rect(V8Art.league(tier), Rect2(Vector2.ZERO, r.size))
	art.name = "Art"
	c.add_child(art)
	return c


static func skin_picker(main, on_done: Callable) -> void :
	var skins: = G.ITEMS.filter( func(x): return x.cat == "skin")
	var p: = popup(main, V6Txt.s("skins.title"), 120 + ((skins.size() + 2) / 3) * 230 + 40)
	for k in skins.size():
		var it: Dictionary = skins[k]
		var own: = G.owns(it.id)
		var on: bool = G.S.get("skin", "s_sakura") == it.id
		var r: = Rect2(30 + (k % 3) * 204, 64 + (k / 3) * 230, 190, 214)
		var card: = UI.rbox("gold" if on else "plum", r, 22, 3, 8)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(card)
		var tile: = Tile.new()
		tile.face = it.tile
		tile.position = Vector2(95, 86)
		tile.scale = Vector2(1.25, 1.25)
		card.add_child(tile)
		tile.build(G.SKIN_LOOK.get(it.id, {}))
		if not own:
			tile.modulate = Color(0.45, 0.42, 0.5)
		var nm: = UI.center_label(UI.label(it.name.replace("Фишки ", ""), 17, Color.WHITE, Color(0.1, 0.05, 0.2), 3, "body", 900), Rect2(0, 158, 190, 26))
		card.add_child(nm)
		var how: = V6Txt.s("skins.on") if on else (V6Txt.s("skins.pick") if own else G.skin_source(it.id))
		var st: = UI.center_label(UI.label(how, 16, Color("ffd34d") if on else Color("d9c4e6")), Rect2(0, 184, 190, 22))
		card.add_child(st)
		card.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				if not own:
					main.toast(V6Txt.s("skins.where") % [it.name.replace("Фишки ", ""), G.skin_source(it.id)], "gift")
					return
				Sfx.play("pop")
				G.S.skin = it.id
				G.save()
				main.toast(V6Txt.s("skins.set") % it.name.replace("Фишки ", ""), "star")
				close_popup(p)
				on_done.call())



# 0.8: confirmation before spending currency (spec: no spend without Common.confirm).
#   Common.confirm(main, title, text, price_icon, price, on_yes, opts) -> RBox (null if skipped via skip_key)
#   price_icon: G.icon name ("gem", "coin", "ticket"…) or "" for no price row; price: amount shown.
#   opts: skip_key: String  — shows «Не спрашивать в этой партии»; when ticked and confirmed, later calls with
#                             the same key call on_yes at once. Make the key per match, e.g. "hint_%d" % get_instance_id().
#         on_no: Callable   — called on «Отмена», ×, or tap outside.
#         yes_text / no_text: String — button captions (default «Да» / «Отмена»).
#         balance_check: bool (default true) — for gem/coin prices: if the player cannot pay, «Да» is disabled.
# The callback never spends anything itself: on_yes does the spending.
static var confirm_skips: = {}

static func confirm_skip_reset(prefix: = "") -> void :
	if prefix == "":
		confirm_skips.clear()
		return
	for k in confirm_skips.keys():
		if str(k).begins_with(prefix):
			confirm_skips.erase(k)


static func confirm(main, title: String, text: String, price_icon: String, price: int, on_yes: Callable, opts: = {}) -> RBox:
	var skip_key: String = str(opts.get("skip_key", ""))
	if skip_key != "" and confirm_skips.get(skip_key, false):
		on_yes.call()
		return null
	var w: = 600.0
	var tw: = w - 80.0
	var tsize: = 24
	var text_h: float = UI.font("body", 800).get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, tw, tsize).y + 8.0
	var has_price: = price_icon != "" and price > 0
	var balance: = -1
	if has_price and opts.has("balance"):
		# a currency outside G.S.gems / coins (event currency): the caller passes the balance
		balance = int(opts.balance)
	elif has_price and opts.get("balance_check", true):
		if price_icon == "gem":
			balance = int(G.S.gems)
		elif price_icon == "coin":
			balance = int(G.S.coins)
	var short: = balance >= 0 and balance < price
	var h: = 64.0 + text_h + 24.0
	if has_price:
		h += 70.0 + (34.0 if balance >= 0 else 0.0) + 14.0
	if skip_key != "":
		h += 62.0
	h += 92.0 + 34.0
	var p: = popup(main, title, h, "cream", w)
	var root: Control = p.get_meta("root")
	var done: = [false]
	var y: = 64.0
	var tl: = UI.label(text, tsize, UI.INK, UI.DARK, 3, "body", 800)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.position = Vector2(40, y)
	tl.size = Vector2(tw, text_h)
	p.add_child(tl)
	y += text_h + 24.0
	if has_price:
		var num: = UI.fmt(price)
		var nw: float = UI.font("body", 900).get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var pw: = clampf(nw + 112.0, 170.0, 360.0)
		var pill: = UI.rbox("plum", Rect2((w - pw) * 0.5, y, pw, 64), 32, 3, 8)
		pill.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
		p.add_child(pill)
		var ptex: Texture2D = opts.get("price_tex") if opts.get("price_tex") is Texture2D else ui_icon(price_icon)
		pill.add_child(V8Art.rect(ptex, Rect2(10, 2, 60, 60)))
		var pl: = UI.label(num, 34, Color("ff9a9a") if short else Color.WHITE, Color(0.2, 0.05, 0.2), 4, "body", 900)
		pl.position = Vector2(76, 0)
		pl.size = Vector2(pw - 92, 64)
		pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pill.add_child(pl)
		y += 70.0
		if balance >= 0:
			var bt: String = ("Не хватает: у тебя %s" if short else "У тебя: %s") % UI.fmt(balance)
			p.add_child(UI.center_label(UI.label(bt, 19, Color("ff9a9a") if short else UI.MUTED, UI.DARK, 2, "body", 800), Rect2(0, y, w, 30)))
			y += 34.0
		y += 14.0
	var skip: = [false]
	if skip_key != "":
		var row: = Control.new()
		row.position = Vector2(0, y)
		row.size = Vector2(w, 52)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(row)
		var cap: = "Не спрашивать в этой партии"
		var cw: float = UI.font("body", 800).get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		var x0: = (w - (44.0 + 14.0 + cw)) * 0.5
		var box: = UI.rbox("glass", Rect2(x0, 4, 44, 44), 12, 3, 6)
		box.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
		row.add_child(box)
		var mark: = UI.center_label(UI.label("✓", 30, Color("ffd34d"), UI.DARK, 3, "body", 900), Rect2(0, 0, 44, 44))
		mark.visible = false
		box.add_child(mark)
		var cl: = UI.label(cap, 21, UI.INK, UI.DARK, 2, "body", 800)
		cl.position = Vector2(x0 + 58, 0)
		cl.size = Vector2(cw + 8, 52)
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(cl)
		row.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				skip[0] = not skip[0]
				mark.visible = skip[0]
				Sfx.play("tap")
				UI.punch(box, 0.15))
		y += 62.0
	var bw: = (w - 60.0 - 20.0) * 0.5
	var no: = JButton.make(str(opts.get("no_text", "Отмена")), "glass", Rect2(30, y + 4, bw, 84), null, 28)
	p.add_child(no)
	var yes: = JButton.make(str(opts.get("yes_text", "Да")), "glass" if short else "gold", Rect2(50 + bw, y + 4, bw, 84), null, 30)
	if short:
		yes.modulate = Color(1, 1, 1, 0.55)
	else:
		yes.shine_every = 2.6
	p.add_child(yes)
	root.set_meta("on_close", func():
		if not done[0]:
			done[0] = true
			var cb_no = opts.get("on_no")
			if cb_no is Callable and (cb_no as Callable).is_valid():
				(cb_no as Callable).call())
	no.pressed.connect( func(): close_popup(p))
	yes.pressed.connect( func():
		if done[0]:
			return
		if short:
			UI.punch(yes, 0.12)
			if main.has_method("toast"):
				main.toast("Не хватает %s" % ("кристаллов" if price_icon == "gem" else "монет"), price_icon)
			return
		done[0] = true
		if skip[0] and skip_key != "":
			confirm_skips[skip_key] = true
		close_popup(p)
		on_yes.call())
	return p


static func living_art(parent: Control, tex: Texture2D, r: Rect2, focus: = Vector2(0.5, 0.35)) -> TextureRect:
	var art: = card_art(tex, r, focus, 1.0, 0.0)
	(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.0)
	art.pivot_offset = r.size * Vector2(0.5, 0.4)
	parent.add_child(art)
	var t: = art.create_tween().set_loops()
	t.tween_property(art, "scale", Vector2(1.035, 1.035), 3.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(art, "scale", Vector2.ONE, 3.2).set_trans(Tween.TRANS_SINE)
	return art
