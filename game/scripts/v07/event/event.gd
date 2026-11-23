extends Node



const UNLOCK_AT: = 4

func _ready() -> void :
	for it in V7EventData.limited_items():
		if not G.ITEM.has(it.id):
			G.ITEMS.append(it)
			G.ITEM[it.id] = it
	if "--event_selftest=1" in OS.get_cmdline_user_args():
		_selftest.call_deferred()
	if "--league_selftest=1" in OS.get_cmdline_user_args():
		_league_selftest.call_deferred()


func _league_selftest() -> void :
	var fails: = V8LeagueSelftest.run()
	get_tree().quit(1 if fails > 0 else 0)


func _selftest() -> void :
	var cfgs: = []
	for e in V7EventData.EVENTS:
		for i in V7EventData.NODES:
			cfgs.append(V7EventData.node_cfg(i, e, e.hero))
	var wd: = V7Ladder.week_day()
	for w in 8:
		for k in V7Ladder.TABLES:
			cfgs.append(V7Ladder.table_cfg(k, wd + w * 7))
	var bad: = 0
	for cfg in cfgs:
		seed(int(cfg.seed))
		var b: = TrayBoard.new()
		add_child(b)
		b.setup(cfg)
		var ok: = true
		var guard: = 0
		while b.board_count() > 0 and guard < 3000:
			guard += 1
			var t: Tile = b.solver_move()
			if t == null:
				ok = false
				break
			if t.ice > 0:
				t.ice -= 1
				continue
			var twin: Tile = null
			for x in b.tray:
				if x.face == t.face:
					twin = x
			if twin:
				b.tray.erase(twin)
				twin.alive = false
				t.alive = false
			else:
				b.tray.append(t)
				if b.tray.size() >= TrayBoard.SLOTS:
					ok = false
					break
		if not ok or b.board_count() > 0:
			bad += 1
			printerr("EVENT FAIL %s seed %d left %d" % [cfg.code, int(cfg.seed), b.board_count()])
		b.free()
	var t: = V7Ladder.st()
	var rows: = V7Ladder.group(t, 1.0)
	printerr("EVENT SELFTEST %d/%d boards solved · week par %d/%d/%d · bots at week end: top %d, 5th %d, 15th %d" % [cfgs.size() - bad, cfgs.size(), 
		V7Ladder.table_par(0, int(t.start)), V7Ladder.table_par(1, int(t.start)), V7Ladder.table_par(2, int(t.start)), int(rows[0].score), int(rows[4].score), int(rows[14].score)])
	get_tree().quit()

static func is_open() -> bool:
	if "--event_open=1" in OS.get_cmdline_user_args():
		return true
	return int(G.S.unlocked) >= UNLOCK_AT

# 0.8: event currencies in the cur/ family (gold rim, graphite lacquer, sakura) through the V8Art cache
static func cur_icon(def: Dictionary) -> Texture2D:
	return V8Art.event_cur(String(def.icon))

static func art(def: Dictionary, wide: = false) -> Texture2D:
	return load("res://assets/v07/event/%s_%s.webp" % [def.art, "wide" if wide else "card"])


static func home_cards(home: Control, main) -> void :
	if not is_open():
		return
	var W: float = home.size.x
	var has_second: bool = (G.summon_open() and int(G.S.newbie_left) > 0) or not G.summon_open()
	var y: = 586.0 if has_second else 410.0
	var def: = V7EventData.cur_def()
	var ev: = V7EventData.st()
	var c1: Control = home._banner_card(Rect2(W - 214, y, 198, 156), art(def), "ИВЕНТ", def.name, "ещё " + V7EventData.left_text(V7EventData.left_secs()), "rose", Vector2(0.5, 0.2))
	c1.add_child(UI.tex(cur_icon(def), Rect2(150, 4, 44, 44)))
	if ev.daily != V7EventData.today_key():
		var x2: = UI.rbox("red", Rect2(132, 44, 64, 26), 13, 2, 4)
		c1.add_child(x2)
		x2.add_child(UI.center_label(UI.label("×2", 16, Color.WHITE, Color("6a1020"), 2, "body", 900), Rect2(0, 0, 64, 26)))
	c1.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			Sfx.play("pop")
			UI.punch(c1, 0.06)
			main.go("v7event"))
	UI.slide_in(c1, Vector2(60, 0), 0.34)
	var t: = V7Ladder.st()
	var rows: = V7Ladder.group(t)
	var place: = V7Ladder.place_of(rows)
	var L: Dictionary = V7Ladder.LEAGUES[int(t.league)]
	var sub: String = ("#%d · %s" % [place, L.short]) if V7Ladder.my_score(t) > 0 else String(L.name)
	var c2: Control = home._banner_card(Rect2(W - 214, y + 168, 198, 156), load("res://assets/v07/event/cg_finale_card.webp"), "ТУРНИР", "Неделя", sub, "gold", Vector2(0.5, 0.3))
	c2.add_child(V8Art.rect(V8Art.icon("trophy"), Rect2(150, 4, 44, 44)))
	c2.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			Sfx.play("pop")
			UI.punch(c2, 0.06)
			main.go("v7tourney"))
	UI.slide_in(c2, Vector2(60, 0), 0.4)
	G.save()
	show_pending(home, main)


static func show_pending(node: Control, main) -> void :
	var r: = V7EventData.root()
	if r.pending.is_empty():
		return
	await node.get_tree().create_timer(1.0).timeout
	if not is_instance_valid(node) or not node.is_inside_tree() or r.pending.is_empty():
		return
	var item: Dictionary = r.pending.pop_front()
	G.save()
	match item.type:
		"tour_end":
			_tour_result(main, item)
		"event_end":
			_event_result(main, item)

static func _tour_result(main, it: Dictionary) -> void :
	var L: Dictionary = V7Ladder.LEAGUES[int(it.league)]
	var NL: Dictionary = V7Ladder.LEAGUES[int(it.new_league)]
	var p: = Common.popup(main, "Итоги недели", 660)
	var place: = int(it.place)
	var big: = UI.center_label(UI.title("#%d" % place, 96, L.color, UI.DARK), Rect2(0, 54, 660, 120))
	p.add_child(big)
	UI.pop_in(big, 0.2, 2.0)
	p.add_child(UI.center_label(UI.label("%s · %d очков" % [L.name, int(it.score)], 22, UI.INK, UI.DARK, 3, "body", 900), Rect2(0, 176, 660, 32)))
	var move: = "Лига сохранена"
	var mc: = Color("ddd2c4")
	if int(it.new_league) > int(it.league):
		move = "Повышение: %s" % NL.name
		mc = Color("a9d9c4")
	elif int(it.new_league) < int(it.league):
		move = "Новая неделя в лиге: %s" % NL.name
		mc = Color("e3a3b2")
	p.add_child(UI.center_label(UI.label(move, 24, mc, UI.DARK, 3, "body", 900), Rect2(0, 216, 660, 36)))
	Common.chip(p, V8Art.cur("gem"), "+%d кристаллов" % (int(it.gems) + int(it.prize_gems)), Rect2(150, 276, 360, 56), "plum", 22)
	if String(it.prize) != "":
		var pi: Dictionary = G.ITEM[it.prize]
		var a: = Common.card_art(G.art_tex(pi), Rect2(60, 350, 150, 200), Vector2(0.5, 0.3), 1.0, 18)
		p.add_child(a)
		var nl: = UI.label(("Наряд недели: «%s»" % pi.name) if it.prize_new else ("«%s» уже был твоим: +%d кристаллов" % [pi.name, int(it.prize_gems)]), 21, Color("ffd98a"), UI.DARK, 3, "body", 900)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.position = Vector2(230, 380)
		nl.size = Vector2(380, 120)
		nl.custom_minimum_size = Vector2(380, 0)
		p.add_child(nl)
		Fx.burst(p, Vector2(330, 120), "confetti", 70, Color.WHITE, 1.2)
		Sfx.play("reveal_ssr", 1.0, -2)
	else:
		var tip: = UI.label("Призовой наряд недели берут трое лучших в группе. Новая неделя уже началась.", 20, UI.INK)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.position = Vector2(60, 370)
		tip.size = Vector2(540, 100)
		tip.custom_minimum_size = Vector2(540, 0)
		p.add_child(tip)
		Sfx.play("win", 1.0, -6)
	var b: = JButton.make("К турниру", "pink", Rect2(110, 560, 440, 84), null, 28)
	b.pressed.connect( func():
		Common.close_popup(p)
		main.go("v7tourney"))
	p.add_child(b)
	main.refresh_currency(true)

static func _event_result(main, it: Dictionary) -> void :
	var p: = Common.popup(main, "Ивент завершён", 480)
	var l: = UI.label("«%s» закончился. Пройдено столов: %d из %d." % [it.name, int(it.nodes), V7EventData.NODES], 22, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(50, 70)
	l.size = Vector2(560, 90)
	l.custom_minimum_size = Vector2(560, 0)
	p.add_child(l)
	var g: = "Остаток валюты (%d) обменян: +%d кристаллов" % [int(it.left), int(it.gems)] if int(it.left) > 0 else "Вся валюта потрачена, ничего не сгорело"
	var gl: = UI.label(g, 21, Color("ffd98a"), UI.DARK, 3, "body", 900)
	gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gl.position = Vector2(50, 180)
	gl.size = Vector2(560, 70)
	gl.custom_minimum_size = Vector2(560, 0)
	p.add_child(gl)
	var nd: = V7EventData.cur_def()
	var nx: = UI.label("Уже идёт новый: «%s»" % nd.name, 22, Color("a9d9c4"), UI.DARK, 3, "body", 900)
	nx.position = Vector2(50, 268)
	p.add_child(nx)
	var b: = JButton.make("Открыть ивент", "pink", Rect2(110, 350, 440, 90), null, 28)
	b.pressed.connect( func():
		Common.close_popup(p)
		main.go("v7event"))
	p.add_child(b)
	main.refresh_currency(true)
