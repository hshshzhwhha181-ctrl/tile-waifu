extends Control

# Лунный стол на троих — экран партии (контракт MODES §7.1: setup(main, args), сигнал finished(result)).
# Если в дереве уже есть V10MjRiichiScreen (дорожка riichi), хаб может открыть его с seats=3 — см. README;
# этот экран — самостоятельная раскладка §4.6/§4.7 для портрета: соперница напротив убрана,
# боковые сбросы повёрнуты на ±120°, сверху — Лунная подставка для северов, справа сверху — табло события.
#
# args: seed, presence, event (bool, «Хозяйка против двоих»), partner (id), host (id, "yue"),
#       rival (id третьей), hall ("study"|"bamboo"), names ("ru"|"jp"), fast (без пауз), demo (ИИ за игрока),
#       look (материал фишек, необязательно), sfx (необязательно), tsumo_loss (bool).

signal finished(result: Dictionary)

const TOK: = {
	"n900": Color("121014"), "n800": Color("1b171c"), "n700": Color("26212a"), "n600": Color("332c36"),
	"p100": Color("f5ead8"), "p300": Color("ddd2c4"), "p500": Color("b3a89c"), "p700": Color("7e756d"),
	"g300": Color("f1d9a0"), "g500": Color("e8c47e"), "g700": Color("a87b3a"),
	"r500": Color("d796a5"), "r700": Color("9a4f66"), "j300": Color("a9d9c4"), "j500": Color("5b9580"),
	"ember": Color("e07a7a"), "moon": Color("c8b6ff"),
}
const ACCENT: = {"mc": "ff8fb8", "rin": "4fbf9f", "hana": "ffb35c", "yue": "c8b6ff", "nova": "4fe3ff"}
const NAMES: = {"mc": "Маджонг-тян", "rin": "Рин", "hana": "Хана", "yue": "Юэ", "nova": "Нова"}
const TILE_DIR: = "res://assets/v08/table/"
const EMO_DIR: = "res://assets/v08/emotions/"
const ASSET_DIR: = "res://assets/v10/mj/sanma/"
const ME: = 0
const PORTRAIT_REGION: = Rect2(150, 80, 300, 300)

var seats: = 3
var main = null
var args: = {}
var r: V10MjSanmaRound
var L: V10MjSanmaLandlord = null
var presence = null
var ids: = ["mc", "yue", "hana"]
var host_seat: = 1
var fast: = false
var demo: = false
var names_ru: = true
var event_on: = false
var t_start: = 0

var waiting: = false
var cur_ask: = {}
var sel: = -1
var riichi_pick: = false
var delay: = 0.0
var paused: = false
var sheet_open: = false
var match_done: = false
var final_res: = {}
var hand_best_new: = false
var ev_best_mult: = 0

# раскладка
var W: = 720.0
var H: = 1280.0
var ex: = 0.0
var C: = Vector2(360, 500)
var hand_y: = 980.0
var tile_w: = 46.0
var rects: = {}

# узлы
var bg: TextureRect
var layer_table: Control
var layer_fx: Control
var layer_ui: Control
var stand: Control
var host_scene: TextureRect = null
var center_lbl: Label
var wall_lbl: Label
var dora_box: HBoxContainer
var sticks_lbl: Label
var ponds: = []          # Control на место (место 0 — прямое, 1/2 — повёрнуты)
var meld_boxes: = []
var seat_ui: = []        # {root, portrait, face, name, score, wind, riichi}
var hand_box: Control
var btn_row: HBoxContainer
var buttons: = {}
var event_board: Control = null
var ev_mult_lbl: Label
var ev_score_lbl: Label
var ev_cap_lbl: Label
var subtitle: Label
var ribbon: ColorRect
var ribbon_lbl: Label
var sheet: Control = null
var hint_lbl: Label
var pause_btn: Control
var music: AudioStreamPlayer
var voice: AudioStreamPlayer
var kita_slots: = [[], [], []]
var _tex_cache: = {}
var _fonts: = {}
var _last_voice: = -100.0
var _kita_line_i: = 0
var _tw_count: = 0


# ── вход ─────────────────────────────────────────────────────────────────────────────────────────────────

func setup(main_, a: Dictionary) -> void:
	main = main_
	args = a
	fast = bool(a.get("fast", false))
	demo = bool(a.get("demo", false))
	event_on = bool(a.get("event", false))
	names_ru = String(a.get("names", "ru")) == "ru"
	presence = a.get("presence", null)
	if presence == null:
		presence = V10MjSanmaPresenceProbe.new()
	var partner: String = String(a.get("partner", _g_partner()))
	var host: String = String(a.get("host", "yue"))
	var rival: String = String(a.get("rival", ""))
	if rival == "" or rival == host or rival == partner:
		for h in ["hana", "rin", "nova", "mc"]:
			if h != host and h != partner:
				rival = h
				break
	if partner == host:
		partner = "mc"
	ids = [partner, host, rival]
	host_seat = 1
	var sd: int = int(a.get("seed", randi()))
	r = V10MjSanmaRound.new()
	var pl: = []
	for i in 3:
		pl.append({"id": ids[i], "ctl": "ai" if (i != ME or demo) else "human"})
	r.setup({"seed": sd, "players": pl, "tsumo_loss": bool(a.get("tsumo_loss", false)), "dealer": int(a.get("dealer", -1)) if int(a.get("dealer", -1)) >= 0 else sd % 3})
	if a.get("hall", "bamboo") == "study":
		V8AI.room_skill = 0.75
	if event_on:
		L = V10MjSanmaLandlord.new().setup(host_seat, host, sd)
	t_start = Time.get_ticks_msec()
	if is_inside_tree():
		_build()

func _ready() -> void:
	if r != null and layer_table == null:
		_build()

func _g_partner() -> String:
	var g = get_node_or_null("/root/G")
	if g != null and "S" in g:
		return String(g.S.get("partner", "mc"))
	return "mc"

func _g_bool(k: String, d: bool) -> bool:
	var g = get_node_or_null("/root/G")
	if g != null and "S" in g:
		return bool(g.S.get(k, d))
	return d


# ── шрифты и ассеты ─────────────────────────────────────────────────────────────────────────────────────

func font(kind: String, weight: = 800) -> FontVariation:
	var key: = "%s%d" % [kind, weight]
	if _fonts.has(key):
		return _fonts[key]
	var files: Array = {"body": ["nunito-cyr", "nunito-lat"], "title": ["playfair-cyr", "playfair-lat"], "italic": ["playfair-i-cyr", "playfair-i-lat"]}[kind]
	var ts: = TextServerManager.get_primary_interface()
	var fv: = FontVariation.new()
	fv.base_font = load("res://assets/fonts/%s.woff2" % files[0])
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	var fb: = FontVariation.new()
	fb.base_font = load("res://assets/fonts/%s.woff2" % files[1])
	fb.variation_opentype = {ts.name_to_tag("wght"): weight}
	fv.fallbacks = [fb]
	_fonts[key] = fv
	return fv

func lbl(text: String, sz: int, col: Color, kind: = "body", weight: = 800) -> Label:
	var l: = Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind, weight))
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]

func tile_tex(t: int) -> Texture2D:
	return tex(TILE_DIR + "t%02d.png" % V8Mj.face(t))

func accent(seat: int) -> Color:
	return Color(String(ACCENT.get(ids[seat], "c8b6ff")))

func emo_tex(seat: int, emo: String) -> Texture2D:
	var t: = tex(EMO_DIR + "%s_%s.webp" % [ids[seat], emo])
	if t == null:
		return null
	var at: = AtlasTexture.new()
	at.atlas = t
	at.region = PORTRAIT_REGION
	return at


# ── построение ──────────────────────────────────────────────────────────────────────────────────────────

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vs: = get_viewport_rect().size if size.x < 2 else size
	W = vs.x
	H = vs.y
	ex = maxf(0.0, H - 1280.0)
	C = Vector2(W * 0.5, 500.0 + ex)
	hand_y = 980.0 + ex

	bg = TextureRect.new()
	# событие «Хозяйка против двоих» — полнолуние (вторая скатерть), обычный стол — серп
	bg.texture = tex(ASSET_DIR + ("cloth/moon_cloth_event.webp" if event_on else "cloth/moon_cloth.webp"))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(W, H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	if bg.texture == null:
		var g: = ColorRect.new()
		g.color = TOK.n900
		g.size = Vector2(W, H)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(g)
	var shade: = _vignette()
	add_child(shade)

	layer_table = Control.new()
	layer_table.size = Vector2(W, H)
	layer_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer_table)
	layer_ui = Control.new()
	layer_ui.size = Vector2(W, H)
	layer_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer_ui)
	layer_fx = Control.new()
	layer_fx.size = Vector2(W, H)
	layer_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer_fx)

	_build_host_scene()
	_build_stand()
	_build_center()
	_build_seats()
	_build_ponds()
	_build_hand_area()
	_build_band()
	if event_on:
		_build_event_board()
	_build_overlays()
	_audio()
	_register_sacred()
	_refresh_all()

func _vignette() -> Control:
	var tr: = TextureRect.new()
	var gt: = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.42)
	gt.fill_to = Vector2(1.05, 1.05)
	var gr: = Gradient.new()
	gr.set_color(0, Color(0.07, 0.06, 0.1, 0.0))
	gr.set_color(1, Color(0.04, 0.03, 0.06, 0.62))
	gt.gradient = gr
	gt.width = 256
	gt.height = 256
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.size = Vector2(W, H)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

# На вытянутых экранах (9:20+) лишняя высота — сцена хозяйки над столом.
func _build_host_scene() -> void:
	if ex < 160:
		return
	var t: = tex(EMO_DIR + "%s_shy.webp" % ids[host_seat])
	if t == null:
		return
	host_scene = TextureRect.new()
	host_scene.texture = t
	host_scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host_scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var h: = minf(ex + 120.0, 520.0)
	host_scene.size = Vector2(h * 600.0 / 765.0, h)
	host_scene.position = Vector2(W * 0.5 - host_scene.size.x * 0.5, 8.0)
	host_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# мягкое растворение снизу, чтобы она «стояла» за подставкой
	var mat: = ShaderMaterial.new()
	var sh: = Shader.new()
	sh.code = "shader_type canvas_item; uniform float fade = 0.32; void fragment(){ vec4 c = texture(TEXTURE, UV); float a = smoothstep(1.0, 1.0 - fade, UV.y); COLOR = vec4(c.rgb, c.a * a); }"
	mat.shader = sh
	host_scene.material = mat
	host_scene.pivot_offset = host_scene.size * Vector2(0.5, 0.9)
	layer_table.add_child(host_scene)
	var glow: = TextureRect.new()
	var gt: = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gr: = Gradient.new()
	gr.set_color(0, Color(TOK.moon, 0.28))
	gr.set_color(1, Color(TOK.moon, 0.0))
	gt.gradient = gr
	glow.texture = gt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(h * 1.1, h * 1.1)
	glow.position = Vector2(W * 0.5 - glow.size.x * 0.5, host_scene.position.y - h * 0.05)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_table.add_child(glow)
	layer_table.move_child(glow, 0)

# Лунная подставка для северов: лежащий серп-«колыбель» и три гнезда над ним
# (слева — место 2, в центре — ты, справа — место 1). Рисуется кодом, без арта.
const STAND_W: = 360.0
const STAND_H: = 96.0
const STAND_GX: = [62.0, 180.0, 298.0]   # центры гнёзд по x (место 2, ты, место 1)

func _build_stand() -> void:
	stand = Control.new()
	stand.size = Vector2(STAND_W, STAND_H)
	var top: = ex + 14.0
	if host_scene != null:
		top = host_scene.position.y + host_scene.size.y - 86.0
	stand.position = Vector2(W * 0.5 - STAND_W * 0.5, top)
	stand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stand.draw.connect(_draw_stand)
	layer_table.add_child(stand)
	rects.stand = Rect2(stand.position, stand.size)

func _crescent_y(x: float, r: float, cy: float) -> float:
	var dx: = x - STAND_W * 0.5
	return cy + sqrt(maxf(0.0, r * r - dx * dx))

func _draw_stand() -> void:
	var moon: Color = TOK.moon
	var outer: = PackedVector2Array()
	var inner: = PackedVector2Array()
	var n: = 40
	for i in n + 1:
		var x: = 8.0 + (STAND_W - 16.0) * i / float(n)
		outer.append(Vector2(x, _crescent_y(x, 300.0, -214.0)))
		inner.append(Vector2(x, _crescent_y(x, 300.0, -226.0)))
	var poly: = PackedVector2Array()
	poly.append_array(outer)
	var inv: = inner.duplicate()
	inv.reverse()
	poly.append_array(inv)
	# тень-ложе и сам серп
	var bed: = PackedVector2Array()
	for p in inner:
		bed.append(p)
	for i in range(n, -1, -1):
		var x2: = 8.0 + (STAND_W - 16.0) * i / float(n)
		bed.append(Vector2(x2, _crescent_y(x2, 300.0, -226.0) - 46.0))
	stand.draw_colored_polygon(bed, Color(TOK.n900, 0.55))
	stand.draw_colored_polygon(poly, Color(moon, 0.42))
	stand.draw_polyline(outer, Color(TOK.g500, 0.75), 1.5, true)
	stand.draw_polyline(inner, Color(moon, 0.9), 1.0, true)
	# гнёзда: точка цвета владельца
	for k in 3:
		var gx: float = STAND_GX[k]
		var gy: = _crescent_y(gx, 300.0, -226.0) + 7.0
		stand.draw_circle(Vector2(gx, gy), 3.5, _stand_owner_col(k))

func _stand_owner_col(k: int) -> Color:
	var seat: int = [2, 0, 1][k]
	return accent(seat)

# Глобальная позиция центра n-го севера места `seat` на подставке и угол (по касательной к серпу).
func stand_slot(seat: int, n: int) -> Array:
	var k: int = {2: 0, 0: 1, 1: 2}[seat]
	var x: float = STAND_GX[k] + (n - 1.5) * 21.0
	var y: = _crescent_y(x, 300.0, -226.0) - 20.0
	var dx: = x - STAND_W * 0.5
	var ang: = -atan2(dx, sqrt(maxf(1.0, 300.0 * 300.0 - dx * dx)))
	return [stand.position + Vector2(x, y), ang]

func _build_center() -> void:
	var plate: = Control.new()
	plate.size = Vector2(232, 196)
	plate.position = C - Vector2(116, 98)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.draw.connect(func():
		var cc: = Vector2(116, 98)
		var tri: = PackedVector2Array()
		for i in 3:
			var a: = PI * 0.5 + TAU * i / 3.0
			tri.append(cc + Vector2(cos(a), sin(a)) * 100.0)
		plate.draw_colored_polygon(tri, Color(TOK.n900, 0.72))
		tri.append(tri[0])
		plate.draw_polyline(tri, Color(TOK.g500, 0.4), 1.5, true)
		plate.draw_arc(cc, 52, 0, TAU, 48, Color(TOK.moon, 0.22), 1.0, true))
	layer_table.add_child(plate)
	center_lbl = lbl("", 26, TOK.p100, "title", 700)
	center_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_lbl.size = Vector2(200, 34)
	center_lbl.position = C + Vector2(-100, -70)
	layer_table.add_child(center_lbl)
	wall_lbl = lbl("", 18, TOK.p300)
	wall_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wall_lbl.size = Vector2(200, 24)
	wall_lbl.position = C + Vector2(-100, -38)
	layer_table.add_child(wall_lbl)
	dora_box = HBoxContainer.new()
	dora_box.add_theme_constant_override("separation", 3)
	dora_box.position = C + Vector2(-60, -10)
	dora_box.size = Vector2(120, 46)
	dora_box.alignment = BoxContainer.ALIGNMENT_CENTER
	dora_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_table.add_child(dora_box)
	sticks_lbl = lbl("", 18, TOK.g300)
	sticks_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sticks_lbl.size = Vector2(200, 24)
	sticks_lbl.position = C + Vector2(-100, 40)
	layer_table.add_child(sticks_lbl)

func _portrait(seat: int, d: float) -> Dictionary:
	var root: = Control.new()
	root.size = Vector2(d, d)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.pivot_offset = Vector2(d, d) * 0.5
	var ring: = Panel.new()
	var sbr: = StyleBoxFlat.new()
	sbr.bg_color = Color(accent(seat), 0.0)
	sbr.border_color = accent(seat)
	sbr.set_border_width_all(3)
	sbr.set_corner_radius_all(int(d * 0.5) + 4)
	ring.add_theme_stylebox_override("panel", sbr)
	ring.position = Vector2(-4, -4)
	ring.size = Vector2(d + 8, d + 8)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask: = Panel.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = accent(seat).darkened(0.55)
	sb.set_corner_radius_all(int(d * 0.5))
	mask.add_theme_stylebox_override("panel", sb)
	mask.size = Vector2(d, d)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face: = TextureRect.new()
	face.texture = emo_tex(seat, "shy")
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.size = Vector2(d, d)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(face)
	var flash: = ColorRect.new()
	flash.color = Color(TOK.moon, 0.0)
	flash.size = Vector2(d, d)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(flash)
	root.add_child(mask)
	root.add_child(ring)
	return {"root": root, "face": face, "flash": flash, "ring": ring}

func _build_seats() -> void:
	seat_ui = [{}, {}, {}]
	var d: = 92.0
	var pos: = {1: Vector2(W - 16 - d, ex + 162), 2: Vector2(16, ex + 162)}
	for s in [1, 2]:
		var p: = _portrait(s, d)
		p.root.position = pos[s]
		layer_table.add_child(p.root)
		var nm: = lbl(NAMES.get(ids[s], ids[s]), 18, TOK.p300)
		nm.size = Vector2(150, 24)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if s == 1 else HORIZONTAL_ALIGNMENT_LEFT
		nm.position = pos[s] + Vector2(d - 150 if s == 1 else 0, d + 8)
		layer_table.add_child(nm)
		var sc: = lbl("", 24, TOK.p100, "body", 900)
		sc.size = Vector2(150, 30)
		sc.horizontal_alignment = nm.horizontal_alignment
		sc.position = nm.position + Vector2(0, 22)
		layer_table.add_child(sc)
		var wd: = lbl("", 18, TOK.g300, "title", 700)
		wd.size = Vector2(40, 28)
		wd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wd.size = Vector2(150, 24)
		wd.horizontal_alignment = nm.horizontal_alignment
		wd.position = nm.position + Vector2(0, 52)
		layer_table.add_child(wd)
		seat_ui[s] = {"root": p.root, "face": p.face, "flash": p.flash, "name": nm, "score": sc, "wind": wd, "ring": p.ring}
	rects.seat1 = Rect2(pos[1] - Vector2(60, 8), Vector2(d + 60, d + 64))
	rects.seat2 = Rect2(pos[2] - Vector2(0, 8), Vector2(d + 60, d + 64))

func _build_ponds() -> void:
	ponds = []
	for s in 3:
		var p: = Control.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if s == ME:
			p.position = C + Vector2(-102, 122)
		else:
			var dir: = Vector2(0.866 if s == 1 else -0.866, -0.5)
			p.position = C + dir * 124.0
			p.rotation = deg_to_rad(-120.0 if s == 1 else 120.0)
		layer_table.add_child(p)
		ponds.append(p)
	meld_boxes = []
	for s in 3:
		var mb: = Control.new()
		mb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer_table.add_child(mb)
		meld_boxes.append(mb)
	meld_boxes[ME].position = Vector2(W - 24, hand_y - 120)
	meld_boxes[1].position = Vector2(W - 24, ex + 350)
	meld_boxes[2].position = Vector2(24, ex + 350)

func _build_hand_area() -> void:
	hand_box = Control.new()
	hand_box.position = Vector2(0, hand_y)
	hand_box.size = Vector2(W, 96)
	hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_ui.add_child(hand_box)
	btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.position = Vector2(16, hand_y - 108)
	btn_row.size = Vector2(W - 32, 88)
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_ui.add_child(btn_row)
	hint_lbl = lbl("", 18, TOK.p500)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.size = Vector2(W, 24)
	hint_lbl.position = Vector2(0, hand_y + 74)
	layer_ui.add_child(hint_lbl)
	rects.hand = Rect2(Vector2(8, hand_y - 22), Vector2(W - 16, 100))
	rects.buttons = Rect2(btn_row.position, btn_row.size)
	rects.pond = Rect2(C + Vector2(-110, 114), Vector2(220, 4 * 47 + 16))
	rects.melds = Rect2(Vector2(W * 0.5, hand_y - 122), Vector2(W * 0.5 - 8, 0))

func _build_band() -> void:
	var by: = H - 180.0
	var band: = ColorRect.new()
	band.color = Color(TOK.n900, 0.82)
	band.position = Vector2(0, by)
	band.size = Vector2(W, 180)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_ui.add_child(band)
	var line: = ColorRect.new()
	line.color = Color(TOK.g700, 0.5)
	line.position = Vector2(0, by)
	line.size = Vector2(W, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_ui.add_child(line)
	# пауза (тихая кнопка)
	pause_btn = Button.new()
	pause_btn.flat = true
	pause_btn.text = "II"
	pause_btn.add_theme_font_override("font", font("body", 900))
	pause_btn.add_theme_font_size_override("font_size", 26)
	pause_btn.add_theme_color_override("font_color", TOK.p300)
	pause_btn.position = Vector2(16, by + 50)
	pause_btn.size = Vector2(80, 80)
	pause_btn.set_meta("ux_role", "tertiary")
	pause_btn.pressed.connect(_on_pause)
	layer_ui.add_child(pause_btn)
	# портрет партнёра (арочное окно 140) справа
	var p: = _portrait(ME, 132.0)
	p.root.position = Vector2(W - 24 - 132, by + 24)
	layer_ui.add_child(p.root)
	var you: = lbl(NAMES.get(ids[ME], ids[ME]), 18, TOK.p300)
	you.position = Vector2(112, by + 40)
	you.size = Vector2(300, 24)
	layer_ui.add_child(you)
	var sc: = lbl("", 40, TOK.p100, "body", 900)
	sc.position = Vector2(112, by + 64)
	sc.size = Vector2(320, 48)
	layer_ui.add_child(sc)
	var wd: = lbl("", 22, TOK.g300, "title", 700)
	wd.position = Vector2(112, by + 116)
	wd.size = Vector2(320, 30)
	layer_ui.add_child(wd)
	seat_ui[ME] = {"root": p.root, "face": p.face, "flash": p.flash, "name": you, "score": sc, "wind": wd, "ring": p.ring}
	rects.band = Rect2(0, by, W, 180)

# Табло «Хозяйка против двоих»: у правого края, над портретом соперницы, вне святой зоны.
func _build_event_board() -> void:
	event_board = Control.new()
	event_board.size = Vector2(168, 140)
	event_board.position = Vector2(W - 168 - 10, ex + 14)
	if host_scene != null:
		event_board.position.y = ex + 16
	event_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_board.pivot_offset = event_board.size * 0.5
	event_board.draw.connect(func():
		var rr: = Rect2(Vector2.ZERO, event_board.size)
		event_board.draw_rect(rr, Color(TOK.n900, 0.86))
		event_board.draw_rect(rr, Color(TOK.g500, 0.7), false, 1.5)
		event_board.draw_line(Vector2(12, 48), Vector2(156, 48), Color(TOK.g700, 0.6), 1.0))
	layer_ui.add_child(event_board)
	ev_cap_lbl = lbl(V10MjSanmaText.UI.event_title.to_upper(), 15, TOK.g500, "body", 900)
	ev_cap_lbl.add_theme_constant_override("outline_size", 0)
	ev_cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev_cap_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ev_cap_lbl.position = Vector2(6, 6)
	ev_cap_lbl.size = Vector2(156, 40)
	event_board.add_child(ev_cap_lbl)
	ev_mult_lbl = lbl("×2", 52, TOK.g300, "title", 700)
	ev_mult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev_mult_lbl.position = Vector2(0, 46)
	ev_mult_lbl.size = Vector2(168, 64)
	ev_mult_lbl.pivot_offset = Vector2(84, 32)
	event_board.add_child(ev_mult_lbl)
	ev_score_lbl = lbl("", 18, TOK.p300, "body", 800)
	ev_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev_score_lbl.position = Vector2(0, 110)
	ev_score_lbl.size = Vector2(168, 26)
	event_board.add_child(ev_score_lbl)
	rects.event = Rect2(event_board.position, event_board.size)
	# табло занимает правый верх — портрет соперницы справа сдвигаем ниже не нужно: он на ex+150

func _build_overlays() -> void:
	subtitle = lbl("", 28, TOK.p100, "italic", 600)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.size = Vector2(W - 120 - 190, 80)
	subtitle.position = Vector2(120, ex + 124)
	if host_scene != null:
		subtitle.position.y = stand.position.y + stand.size.y + 4
	subtitle.modulate.a = 0.0
	layer_fx.add_child(subtitle)
	ribbon = ColorRect.new()
	ribbon.size = Vector2(W, 64)
	ribbon.position = Vector2(0, C.y - 32)
	ribbon.color = Color(TOK.moon, 0.0)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_fx.add_child(ribbon)
	ribbon_lbl = lbl("", 34, TOK.n900, "title", 700)
	ribbon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ribbon_lbl.size = Vector2(W, 64)
	ribbon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ribbon_lbl.remove_theme_color_override("font_shadow_color")
	ribbon.add_child(ribbon_lbl)

func _audio() -> void:
	music = AudioStreamPlayer.new()
	if AudioServer.get_bus_index("Music") >= 0:
		music.bus = "Music"
	var ms: = ASSET_DIR + "music/moon_table.ogg"
	if ResourceLoader.exists(ms) and _g_bool("music", true) and not fast:
		var st = load(ms)
		if "loop" in st:
			st.loop = true
		music.stream = st
		music.volume_db = -4.0
		add_child(music)
		music.play()
	else:
		add_child(music)
	voice = AudioStreamPlayer.new()
	if AudioServer.get_bus_index("Voice") >= 0:
		voice.bus = "Voice"
	add_child(voice)

func _register_sacred() -> void:
	for k in ["hand", "buttons", "pond", "melds"]:
		if rects.has(k) and rects[k].size.x > 0:
			presence.sacred(rects[k])


# ── обновление вида ─────────────────────────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_refresh_center()
	_refresh_seats()
	for s in 3:
		_refresh_pond(s)
		_refresh_melds(s)
	_refresh_hand()
	_refresh_buttons()
	_refresh_event()

func _wind_name(k: int) -> String:
	return V8Mj.WIND_RU[k - 27] if names_ru else V8Mj.WIND_CH[k - 27]

func _refresh_center() -> void:
	# название раздачи меняется только на раздаче (после итога движок уже повернул ветер/дилера)
	if r.state in ["draw", "turn", "ask", "apply_turn", "after_discard", "after_kakan", "after_kita"] or center_lbl.text == "":
		center_lbl.text = V10MjSanmaText.UI.round % [V8Mj.WIND_RU[r.round_wind], r.kyoku + 1]
	wall_lbl.text = V10MjSanmaText.UI.wall % maxi(0, r.wall_left())
	for c in dora_box.get_children():
		c.queue_free()
	for d in r.dora_ind:
		dora_box.add_child(_tile_rect(d, Vector2(30, 42)))
	var parts: = []
	if r.honba > 0:
		parts.append(V10MjSanmaText.UI.honba % r.honba)
	if r.sticks > 0:
		parts.append("◆ %d" % r.sticks)
	sticks_lbl.text = "  ".join(parts)

func _refresh_seats() -> void:
	for s in 3:
		var u: Dictionary = seat_ui[s]
		if u.is_empty():
			continue
		u.score.text = _fmt(r.scores[s])
		var wn: = _wind_name(r.seat_wind(s)) if r.state != "idle" else ""
		u.wind.text = wn if s != ME else wn + ("  ·  " + V10MjSanmaText.btn("riichi")[0] if r.riichi[s] else "")
		u.ring.modulate = Color(1, 1, 1, 1.0 if r.turn == s else 0.45)

func _fmt(n: int) -> String:
	var s: = str(absi(n))
	var out: = ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("−" if n < 0 else "") + s + out

func _tile_rect(t: int, sz: Vector2, side: = false) -> TextureRect:
	var tr: = TextureRect.new()
	tr.texture = tile_tex(t)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.custom_minimum_size = sz
	tr.size = sz
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if side:
		tr.pivot_offset = sz * 0.5
		tr.rotation = PI * 0.5
	return tr

func pond_tile_size(s: int) -> Vector2:
	return Vector2(34, 47) if s == ME else Vector2(30, 41)

func pond_slot(s: int, i: int, side_before: int) -> Vector2:
	var ts: = pond_tile_size(s)
	var row: = i / 6
	var col: = i % 6
	var x: = col * ts.x + (ts.y - ts.x if side_before > 0 and side_before / 6 == row and (side_before % 6) < col else 0.0)
	if s == ME:
		return Vector2(x, row * ts.y)
	return Vector2(-3 * ts.x + x, row * ts.y)

func _refresh_pond(s: int) -> void:
	var p: Control = ponds[s]
	for c in p.get_children():
		c.queue_free()
	var ts: = pond_tile_size(s)
	var side_i: = -1
	var i: = 0
	for e in r.ponds[s]:
		if e.called:
			continue
		var side: bool = e.riichi
		if side:
			side_i = i
		var pos: = pond_slot(s, i, side_i + 1 if side_i >= 0 and side_i < i else 0)
		var tr: = _tile_rect(e.t, ts, side)
		tr.position = pos
		if side:
			tr.position += Vector2((ts.y - ts.x) * 0.5, 0)
		if e.tsumogiri:
			tr.modulate = Color(0.86, 0.84, 0.9)
		p.add_child(tr)
		i += 1

func _refresh_melds(s: int) -> void:
	var mb: Control = meld_boxes[s]
	for c in mb.get_children():
		c.queue_free()
	var ts: = Vector2(34, 47) if s == ME else Vector2(26, 36)
	var x: = 0.0
	var y: = 0.0
	for md in r.melds[s]:
		var tiles: Array = md.tiles
		var n: = tiles.size()
		var group_w: = n * ts.x
		if s == ME or s == 1:
			x -= group_w + 6
		for j in n:
			var tr: = _tile_rect(tiles[j], ts)
			if md.type == "ankan" and (j == 0 or j == 3):
				tr.texture = tex(TILE_DIR + "back.png")
			tr.position = Vector2(x + j * ts.x, y)
			mb.add_child(tr)
		if s == 2:
			x += group_w + 6
		if s != ME and absf(x) > 150:
			x = 0.0
			y += ts.y + 4

func _hand_tiles() -> Array:
	var h: Array = r.hands[ME].duplicate()
	if r.drawn >= 0 and r.turn == ME and r.drawn in h:
		h.erase(r.drawn)
		h = V8Mj.sort_tiles(h)
		h.append(r.drawn)
	else:
		h = V8Mj.sort_tiles(h)
	return h

func _refresh_hand() -> void:
	for c in hand_box.get_children():
		c.queue_free()
	var h: = _hand_tiles()
	var n: = h.size()
	var has_drawn: bool = r.drawn >= 0 and r.turn == ME and n % 3 == 2
	var avail: = W - 24.0 - (12.0 if has_drawn else 0.0)
	tile_w = minf(48.0, floorf(avail / maxf(1, n)))
	var th: = tile_w * 200.0 / 144.0
	var total: = tile_w * n + (12.0 if has_drawn else 0.0)
	var x0: = (W - total) * 0.5
	var allowed: = _allowed_discards()
	for i in n:
		var t: int = h[i]
		var b: = Control.new()
		b.size = Vector2(tile_w, th)
		b.position = Vector2(x0 + i * tile_w + (12.0 if has_drawn and i == n - 1 else 0.0), 0)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.set_meta("tile", t)
		var tr: = _tile_rect(t, Vector2(tile_w, th))
		b.add_child(tr)
		if waiting and cur_ask.get("kind", "") == "turn":
			if not allowed.is_empty() and not t in allowed:
				tr.modulate = Color(0.55, 0.52, 0.6)
		if i == sel:
			b.position.y -= 16
			var gl: = ColorRect.new()
			gl.color = Color(TOK.moon, 0.85)
			gl.size = Vector2(tile_w - 8, 4)
			gl.position = Vector2(4, th + 4)
			gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(gl)
		b.gui_input.connect(_on_tile_input.bind(i))
		hand_box.add_child(b)
	if waiting and cur_ask.get("kind", "") == "turn":
		hint_lbl.text = V10MjSanmaText.UI.tap_twice if r.hand_no <= 1 and r.ponds[ME].size() < 2 else ""
	else:
		hint_lbl.text = ""

func _allowed_discards() -> Array:
	if not waiting or cur_ask.get("kind", "") != "turn":
		return []
	var o: Dictionary = cur_ask.opts
	if riichi_pick:
		return o.riichi
	if r.riichi[ME]:
		return [r.drawn]
	var out: = []
	for t in r.hands[ME]:
		if not (t >> 2) in o.forbidden:
			out.append(t)
	return out

func _refresh_buttons() -> void:
	for c in btn_row.get_children():
		c.queue_free()
	buttons = {}
	if not waiting:
		return
	var o: Dictionary = cur_ask.get("opts", {})
	var list: = []
	match cur_ask.get("kind", ""):
		"turn":
			if o.get("tsumo", false):
				list.append("tsumo")
			if not o.get("riichi", []).is_empty() and not riichi_pick:
				list.append("riichi")
			if o.get("kita", false):
				list.append("kita")
			if not o.get("kans", []).is_empty():
				list.append("kan")
			list = list.slice(0, 3)
			if riichi_pick:
				list.append("pass")
		"call":
			if o.get("ron", false):
				list.append("ron")
			if o.get("pon", false):
				list.append("pon")
			if o.get("kan", false):
				list.append("kan")
			list = list.slice(0, 3)
			list.append("pass")
		"chankan", "kita_ron":
			list = ["ron", "pass"]
	for id in list:
		var b: = _decision_button(id)
		btn_row.add_child(b)
		buttons[id] = b

func _decision_button(id: String) -> Button:
	var parts: Array = V10MjSanmaText.btn(id, names_ru)
	var b: = Button.new()
	b.custom_minimum_size = Vector2(150 if id != "pass" else 136, 84)
	b.focus_mode = Control.FOCUS_NONE
	var primary: bool = id in ["ron", "tsumo"]
	var sb: = StyleBoxFlat.new()
	sb.bg_color = TOK.r500 if primary else Color(TOK.n700, 0.94)
	sb.border_color = TOK.moon if id == "kita" else (TOK.g500 if not primary else TOK.r700)
	sb.set_border_width_all(0 if id == "pass" else 2)
	sb.set_corner_radius_all(42 if primary else 6)
	if id == "pass":
		sb.bg_color = Color(TOK.n800, 0.82)
		sb.border_color = Color(TOK.p700, 0.8)
		sb.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", sb)
	var sbp: = sb.duplicate()
	sbp.bg_color = sb.bg_color.darkened(0.2)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("hover", sb)
	b.text = ""
	b.set_meta("ux_role", "secondary" if not primary else "game")
	var v: = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -4)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big: = lbl(parts[0], 28 if parts[1] != "" else 22, TOK.n900 if primary else (TOK.p100 if parts[1] != "" else TOK.p300), "title" if parts[1] != "" else "body", 700)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.remove_theme_color_override("font_shadow_color")
	v.add_child(big)
	if parts[1] != "":
		var small: = lbl(parts[1], 18, TOK.n800 if primary else (TOK.moon if id == "kita" else TOK.p500), "body", 700)
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		small.remove_theme_color_override("font_shadow_color")
		v.add_child(small)
	b.add_child(v)
	b.pressed.connect(press.bind(id))
	return b

func _refresh_event() -> void:
	if event_board == null or L == null:
		return
	ev_mult_lbl.text = V10MjSanmaText.UI.event_mult % L.mult
	ev_score_lbl.text = V10MjSanmaText.UI.event_score % L.ev_score[ME] if L.ev_score[ME] != 0 else V10MjSanmaText.UI.event_hint


# ── ввод ────────────────────────────────────────────────────────────────────────────────────────────────

func _on_tile_input(e: InputEvent, i: int) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
	if not tap:
		return
	accept_event()
	if not waiting or cur_ask.get("kind", "") != "turn":
		return
	var h: = _hand_tiles()
	if i >= h.size():
		return
	var t: int = h[i]
	var allowed: = _allowed_discards()
	presence.on("pick", {"pos": hand_box.global_position + Vector2((i + 0.5) * tile_w, 0)})
	if not t in allowed:
		V9Feel.sound("deny", 1.0, -6.0)
		return
	if sel == i:
		_discard(t)
	else:
		sel = i
		V9Feel.sound("select", randf_range(0.97, 1.04), -4.0)
		_refresh_hand()

func _discard(t: int) -> void:
	var a: = {"a": "discard", "t": t, "seat": ME}
	if riichi_pick:
		a["riichi"] = true
	_answer(a)

func press(id: String) -> void:
	if not waiting:
		return
	if buttons.has(id):
		V9Feel.press(buttons[id], "pop")
	var kind: String = cur_ask.get("kind", "")
	var o: Dictionary = cur_ask.get("opts", {})
	match id:
		"pass":
			if riichi_pick:
				riichi_pick = false
				_refresh_hand()
				_refresh_buttons()
				return
			_answer({"a": "pass", "seat": ME})
		"ron":
			_answer({"a": "ron", "seat": ME})
		"tsumo":
			_answer({"a": "tsumo", "seat": ME})
		"pon":
			_answer({"a": "pon", "seat": ME})
		"kan":
			if kind == "turn":
				_answer({"a": o.kans[0].a, "k": o.kans[0].k, "seat": ME})
			else:
				_answer({"a": "kan", "seat": ME})
		"kita":
			_answer({"a": "kita", "seat": ME})
		"riichi":
			riichi_pick = true
			sel = -1
			_refresh_hand()
			_refresh_buttons()

func _answer(a: Dictionary) -> void:
	waiting = false
	sel = -1
	riichi_pick = false
	cur_ask = {}
	r.answer(a)
	if "input_on" in presence:
		presence.input_on = false
	_refresh_buttons()
	_refresh_hand()
	delay = 0.0

func _on_pause() -> void:
	V9Feel.press(pause_btn, "pop")
	paused = not paused


# ── цикл движка ─────────────────────────────────────────────────────────────────────────────────────────

func waiting_input() -> bool:
	return waiting

func _process(dt: float) -> void:
	if r == null or layer_table == null or paused or sheet_open or match_done or fast:
		return
	if waiting:
		return
	delay -= dt
	if delay > 0:
		return
	pump_once()

func pump_once() -> Dictionary:
	if waiting or match_done or sheet_open:
		return {}
	var ev: = r.advance()
	_handle(ev)
	return ev

func _handle(ev: Dictionary) -> void:
	match ev.get("ev", ""):
		"deal":
			_on_deal(ev)
			delay = 0.6
		"draw":
			if ev.seat == ME:
				_refresh_hand()
			_refresh_center()
			delay = 0.08 if ev.seat == ME else 0.12
		"discard":
			_on_discard(ev)
			delay = 0.42
		"call":
			_on_call(ev)
			delay = 0.6
		"kita":
			_on_kita(ev)
			delay = 0.55 if ev.seat != ME else 0.2
		"riichi_stick":
			_refresh_center()
			_refresh_seats()
			delay = 0.1
		"ask":
			_on_ask(ev)
		"win":
			_on_win(ev)
		"draw_end":
			_on_draw_end(ev)
		"match_end":
			_on_match_end(ev)
		_:
			delay = 0.0
	_refresh_seats()

func _on_deal(ev: Dictionary) -> void:
	_refresh_all()
	if L != null:
		L.declare()
		_refresh_event()
		_pop(ev_mult_lbl, 1.35)
		_say(L.host_line_id())
		presence.on("wave", {"wave": r.hand_no, "block": 0.0})

func _on_discard(ev: Dictionary) -> void:
	var s: int = ev.seat
	var from: Vector2
	if s == ME:
		from = hand_box.global_position + Vector2(W * 0.5, 0)
	else:
		from = seat_ui[s].root.global_position + Vector2(46, 46)
	_refresh_pond(s)
	_refresh_hand()
	_refresh_center()
	var p: Control = ponds[s]
	if p.get_child_count() > 0:
		var last: Control = p.get_child(p.get_child_count() - 1)
		_fly_in(last, from)
	V9Feel.sound("clack%d" % (randi() % 3), randf_range(0.95, 1.05), -2.0 if s != ME else -6.0)
	if ev.riichi:
		_ribbon(V10MjSanmaText.btn("riichi", names_ru)[0] + " · " + V10MjSanmaText.btn("riichi", names_ru)[1], accent(s))
		presence.on("riichi", {"who": "me" if s == ME else ids[s], "seat": s, "block": 0.0})

func _on_call(ev: Dictionary) -> void:
	var s: int = ev.seat
	_refresh_melds(s)
	_refresh_pond(int(ev.get("from", s)))
	_refresh_hand()
	_refresh_center()
	var ty: String = ev.type
	var kind: = "kan" if ty in ["ankan", "minkan", "kakan"] else ty
	var b: Array = V10MjSanmaText.btn(kind, names_ru)
	_ribbon(b[0] + " · " + b[1], accent(s))
	presence.on("call", {"who": "me" if s == ME else ids[s], "kind": kind, "seat": s, "block": 0.0})
	if kind == "kan":
		presence.on("dora", {"block": 0.0})
	if L != null and L.on_engine(ev):
		_event_bump()

# Отложенный Север = благословение хозяйки: фишка летит к её портрету, портрет мигает, кивок,
# затем фишка ложится на Лунную подставку. Решение уже принято — ввод не блокируется (block 0).
func _on_kita(ev: Dictionary) -> void:
	var s: int = ev.seat
	var n: int = int(ev.n)
	_refresh_hand()
	var from: Vector2
	if s == ME:
		from = hand_box.global_position + Vector2(W * 0.5, 10)
	else:
		from = seat_ui[s].root.global_position + Vector2(46, 46)
	var slot: Array = stand_slot(s, mini(n - 1, 3))
	var host_r: = host_portrait_rect()
	var t: = _tile_rect(ev.tile, Vector2(34, 47))
	t.pivot_offset = Vector2(17, 23.5)
	t.position = from - Vector2(17, 23.5)
	layer_fx.add_child(t)
	var mid: = host_r.get_center()
	var tw: = create_tween()
	_tw_count += 1
	var d1: = 0.0 if fast else 0.38
	var d2: = 0.0 if fast else 0.3
	tw.tween_property(t, "position", mid - Vector2(17, 23.5), d1).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(t, "rotation", 0.25, d1)
	tw.tween_callback(_host_bless)
	# у хозяйки фишка растворяется в лунном свете и проявляется на подставке (не летит через её фигуру)
	tw.tween_property(t, "scale", Vector2(0.4, 0.4), d2 * 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(t, "modulate:a", 0.0, d2 * 0.6)
	tw.tween_callback(func():
		t.position = slot[0] - Vector2(17, 23.5)
		t.rotation = float(slot[1])
		t.scale = Vector2(0.9, 0.9))
	tw.tween_property(t, "modulate:a", 1.0, d2 * 0.6)
	tw.parallel().tween_property(t, "scale", Vector2(0.62, 0.62), d2 * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		t.reparent(stand)
		kita_slots[s].append(t)
		V9Feel.sound("sparkle", 1.2, -10.0))
	if L != null and L.on_engine(ev):
		_event_bump()
	presence.on("kita", {"who": "me" if s == ME else ids[s], "seat": s, "n": n, "block": 0.0})
	presence.on("dora", {"block": 0.0})
	_kita_line_i += 1
	_say("kita_%d" % (((_kita_line_i - 1) % 5) + 1))

func _host_bless() -> void:
	var u: Dictionary = seat_ui[host_seat]
	var target: Control = host_scene if host_scene != null else u.root
	var fl: ColorRect = u.flash
	if fast:
		return
	_halo(host_halo_center(), 170.0 if host_scene != null else 96.0)
	var tw: = create_tween()
	tw.tween_property(fl, "color", Color(TOK.moon, 0.55), 0.08)
	tw.tween_property(fl, "color", Color(TOK.moon, 0.0), 0.14)
	tw.tween_property(fl, "color", Color(TOK.moon, 0.4), 0.08)
	tw.tween_property(fl, "color", Color(TOK.moon, 0.0), 0.2)
	var nod: = create_tween()
	var base_y: float = target.position.y
	nod.tween_property(target, "position:y", base_y + 7.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	nod.tween_property(target, "position:y", base_y, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	u.face.texture = emo_tex(host_seat, "happy")
	if host_scene != null:
		host_scene.modulate = Color(1.18, 1.14, 1.3)
		create_tween().tween_property(host_scene, "modulate", Color(1, 1, 1), 0.5)
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(u.face):
			u.face.texture = emo_tex(host_seat, "shy"))

# Лунный ореол: кольцо света расходится от хозяйки (≤ 0,6 с, без вспышек, вне святой зоны).
func _halo(center: Vector2, d: float) -> void:
	if not V9Feel.can_fx():
		return
	var h: = TextureRect.new()
	var gt: = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gr: = Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.62, 0.78, 1.0])
	gr.colors = PackedColorArray([Color(TOK.moon, 0.0), Color(TOK.moon, 0.0), Color(TOK.moon, 0.75), Color(TOK.moon, 0.0)])
	gt.gradient = gr
	gt.width = 128
	gt.height = 128
	h.texture = gt
	h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	h.size = Vector2(d, d) * 1.6
	h.pivot_offset = h.size * 0.5
	h.position = center - h.size * 0.5
	h.scale = Vector2(0.55, 0.55)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_fx.add_child(h)
	var tw: = h.create_tween()
	tw.tween_property(h, "scale", Vector2(1.25, 1.25), 0.55).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(h, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(h.queue_free)

func _event_bump() -> void:
	_refresh_event()
	_pop(ev_mult_lbl, 1.5)
	if event_board != null and not fast:
		var tw: = create_tween()
		tw.tween_property(ev_mult_lbl, "modulate", Color(1.4, 1.25, 0.9), 0.08)
		tw.tween_property(ev_mult_lbl, "modulate", Color(1, 1, 1), 0.3)
	ev_best_mult = maxi(ev_best_mult, L.mult)

func _on_ask(ev: Dictionary) -> void:
	if int(ev.get("seat", -1)) != ME:
		# не наш вопрос (не должно случаться: все ИИ решают сами)
		r.answer({"a": "pass", "seat": ev.get("seat", 0)})
		return
	waiting = true
	cur_ask = ev
	sel = -1
	riichi_pick = false
	if "input_on" in presence:
		presence.input_on = true
	if ev.kind == "turn" and ev.opts.get("tsumo", false):
		presence.on("tenpai", {"who": "me", "block": 0.0})
	_refresh_hand()
	_refresh_buttons()
	if demo:
		_demo_answer()

func _demo_answer() -> void:
	var a: Dictionary
	if cur_ask.kind == "turn":
		a = V10MjSanmaAI.turn(r, ME, cur_ask.opts)
	elif cur_ask.kind == "call":
		a = V10MjSanmaAI.decide_call(r, ME, cur_ask.opts)
	else:
		a = {"a": "ron"}
	a["seat"] = ME
	_answer(a)

func _on_win(ev: Dictionary) -> void:
	var w: int = ev.seat
	_refresh_all()
	var b: Array = V10MjSanmaText.btn("tsumo" if ev.tsumo else "ron", names_ru)
	_ribbon(b[0] + " · " + b[1], accent(w))
	presence.on("tsumo" if ev.tsumo else "ron", {"who": "me" if w == ME else ids[w], "seat": w, "block": 0.0})
	if int(ev.from) == ME and w != ME:
		presence.on("dealin", {"who": "me", "block": 0.0})
	var ev_d: = [0, 0, 0]
	if L != null:
		ev_d = L.settle(ev)
		_refresh_event()
	var dt: = Time.get_date_string_from_system()
	hand_best_new = V10MjSanmaData.note_hand(ev, ME, r.seed, dt)
	_show_hand_sheet(ev, ev_d)

func _on_draw_end(ev: Dictionary) -> void:
	_refresh_all()
	presence.on("tenpai" if ME in ev.tenpai else "noten", {"who": "me", "block": 0.0})
	if L != null:
		L.settle(ev)
	_show_hand_sheet(ev, [0, 0, 0])

func _on_match_end(ev: Dictionary) -> void:
	match_done = true
	var fr: Dictionary = ev.result
	var place: int = int(fr.place[ME])
	var rw: = V10MjSanmaData.note_match(fr, ME, r.stats.kita, Time.get_date_string_from_system())
	if L != null:
		V10MjSanmaData.note_event(L.ev_score[ME], ev_best_mult, Time.get_date_string_from_system().substr(0, 7))
	presence.on("win" if place == 1 else "lose", {"block": 0.0})
	final_res = {"mode": "sanma", "win": place == 1, "score": int(fr.scores[ME]), "stars": 0,
		"time_s": int((Time.get_ticks_msec() - t_start) / 1000), "pairs": 0, "hero": ids[ME], "seed": r.seed,
		"rewards": rw, "place": place, "scores": fr.scores, "event_score": L.ev_score[ME] if L != null else 0,
		"best_hand": V10MjSanmaData.st().best_hand}
	_show_final_sheet(final_res)


# ── листы итогов ────────────────────────────────────────────────────────────────────────────────────────

func _sheet_base(h: float) -> Control:
	if sheet != null:
		sheet.queue_free()
	sheet_open = true
	sheet = Control.new()
	sheet.size = Vector2(W, H)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.size = Vector2(W, H)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(dim)
	var panel: = Panel.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(TOK.n700, 0.98)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(TOK.g700, 0.6)
	sb.border_width_top = 1
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = Vector2(W, h)
	panel.position = Vector2(0, H - h)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(panel)
	if not fast:
		panel.position.y = H
		create_tween().tween_property(panel, "position:y", H - h, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	return panel

func _primary_button(text: String, cb: Callable) -> Button:
	var b: = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(560, 104)
	b.size = Vector2(560, 104)
	var sb: = StyleBoxFlat.new()
	sb.bg_color = TOK.r500
	sb.set_corner_radius_all(52)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	var sbp: = sb.duplicate()
	sbp.bg_color = TOK.r700
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_font_override("font", font("title", 600))
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", TOK.n900)
	b.add_theme_color_override("font_pressed_color", TOK.n900)
	b.add_theme_color_override("font_hover_color", TOK.n900)
	b.set_meta("ux_role", "primary")
	b.pressed.connect(func():
		V9Feel.press(b, "pop")
		cb.call())
	return b

func _show_hand_sheet(ev: Dictionary, ev_d: Array) -> void:
	var is_win: bool = ev.ev == "win"
	var panel: = _sheet_base(560.0)
	var y: = 28.0
	var title: String
	if is_win:
		var w: int = ev.seat
		title = (V10MjSanmaText.UI.you if w == ME else NAMES.get(ids[w], ids[w])) + " · " + V10MjSanmaText.UI.result_win
	else:
		title = V10MjSanmaText.UI.result_draw
	var tl: = lbl(title, 44, TOK.p100, "title", 700)
	tl.position = Vector2(32, y)
	tl.size = Vector2(W - 64, 56)
	panel.add_child(tl)
	y += 64
	if is_win:
		var e: Dictionary = ev.eval
		var hb: = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 1)
		hb.position = Vector2(32, y)
		var all_t: Array = ev.hand.duplicate()
		if not ev.tsumo:
			all_t.append(ev.tile)
		for t in V8Mj.sort_tiles(all_t):
			hb.add_child(_tile_rect(t, Vector2(36, 50)))
		for md in ev.get("melds", []):
			var gap: = Control.new()
			gap.custom_minimum_size = Vector2(8, 10)
			hb.add_child(gap)
			for t in md.tiles:
				hb.add_child(_tile_rect(t, Vector2(30, 42)))
		for t in ev.get("kita", []):
			var kt: = _tile_rect(t, Vector2(30, 42))
			kt.modulate = Color(TOK.moon).lightened(0.4)
			hb.add_child(kt)
		panel.add_child(hb)
		y += 62
		var lines: = []
		for yk in e.get("yaku", []):
			var nm: String = V8Mj.yaku_name(String(yk[0]))
			lines.append([nm, "%d" % int(yk[1]) if int(e.get("yakuman", 0)) == 0 else "★"])
		var dn: int = int(e.get("dora", 0)) + int(e.get("aka", 0)) + int(e.get("ura", 0))
		if dn > 0:
			lines.append([V10MjSanmaText.UI.result_dora, "%d" % dn])
		if int(e.get("kita_han", 0)) > 0:
			lines.append([V10MjSanmaText.UI.result_kita + " ×%d" % int(e.kita), "%d" % int(e.kita_han)])
		var cap: = lbl(V10MjSanmaText.UI.result_combo, 15, TOK.g500, "body", 900)
		cap.position = Vector2(32, y)
		panel.add_child(cap)
		y += 24
		for ln in lines.slice(0, 6):
			var a: = lbl(ln[0], 24, TOK.p100, "body", 700)
			a.position = Vector2(32, y)
			a.size = Vector2(440, 32)
			panel.add_child(a)
			var b: = lbl(ln[1], 24, TOK.g300, "body", 900)
			b.position = Vector2(W - 32 - 80, y)
			b.size = Vector2(80, 32)
			b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			panel.add_child(b)
			y += 32
		var lim: String = String(e.get("limit", ""))
		var pts: int = int(ev.delta[ev.seat])
		var big: = lbl(("%s  " % lim if lim != "" else "") + "+" + _fmt(pts), 40, TOK.g300, "title", 700)
		big.position = Vector2(32, y + 6)
		big.size = Vector2(W - 64, 50)
		panel.add_child(big)
		y += 56
		if hand_best_new and ev.seat == ME:
			var rec: = lbl(V10MjSanmaText.UI.record, 18, TOK.moon, "body", 900)
			rec.position = Vector2(32, y)
			panel.add_child(rec)
			y += 26
	else:
		var names: = []
		for s in ev.tenpai:
			names.append(V10MjSanmaText.UI.you if s == ME else NAMES.get(ids[s], ids[s]))
		var tx: = lbl(V10MjSanmaText.UI.tenpai % (", ".join(names) if not names.is_empty() else V10MjSanmaText.UI.nobody), 24, TOK.p300)
		tx.position = Vector2(32, y)
		panel.add_child(tx)
		y += 40
	if L != null and ev_d[ME] != 0:
		var el: = lbl(V10MjSanmaText.UI.event_title + " · " + (V10MjSanmaText.UI.event_mult % L.mult) + "   %+d" % ev_d[ME], 18, TOK.g500, "body", 800)
		el.position = Vector2(32, y)
		panel.add_child(el)
	var nb: = _primary_button(V10MjSanmaText.UI.next, _close_sheet)
	nb.position = Vector2((W - 560) * 0.5, 560 - 104 - 32)
	panel.add_child(nb)
	if fast and not bool(args.get("hold", false)):
		_close_sheet()

func _close_sheet() -> void:
	if sheet != null:
		sheet.queue_free()
		sheet = null
	sheet_open = false
	delay = 0.3

func _show_final_sheet(res: Dictionary) -> void:
	var panel: = _sheet_base(640.0)
	var place: int = res.place
	var tl: = lbl(V10MjSanmaText.UI.result_place % place, 64, TOK.p100, "title", 700)
	tl.position = Vector2(32, 24)
	tl.size = Vector2(W - 64, 76)
	panel.add_child(tl)
	var y: = 112.0
	var order: Array = r.placements()
	for i in 3:
		var s: int = order[i]
		var a: = lbl("%d  %s" % [i + 1, V10MjSanmaText.UI.you if s == ME else NAMES.get(ids[s], ids[s])], 26, TOK.p100 if s == ME else TOK.p300, "body", 800)
		a.position = Vector2(32, y)
		a.size = Vector2(400, 34)
		panel.add_child(a)
		var b: = lbl(_fmt(r.scores[s]), 26, TOK.p100, "body", 900)
		b.position = Vector2(W - 32 - 240, y)
		b.size = Vector2(240, 34)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		panel.add_child(b)
		y += 40
	y += 12
	var rw: Dictionary = res.rewards
	var rt: = V10MjSanmaText.UI.coins % int(rw.coins)
	if int(rw.gems) > 0:
		rt += "  ·  " + V10MjSanmaText.UI.gems % int(rw.gems)
	var rl: = lbl(rt, 26, TOK.g300, "body", 900)
	rl.position = Vector2(32, y)
	panel.add_child(rl)
	y += 40
	var bh: Dictionary = res.best_hand
	if not bh.is_empty():
		var bl: = lbl(V10MjSanmaText.UI.record + ": " + _fmt(int(bh.pts)) + ("  " + String(bh.name) if String(bh.get("name", "")) != "" else ""), 18, TOK.p500, "body", 800)
		bl.position = Vector2(32, y)
		panel.add_child(bl)
		y += 28
	if L != null:
		var el: = lbl(V10MjSanmaText.UI.event_score % L.ev_score[ME], 18, TOK.g500, "body", 800)
		el.position = Vector2(32, y)
		panel.add_child(el)
	var nb: = _primary_button(V10MjSanmaText.UI.next, func():
		finished.emit(final_res))
	nb.position = Vector2((W - 560) * 0.5, 640 - 104 - 40)
	panel.add_child(nb)


# ── сок ─────────────────────────────────────────────────────────────────────────────────────────────────

func _fly_in(node: Control, from_global: Vector2) -> void:
	if fast or not V9Feel.can_fx():
		return
	var target: = node.position
	var parent: = node.get_parent() as Control
	var local_from: = parent.get_global_transform().affine_inverse() * from_global
	node.position = local_from
	node.modulate.a = 0.0
	var tw: = node.create_tween()
	tw.tween_property(node, "position", target, 0.18).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "modulate:a", 1.0, 0.08)

func _pop(n: Control, k: float) -> void:
	if n == null or fast:
		return
	n.scale = Vector2(k, k)
	n.create_tween().tween_property(n, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _ribbon(text: String, col: Color) -> void:
	if fast:
		return
	ribbon_lbl.text = text
	ribbon.color = Color(col, 0.0)
	var tw: = create_tween()
	tw.tween_property(ribbon, "color", Color(col, 0.88), 0.12)
	tw.tween_interval(0.46)
	tw.tween_property(ribbon, "color", Color(col, 0.0), 0.12)
	ribbon_lbl.modulate.a = 0.0
	var tw2: = create_tween()
	tw2.tween_property(ribbon_lbl, "modulate:a", 1.0, 0.12)
	tw2.tween_interval(0.46)
	tw2.tween_property(ribbon_lbl, "modulate:a", 0.0, 0.12)

# Реплика хозяйки: субтитр у её зоны (не на поле) + голос, не чаще раза в 20 с (кроме объявления множителя).
func _say(line_id: String) -> void:
	var ln: Dictionary = V10MjSanmaText.LINES.get(line_id, {})
	if ln.is_empty():
		return
	var now: = Time.get_ticks_msec() / 1000.0
	var forced: = line_id.begins_with("host_")
	if not forced and now - _last_voice < 20.0:
		return
	_last_voice = now
	subtitle.text = ln.ru
	if not fast:
		var tw: = create_tween()
		subtitle.modulate.a = 0.0
		tw.tween_property(subtitle, "modulate:a", 1.0, 0.3)
		tw.tween_interval(2.6)
		tw.tween_property(subtitle, "modulate:a", 0.0, 0.3)
	else:
		subtitle.modulate.a = 1.0
	var vp: = V10MjSanmaText.voice_path(line_id)
	if ResourceLoader.exists(vp) and _g_bool("voice", true) and not fast:
		voice.stream = load(vp)
		voice.play()
		var sfx = get_node_or_null("/root/Sfx")
		if sfx != null and sfx.has_method("duck"):
			sfx.duck(-8.0, 3.0)


# ── API для самотеста, демо и хаба ──────────────────────────────────────────────────────────────────────

func host_portrait_rect() -> Rect2:
	if host_scene != null:
		# фишка уходит к её плечу (сбоку от лица), а не на лицо и не на фигуру
		return Rect2(host_scene.global_position + host_scene.size * Vector2(0.7, 0.2), host_scene.size * Vector2(0.18, 0.18))
	var u: Dictionary = seat_ui[host_seat]
	return Rect2(u.root.global_position, u.root.size)

func host_halo_center() -> Vector2:
	if host_scene != null:
		return host_scene.global_position + host_scene.size * Vector2(0.5, 0.27)
	return host_portrait_rect().get_center()

func event_board_rect() -> Rect2:
	return rects.get("event", Rect2())

func has_button(id: String) -> bool:
	return buttons.has(id)

# Тапаемые элементы без руки (UX §3.7: в партии ≤ 6).
func ux_tappables() -> int:
	return 1 + buttons.size()

func sacred_rects() -> Array:
	var out: = []
	for k in ["hand", "buttons", "pond", "melds"]:
		if rects.has(k):
			out.append(rects[k])
	return out

# Самотест/демо: подложить Север в ход игрока и показать «Север · кита».
func debug_force_kita() -> bool:
	if not waiting or cur_ask.get("kind", "") != "turn":
		return false
	var north: = -1
	for c in 4:
		var id: = 30 * 4 + c
		if not id in r.hands[ME]:
			north = id
			break
	if north < 0:
		return false
	if r.drawn >= 0 and r.drawn in r.hands[ME]:
		r.hands[ME].erase(r.drawn)
	else:
		r.hands[ME].pop_back()
	r.hands[ME].append(north)
	r.drawn = north
	cur_ask.opts = r.turn_options(ME)
	r.ask = cur_ask
	_refresh_hand()
	_refresh_buttons()
	return bool(cur_ask.opts.get("kita", false))

func debug_set_mult(m: int) -> void:
	if L != null:
		L.mult = m
		ev_best_mult = maxi(ev_best_mult, m)
		_refresh_event()

func debug_select(i: int) -> void:
	sel = i
	_refresh_hand()
