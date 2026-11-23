extends Control



var main
var W: = 720.0
var H: = 1280.0
var lvl: = 0
var cfg: Dictionary
var board: TrayBoard
var fx_layer: Node2D
var bubble: Control
var portrait: Control
var tiles_lbl: Label
var shard_lbl: Label
var gems_lbl: Label
var combo_lbl: Label
var meter: RBox
var meter_w: = 0.0
var tray_box: RBox
var slot_rects: Array = []
var fever_overlay: ColorRect
var fever_fx: Node2D
var btn_hint: JButton
var btn_undo: JButton
var btn_shuffle: JButton
var hint_n: = 2
var undo_n: = 2
var shuffle_n: = 1
var rescue_free: = true
var charge: = 0.0
var fever_until: = -1.0
var fever_pending: = false
var start_t: = 0.0
var boosters_used: = 0
var fails: = 0
var gained: = 0
var shards_found: = 0
var victory_summon_btn: JButton
var victory_next_btn: JButton
var fail_retry_btn: JButton
var board_rect: = Rect2()
var talk_cd: = 0.0
var partner: = "mc"
var mode: = ""
var gold_mult: = 5
var gem_bonus: = 0.0
var tut: = false
var first_unlock_summon: = false
var args0: = {}

var denies: = 0
var max_combo: = 0
var cat_streak: = 0
var cat_last: = -1
var sets_done: = []
var gold_total: = 0
var gold_got: = 0
var last_combo: = 0
var riichi: = false
var riichi_btn: JButton
var riichi_offered: = false

var fortune: = {}
var skill_charge: = 0
var SKILL_NEED: = 8
var stage: V6HeroStage
var duel = null
var _v6_danger: = false
var skill_ready: = false
var v7combo: V7Combo
var skill_bar: RBox
var skill_bar_w: = 100.0
var blitz_left: = 0.0
var blitz_score: = 0
var boards_done: = 0
var timer_lbl: Label
var score_lbl: Label
var free_rescue_left: = 0
var first_pairs_bonus: = 0

func build(m, args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	args0 = args
	main.show_chrome(false, false)
	lvl = int(args.get("level", G.current_level))
	partner = args.get("partner", G.S.level_partner)
	if _v6_setup(args):
		pass
	elif args.get("daily", false):
		mode = "daily"
		var d: = int(G.today().substr(8, 2))
		lvl = d % G.LEVELS.size()
		cfg = G.LEVELS[lvl].duplicate(true)
		cfg.name = V6Txt.s("play.daily_name")
		cfg.seed = int(G.today().replace("-", ""))
		cfg.reward = {"gems": 100}
		cfg.erase("shard")
		cfg.goal = V6Txt.s("play.goal_clear")
		cfg.intro = V6Txt.s("play.daily_intro")
	elif args.get("mode", "") in ["blitz", "zen"]:
		mode = args.mode
		cfg = _mode_cfg(0)
		blitz_left = 120.0
	elif args.get("mode", "") == "duel":
		mode = "duel"
		cfg = V6Heroines.duel_cfg(_v6_rival(args), partner)
	elif args.has("trial"):
		mode = "trial"
		partner = args.trial
		lvl = 0
		for i in G.LEVELS.size():
			if G.LEVELS[i].hero == partner:
				lvl = i
		cfg = G.LEVELS[lvl].duplicate(true)
		cfg.name = V6Txt.s("play.trial_name_pre") + G.HEROES[partner].name
		cfg.reward = {"gems": 0}
		cfg.erase("shard")
		cfg.goal = V6Txt.s("play.trial_goal")
		cfg.intro = V6Txt.s("play.trial_intro")
	else:
		G.current_level = lvl
		cfg = G.LEVELS[lvl]
	if not G.hero_unlocked(partner) and mode != "trial":
		partner = "mc"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--partner="):
			partner = a.substr(10)
	tut = lvl == 0 and mode == "" and not G.S.tut_done
	if mode == "" and not tut:
		fortune = G.draw_fortune(cfg)
		if fortune.get("gold", 0) > 0:
			cfg = cfg.duplicate(true)
			cfg.gold = int(cfg.get("gold", 0)) + int(fortune.gold)
	Sfx.music("play" if mode != "zen" else "menu")
	Common.backdrop(self, cfg.bg, size, 1.6 if cfg.bg != "play" else 0.0, 0.85, cfg.tint, Vector2(0.5, 0.5))
	Fx.ambient(self, cfg.fx, size)
	Common.vignette(self, size, Color(0.25, 0.08, 0.18), 0.55)
	_build_hud()
	board_rect = Rect2(10, 318, W - 20, H - 318 - 186)
	_make_board()
	_apply_perk()
	fx_layer = Node2D.new()
	add_child(fx_layer)
	v7combo = V7Combo.new().setup(self)
	add_child(v7combo)
	fever_overlay = Common.vignette(self, size, Color(1.0, 0.55, 0.2), 0.0)
	fever_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bottom()
	if mode == "duel":
		duel = V6Duel.new()
		add_child(duel)
		duel.setup(self, _v6_rival(args0))
	_refresh()
	_intro()


func _v6_rival(args: Dictionary) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rival="):
			return a.substr(8)
	return String(args.get("rival", "rin"))


func _v6_setup(_args: Dictionary) -> bool:
	return false

func _slot_count() -> int:
	return V7Passives.slots(partner, 6 if mode == "zen" else 4)

func _make_board() -> void :
	if board:
		board.queue_free()
	board = V6SpecialBoard.new()
	board.look = G.skin_look()
	board.slots = _slot_count()
	add_child(board)
	if fx_layer:
		move_child(board, fx_layer.get_index())
	board.setup(cfg)
	gold_total = board.tiles.filter( func(t): return t.gold).size() / 2
	board.fit_into(board_rect)
	board.slot_pos.clear()
	for r in slot_rects:
		board.slot_pos.append((r as Rect2).get_center())
	board.slot_size = (slot_rects[0] as Rect2).size.x * 0.92
	board.matched.connect(_on_match)
	board.denied.connect(_on_deny)
	board.cleared.connect(_on_clear)
	board.failed.connect(_on_fail)
	board.tray_changed.connect(_refresh)
	if mode == "" and mode != "trial":
		_place_gift()
	if fortune.get("reveal", false):
		for t in board.tiles:
			if t.secret:
				t.secret = false
				if t.back_spr:
					t.back_spr.queue_free()
					t.back_spr = null
				t.face_spr.visible = true
	V6Specials.hook(self)


func _mode_cfg(n: int) -> Dictionary:
	var shapes: = ["rect", "heart", "diamond", "butterfly", "ring", "pyramid"]
	var r: = RandomNumberGenerator.new()
	r.randomize()
	var zen: = mode == "zen"
	return {
		"name": V6Txt.s("play.blitz_name") if not zen else V6Txt.s("play.zen_name"), "code": "", "bg": ["play", "bg_teahouse", "bg_festival", "bg_palace", "bg_shrine"][n % 5] if zen else "bg_festival", 
		"fx": "petals" if zen else "lanterns", "tint": Color(1, 1, 1), "hero": partner, 
		"shape": shapes[r.randi() % shapes.size()], "cols": 5 if not zen else 6, "rows": 6 if not zen else 7, 
		"layers": 2 + mini(n, 2) if not zen else 3, "fill": 0.65, "faces": 7 + mini(n, 4) if not zen else 12, 
		"mech": "", "hard": 0, "seed": r.randi(), "gold": 2 if not zen else 0, "ice": 0, "hidden": false, 
		"reward": {"gems": 0}, "goal": V6Txt.s("play.blitz_goal") if not zen else V6Txt.s("play.zen_goal"), 
		"intro": V6Txt.s("play.blitz_intro") if not zen else V6Txt.s("play.zen_intro"), 
	}


func _place_gift() -> void :
	var cand: = board.tiles.filter( func(t): return t.shard == "" and not t.gold)
	if cand.size() < 6:
		return
	var a: Tile = cand[randi() % cand.size()]
	for t in cand:
		if t != a and t.step == a.step:
			a.gift = true
			t.gift = true
			return

func _apply_perk() -> void :
	match partner:
		"mc": hint_n += 1
		"rin": undo_n += 1
		"hana": board.combo_window = 6.5
		"yue": gold_mult = 8
		"nova":
			shuffle_n += 1
			gem_bonus = 0.1
	gem_bonus += 0.05 * (G.aff_level(partner) - 1)
	V7Album.apply_bonuses(self)
	match fortune.get("id", ""):
		"great": gem_bonus += 0.5
		"pairs": first_pairs_bonus = 3
		"wind": shuffle_n += 1
		"tea": board.combo_window += 1.5
		"tray": free_rescue_left = 1
		"small": hint_n += 1
	V7Passives.attach(self)


func _build_hud() -> void :
	Common.icon_button(self, "home", "", Rect2(12, 22, 70, 70), func(): main.go("home"))

	var gp: = UI.rbox("cream", Rect2(92, 16, W - 92 - 258, 104), 26, 4, 12)
	add_child(gp)
	var t1: = UI.label(("%s · %s" % [cfg.get("code", str(lvl + 1)), cfg.name]) if mode == "" else cfg.name, 18, Color("ffd98a"), Color(0.1, 0.05, 0.2), 3, "body", 900)
	t1.position = Vector2(16, 6)
	t1.size = Vector2(gp.size.x - 30, 26)
	t1.clip_text = true
	gp.add_child(t1)
	if int(cfg.get("hard", 0)) > 0 and mode == "":
		var hard: = int(cfg.hard)
		var ht: = UI.rbox("red" if hard == 1 else "lav", Rect2(gp.size.x - 150, -14, 140, 30), 14, 2, 6)
		if hard == 2:
			ht.colors(Color("b07cff"), Color("6a3fd0"))
		gp.add_child(ht)
		ht.add_child(UI.center_label(UI.label(G.HARD_NAMES[hard].to_upper(), 14, Color.WHITE, Color(0.2, 0.0, 0.1), 3, "body", 900), Rect2(0, 0, 140, 30)))
	var gl: = UI.label(V6Txt.s("play.goal"), 14, Color("9a6a8a"), Color.WHITE, 2, "body", 900)
	gl.position = Vector2(16, 36)
	gp.add_child(gl)
	gp.add_child(UI.tex(G.tile_tex(0), Rect2(14, 54, 44, 44)))
	tiles_lbl = UI.label("0", 26, UI.INK, Color.WHITE, 4, "body", 900)
	tiles_lbl.position = Vector2(62, 58)
	gp.add_child(tiles_lbl)
	if cfg.has("shard"):
		var sh: String = cfg.shard
		gp.add_child(Common.avatar(sh, Rect2(gp.size.x - 168, 46, 54, 54), "gold"))
		shard_lbl = UI.label("0/1", 24, Color("c58a2c"), Color.WHITE, 4, "body", 900)
		shard_lbl.position = Vector2(gp.size.x - 108, 56)
		gp.add_child(shard_lbl)
		var sl: = UI.label(V6Txt.s("play.shard"), 13, Color("9a6a8a"))
		sl.position = Vector2(gp.size.x - 108, 36)
		gp.add_child(sl)
	if mode in ["blitz", "zen"]:
		timer_lbl = UI.label("2:00" if mode == "blitz" else "∞", 26, Color("ffd98a"), UI.DARK, 4, "body", 900)
		timer_lbl.position = Vector2(gp.size.x - 170, 52)
		gp.add_child(timer_lbl)
		score_lbl = UI.label("0", 26, Color.WHITE, UI.DARK, 4, "body", 900)
		score_lbl.position = Vector2(gp.size.x - 90, 52)
		gp.add_child(score_lbl)

	SKILL_NEED = V6Heroines.skill_need(partner)
	skill_charge = mini(V6Heroines.start_charge(partner), SKILL_NEED - 1)
	var stage_w: = 242.0 if _slot_count() <= 4 else 186.0
	if mode == "duel":
		stage = V6HeroStage.new().setup(partner, Rect2(98, 22, 92, 92), {"compact": true})
	else:
		stage = V6HeroStage.new().setup(partner, Rect2(W - stage_w - 8, 66, stage_w, 240), {"tag": V6Heroines.bond_text(partner)})
	add_child(stage)
	stage.pressed.connect( func():
		if skill_ready and board.input_on:
			_use_skill()
		else:
			_speak("aff"))
	portrait = stage


	var gem: = UI.rbox("plum", Rect2(14, 132, 112, 44), 22, 2, 8)
	gem.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	add_child(gem)
	gem.add_child(UI.tex(G.icon("gem"), Rect2(4, 4, 36, 36)))
	gems_lbl = UI.label(UI.fmt(G.S.gems), 19, Color.WHITE, Color(0.2, 0.05, 0.2), 3, "body", 900)
	gems_lbl.position = Vector2(46, 0)
	gems_lbl.size = Vector2(60, 44)
	gems_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gems_lbl.pivot_offset = Vector2(30, 22)
	gem.add_child(gems_lbl)

	var ns: = _slot_count()
	var gap: = 10.0
	var tray_room: = W - 12 - (stage_w + 16 if mode != "duel" else 258.0)
	var sw: = minf(108.0, (tray_room - 28 - (ns - 1) * gap) / ns)
	var tw: = ns * sw + (ns - 1) * gap + 28
	tray_box = UI.rbox("plum", Rect2(12 + (tray_room - tw) * 0.5, 172, tw, 128), 28, 4, 12)
	tray_box.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	V6HudStyle.tray(tray_box, V7Album.table_for(cfg.get("bg", "")))
	add_child(tray_box)
	slot_rects.clear()
	for i in ns:
		var r: = Rect2(14 + i * (sw + gap), 10, sw, 108)
		var sl: = UI.rbox("plum", r, 18, 2, 4)
		sl.colors(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.22)).set_param("shadow_color", Color(0, 0, 0, 0))
		sl.borders(Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.25))
		V6HudStyle.slot(sl, i)
		tray_box.add_child(sl)
		slot_rects.append(Rect2(tray_box.position + r.position, r.size))

	var mb: = Control.new()
	mb.position = Vector2(tray_box.position.x, 296)
	add_child(mb)
	combo_lbl = UI.label("", 18, Color("ffe7a6"), Color(0.25, 0.05, 0.2), 4, "body", 900)
	combo_lbl.position = Vector2(0, -6)
	combo_lbl.size = Vector2(150, 26)
	combo_lbl.pivot_offset = Vector2(40, 13)
	mb.add_child(combo_lbl)
	var bar_bg: = UI.rbox("plum", Rect2(140, 0, tw - 140, 16), 8, 1, 2)
	bar_bg.colors(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.25)).set_param("shadow_color", Color(0, 0, 0, 0))
	mb.add_child(bar_bg)
	meter_w = bar_bg.size.x - 4
	meter = UI.rbox("gold", Rect2(2, 2, 12, 12), 6, 0, 2)
	meter.colors(Color("f3d38c"), Color("c98597")).set_param("shadow_color", Color(0, 0, 0, 0))
	bar_bg.add_child(meter)
	mb.visible = false

func _build_bottom() -> void :
	var xs: = [W * 0.5 - 200, W * 0.5 - 56, W * 0.5 + 88]
	btn_undo = _action("undo", V6Txt.s("play.undo"), xs[0], "rose")
	btn_undo.pressed.connect(_undo)
	btn_hint = _action("hint", V6Txt.s("play.hint"), xs[1], "gold")
	btn_hint.pressed.connect(_hint)
	btn_shuffle = _action("shuffle", V6Txt.s("play.shuffle"), xs[2], "mint")
	btn_shuffle.pressed.connect(_shuffle)

func _action(icon: String, text: String, x: float, pal: String) -> JButton:

	var b: = JButton.make("", "graphite", Rect2(x, H - 172, 112, 112), null, 20, 56)
	b.box.set_param("border", 4.0).set_param("gloss", 0.1)
	b.add_child(UI.tex(G.icon(icon), Rect2(26, 22, 60, 60)))
	var cap: = UI.center_label(UI.label(text, 16, UI.INK, UI.DARK, 4, "body", 900), Rect2(-20, 110, 152, 30))
	cap.name = "Cap"
	cap.set_meta("base", text)
	b.add_child(cap)
	add_child(b)
	return b

func _set_badge(b: JButton, n: int) -> void :
	var cap: Label = b.get_node("Cap")
	cap.text = "%s · %d" % [cap.get_meta("base"), n] if n > 0 else V6Txt.s("play.price") % cap.get_meta("base")

func _refresh() -> void :
	tiles_lbl.text = str(board.board_count())
	if stage:
		stage.set_charge(SKILL_NEED if skill_ready else skill_charge, SKILL_NEED)
	gems_lbl.text = UI.fmt(G.S.gems)
	if shard_lbl:
		shard_lbl.text = "%d/1" % shards_found
	_set_badge(btn_hint, hint_n)
	_set_badge(btn_undo, undo_n)
	_set_badge(btn_shuffle, shuffle_n)

	for b in [btn_hint, btn_undo, btn_shuffle]:
		b.modulate = Color(0.55, 0.5, 0.6, 0.8) if riichi else Color.WHITE
	_check_riichi()
	var danger: = board.tray.size() >= maxi(3, board.slots - 1)
	if danger and not _v6_danger and stage:
		stage.react("danger")
		if talk_cd <= 0.0:
			talk_cd = 4.0
			stage.say("tray_warn")
	_v6_danger = danger
	tray_box.borders(Color("ff8a9a") if danger else Color("ffe7a6"), Color("e8455f") if danger else Color("c58a2c"))

func _intro() -> void :
	var rib: = Common.ribbon(self, (V6Txt.s("play.ribbon") % cfg.get("code", "")) if mode == "" else cfg.name, Rect2(W * 0.5 - 230, H * 0.4, 460, 92), "pink", 42 if mode == "" else 30)
	rib.pivot_offset = rib.size * 0.5
	var sub: = UI.center_label(UI.label(cfg.get("goal", V6Txt.s("play.goal_clear")), 22, Color.WHITE, Color("7a2346"), 6, "body", 900), Rect2(-40, 92, 540, 40))
	rib.add_child(sub)
	UI.pop_in(rib, 0.1, 0.3)
	Sfx.play("combo", 0.8)
	var t: Tween = rib.create_tween()
	t.tween_interval(1.5)
	t.tween_property(rib, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(rib, "scale", Vector2(1.3, 1.3), 0.3)
	t.tween_callback(rib.queue_free)
	board.visible = false
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree():
		return
	if mode == "" and cfg.get("boss", false):
		await V6BossIntro.run(self, cfg)
		if not is_inside_tree():
			return
	if not fortune.is_empty():
		await _show_fortune()
		if not is_inside_tree():
			return
	board.visible = true
	board.deal()
	await get_tree().create_timer(0.6).timeout
	_tip(cfg.intro)
	Sfx.say(partner, "greet")
	UI.punch(portrait, 0.15)
	start_t = G.time
	if tut:
		await get_tree().create_timer(1.4).timeout
		_tutorial()


func _tip(text: String) -> void :
	var tc: = UI.rbox("cream", Rect2(20, H - 178, W - 40, 104), 24, 3, 10)
	tc.add_to_group("v6_tip")
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc.z_index = 35
	tc.set_param("border_top", Color("e8c9a0")).set_param("border_bottom", Color("a8697a"))
	add_child(tc)
	tc.add_child(Common.avatar("mc", Rect2(8, 8, 84, 84), "gold"))
	var nm: = UI.label(V6Txt.s("play.perk_tip") % [G.HEROES[partner].name, G.PERKS[partner]], 15, Color("b8406c"), Color.WHITE, 3, "body", 900)
	nm.position = Vector2(102, 8)
	nm.size = Vector2(W - 170, 22)
	nm.clip_text = true
	tc.add_child(nm)
	var l: = UI.label(text, 18, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 170, 0)
	l.position = Vector2(102, 32)
	l.size = Vector2(W - 170, 64)
	tc.add_child(l)
	UI.slide_in(tc, Vector2(0, 40), 0.0, 0.35)
	var t: Tween = tc.create_tween()
	t.tween_interval(3.5)
	t.tween_property(tc, "modulate:a", 0.0, 0.4)
	t.tween_callback(tc.queue_free)


func _tutorial() -> void :
	var f: = Sprite2D.new()
	f.texture = G.fx("finger")
	f.z_index = 60
	f.modulate = Color(1, 0.55, 0.7)
	add_child(f)
	var arrow: = Node2D.new()
	f.add_child(arrow)
	var ao: = Polygon2D.new()
	ao.polygon = PackedVector2Array([Vector2(-26, -96), Vector2(26, -96), Vector2(26, -70), Vector2(44, -70), Vector2(0, -30), Vector2(-44, -70), Vector2(-26, -70)])
	ao.color = Color.WHITE
	arrow.add_child(ao)
	var ai: = Polygon2D.new()
	ai.polygon = PackedVector2Array([Vector2(-19, -90), Vector2(19, -90), Vector2(19, -64), Vector2(32, -64), Vector2(0, -38), Vector2(-32, -64), Vector2(-19, -64)])
	ai.color = Color("f2799f")
	arrow.add_child(ai)
	var at: Tween = arrow.create_tween().set_loops()
	at.tween_property(arrow, "position:y", -14.0, 0.35).set_trans(Tween.TRANS_SINE)
	at.tween_property(arrow, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	var moves: = 0
	while is_inside_tree() and moves < 4 and board.input_on:
		var target: = board.best_move()
		if target == null:
			break
		var n0: = board.history.size() + board.tiles.filter( func(t): return not t.alive).size()
		f.position = target.get_global_transform_with_canvas().origin
		f.scale = Vector2(1.6, 1.6)
		while is_inside_tree() and board.history.size() + board.tiles.filter( func(t): return not t.alive).size() == n0:
			await get_tree().create_timer(0.1).timeout
		moves += 1
	f.queue_free()
	G.S.tut_done = true

func _bubble(text: String) -> void :
	stage.say_text(text)

func _speak(kind: String) -> void :
	stage.react("smug")
	stage.say(kind)

func now() -> float:
	return G.time

func _process(dt: float) -> void :
	talk_cd -= dt
	if mode == "blitz" and board and board.input_on and blitz_left > 0.0:
		blitz_left -= dt
		timer_lbl.text = "%d:%02d" % [int(blitz_left) / 60, int(blitz_left) % 60]
		if blitz_left <= 0.0:
			_blitz_end()
	if score_lbl:
		score_lbl.text = str(blitz_score) if mode == "blitz" else V6Txt.s("play.pairs") % blitz_score
	var fever: = now() < fever_until
	if fever:
		charge = (fever_until - now()) / 8.0
	else:
		charge = max(0.0, charge - dt * 0.05)
	meter.size.x = max(12.0, meter_w * clamp(charge, 0.0, 1.0))
	meter.set_param("glow", 1.0 if fever else 0.0)
	if now() - board.last_match > board.combo_window and board.combo > 0:
		combo_lbl.text = ""

func _on_match(mid: Vector2, combo: int, gold: bool, shard: String) -> void :
	var fever: = now() < fever_until
	var mult: = 1 + (combo - 1) / 2
	var gain: = int(round(mult * (2 if fever else 1) * (gold_mult if gold else 1) * (1.0 + gem_bonus)))
	if first_pairs_bonus > 0:
		first_pairs_bonus -= 1
		gain *= 3
	if mode == "trial":
		gain = 0
	if mode == "blitz":
		var pts: = 10 * maxi(1, combo)
		blitz_score += pts
		Fx.float_text(fx_layer, mid + Vector2(0, -10), "+%d" % pts, Color("9fe8d0"), 30)
	elif mode == "zen":
		blitz_score += 1
	if not skill_ready:
		skill_charge += 1
		if skill_charge >= SKILL_NEED:
			_skill_ready()
	G.S.gems += gain
	gained += gain
	G.add_aff(partner, 1)
	G.task_add("pairs")
	max_combo = maxi(max_combo, combo)
	last_combo = combo
	if gold:
		gold_got += 1
	if shard == "":
		_track_set(mid)
	if board.last_gift:
		board.last_gift = false
		_open_gift(mid)
	if combo == 5:
		G.task_add("combo5")
	Fx.flash_glow(fx_layer, mid, Color(1, 0.95, 0.8), 2.4, 0.35)
	Fx.ring(fx_layer, mid, Color(1, 0.85, 0.5), 1.4)
	Fx.burst(fx_layer, mid, "sparkle", 16 + combo * 4, Color(1, 0.9, 0.55) if not gold else Color(1, 0.8, 0.2), 1.0 + combo * 0.1)
	Fx.burst(fx_layer, mid, "petal", 8 + combo * 2)
	Fx.float_text(fx_layer, mid + Vector2(0, 40), "+%d" % gain, Color("fff3c4") if not gold else Color("ffd34d"), 34 if not gold else 44)
	UI.punch(gems_lbl, 0.25)
	if shard != "":
		_shard_found(shard, mid)
	if combo >= 2:
		charge = min(1.0, charge + 0.12 * combo)
		combo_lbl.text = V6Txt.s("play.combo") % combo
		Sfx.play("select", 1.0 + combo * 0.08, -6)
		UI.punch(combo_lbl, 0.35)
		var tiers: = ["", "", "Дуэт", "Трио", "Каскад", "Цветение", "Небесный поток"]
		if combo in [3, 5, 8, 12, 16] or (combo >= 20 and combo % 5 == 0):
			_combo_banner("%s ×%d" % [V7Combo.TIERS.filter( func(x): return combo >= int(x[0])).back()[1], combo], combo)
		if combo >= 3:
			Sfx.play("combo", 1.0 + combo * 0.03)
		if cfg.fx == "lanterns":
			for i in min(combo, 4):
				Fx.burst(fx_layer, Vector2(randf_range(80, W - 80), randf_range(380, 700)), "firework", 50, Color.from_hsv(randf(), 0.6, 1.0), 1.0)
			Sfx.play("sparkle", 0.8)
	else:
		charge = min(1.0, charge + 0.06)
	if combo >= 5 and not fever and not fever_pending:
		if combo == 5 and G.S.get("cutins", true) and not G.S.get("modest", false):
			_cutin()
		_fever()
	elif talk_cd <= 0.0 and combo >= 3:
		talk_cd = 4.0
		_speak("combo")
	else:
		UI.punch(portrait, 0.08)
	stage.absorb(mid)
	stage.react("combo" if combo >= 3 else "match")
	if duel:
		duel.on_player_pair(mid)
	if v7combo:
		v7combo.on_match(mid, combo, gain)
	_refresh()

func _shard_found(h: String, mid: Vector2) -> void :
	shards_found += 1
	if mode == "":
		G.S.shards[h] = int(G.S.shards.get(h, 0)) + 1
	Sfx.play("reveal_sr")
	Fx.burst(fx_layer, mid, "sparkle", 60, Color(1, 0.85, 0.4), 1.8)
	Fx.float_text(fx_layer, mid + Vector2(0, -30), V6Txt.s("play.shard_fx") % [G.HEROES[h].name, mini(int(G.S.shards.get(h, 0)), G.SHARDS_NEED), G.SHARDS_NEED], Color("ffe7a6"), 30)
	if shard_lbl:
		UI.punch(shard_lbl, 0.4)

func _combo_banner(word: String, combo: int) -> void :
	var l: = UI.title(word, 44 + min(combo, 6) * 4, Color("fff6d8"), Color("e0457b"))
	l.size = Vector2(500, 80)
	l.position = Vector2(W * 0.5 - 250, board_rect.get_center().y - 120)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(250, 40)
	l.rotation = deg_to_rad(randf_range(-4, 4))
	l.z_index = 30
	add_child(l)
	l.scale = Vector2(2.0, 2.0)
	l.modulate.a = 0
	var t: Tween = l.create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 1.0, 0.1)
	t.tween_interval(0.35)
	t.tween_property(l, "modulate:a", 0.0, 0.25)
	t.tween_callback(l.queue_free)


func _cutin() -> void :
	stage.react("big")
	stage.say("combo")
	Fx.burst(fx_layer, stage.head_pos(), "heart", 14)

func _fever() -> void :
	fever_until = now() + 8.0
	charge = 1.0
	stage.react("big")
	Sfx.play("fever")
	var rib: = Common.ribbon(self, V6Txt.s("play.fever"), Rect2(W * 0.5 - 190, 330, 380, 76), "gold", 36)
	rib.z_index = 30
	UI.pop_in(rib, 0.0, 0.4)
	var t: Tween = rib.create_tween()
	t.tween_interval(1.0)
	t.tween_property(rib, "modulate:a", 0.0, 0.3)
	t.tween_callback(rib.queue_free)
	fever_fx = Fx.ambient(self, "embers", size)
	var m: ShaderMaterial = fever_overlay.material
	m.set_shader_parameter("pulse", 1.0)
	create_tween().tween_method( func(v): m.set_shader_parameter("vignette", v), 0.0, 0.5, 0.4)
	await get_tree().create_timer(8.0).timeout
	if not is_inside_tree():
		return
	create_tween().tween_method( func(v): m.set_shader_parameter("vignette", v), 0.5, 0.0, 0.6)
	if fever_fx:
		fever_fx.queue_free()

func _on_deny(_t: Tile) -> void :
	denies += 1
	stage.react("deny")
	if talk_cd <= 0.0:
		talk_cd = 5.0
		_bubble(V6Txt.s("play.blocked"))


func _on_fail() -> void :
	_v6_clear_tips()
	if mode == "zen" or mode == "blitz" or mode == "duel" or free_rescue_left > 0:
		if duel:
			duel.on_overflow()
		if free_rescue_left > 0 and mode == "":
			free_rescue_left -= 1
			main.toast(V6Txt.s("play.omikuji_saved"), "star")
		if mode == "blitz":
			blitz_left = maxf(0.0, blitz_left - 10.0)
			Fx.float_text(fx_layer, Vector2(W * 0.5, 260), "−10 с", Color("ff8a9a"), 36)
		Fx.shake(tray_box, 6, 0.3)
		await get_tree().create_timer(0.2).timeout
		board.return_tray(3)
		_refresh()
		return
	fails += 1
	stage.react("fail")
	Sfx.play("deny", 0.7)
	Fx.shake(tray_box, 10, 0.4)
	Sfx.say(partner, "lose")
	await get_tree().create_timer(0.5).timeout
	var p: = Common.popup(main, V6Txt.s("play.full_t"), 440, "cream", 660.0, false)
	p.add_child(Common.avatar(partner, Rect2(30, 60, 120, 120), "pink"))
	var l: = UI.label(V6Txt.s("play.full_d"), 21, UI.INK)
	l.position = Vector2(170, 70)
	p.add_child(l)
	var price: = 0 if rescue_free else 60
	var rb: = JButton.make(V6Txt.s("play.return3") + ("" if price == 0 else " · 60"), "gold", Rect2(60, 210, 540, 92), G.icon("undo") if price == 0 else G.icon("gem"), 30)
	rb.shine_every = 2.0
	rb.pressed.connect( func():
		if price > 0:
			if G.S.gems < price:
				main.toast(V6Txt.s("play.need60"), "gem")
				return
			G.S.gems -= price
		rescue_free = false
		boosters_used += 1
		if riichi:
			riichi = false
			main.toast(V6Txt.s("play.riichi_burnt"), "heart")
		Common.close_popup(p)
		board.return_tray(3)
		_refresh())
	p.add_child(rb)
	fail_retry_btn = JButton.make(V6Txt.s("play.redeal"), "pink", Rect2(60, 320, 260, 84), null, 24)
	fail_retry_btn.pressed.connect( func():
		Common.close_popup(p)
		var a: = args0.duplicate()
		a["retry"] = randi()
		main.go("play", a))
	p.add_child(fail_retry_btn)
	var hb: = JButton.make(V6Txt.s("common.to_home"), "glass", Rect2(340, 320, 260, 84), null, 28)
	hb.pressed.connect( func(): main.go("home"))
	p.add_child(hb)

func _hint() -> void :
	if not board.input_on:
		return
	if riichi:
		main.toast(V6Txt.s("play.riichi_locked"), "star")
		return
	if hint_n <= 0:
		if G.S.gems < 30:
			main.toast(V6Txt.s("play.need30"), "gem")
			return
		G.S.gems -= 30
	else:
		hint_n -= 1
	boosters_used += 1
	if board.hint():
		_bubble(Sfx.say(partner, "hint"))
	_refresh()

func _undo() -> void :
	if not board.input_on:
		return
	if riichi:
		main.toast(V6Txt.s("play.riichi_locked"), "star")
		return
	if undo_n <= 0:
		if G.S.gems < 30:
			main.toast(V6Txt.s("play.need30"), "gem")
			return
		G.S.gems -= 30
		undo_n += 1
	if board.undo():
		undo_n -= 1
		boosters_used += 1
		Sfx.play("whoosh", 1.3)
	_refresh()

func _shuffle() -> void :
	if not board.input_on:
		return
	if riichi:
		main.toast(V6Txt.s("play.riichi_locked"), "star")
		return
	if shuffle_n <= 0:
		if G.S.gems < 30:
			main.toast(V6Txt.s("play.need30"), "gem")
			return
		G.S.gems -= 30
	else:
		shuffle_n -= 1
	boosters_used += 1
	board.shuffle_board()
	_refresh()



func _show_fortune() -> void :
	var root: = Control.new()
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 50
	add_child(root)
	var cw: = 300.0
	var chh: = 420.0
	var card: = UI.rbox("gold", Rect2(W * 0.5 - cw * 0.5, H * 0.3, cw, chh), 26, 5, 14)
	card.colors(Color("3a3038"), Color("1e1a22")).borders(Color("fff0b8"), Color("b07a2a"))
	root.add_child(card)
	card.pivot_offset = Vector2(cw * 0.5, chh * 0.5)
	var back: = UI.rbox("plum", Rect2(10, 10, cw - 20, chh - 20), 20, 3, 4)
	back.colors(Color(0.42, 0.1, 0.2), Color(0.24, 0.05, 0.12)).borders(Color("ffe7a6"), Color("c58a2c"))
	card.add_child(back)
	back.add_child(UI.center_label(UI.title("おみくじ", 40, Color("ffe7a6"), Color(0.2, 0.02, 0.08)), Rect2(0, 120, cw - 20, 60)))
	back.add_child(UI.center_label(UI.label(V6Txt.s("play.omikuji_sub"), 18, Color("ffd0dc")), Rect2(0, 190, cw - 20, 30)))
	UI.pop_in(card, 0.0, 0.5)
	Sfx.play("whoosh", 0.9)
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree():
		return
	var t: = create_tween()
	t.tween_property(card, "scale:x", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback( func():
		back.queue_free()
		var lvl_l: = UI.center_label(UI.title(fortune.rank, 30, Color("f2a5bd"), Color(0.15, 0.03, 0.08)), Rect2(0, 30, cw, 50))
		card.add_child(lvl_l)
		var nm: = UI.center_label(UI.title(fortune.name, 34, Color("ffe7a6"), Color(0.2, 0.05, 0.02)), Rect2(0, 110, cw, 60))
		card.add_child(nm)
		var d: = UI.label(fortune.desc, 20, Color("f3e6dc"))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(cw - 48, 0)
		d.position = Vector2(24, 190)
		d.size = Vector2(cw - 48, 160)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(d))
	t.tween_property(card, "scale:x", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("reveal_sr", 1.15)
	await get_tree().create_timer(0.4).timeout
	Fx.burst(root, Vector2(W * 0.5, H * 0.3 + 200), "sparkle", 30, Color(1, 0.85, 0.5), 1.2)
	await get_tree().create_timer(1.7).timeout
	if not is_inside_tree():
		return

	var t2: = create_tween().set_parallel()
	t2.tween_property(card, "scale", Vector2(0.2, 0.2), 0.35).set_trans(Tween.TRANS_QUAD)
	t2.tween_property(card, "position", Vector2(60, 150) - Vector2(cw, chh) * 0.4, 0.35).set_trans(Tween.TRANS_QUAD)
	t2.tween_property(card, "modulate:a", 0.0, 0.35)
	await t2.finished
	root.queue_free()
	var chip: = UI.rbox("plum", Rect2(136, 132, 260, 44), 22, 2, 8)
	chip.add_to_group("v6_chip")
	chip.borders(Color("ffe7a6"), Color("c58a2c"))
	add_child(chip)
	chip.add_child(UI.center_label(UI.label("%s · %s" % [fortune.rank, fortune.name], 16, Color("ffe7a6"), UI.DARK, 3, "body", 900), Rect2(0, 0, 260, 44)))
	var ct: = chip.create_tween()
	ct.tween_interval(4.0)
	ct.tween_property(chip, "modulate:a", 0.0, 0.6)
	ct.tween_callback(chip.queue_free)
	UI.pop_in(chip, 0.0, 0.6)

func _skill_ready() -> void :
	skill_ready = true
	skill_charge = SKILL_NEED
	stage.set_charge(SKILL_NEED, SKILL_NEED)
	_bubble(V6Txt.s("play.skill_ready") % G.SKILLS[partner].name)
	Sfx.play("reveal_sr", 1.3, -4)

func _use_skill() -> void :
	var why: = V6Skills.blocked(self)
	if why != "":
		stage.say_text(why)
		return
	skill_ready = false
	skill_charge = 0
	_refresh()
	await V6Skills.use(self)
	if is_inside_tree():
		_refresh()


func _open_gift(mid: Vector2) -> void :
	var r: = randi() % 4
	var text: = ""
	match r:
		0:
			var g: = 40 + randi() % 41
			G.S.gems += g
			gained += g
			text = V6Txt.s("play.gift_gems") % g
		1:
			hint_n += 1
			text = V6Txt.s("play.gift_hint")
		2:
			skill_charge = SKILL_NEED - 1
			text = V6Txt.s("play.gift_skill")
		3:
			G.add_aff(partner, 15)
			text = V6Txt.s("play.gift_note") % G.HEROES[partner].name
	Sfx.play("reveal_ssr", 1.2, -2)
	Fx.burst(fx_layer, mid, "confetti", 40, Color.WHITE, 1.0)
	Fx.burst(fx_layer, mid, "heart", 10)
	main.toast(text, "gift")
	_refresh()

func _blitz_end() -> void :
	board.input_on = false
	var best: = int(G.S.get("blitz_best", 0))
	var record: = blitz_score > best
	if record:
		G.S.blitz_best = blitz_score
	var gems: = mini(150, blitz_score / 20)
	G.S.gems += gems
	G.save()
	Sfx.play("win")
	var p: = Common.popup(main, V6Txt.s("play.time_up"), 520, "cream", 660.0, false)
	p.add_child(UI.center_label(UI.title(str(blitz_score), 72, Color("ffe7a6"), Color("5a1a6a")), Rect2(0, 70, 660, 100)))
	p.add_child(UI.center_label(UI.label(V6Txt.s("play.boards") % boards_done, 22, UI.INK), Rect2(0, 170, 660, 30)))
	p.add_child(UI.center_label(UI.label(V6Txt.s("play.record_new") if record else V6Txt.s("play.record") % best, 24, Color("ffd34d") if record else Color("d9c4e6"), UI.DARK, 3, "body", 900), Rect2(0, 214, 660, 34)))
	p.add_child(UI.center_label(UI.label(V6Txt.s("common.plus_gems") % gems, 22, Color("9fe8d0")), Rect2(0, 256, 660, 30)))
	var again: = JButton.make(V6Txt.s("common.again"), "pink", Rect2(60, 330, 260, 90), null, 30)
	again.pressed.connect( func(): main.go("play", {"mode": "blitz", "partner": partner, "retry": randi()}))
	p.add_child(again)
	var home: = JButton.make(V6Txt.s("common.to_home"), "glass", Rect2(340, 330, 260, 90), null, 28)
	home.pressed.connect( func(): main.go("home"))
	p.add_child(home)



func _track_set(mid: Vector2) -> void :
	var f: int = board.last_face
	var c: = G.face_cat(f)
	if c == cat_last:
		cat_streak += 1
	else:
		cat_streak = 1
		cat_last = c
	if cat_streak == 3 and c >= 0:
		cat_streak = 0
		cat_last = -1
		sets_done.append(c)
		var nm: String = G.CATS[c][2]
		_yaku_banner(nm, V6Txt.s("play.set3") + G.CATS[c][3])
		G.S.gems += 15
		gained += 15
		Fx.float_text(fx_layer, mid + Vector2(0, -50), "+15", Color("ffd34d"), 36)

func _yaku_banner(name: String, sub: String) -> void :
	var rib: = UI.rbox("plum", Rect2(W * 0.5 - 250, 420, 500, 112), 30, 4, 12)
	rib.colors(Color(0.16, 0.08, 0.3, 0.96), Color(0.08, 0.04, 0.16, 0.96)).borders(Color("fff0b8"), Color("c58a2c"))
	rib.z_index = 32
	add_child(rib)
	var t: = UI.center_label(UI.title(name, 46, Color("ffe7a6"), Color("5a1a6a")), Rect2(0, 8, 500, 62))
	rib.add_child(t)
	rib.add_child(UI.center_label(UI.label(sub, 18, Color("e9dcff")), Rect2(0, 70, 500, 30)))
	UI.pop_in(rib, 0.0, 1.6)
	rib.shine(0.15)
	Sfx.play("reveal_sr", 1.1)
	var tw: Tween = rib.create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(rib, "modulate:a", 0.0, 0.3)
	tw.tween_callback(rib.queue_free)
	if talk_cd <= 0.0:
		talk_cd = 3.0
		UI.punch(portrait, 0.25)
		_bubble(Sfx.say(partner, "yaku"))


func _check_riichi() -> void :
	if riichi or riichi_offered or mode == "trial" or not board.input_on:
		return
	var left: = board.board_count()
	if left > 0 and left <= 16 and board.tray.is_empty() and left < board.tiles.size() * 0.6:
		riichi_offered = true
		riichi_btn = JButton.make(V6Txt.s("play.riichi"), "red", Rect2(W - 150, H - 166, 140, 92), null, 26)
		riichi_btn.set_sub(V6Txt.s("play.riichi_sub"), 15)
		riichi_btn.pulse = true
		riichi_btn.shine_every = 1.2
		riichi_btn.z_index = 40
		riichi_btn.pressed.connect(_declare_riichi)
		add_child(riichi_btn)
		UI.pop_in(riichi_btn, 0.0, 0.3)
		Sfx.play("pop", 0.8)

func _check_riichi_force() -> void :
	riichi_offered = true
	riichi_btn = JButton.make(V6Txt.s("play.riichi"), "red", Rect2(W - 150, H - 166, 140, 92), null, 26)
	riichi_btn.set_sub(V6Txt.s("play.riichi_sub"), 15)
	riichi_btn.z_index = 40
	add_child(riichi_btn)

func _declare_riichi() -> void :
	if riichi:
		return
	riichi = true
	riichi_btn.queue_free()
	riichi_btn = null
	Sfx.play("fever", 1.15)
	var rib: = Common.ribbon(self, V6Txt.s("play.riichi"), Rect2(W * 0.5 - 200, 400, 400, 96), "red", 54)
	rib.z_index = 33
	UI.pop_in(rib, 0.0, 2.0)
	var tw: Tween = rib.create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(rib, "modulate:a", 0.0, 0.3)
	tw.tween_callback(rib.queue_free)
	Fx.burst(fx_layer, Vector2(W * 0.5, 450), "sparkle", 50, Color(1, 0.5, 0.5), 1.6)
	UI.punch(portrait, 0.3)
	_bubble(Sfx.say(partner, "riichi"))
	tray_box.set_param("glow", 1.0).set_param("glow_color", Color(1, 0.35, 0.4))
	_refresh()

func _collect_yaku(secs: float) -> Array:
	var ys: = []
	if riichi:
		ys.append("riichi")
	if boosters_used == 0 and fails == 0:
		ys.append("clean")
	if board.max_tray <= 2:
		ys.append("calm")
	if denies == 0:
		ys.append("sharp")
	if secs < board.tiles.size() * 1.1:
		ys.append("swift")
	if max_combo >= 7:
		ys.append("dragon")
	if gold_total > 0 and gold_got >= gold_total:
		ys.append("goldvein")
	if last_combo >= 3:
		ys.append("finale")
	for c in sets_done:
		ys.append("set:%d" % c)
	return ys

func _yaku_name(y: String) -> String:
	if y.begins_with("set:"):
		return G.CATS[int(y.substr(4))][2]
	return G.YAKU[y].name

func _yaku_rp(y: String) -> int:
	if y.begins_with("set:"):
		return G.YAKU.set.rp
	return G.YAKU[y].rp


var yaku_list: = []
var rp_gain: = 0
var rp_before: = 0
var rank_ups: = []

func _v6_clear_tips() -> void :
	get_tree().call_group("v6_tip", "queue_free")

func _on_clear() -> void :
	_v6_clear_tips()
	get_tree().call_group("v6_chip", "queue_free")
	if duel:
		duel.finish()
		return
	if mode in ["blitz", "zen"]:
		boards_done += 1
		if mode == "blitz":
			blitz_left += 10.0
			blitz_score += 100
			Fx.float_text(fx_layer, Vector2(W * 0.5, 600), V6Txt.s("play.clear10"), Color("ffe7a6"), 40)
		else:
			G.S.gems += 30
			gained += 30
			Fx.float_text(fx_layer, Vector2(W * 0.5, 600), V6Txt.s("play.clear30"), Color("ffe7a6"), 40)
		Sfx.play("win", 1.2, -6)
		Fx.burst(fx_layer, Vector2(W * 0.5, 600), "confetti", 50, Color.WHITE, 1.0)
		await get_tree().create_timer(0.8).timeout
		if not is_inside_tree():
			return
		cfg = _mode_cfg(boards_done)
		_make_board()
		board.deal()
		_refresh()
		return
	var secs: = now() - start_t
	var stars: = 3 if fails == 0 and boosters_used == 0 else (2 if fails == 0 and boosters_used <= 2 else 1)
	if G.demo:
		stars = 3
	if riichi_btn:
		riichi_btn.queue_free()
	yaku_list = _collect_yaku(secs)
	var first: = false
	var reward: = 0
	if mode == "":
		first = G.level_stars(lvl) == 0
		G.S.stars[str(lvl)] = max(G.level_stars(lvl), stars)
		G.S.unlocked = max(int(G.S.unlocked), min(lvl + 2, G.LEVELS.size()))
		reward = cfg.reward.gems + stars * 20
		if first and cfg.reward.has("item"):
			G.give(cfg.reward.item)
		if first and lvl == 2:
			first_unlock_summon = true
			G.S.free10 = true
		if lvl >= 1:
			G.set_meta("pending_offer", true)
	elif mode == "daily":
		reward = cfg.reward.gems + stars * 20
		var dm: = G.dailymap()
		var d: = int(G.today().substr(8, 2))
		if not d in dm.done.map( func(x): return int(x)):
			dm.done.append(d)
	if riichi:
		reward = reward * 2 + gained
	if mode != "trial":
		rp_before = int(G.S.rp)
		rp_gain = 20 + stars * 5 + (int(cfg.get("hard", 0)) * 15 if mode == "" else 0)
		for y in yaku_list:
			rp_gain += _yaku_rp(y)
			if not y.begins_with("set:"):
				G.S.yaku_seen[y] = int(G.S.yaku_seen.get(y, 0)) + 1
		rank_ups = G.add_rp(rp_gain)
	if mode != "trial":
		G.add_aff(partner, 10)
		G.task_add("levels")
		G.add_pass_xp(100)
		G.S.xp = int(G.S.xp) + 40
	G.S.gems += reward
	G.S.tut_done = true
	G.save()
	await get_tree().create_timer(0.4).timeout
	_victory(stars, reward, secs, first)

func _victory(stars: int, reward: int, secs: float, first: bool) -> void :
	print("VICTORY stars=%d" % stars)
	Sfx.music("")
	Sfx.play("win")
	var root: = Control.new()
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim: = ColorRect.new()
	dim.size = size
	dim.color = Color(0.22, 0.06, 0.16, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.6, 0.4)
	var rays: = Common.rays(root, Vector2(W * 0.5, H * 0.3), 1100, Color(1, 0.9, 0.6, 0.6), 14, 0.06, 0.7)
	rays.modulate.a = 0
	rays.create_tween().tween_property(rays, "modulate:a", 1.0, 0.5)
	Fx.burst(root, Vector2(W * 0.2, H), "confetti", 70, Color.WHITE, 1.1)
	Fx.burst(root, Vector2(W * 0.8, H), "confetti", 70, Color.WHITE, 1.1)

	var vh: = Hero.new().setup(partner, 700.0)
	vh.position = Vector2(W * 0.5, H + 40)
	vh.interactive = false
	root.add_child(vh)
	UI.slide_in(vh, Vector2(0, 200), 0.2, 0.6)
	vh.react("big")

	var pw: = 600.0
	var py: = H * 0.06
	var title: = Common.ribbon(root, V6Txt.s("play.win") if not riichi else V6Txt.s("play.win_riichi"), Rect2(W * 0.5 - 260, py, 520, 104), "pink" if not riichi else "red", 56 if not riichi else 44)
	UI.pop_in(title, 0.1, 0.3)
	var card: = UI.rbox("cream", Rect2((W - pw) * 0.5, py + 130, pw, 360), 34, 5, 14)
	card.set_param("pattern", 1.0)
	root.add_child(card)
	UI.pop_in(card, 0.25, 0.7)
	var star_nodes: = []
	for i in 3:
		var s: = UI.tex(G.fx("star_empty"), Rect2(pw * 0.5 - 60 + (i - 1) * 150, 18 + (0 if i == 1 else 22), 120, 120))
		card.add_child(s)
		star_nodes.append(s)
	var tl: = UI.center_label(UI.label(V6Txt.s("play.stats") % [int(secs), boosters_used, fails], 20, UI.INK), Rect2(0, 156, pw, 30))
	card.add_child(tl)

	var rr: = UI.rbox("glass", Rect2(30, 196, pw - 60, 120), 24, 3, 8)
	card.add_child(rr)
	rr.add_child(UI.tex(G.icon("gem"), Rect2(16, 14, 90, 90)))
	var gl: = UI.label("+0", 40, Color("f2799f"), Color.WHITE, 6, "title", 900)
	gl.position = Vector2(110, 24)
	rr.add_child(gl)
	if first and cfg.reward.has("item"):
		var it: Dictionary = G.ITEM[cfg.reward.item]
		var ib: = UI.rbox("gold", Rect2(pw - 60 - 250, 10, 236, 100), 20, 3, 6)
		rr.add_child(ib)
		ib.add_child(UI.tex(G.item_tex(it), Rect2(8, 8, 84, 84)))
		var il: = UI.label(it.name, 18, Color.WHITE, Color("7a4a0c"), 4, "body", 900)
		il.position = Vector2(98, 14)
		il.size = Vector2(130, 70)
		il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ib.add_child(il)
		var nb: = UI.rbox("red", Rect2(150, -14, 80, 28), 14, 2, 4)
		ib.add_child(nb)
		nb.add_child(UI.center_label(UI.label(V6Txt.s("common.new"), 15, Color.WHITE), Rect2(0, 0, 80, 28)))
	if shards_found > 0 and cfg.has("shard"):
		var sh: String = cfg.shard
		var have: = mini(int(G.S.shards.get(sh, 0)), G.SHARDS_NEED)
		var sc: = Common.chip(card, null, V6Txt.s("play.shard_chip") % [G.HEROES[sh].name, have, G.SHARDS_NEED, V6Txt.s("play.shard_full") if have >= G.SHARDS_NEED else ""], Rect2(30, 322, pw - 60, 34), "gold", 17)
	if mode != "trial":
		var hl: = UI.label(V6Txt.s("play.aff10"), 18, Color("e0457b"), Color.WHITE, 3, "body", 900)
		hl.position = Vector2(112, 74)
		rr.add_child(hl)

	var yh: = 44.0 + maxi(1, mini(yaku_list.size(), 8)) * 30 + 104
	var yp: = _yaku_panel(root, Rect2((W - pw) * 0.5, py + 500, pw, yh))

	var by: = H - 150.0
	var next_text: = V6Txt.s("play.next") if mode == "" else (V6Txt.s("common.to_home") if mode == "daily" else V6Txt.s("play.to_banner"))
	victory_next_btn = JButton.make(next_text, "pink", Rect2(W * 0.5 - 290, by, 280, 96), null, 26)
	victory_next_btn.shine_every = 2.5
	victory_next_btn.pressed.connect( func():
		if mode == "trial":
			main.go("summon", {"banner": _banner_of(partner)})
		elif mode == "daily":
			main.go("home")
		else:
			var nx: int = min(lvl + 1, G.LEVELS.size() - 1)
			main.go("levels", {"select": nx, "pick": true}))
	root.add_child(victory_next_btn)
	var summon_ok: = G.summon_open()
	victory_summon_btn = JButton.make(V6Txt.s("play.wishes") if summon_ok else V6Txt.s("common.to_home"), "lav", Rect2(W * 0.5 + 10, by, 280, 96), G.icon("gem") if summon_ok else G.icon("home"), 30)
	victory_summon_btn.pressed.connect( func():
		if G.summon_open():
			main.go("summon", {"banner": _banner_of(partner) if mode == "trial" else 1})
		else:
			main.go("home"))
	root.add_child(victory_summon_btn)
	UI.pop_in(victory_next_btn, 0.9)
	UI.pop_in(victory_summon_btn, 1.0)
	V7Photo.victory_hook(self, root, stars, secs)

	await get_tree().create_timer(0.7).timeout
	for i in stars:
		if not is_inside_tree():
			return
		var s: TextureRect = star_nodes[i]
		s.texture = G.fx("star")
		UI.pop_in(s, 0.0, 2.2)
		Sfx.play("star%d" % i)
		Fx.burst(root, card.position + s.position + s.size * 0.5, "sparkle", 26, Color(1, 0.85, 0.4), 1.2)
		await get_tree().create_timer(0.32).timeout
	Sfx.say(partner, "win")

	var tw: = create_tween()
	tw.tween_method( func(v): gl.text = "+%d" % int(v), 0.0, float(reward + gained), 0.8)
	if reward + gained > 0:
		main.fly_gems(card.position + Vector2(80, 260), 8)
	await _animate_rank(yp)
	Sfx.music("menu")
	if first_unlock_summon:
		await get_tree().create_timer(1.6).timeout
		if is_inside_tree():
			_summon_unlocked()

func _yaku_panel(root: Control, r: Rect2) -> Control:
	var box: = UI.rbox("cream", r, 30, 4, 12)
	root.add_child(box)
	UI.pop_in(box, 0.45, 0.8)
	var hd: = UI.label(V6Txt.s("play.yaku_head"), 17, Color("ffd98a"), Color(0.1, 0.05, 0.2), 3, "body", 900)
	hd.position = Vector2(24, 12)
	box.add_child(hd)
	var shown: = yaku_list.slice(0, 8)
	for i in shown.size():
		var y: String = shown[i]
		var nm: = UI.label(_yaku_name(y), 21, Color("fff1dc"), Color(0.1, 0.05, 0.2), 3, "title", 800)
		nm.position = Vector2(24, 40 + i * 30)
		box.add_child(nm)
		var pts: = UI.label("+%d" % _yaku_rp(y), 20, Color("ffd34d"), Color(0.1, 0.05, 0.2), 3, "body", 900)
		pts.position = Vector2(r.size.x - 90, 42 + i * 30)
		box.add_child(pts)
		nm.modulate.a = 0
		pts.modulate.a = 0
		var tw: Tween = nm.create_tween()
		tw.tween_interval(1.4 + i * 0.22)
		tw.tween_property(nm, "modulate:a", 1.0, 0.15)
		tw.parallel().tween_property(pts, "modulate:a", 1.0, 0.15)
		tw.tween_callback( func(): Sfx.play("star%d" % mini(i, 2), 1.2, -6))
	if shown.is_empty():
		var nl: = UI.label(V6Txt.s("play.no_yaku"), 18, Color("d9c4e6"))
		nl.position = Vector2(24, 44)
		box.add_child(nl)
	var by: = r.size.y - 92
	var info: = G.rank_of(rp_before)
	var em: = Common.rank_emblem(box, Rect2(18, by, 76, 76), info.tier, info.sub)
	em.name = "Em"
	var tl: = UI.label(info.title, 22, Color("fff1dc"), Color(0.1, 0.05, 0.2), 3, "body", 900)
	tl.name = "T"
	tl.position = Vector2(106, by + 2)
	box.add_child(tl)
	var gl: = UI.label(V6Txt.s("play.rp_gain") % rp_gain, 20, Color("ffd34d"), Color(0.1, 0.05, 0.2), 3, "body", 900)
	gl.position = Vector2(r.size.x - 130, by + 4)
	box.add_child(gl)
	var bar: = Common.progress_bar(box, Rect2(106, by + 40, r.size.x - 130, 20), float(info.into) / info.need, "gold")
	box.set_meta("bar", bar)
	box.set_meta("bar_w", r.size.x - 130 - 6)
	box.set_meta("by", by)
	return box

func _animate_rank(box: Control) -> void :
	if not is_inside_tree() or mode == "trial":
		return
	await get_tree().create_timer(0.3 + yaku_list.size() * 0.22).timeout
	if not is_inside_tree():
		return
	var info: = G.rank_of(int(G.S.rp))
	var fill: Control = box.get_meta("bar")
	if rank_ups.size() > 0:
		var up: Dictionary = rank_ups[-1]
		var em: Control = box.get_node("Em")
		var by: float = box.get_meta("by")
		em.queue_free()
		var em2: = Common.rank_emblem(box, Rect2(18, by, 76, 76), info.tier, info.sub)
		UI.pop_in(em2, 0.0, 2.0)
		(box.get_node("T") as Label).text = info.title
		Sfx.play("reveal_ssr" if up.sub == 0 else "reveal_sr")
		Fx.burst(box, Vector2(56, by + 38), "sparkle", 40, G.RANKS[info.tier].color, 1.4)
		var gems: = 0
		for u in rank_ups:
			gems += int(u.gems)
		main.toast(V6Txt.s("play.rankup") % [info.title, gems], "trophy")
		Sfx.say(partner, "rankup")
	if fill:
		var w: float = maxf(14.0, float(box.get_meta("bar_w")) * clampf(float(info.into) / info.need, 0.0, 1.0))
		fill.create_tween().tween_property(fill, "size:x", w, 0.6).set_trans(Tween.TRANS_QUAD)

func _banner_of(h: String) -> int:
	for i in G.BANNERS.size():
		if G.BANNERS[i].hero == h and not G.BANNERS[i].get("newbie", false):
			return i
	return 1

var unlock_go_btn: JButton


func _summon_unlocked() -> void :
	main.refresh_nav()
	var p: = Common.popup(main, V6Txt.s("play.unlock_t"), 560, "lav")
	var art: = Common.card_art(load("res://assets/bg/summon.webp"), Rect2(30, 60, 600, 260), Vector2(0.5, 0.4), 1.0, 22)
	p.add_child(art)
	Common.rays(p, Vector2(330, 190), 700, Color(1, 0.9, 0.6, 0.6), 12, 0.05, 0.7)
	var t: = UI.center_label(UI.title(V6Txt.s("play.unlock_name"), 40, Color.WHITE, Color("3f2a7a")), Rect2(0, 230, 660, 60))
	p.add_child(t)
	var s: = UI.center_label(UI.label(V6Txt.s("play.unlock_d"), 19, Color("3f2a7a")), Rect2(0, 330, 660, 30))
	p.add_child(s)
	Sfx.play("reveal_sr")
	Fx.burst(p, Vector2(330, 190), "sparkle", 60, Color(1, 0.85, 0.5), 1.6)
	unlock_go_btn = JButton.make(V6Txt.s("play.unlock_go"), "gold", Rect2(130, 410, 400, 100), G.icon("gem"), 36)
	unlock_go_btn.shine_every = 1.6
	unlock_go_btn.pulse = true
	unlock_go_btn.pressed.connect( func(): main.go("summon", {"banner": 1}))
	p.add_child(unlock_go_btn)

func dev_act(a: String) -> void :
	match a:
		"match":
			for i in 2:
				var t: = board.best_move()
				if t:
					board.tap(t)
				await get_tree().create_timer(0.3).timeout
		"three":
			var fr: = board.free_tiles()
			var used: = {}
			for t in fr:
				if not used.has(t.face) and board.tray.size() < 3:
					used[t.face] = true
					board.tap(t)
		"fail":
			_on_fail()
		"yaku":
			riichi = true
			sets_done = [0, 2]
			max_combo = 7
			last_combo = 4
			G.S.rp = 170
			for t in board.tiles:
				t.alive = false
				t.hide()
			_on_clear()
		"skill":
			skill_charge = SKILL_NEED
			_skill_ready()
		"useskill":
			_use_skill()
		"rapid":
			var fr: = board.free_tiles()
			var used: = {}
			var n: = 0
			for t in fr:
				if not used.has(t.face) and n < 3:
					used[t.face] = true
					n += 1
					board.tap(t)
					await get_tree().create_timer(0.06).timeout
		"riichi":
			riichi_offered = false
			board.tray.clear()
			_check_riichi_force()
		"clear":
			for t in board.tiles:
				t.alive = false
				t.hide()
			_on_clear()
		"fever":
			_fever()
		"cutin":
			_cutin()
