class_name V10MjCubeStyle
extends RefCounted

# Вид Куба: токены «Тишина и лак» (UX_RULES §6.2; класс DS появится в polish — тогда TOK читает DS), акценты
# героинь, шрифты трёх голосов (UX §6.3) и фон: её стол из дорожки look (дальний слой far_<героиня>.webp), если он
# есть, иначе градиент ночи с её цветом.

const TOK: = {
	"night900": Color("121014"), "night800": Color("1B171C"), "night700": Color("26212A"), "night600": Color("332C36"),
	"paper100": Color("F5EAD8"), "paper300": Color("DDD2C4"), "paper500": Color("B3A89C"), "paper700": Color("7E756D"),
	"gold300": Color("F1D9A0"), "gold500": Color("E8C47E"), "gold700": Color("A87B3A"),
	"rose500": Color("D796A5"), "rose700": Color("9A4F66"), "jade300": Color("A9D9C4"), "jade500": Color("5B9580"),
	"ember": Color("E07A7A"),
}

# accent / glow / deep (≤ 10 % пикселей)
const ACCENT: = {
	"mc": [Color("ff8fb8"), Color("ffd0e0"), Color("6a1f45")],
	"rin": [Color("4fbf9f"), Color("bff0e0"), Color("16514a")],
	"hana": [Color("ffb35c"), Color("ffe0b8"), Color("7a3a0c")],
	"yue": [Color("c8b6ff"), Color("ece6ff"), Color("3f2f7a")],
	"nova": [Color("4fe3ff"), Color("c8f6ff"), Color("0f3a5a")],
}
const FAR: = "res://assets/v10/mj/look/tables/far_%s.webp"
const FAR_HOUSE: = "res://assets/v10/mj/look/tables/far_house.webp"
# фишка-подпись героини (MODES §3.4.1): её символ в колоде (как у столов look: веер/чаша/солнце/луна/кристалл)
const SIGNATURE: = {"mc": 0, "rin": 21, "hana": 3, "yue": 7, "nova": 24}


static func accent(hero: String) -> Array:
	return ACCENT.get(hero, ACCENT.mc)


static func font(kind: String, weight: = 700) -> Font:
	if kind == "italic":
		var ts: = TextServerManager.get_primary_interface()
		var fv: = FontVariation.new()
		fv.base_font = load("res://assets/fonts/playfair-i-cyr.woff2")
		fv.variation_opentype = {ts.name_to_tag("wght"): weight}
		var fb: = FontVariation.new()
		fb.base_font = load("res://assets/fonts/playfair-i-lat.woff2")
		fb.variation_opentype = {ts.name_to_tag("wght"): weight}
		fv.fallbacks = [fb]
		return fv
	return UI.font("title" if kind == "title" else "body", weight)


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


static func shadow(l: Label, a: = 0.6) -> void:
	l.label_settings.shadow_color = Color(0, 0, 0, a)
	l.label_settings.shadow_size = 8
	l.label_settings.shadow_offset = Vector2(0, 2)


# her table (look lane) as the backdrop: the far layer, cover-fit and dimmed; null if the art is absent
static func table_tex(hero: String) -> Texture2D:
	var p: = FAR % hero
	if ResourceLoader.exists(p):
		return load(p)
	if ResourceLoader.exists(FAR_HOUSE):
		return load(FAR_HOUSE)
	return null


static func night_gradient(hero: String) -> GradientTexture2D:
	var g: = Gradient.new()
	var a: Array = accent(hero)
	g.set_color(0, Color(a[2]).darkened(0.5).lerp(TOK.night900, 0.3))
	g.set_color(1, TOK.night900)
	g.add_point(0.3, TOK.night800)
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.8, 0.0)
	gt.fill_to = Vector2(0.4, 1.0)
	gt.width = 64
	gt.height = 128
	return gt


# soft pool of her light under the figure (radial, additive look without additive blending)
static func pool(hero: String) -> GradientTexture2D:
	var g: = Gradient.new()
	var c: Color = accent(hero)[0]
	g.set_color(0, Color(c, 0.22))
	g.set_color(1, Color(c, 0.0))
	g.add_point(0.5, Color(c, 0.08))
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	return gt
