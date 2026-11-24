extends "res://scripts/screens/play.gd"







const MINE: = ["climb", "etude", "shift"]

var run: = {}
var strip: Control
var strip_h: = 0.0

var lamp_nodes: Array = []
var floor_gems: = 0
var over: = false
var bless_cards: Array = []

var etude_i: = 0
var etude_undos: = 0
var stuck: = false
var etude_star_nodes: Array = []
var undo_lbl: Label

var table: = 0
var seats: Array = []
var tips: = 0
var served: = 0
var missed: = 0
var tips_lbl: Label
var shift_live: = false


func _v6_setup(args: Dictionary) -> bool:
	var m: String = args.get("mode", "")
	var dev: = {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv: = a.substr(2).split("=", true, 1)
			dev[kv[0]] = kv[1]
	match m:
		"climb":
			mode = "climb"
			run = args.get("run", {})
			if run.is_empty():
				run = V6ModesData.new_run(partner)
				if dev.has("climb_floor"):
					run.floor = int(dev.climb_floor)
				var s: = V6ModesData.st()
				s.climb_runs = int(s.climb_runs) + 1
			partner = run.partner
			cfg = V6ModesData.floor_cfg(run)
			hint_n = int(run.hint)
			undo_n = int(run.undo)
			shuffle_n = int(run.shuffle)
			return true
		"etude":
			mode = "etude"
			etude_i = clampi(int(args.get("etude", dev.get("etude", "0"))), 0, V6ModesData.ETUDES - 1)
			cfg = V6ModesData.etude_cfg(etude_i)
			return true
		"shift":
			mode = "shift"
			table = 0
			cfg = V6ModesData.shift_cfg(0, partner)
			return true
	return false

func _slot_count() -> int:
	match mode:
		"climb":
			return V7Passives.slots(partner, int(run.get("slots", 4)))
		"etude":
			return V6ModesData.ETUDE_SLOTS
	return super._slot_count()

func _make_board() -> void :
	if mode in MINE:
		if strip == null:
			_build_strip()
		var top: = board_rect.position.y + strip_h + 8
		board_rect = Rect2(board_rect.position.x, top, board_rect.size.x, board_rect.end.y - top)
	if mode == "etude":
		seed(int(cfg.seed))
	super._make_board()
	if mode == "etude":
		randomize()

func _apply_perk() -> void :
	super._apply_perk()
	match mode:
		"climb":
			if int(run.floor) > 1:
				hint_n = int(run.hint)
				undo_n = int(run.undo)
				shuffle_n = int(run.shuffle)
			var b: Dictionary = run.bless
			var n: = int(b.get("breath", 0))
			if n > 0:
				board.combo_window += (2.5 if V6ModesData.bless_plus("breath") else 1.5) * n
			n = int(b.get("backdoor", 0))
			if n > 0:
				shuffle_n += (2 if V6ModesData.bless_plus("backdoor") else 1) * n
			if int(b.get("silver", 0)) > 0:
				gold_mult *= 3 if V6ModesData.bless_plus("silver") else 2
		"etude":
			hint_n = 0
			undo_n = 0
			shuffle_n = 0
			gem_bonus = 0.0

func _intro() -> void :
	await super._intro()
	if not is_inside_tree():
		return
	match mode:
		"climb":
			var w: = int(run.bless.get("warmup", 0))
			if w > 0:
				board.auto_pairs(w * (2 if V6ModesData.bless_plus("warmup") else 1))
			if int(run.bless.get("overclock", 0)) > 0:
				if V6ModesData.bless_plus("overclock"):
					skill_charge = SKILL_NEED
					if not skill_ready:
						_skill_ready()
				else:
					skill_charge = maxi(skill_charge, SKILL_NEED / 2)
			_refresh()
		"shift":
			shift_live = true
			for i in seats.size():
				get_tree().create_timer(0.4 + i * 0.7).timeout.connect( func(): _seat_arrive(i))


func _build_strip() -> void :
	strip_h = {"climb": 72.0, "etude": 64.0, "shift": 132.0}[mode]
	strip = Control.new()
	strip.position = Vector2(10, board_rect.position.y)
	strip.size = Vector2(W - 20, strip_h)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.z_index = 5
	add_child(strip)
	match mode:
		"climb":
			_climb_strip()
		"etude":
			_etude_strip()
		"shift":
			_shift_strip()
	UI.slide_in(strip, Vector2(0, -20), 0.2, 0.4)

func _panel(r: Rect2) -> RBox:
	var p: = UI.rbox("glass", r, minf(22.0, r.size.y * 0.5), 3, 8)
	p.borders(Color("ffe7a6"), Color("c58a2c"))
	strip.add_child(p)
	return p

func _lantern(parent: Control, pos: Vector2, lit: bool) -> Control:
	var c: = Control.new()
	c.position = pos
	c.size = Vector2(30, 40)
	c.pivot_offset = Vector2(15, 20)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	var g: = Sprite2D.new()
	g.texture = G.fx("glow")
	g.material = Fx.add_mat()
	g.position = Vector2(15, 20)
	g.scale = Vector2(0.9, 0.9)
	g.modulate = Color(1, 0.55, 0.25, 0.7)
	g.name = "Glow"
	c.add_child(g)
	var cap: = UI.rbox("gold", Rect2(9, 0, 12, 6), 3, 0, 2)
	cap.set_param("shadow_color", Color(0, 0, 0, 0))
	c.add_child(cap)
	var body: = UI.rbox("red", Rect2(2, 5, 26, 30), 12, 2, 4)
	body.colors(Color("ff9a6a"), Color("d8344a")).borders(Color("ffe7a6"), Color("8a1a2a"))
	body.name = "Body"
	c.add_child(body)
	var foot: = UI.rbox("gold", Rect2(9, 34, 12, 6), 3, 0, 2)
	foot.set_param("shadow_color", Color(0, 0, 0, 0))
	c.add_child(foot)
	_set_lamp(c, lit, false)
	return c

func _set_lamp(c: Control, lit: bool, animate: = true) -> void :
	var g: Sprite2D = c.get_node("Glow")
	g.visible = lit
	c.modulate = Color.WHITE if lit else Color(0.35, 0.3, 0.4, 0.75)
	if animate and not lit:
		UI.punch(c, 0.4)
		Fx.burst(strip, c.position + Vector2(15, 20), "sparkle", 14, Color(1, 0.6, 0.3), 0.7)


func _climb_strip() -> void :
	var w: = strip.size.x
	var p: = _panel(Rect2(0, 0, w, strip_h))
	var fl: = UI.label("ЭТАЖ", 16, Color("cbb5dc"), Color.WHITE, 0, "body", 900)
	fl.position = Vector2(18, 2)
	p.add_child(fl)
	var fn: = UI.title(str(int(run.floor)), 40, Color("ffe7a6"), Color("5a1a6a"))
	fn.position = Vector2(16, 18)
	fn.size = Vector2(80, 50)
	p.add_child(fn)
	if int(run.floor) % 5 == 0:
		var g: = UI.rbox("red", Rect2(84, 10, 86, 26), 13, 2, 4)
		p.add_child(g)
		g.add_child(UI.center_label(UI.label("СТРАЖ", 16, Color.WHITE, Color("6a1020"), 3, "body", 900), Rect2(0, 0, 86, 26)))

	lamp_nodes.clear()
	var lx: = 186.0
	for i in V6ModesData.LAMPS_MAX:
		if i >= maxi(int(run.lamps), V6ModesData.LAMPS_START):
			break
		lamp_nodes.append(_lantern(p, Vector2(lx + i * 36, 15), i < int(run.lamps)))

	var bx: = w - 14.0
	var ids: Array = run.bless.keys()
	ids.reverse()
	for id in ids:
		bx -= 52
		var av: = Common.avatar(V6ModesData.BLESS[id].hero, Rect2(bx, 10, 48, 48), "gold" if V6ModesData.bless_plus(id) else "plum")
		p.add_child(av)
		var n: = int(run.bless[id])
		if n > 1:
			var nb: = UI.rbox("pink", Rect2(28, 28, 28, 24), 12, 2, 2)
			av.add_child(nb)
			nb.add_child(UI.center_label(UI.label(str(n), 16, Color.WHITE, Color("6a1020"), 2, "body", 900), Rect2(0, 0, 28, 24)))
		if bx < 400:
			break
	if ids.is_empty():
		var hl: = UI.label("благословения появятся после этажа", 16, Color("cbb5dc"))
		hl.size = Vector2(310, 26)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hl.position = Vector2(w - 324, 22)
		p.add_child(hl)

func _climb_fail() -> void :
	run.lamps = int(run.lamps) - 1
	var i: = int(run.lamps)
	if i >= 0 and i < lamp_nodes.size():
		_set_lamp(lamp_nodes[i], false)
	Sfx.play("deny", 0.7)
	Fx.shake(tray_box, 8, 0.35)
	if int(run.lamps) <= 0:
		over = true
		Sfx.say(partner, "lose")
		await get_tree().create_timer(0.7).timeout
		if is_inside_tree():
			_climb_over(false)
		return
	Fx.float_text(fx_layer, Vector2(W * 0.5, 360), "Фонарь погас · осталось %d" % int(run.lamps), Color("ffb38a"), 30)
	await get_tree().create_timer(0.25).timeout
	if is_inside_tree():
		board.return_tray(3)
		_refresh()

func _climb_clear() -> void :
	var f: = int(run.floor)
	var s: = V6ModesData.st()
	var gems: = V6ModesData.floor_gems(f)
	var chest: = f % 5 == 0
	if chest:
		gems += 80 + f * 10
		run.chests = int(run.chests) + 1
		run.lamps = mini(int(run.lamps) + 1, V6ModesData.LAMPS_MAX)
	var mile_gems: = 0
	for m in V6ModesData.CLIMB_MILES:
		if f >= int(m[0]) and not int(m[0]) in s.climb_miles.map( func(x): return int(x)):
			s.climb_miles.append(int(m[0]))
			mile_gems += int(m[1])
	G.S.gems += gems + mile_gems
	run.gems = int(run.gems) + gems + mile_gems + gained
	gained = 0
	var record: = f > int(s.climb_best)
	if record:
		s.climb_best = f
	run.hint = hint_n
	run.undo = undo_n
	run.shuffle = shuffle_n
	G.add_aff(partner, 4)
	G.task_add("levels")
	G.add_pass_xp(40)
	var ca: = V8PlayRules.award("other", V8PlayRules.climb_rp(f), true)
	# the run's rank points and rank-ups, for the rank card of the end window
	run["rp"] = int(run.get("rp", 0)) + int(ca.get("rp", 0))
	run["ups"] = (run.get("ups", []) as Array) + (ca.get("ups", []) as Array)
	Sfx.play("win", 1.1)
	Sfx.say(partner, "win")
	_v8_end_overlays()
	await get_tree().create_timer(0.35).timeout
	if is_inside_tree():
		_floor_overlay(f, gems, chest, mile_gems, record, ca)

func _floor_overlay(f: int, gems: int, chest: bool, mile_gems: int, record: bool, ca: = {}) -> void :
	var root: = Control.new()
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 60
	add_child(root)
	var dim: = ColorRect.new()
	dim.size = size
	dim.color = Color(0.08, 0.03, 0.14, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.78, 0.35)
	Common.rays(root, Vector2(W * 0.5, 170), 900, Color(0.75, 0.8, 1.0, 0.45), 12, 0.04, 0.6)
	var rib: = Common.ribbon(root, "Этаж %d пройден" % f, Rect2(W * 0.5 - 250, 70, 500, 96), "gold" if chest else "pink", 40)
	UI.pop_in(rib, 0.05, 0.4)
	var line: = "+" + gems_text(gems)
	if chest:
		line += " · сундук стража · фонарь +1"
	if mile_gems > 0:
		line += " · веха +%d" % mile_gems
	if int(ca.get("rp", 0)) > 0:
		line += " · " + V8PlayRules.award_text(ca)
	var rl: = UI.center_label(UI.label(line, 22, Color("ffe7a6"), UI.DARK, 4, "body", 900), Rect2(20, 176, W - 40, 34))
	root.add_child(rl)
	var note: = V8PlayRules.rankup_text(ca)
	if note == "" and record:
		note = "Новый рекорд лестницы!"
	if note != "":
		root.add_child(UI.center_label(UI.label(note, 20, Color("ffd34d") if V8PlayRules.rankup_text(ca) != "" else Color("9fe8d0"), UI.DARK, 3, "body", 900), Rect2(20, 210, W - 40, 30)))
	if chest:
		Fx.burst(root, Vector2(W * 0.5, 190), "confetti", 70, Color.WHITE, 1.2)
		Sfx.play("reveal_ssr", 1.1, -2)
	main.fly_gems(V10Layout.to_canvas(self, Vector2(W * 0.5, 190)), 6)
	var hl: = UI.center_label(UI.title("Выбери благословение", 34, Color.WHITE, Color("3f2a7a")), Rect2(0, 252, W, 50))
	root.add_child(hl)
	var offer: = V6ModesData.bless_offer(run)
	var y: = 318.0
	for k in offer.size():
		var id: String = offer[k]
		var card: = _bless_card(root, id, Rect2(40, y, W - 80, 172))
		bless_cards.append([id, card])
		UI.slide_in(card, Vector2(0, 60), 0.25 + k * 0.12, 0.4)
		y += 190
	var quit: = JButton.make("Завершить восхождение", "glass", Rect2(W * 0.5 - 220, y + 14, 440, 84), null, 24)
	quit.pressed.connect( func():
		root.queue_free()
		_climb_over(true))
	root.add_child(quit)
	UI.pop_in(quit, 0.7)

func _bless_card(root: Control, id: String, r: Rect2) -> Control:
	var b: Dictionary = V6ModesData.BLESS[id]
	var plus: = V6ModesData.bless_plus(id)
	var col: Color = G.HEROES[b.hero].color
	var card: = UI.rbox("glass", r, 30, 4, 12)
	card.colors(Color(col.r * 0.32, col.g * 0.2, col.b * 0.34, 0.97), Color(0.07, 0.04, 0.1, 0.98))
	card.borders(Color("fff0b8") if plus else Color("ffe7a6"), Color("f0b03a") if plus else Color("8a6a3a"))
	if plus:
		card.set_param("glow", 1.0).set_param("glow_color", Color(1.0, 0.8, 0.4))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = r.size * 0.5
	root.add_child(card)
	var halo: = Sprite2D.new()
	halo.texture = G.fx("glow")
	halo.material = Fx.add_mat()
	halo.position = Vector2(86, r.size.y * 0.5)
	halo.scale = Vector2(2.4, 2.4)
	halo.modulate = Color(col.r, col.g, col.b, 0.55)
	card.add_child(halo)
	card.add_child(Common.avatar(b.hero, Rect2(22, (r.size.y - 128) * 0.5, 128, 128), "gold" if plus else "plum"))
	var hn: = UI.label(G.HEROES[b.hero].name.to_upper(), 16, col.lightened(0.45), Color(0, 0, 0, 0), 0, "body", 900)
	hn.position = Vector2(172, 18)
	card.add_child(hn)
	if plus:
		var pw: = UI.font("body", 900).get_string_size("ОНА С ТОБОЙ · СИЛЬНЕЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24.0
		var pb: = UI.rbox("gold", Rect2(r.size.x - pw - 16, 14, pw, 28), 14, 2, 4)
		card.add_child(pb)
		pb.add_child(UI.center_label(UI.label("ОНА С ТОБОЙ · СИЛЬНЕЕ", 16, Color("4a2a06"), Color(0, 0, 0, 0), 0, "body", 900), Rect2(0, 0, pw, 28)))
	var nm: = UI.title(b.name, 34, Color("fff6d8"), Color("3a1030"))
	nm.position = Vector2(170, 38)
	nm.size = Vector2(r.size.x - 190, 50)
	card.add_child(nm)
	var d: = UI.label(b.plus if plus else b.desc, 20, Color("ffe7a6") if plus else Color("f1e6ff"))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.position = Vector2(172, 94)
	d.size = Vector2(r.size.x - 196, 60)
	card.add_child(d)
	var have: = int(run.bless.get(id, 0))
	if have > 0:
		var hb: = UI.rbox("pink", Rect2(r.size.x - 96, -12, 86, 28), 14, 2, 4)
		card.add_child(hb)
		hb.add_child(UI.center_label(UI.label("уже ×%d" % have, 16, Color.WHITE, Color("6a1020"), 2, "body", 900), Rect2(0, 0, 86, 28)))
	card.gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed and not card.has_meta("used"):
			card.set_meta("used", true)
			_pick_blessing(id, card))
	return card

func _pick_blessing(id: String, card: Control) -> void :
	var plus: = V6ModesData.bless_plus(id)
	run.bless[id] = int(run.bless.get(id, 0)) + 1
	match id:
		"lamp":
			run.lamps = mini(int(run.lamps) + (2 if plus else 1), V6ModesData.LAMPS_MAX)
		"tips":
			run.hint = int(run.hint) + (3 if plus else 2)
		"cup":
			run.slots = mini(int(run.slots) + 1, V6ModesData.SLOTS_MAX)
			if plus:
				run.undo = int(run.undo) + 1
		"pause":
			run.undo = int(run.undo) + (4 if plus else 3)
		"clear":
			if plus:
				run.hint = int(run.hint) + 1
	Sfx.play("reveal_sr", 1.2)
	Sfx.say(V6ModesData.BLESS[id].hero, "aff")
	UI.punch(card, 0.25)
	Fx.burst(card, card.size * 0.5, "sparkle", 40, G.HEROES[V6ModesData.BLESS[id].hero].color.lightened(0.3), 1.3)
	await get_tree().create_timer(0.55).timeout
	run.floor = int(run.floor) + 1
	main.go("arena", {"mode": "climb", "run": run, "partner": run.partner})

func _climb_over(by_choice: bool) -> void :
	over = true
	board.input_on = false
	var s: = V6ModesData.st()
	var reached: = int(run.floor) - (0 if by_choice else 1)
	run.gems = int(run.gems) + gained
	gained = 0
	# 0.8: every cleared floor was already counted as a won game (V8PlayRules.award in _climb_clear). Ending the
	# run by choice adds no game; a run lost on its last lantern counts that one floor as a lost game.
	var ra: = {"rp": int(run.get("rp", 0)), "ups": run.get("ups", []), "gems": 0, "title": String(G.rank_of(int(G.S.rp)).title)}
	if not by_choice:
		V8PlayRules.award("other", 0, false)
	else:
		G.save()
	_v8_saved = true
	Sfx.play("win" if by_choice else "deny", 1.0 if by_choice else 0.6)
	var ctx: = v8_res_open("Восхождение окончено", "pink", 40)
	v8_res_big(ctx, str(maxi(0, reached)), "пройдено этажей")
	var best: = int(s.climb_best)
	v8_res_line(ctx, "Рекорд: %s · сундуков: %d" % [pl(best, "этаж", "этажа", "этажей"), int(run.chests)], 20, Color("fff1dc"), 4.0)
	v8_res_reward(ctx, int(run.gems), "", "gem", "за забег")
	for m in V6ModesData.CLIMB_MILES:
		if not int(m[0]) in s.climb_miles.map( func(x): return int(x)):
			v8_res_line(ctx, "Следующая веха: этаж %d · +%s" % [int(m[0]), gems_text(int(m[1]))], 18, Color("ffd98a"))
			break
	v8_res_avatars(ctx, run.bless.keys().map( func(id): return V6ModesData.BLESS[id].hero), 56.0)
	v8_res_rank(ctx, ra)
	# 0.8: her face on the result: a new climb record amazes her, a run lost on its last lantern saddens her
	ctx["emo"] = "surprised" if reached > 0 and reached >= best else (V8Art.win_emotion(partner) if by_choice else "sad")
	v8_res_close(ctx, partner, "Новое восхождение", func(): main.go("arena", {"mode": "climb", "partner": G.S.level_partner, "retry": randi()}),
		"К режимам", func(): main.go("modes"))


func _etude_strip() -> void :
	var w: = strip.size.x
	var p: = _panel(Rect2(0, 0, w, strip_h))
	var t: = UI.label("Отмен:", 18, Color("cbb5dc"), Color(0, 0, 0, 0), 0, "body", 900)
	t.position = Vector2(20, 18)
	p.add_child(t)
	undo_lbl = UI.label("0", 26, Color("ffe7a6"), UI.DARK, 3, "body", 900)
	undo_lbl.position = Vector2(96, 12)
	p.add_child(undo_lbl)
	var rule: = UI.label("0 отмен = 3★ · до 3 = 2★", 16, Color("cbb5dc"))
	rule.position = Vector2(150, 21)
	p.add_child(rule)
	etude_star_nodes.clear()
	for i in 3:
		var s: = V8Art.star_rect(true, Rect2(w - 168 + i * 52, 6, 52, 52))
		p.add_child(s)
		etude_star_nodes.append(s)
	var best: = V6ModesData.etude_stars(etude_i)
	if best > 0:
		var bl: = UI.label("лучшее: %s" % "★".repeat(best), 16, Color("ffd98a"))
		bl.position = Vector2(w - 330, 22)
		p.add_child(bl)

func _etude_live_stars() -> int:
	return 3 if etude_undos == 0 else (2 if etude_undos <= 3 else 1)

func _etude_update() -> void :
	if undo_lbl:
		undo_lbl.text = str(etude_undos)
		UI.punch(undo_lbl, 0.25)
	var n: = _etude_live_stars()
	for i in etude_star_nodes.size():
		var s: TextureRect = etude_star_nodes[i]
		var on: = i < n
		if not on and s.texture != V8Art.star(false):
			s.texture = V8Art.star(false)
			UI.punch(s, 0.3)

func _etude_stuck() -> void :
	stuck = true
	Sfx.play("deny", 0.8)
	Fx.shake(tray_box, 8, 0.3)
	# 0.8: over the etude strip above the table (never over a tile row), and it lets taps through
	var sr: = Rect2(strip.position, strip.size) if strip else Rect2(10, board_rect.position.y - 70, W - 20, 64)
	var rib: = Common.ribbon(self, "Тупик · отмени ход", Rect2(sr.position.x + 40, sr.position.y - 4, sr.size.x - 80, sr.size.y + 8), "red", 32)
	rib.z_index = 40
	_v8_ignore(rib)
	rib.name = "StuckRib"
	UI.pop_in(rib, 0.0, 0.5)
	btn_undo.pulse = true
	btn_undo.shine_every = 1.0

func _etude_clear() -> void :
	var stars: = _etude_live_stars()
	var s: = V6ModesData.st()
	var prev: = V6ModesData.etude_stars(etude_i)
	var gems: = 0
	if prev == 0:
		gems += V6ModesData.etude_first_gems(etude_i)
	if stars > prev:
		gems += (stars - prev) * 20
		s.etude_stars[str(etude_i)] = stars
	G.S.gems += gems
	G.add_aff("mc", 3)
	G.task_add("levels")
	G.add_pass_xp(50)
	var ea: = V8PlayRules.award("etude", V8PlayRules.etude_rp(stars), true)
	_v8_saved = true
	_v8_end_overlays()
	Sfx.play("win")
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	var ctx: = v8_res_open("Этюд %d решён" % (etude_i + 1), "pink", 44)
	var row: = v8_res_stars(ctx, "0 отмен — 3★ · до 3 отмен — 2★")
	v8_res_line(ctx, "Отмен: %d" % etude_undos, 20, Color("fff1dc"), 4.0)
	if gems > 0:
		v8_res_reward(ctx, gems)
	else:
		v8_res_line(ctx, "Награда уже получена · попробуй без отмен", 18, Color("cbb5dc"))
	var said: String = ["Красиво решено. Видишь, как близнецы прятались?", "Ты думаешь на два хода вперёд, мне нравится.", "Чистое решение. Следующий этюд хитрее."][stars - 1] if stars > 0 else ""
	v8_res_say(ctx, "mc", said)
	v8_res_rank(ctx, ea)
	var last: = etude_i >= V6ModesData.ETUDES - 1
	var go_next: = func():
		if last:
			main.go("modes", {"open": "etude"})
		else:
			main.go("arena", {"mode": "etude", "etude": etude_i + 1, "partner": partner})
	ctx["emo"] = V8Art.win_emotion("mc") if stars >= 2 else ("happy" if stars == 1 else "pout")
	v8_res_close(ctx, "mc", "Следующий этюд" if not last else "К этюдам", go_next,
		"Ещё раз", func(): main.go("arena", {"mode": "etude", "etude": etude_i, "partner": partner, "retry": randi()}))
	if gems > 0:
		main.fly_gems(V10Layout.to_canvas(self, Vector2(W * 0.5, 480)), 6)
	v8_res_light_stars(ctx, row, stars)


func _shift_strip() -> void :
	var w: = strip.size.x
	var tw: = 124.0
	var sw: = (w - tw - 16) / 3.0
	seats.clear()
	for i in 3:
		var card: = _panel(Rect2(i * (sw + 8), 0, sw, strip_h))
		seats.append({"hero": "", "cat": -1, "need": 0, "left": 0.0, "pat": 1.0, "tip": 0, "node": card, "busy": false})
		_seat_draw(i)
	var tb: = _panel(Rect2(w - tw, 0, tw, strip_h))
	tb.colors(Color(0.32, 0.2, 0.08, 0.92), Color(0.18, 0.1, 0.04, 0.94))
	tb.add_child(V8Art.rect(V8Art.cur("gem"), Rect2(tw * 0.5 - 28, 6, 56, 56)))
	tips_lbl = UI.center_label(UI.label("0", 30, Color("ffe7a6"), UI.DARK, 4, "body", 900), Rect2(0, 58, tw, 40))
	tb.add_child(tips_lbl)
	tb.add_child(UI.center_label(UI.label("чаевые", 16, Color("e8d2a8")), Rect2(0, 96, tw, 24)))

func _seat_draw(i: int) -> void :
	var s: Dictionary = seats[i]
	var card: RBox = s.node
	for c in card.get_children():
		c.queue_free()
	var cw: = card.size.x
	if s.hero == "":
		card.modulate = Color(1, 1, 1, 0.55)
		card.add_child(UI.center_label(UI.label("свободно", 17, Color("cbb5dc")), Rect2(0, 0, cw, strip_h)))
		return
	card.modulate = Color.WHITE
	var col: Color = G.HEROES[s.hero].color
	card.add_child(Common.avatar(s.hero, Rect2(6, 8, 74, 74), "gold" if G.hero_unlocked(s.hero) else "plum"))
	# 0.8: the name has its own line under the avatar and order (full card width), the category sits beside
	# the order tile above it, so a long name («Маджонг-тян») never runs into the category
	var nm: = UI.center_label(UI.label(G.HEROES[s.hero].name, 16, Color.WHITE, UI.DARK, 3, "body", 900), Rect2(4, 84, cw - 8, 22))
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	card.add_child(nm)
	var c: Array = G.CATS[s.cat]
	var ic: = UI.tex(G.tile_tex(int(c[0])), Rect2(86, 6, 44, 56))
	card.add_child(ic)
	var nl: = UI.label("×%d" % int(s.need), 28, Color("ffe7a6"), UI.DARK, 4, "body", 900)
	nl.position = Vector2(cw - 54, 14)
	nl.name = "Need"
	card.add_child(nl)
	var cl: = UI.label(str(c[3]), 16, Color("f3ecff"), UI.DARK, 2, "body", 900)
	cl.position = Vector2(84, 60)
	cl.size = Vector2(cw - 88, 22)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cl.clip_text = true
	card.add_child(cl)
	var bar_bg: = UI.rbox("plum", Rect2(8, strip_h - 20, cw - 16, 10), 5, 1, 2)
	bar_bg.colors(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.35)).set_param("shadow_color", Color(0, 0, 0, 0))
	card.add_child(bar_bg)
	var bar: = UI.rbox("gold", Rect2(2, 2, cw - 20, 6), 3, 0, 1)
	bar.colors(Color("fff0b8"), col).set_param("shadow_color", Color(0, 0, 0, 0))
	bar.name = "Bar"
	bar_bg.add_child(bar)
	s["bar"] = bar
	s["bar_w"] = cw - 20

func _cats_free() -> Dictionary:

	var cnt: = {}
	for t in board.tiles:
		if board.on_board(t) and not t.pending and t.shard == "":
			var c: = G.face_cat(t.face)
			if c >= 0:
				cnt[c] = int(cnt.get(c, 0)) + 1
	var out: = {}
	for c in cnt:
		out[c] = int(cnt[c]) / 2
	for s in seats:
		if s.hero != "":
			out[s.cat] = int(out.get(s.cat, 0)) - int(s.need)
	return out

func _seat_arrive(i: int) -> void :
	if not is_inside_tree() or not shift_live or i >= seats.size():
		return
	var s: Dictionary = seats[i]
	if s.hero != "" or s.busy:
		return
	var free: = _cats_free()
	var avail: = free.keys().filter( func(c): return int(free[c]) > 0)
	if avail.is_empty():
		return
	var taken: = seats.map( func(x): return x.hero)
	var pool: = V6ModesData.GUESTS.filter( func(h): return not h in taken)
	var h: String = pool[randi() % pool.size()]
	var taste: Dictionary = V6ModesData.TASTE[h]
	var cat: int = avail[randi() % avail.size()]
	for c in taste.cats:
		if c in avail:
			cat = c
			break
	var mx: = mini(3, int(free[cat]))
	var need: = 1
	var r: = randf()
	if mx >= 2 and r > 0.45:
		need = 2
	if mx >= 3 and r > 0.82:
		need = 3
	var pat: float = float(taste.pat) * (1.0 - 0.08 * table) + need * 8.0
	var tip: = int(round((12 + 10 * need) * float(taste.tip) * (1.5 if G.hero_unlocked(h) else 1.0)))
	s.hero = h
	s.cat = cat
	s.need = need
	s.left = pat
	s.pat = pat
	s.tip = tip
	_seat_draw(i)
	var card: Control = s.node
	card.pivot_offset = card.size * 0.5
	UI.pop_in(card, 0.0, 0.7)
	Sfx.play("pop", 1.1)
	var lines: Array = V6ModesData.ORDER_LINES[h]
	_seat_bubble(i, lines[randi() % lines.size()])

# 0.8: one guest bubble at a time, no wider than her seat, so two never cover each other
var _seat_bub: Control = null

func _seat_bubble(i: int, text: String) -> void :
	# 0.8: the line is said inside the guest's seat card (over her name and category, tail up to her face),
	# never over the table under the strip
	var card: Control = seats[i].node
	if _seat_bub and is_instance_valid(_seat_bub):
		_seat_bub.queue_free()
	var w: = card.size.x - 8.0
	var f: = UI.font("body", 800)
	var fs: = 17
	var th: float = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, w - 16.0, fs).y
	while fs > 16 and th > 66.0:
		fs -= 1
		th = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, w - 16.0, fs).y
	var h: = clampf(th + 12.0, 40.0, card.size.y - 8.0)
	var b: = Control.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.position = Vector2(4, card.size.y - h - 4.0)
	b.size = Vector2(w, h)
	b.z_index = 6
	var tail: = Polygon2D.new()
	tail.color = Color(0.12, 0.11, 0.13, 0.97)
	tail.polygon = PackedVector2Array([Vector2(30, 6), Vector2(52, 6), Vector2(38, -8)])
	b.add_child(tail)
	var box: = UI.rbox("cream", Rect2(0, 0, w, h), 16, 3, 6)
	box.set_param("border_top", Color("e8c9a0")).set_param("border_bottom", Color("a8697a"))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var l: = UI.label(text, fs, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(8, 2)
	l.size = Vector2(w - 16, h - 4)
	b.add_child(l)
	card.add_child(b)
	b.modulate.a = 0.0
	var tin: = b.create_tween()
	tin.tween_property(b, "modulate:a", 1.0, 0.12)
	_seat_bub = b
	var t: Tween = b.create_tween()
	t.tween_interval(1.8)
	t.tween_property(b, "modulate:a", 0.0, 0.3)
	t.tween_callback(b.queue_free)

func _seat_leave(i: int, happy: bool) -> void :
	var s: Dictionary = seats[i]
	var h: String = s.hero
	s.busy = true
	if happy:
		var th: Array = V6ModesData.THANKS[h]
		_seat_bubble(i, th[randi() % th.size()])
	else:
		_seat_bubble(i, V6ModesData.LEAVE[h])
	var card: Control = s.node
	var t: = card.create_tween()
	t.tween_interval(0.9)
	t.tween_property(card, "modulate:a", 0.0, 0.25)
	t.tween_callback( func():
		s.hero = ""
		s.busy = false
		_seat_draw(i)
		get_tree().create_timer(1.2).timeout.connect( func(): _seat_arrive(i)))

func _shift_serve(mid: Vector2) -> void :
	var c: = G.face_cat(board.last_face)
	var best: = -1
	for i in seats.size():
		var s: Dictionary = seats[i]
		if s.hero != "" and not s.busy and int(s.cat) == c and int(s.need) > 0:
			if best < 0 or float(s.left) < float(seats[best].left):
				best = i
	if best < 0:
		return
	var s: Dictionary = seats[best]
	s.need = int(s.need) - 1
	var card: Control = s.node
	var target: = strip.position + card.position + Vector2(40, 44)

	var spark: = Sprite2D.new()
	spark.texture = G.fx("glow")
	spark.material = Fx.add_mat()
	spark.modulate = G.HEROES[s.hero].color.lightened(0.3)
	spark.position = mid
	spark.scale = Vector2(0.8, 0.8)
	spark.z_index = 50
	add_child(spark)
	var ft: = spark.create_tween()
	ft.tween_property(spark, "position", target, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ft.tween_callback(spark.queue_free)
	UI.punch(card, 0.2)
	if int(s.need) > 0:
		var nl = card.get_node_or_null("Need")
		if nl:
			nl.text = "×%d" % int(s.need)
		return
	var bonus: = int(round(10.0 * clampf(float(s.left) / float(s.pat), 0.0, 1.0)))
	var got: = int(s.tip) + bonus
	tips += got
	served += 1
	G.add_aff(s.hero, 5)
	tips_lbl.text = str(tips)
	UI.punch(tips_lbl, 0.35)
	Fx.burst(self, target, "heart", 10)
	Fx.float_text(fx_layer, target + Vector2(30, 70), "+%d чаевых" % got, Color("ffe7a6"), 28)
	Sfx.play("reveal_r", 1.2, -3)
	_seat_leave(best, true)

func _shift_tick(dt: float) -> void :
	if not shift_live or not board or not board.input_on:
		return
	for i in seats.size():
		var s: Dictionary = seats[i]
		if s.hero == "" or s.busy:
			continue
		s.left = float(s.left) - dt
		var bar = s.get("bar")
		if bar and is_instance_valid(bar):
			var k: = clampf(float(s.left) / float(s.pat), 0.0, 1.0)
			bar.size.x = maxf(6.0, float(s.bar_w) * k)
			if k < 0.25:
				bar.modulate = Color(1, 0.55, 0.55)
		if float(s.left) <= 0.0:
			missed += 1
			_seat_leave(i, false)

func _shift_validate() -> void :

	var free: = _cats_free()
	for i in seats.size():
		var s: Dictionary = seats[i]
		if s.hero == "":
			get_tree().create_timer(0.5 + i * 0.5).timeout.connect( func(): _seat_arrive(i))
			continue
		if int(free.get(s.cat, 0)) < 0:
			var avail: = free.keys().filter( func(c): return int(free[c]) >= int(s.need))
			if avail.is_empty():
				s.need = 1
				avail = free.keys().filter( func(c): return int(free[c]) > 0)
			if not avail.is_empty():
				free[s.cat] = int(free[s.cat]) + int(s.need)
				s.cat = avail[randi() % avail.size()]
				free[s.cat] = int(free[s.cat]) - int(s.need)
				_seat_draw(i)

func _shift_clear() -> void :
	table += 1
	G.add_pass_xp(30)
	if table < V6ModesData.SHIFT_TABLES:
		Sfx.play("win", 1.2, -6)
		# 0.9: petals and gold dust under the (empty) board, not flat confetti over the next table
		var ub: = _v9_under_board_fx()
		Fx.burst(ub, board_rect.get_center(), "petal", 24, Color(1, 0.8, 0.88), 1.3)
		Fx.burst(ub, board_rect.get_center(), "sparkle", 30, Color(1, 0.86, 0.5), 1.3)
		Fx.float_text(fx_layer, Vector2(W * 0.5, 620), "Стол убран · несут следующий", Color("ffe7a6"), 34)
		await get_tree().create_timer(0.9).timeout
		if not is_inside_tree():
			return
		cfg = V6ModesData.shift_cfg(table, partner)
		_make_board()
		_apply_shift_board()
		board.deal()
		_refresh()
		await get_tree().create_timer(1.0).timeout
		if is_inside_tree():
			_shift_validate()
		return
	shift_live = false
	_shift_end()

func _apply_shift_board() -> void :
	board.combo_window = maxf(board.combo_window, 3.0)

func _shift_end() -> void :
	var s: = V6ModesData.st()
	var record: = tips > int(s.shift_best)
	if record:
		s.shift_best = tips
	s.shift_runs = int(s.shift_runs) + 1
	s.shift_served = int(s.shift_served) + served
	G.S.gems += tips
	G.task_add("levels")
	G.add_aff(partner, 6)
	var sa: = V8PlayRules.award("other", V8PlayRules.shift_rp(served), served > missed)
	_v8_saved = true
	Sfx.play("win")
	Sfx.say(partner, "win")
	var ctx: = v8_res_open("Смена закрыта", "pink", 44)
	v8_res_big(ctx, str(tips), "чаевые")
	v8_res_line(ctx, "Обслужено: %s · ушли без заказа: %d" % [pl(served, "гостья", "гостьи", "гостий"), missed], 20, Color("fff1dc"), 2.0)
	v8_res_line(ctx, ("Новый рекорд чайной!" if record else "Рекорд: %d" % int(s.shift_best)), 22, Color("ffd34d") if record else Color("d9c4e6"), 4.0)
	if tips > 0:
		v8_res_reward(ctx, tips, "+5 симпатии от каждой гостьи", "gem", "чаевые")
	v8_res_line(ctx, "Твои героини дают чаевые ×1,5", 17, Color("cbb5dc"), 2.0)
	v8_res_avatars(ctx, V6ModesData.GUESTS, 56.0, func(h): return "gold" if G.hero_unlocked(String(h)) else "plum")
	v8_res_rank(ctx, sa)
	ctx["emo"] = "surprised" if record else (V8Art.win_emotion(partner) if served > missed else "pout")
	v8_res_close(ctx, partner, "Новая смена", func(): main.go("arena", {"mode": "shift", "partner": partner, "retry": randi()}),
		"К режимам", func(): main.go("modes"))
	if tips > 0:
		main.fly_gems(V10Layout.to_canvas(self, Vector2(W * 0.5, 420)), 8)


func _process(dt: float) -> void :
	super._process(dt)
	if mode == "shift":
		_shift_tick(dt)

func _on_match(mid: Vector2, combo: int, gold: bool, shard: String) -> void :
	super._on_match(mid, combo, gold, shard)
	if mode == "shift":
		_shift_serve(mid)

func _on_fail() -> void :
	match mode:
		"climb":
			_climb_fail()
		"etude":
			_etude_stuck()
		"shift":
			for s in seats:
				if s.hero != "":
					s.left = float(s.left) - 8.0
			Fx.float_text(fx_layer, Vector2(W * 0.5, 360), "Гостьи ждут дольше · −8 с", Color("ffb38a"), 28)
			Sfx.play("deny", 0.8)
			Fx.shake(tray_box, 6, 0.3)
			await get_tree().create_timer(0.2).timeout
			if is_inside_tree():
				board.return_tray(3)
				_refresh()
		_:
			super._on_fail()

func _on_clear() -> void :
	match mode:
		"climb":
			_climb_clear()
		"etude":
			_etude_clear()
		"shift":
			_shift_clear()
		_:
			super._on_clear()

func _check_riichi() -> void :
	if mode in MINE:
		return
	super._check_riichi()

func _skill_ready() -> void :
	if mode == "etude":
		skill_charge = 0
		return
	super._skill_ready()

func _help_ok(kind: String) -> bool:
	if mode == "etude":
		# etude: only undo, and it also works while stuck (input off); an empty history is refused by the gate, so
		# the button gives only the deny (its handler then says why), never a success pop that does nothing
		var hist = board.get("history") if board else null
		return kind == "undo" and not (hist is Array and (hist as Array).is_empty())
	return super._help_ok(kind)

func _hint() -> void :
	if mode == "etude":
		V9Feel.deny(btn_hint)
		main.toast("В этюде подсказок нет: только отмена", "hint")
		return
	super._hint()

func _shuffle() -> void :
	if mode == "etude":
		V9Feel.deny(btn_shuffle)
		main.toast("В этюде фишки не смешиваются", "shuffle")
		return
	super._shuffle()

func _undo() -> void :
	if mode != "etude":
		super._undo()
		return
	if board.undo():
		etude_undos += 1
		Sfx.play("whoosh", 1.3)
		if stuck:
			stuck = false
			board.input_on = true
			btn_undo.pulse = false
			btn_undo.shine_every = 0.0
			var rib = get_node_or_null("StuckRib")
			if rib:
				rib.queue_free()
		_etude_update()
	else:
		V9Feel.deny(btn_undo)
		main.toast(V8PlayRules.T.undo_none, "undo")
	_refresh()

func _refresh() -> void :
	super._refresh()
	if mode == "etude" and btn_undo:
		for b in [btn_hint, btn_shuffle]:
			b.modulate = Color(0.5, 0.45, 0.55, 0.55)
			(b.get_node("Cap") as Label).text = "нет в этюде"
		(btn_undo.get_node("Cap") as Label).text = "Отмена · своб."

func dev_act(a: String) -> void :
	match a:
		"floorclear", "clear":
			for t in board.tiles:
				t.alive = false
				t.hide()
			_on_clear()
		"stuck":
			_on_fail()
		"bless":
			if not bless_cards.is_empty():
				_pick_blessing(bless_cards[0][0], bless_cards[0][1])
		"undo":
			_undo()
		"auto":
			for i in 6:
				var t: = board.solver_move()
				if t:
					board.tap(t)
				await get_tree().create_timer(0.35).timeout
		"serve":
			for s in seats:
				if s.hero != "":
					for t in board.free_tiles():
						if G.face_cat(t.face) == int(s.cat):
							board.last_face = t.face
							_shift_serve(V10Layout.local_of(self, t.get_global_transform_with_canvas().origin))
							break
					break
		_:
			super.dev_act(a)
