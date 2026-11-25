class_name V10MjGardenLook
extends RefCounted

# Вид Сада 2.0: токены «Тишина и лак» (UX_RULES §6.2; класс DS появится в polish — тогда TOK читает DS), акценты
# героинь, шрифты, арка окна и два стола — дневной и «Ночной стол» (MODES §4.9) — поверх стола героини дорожки look
# (V10MjTables / V10MjTableView / V10MjTileMaterial).
#
# Ночной стол: тёмная палитра (дальний слой и сукно темнее), лампа над столом (тёплое пятно на сукне и сама лампа
# в полосе), фишки бликуют теплее (свет лампы для материала), за окном дождь (частицы стола — «rain»).

const TOK: = {
	"night900": Color("121014"), "night800": Color("1B171C"), "night700": Color("26212A"), "night600": Color("332C36"),
	"paper100": Color("F5EAD8"), "paper300": Color("DDD2C4"), "paper500": Color("B3A89C"), "paper700": Color("7E756D"),
	"gold300": Color("F1D9A0"), "gold500": Color("E8C47E"), "gold700": Color("A87B3A"),
	"rose500": Color("D796A5"), "rose700": Color("9A4F66"), "jade300": Color("A9D9C4"), "jade500": Color("5B9580"),
	"ember": Color("E07A7A"),
}

# акцент героини: accent / glow / deep (≤ 10 % пикселей)
const ACCENT: = {
	"mc": [Color("ff8fb8"), Color("ffd0e0"), Color("6a1f45")],
	"rin": [Color("4fbf9f"), Color("bff0e0"), Color("16514a")],
	"hana": [Color("ffb35c"), Color("ffe0b8"), Color("7a3a0c")],
	"yue": [Color("c8b6ff"), Color("ece6ff"), Color("3f2f7a")],
	"nova": [Color("4fe3ff"), Color("c8f6ff"), Color("0f3a5a")],
}

const NIGHT_LAMP: = Color("ffc98a")
const NIGHT_CLOTH: = Color(0.58, 0.55, 0.66)
const NIGHT_FAR_DARK: = 0.86
const DAY_FAR_DARK: = 0.5


static func accent(hero: String) -> Array:
	return ACCENT.get(hero, ACCENT.yue)


# стол Сада: стол героини (S/SSR — её весь, A — дом в её свете), ночью — тёмный с тёплой лампой и дождём
static func theme(hero: String, night: bool) -> Dictionary:
	var th: = V10MjTables.theme_for(hero)
	th = th.duplicate(true)
	if night:
		th.lamp = {"uv": Vector2(0.5, 0.04), "col": NIGHT_LAMP, "k": 0.52}
		th.cloth.tint = Color(th.cloth.get("tint", Color.WHITE)) * NIGHT_CLOTH
		th.cloth.tint.a = 1.0
		th.amb = {"sfx": "rain", "fx": "rain", "fx_col": Color("b9c6e6")}
	th["garden_night"] = night
	return th


# свет для материала фишек: днём — лампа стола, ночью — тёплая лампа над серединой, блик сильнее
static func light(th: Dictionary, board_rect: Rect2, night: bool) -> Dictionary:
	var lt: = V10MjTables.light(th, board_rect)
	if night:
		lt.lamp = board_rect.position + board_rect.size * Vector2(0.5, -0.08)
		lt.lamp_col = NIGHT_LAMP
		lt.gloss = 1.3
		lt.ambient = Color(0.06, 0.045, 0.04)
	return lt


static func far_dark(night: bool) -> float:
	return NIGHT_FAR_DARK if night else DAY_FAR_DARK


# контур арки: прямоугольник с полукруглым верхом; closed = false — без нижней кромки
static func arch_points(r: Rect2, seg: = 24, closed: = true) -> PackedVector2Array:
	var pts: = PackedVector2Array()
	var rad: = r.size.x * 0.5
	var cy: = r.position.y + rad
	pts.append(Vector2(r.position.x, r.end.y))
	pts.append(Vector2(r.position.x, cy))
	for k in range(1, seg):
		var an: = PI + PI * k / seg
		pts.append(Vector2(r.position.x + rad + cos(an) * rad, cy + sin(an) * rad))
	pts.append(Vector2(r.end.x, cy))
	pts.append(Vector2(r.end.x, r.end.y))
	if closed:
		pts.append(pts[0])
	return pts


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
