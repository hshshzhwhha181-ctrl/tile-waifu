class_name V10ChallengePoster
extends RefCounted

# «Вызов по коду»: the poster — a 720×1280 PNG in the «Тишина и лак» magazine-cover language (UX §6.8): night
# lacquer, the partner heroine walking off the right edge, the overline spine and the antiqua title on the left
# margin, the author's time huge in Nunito 900, the stars, «Мой стол — 1:42. Сможешь?», the nick and the code band.
#
# OUTFIT (spec §2.7): the poster leaves the phone, so it always shows a SFW look. An outfit with sfw == false (or
# bold) is replaced by its `alt`; without an alt — by the heroine's base look. The base look uses the rigged cut-out
# (assets/hero/<id>.png), any other look its full illustration (assets/outfits/<img>.webp) under night gradients.
#
#   info(p, deal, extra) -> Dictionary        p = code payload, deal = V10ChallengeDeal.resolve(p),
#                                             extra = {hero, outfit, nick}
#   outfit_art(hero, outfit_id) -> {kind: "cutout"|"art", path, img, swapped, outfit}
#   make(info) -> Control (720×1280)          the live poster (also the preview of the «Бросить вызов» sheet)
#   render(info, host) -> Image               await: SubViewport → Image (empty in a headless run)
#   face_rect(poster) -> Rect2                where the face is (nothing may cover it + 48 px)

const U: = preload("res://scripts/v10/duels/challenge/challenge_util.gd")
const C: = preload("res://scripts/v10/duels/challenge/challenge_code.gd")

const SIZE: = Vector2(720, 1280)
const HEROES: = ["mc", "rin", "hana", "yue", "nova"]
const BASE_IMG: = {"mc": "mc_base", "rin": "rin_base", "hana": "hana_base", "yue": "yue_base", "nova": "nova_base"}
const LX: = 44.0  # left margin of the text column
const FACE_AT: = Vector2(508, 318)  # where the face centre sits on the cover
const FACE_W: = 112.0  # face width on the cover (cut-out)
const BAND_Y: = 1150.0  # top of the code band

# ---------------------------------------------------------------- data

static func info(p: Dictionary, deal: Dictionary, extra: = {}) -> Dictionary:
	var hero: = String(extra.get("hero", "mc"))
	var t: = int(p.get("tenths", 0))
	var nick: = String(extra.get("nick", U.my_nick()))
	return {
		"hero": hero if hero in HEROES else "mc",
		"outfit": String(extra.get("outfit", _equipped(hero))),
		"tenths": t, "time": U.fmt_time(t), "stars": int(p.get("stars", 3)),
		"mode_name": String(deal.get("mode_name", "Путь")), "table": String(deal.get("table", "")),
		"code": C.encode(p), "nick": nick,
		"line": "Мой стол — %s. Сможешь?" % U.fmt_time(t),
	}


static func _equipped(hero: String) -> String:
	var gg: = U.g()
	if gg and gg.has_method("equipped"):
		return String(gg.call("equipped", hero))
	return ""


static func outfit_art(hero: String, outfit_id: String) -> Dictionary:
	var h: = hero if hero in HEROES else "mc"
	var out: = {"kind": "cutout", "path": "res://assets/hero/%s.png" % h, "img": String(BASE_IMG[h]), "swapped": false,
		"outfit": outfit_id}
	var gg: = U.g()
	if outfit_id == "" or gg == null or not (gg.ITEM as Dictionary).has(outfit_id):
		return out
	var it: Dictionary = gg.ITEM[outfit_id]
	var img: = String(it.get("img", ""))
	if V8Art.RETIRED_IMG.has(img):
		img = String(V8Art.RETIRED_IMG[img])
	var sfw: = bool(it.get("sfw", not bool(it.get("bold", false))))
	if not sfw:
		out.swapped = true
		img = String(it.get("alt", ""))
	if img == "" or img == String(BASE_IMG[h]):
		return out
	var path: = "res://assets/outfits/%s.webp" % img
	if not ResourceLoader.exists(path):
		return out
	out.kind = "art"
	out.path = path
	out.img = img
	return out

# ---------------------------------------------------------------- the poster

static func make(inf: Dictionary) -> Control:
	var root: = Control.new()
	root.name = "ChallengePoster"
	root.size = SIZE
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var hero: = String(inf.get("hero", "mc"))
	var acc: Dictionary = V10DS.hero(hero)
	root.add_child(_Back.new(acc))
	var art: = outfit_art(hero, String(inf.get("outfit", "")))
	root.set_meta("art", art)
	var face: = Rect2()
	var tex: Texture2D = V8Art.tex(String(art.path))
	if tex:
		var tr: = TextureRect.new()
		tr.name = "Heroine"
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ts: = tex.get_size()
		if art.kind == "cutout":
			var fc: = V8Art.rig_face(hero)
			var fw: = float(V8Art.RIG_FACE_W.get(hero, 90.0))
			var s: = FACE_W / fw
			tr.size = ts * s
			tr.position = FACE_AT - fc * s
			face = Rect2(FACE_AT - Vector2(FACE_W * 0.6, FACE_W * 0.75), Vector2(FACE_W * 1.2, FACE_W * 1.5))
		else:
			# the illustrations frame a standing figure, head at ≈ 15 % of the height, face ≈ 8.5 % of the width
			var s2: = SIZE.y * 1.14 / ts.y
			tr.size = ts * s2
			var fpos: = Vector2(ts.x * 0.5, ts.y * 0.15) * s2
			tr.position = Vector2(FACE_AT.x - fpos.x, 0.0)
			var fw2: = ts.x * 0.085 * s2
			face = Rect2(tr.position + fpos - Vector2(fw2 * 0.6, fw2 * 0.75), Vector2(fw2 * 1.2, fw2 * 1.5))
			tr.modulate = Color(0.74, 0.72, 0.8)  # the lit room sinks into the night
		root.add_child(tr)
	root.set_meta("face_rect", face)
	root.add_child(_Shade.new(art.kind == "art"))
	# ---- left column: spine, mode and table
	var items: = []
	var spine: = V10Type.label("ВЫЗОВ  ·  TILE WAIFU", "overline", 18, V10DS.GOLD_500, true)
	spine.position = Vector2(LX, 52)
	spine.size = Vector2(420, 24)
	root.add_child(spine)
	items.append(spine)
	var hair: = V10ChallengeUI.Hair.new(120)
	hair.position = Vector2(LX, 86)
	root.add_child(hair)
	var mode_l: = V10Type.label(String(inf.get("mode_name", "Путь")).to_upper(), "overline", 18, V10DS.PAPER_300, true)
	mode_l.position = Vector2(LX, 104)
	mode_l.size = Vector2(320, 26)
	root.add_child(mode_l)
	items.append(mode_l)
	var tparts: = String(inf.get("table", "")).split(" · ")
	var tname: = tparts[tparts.size() - 1] if tparts.size() > 0 else ""
	var tcode: = tparts[0] if tparts.size() > 1 else ""
	if tcode != "":
		mode_l.text += "  ·  " + tcode
	var tl: = V10Type.label(tname, "display", 52, V10DS.PAPER_100, true)
	tl.position = Vector2(LX - 2, 132)
	tl.size = Vector2(FACE_AT.x - FACE_W - 48 - LX, 132)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.max_lines_visible = 2
	tl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	for k in [52, 44, 36]:
		tl.label_settings = V10Type.settings("display", k, V10DS.PAPER_100, true)
		if V10Type.lines_needed(tname, "display", k, tl.size.x) <= 2:
			break
	root.add_child(tl)
	items.append(tl)
	# ---- the time, huge, lower left (over her dress, never her face)
	var tm: = V10Type.label(String(inf.get("time", "0:00")), "num", 236, V10DS.PAPER_100, true)
	var tsz: = 236
	for k in [236, 212, 188, 164]:
		tsz = k
		if V10Type.text_w(tm.text, "num", k) <= 600.0:
			break
	tm.label_settings = V10Type.settings("num", tsz, V10DS.PAPER_100, true)
	tm.name = "Time"
	tm.position = Vector2(LX - 10, 640)
	tm.size = Vector2(640, 250)
	tm.clip_text = false
	root.add_child(tm)
	items.append(tm)
	var st: = V10ChallengeUI.Stars.new(int(inf.get("stars", 3)), 3, 26.0)
	st.position = Vector2(LX + 4, 894)
	root.add_child(st)
	var line: = V10Type.label(String(inf.get("line", "")), "display_italic", 40, V10DS.PAPER_100, true)
	line.position = Vector2(LX, 950)
	line.size = Vector2(470, 104)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.max_lines_visible = 2
	line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	root.add_child(line)
	items.append(line)
	var nick: = String(inf.get("nick", ""))
	if nick != "":
		var nl: = V10Type.label("— " + nick, "ui", 26, V10DS.GOLD_300, true)
		nl.position = Vector2(LX, 1064)
		nl.size = Vector2(470, 36)
		root.add_child(nl)
		items.append(nl)
	# ---- code band
	var band: = _Band.new()
	band.position = Vector2(0, BAND_Y)
	band.size = Vector2(SIZE.x, SIZE.y - BAND_Y)
	root.add_child(band)
	var ov: = V10Type.label("КОД ВЫЗОВА", "overline", 15, V10DS.GOLD_500)
	ov.position = Vector2(LX, BAND_Y + 22)
	ov.size = Vector2(300, 20)
	root.add_child(ov)
	var code: = V10Type.label(String(inf.get("code", "")), "num", 44, V10DS.PAPER_100)
	code.name = "Code"
	code.position = Vector2(LX - 2, BAND_Y + 46)
	code.size = Vector2(560, 56)
	root.add_child(code)
	items.append(code)
	var where: = V10Type.label("Столы → Соперницы → Вызов по коду", "ui", 18, V10DS.PAPER_500)
	where.position = Vector2(LX, BAND_Y + 96)
	where.size = Vector2(520, 26)
	root.add_child(where)
	root.set_meta("text_nodes", items)
	return root


static func face_rect(poster: Control) -> Rect2:
	return poster.get_meta("face_rect", Rect2()) if poster else Rect2()


# every text of the poster stays out of face_rect + 48 (UX Г-1)
static func face_clear(poster: Control) -> bool:
	var f: = face_rect(poster).grow(48)
	if f.size == Vector2.ZERO:
		return true
	for n in poster.get_meta("text_nodes", []):
		var l: = n as Label
		var w: = V10Type.text_w(l.text, "ui", 18)
		if l.label_settings:
			w = l.label_settings.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.label_settings.font_size).x
		var r: = Rect2(l.position, Vector2(minf(w, l.size.x), l.size.y))
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
			r.size.x = l.size.x
		if r.intersects(f):
			return false
	return true


# await V10ChallengePoster.render(info, host) -> Image (720×1280, RGB8); empty Image when nothing renders (headless)
static func render(inf: Dictionary, host: Node) -> Image:
	var vp: = SubViewport.new()
	vp.name = "ChallengePosterVP"
	vp.size = Vector2i(SIZE)
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	host.add_child(vp)
	var p: = make(inf)
	vp.add_child(p)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = null
	if DisplayServer.get_name() != "headless":
		img = vp.get_texture().get_image()
	vp.queue_free()
	if img == null:
		return Image.new()
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	return img

# ---------------------------------------------------------------- painted layers

class _Back:
	extends Control
	var acc: Dictionary

	func _init(a: Dictionary) -> void:
		acc = a
		size = V10ChallengePoster.SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: = size.x
		var h: = size.y
		var top: = V10DS.NIGHT_800
		var bot: = V10DS.NIGHT_900
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([top, top, bot, bot]))
		# the heroine's accent as a glow behind her (≤ 10 % of the pixels carry colour)
		var g: Color = acc.get("deep", V10DS.ROSE_700)
		for i in 14:
			var k: = 1.0 - i / 14.0
			draw_circle(V10ChallengePoster.FACE_AT + Vector2(30, 260), 140.0 + i * 34.0, Color(g, 0.035 * k), true, -1.0, true)
		# felt light pooled at the bottom of the table
		var f: = V10DS.FELT_HI
		for i in 10:
			draw_circle(Vector2(w * 0.3, h + 120), 220.0 + i * 46.0, Color(f, 0.05), true, -1.0, true)
		# a lacquer sheen line across the top third
		var lac: = Color(V10DS.PAPER_100, V10DS.LACQUER_A)
		var clr: = Color(V10DS.PAPER_100, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.4), Vector2(0, h * 0.4)]), PackedColorArray([lac, lac, clr, clr]))


# night gradients that let the text column read over the art
class _Shade:
	extends Control
	var strong: = false

	func _init(on_art: bool) -> void:
		strong = on_art
		size = V10ChallengePoster.SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: = size.x
		var h: = size.y
		var n: = V10DS.NIGHT_900
		var a0: = 0.92 if strong else 0.80
		var c0: = Color(n, a0)
		var c1: = Color(n, 0.0)
		# left column, lower two thirds
		var x1: = 470.0 if strong else 420.0
		draw_polygon(PackedVector2Array([Vector2(0, 560), Vector2(x1, 560), Vector2(x1, h), Vector2(0, h)]), PackedColorArray([Color(n, 0.0), c1, c1, Color(n, 0.0)]))
		var steps: = 12
		for i in steps:
			var xa: = x1 * i / steps
			var xb: = x1 * (i + 1) / steps
			var ka: = a0 * pow(1.0 - float(i) / steps, 1.4)
			var kb: = a0 * pow(1.0 - float(i + 1) / steps, 1.4)
			draw_polygon(PackedVector2Array([Vector2(xa, 520), Vector2(xb, 520), Vector2(xb, h), Vector2(xa, h)]),
				PackedColorArray([Color(n, ka * 0.0), Color(n, kb * 0.0), Color(n, kb), Color(n, ka)]))
		# the top band under the spine and the title
		if strong:
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 300), Vector2(0, 300)]), PackedColorArray([Color(n, 0.8), Color(n, 0.5), c1, c1]))
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(200, 0), Vector2(200, h), Vector2(0, h)]), PackedColorArray([Color(n, 0.7), Color(n, 0.0), Color(n, 0.0), Color(n, 0.7)]))
		# the bottom fades into the code band
		draw_polygon(PackedVector2Array([Vector2(0, h - 420), Vector2(w, h - 420), Vector2(w, h), Vector2(0, h)]), PackedColorArray([c1, c1, Color(n, 0.95), Color(n, 0.95)]))


class _Band:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(V10DS.NIGHT_900, V10DS.ON_ART_A))
		var c: = Color(V10DS.GOLD_500, 0.55)
		var c0: = Color(V10DS.GOLD_500, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, 1.5), Vector2(0, 1.5)]), PackedColorArray([c0, c, c, c0]))
		draw_polygon(PackedVector2Array([Vector2(size.x * 0.5, 0), Vector2(size.x, 0), Vector2(size.x, 1.5), Vector2(size.x * 0.5, 1.5)]), PackedColorArray([c, c0, c0, c]))
