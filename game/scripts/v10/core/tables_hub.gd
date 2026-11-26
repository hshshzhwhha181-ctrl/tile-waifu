extends "res://scripts/screens/modes.gd"

# «Столы» — the centre tab of 0.10 (UX_RULES §3.1–§3.2, MODES §6.1, docs/INTEGRATION_0.10.md §1, W1 skeleton).
# ONE vertical screen in HUD v2 plates: the Path scroll (→ the full map, the old `levels` screen), ★ «Играть · N»,
# the «Сегодня» row (Партия дня · Режим дня ×2, the same rows as the Afisha), then three shelves with the 0.9 modes:
# Испытания · Соперницы · Для души. A shelf shows only open modes plus at most ONE teaser («Откроется: …»), no
# «Скоро», no walls of locks (P0-8). It extends the 0.9 «Режимы» screen to keep its mode launchers (_open, _info,
# _duel_pick) — W4 replaces the shelves with the MODES §7.1 contract (mj-*, tower).

const SHELVES: = [
	["Испытания", [["climb", "Лунная лестница"]]],
	["Соперницы", [["duel", "Дуэли"], ["tourney", "Турнир недели"]]],
	["Для души", [["zen", "Сад"], ["etude", "Этюды"], ["blitz", "Блиц"], ["shift", "Смена в чайной"]]],
]
const X0: = 32.0
const COL_W: = 656.0

var play_btn: V10Button
var scroll_plate: V10Plate
var today_plates: = {}
var shelf_plates: = {}
var cx: = 0.0


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
	var y: = 104.0
	# 1. the Path scroll: five nearest tables + the chapter → the full map (1)
	var pi: = V10Nav.path_info()
	var stars: = 0
	for v in G.S.get("stars", {}).values() if G.S.get("stars") is Dictionary else []:
		stars += int(v)
	scroll_plate = V10Plate.make("L", 656, "Путь · %s" % pi.loc, "Стол %s · ★ %d" % [pi.code, stars])
	scroll_plate.interactive = true
	scroll_plate.name = "PathScroll"
	scroll_plate.set_meta("ux_role", "secondary")
	scroll_plate.right_slot = _Nodes.new(int(pi.lvl))
	scroll_plate.position = Vector2(cx + X0, y)
	scroll_plate.pressed.connect(func() -> void: main.go("v10path", {"select": int(pi.lvl)}))
	add_child(scroll_plate)
	y += 160.0 + 48.0
	# 2. ★ «Играть · N»
	play_btn = V10Button.make("play", "Играть · %s" % pi.code, Vector2(440, 104))
	play_btn.overline = "Путь · %s" % pi.loc
	play_btn.name = "PlayPath"
	play_btn.set_meta("ux_role", "primary")
	play_btn.position = Vector2(cx + (720.0 - 440.0) * 0.5, y)
	play_btn.pressed.connect(func() -> void: V10Nav.play_path(main))
	add_child(play_btn)
	y += 104.0 + 32.0
	# 3. «Сегодня»: Партия дня · Режим дня ×2 (from L6, like the lantern)
	if V10Nav.today_lit():
		y = _caption("Сегодня", y)
		var rows: = {}
		for r in V10Afisha.rows():
			rows[r.id] = r
		var x: = cx + X0
		for id in ["daily", "mode"]:
			if not rows.has(id):
				continue
			var r: Dictionary = rows[id]
			var p: = V10Plate.make("M", 328, str(r.title), str(r.get("mode_name", r.sub)) if id == "mode" else str(r.sub),
				"✓" if bool(r.done) else "")
			p.interactive = true
			p.disabled = not bool(r.open)
			p.name = "Today_" + id
			p.set_meta("ux_role", "secondary")
			p.position = Vector2(x, y)
			var rr: = r
			p.pressed.connect(func() -> void:
				if not bool(rr.open):
					main.toast(str(rr.lock), "lock")
				elif rr.id == "daily":
					Daily.calendar(main)
				else:
					_open(str(rr.mode)))
			add_child(p)
			today_plates[id] = p
			x += 328.0 + 0.0
		y += 80.0 + 24.0
	# 4. shelves
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
			var open: = _mode_is_open(it[0])
			var p: = V10Plate.make("M", 328, it[1], _status_v10(it[0]) if open else _lock_v10(it[0]))
			p.interactive = true
			p.disabled = not open
			p.name = "Mode_" + str(it[0])
			p.position = Vector2(cx + X0 + (i % 2) * 328.0, y + (i / 2) * 88.0)
			var id: String = it[0]
			p.pressed.connect(func() -> void: _open_v10(id))
			add_child(p)
			shelf_plates[id] = p
			mode_tiles[id] = p
		y += ceilf(items.size() / 2.0) * 88.0 + 16.0
	var open: String = args.get("open", args.get("mode", ""))
	if open != "":
		await get_tree().create_timer(0.35).timeout
		if is_inside_tree():
			_open_v10(open)


func _caption(text: String, y: float) -> float:
	var l: = V10Type.label(text.to_upper(), "overline", 15, V10DS.GOLD_500)
	l.position = Vector2(cx + X0, y)
	l.size = Vector2(COL_W, 22)
	add_child(l)
	return y + 30.0


func _mode_is_open(id: String) -> bool:
	if id == "tourney":
		return int(G.S.get("unlocked", 1)) >= V10Nav.WEEK_AT
	return V6ModesData.mode_open(id)


func _lock_v10(id: String) -> String:
	if id == "tourney":
		return V10Nav.T_LOCK % (V10Nav.WEEK_AT - 1)
	return V6ModesData.locked_text(id)


func _status_v10(id: String) -> String:
	if id == "tourney":
		return "Твоя группа недели"
	return _status(id)


func _open_v10(id: String) -> void:
	if id == "tourney":
		if _mode_is_open(id):
			main.go("v7tourney", {"tab": "week"})
		else:
			main.toast("Турнир недели · " + _lock_v10(id).to_lower(), "lock")
		return
	_open(id)


func _hub_help() -> void:
	var p: = Common.popup(main, "Столы", 520)
	var l: = UI.label("Здесь Путь и все режимы. «Играть» сажает за следующий стол Пути. Свиток открывает карту.\n\n«Сегодня» — партия дня и режим дня: в нём монеты и очки ранга ×2.\n\nНовые режимы открываются по мере игры, на полке виден только следующий.", 21, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(40, 64)
	l.size = Vector2(580, 380)
	p.add_child(l)


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
