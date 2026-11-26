extends "res://scripts/screens/modes.gd"

# «Столы» — the centre tab of 0.10 (UX_RULES §3.1–§3.2, MODES §6.1, docs/INTEGRATION_0.10.md §1, W4).
# ONE vertical screen in HUD v2 plates: the Path scroll (→ the full map), ★ «Играть · N»,
# the «Сегодня» row (Партия дня · Режим дня ×2 · Задача дня · Чтение руки), then three W4 shelves:
# Пасьянсы · За столом · Испытания и соперницы. A shelf shows open modes plus at most ONE teaser (P0-8).

const SHELVES: = [
	["Приключение · Битвы с монстрами", [
		["adventure", "Битва с монстрами"],
	]],
	["Пасьянсы", [
		["classic", "Классика"],
		["triples", "Тройки"],
		["connect", "Связи"],
		["garden", "Сад"],
		["cube", "Куб"],
	]],
	["За столом", [
		["bridge_hand", "Собери руку"],
		["hand", "Чтение руки"],
		["riichi", "Стол на четверых"],
		["sanma", "Стол на троих"],
		["koikoi", "Коикои"],
	]],
	["Испытания и соперницы", [
		["pagoda", "Пагода Луны"],
		["journey", "Странствие"],
		["duels", "Дуэли"],
		["challenge", "Вызов по коду"],
		["blitz", "Блиц"],
		["tourney", "Турнир недели"],
	]],
]
const X0: = 32.0
const COL_W: = 656.0
const CARD_W: = 320.0
const CARD_H: = 184.0
const CARD_GAP: = 16.0
const BANNER_H: = 248.0
const BG: = "res://assets/bg/"
const OUT: = "res://assets/outfits/"
const HF: = "res://assets/v10/hf_ui/"
# [artwork, focus (0..1 of the image), zoom, badge glyph ("nav:<n>" = tab art, else V8Art.icon)]
const ART: = {
	"daily": [HF + "banner_mc_tea.png", Vector2(0.5, 0.35), 1.0, "calendar"],
	"mode": [HF + "banner_nova.png", Vector2(0.5, 0.35), 1.0, "shuffle"],
	"bridge_daily": [HF + "banner_kohaku.png", Vector2(0.5, 0.32), 1.0, "hint"],
	"hand": [OUT + "yue_queen.webp", Vector2(0.5, 0.2), 1.0, "visits"],
	"classic": [HF + "banner_path.png", Vector2(0.5, 0.35), 1.0, "nav:play"],
	"triples": [HF + "banner_rin.png", Vector2(0.5, 0.32), 1.0, "tasks"],
	"connect": [HF + "banner_tsubame.png", Vector2(0.5, 0.32), 1.0, "shuffle"],
	"garden": [BG + "bg_shrine.webp", Vector2(0.4, 0.7), 1.3, "heart"],
	"cube": [HF + "banner_nova.png", Vector2(0.5, 0.4), 1.05, "rating"],
	"bridge_hand": [OUT + "mc_dragon.webp", Vector2(0.5, 0.2), 1.0, "hint"],
	"riichi": [HF + "banner_shirin.png", Vector2(0.5, 0.32), 1.0, "trophy"],
	"sanma": [OUT + "hana_street.webp", Vector2(0.5, 0.2), 1.0, "tasks"],
	"koikoi": [HF + "banner_story.png", Vector2(0.5, 0.35), 1.0, "heart"],
	"pagoda": ["res://assets/v10/tower/pagoda_far.webp", Vector2(0.5, 0.5), 1.0, "trophy"],
	"journey": ["res://assets/v10/tower/journey_far.webp", Vector2(0.5, 0.5), 1.0, "visits"],
	"duels": [OUT + "nova_ssr.webp", Vector2(0.5, 0.2), 1.0, "trophy"],
	"challenge": [HF + "banner_tsubame.png", Vector2(0.5, 0.35), 1.0, "letters"],
	"blitz": [HF + "banner_shirin.png", Vector2(0.5, 0.35), 1.0, "hint"],
	"tourney": ["res://assets/v08/ui/bg/tourney.webp", Vector2(0.5, 0.5), 1.0, "trophy"],
	"adventure": ["res://assets/v10/adventure/paper_oni.png", Vector2(0.5, 0.32), 1.0, "trophy"],
	"default": [HF + "banner_path.png", Vector2(0.5, 0.35), 1.0, "nav:play"],
}

var play_btn: V10Button
var scroll_plate: Control
var today_plates: = {}
var shelf_plates: = {}
var cx: = 0.0
var _scroll: ScrollContainer
var _body: Control


func build(m, args: Dictionary) -> void:
	main = m
	W = size.x
	H = size.y
	cx = floorf(maxf(0.0, (W - 720.0) * 0.5))
	main.show_chrome(false, true)
	Sfx.music("menu")
	var s: = V6ModesData.st()
	if not "hub" in s.seen:
		s.seen.append("hub")
		G.save()
	Common.backdrop(self, "menu", size, 2.4, 0.7)
	var tint: = ColorRect.new()
	tint.color = Color(V10DS.NIGHT_900, 0.74)
	var br: = V10Layout.bleed_rect(self)
	tint.position = br.position
	tint.size = br.size
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)
	V8Header.make(self, main, "Столы", Callable(), _hub_help)
	_scroll = ScrollContainer.new()
	_scroll.name = "TablesScroll"
	_scroll.position = Vector2(0.0, 104.0)
	_scroll.size = Vector2(W, maxf(400.0, H - 104.0 - 136.0))
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_body = Control.new()
	_body.name = "TablesBody"
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_body)
	var y: = 8.0
	# 1. the Path banner: chapter scenery + emblem + the big gold star counter → the full map
	var pi: = V10Nav.path_info()
	var stars: = 0
	for v in G.S.get("stars", {}).values() if G.S.get("stars") is Dictionary else []:
		stars += int(v)
	scroll_plate = _path_banner(pi, stars, y)
	_body.add_child(scroll_plate)
	y += BANNER_H + 56.0
	# 2. ★ «Играть · N»
	play_btn = V10Button.make("play", "Играть · %s" % pi.code, Vector2(440, 104))
	play_btn.overline = "Путь · %s" % pi.loc
	play_btn.name = "PlayPath"
	play_btn.set_meta("ux_role", "primary")
	play_btn.set_meta("tut_id", "tables.play")
	play_btn.position = Vector2(cx + (720.0 - 440.0) * 0.5, y)
	play_btn.pressed.connect(func() -> void: V10Nav.play_path(main))
	_body.add_child(play_btn)
	y += 104.0 + 20.0
	# 3. «Сегодня»: Партия дня · Режим дня (+ Задача дня from L22, Чтение руки from L30)
	if V10Nav.today_lit():
		y = _caption("Сегодня", y, V10DS.ROSE_500)
		var rows: = {}
		for r in V10Afisha.rows():
			rows[r.id] = r
		var today_list: Array = []
		for id in ["daily", "mode"]:
			if rows.has(id):
				today_list.append(rows[id])
		if int(G.S.get("unlocked", 1)) >= 22:
			var bd_done: = V10MjBridgeSave.answered(V10MjBridgeSave.st(G.S), V10Meta.cal_key())
			today_list.append({"id": "bridge_daily", "title": "Задача дня", "sub": "Какую фишку сбросить?", "open": true, "done": bd_done, "lock": ""})
		if V10HandState.is_open():
			var he: Dictionary = V10PalmInfo.afisha_entry()
			today_list.append({"id": "hand", "title": "Чтение руки", "sub": "Угадай ожидание дня", "open": true, "done": bool(he.get("done", false)), "lock": ""})
		var tn: = today_list.size()
		for ti in tn:
			var r: Dictionary = today_list[ti]
			var tid: = String(r.id)
			var sub_s: = String(r.get("mode_name", r.sub)) if tid == "mode" else String(r.sub)
			var open_t: = bool(r.open)
			var full_t: = ti == tn - 1 and tn % 2 == 1
			var wt: = COL_W if full_t else CARD_W
			var p: = _make_card(tid, String(r.title), sub_s, V10DS.ROSE_500, wt, open_t, bool(r.done))
			p.name = "Today_" + tid
			p.set_meta("ux_role", "secondary")
			p.position = Vector2(cx + X0 + (0.0 if full_t else (ti % 2) * (CARD_W + CARD_GAP)), y + (ti / 2) * (CARD_H + CARD_GAP))
			var rr: = r
			p.pressed.connect(func() -> void:
				if not bool(rr.open):
					main.toast(String(rr.lock), "lock")
				elif rr.id == "daily":
					Daily.calendar(main)
				elif rr.id == "bridge_daily":
					_open_v10("bridge_daily")
				elif rr.id == "hand":
					_open_v10("hand")
				else:
					_open_v10(String(rr.mode)))
			_body.add_child(p)
			today_plates[tid] = p
		y += ceilf(tn / 2.0) * (CARD_H + CARD_GAP) + 8.0
	# 4. W4 shelves (P0-8: open modes + at most ONE teaser per shelf)
	var si: = 0
	for sh in SHELVES:
		var items: = []
		var teaser: = []
		for it in sh[1]:
			if _mode_is_open(it[0]):
				items.append(it)
			elif teaser.is_empty():
				teaser = it
		if not teaser.is_empty():
			items.append(teaser)
		if items.is_empty():
			si += 1
			continue
		var acc: = _shelf_accent(si)
		si += 1
		y = _caption(sh[0], y, acc)
		var n: = items.size()
		for i in n:
			var it: Array = items[i]
			var id: String = it[0]
			var open: = _mode_is_open(id)
			var full: = i == n - 1 and n % 2 == 1
			var p: = _make_card(id, it[1], _status_v10(id) if open else _lock_v10(id), acc, COL_W if full else CARD_W, open, false)
			p.name = "Mode_" + id
			p.set_meta("tut_id", "tables.tourney" if id == "tourney" else "tables.mode." + id)
			p.position = Vector2(cx + X0 + (0.0 if full else (i % 2) * (CARD_W + CARD_GAP)), y + (i / 2) * (CARD_H + CARD_GAP))
			p.pressed.connect(func() -> void: _open_v10(id))
			_body.add_child(p)
			shelf_plates[id] = p
			mode_tiles[id] = p
		y += ceilf(n / 2.0) * (CARD_H + CARD_GAP) + 8.0
	_body.custom_minimum_size = Vector2(W, y + 28.0)
	var open_arg: String = args.get("open", args.get("mode", ""))
	if open_arg != "":
		await get_tree().create_timer(0.35).timeout
		if is_inside_tree():
			_open_v10(open_arg)


func _shelf_accent(i: int) -> Color:
	match i:
		0:
			return V10DS.JADE_300
		1:
			return V10DS.GOLD_500
	return Color(V10DS.hero("yue").accent)


func _make_card(id: String, title: String, sub: String, accent: Color, w: float, open: bool, done: bool) -> Control:
	var c: = _Card.new()
	var spec: Array = ART.get(id, ART["default"])
	c.setup(Vector2(w, CARD_H), title, sub, accent, open, done, spec)
	return c


func _path_banner(pi: Dictionary, stars: int, y: float) -> Control:
	var wd: int = int(V10PathState.node(int(pi.lvl)).get("world", 0))
	var cv: Texture2D = null
	var cp: = "res://assets/v10/path/cover_w%d.webp" % (clampi(wd, 0, 5) + 1)
	if ResourceLoader.exists(cp):
		cv = load(cp)
	var spec: Array = [cp, Vector2(0.5, 0.5), 1.0, ""]
	var c: = _Card.new()
	c.banner = true
	c.setup(Vector2(COL_W, BANNER_H), "", "", V10DS.GOLD_500, true, false, spec)
	c.name = "PathScroll"
	c.set_meta("ux_role", "secondary")
	c.set_meta("tut_id", "tables.scroll")
	c.position = Vector2(cx + X0, y)
	c.pressed.connect(func() -> void: main.go("v10path", {"select": int(pi.lvl)}))
	# chapter emblem
	var em: = TextureRect.new()
	var ep: = "res://assets/v10/path/ic_scroll.png"
	if ResourceLoader.exists(ep):
		em.texture = load(ep)
	em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	em.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	em.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	em.mouse_filter = Control.MOUSE_FILTER_IGNORE
	em.position = Vector2(26, 28)
	em.size = Vector2(76, 76)
	c.add_child(em)
	c.add_child(_lbl("ПУТЬ · ГЛАВА", "overline", 18, V10DS.GOLD_300, Vector2(116, 24), Vector2(300, 26)))
	var tfs: = 40
	for k in [40, 36, 32, 28]:
		tfs = k
		if V10Type.text_w(String(pi.loc), "display", k) <= 330.0:
			break
	c.add_child(_lbl(String(pi.loc), "display", tfs, V10DS.PAPER_100, Vector2(116, 50), Vector2(340, 56)))
	c.add_child(_lbl("Стол %s" % pi.code, "ui_strong", 24, V10DS.PAPER_300, Vector2(116, 108), Vector2(300, 34)))
	# the gold star counter plaque
	var sp: = _StarPlaque.new()
	sp.count = stars
	sp.position = Vector2(COL_W - 24.0 - 188.0, 22.0)
	sp.size = Vector2(188, 112)
	c.add_child(sp)
	var go: = _lbl("Открыть карту  ›", "ui_strong", 24, V10DS.GOLD_300, Vector2(28, BANNER_H - 66.0), Vector2(260, 36))
	c.add_child(go)
	var nodes: = _Nodes.new(int(pi.lvl))
	nodes.position = Vector2(COL_W - 24.0 - 176.0, BANNER_H - 70.0)
	nodes.size = Vector2(176, 48)
	c.add_child(nodes)
	return c


static func _lbl(text: String, role: String, size_px: int, col: Color, pos: Vector2, sz: Vector2, align: = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l: = V10Type.label(text, role, size_px, col, true)
	var ls: = l.label_settings.duplicate() as LabelSettings
	ls.shadow_color = Color(V10DS.NIGHT_900, 0.9)
	ls.shadow_size = 8
	ls.shadow_offset = Vector2(0, 2)
	l.label_settings = ls
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	return l


func _caption(text: String, y: float, accent: Color) -> float:
	var l: = _lbl(text, "display", 30, V10DS.GOLD_300, Vector2(cx + X0 + 36.0, y), Vector2(COL_W - 40.0, 44))
	l.clip_text = false
	_body.add_child(l)
	var orn: = Control.new()
	orn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orn.position = Vector2(cx + X0, y)
	orn.size = Vector2(COL_W, 44)
	var tw: = V10Type.text_w(text, "display", 30)
	orn.draw.connect(func() -> void:
		var c: = Vector2(13, 24)
		var d: = 10.0
		orn.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), V10DS.GOLD_500)
		orn.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d + 4), c + Vector2(d - 4, 0), c + Vector2(0, d - 4), c + Vector2(-d + 4, 0)]), accent)
		var x0: = 36.0 + tw + 18.0
		orn.draw_polyline_colors(PackedVector2Array([Vector2(x0, 25), Vector2(x0 + 120, 25), Vector2(COL_W, 25)]),
				PackedColorArray([Color(V10DS.GOLD_500, 0.9), Color(accent, 0.45), Color(accent, 0.0)]), 2.0, true))
	_body.add_child(orn)
	return y + 56.0


func _mode_is_open(id: String) -> bool:
	var u: = int(G.S.get("unlocked", 1))
	match id:
		"adventure":
			return true
		"classic":
			return u >= 10
		"triples":
			return u >= 14
		"connect":
			return u >= 18
		"garden":
			return V10MjGardenInfo.is_open(int(G.S.get("rp", 0)), V6ModesData.mode_open("zen"))
		"cube":
			return u >= 40
		"bridge_daily":
			return u >= 22
		"bridge_hand":
			return u >= 26
		"hand":
			return V10HandState.is_open()
		"riichi":
			return u >= 34 or bool(V10MjBridgeSave.st(G.S).get("riichi_open", false))
		"sanma":
			var rs: Dictionary = G.S.get("v10_mj_riichi", {}) if G.S.get("v10_mj_riichi") is Dictionary else {}
			return V10MjSanmaInfo.unlocked(int(rs.get("games", 0)))
		"koikoi":
			return V10MjKoikoiInfo.unlocked(u)
		"pagoda":
			return V10Pagoda.is_open()
		"journey":
			return V10Journey.is_open()
		"duels":
			return V10Duel.menu_open()
		"challenge":
			return true
		"tourney":
			return u >= V10Nav.WEEK_AT
	return V6ModesData.mode_open(id)


func _lock_v10(id: String) -> String:
	match id:
		"adventure":
			return ""
		"classic":
			return "Откроется на уровне 10"
		"triples":
			return "Откроется на уровне 14"
		"connect":
			return "Откроется на уровне 18"
		"garden":
			return V10MjGardenInfo.lock_text()
		"cube":
			return "Откроется на уровне 40"
		"bridge_daily":
			return "Откроется на уровне 22"
		"bridge_hand":
			return "Откроется на уровне 26"
		"hand":
			return V10HandState.lock_text()
		"riichi":
			return "Уровень 34 или 3 Задачи дня"
		"sanma":
			return "После 3 партий за столом"
		"koikoi":
			return "Откроется на уровне 45"
		"pagoda":
			return V10Pagoda.locked_text()
		"journey":
			return V10Journey.locked_text()
		"duels":
			return V10Duel.lock_text("menu")
		"tourney":
			return V10Nav.T_LOCK % (V10Nav.WEEK_AT - 1)
	return V6ModesData.locked_text(id)


func _status_v10(id: String) -> String:
	match id:
		"adventure":
			var ai: Dictionary = V10AdventureData.hub_card_info()
			return String(ai.get("subtitle", "Сразись с ёкай-боссами"))
		"classic":
			return "Свободная · День · Память"
		"triples":
			return "Собирай по три в лотке"
		"connect":
			return "Линии до двух поворотов"
		"garden":
			return "Волна за волной без спешки"
		"cube":
			return "Объёмные фигуры 3D"
		"bridge_hand":
			return "Четыре набора и пара"
		"hand":
			var he: Dictionary = V10PalmInfo.afisha_entry()
			return "Догадка сделана" if bool(he.get("done", false)) else "Угадай ожидание дня"
		"riichi":
			return "Японский маджонг на четверых"
		"sanma":
			return "Втроём, дороже и быстрее"
		"koikoi":
			return "Карты месяцев, рискни ещё раз"
		"pagoda":
			var pst: Dictionary = V10Pagoda.st()
			var b: = int(pst.get("best", {}).get("0", 0))
			return "Рекорд: %d эт." % b if b > 0 else "Бесконечная башня"
		"journey":
			var wi: Dictionary = V10Journey.week_info()
			return "Попытки %d/%d" % [int(wi.get("attempts_left", 0)), int(wi.get("attempts_max", 2))]
		"duels":
			var ds: Dictionary = V10DuelInfo.status()
			var txt: = String(ds.get("text", ""))
			return txt if txt != "" else "Гонка за парами"
		"challenge":
			return "Тот же стол друга по коду"
		"tourney":
			return "Твоя группа недели"
	return _status(id)


func _open_v10(id: String) -> void:
	if id == "zen":
		id = "garden"
	elif id == "climb":
		id = "pagoda"
	elif id == "duel":
		id = "duels"
	if not _mode_is_open(id):
		main.toast(_lock_v10(id), "lock")
		return
	var hero: String = G.S.partner if G.hero_unlocked(G.S.partner) else "mc"
	match id:
		"adventure":
			var ai2: Dictionary = V10AdventureData.hub_card_info()
			main.go("adventure", {"stage": int(ai2.get("stage", 0)), "hero": hero})
		"classic":
			main.go("mj_classic_lobby", {"hero": "mc", "partner": hero})
		"triples":
			main.go("mj_triples", {"hero": "hana"})
		"connect":
			main.go("mj_connect", {"hero": "rin"})
		"garden":
			main.go("mj_garden", {"hero": "yue"})
		"cube":
			main.go("mj_cube", {"hero": "nova"})
		"bridge_daily":
			main.go("mj_bridge_daily", {"hero": "mc"})
		"bridge_hand":
			main.go("mj_bridge_hand", {"hero": "hana"})
		"hand":
			main.go("hand", {"back": "tables"})
		"riichi":
			main.go("mj_riichi", {"hero": "mc"})
		"sanma":
			main.go("mj_sanma", {"hero": "yue"})
		"koikoi":
			main.go("mj_koikoi", {"hero": "rin"})
		"pagoda":
			main.go("pagoda", {})
		"journey":
			main.go("journey", {})
		"duels":
			main.go("duels", {})
		"challenge":
			main.go("challenge", {})
		"tourney":
			main.go("v7tourney", {"tab": "week"})
		_:
			_open(id)


func _hub_help() -> void:
	V10Help.open(main, "tables")


func dev_act(a: String) -> void :
	if a.begins_with("scroll"):  # dev screenshots: --act=scroll800
		_scroll.scroll_vertical = int(a.substr(6))
		return
	_open_v10(a)


# five nearest Path tables as dots on a thread: done (gold), current (rose), ahead (paper)
class _Nodes:
	extends Control
	var cur: = 0

	func _init(c: int) -> void:
		cur = c
		custom_minimum_size = Vector2(160, 48)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var nodes: Array[int] = []
		var k0: = maxi(0, cur - 2)
		while nodes.size() < 5 and k0 < V10LevelGen.TOTAL:
			if not V10LevelGen.is_peak(k0):
				nodes.append(k0)
			k0 += 1
		var n: = nodes.size()
		if n < 2:
			return
		var x0: = 12.0
		var step: = (size.x - 24.0) / (n - 1)
		var yc: = size.y * 0.5
		draw_line(Vector2(x0, yc), Vector2(x0 + step * (n - 1), yc), Color(V10DS.PAPER_700, 0.6), 1.0, true)
		for i in n:
			var k: int = nodes[i]
			var done: = V10PathState.stars(k) > 0 or V10PathState.bypassed(k)
			var c: = V10DS.ROSE_500 if k == cur else (V10DS.GOLD_300 if done else V10DS.PAPER_700)
			draw_circle(Vector2(x0 + step * i, yc), 9.0 if k == cur else 6.0, c, true, -1.0, true)


# ── illustrated card (Wave 2): gold-framed artwork, readability scrim, accent badge, big title ──────────
class _Card:
	extends Control
	signal pressed
	var disabled: = false
	var banner: = false
	var accent: = Color.WHITE
	var is_open: = true
	var done: = false
	var _down: = false
	var _over: Control
	var _title: String = ""
	var _sub: String = ""
	var _spec: Array = []
	var _glyph: Texture2D = null

	func setup(sz: Vector2, title: String, sub: String, acc: Color, open: bool, is_done: bool, spec: Array) -> void:
		size = sz
		custom_minimum_size = sz
		pivot_offset = sz * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP
		accent = acc
		is_open = open
		disabled = not open
		done = is_done
		_title = title
		_sub = sub
		_spec = spec
		var g: String = String(spec[3]) if spec.size() > 3 else ""
		if g.begins_with("nav:"):
			_glyph = V8Art.nav(g.substr(4))
		elif g != "":
			_glyph = V8Art.icon(g)
		var ap: String = String(spec[0])
		if ResourceLoader.exists(ap):
			var tex: Texture2D = load(ap)
			var inset: = 4.0
			var art: = Common.card_art(tex, Rect2(Vector2(inset, inset), sz - Vector2(inset, inset) * 2.0), Vector2(spec[1]), float(spec[2]), 12.0)
			var mat: = art.material as ShaderMaterial
			mat.set_shader_parameter("bottom_shade", 0.0)
			if not open:
				mat.set_shader_parameter("gray", 0.88)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(art)
		_over = Control.new()
		_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_over.size = sz
		_over.draw.connect(_draw_over)
		add_child(_over)
		if not banner:
			_build_text()

	static func _mk(text: String, role: String, size_px: int, col: Color, pos: Vector2, sz: Vector2) -> Label:
		var l: = V10Type.label(text, role, size_px, col, true)
		var ls: = l.label_settings.duplicate() as LabelSettings
		ls.shadow_color = Color(V10DS.NIGHT_900, 0.9)
		ls.shadow_size = 8
		ls.shadow_offset = Vector2(0, 2)
		l.label_settings = ls
		l.position = pos
		l.size = sz
		return l

	func _build_text() -> void:
		var w: = size.x
		var tw: = w - 32.0
		var lines: = 1 if V10Type.text_w(_sub, "ui_strong", 20) <= tw else 2
		var sub_h: = 28.0 * float(mini(lines, 2))
		var tfs: = 28
		for k in [28, 26, 24, 22]:
			tfs = k
			if V10Type.text_w(_title, "display", k) <= tw:
				break
		var ty: = size.y - 16.0 - sub_h - 40.0
		var tcol: = V10DS.PAPER_100 if is_open else V10DS.PAPER_300
		add_child(_mk(_title, "display", tfs, tcol, Vector2(16, ty), Vector2(tw, 40)))
		var sl: = _mk(_sub, "ui_strong", 20, V10DS.PAPER_300 if is_open else V10DS.PAPER_500, Vector2(16, ty + 40.0), Vector2(tw, sub_h))
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.max_lines_visible = 2
		sl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		add_child(sl)

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		var rad: = 16.0
		draw_colored_polygon(V10Button.rr_pts(Rect2(Vector2(0, 5), size).grow(1.0), rad + 1.0, 8), Color(V10DS.NIGHT_900, 0.55))
		var op: = V10Button.rr_pts(r, rad, 8)
		var ga: = 1.0 if is_open else 0.5
		draw_polygon(op, V10Button.grad_cols(op, 0.0, size.y, [[0.0, Color(V10DS.PLATE_SPARK, ga)], [0.5, Color(V10DS.GOLD_500, ga)], [1.0, Color(V10DS.GOLD_700, ga)]]))
		var r2: = r.grow(-2.5)
		draw_colored_polygon(V10Button.rr_pts(r2, rad - 2.5, 8), V10DS.NIGHT_900)
		var r3: = r.grow(-3.5)
		var p3: = V10Button.rr_pts(r3, rad - 3.5, 8)
		draw_polygon(p3, V10Button.grad_cols(p3, 0.0, size.y, [[0.0, V10DS.PLATE_TOP], [1.0, V10DS.PLATE_BOT]]))

	func _draw_over() -> void:
		var o: = _over
		var sz: = size
		var ar: = Rect2(Vector2(4, 4), sz - Vector2(8, 8))
		var pts: = V10Button.rr_pts(ar, 12.0, 8)
		var n9: = V10DS.NIGHT_900
		# readability scrim: calm at the top (the art breathes), deep at the text
		var stops: Array = [[0.0, Color(n9, 0.10)], [0.34, Color(n9, 0.22)], [0.62, Color(n9, 0.74)], [1.0, Color(n9, 0.96)]]
		if banner:
			stops = [[0.0, Color(n9, 0.28)], [0.55, Color(n9, 0.5)], [1.0, Color(n9, 0.92)]]
		o.draw_polygon(pts, V10Button.grad_cols(pts, ar.position.y, ar.end.y, stops))
		if banner:  # extra left shade under the title block
			var cols: = PackedColorArray()
			for p in pts:
				cols.append(Color(n9, lerpf(0.78, 0.0, clampf((p.x - ar.position.x) / (ar.size.x * 0.8), 0.0, 1.0))))
			o.draw_polygon(pts, cols)
		if not is_open:
			o.draw_colored_polygon(pts, Color(n9, 0.38))
		# inner gold hairline + accent underline
		var hp: = V10Button.rr_pts(ar.grow(-3.0), 9.0, 8)
		hp.append(hp[0])
		o.draw_polyline(hp, Color(V10DS.GOLD_300, 0.30 if is_open else 0.12), 1.2, true)
		var ay: = sz.y - 9.0
		o.draw_polyline_colors(PackedVector2Array([Vector2(18, ay), Vector2(sz.x * 0.5, ay), Vector2(sz.x - 18, ay)]),
				PackedColorArray([Color(accent, 0.95 if is_open else 0.35), Color(accent, 0.55 if is_open else 0.15), Color(accent, 0.0)]), 3.0, true)
		# corner studs
		for cxy in [Vector2(9, 9), Vector2(sz.x - 9, 9), Vector2(9, sz.y - 9), Vector2(sz.x - 9, sz.y - 9)]:
			o.draw_colored_polygon(PackedVector2Array([cxy + Vector2(0, -3.2), cxy + Vector2(3.2, 0), cxy + Vector2(0, 3.2), cxy + Vector2(-3.2, 0)]), Color(V10DS.PLATE_SPARK, 0.9 if is_open else 0.4))
		if banner:
			return
		# accent badge (top-left): gold ring · dark lacquer · accent ring · glyph
		var c: = Vector2(46, 46)
		o.draw_circle(c + Vector2(0, 3), 30, Color(n9, 0.6), true, -1.0, true)
		o.draw_circle(c, 30, V10DS.GOLD_500 if is_open else V10DS.GOLD_700, true, -1.0, true)
		o.draw_circle(c, 27.5, n9, true, -1.0, true)
		o.draw_circle(c, 26, accent.darkened(0.55), true, -1.0, true)
		o.draw_arc(c, 24.5, 0, TAU, 48, Color(accent, 0.95 if is_open else 0.4), 2.2, true)
		if _glyph != null:
			o.draw_texture_rect(_glyph, Rect2(c - Vector2(19, 19), Vector2(38, 38)), false, Color.WHITE if is_open else Color(1, 1, 1, 0.55))
		# status chip (top-right): done ✓ or lock
		var sc: = Vector2(sz.x - 40, 40)
		if not is_open:
			o.draw_circle(sc, 22, Color(n9, 0.82), true, -1.0, true)
			o.draw_arc(sc, 21, 0, TAU, 40, Color(V10DS.GOLD_700, 0.9), 1.6, true)
			var lk: = V8Art.icon("lock")
			if lk != null:
				o.draw_texture_rect(lk, Rect2(sc - Vector2(15, 15), Vector2(30, 30)), false)
		elif done:
			o.draw_circle(sc, 22, V10DS.GOLD_500, true, -1.0, true)
			o.draw_circle(sc, 19, V10DS.JADE_500, true, -1.0, true)
			o.draw_polyline(PackedVector2Array([sc + Vector2(-9, 0), sc + Vector2(-3, 7), sc + Vector2(10, -8)]), V10DS.PAPER_100, 3.5, true)

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
			if e.pressed:
				_down = true
				var tw: = create_tween()
				tw.tween_property(self, "scale", Vector2.ONE * 0.97, 0.06)
			elif _down:
				_down = false
				var tw2: = create_tween()
				tw2.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				if Rect2(Vector2.ZERO, size).grow(12).has_point(e.position):
					pressed.emit()
			accept_event()


# gold star counter of the Path banner
class _StarPlaque:
	extends Control
	var count: = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		V10Button.lacquer(self, r, 22.0, V10DS.BTN_SEC_TOP, V10DS.BTN_SEC_TOP.lerp(V10DS.BTN_SEC_BOT, 0.5), V10DS.BTN_SEC_BOT)
		var st: = V8Art.star(true)
		if st != null:
			draw_texture_rect(st, Rect2(Vector2(16, 14), Vector2(64, 64)), false)
		var f: = V10Type.font("num")
		var t: = str(count)
		var fs: = 40 if t.length() <= 4 else 32
		draw_string_outline(f, Vector2(88, 56), t, HORIZONTAL_ALIGNMENT_LEFT, size.x - 96.0, fs, 6, V10DS.BTN_PLAY_OUTLINE)
		draw_string(f, Vector2(88, 56), t, HORIZONTAL_ALIGNMENT_LEFT, size.x - 96.0, fs, V10DS.GOLD_300)
		var f2: = V10Type.font("ui_strong")
		draw_string(f2, Vector2(16, 98), "собрано звёзд", HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 18, V10DS.PAPER_300)
