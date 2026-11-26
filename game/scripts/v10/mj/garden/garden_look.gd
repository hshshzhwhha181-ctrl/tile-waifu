class_name V10MjGardenLook
extends RefCounted

# Вид Сада 2.0: токены «Тишина и лак» (UX_RULES §6.2; класс DS появится в polish — тогда TOK читает DS), акценты
# героинь, шрифты, арка окна и два стола — дневной и «Ночной стол» (MODES §4.9) — поверх стола героини дорожки look
# (V10MjTables / V10MjTableView / V10MjTileMaterial).
#
# Ночной стол: тёмная палитра (дальний слой и сукно темнее), лампа над столом (тёплое пятно на сукне и сама лампа
# в полосе), фишки бликуют теплее (свет лампы для материала), за окном дождь (частицы стола — «rain»).

const TOK: = {
	"night900": V10DS.NIGHT_900, "night800": V10DS.NIGHT_800, "night700": V10DS.NIGHT_700, "night600": V10DS.NIGHT_600,
	"paper100": V10DS.PAPER_100, "paper300": V10DS.PAPER_300, "paper500": V10DS.PAPER_500, "paper700": V10DS.PAPER_700,
	"gold300": V10DS.GOLD_300, "gold500": V10DS.GOLD_500, "gold700": V10DS.GOLD_700,
	"rose500": V10DS.ROSE_500, "rose700": V10DS.ROSE_700, "jade300": V10DS.JADE_300, "jade500": V10DS.JADE_500,
	"ember": V10DS.EMBER,
}

# акцент героини: accent / glow / deep (≤ 10 % пикселей) — алиас к V10DS.HEROES
const ACCENT: = {
	"mc": [V10DS.HEROES.mc.accent, V10DS.HEROES.mc.glow, V10DS.HEROES.mc.deep],
	"rin": [V10DS.HEROES.rin.accent, V10DS.HEROES.rin.glow, V10DS.HEROES.rin.deep],
	"hana": [V10DS.HEROES.hana.accent, V10DS.HEROES.hana.glow, V10DS.HEROES.hana.deep],
	"yue": [V10DS.HEROES.yue.accent, V10DS.HEROES.yue.glow, V10DS.HEROES.yue.deep],
	"nova": [V10DS.HEROES.nova.accent, V10DS.HEROES.nova.glow, V10DS.HEROES.nova.deep],
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
