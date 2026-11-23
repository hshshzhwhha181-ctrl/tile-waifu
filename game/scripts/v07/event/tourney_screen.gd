extends Control


var main
var W: = 720.0
var H: = 1280.0
var list: VBoxContainer
var scroll: ScrollContainer
var table_btns: Array = []

func build(m, _args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	main.show_chrome(true, true)
	Sfx.music("menu")
	var t: = V7Ladder.st()
	var L: Dictionary = V7Ladder.LEAGUES[int(t.league)]
	Common.backdrop(self, "bg_festival", size, 2.6, 0.55, Color(1, 0.95, 0.95))
	Fx.ambient(self, "lanterns", size)
	Common.vignette(self, size, Color(0.08, 0.04, 0.1), 0.65)
	var rows: = V7Ladder.group(t)
	var place: = V7Ladder.place_of(rows)
	_header(t, L, place)
	_prize(t)
	_tables(t)
	_board(t, rows)
	V7Event.show_pending(self, main)
	G.save()

func _header(t: Dictionary, L: Dictionary, place: int) -> void :
	var r: = Rect2(16, 124, W - 32, 190)
	var card: = UI.rbox("plum", r, 28, 4, 10)
	card.colors(Color(0.12, 0.06, 0.16, 1.0), Color(0.08, 0.04, 0.1, 1.0)).borders(Color("ffe7a6"), Color("c58a2c"))
	add_child(card)
	var art: = Common.card_art(load("res://assets/v07/event/cg_finale_wide.webp"), Rect2(4, 4, r.size.x - 8, r.size.y - 8), Vector2(0.5, 0.55), 1.0, 24)
	card.add_child(art)
	var shade: = ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.07, 0.55)
	shade.position = Vector2(4, 4)
	shade.size = r.size - Vector2(8, 8)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shade)
	var tt: = UI.title("Турнир недели", 40, Color("fff3dc"), UI.DARK)
	tt.position = Vector2(22, 14)
	tt.size = Vector2(440, 54)
	card.add_child(tt)
	var lc: = UI.rbox("plum", Rect2(22, 74, 250, 46), 23, 3, 6)
	lc.colors(Color(L.color.darkened(0.55), 0.95), Color(L.color.darkened(0.8), 0.95)).borders(L.color, L.color.darkened(0.4))
	card.add_child(lc)
	lc.add_child(UI.center_label(UI.label(L.name, 21, L.color.lightened(0.3), UI.DARK, 3, "body", 900), Rect2(0, 0, 250, 46)))
	var left: = UI.label("До конца недели: " + V7EventData.left_text(V7Ladder.left_secs()), 18, Color("ffd98a"), UI.DARK, 3, "body", 900)
	left.position = Vector2(24, 132)
	card.add_child(left)
	var my: = V7Ladder.my_score(t)
	var pl: = UI.label(("#%d" % place) if my > 0 else "—", 54, Color.WHITE, UI.DARK, 5, "title", 900)
	pl.position = Vector2(r.size.x - 200, 30)
	pl.size = Vector2(180, 70)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(pl)
	var sc: = UI.label("%d очков" % my if my > 0 else "ещё не играла", 18, Color("ddd2c4"), UI.DARK, 3, "body", 900)
	sc.position = Vector2(r.size.x - 260, 102)
	sc.size = Vector2(240, 26)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(sc)
	var info: = JButton.make("?", "graphite", Rect2(r.size.x - 70, r.size.y - 64, 54, 54), null, 28)
	info.pressed.connect(rules)
	card.add_child(info)
	UI.slide_in(card, Vector2(0, -20), 0.0, 0.4)

func _prize(t: Dictionary) -> void :
	var pid: String = V7Ladder.prize_of(int(t.start))
	var it: Dictionary = G.ITEM[pid]
	var r: = Rect2(16, 326, W - 32, 112)
	var row: = UI.rbox("glass", r, 24, 3, 8)
	row.borders(Color("ffe7a6"), Color("c58a2c"))
	add_child(row)
	var a: = Common.card_art(G.art_tex(it), Rect2(10, 8, 80, 96), Vector2(0.5, 0.25), 1.0, 14)
	row.add_child(a)
	var l1: = UI.label("Приз топ-3 группы: «%s»" % it.name, 20, Color("ffe7a6"), UI.DARK, 3, "body", 900)
	l1.position = Vector2(104, 10)
	l1.size = Vector2(r.size.x - 120, 28)
	l1.clip_text = true
	row.add_child(l1)
	var own: = G.owns(pid)
	var l2: = UI.label(("уже твой: вместо него +%d кристаллов" % V7Ladder.PRIZE_OWNED_GEMS) if own else "%s · %s · наряд меняется каждую неделю" % [it.rar, G.HEROES[it.hero].name], 16, Color("ddd2c4"))
	l2.position = Vector2(106, 42)
	row.add_child(l2)
	var l3: = UI.label("Топ-5 идут выше, последние 5 ниже, без игры лига та же", 15, Color("bfb3a8"))
	l3.position = Vector2(106, 72)
	l3.size = Vector2(r.size.x - 120, 26)
	l3.clip_text = true
	row.add_child(l3)
	UI.slide_in(row, Vector2(0, 20), 0.08, 0.4)

func _tables(t: Dictionary) -> void :
	var bw: = (W - 32 - 20) / 3.0
	table_btns.clear()
	for k in V7Ladder.TABLES:
		var cfg: = V7Ladder.table_cfg(k, int(t.start))
		var r: = Rect2(16 + k * (bw + 10), 450, bw, 160)
		var c: = UI.rbox("plum", r, 24, 3, 8)
		c.colors(Color(0.14, 0.08, 0.16, 0.96), Color(0.08, 0.04, 0.1, 0.97)).borders(Color("ffe7a6"), Color("c58a2c"))
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.pivot_offset = r.size * 0.5
		add_child(c)
		var path: = "res://assets/bg/%s.webp" % cfg.bg
		var art: = Common.card_art(load(path), Rect2(4, 4, bw - 8, 70), Vector2(0.5, 0.5), 1.0, 18)
		c.add_child(art)
		c.add_child(UI.center_label(UI.label(["Стол I", "Стол II", "Стол III"][k], 22, Color.WHITE, UI.DARK, 4, "body", 900), Rect2(0, 18, bw, 34)))
		var feat: = UI.label(V6Layouts.shape_name(cfg.shape) + (" · ★" if k == 2 else ""), 14, Color("ddd2c4"), UI.DARK, 2)
		feat.position = Vector2(0, 78)
		feat.size = Vector2(bw, 22)
		feat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(feat)
		var best: = int(t.best[k])
		var bl: = UI.label(("Лучший: %d" % best) if best > 0 else "Не сыгран", 18, Color("ffe7a6") if best > 0 else Color("bfb3a8"), UI.DARK, 3, "body", 900)
		bl.position = Vector2(0, 100)
		bl.size = Vector2(bw, 26)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(bl)
		var go: = UI.rbox("pink" if best == 0 else "gold", Rect2(14, 128, bw - 28, 24), 12, 2, 4)
		c.add_child(go)
		go.add_child(UI.center_label(UI.label("ИГРАТЬ" if best == 0 else "УЛУЧШИТЬ", 14, Color.WHITE if best == 0 else Color("3a2410"), UI.DARK if best == 0 else Color(1, 1, 1, 0.4), 2, "body", 900), Rect2(0, 0, bw - 28, 24)))
		var kk: = k
		c.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				Sfx.play("pop")
				UI.punch(c, 0.08)
				main.go("v7play", {"mode": "v7tourney", "table": kk, "partner": G.S.level_partner if G.hero_unlocked(G.S.level_partner) else "mc"}))
		UI.slide_in(c, Vector2(0, 30), 0.12 + k * 0.05, 0.4)
		table_btns.append(c)

func _board(t: Dictionary, rows: Array) -> void :
	var top: = 624.0
	var bottom: = H - 140.0
	var frame: = UI.rbox("glass", Rect2(16, top, W - 32, bottom - top), 26, 3, 8)
	frame.borders(Color("ffe7a6"), Color("c58a2c"))
	add_child(frame)
	var hd: = UI.label("Группа · %d игроков" % V7Ladder.GROUP, 17, Color("bfb3a8"), UI.DARK, 2, "body", 900)
	hd.position = Vector2(36, top + 10)
	add_child(hd)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(24, top + 40)
	scroll.size = Vector2(W - 48, bottom - top - 50)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(W - 48, 0)
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var league: = int(t.league)
	var me_i: = 0
	for i in rows.size():
		var place: = i + 1
		if place == V7Ladder.UP + 1 and league < V7Ladder.LEAGUES.size() - 1:
			list.add_child(_divider("▲ зона повышения выше", Color("a9d9c4")))
		if place == V7Ladder.GROUP - V7Ladder.DOWN + 1 and league > 0:
			list.add_child(_divider("▼ зона понижения ниже", Color("e3a3b2")))
		list.add_child(_row(rows[i], place, league))
		if rows[i].me:
			me_i = i
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		scroll.scroll_vertical = maxi(0, int((me_i - 3) * 70.0))

func _divider(text: String, col: Color) -> Control:
	var c: = Control.new()
	c.custom_minimum_size = Vector2(W - 48, 26)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var l: = UI.label(text, 14, col, UI.DARK, 2, "body", 900)
	l.position = Vector2(0, 2)
	l.size = Vector2(W - 48, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(l)
	return c

func _row(r: Dictionary, place: int, league: int) -> Control:
	var c: = Control.new()
	c.custom_minimum_size = Vector2(W - 48, 64)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var me: bool = r.me
	var z: = V7Ladder.zone(place, league)
	var bg: = UI.rbox("pink" if me else "plum", Rect2(0, 0, W - 48, 64), 20, 2 if me else 1, 4)
	if not me:
		bg.colors(Color(0.16, 0.14, 0.17, 0.85), Color(0.1, 0.09, 0.11, 0.9))
		bg.borders(Color("a9d9c4") if z == "up" else (Color("e3a3b2") if z == "down" else Color(1, 1, 1, 0.08)), Color(0, 0, 0, 0.3))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	var pc: = Color("ffd34d") if place == 1 else (Color("e9e4ff") if place == 2 else (Color("d99a6c") if place == 3 else Color("ddd2c4")))
	var pl: = UI.label(str(place), 26, pc, UI.DARK, 3, "title", 900)
	pl.position = Vector2(8, 0)
	pl.size = Vector2(52, 64)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(pl)
	var av: = Common.avatar(r.hero, Rect2(64, 6, 52, 52), "gold" if place <= 3 else "plum")
	c.add_child(av)
	var nm: = UI.label(r.name, 21, Color.WHITE, UI.DARK, 3, "body", 900)
	nm.position = Vector2(128, 0)
	nm.size = Vector2(300, 64)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.clip_text = true
	c.add_child(nm)
	if place <= 3 and int(r.score) > 0:
		c.add_child(UI.tex(G.icon("trophy"), Rect2(W - 48 - 186, 10, 44, 44)))
	var sc: = UI.label(UI.fmt(int(r.score)) if int(r.score) > 0 else "—", 22, Color("ffe7a6"), UI.DARK, 3, "body", 900)
	sc.position = Vector2(W - 48 - 140, 0)
	sc.size = Vector2(124, 64)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(sc)
	return c

func rules() -> void :
	var p: = Common.popup(main, "Правила турнира", 700)
	var txt: = "• Неделя идёт с понедельника по воскресенье. Три стола недели одинаковые у всех игроков.\n• Очки за пару: %d, серия добавляет +%d за каждую пару подряд, золото +%d. Очищенный стол +%d, скорость до +%d, партия без помощи и переполнений +%d.\n• Помощь только бесплатная и стоит %d очков. Переполнение лотка −%d, третье заканчивает партию.\n• В зачёт идёт лучший результат на каждом столе: переигрывать можно сколько угодно, хуже не станет.\n• В группе 20 игроков. Топ-5 поднимаются в следующую лигу, последние 5 опускаются. Не играла неделю: лига сохраняется.\n• Награды по месту в кристаллах, топ-3 получают наряд недели." % [V7Ladder.PAIR, V7Ladder.COMBO, V7Ladder.GOLD, V7Ladder.CLEAR, V7Ladder.TIME, V7Ladder.CLEAN, V7Ladder.BOOSTER, V7Ladder.OVERFLOW]
	var l: = UI.label(txt, 18, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(40, 60)
	l.size = Vector2(580, 440)
	l.custom_minimum_size = Vector2(580, 0)
	p.add_child(l)
	var y: = 500.0
	var hl: = UI.label("Награды лиги «%s»: 1 место %d · 2–3 %d · 4–5 %d · 6–10 %d · остальные %d" % ([V7Ladder.LEAGUES[int(V7Ladder.st().league)].short] + V7Ladder.LEAGUES[int(V7Ladder.st().league)].gems), 17, Color("ffd98a"), UI.DARK, 2, "body", 900)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.position = Vector2(40, y)
	hl.size = Vector2(580, 60)
	hl.custom_minimum_size = Vector2(580, 0)
	p.add_child(hl)
	var hist: Array = V7Ladder.st().get("history", [])
	if not hist.is_empty():
		var last: Dictionary = hist[hist.size() - 1]
		var ll: = UI.label("Прошлая неделя: #%d, %s, %d очков" % [int(last.place), V7Ladder.LEAGUES[int(last.league)].short, int(last.score)], 17, Color("a9d9c4"))
		ll.position = Vector2(40, y + 80)
		p.add_child(ll)

func dev_act(a: String) -> void :
	match a:
		"rules":
			rules()
		"scroll":
			scroll.scroll_vertical = 600
