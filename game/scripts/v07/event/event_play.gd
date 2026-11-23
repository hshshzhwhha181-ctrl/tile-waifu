extends "res://scripts/screens/play.gd"





const MINE: = ["v7event", "v7tourney"]

var node_i: = 0
var table_k: = 0
var def: = {}
var strip: Control
var strip_h: = 64.0
var score: = 0
var overflows: = 0
var score_lbl2: Label
var info_lbl: Label
var finished: = false

func _v6_setup(args: Dictionary) -> bool:
	var m: String = args.get("mode", "")
	var dev: = {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv: = a.substr(2).split("=", true, 1)
			dev[kv[0]] = kv[1]
	match m:
		"v7event":
			mode = m
			def = V7EventData.cur_def()
			node_i = clampi(int(args.get("node", dev.get("event_node", "0"))), 0, V7EventData.NODES - 1)
			var rs: = -1
			if V7EventData.node_stars(node_i) > 0:
				rs = randi() % 1000000
			cfg = V7EventData.node_cfg(node_i, def, partner, rs)
			return true
		"v7tourney":
			mode = m
			table_k = clampi(int(args.get("table", dev.get("event_table", "0"))), 0, V7Ladder.TABLES - 1)
			cfg = V7Ladder.table_cfg(table_k, int(V7Ladder.st().start))
			return true
	return false

func _make_board() -> void :
	if mode in MINE:
		if strip == null:
			_build_strip()
		var top: = board_rect.position.y + strip_h + 6
		board_rect = Rect2(board_rect.position.x, top, board_rect.size.x, board_rect.end.y - top)
	if mode == "v7tourney":
		seed(int(cfg.seed))
	super._make_board()
	if mode == "v7tourney":
		randomize()

func _build_strip() -> void :
	strip = Control.new()
	strip.position = Vector2(10, board_rect.position.y)
	strip.size = Vector2(W - 20, strip_h)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.z_index = 5
	add_child(strip)
	var p: = UI.rbox("glass", Rect2(0, 0, strip.size.x, strip_h), 24, 3, 8)
	p.borders(Color("ffe7a6"), Color("c58a2c"))
	strip.add_child(p)
	if mode == "v7event":
		p.add_child(UI.tex(V7Event.cur_icon(def), Rect2(10, 6, 52, 52)))
		var l: = UI.label("%s · стол %d из %d" % [def.name, node_i + 1, V7EventData.NODES], 19, Color("ffe7a6"), UI.DARK, 3, "body", 900)
		l.position = Vector2(70, 6)
		p.add_child(l)
		var bonus: = "Героиня ивента рядом: +50%" if partner == def.hero else "С героиней ивента (%s) +50%%" % G.HEROES[def.hero].name
		info_lbl = UI.label(bonus, 15, Color("a9d9c4") if partner == def.hero else Color("c9bdb0"))
		info_lbl.position = Vector2(72, 34)
		p.add_child(info_lbl)
		score_lbl2 = UI.label("%d" % V7EventData.cur(), 24, Color.WHITE, UI.DARK, 4, "body", 900)
		score_lbl2.position = Vector2(strip.size.x - 150, 0)
		score_lbl2.size = Vector2(136, strip_h)
		score_lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_lbl2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(score_lbl2)
	else:
		var t: = V7Ladder.st()
		var L: Dictionary = V7Ladder.LEAGUES[int(t.league)]
		p.add_child(UI.tex(G.icon("trophy"), Rect2(8, 4, 56, 56)))
		var l: = UI.label("ОЧКИ", 13, Color("cbb5dc"), Color.WHITE, 0, "body", 900)
		l.position = Vector2(72, 6)
		p.add_child(l)
		score_lbl2 = UI.label("0", 28, Color.WHITE, UI.DARK, 4, "body", 900)
		score_lbl2.position = Vector2(72, 20)
		score_lbl2.pivot_offset = Vector2(20, 18)
		p.add_child(score_lbl2)
		info_lbl = UI.label("Лучший: %d · %s" % [int(t.best[table_k]), L.short], 17, L.color, UI.DARK, 3, "body", 900)
		info_lbl.position = Vector2(220, 20)
		p.add_child(info_lbl)
	UI.slide_in(strip, Vector2(0, -20), 0.2, 0.4)

func _apply_perk() -> void :
	super._apply_perk()
	if mode == "v7tourney":
		gem_bonus = 0.0

func _check_riichi() -> void :
	if mode in MINE:
		return
	super._check_riichi()

func _on_match(mid: Vector2, combo: int, gold: bool, shard: String) -> void :
	super._on_match(mid, combo, gold, shard)
	if mode == "v7tourney" and not finished:
		var pts: = V7Ladder.score_pair(combo, gold)
		score += pts
		score_lbl2.text = str(score)
		UI.punch(score_lbl2, 0.2)
		Fx.float_text(fx_layer, mid + Vector2(0, -24), "+%d" % pts, Color("a9d9c4"), 26)


func _booster_ok(n: int) -> bool:
	if mode == "v7tourney" and n <= 0:
		main.toast("В турнире только бесплатная помощь", "trophy")
		return false
	return true

func _hint() -> void :
	if _booster_ok(hint_n):
		super._hint()

func _undo() -> void :
	if _booster_ok(undo_n):
		super._undo()

func _shuffle() -> void :
	if _booster_ok(shuffle_n):
		super._shuffle()

func _on_fail() -> void :
	if not mode in MINE:
		super._on_fail()
		return
	_v6_clear_tips()
	overflows += 1
	fails += 1
	stage.react("fail")
	Sfx.play("deny", 0.8)
	Fx.shake(tray_box, 8, 0.3)
	if mode == "v7tourney":
		score -= V7Ladder.OVERFLOW
		score_lbl2.text = str(score)
		Fx.float_text(fx_layer, Vector2(W * 0.5, 380), "Лоток переполнен · −%d" % V7Ladder.OVERFLOW, Color("ff8a9a"), 30)
		if overflows >= 3:
			_tour_finish(false)
			return
	else:
		Fx.float_text(fx_layer, Vector2(W * 0.5, 380), "Три фишки вернулись на стол", Color("ffb38a"), 28)
	await get_tree().create_timer(0.25).timeout
	if is_inside_tree():
		board.return_tray(3)
		_refresh()

func _on_clear() -> void :
	match mode:
		"v7event":
			_event_clear()
		"v7tourney":
			_tour_finish(true)
		_:
			super._on_clear()


func _event_clear() -> void :
	if finished:
		return
	finished = true
	_v6_clear_tips()
	get_tree().call_group("v6_chip", "queue_free")
	var stars: = 3 if fails == 0 and boosters_used == 0 else (2 if fails <= 1 and boosters_used <= 2 else 1)
	var prev: = V7EventData.node_stars(node_i)
	var first: = prev == 0
	var rw: = V7EventData.clear_reward(node_i, stars, first, partner, def)
	var ev: = V7EventData.st()
	ev.nodes[str(node_i)] = maxi(prev, stars)
	if not first:
		ev.bis = int(ev.bis) + 1
	var miles: = V7EventData.add_cur(int(rw.total))
	G.add_aff(partner, 10)
	if partner == def.hero:
		G.add_aff(partner, 10)
	G.task_add("levels")
	G.add_pass_xp(100)
	G.S.xp = int(G.S.xp) + 40
	G.save()
	print("V7EVENT CLEAR node=%d stars=%d cur=+%d" % [node_i, stars, int(rw.total)])
	Sfx.play("win")
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return
	var root: = _overlay()
	var rib: = Common.ribbon(root, "Стол %d пройден" % (node_i + 1), Rect2(W * 0.5 - 250, 150, 500, 96), "pink", 40)
	UI.pop_in(rib, 0.05, 0.4)
	var srow: = []
	for i in 3:
		var st: = UI.tex(G.fx("star_empty"), Rect2(W * 0.5 - 60 + (i - 1) * 140, 262 + (0 if i == 1 else 20), 120, 120))
		root.add_child(st)
		srow.append(st)
	var y: = 410.0
	var panel: = UI.rbox("glass", Rect2(60, y, W - 120, 70 + rw.parts.size() * 40), 26, 3, 10)
	panel.borders(Color("ffe7a6"), Color("c58a2c"))
	root.add_child(panel)
	panel.add_child(UI.tex(V7Event.cur_icon(def), Rect2(16, 8, 54, 54)))
	var tl: = UI.label("+%d  %s" % [int(rw.total), def.cur], 28, Color("ffe7a6"), UI.DARK, 4, "body", 900)
	tl.position = Vector2(80, 12)
	panel.add_child(tl)
	for k in rw.parts.size():
		var pr: Array = rw.parts[k]
		var a: = UI.label(String(pr[0]), 18, Color("ddd2c4"))
		a.position = Vector2(30, 66 + k * 40)
		panel.add_child(a)
		var b: = UI.label(("×2" if String(pr[0]).begins_with("Первая") else "+%d" % int(pr[1])), 18, Color("a9d9c4"), UI.DARK, 2, "body", 900)
		b.position = Vector2(panel.size.x - 110, 66 + k * 40)
		panel.add_child(b)
	y += panel.size.y + 18
	for m in miles:
		var c: = Common.chip(root, G.icon("gift"), "Веха %d: %s" % [int(m.at), V7EventData.mile_text(m, def)], Rect2(80, y, W - 160, 52), "plum", 18)
		UI.pop_in(c, 0.6)
		y += 60

	var beat: = {0: 0, 5: 1, 11: 2}
	if first and beat.has(node_i):
		var line: String = def.lines[beat[node_i]]
		var bub: = UI.rbox("cream", Rect2(40, y + 4, W - 80, 118), 24, 3, 10)
		root.add_child(bub)
		bub.add_child(Common.avatar(def.hero, Rect2(12, 12, 94, 94), "gold"))
		var bl: = UI.label(line, 19, UI.INK)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.position = Vector2(120, 14)
		bl.size = Vector2(W - 220, 96)
		bl.custom_minimum_size = Vector2(W - 220, 0)
		bub.add_child(bl)
		UI.slide_in(bub, Vector2(0, 30), 0.8)
		y += 132
	var nxt: = node_i + 1
	var has_next: = nxt < V7EventData.NODES
	var bw: = (W - 100) * 0.5
	var b1: = JButton.make("Следующий стол" if has_next else "Ещё раз", "pink", Rect2(40, minf(y + 30, H - 200), bw, 96), null, 26)
	b1.shine_every = 2.2
	b1.pressed.connect( func():
		main.go("v7play", {"mode": "v7event", "node": nxt if has_next else node_i, "partner": partner, "retry": randi()}))
	root.add_child(b1)
	var b2: = JButton.make("К карте ивента", "glass", Rect2(60 + bw, b1.position.y, bw, 96), null, 24)
	b2.pressed.connect( func(): main.go("v7event"))
	root.add_child(b2)
	Fx.burst(root, Vector2(W * 0.5, 300), "confetti", 60, Color.WHITE, 1.1)
	await get_tree().create_timer(0.5).timeout
	for i in stars:
		if not is_inside_tree():
			return
		var st: TextureRect = srow[i]
		st.texture = G.fx("star")
		UI.pop_in(st, 0.0, 2.0)
		Sfx.play("star%d" % i)
		await get_tree().create_timer(0.3).timeout


func _tour_finish(cleared: bool) -> void :
	if finished:
		return
	finished = true
	board.input_on = false
	_v6_clear_tips()
	get_tree().call_group("v6_chip", "queue_free")
	var secs: = now() - start_t
	var fin: = V7Ladder.score_finish(cleared, secs, boosters_used, 0)
	var total: = maxi(0, score + int(fin.total))
	var res: = V7Ladder.submit(table_k, total)
	G.task_add("levels")
	G.add_pass_xp(80)
	G.add_aff(partner, 5)
	G.save()
	print("V7TOURNEY table=%d score=%d cleared=%s place %d->%d" % [table_k, total, str(cleared), int(res.place_before), int(res.place_after)])
	Sfx.play("win" if cleared else "deny", 1.0 if cleared else 0.7)
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return
	var root: = _overlay()
	var rib: = Common.ribbon(root, "Стол очищен" if cleared else "Партия окончена", Rect2(W * 0.5 - 250, 150, 500, 96), "gold" if cleared else "pink", 38)
	UI.pop_in(rib, 0.05, 0.4)
	var big: = UI.center_label(UI.title(str(total), 88, Color("ffe7a6"), UI.DARK), Rect2(0, 260, W, 110))
	root.add_child(big)
	UI.pop_in(big, 0.2, 1.6)
	var rows: = [["Пары и серии", score + overflows * V7Ladder.OVERFLOW]]
	if overflows > 0:
		rows.append(["Переполнения ×%d" % overflows, - overflows * V7Ladder.OVERFLOW])
	for pr in fin.parts:
		rows.append(pr)
	var panel: = UI.rbox("glass", Rect2(70, 390, W - 140, 24 + rows.size() * 38), 24, 3, 10)
	panel.borders(Color("ffe7a6"), Color("c58a2c"))
	root.add_child(panel)
	for k in rows.size():
		var a: = UI.label(String(rows[k][0]), 18, Color("ddd2c4"))
		a.position = Vector2(26, 12 + k * 38)
		panel.add_child(a)
		var v: = int(rows[k][1])
		var b: = UI.label(("+%d" % v) if v >= 0 else str(v), 18, Color("a9d9c4") if v >= 0 else Color("e3a3b2"), UI.DARK, 2, "body", 900)
		b.position = Vector2(panel.size.x - 110, 12 + k * 38)
		panel.add_child(b)
	var y: = panel.position.y + panel.size.y + 20
	var t: = V7Ladder.st()
	var line: = ("Новый рекорд стола! Было %d" % int(res.old)) if res.improved else ("Лучший результат стола: %d" % int(res.best))
	root.add_child(UI.center_label(UI.label(line, 22, Color("a9d9c4") if res.improved else Color("ddd2c4"), UI.DARK, 3, "body", 900), Rect2(0, y, W, 34)))
	y += 40
	var pl: = "Место в группе: #%d" % int(res.place_after)
	if int(res.place_after) < int(res.place_before):
		pl += "  ▲ %d" % (int(res.place_before) - int(res.place_after))
	var z: = V7Ladder.zone(int(res.place_after), int(t.league))
	var zc: = Color("ffe7a6")
	if z == "up":
		pl += " · зона повышения"
		zc = Color("a9d9c4")
	elif z == "down":
		pl += " · зона понижения"
		zc = Color("e3a3b2")
	root.add_child(UI.center_label(UI.label(pl, 24, zc, UI.DARK, 3, "body", 900), Rect2(0, y, W, 36)))
	y += 60
	var bw: = (W - 100) * 0.5
	var b1: = JButton.make("Ещё раз", "pink", Rect2(40, minf(y + 10, H - 200), bw, 96), null, 28)
	b1.pressed.connect( func(): main.go("v7play", {"mode": "v7tourney", "table": table_k, "partner": partner, "retry": randi()}))
	root.add_child(b1)
	var b2: = JButton.make("К турниру", "glass", Rect2(60 + bw, b1.position.y, bw, 96), null, 26)
	b2.pressed.connect( func(): main.go("v7tourney"))
	root.add_child(b2)
	if res.improved:
		Fx.burst(root, Vector2(W * 0.5, 310), "confetti", 60, Color.WHITE, 1.1)

func _overlay() -> Control:
	var root: = Control.new()
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 60
	add_child(root)
	var dim: = ColorRect.new()
	dim.size = size
	dim.color = Color(0.05, 0.03, 0.07, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.82, 0.35)
	Common.rays(root, Vector2(W * 0.5, 230), 900, Color(1.0, 0.85, 0.6, 0.4), 12, 0.04, 0.55)
	return root

func _process(dt: float) -> void :
	super._process(dt)
	if mode == "v7event" and score_lbl2:
		score_lbl2.text = str(V7EventData.cur())

func dev_act(a: String) -> void :
	match a:
		"clear":
			for t in board.tiles:
				t.alive = false
				t.hide()
			_on_clear()
		"auto":
			for i in 8:
				var t: = board.solver_move()
				if t and board.input_on:
					board.tap(t)
				await get_tree().create_timer(0.3).timeout
		"win":
			var guard: = 0
			while is_inside_tree() and board.board_count() > 0 and guard < 400 and not finished:
				guard += 1
				var t: = board.solver_move()
				if t and board.input_on and board.busy == 0:
					board.tap(t)
				await get_tree().create_timer(0.12).timeout
		"overflow":
			_on_fail()
		_:
			super.dev_act(a)
