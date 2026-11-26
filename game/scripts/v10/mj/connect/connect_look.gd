class_name V10MjConnectLook
extends RefCounted

# Вид Связей: токены дизайн-системы «Тишина и лак» (алиас V10DS), нити героинь (MODES §4.3),
# шрифты и общие элементы интерфейса (UX_RULES §6, HUD_V2 §2–§3).

const TOK: = {
	"night900": V10DS.NIGHT_900, "night800": V10DS.NIGHT_800, "night700": V10DS.NIGHT_700, "night600": V10DS.NIGHT_600,
	"paper100": V10DS.PAPER_100, "paper300": V10DS.PAPER_300, "paper500": V10DS.PAPER_500, "paper700": V10DS.PAPER_700,
	"gold300": V10DS.GOLD_300, "gold500": V10DS.GOLD_500, "gold700": V10DS.GOLD_700,
	"rose300": V10DS.ROSE_300, "rose500": V10DS.ROSE_500, "rose700": V10DS.ROSE_700,
	"jade300": V10DS.JADE_300, "jade500": V10DS.JADE_500, "ember": V10DS.EMBER,
}

const ACCENT: = {
	"mc": [V10DS.HEROES.mc.accent, V10DS.HEROES.mc.glow, V10DS.HEROES.mc.deep],
	"rin": [V10DS.HEROES.rin.accent, V10DS.HEROES.rin.glow, V10DS.HEROES.rin.deep],
	"hana": [V10DS.HEROES.hana.accent, V10DS.HEROES.hana.glow, V10DS.HEROES.hana.deep],
	"yue": [V10DS.HEROES.yue.accent, V10DS.HEROES.yue.glow, V10DS.HEROES.yue.deep],
	"nova": [V10DS.HEROES.nova.accent, V10DS.HEROES.nova.glow, V10DS.HEROES.nova.deep],
}

# Её нить (MODES §4.3): красная шёлковая лента у Рин, розовая ветвь сакуры у Маджонг-тян,
# солнечный трек у Ханы, лунный луч у Юэ, неон-трасса у Новы.
const THREADS: = {
	"rin": {"name": "Шёлковая лента", "line": Color("#E05A6B"), "glow": Color("#FFC2CA"), "sfx": 1, "kind": "silk"},
	"mc": {"name": "Ветвь сакуры", "line": V10DS.HEROES.mc.accent, "glow": V10DS.HEROES.mc.glow, "sfx": 2, "kind": "sakura"},
	"hana": {"name": "Солнечный трек", "line": V10DS.HEROES.hana.accent, "glow": V10DS.HEROES.hana.glow, "sfx": 3, "kind": "sun"},
	"yue": {"name": "Лунный луч", "line": V10DS.HEROES.yue.accent, "glow": V10DS.HEROES.yue.glow, "sfx": 4, "kind": "moon"},
	"nova": {"name": "Неон-трасса", "line": V10DS.HEROES.nova.accent, "glow": V10DS.HEROES.nova.glow, "sfx": 5, "kind": "neon"},
}

const SIGNATURE: = {"mc": 0, "rin": 21, "hana": 3, "yue": 7, "nova": 24}
const CHAPTER_HOST: = ["rin", "yue", "mc", "hana", "rin", "nova", "yue", "mc", "rin"]
const HERO_TABLE: = {"mc": "default", "rin": "bg_teahouse", "hana": "bg_festival", "yue": "bg_palace", "nova": "bg_neon"}

static var _fonts: = {}


static func accent(hero: String) -> Array:
	return ACCENT.get(hero, ACCENT.rin)


static func thread_for(hero: String) -> Dictionary:
	if THREADS.has(hero):
		return THREADS[hero]
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree and tree.root else null
	if g and g.get("HEROES") is Dictionary and (g.HEROES as Dictionary).has(hero):
		var c: Color = g.HEROES[hero].color
		return {"name": "Нить героини", "line": c, "glow": c.lightened(0.35), "sfx": 1, "kind": "silk"}
	return THREADS.rin


static func font(kind: String, weight: = 700) -> Font:
	var key: = "%s_%d" % [kind, weight]
	if _fonts.has(key):
		return _fonts[key]
	var f: Font
	if kind == "italic":
		var ts: = TextServerManager.get_primary_interface()
		var fv: = FontVariation.new()
		fv.base_font = load("res://assets/fonts/playfair-i-cyr.woff2")
		fv.variation_opentype = {ts.name_to_tag("wght"): weight}
		var fb: = FontVariation.new()
		fb.base_font = load("res://assets/fonts/playfair-i-lat.woff2")
		fb.variation_opentype = {ts.name_to_tag("wght"): weight}
		fv.fallbacks = [fb]
		f = fv
	else:
		f = UI.font("title" if kind == "title" else "body", weight)
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


static func shadow(l: Label, a: = 0.55) -> Label:
	l.label_settings.shadow_color = Color(V10DS.SHADOW, a)
	l.label_settings.shadow_offset = Vector2(0, 2)
	l.label_settings.shadow_size = 6
	return l


static func primary(text: String, w: = 560.0, fx_min: = false) -> Button:
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
	if not fx_min:
		var tw: = b.create_tween().set_loops()
		tw.tween_property(b, "scale", Vector2(0.985, 0.985), 1.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)
	return b


static func secondary(text: String, w: = 320.0, arrow: = true) -> Button:
	var b: = Button.new()
	b.text = text + ("  ›" if arrow else "")
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(w, 80)
	b.custom_minimum_size = Vector2(maxi(80, int(w)), 80)
	b.add_theme_font_override("font", font("body", 800))
	b.add_theme_font_size_override("font_size", 22)
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, TOK.paper100)
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
	var ic: = V10MjConnectIcon.new(kind, col)
	ic.position = Vector2(16, 16)
	ic.size = Vector2(48, 48)
	b.add_child(ic)
	b.pivot_offset = Vector2(40, 40)
	b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
	return b


static func sheet(layer: Control, vw: Vector2, height: float, fx_min: = false) -> Panel:
	for c in layer.get_children():
		c.queue_free()
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: = ColorRect.new()
	dim.color = Color(TOK.night900, 0.45 if fx_min else 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var p: = Panel.new()
	p.name = "Sheet"
	var sb: = StyleBoxFlat.new()
	sb.bg_color = TOK.night700
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.border_color = V10DS.hair()
	sb.border_width_top = 1
	p.add_theme_stylebox_override("panel", sb)
	p.size = Vector2(vw.x, height)
	p.position = Vector2(0, vw.y - height if fx_min else vw.y)
	layer.add_child(p)
	if not fx_min:
		var tw: = p.create_tween().set_parallel()
		tw.tween_property(p, "position:y", vw.y - height, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tw.tween_property(dim, "color:a", 0.45, 0.22)
	return p


static func close_sheet(layer: Control) -> void:
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in layer.get_children():
		c.queue_free()
