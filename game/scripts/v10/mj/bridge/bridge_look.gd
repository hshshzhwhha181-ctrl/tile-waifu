class_name V10MjBridgeLook
extends RefCounted

# Вид моста: токены «Тишина и лак» (UX_RULES §6.2; класс DS появится при вливании — тогда TOK читает DS 1:1),
# акценты героинь, шрифты трёх голосов (§6.3) и общие строители кнопок/листов для двух экранов.

const TOK: = {
	"night900": Color("121014"), "night800": Color("1B171C"), "night700": Color("26212A"), "night600": Color("332C36"),
	"paper100": Color("F5EAD8"), "paper300": Color("DDD2C4"), "paper500": Color("B3A89C"), "paper700": Color("7E756D"),
	"gold300": Color("F1D9A0"), "gold500": Color("E8C47E"), "gold700": Color("A87B3A"),
	"rose300": Color("ECC0C9"), "rose500": Color("D796A5"), "rose700": Color("9A4F66"),
	"jade300": Color("A9D9C4"), "jade500": Color("5B9580"), "ember": Color("E07A7A"),
}

# акцент героини: accent / glow / deep (≤ 10 % пикселей)
const ACCENT: = {
	"mc": [Color("ff8fb8"), Color("ffd0e0"), Color("6a1f45")],
	"rin": [Color("4fbf9f"), Color("bff0e0"), Color("16514a")],
	"hana": [Color("ffb35c"), Color("ffe0b8"), Color("7a3a0c")],
	"yue": [Color("c8b6ff"), Color("ece6ff"), Color("3f2f7a")],
	"nova": [Color("4fe3ff"), Color("c8f6ff"), Color("0f3a5a")],
}
const HERO_NAME: = {"mc": "Маджонг-тян", "rin": "Рин", "hana": "Хана", "yue": "Юэ", "nova": "Нова"}
const VOICE_FONT: = ["res://assets/v10/mj/stage/fonts/caveat-cyrillic-600-normal.woff2",
	"res://assets/v10/mj/stage/fonts/caveat-latin-600-normal.woff2"]

static var _fonts: = {}


static func accent(hero: String) -> Array:
	return ACCENT.get(hero, ACCENT.mc)


static func hero_ok(hero: String) -> String:
	return hero if ACCENT.has(hero) else "mc"


static func font(kind: String, weight: = 700) -> Font:
	var key: = "%s%d" % [kind, weight]
	if _fonts.has(key):
		return _fonts[key]
	var f: Font
	match kind:
		"italic":
			var ts: = TextServerManager.get_primary_interface()
			var fv: = FontVariation.new()
			fv.base_font = load("res://assets/fonts/playfair-i-cyr.woff2")
			fv.variation_opentype = {ts.name_to_tag("wght"): weight}
			var fb: = FontVariation.new()
			fb.base_font = load("res://assets/fonts/playfair-i-lat.woff2")
			fb.variation_opentype = {ts.name_to_tag("wght"): weight}
			fv.fallbacks = [fb]
			f = fv
		"voice":
			# голос героини — Caveat 600 (шрифт дорожки stage); без него — Playfair Italic
			if ResourceLoader.exists(VOICE_FONT[0]):
				var base: FontFile = load(VOICE_FONT[0])
				var fv2: = FontVariation.new()
				fv2.base_font = base
				if ResourceLoader.exists(VOICE_FONT[1]):
					fv2.fallbacks = [load(VOICE_FONT[1])]
				f = fv2
			else:
				f = font("italic", 600)
		"title":
			f = UI.font("title", weight)
		_:
			f = UI.font("body", weight)
	_fonts[key] = f
	return f


static func label(text: String, size: int, color: Color, kind: = "body", weight: = 800) -> Label:
	var l: = Label.new()
	l.text = text
	var ls: = LabelSettings.new()
	ls.font = font(kind, weight)
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# фон: градиент ночи с отсветом её цвета сверху справа
static func backdrop(hero: String) -> TextureRect:
	var bg: = TextureRect.new()
	bg.name = "Bg"
	var g: = Gradient.new()
	var a: Array = accent(hero)
	g.set_color(0, Color(a[2]).darkened(0.5).lerp(TOK.night900, 0.3))
	g.set_color(1, TOK.night900)
	g.add_point(0.24, TOK.night800)
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.85, 0.0)
	gt.fill_to = Vector2(0.35, 1.0)
	gt.width = 64
	gt.height = 128
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg


# лаковая подложка стола (фетр + линия 1 px gold700 35 %): рисуется кодом, без бликов
static func felt(r: Rect2, hero: String) -> Control:
	var c: = Control.new()
	c.name = "Felt"
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var deep: Color = accent(hero)[2]
	c.draw.connect(func():
		var rr: = Rect2(Vector2.ZERO, c.size)
		var sb: = StyleBoxFlat.new()
		sb.bg_color = TOK.night800.lerp(deep, 0.18)
		sb.set_corner_radius_all(4)
		sb.border_color = Color(TOK.gold700, 0.35)
		sb.set_border_width_all(1)
		c.draw_style_box(sb, rr)
		# мягкое пятно лампы сверху
		for k in 6:
			var t: = float(k) / 6.0
			c.draw_circle(Vector2(c.size.x * 0.5, -c.size.y * 0.15), c.size.x * (0.75 - t * 0.1), Color(1, 0.93, 0.8, 0.012)))
	return c


static func primary(text: String, w: = 560.0) -> Button:
	var b: = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(w, 104)
	b.custom_minimum_size = b.size
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = TOK.rose700 if st == "pressed" else (TOK.night600 if st == "disabled" else TOK.rose500)
		sb.set_corner_radius_all(52)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_override("font", font("title", 600))
	b.add_theme_font_size_override("font_size", 32)
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, TOK.night900)
	b.add_theme_color_override("font_disabled_color", TOK.paper700)
	b.pivot_offset = b.size * 0.5
	b.set_meta("ux_role", "primary")
	b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
	return b


# «дыхание» главной кнопки — единственная бесконечная анимация UI (UX §6.7)
static func breathe(b: Control) -> void:
	var tw: = b.create_tween().set_loops()
	tw.tween_property(b, "scale", Vector2(0.985, 0.985), 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)


static func secondary(text: String, w: = 360.0, arrow: = true) -> Button:
	var b: = Button.new()
	b.text = text + ("  ›" if arrow else "")
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(w, 80)
	b.custom_minimum_size = b.size
	b.add_theme_font_override("font", font("body", 800))
	b.add_theme_font_size_override("font_size", 22)
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, TOK.paper100)
	b.add_theme_color_override("font_disabled_color", TOK.paper700)
	b.pivot_offset = b.size * 0.5
	b.set_meta("ux_role", "secondary")
	b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
	return b


static func icon_button(kind: String, pos: Vector2, col: = TOK.paper300) -> Button:
	var b: = Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.size = Vector2(80, 80)
	b.custom_minimum_size = Vector2(80, 80)
	b.set_meta("ux_role", "tertiary")
	var ic: = V10MjBridgeIcon.new(kind, col)
	ic.position = Vector2(16, 16)
	ic.size = Vector2(48, 48)
	b.add_child(ic)
	b.pivot_offset = Vector2(40, 40)
	b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
	return b


# нижний лист (одно окно, не поверх другого листа); dim — притушить экран под ним
static func sheet(layer: Control, vw: Vector2, height: float) -> Panel:
	for c in layer.get_children():
		c.queue_free()
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: = ColorRect.new()
	dim.color = Color(TOK.night900, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var p: = Panel.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = TOK.night700
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.border_color = Color(TOK.gold700, 0.35)
	sb.border_width_top = 1
	p.add_theme_stylebox_override("panel", sb)
	p.size = Vector2(vw.x, height)
	p.position = Vector2(0, vw.y)
	layer.add_child(p)
	var tw: = p.create_tween().set_parallel()
	tw.tween_property(p, "position:y", vw.y - height, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(dim, "color:a", 0.45, 0.22)
	return p


static func close_sheet(layer: Control) -> void:
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in layer.get_children():
		c.queue_free()


static func stars_row(n: int, of: = 3, size: = 44.0) -> Control:
	var row: = Control.new()
	row.size = Vector2(of * (size + 10.0), size)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in of:
		var ic: = V10MjBridgeIcon.new("star", TOK.gold300 if k < n else Color(TOK.paper700, 0.6))
		ic.size = Vector2(size, size)
		ic.position = Vector2(k * (size + 10.0), 0)
		row.add_child(ic)
	return row
