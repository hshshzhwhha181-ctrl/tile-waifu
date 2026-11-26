extends "res://scripts/screens/modes.gd"

# «Столы» — the centre tab of 0.10 (UX_RULES §3.1–§3.2, MODES §6.1, docs/INTEGRATION_0.10.md §1, W4).
# ONE vertical screen in HUD v2 plates: the Path scroll (→ the full map), ★ «Играть · N»,
# the «Сегодня» row (Партия дня · Режим дня ×2 · Задача дня · Чтение руки), then three W4 shelves:
# Пасьянсы · За столом · Испытания и соперницы. A shelf shows open modes plus at most ONE teaser (P0-8).

const SHELVES: = [
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

var play_btn: V10Button
var scroll_plate: V10Plate
var today_plates: = {}
var shelf_plates: = {}
var cx: = 0.0
var _scroll: ScrollContainer
var _body: Control


func build(m, args: Dictionary) -> void :
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
	tint.color = Color(V10DS.NIGHT_900, 0.62)
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
	var y: = 0.0
	# 1. the Path scroll: five nearest tables + the chapter → the full map
	var pi: = V10Nav.path_info()
	var stars: = 0
	for v in G.S.get("stars", {}).values() if G.S.get("stars") is Dictionary else []:
		stars += int(v)
	scroll_plate = V10Plate.make("L", 656, "Путь · %s" % pi.loc, "Стол %s · ★ %d" % [pi.code, stars])
	scroll_plate.interactive = true
	scroll_plate.name = "PathScroll"
	scroll_plate.set_meta("ux_role", "secondary")
	scroll_plate.set_meta("tut_id", "tables.scroll")
	scroll_plate.right_slot = _Nodes.new(int(pi.lvl))
	scroll_plate.position = Vector2(cx + X0, y)
	scroll_plate.pressed.connect(func() -> void: main.go("v10path", {"select": int(pi.lvl)}))
	_body.add_child(scroll_plate)
	y += 160.0 + 40.0
	# 2. ★ «Играть · N»
	play_btn = V10Button.make("play", "Играть · %s" % pi.code, Vector2(440, 104))
	play_btn.overline = "Путь · %s" % pi.loc
	play_btn.name = "PlayPath"
	play_btn.set_meta("ux_role", "primary")
	play_btn.set_meta("tut_id", "tables.play")
	play_btn.position = Vector2(cx + (720.0 - 440.0) * 0.5, y)
	play_btn.pressed.connect(func() -> void: V10Nav.play_path(main))
	_body.add_child(play_btn)
	y += 104.0 + 28.0
	# 3. «Сегодня»: Партия дня · Режим дня ×2 (+ Задача дня from L22, Чтение руки from L30)
	if V10Nav.today_lit():
		y = _caption("Сегодня", y)
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
		for ti in today_list.size():
			var r: Dictionary = today_list[ti]
			var tid: = String(r.id)
			var sub_s: = String(r.get("mode_name", r.sub)) if tid == "mode" else String(r.sub)
			var p: = V10Plate.make("M", 328, String(r.title), sub_s, "✓" if bool(r.done) else "")
			p.interactive = true
			p.disabled = not bool(r.open)
			p.name = "Today_" + tid
			p.set_meta("ux_role", "secondary")
			p.position = Vector2(cx + X0 + (ti % 2) * 328.0, y + (ti / 2) * 88.0)
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
		y += ceilf(today_list.size() / 2.0) * 88.0 + 16.0
	# 4. W4 shelves (P0-8: open modes + at most ONE teaser per shelf)
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
			continue
		y = _caption(sh[0], y)
		for i in items.size():
			var it: Array = items[i]
			var id: String = it[0]
			var open: = _mode_is_open(id)
			var p: = V10Plate.make("M", 328, it[1], _status_v10(id) if open else _lock_v10(id))
			p.interactive = true
			p.disabled = not open
			p.name = "Mode_" + id
			p.set_meta("tut_id", "tables.tourney" if id == "tourney" else "tables.mode." + id)
			p.position = Vector2(cx + X0 + (i % 2) * 328.0, y + (i / 2) * 88.0)
			p.pressed.connect(func() -> void: _open_v10(id))
			_body.add_child(p)
			shelf_plates[id] = p
			mode_tiles[id] = p
		y += ceilf(items.size() / 2.0) * 88.0 + 16.0
	_body.custom_minimum_size = Vector2(W, y + 28.0)
	var open_arg: String = args.get("open", args.get("mode", ""))
	if open_arg != "":
		await get_tree().create_timer(0.35).timeout
		if is_inside_tree():
			_open_v10(open_arg)


func _caption(text: String, y: float) -> float:
	var l: = V10Type.label(text.to_upper(), "overline", 15, V10DS.GOLD_500)
	l.position = Vector2(cx + X0, y)
	l.size = Vector2(COL_W, 22)
	_body.add_child(l)
	return y + 30.0


func _mode_is_open(id: String) -> bool:
	var u: = int(G.S.get("unlocked", 1))
	match id:
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
