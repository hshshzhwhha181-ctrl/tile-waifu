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
		info_lbl = UI.label(bonus, 16, Color("a9d9c4") if partner == def.hero else Color("c9bdb0"))
		info_lbl.position = Vector2(72, 33)
		info_lbl.size = Vector2(strip.size.x - 72 - 150, 24)
		info_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info_lbl.clip_text = true
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
		# 0.8: the crest of the weekly league this table counts for (league/*)
		Common.league_emblem(p, Rect2(8, 4, 56, 56), int(t.league))
		var l: = UI.label("ОЧКИ", 16, Color("cbb5dc"), Color.WHITE, 0, "body", 900)
		l.position = Vector2(72, 0)
		p.add_child(l)
		score_lbl2 = UI.label("0", 28, Color.WHITE, UI.DARK, 4, "body", 900)
		score_lbl2.position = Vector2(72, 22)
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
	stage.flash_emotion("sad")
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
	rp_before = int(G.S.rp)
	var ea: = V8PlayRules.award("event", V8PlayRules.event_rp(stars), true)
	rp_gain = int(ea.rp)
	rank_ups = ea.ups
	_v8_saved = true
	_v8_end_overlays()
	print("V7EVENT CLEAR node=%d stars=%d cur=+%d" % [node_i, stars, int(rw.total)])
	Sfx.play("win")
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return
	# 0.8 (spec 5): the shared result window (panel, rank bar, league line, main action bottom right)
	var ctx: = v8_res_open("Стол %d пройден" % (node_i + 1), "pink", 44)
	var srow: = v8_res_stars(ctx, V8PlayRules.T.star_rule_event)
	# one source of drops: the total says it all (no «Стол +66» under «+66 Лунные капли»)
	var parts: Array = rw.parts if rw.parts.size() > 1 else []
	var pw: float = ctx.w - V8_RES_PAD * 2.0
	var panel: = UI.rbox("glass", Rect2(V8_RES_PAD, ctx.y, pw, 72 + parts.size() * 34 + (8 if parts.size() > 0 else 0)), 24, 3, 8)
	panel.borders(Color("ffe7a6"), Color("8a6a3a"))
	(ctx.plate as Control).add_child(panel)
	panel.add_child(UI.tex(V7Event.cur_icon(def), Rect2(12, 8, 56, 56)))
	var tl: = UI.label("+%d  %s" % [int(rw.total), def.cur], 28, Color("ffe7a6"), UI.DARK, 4, "body", 900)
	tl.position = Vector2(80, 4)
	tl.size = Vector2(pw - 90, 40)
	tl.clip_text = true
	panel.add_child(tl)
	panel.add_child(V8Art.rect(V8Art.icon("heart"), Rect2(82, 42, 24, 24)))
	var hl: = UI.label("+%d симпатии" % (20 if partner == def.hero else 10), 17, Color("f7a8c4"), UI.DARK, 3, "body", 900)
	hl.position = Vector2(112, 40)
	panel.add_child(hl)
	for k in parts.size():
		var pr: Array = parts[k]
		var a: = UI.label(String(pr[0]), 18, Color("ddd2c4"))
		a.position = Vector2(24, 72 + k * 34)
		panel.add_child(a)
		var b: = UI.label(("×2" if String(pr[0]).begins_with("Первая") else "+%d" % int(pr[1])), 18, Color("a9d9c4"), UI.DARK, 2, "body", 900)
		b.position = Vector2(pw - 100, 72 + k * 34)
		panel.add_child(b)
	ctx.y += panel.size.y + 10.0
	for m in miles:
		var c: = Common.chip(ctx.plate, V8Art.icon("gift"), "Веха %d: %s" % [int(m.at), V7EventData.mile_text(m, def)], Rect2(V8_RES_PAD + 8, ctx.y, pw - 16, 46), "plum", 18)
		UI.pop_in(c, 0.6)
		ctx.y += 54.0
	var beat: = {0: 0, 5: 1, 11: 2}
	if first and beat.has(node_i):
		v8_res_say(ctx, String(def.hero), String(def.lines[beat[node_i]]))
	v8_res_rank(ctx, ea)
	var nxt: = node_i + 1
	var has_next: = nxt < V7EventData.NODES
	var go_next: = func(): main.go("v7play", {"mode": "v7event", "node": nxt if has_next else node_i, "partner": partner, "retry": randi()})
	ctx["emo"] = V8Art.win_emotion(String(def.hero)) if stars >= 2 else "happy"
	v8_res_close(ctx, String(def.hero), "Следующий стол" if has_next else "Ещё раз", go_next,
		"К карте ивента", func(): main.go("v7event"))
	Fx.burst(ctx.root, Vector2(W * 0.5, 300), "confetti", 60, Color.WHITE, 1.1)
	v8_res_light_stars(ctx, srow, stars)


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
	rp_before = int(G.S.rp)
	var ta: = V8PlayRules.award("tourney", V8PlayRules.tourney_rp(cleared, total, int(res.place_before) - int(res.place_after)), cleared)
	rp_gain = int(ta.rp)
	rank_ups = ta.ups
	_v8_saved = true
	_v8_end_overlays()
	print("V7TOURNEY table=%d score=%d cleared=%s place %d->%d" % [table_k, total, str(cleared), int(res.place_before), int(res.place_after)])
	Sfx.play("win" if cleared else "deny", 1.0 if cleared else 0.7)
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return
	var ctx: = v8_res_open("Стол очищен" if cleared else "Партия окончена", "gold" if cleared else "pink", 40)
	v8_res_big(ctx, str(total), "очки стола")
	var rows: = [["Пары и серии", score + overflows * V7Ladder.OVERFLOW]]
	if overflows > 0:
		rows.append(["Переполнения ×%d" % overflows, - overflows * V7Ladder.OVERFLOW])
	for pr in fin.parts:
		rows.append(pr)
	var pw: float = ctx.w - V8_RES_PAD * 2.0
	var panel: = UI.rbox("glass", Rect2(V8_RES_PAD, ctx.y, pw, 16 + rows.size() * 34), 24, 3, 8)
	panel.borders(Color("ffe7a6"), Color("8a6a3a"))
	(ctx.plate as Control).add_child(panel)
	for k in rows.size():
		var a: = UI.label(String(rows[k][0]), 18, Color("ddd2c4"))
		a.position = Vector2(24, 8 + k * 34)
		panel.add_child(a)
		var v: = int(rows[k][1])
		var b: = UI.label(("+%d" % v) if v >= 0 else str(v), 18, Color("a9d9c4") if v >= 0 else Color("e3a3b2"), UI.DARK, 2, "body", 900)
		b.position = Vector2(pw - 100, 8 + k * 34)
		panel.add_child(b)
	ctx.y += panel.size.y + 10.0
	var t: = V7Ladder.st()
	var line: = ("Новый рекорд стола! Было %d" % int(res.old)) if res.improved else ("Лучший результат стола: %d" % int(res.best))
	v8_res_line(ctx, line, 20, Color("a9d9c4") if res.improved else Color("ddd2c4"), 2.0)
	var pl_: = "Место в группе: #%d" % int(res.place_after)
	if int(res.place_after) < int(res.place_before):
		pl_ += "  ▲ %d" % (int(res.place_before) - int(res.place_after))
	var z: = V7Ladder.zone(int(res.place_after), int(t.league))
	var zc: = Color("ffe7a6")
	if z == "up":
		pl_ += " · зона повышения"
		zc = Color("a9d9c4")
	elif z == "down":
		pl_ += " · зона понижения"
		zc = Color("e3a3b2")
	v8_res_line(ctx, pl_, 22, zc)
	v8_res_rank(ctx, ta, maxi(0, int(res.best) - int(res.old)))
	# 0.8: a new table record amazes her; a cleared table is a win; a table lost to overflows saddens her
	ctx["emo"] = "surprised" if res.improved else (V8Art.win_emotion(partner) if cleared else "sad")
	v8_res_close(ctx, partner, "Ещё раз", func(): main.go("v7play", {"mode": "v7tourney", "table": table_k, "partner": partner, "retry": randi()}),
		"К турниру", func(): main.go("v7tourney"))
	if res.improved:
		Fx.burst(ctx.root, Vector2(W * 0.5, 310), "confetti", 60, Color.WHITE, 1.1)

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
