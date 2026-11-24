class_name V10MjTriplesLook
extends RefCounted

# Вид Троек: токены «Тишина и лак» (UX_RULES §6.2; класс DS появится в polish — тогда TOK читает DS), пять рамок
# лотка (9-patch из Higgsfield, gpt_image_2_6 xhigh, прозрачный фон) и стол героини.
# Рамка выбирается: args.look.tray (ключ или {tex, well, size}) → рамка партнёрши → лаковая полка.

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

# рамки лотка: size — размер текстуры, well — внутренняя «полка» (x0, y0, x1, y1) в пикселях текстуры
const TRAYS: = {
	"lacquer": {"name": "Лаковая полка", "tex": "res://assets/v10/mj/triples/tray_lacquer.webp",
		"size": Vector2(1331, 186), "well": Rect2(99, 40, 1134, 116), "job": "0637e7e0-87d3-4f8b-970c-3b69ca584494"},
	"tea": {"name": "Чайный поднос", "tex": "res://assets/v10/mj/triples/tray_tea.webp",
		"size": Vector2(1340, 233), "well": Rect2(122, 54, 1095, 137), "job": "83923632-d9e0-42e4-bcb1-467832c96840"},
	"track": {"name": "Беговая дорожка", "tex": "res://assets/v10/mj/triples/tray_track.webp",
		"size": Vector2(1342, 282), "well": Rect2(130, 70, 1084, 149), "job": "14ee050c-1aa4-45ef-932e-653fb89e2112"},
	"moon": {"name": "Лунная ладья", "tex": "res://assets/v10/mj/triples/tray_moon.webp",
		"size": Vector2(1339, 251), "well": Rect2(62, 122, 1213, 84), "job": "b402f73c-36e9-4eea-bb04-2c865e298ed7"},
	"neon": {"name": "Неоновая шина", "tex": "res://assets/v10/mj/triples/tray_neon.webp",
		"size": Vector2(1344, 186), "well": Rect2(120, 31, 1103, 122), "job": "e761e992-004b-4d3d-ae1c-2e036d8bdbed"},
}
const HERO_TRAY: = {"mc": "lacquer", "rin": "tea", "hana": "track", "yue": "moon", "nova": "neon"}
# стол героини (тема V6BoardTable)
const HERO_TABLE: = {"mc": "default", "rin": "bg_teahouse", "hana": "bg_festival", "yue": "bg_palace", "nova": "bg_neon"}


static func accent(hero: String) -> Array:
	return ACCENT.get(hero, ACCENT.mc)


static func tray_def(args: Dictionary, hero: String) -> Dictionary:
	var lk = args.get("look", {})
	if lk is Dictionary:
		var t = lk.get("tray")
		if t is String and TRAYS.has(t):
			return TRAYS[t]
		if t is Dictionary and t.has("tex"):
			return t
	return TRAYS[HERO_TRAY.get(hero, "lacquer")]


# Раскладка лотка в ширину avail: шаг ячейки pitch (88 по спеке, меньше — если рамка не помещается),
# масштаб рамки k (уголки рамки не тянутся — 9-patch масштабируется целиком, тянется только середина полки).
# Возвращает {k, pitch, tile_w, frame: Rect2 (в пикселях экрана относительно центра), well: Rect2}
static func fit(def: Dictionary, avail_w: float, cells: int, want_pitch: = 88.0) -> Dictionary:
	var size: Vector2 = def.size
	var well: Rect2 = def.well
	var caps: = well.position.x + (size.x - well.end.x)
	var pitch: = want_pitch
	var k: = 0.0
	# высота полки ≈ 0.86 высоты фишки, но рамка не выше 200 px
	for attempt in 12:
		var tile_h: = pitch * Tile.TH / Tile.TW
		k = minf(tile_h * 0.86 / well.size.y, 200.0 / size.y)
		var need: = caps * k + cells * pitch + 12.0
		if need <= avail_w:
			break
		# сначала ужимаем рамку (не меньше 0.45 от «правильного»), потом шаг ячейки
		var k_fit: = (avail_w - cells * pitch - 12.0) / caps
		if k_fit >= k * 0.62:
			k = k_fit
			break
		pitch -= 2.0
	var well_w: = cells * pitch + 12.0
	var frame_w: = caps * k + well_w
	var frame_h: = size.y * k
	var frame: = Rect2(-frame_w * 0.5, -frame_h * 0.5, frame_w, frame_h)
	var wl: = Rect2(frame.position.x + well.position.x * k, frame.position.y + well.position.y * k, well_w, well.size.y * k)
	return {"k": k, "pitch": pitch, "frame": frame, "well": wl, "tile_w": pitch - 6.0}


# узел рамки: NinePatchRect в пикселях текстуры, масштабированный на k (уголки не искажаются)
static func make_frame(def: Dictionary, f: Dictionary) -> Control:
	var tex: Texture2D = null
	if ResourceLoader.exists(String(def.tex)):
		tex = load(String(def.tex))
	var k: float = f.k
	var size: Vector2 = def.size
	var well: Rect2 = def.well
	if tex == null:
		var p: = Panel.new()
		var sb: = StyleBoxFlat.new()
		sb.bg_color = TOK.night800
		sb.border_color = TOK.gold700
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(24)
		p.add_theme_stylebox_override("panel", sb)
		p.position = (f.frame as Rect2).position
		p.size = (f.frame as Rect2).size
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return p
	var np: = NinePatchRect.new()
	np.texture = tex
	np.patch_margin_left = int(well.position.x + 8)
	np.patch_margin_right = int(size.x - well.end.x + 8)
	np.patch_margin_top = 0
	np.patch_margin_bottom = 0
	np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	np.size = Vector2((f.frame as Rect2).size.x / k, size.y)
	np.scale = Vector2(k, k)
	np.position = (f.frame as Rect2).position
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	np.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return np


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
