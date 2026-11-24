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
# 0.9 Ultimate (scripts/v09/ult/ult_cast.gd); v9_from_ult is true while an ult removes a pair (its matched signal)
var ult: V9UltCast
var v9_from_ult: = false

func build(m, args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	args0 = args
	main.show_chrome(false, false)
	# 0.8 art (V8Art) is drawn far below its source size: every TextureRect / Sprite2D of the match inherits
	# mipmapped sampling from here (textures without mipmaps simply sample linear as before)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	# 0.9: no full-screen fever vignette — it pulsed over the board at every fx level; V7Combo's burning table
	# frame (outside the tiles, gated by S.fx_level) carries the fever now
	_build_bottom()
	if mode == "duel":
		duel = V6Duel.new()
		add_child(duel)
		duel.setup(self, _v6_rival(args0))
	_refresh()
	_intro()
	_v8_dev()
	_v9_dev()


# dev: --v8_win=1 opens the victory window as soon as the table is playable (for screenshots),
# --v8_rankup=1 puts the rank 5 points below the next step first. Dev runs save to a separate file.
func _v8_dev() -> void :
	var ua: = OS.get_cmdline_user_args()
	if "--v8_devsave=1" in ua or "--v8_win=1" in ua or "--v8_hintpay=1" in ua:
		G.save_path = "user://dev_v8_play.json"
	if not ("--v8_win=1" in ua or "--v8_hintpay=1" in ua):
		return
	for a in ua:
		if a.begins_with("--v8_rp="):
			G.S.rp = int(a.substr(8))
	if "--v8_rankup=1" in ua:
		var r: = G.rank_of(int(G.S.rp))
		G.S.rp = int(G.S.rp) + int(r.need) - int(r.into) - 5
	while is_inside_tree() and not board.input_on:
		await get_tree().create_timer(0.05).timeout
	if not is_inside_tree():
		return
	if "--v8_hintpay=1" in ua:
		hint_n = 0
		await get_tree().create_timer(0.3).timeout
		_hint()
		return
	if "--v8_yaku=1" in ua:
		riichi = true
		sets_done = [0, 2]
		max_combo = 7
		last_combo = 4
	for t in board.tiles:
		t.alive = false
		t.hide()
	_on_clear()


func _v6_rival(args: Dictionary) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rival="):
			return a.substr(8)
	return String(args.get("rival", "rin"))


func _v6_setup(_args: Dictionary) -> bool:
	return false

func _slot_count() -> int:
	return V7Passives.slots(partner, 6 if mode == "zen" else 4)

# a Node2D right under the board (above the backdrop and the table felt): decor that must stay behind the tiles
func _v9_under_board_fx() -> Node2D:
	var n: Node2D = get_node_or_null("V9UnderBoardFx")
	if n == null:
		n = Node2D.new()
		n.name = "V9UnderBoardFx"
		add_child(n)
	if board and is_instance_valid(board) and n.get_index() > board.get_index():
		move_child(n, board.get_index())
	return n

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
	# 0.10 M0: the board reads slot_pos in global coordinates (tile_layer.to_local) and the screen sits in the
	# content column, not at the viewport origin (tablets, cut-outs): convert, or tray tiles land off their slots
	for r in slot_rects:
		board.slot_pos.append(get_global_transform() * (r as Rect2).get_center())
	board.slot_size = (slot_rects[0] as Rect2).size.x * 0.92
	# matched gives a viewport point; _on_match (and its overrides) draw in this screen's own coordinates
	board.matched.connect( func(mid: Vector2, combo: int, gold: bool, shard: String): _on_match(V10Layout.local_of(self, mid), combo, gold, shard))
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
	_v8_round_btn(V8Art.nav("home"), Rect2(12, 22, 70, 70), 0.62, func(): main.leave_match())

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
		ht.add_child(UI.center_label(UI.label(G.HARD_NAMES[hard].to_upper(), 16, Color.WHITE, Color(0.2, 0.0, 0.1), 3, "body", 900), Rect2(0, 0, 140, 30)))
	var gl: = UI.label(V6Txt.s("play.goal"), 16, Color("9a6a8a"), Color.WHITE, 2, "body", 900)
	gl.position = Vector2(16, 32)
	gp.add_child(gl)
	gp.add_child(UI.tex(G.tile_tex(0), Rect2(14, 58, 40, 40)))
	tiles_lbl = UI.label("0", 26, UI.INK, Color.WHITE, 4, "body", 900)
	tiles_lbl.position = Vector2(60, 60)
	gp.add_child(tiles_lbl)
	if cfg.has("shard"):
		var sh: String = cfg.shard
		gp.add_child(Common.avatar(sh, Rect2(gp.size.x - 168, 46, 54, 54), "gold"))
		shard_lbl = UI.label("0/1", 24, Color("c58a2c"), Color.WHITE, 4, "body", 900)
		shard_lbl.position = Vector2(gp.size.x - 108, 56)
		gp.add_child(shard_lbl)
		var sl: = UI.label(V6Txt.s("play.shard"), 16, Color("9a6a8a"), Color.WHITE, 2, "body", 900)
		sl.position = Vector2(gp.size.x - 108, 32)
		gp.add_child(sl)
	if mode in ["blitz", "zen"]:
		timer_lbl = UI.label("2:00" if mode == "blitz" else "∞", 26, Color("ffd98a"), UI.DARK, 4, "body", 900)
		timer_lbl.position = Vector2(gp.size.x - 170, 52)
		gp.add_child(timer_lbl)
		score_lbl = UI.label("0", 26, Color.WHITE, UI.DARK, 4, "body", 900)
		score_lbl.position = Vector2(gp.size.x - 90, 52)
		gp.add_child(score_lbl)

	# 0.9: the skill meter is the Ultimate: need / start charge from V9Ults (ranked: 6, start 0)
	ult = V9UltCast.new().setup(self)
	add_child(ult)
	SKILL_NEED = ult.need()
	skill_charge = ult.start_charge()
	var stage_w: = 242.0 if _slot_count() <= 4 else 186.0
	if mode == "duel":
		stage = V6HeroStage.new().setup(partner, Rect2(98, 22, 92, 92), {"compact": true})
	else:
		# 0.8: only «Симпатия N» on the stage tag — the skill threshold is on the «умение 0/N» bar, and the long
		# bond_text («… · умение за 7 пар · наряд +N») ran past the right screen edge
		stage = V6HeroStage.new().setup(partner, Rect2(W - stage_w - 8, 66, stage_w, 240), {"tag": "Симпатия %d" % G.aff_level(partner)})
	add_child(stage)
	if ult.mod != "":
		stage.set_ult_badge(ult.mod, G.HEROES[partner].color, String(V9Ults.MODS[ult.mod].desc))
	stage.pressed.connect( func():
		# 0.9: every portrait tap is answered. Busy (a cast running) or ready-but-the-board-is-busy (deal, fail
		# delay, clear) is a deny — never silence and never a chat that hides the ready glow. A talk tap gets the
		# press; the bubble has its own cooldown so mashing does not stack lines.
		if ult.busy:
			V9Feel.deny(stage)
			return
		if skill_ready and not board.input_on:
			# ready, but the table is busy (deal, a fail beat, a clear): the deny and a short line that says why,
			# so the glow does not read as broken
			V9Feel.deny(stage)
			_speak_wait()
			return
		if skill_ready:
			_use_skill()
		else:
			V9Feel.press(stage, "pop", "tap")
			_speak("aff", true))
	portrait = stage


	var gem: = UI.rbox("plum", Rect2(14, 132, 112, 44), 22, 2, 8)
	gem.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	add_child(gem)
	gem.add_child(V8Art.rect(V8Art.cur("gem"), Rect2(2, 2, 40, 40)))
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
	# 0.8: sound (84) + undo / hint / shuffle (112 each) are one row centred under the board with equal 50 px gaps,
	# so the left and right margins match (was 25 px left, 160 px right)
	var gap: = 50.0
	var x0: = (W - (84.0 + 3.0 * 112.0 + 3.0 * gap)) * 0.5
	var xs: = [x0 + 84.0 + gap, x0 + 84.0 + 112.0 + 2.0 * gap, x0 + 84.0 + 224.0 + 3.0 * gap]
	btn_undo = _action("undo", V6Txt.s("play.undo"), xs[0], "rose")
	btn_undo.pressed.connect(_undo)
	btn_hint = _action("hint", V6Txt.s("play.hint"), xs[1], "gold")
	btn_hint.pressed.connect(_hint)
	btn_shuffle = _action("shuffle", V6Txt.s("play.shuffle"), xs[2], "mint")
	btn_shuffle.pressed.connect(_shuffle)
	# 0.9: a help tap that would be refused answers with the deny alone (JButton gate), then the handler says why
	btn_undo.set_gate( func(): return _help_ok("undo"), _undo)
	btn_hint.set_gate( func(): return _help_ok("hint"), _hint)
	btn_shuffle.set_gate( func(): return _help_ok("shuffle"), _shuffle)
	# (riichi disables them; a tap then reaches the same handlers through `denied`, which say «заблокировано»)
	# 0.8: sound on / off right in the match (icon/sound, icon/sound_off), bottom left beside the helps
	btn_sound = _v8_round_btn(V8Art.icon("sound" if _v8_sound_on() else "sound_off"), Rect2(x0, H - 158, 84, 84), 0.6, _v8_toggle_sound)

func _action(icon: String, text: String, x: float, pal: String) -> JButton:

	var b: = JButton.make("", "graphite", Rect2(x, H - 172, 112, 112), null, 20, 56)
	b.box.set_param("border", 4.0).set_param("gloss", 0.1)
	# 0.8: the bare gold glyphs of the art set (icon/undo, hint, shuffle: 160 px drawn at 64)
	var ic: = V8Art.rect(V8Art.icon(icon), Rect2(24, 20, 64, 64))
	ic.name = "Icon"
	b.add_child(ic)
	var cap: = UI.center_label(UI.label(text, 16, UI.INK, UI.DARK, 4, "body", 900), Rect2(-20, 110, 152, 30))
	cap.name = "Cap"
	cap.set_meta("base", text)
	b.add_child(cap)
	add_child(b)
	return b

# a round graphite button with one 0.8 glyph (home, sound): `k` is the glyph's share of the button
func _v8_round_btn(t: Texture2D, r: Rect2, k: float, cb: Callable) -> JButton:
	var b: = JButton.make("", "graphite", r, null, 20, r.size.y * 0.5)
	b.box.set_param("border", 3.0).set_param("gloss", 0.1)
	var d: = r.size.x * k
	var ic: = V8Art.rect(t, Rect2((r.size - Vector2(d, d)) * 0.5, Vector2(d, d)))
	ic.name = "Icon"
	b.add_child(ic)
	b.pressed.connect(cb)
	add_child(b)
	return b

var btn_sound: JButton

func _v8_sound_on() -> bool:
	return bool(G.S.get("sound", true)) or bool(G.S.get("music", true))

func _v8_toggle_sound() -> void :
	var on: = not _v8_sound_on()
	G.S.sound = on
	G.S.music = on
	G.save()
	if on:
		Sfx.cur_music = ""
		Sfx.music("play" if mode != "zen" else "menu")
	else:
		Sfx.music("")
	if btn_sound and is_instance_valid(btn_sound):
		(btn_sound.get_node("Icon") as TextureRect).texture = V8Art.icon("sound" if on else "sound_off")

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

	# 0.9: riichi locks the helps for real (JButton dims them and answers a tap with a deny; `denied` says why)
	for b in [btn_hint, btn_undo, btn_shuffle]:
		if b.disabled != riichi:
			b.disabled = riichi
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
	# 0.8: hold the «v6_tip» slot until the intro tip is shown, so a specials card never comes first and
	# then gets the intro tip drawn over it
	var hold: = Control.new()
	hold.visible = false
	hold.add_to_group("v6_tip")
	add_child(hold)
	# 0.8: the level ribbon is shown over the tray, which is still empty at the start. It never covers
	# a tile row and never takes a tap (mouse_filter IGNORE). It is gone before the luck strip uses the same place.
	var tr_: = Rect2(tray_box.position, tray_box.size)
	var rib_txt: String = (V6Txt.s("play.ribbon") % cfg.get("code", "")) if mode == "" else String(cfg.name)
	var rib_fs: = 40 if mode == "" else 30
	while rib_fs > 24 and UI.font("title", 900).get_string_size(rib_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, rib_fs).x > tr_.size.x - 60.0:
		rib_fs -= 2
	var rib: = Common.ribbon(self, rib_txt, Rect2(tr_.position.x + 6, tr_.position.y + 6, tr_.size.x - 12, 72), "pink", rib_fs)
	rib.name = "V8LevelRibbon"
	rib.z_index = 210
	rib.pivot_offset = rib.size * 0.5
	var goal_t: String = cfg.get("goal", V6Txt.s("play.goal_clear"))
	var gfs: = 20
	while gfs > 16 and UI.font("body", 900).get_string_size(goal_t, HORIZONTAL_ALIGNMENT_LEFT, -1, gfs).x > tr_.size.x - 12.0:
		gfs -= 1
	var sub: = UI.center_label(UI.label(goal_t, gfs, Color.WHITE, Color("3a1424"), 6, "body", 900), Rect2(-6, 74, tr_.size.x, 40))
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.clip_text = true
	rib.add_child(sub)
	_v8_ignore(rib)
	UI.pop_in(rib, 0.1, 0.5)
	Sfx.play("combo", 0.8)
	var t: Tween = rib.create_tween()
	t.tween_interval(1.1)
	t.tween_property(rib, "modulate:a", 0.0, 0.25)
	t.tween_callback(rib.queue_free)
	board.visible = false
	var boss: bool = mode == "" and cfg.get("boss", false)
	# 0.8: with a luck card (every story level after the tutorial, e.g. 1-6) the table is dealt at once
	# and is playable in under a second; the omikuji shows as a small strip that does not block the board.
	var quick: = not fortune.is_empty() and not boss
	await get_tree().create_timer(0.1 if quick else 1.1).timeout
	if not is_inside_tree():
		return
	if boss:
		await V6BossIntro.run(self, cfg)
		if not is_inside_tree():
			return
	board.visible = true
	if not fortune.is_empty():
		_v8_quick_deal()
	else:
		board.deal()
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	Sfx.say(partner, "greet")
	UI.punch(portrait, 0.15)
	start_t = G.time
	# 0.8: one overlay at a time — level banner, then the luck strip, then the intro tip
	if not fortune.is_empty():
		await get_tree().create_timer(0.9).timeout
		if not is_inside_tree() or _v8_over:
			return
		_show_fortune()
		await get_tree().create_timer(V8_FORTUNE_SECS + 0.35).timeout
		if not is_inside_tree() or _v8_over:
			return
	if is_instance_valid(hold):
		hold.queue_free()
	_tip(cfg.intro)
	if tut:
		await get_tree().create_timer(1.4).timeout
		_tutorial()


func _tip(text: String) -> void :
	# 0.8: sized from the wrapped text; it sits in the band of the action buttons (v8_bottom_card), never over
	# the table, and the buttons step aside while it is shown
	var tw_: = W - 170.0
	var th: float = UI.font("body", 800).get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, tw_, 18).y
	var h: = maxf(104.0, 36.0 + th + 14.0)
	var tc: = UI.rbox("cream", Rect2(20, H - 186 - h, W - 40, h), 24, 3, 10)
	tc.add_to_group("v6_tip")
	tc.z_index = 35
	v8_bottom_card(tc)
	tc.set_param("border_top", Color("e8c9a0")).set_param("border_bottom", Color("a8697a"))
	add_child(tc)
	tc.add_child(Common.avatar("mc", Rect2(8, 8, 84, 84), "gold"))
	var nm: = UI.label(V6Txt.s("play.perk_tip") % [G.HEROES[partner].name, G.PERKS[partner]], 16, Color("b8406c"), Color.WHITE, 3, "body", 900)
	nm.position = Vector2(102, 8)
	nm.size = Vector2(W - 170, 24)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	tc.add_child(nm)
	var l: = UI.label(text, 18, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 170, 0)
	l.position = Vector2(102, 34)
	l.size = Vector2(W - 170, h - 44)
	tc.add_child(l)
	UI.slide_in(tc, Vector2(0, 40), 0.0, 0.35)
	# 0.8: at most 2.5 s on screen (2.1 s + fade), and a tap on the table closes it at once
	var t: Tween = tc.create_tween()
	t.tween_interval(2.1)
	t.tween_property(tc, "modulate:a", 0.0, 0.4)
	t.tween_callback(tc.queue_free)


# 0.8: a card that explains something during a match (intro tip, V6Specials «Новинка») goes into the band of
# the action buttons under the table, never over a tile row. The buttons hide while one is shown (a tap on
# the card closes it), and come back when the last card goes or the player taps a tile.
var _v8_bar_cards: Array = []

func v8_bottom_card(c: Control) -> void :
	var top: = board_rect.end.y + 4.0
	var h: = c.size.y
	c.position = Vector2(20, top + maxf(0.0, (H - 8.0 - top - h) * 0.5))
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.gui_input.connect( func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			c.accept_event()
			if is_instance_valid(c) and not c.is_queued_for_deletion():
				c.queue_free())
	# a card shown before the first tap gives way as soon as play starts; one shown later stays its time
	if board and board.tray.is_empty() and board.history.is_empty():
		c.set_meta("v8_fresh", true)
	_v8_bar_cards.append(c)
	_v8_bar_show(false)
	c.tree_exiting.connect( func():
		_v8_bar_cards.erase(c)
		if _v8_bar_cards.is_empty():
			_v8_bar_show(true))

func _v8_bar_show(on: bool) -> void :
	for b in [btn_undo, btn_hint, btn_shuffle, btn_sound]:
		if b and is_instance_valid(b):
			b.visible = on

func _v8_bar_clear() -> void :
	for c in _v8_bar_cards.duplicate():
		if is_instance_valid(c) and not c.is_queued_for_deletion() and c.has_meta("v8_fresh") and not c.has_meta("v8_out"):
			c.set_meta("v8_out", true)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var t: Tween = c.create_tween()
			t.tween_property(c, "modulate:a", 0.0, 0.2)
			t.tween_callback(c.queue_free)
	if _v8_bar_cards.all( func(x): return not is_instance_valid(x) or x.has_meta("v8_out")):
		_v8_bar_show(true)


# an overlay of the running match never takes a tap: the node and everything in it let input through
func _v8_ignore(n: Node) -> void :
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_v8_ignore(c)

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
		f.position = V10Layout.local_of(self, target.get_global_transform_with_canvas().origin)
		f.scale = Vector2(1.6, 1.6)
		while is_inside_tree() and board.history.size() + board.tiles.filter( func(t): return not t.alive).size() == n0:
			await get_tree().create_timer(0.1).timeout
		moves += 1
	f.queue_free()
	G.S.tut_done = true

# ---- 0.8: Russian plural agreement (1 пара, 2 пары, 5 пар) for every count shown in a match or result
static func pl(n: int, one: String, few: String, many: String) -> String:
	return "%d %s" % [n, V8PlayRules.plural(n, one, few, many)]

static func gems_text(n: int) -> String:
	return pl(n, "кристалл", "кристалла", "кристаллов")

static func pairs_text(n: int) -> String:
	return pl(n, "пара", "пары", "пар")

func _bubble(text: String) -> void :
	stage.say_text(text)

var _speak_t: = -99.0

func _speak(kind: String, tapped: = false) -> void :
	if tapped and now() - _speak_t < 1.6:
		return
	_speak_t = now()
	stage.react("smug")
	stage.say(kind)

const V9_WAIT_LINES: = ["Ульта готова — дай столу улечься.", "Секунду — стол ещё занят.", "Готова! Как только стол оживёт."]

func _speak_wait() -> void :
	if now() - _speak_t < 1.6:
		return
	_speak_t = now()
	stage.say_text(V9_WAIT_LINES[randi() % V9_WAIT_LINES.size()], 1.8)

func now() -> float:
	return G.time

func _process(dt: float) -> void :
	talk_cd -= dt
	if _fortune_close.is_valid() and board and (board.tray.size() > 0 or board.combo > 0):
		_v8_fold_fortune()
	if not _v8_bar_cards.is_empty() and board and (board.tray.size() > 0 or not board.history.is_empty()):
		_v8_bar_clear()
	if mode == "blitz" and board and board.input_on and not _blitz_done:
		blitz_left = maxf(0.0, blitz_left - dt)
		timer_lbl.text = "%d:%02d" % [int(blitz_left) / 60, int(blitz_left) % 60]
		if blitz_left <= 0.0:
			_blitz_end()
	if score_lbl:
		score_lbl.text = str(blitz_score) if mode == "blitz" else pairs_text(blitz_score)
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
	# the previous step's combo word goes at once (its count is stale now); a new one may follow below
	_v8_clear_combo_word()
	_v8_fold_fortune()
	# 0.9: a pair the ult removed (from_ult) neither charges the ult nor extends / counts the combo; Блиц: 10 points
	var from_ult: = v9_from_ult
	if from_ult:
		combo = 1
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
	if not skill_ready and not from_ult and not (ult and ult.busy):
		skill_charge = V9Ults.add(skill_charge, SKILL_NEED)
		if skill_charge >= SKILL_NEED:
			_skill_ready()
	G.S.gems += gain
	gained += gain
	G.add_aff(partner, 1)
	G.task_add("pairs")
	max_combo = maxi(max_combo, combo)
	if not from_ult:
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
	# 0.9: one hero effect per pair — a palette glow (heroine colour, value ≤ 70 %, never white), a ring and a few
	# sparkles; petals only from ×3 (the combo pill and the tier stamps carry the rest)
	if V9Feel.can_fx():
		Fx.flash_glow(fx_layer, mid, Color(V9Cutin.flash_color(G.HEROES[partner].color), 0.8), 1.4, 0.3)
	Fx.ring(fx_layer, mid, Color(1, 0.85, 0.5, 0.7), 1.0)
	Fx.burst(fx_layer, mid, "sparkle", 8 + mini(combo, 8) * 2, Color(1, 0.9, 0.55) if not gold else Color(1, 0.8, 0.2), 1.0 + mini(combo, 8) * 0.05)
	if combo >= 3:
		Fx.burst(fx_layer, mid, "petal", 4 + mini(combo, 6))
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
			stage.flash_emotion(_v8_combo_emotion(combo))
		if combo >= 3:
			Sfx.play("combo", 1.0 + combo * 0.03)
		if cfg.fx == "lanterns":
			# 0.9: the lantern fireworks bloom behind the tiles (a layer under the board), never over them
			var bgl: = _v9_under_board_fx()
			for i in min(combo, 4):
				Fx.burst(bgl, Vector2(randf_range(80, W - 80), randf_range(board_rect.position.y + 60.0, board_rect.end.y - 60.0)), "firework", 40, Color.from_hsv(randf(), 0.55, 0.9), 1.0)
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
	if v7combo and not from_ult:
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
	# 0.8: the combo word is a slim plaque in the strip between the table frame and the action buttons
	# (v8_band gap slot): it never covers a tile, a button or a caption, and it is gone before the next combo step
	var fs: = 30 + mini(combo, 6)
	var l: = UI.title(word, fs, Color("fff6d8"), Color("e0457b"))
	l.size = Vector2(560, 44)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(280, 22)
	l.rotation = deg_to_rad(randf_range(-1.5, 1.5))
	v8_band(l, 0.4, true, 0, true)
	if not l.is_inside_tree():
		return
	l.scale = Vector2(1.3, 1.3)
	var t: Tween = l.create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# 0.8: the heroine's emotion pop on the portrait card at a combo milestone: ×3 glad, ×5 (fever) amazed, ×8 glad or
# shy once she is fond of the player, then amazed / glad in turn
func _v8_combo_emotion(combo: int) -> String:
	match combo:
		3:
			return "happy"
		5:
			return "surprised"
		8:
			return V8Art.win_emotion(partner)
		12:
			return "surprised"
		16:
			return "happy"
	return "surprised" if (combo / 5) % 2 == 0 else "happy"

# a failed move (a blocked tile tapped): a pout at most every 2.5 s, so a burst of taps never flickers the card
var _v8_pout_t: = -10.0

# 0.8: one transient plaque at a time (combo word, notices, yaku, fever, riichi) in the slim strip between the
# table frame and the tops of the action buttons: it never covers a tile, an action button or its caption, and it
# lets every tap through (mouse_filter IGNORE). It fades out after `hold` seconds. The newest replaces the one
# before unless that one has a higher `prio` (combo word 0 < ribbons 1 < notices 2), then the newcomer is dropped.
# Every caller keeps its plaque ≤ 52 px high so it fits the strip.
var _v8_band_node: Control = null
var _v8_band_prio: = 0
var _v8_band_combo: = false

const V8_BAND_H: = 52.0

func v8_band(n: Control, hold: float, _gap: = true, prio: = 0, combo_word: = false) -> void :
	if _v8_over or _v8_modal:
		n.queue_free()
		return
	if _v8_band_node and is_instance_valid(_v8_band_node) and not _v8_band_node.is_queued_for_deletion():
		if _v8_band_prio > prio and _v8_band_node.modulate.a > 0.05:
			n.queue_free()
			return
		_v8_band_node.queue_free()
	_v8_band_node = n
	_v8_band_prio = prio
	_v8_band_combo = combo_word
	# the frame's outer rim ends ≈ 12 px above board_rect.end, the buttons start 14 px below it
	var mid: = board_rect.end.y - 4.0
	n.position = Vector2((W - n.size.x) * 0.5, mid - n.size.y * 0.5)
	n.pivot_offset = n.size * 0.5
	n.z_index = 45
	_v8_ignore(n)
	add_child(n)
	n.modulate.a = 0.0
	var t: Tween = n.create_tween()
	t.tween_property(n, "modulate:a", 1.0, 0.1)
	t.tween_interval(hold)
	t.tween_property(n, "modulate:a", 0.0, 0.2)
	t.tween_callback(n.queue_free)

# the combo word belongs to one combo step: the next match (or a broken combo) takes it away at once, so the
# plaque never shows «Трио ×3» while the combo pill already reads ×4
func _v8_clear_combo_word() -> void :
	if not _v8_band_combo or _v8_band_node == null or not is_instance_valid(_v8_band_node):
		return
	var n: = _v8_band_node
	_v8_band_node = null
	_v8_band_combo = false
	_v8_band_prio = 0
	n.queue_free()

# in-match notice (main.toast routes here while a match is on): a one-line plaque in the band slot, ~1.5 s
# returns false while a result / modal is up: main.toast then shows its usual pill
func v8_notice(text: String, icon: Texture2D = null) -> bool:
	if _v8_over or _v8_modal or not is_inside_tree():
		return false
	var w: = W - 60.0
	var p: = UI.rbox("plum", Rect2(0, 0, w, 48), 24, 3, 8)
	p.colors(Color(0.2, 0.1, 0.2, 0.96), Color(0.1, 0.05, 0.11, 0.96)).borders(Color("ffe7a6"), Color("c58a2c"))
	p.name = "V8Notice"
	var x0: = 18.0
	if icon:
		p.add_child(V8Art.rect(icon, Rect2(10, 5, 38, 38)))
		x0 = 54.0
	var aw: = w - x0 - 16.0
	var fs: = 20
	var f: = UI.font("body", 800)
	while fs > 16 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > aw:
		fs -= 1
	var l: = UI.label(text, fs, Color.WHITE, Color(0.2, 0.05, 0.2), 3)
	l.position = Vector2(x0, 0)
	l.size = Vector2(aw, 48)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	p.add_child(l)
	v8_band(p, 1.5, true, 2)
	if p.is_inside_tree():
		UI.pop_in(p, 0.0, 0.85)
	return true


func _cutin() -> void :
	stage.react("big")
	stage.say("combo")
	Fx.burst(fx_layer, stage.head_pos(), "heart", 14)

func _fever() -> void :
	fever_until = now() + 8.0
	charge = 1.0
	stage.react("big")
	Sfx.play("fever")
	var rib: = Common.ribbon(self, V6Txt.s("play.fever"), Rect2(0, 0, 400, V8_BAND_H), "gold", 30)
	remove_child(rib)
	v8_band(rib, 1.0, true, 1)
	if rib.is_inside_tree():
		UI.pop_in(rib, 0.0, 0.6)
	# the frame of V7Combo carries the fever (no full-screen vignette or embers over the tiles)

func _on_deny(_t: Tile) -> void :
	denies += 1
	stage.react("deny")
	if now() - _v8_pout_t > 2.5:
		_v8_pout_t = now()
		stage.flash_emotion("pout")
	if talk_cd <= 0.0:
		talk_cd = 5.0
		_bubble(V6Txt.s("play.blocked"))


func _on_fail() -> void :
	_v6_clear_tips()
	if stage:
		stage.flash_emotion("sad")
	if mode == "zen" or mode == "blitz" or mode == "duel" or free_rescue_left > 0:
		if duel:
			duel.on_overflow()
		if free_rescue_left > 0 and mode == "":
			free_rescue_left -= 1
			main.toast(V6Txt.s("play.omikuji_saved"), "gift")
		if mode == "blitz":
			blitz_left = maxf(0.0, blitz_left - 10.0)
			Fx.float_text(fx_layer, Vector2(W * 0.5, 260), "−10 с", Color("ff8a9a"), 36)
			# the overflow ate the last seconds: the run ends here (the countdown only runs while time is left)
			if blitz_left <= 0.0:
				timer_lbl.text = "0:00"
				_blitz_end()
				return
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
	_v8_modal_open()
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	_v8_modal_open()
	var p: = Common.popup(main, V6Txt.s("play.full_t"), 440, "cream", 660.0, false)
	# 0.8: her sad face (emotion art; the base portrait when the file is missing), settling in with a soft pop
	var fav: = V8Art.emotion_avatar(partner, "sad", Rect2(30, 60, 120, 120), "pink")
	p.add_child(fav)
	UI.pop_in(fav, 0.15, 0.85)
	var l: = UI.label(V6Txt.s("play.full_d"), 21, UI.INK)
	l.position = Vector2(170, 70)
	p.add_child(l)
	var price: = 0 if rescue_free else V8PlayRules.RESCUE_PRICE
	var rb: = JButton.make(V6Txt.s("play.return3") + ("" if price == 0 else " · %d" % price), "gold", Rect2(60, 210, 540, 92), V8Art.icon("undo") if price == 0 else V8Art.cur("gem"), 30)
	rb.icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rb.shine_every = 2.0
	var do_rescue: = func():
		if not is_instance_valid(p) or not is_inside_tree():
			return
		if price > 0:
			if not _v8_can_pay(price):
				return
			_v8_spend(price)
		rescue_free = false
		boosters_used += 1
		if riichi:
			riichi = false
			main.toast(V6Txt.s("play.riichi_burnt"), "heart")
		Common.close_popup(p)
		_v8_modal_close()
		board.return_tray(3)
		_refresh()
	rb.pressed.connect( func():
		if price > 0:
			_v8_pay("rescue", V8PlayRules.T.rescue_t, V8PlayRules.T.rescue_d, price, do_rescue)
		else:
			do_rescue.call())
	p.add_child(rb)
	# 0.8: the main action (pink) on the right, under the thumb; the way out on the left
	fail_retry_btn = JButton.make(V6Txt.s("play.redeal"), "pink", Rect2(340, 320, 260, 84), null, 24)
	fail_retry_btn.pressed.connect( func():
		Common.close_popup(p)
		_v8_record_loss()
		var a: = args0.duplicate()
		a["retry"] = randi()
		main.go("play", a))
	p.add_child(fail_retry_btn)
	var hb: = JButton.make(V6Txt.s("common.to_home"), "glass", Rect2(60, 320, 260, 84), null, 28)
	hb.pressed.connect( func():
		_v8_record_loss()
		main.go("home"))
	p.add_child(hb)

# a lost Path / daily table (left from the overflow window or the house button) counts as a game without a
# win; so does a duel or a blitz run left before its end (zen counts every cleared board on its own)
var _v8_loss_done: = false

func _v8_record_loss() -> void :
	if _v8_loss_done or _v8_over or _v8_saved:
		return
	var src: = _v8_source()
	if src in ["path", "daily", "duel", "blitz"]:
		_v8_loss_done = true
		G.record_game(src, false)
		G.save()

func _v8_source() -> String:
	match mode:
		"":
			return "path"
		"daily", "duel", "blitz", "zen":
			return mode
	return "other"

# false when a help tap will be refused (subclasses add their own rules); the handler's toast then says why
func _help_ok(kind: String) -> bool:
	if board == null or not board.input_on or riichi:
		return false
	match kind:
		"hint":
			return not _v8_hint_active() and board.best_move() != null
		"undo":
			return not board.history.is_empty()
	return true

func _hint() -> void :
	if riichi:
		V9Feel.deny(btn_hint)
		main.toast(V6Txt.s("play.riichi_locked"), "lock")
		return
	if not board.input_on:
		V9Feel.deny(btn_hint)
		return
	if _v8_hint_active():
		V9Feel.deny(btn_hint)
		main.toast(V8PlayRules.T.hint_on, "hint")
		return
	if board.best_move() == null:
		V9Feel.deny(btn_hint)
		return
	if hint_n <= 0:
		_v8_pay("hint", V8PlayRules.T.hint_t, V8PlayRules.T.hint_d, V8PlayRules.HELP_PRICE, func(): _v8_do_hint(true))
		return
	_v8_do_hint(false)

func _v8_do_hint(paid: bool) -> void :
	if not is_inside_tree() or not board.input_on or riichi or _v8_hint_active():
		return
	if paid and not _v8_can_pay(V8PlayRules.HELP_PRICE):
		return
	if not board.hint():
		V9Feel.deny(btn_hint)
		_refresh()
		return
	if paid:
		_v8_spend(V8PlayRules.HELP_PRICE)
	else:
		hint_n -= 1
	boosters_used += 1
	_bubble(Sfx.say(partner, "hint"))
	_refresh()

func _undo() -> void :
	if riichi:
		V9Feel.deny(btn_undo)
		main.toast(V6Txt.s("play.riichi_locked"), "lock")
		return
	if not board.input_on:
		V9Feel.deny(btn_undo)
		return
	if board.history.is_empty():
		V9Feel.deny(btn_undo)
		main.toast(V8PlayRules.T.undo_none, "undo")
		return
	if undo_n <= 0:
		_v8_pay("undo", V8PlayRules.T.undo_t, V8PlayRules.T.undo_d, V8PlayRules.HELP_PRICE, func(): _v8_do_undo(true))
		return
	_v8_do_undo(false)

func _v8_do_undo(paid: bool) -> void :
	if not is_inside_tree() or not board.input_on or riichi:
		return
	if paid and not _v8_can_pay(V8PlayRules.HELP_PRICE):
		return
	if board.undo():
		if paid:
			_v8_spend(V8PlayRules.HELP_PRICE)
		else:
			undo_n -= 1
		boosters_used += 1
		Sfx.play("whoosh", 1.3)
	else:
		V9Feel.deny(btn_undo)
	_refresh()

func _shuffle() -> void :
	if riichi:
		V9Feel.deny(btn_shuffle)
		main.toast(V6Txt.s("play.riichi_locked"), "lock")
		return
	if not board.input_on:
		V9Feel.deny(btn_shuffle)
		return
	if shuffle_n <= 0:
		_v8_pay("shuffle", V8PlayRules.T.shuffle_t, V8PlayRules.T.shuffle_d, V8PlayRules.HELP_PRICE, func(): _v8_do_shuffle(true))
		return
	_v8_do_shuffle(false)

func _v8_do_shuffle(paid: bool) -> void :
	if not is_inside_tree() or not board.input_on or riichi:
		return
	if paid:
		if not _v8_can_pay(V8PlayRules.HELP_PRICE):
			return
		_v8_spend(V8PlayRules.HELP_PRICE)
	else:
		shuffle_n -= 1
	boosters_used += 1
	board.shuffle_board()
	_refresh()


# ---- 0.8: every paid help goes through Common.confirm with «Не спрашивать в этой партии».
# The skip key is per match (this play node), so a new match always asks again.
func _v8_skip_prefix() -> String:
	return "m%d_" % get_instance_id()

func _v8_pay(kind: String, title: String, text: String, price: int, on_yes: Callable) -> void :
	if G.demo:
		on_yes.call()
		return
	_v6_clear_tips()
	Common.confirm(main, title, text, "gem", price, on_yes, {"skip_key": _v8_skip_prefix() + kind})

func _v8_can_pay(price: int) -> bool:
	if int(G.S.gems) < price:
		main.toast(V6Txt.s("play.need60") if price >= 60 else V6Txt.s("play.need30"), "gem")
		return false
	return true

func _v8_spend(price: int) -> void :
	G.S.gems = int(G.S.gems) - price
	G.save()
	UI.punch(gems_lbl, 0.3)

func _v8_hint_active() -> bool:
	for t in board.tiles:
		if t.alive and t.get("_hint_tw") != null:
			return true
	return false

func _exit_tree() -> void :
	Common.confirm_skip_reset(_v8_skip_prefix())



# 0.8: fast deal for the luck-card levels: every tile lands within ~0.75 s and input opens right after (0.9: the
# board's own deal(fast), so a tap during it skips the rest like any deal)
func _v8_quick_deal() -> void :
	board.deal(true)

# 0.8 match overlay layout: each transient overlay has its own slot, so two never land on each other, and
# none of them covers a tile of the table or takes a tap (mouse_filter IGNORE).
#   y 126–166, x 136–396 : one note under the goal plate (luck chip or «Стиль: …»), newest replaces older
#   y 121–175, x 132–398 : combo pill (V7Combo) with its milestone line («+1 к умению» …) inside; opaque, and
#                          the note is hidden while it shows (V7Combo._hide_notes), never drawn through it
#   inside the portrait   : the heroine's speech bubble (V6HeroStage.say_text), over her name plate
#   over the empty tray   : the level ribbon at the start, then the luck strip before the first tap
#   action-button band    : the intro tip and «Новинка» cards (v8_bottom_card; the buttons hide meanwhile)
#                           and the transient ribbons: yaku, fever, riichi (v8_band, one at a time)
#   frame–buttons strip   : the combo word (v8_band gap slot, shares the one-at-a-time slot with the ribbons)
#   bottom edge           : toasts (main.toast, one at a time while a match is on, over the button captions)
# The luck strip shows only before the first tap and folds into the chip at once when play starts.
const V8_NOTE_RECT: = Rect2(136, 126, 260, 40)

var _fortune_close: = Callable()

func _v8_fold_fortune() -> void :
	if _fortune_close.is_valid():
		var c: = _fortune_close
		_fortune_close = Callable()
		c.call()

# one note in the slot under the goal plate: the newest replaces the one before
func v8_note(text: String, col: = Color("ffe7a6"), secs: = 4.0) -> Control:
	if _v8_over:
		return null
	get_tree().call_group("v8_note", "queue_free")
	var f: = UI.font("body", 900)
	var fs: = 17
	# ≥ 16 px of side padding inside the plate (the rim is 2 px): text never touches the rims
	while fs > 16 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 36.0 > V8_NOTE_RECT.size.x:
		fs -= 1
	var w: = clampf(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 36.0, 120.0, V8_NOTE_RECT.size.x)
	var chip: = UI.rbox("plum", Rect2(V8_NOTE_RECT.end.x - w, V8_NOTE_RECT.position.y, w, V8_NOTE_RECT.size.y), 20, 2, 8)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_to_group("v6_chip")
	chip.add_to_group("v8_note")
	chip.borders(Color("ffe7a6"), Color("c58a2c"))
	add_child(chip)
	# the combo pill owns this slot while it runs: the note waits hidden under it (V7Combo._hide_notes)
	if v7combo and v7combo.shown and not v7combo.stopped:
		chip.visible = false
	var l: = UI.center_label(UI.label(text, fs, col, UI.DARK, 3, "body", 900), Rect2(16, 0, w - 32, V8_NOTE_RECT.size.y))
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	chip.add_child(l)
	var ct: = chip.create_tween()
	ct.tween_interval(secs)
	ct.tween_property(chip, "modulate:a", 0.0, 0.5)
	ct.tween_callback(chip.queue_free)
	UI.pop_in(chip, 0.0, 0.6)
	return chip

# 0.8: the omikuji is a strip over the top of the table (tap to hide), it then folds into the chip.
func _show_fortune() -> void :
	# play already started (a tile in the tray or a pair taken): no strip over the board, only the chip
	if board and (board.tray.size() > 0 or not board.history.is_empty() or board.combo > 0):
		_v8_fortune_chip()
		return
	# 0.8: it covers the tray, which is empty before the first tap, so every tile row stays visible and tappable
	var root: = Control.new()
	root.size = Vector2(tray_box.size.x, tray_box.size.y)
	root.position = tray_box.position
	# 0.8: never takes a tap: it folds by itself after V8_FORTUNE_SECS or at the first tap on the table
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# z 0 on purpose: popups (main.overlay, z 0) must stay above it; it is added after the board anyway
	root.z_index = 0
	add_child(root)
	var card: = UI.rbox("gold", Rect2(Vector2.ZERO, root.size), 26, 4, 10)
	card.colors(Color("3a3038"), Color("1e1a22")).borders(Color("fff0b8"), Color("b07a2a"))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)
	root.pivot_offset = root.size * 0.5
	var seal: = UI.rbox("plum", Rect2(12, 12, 94, 94), 20, 3, 4)
	seal.colors(Color(0.42, 0.1, 0.2), Color(0.24, 0.05, 0.12)).borders(Color("ffe7a6"), Color("c58a2c"))
	card.add_child(seal)
	seal.add_child(UI.center_label(UI.title("吉", 50, Color("ffe7a6"), Color(0.2, 0.02, 0.08)), Rect2(0, 0, 94, 94)))
	var seal_y: = (root.size.y - 94.0) * 0.5
	seal.position.y = seal_y
	var tx: = 118.0
	var tw_: = root.size.x - tx - 12.0
	var nm_txt: = "%s · %s" % [fortune.rank, fortune.name]
	var nf: = 26
	while nf > 24 and UI.font("title", 900).get_string_size(nm_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, nf).x > tw_:
		nf -= 1
	if UI.font("title", 900).get_string_size(nm_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, nf).x > tw_:
		nm_txt = String(fortune.name)
	var nm: = UI.label(nm_txt, nf, Color("ffe7a6"), Color(0.2, 0.05, 0.02), 4, "title", 900)
	nm.position = Vector2(tx, 6)
	nm.size = Vector2(tw_, 38)
	nm.clip_text = true
	card.add_child(nm)
	var df: = 18
	while df > 16 and UI.font("body", 800).get_multiline_string_size(fortune.desc, HORIZONTAL_ALIGNMENT_LEFT, tw_, df).y > root.size.y - 48.0:
		df -= 1
	var d: = UI.label(fortune.desc, df, Color("f3e6dc"))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.position = Vector2(tx, 42)
	d.size = Vector2(tw_, root.size.y - 46.0)
	card.add_child(d)
	UI.slide_in(root, Vector2(0, -30), 0.0, 0.3)
	Sfx.play("reveal_sr", 1.15)
	Fx.burst(self, root.position + Vector2(60, 60), "sparkle", 18, Color(1, 0.85, 0.5), 1.0)
	var closed: = [false]
	# the strip may already be freed when the timer fires: keep it in an array, never capture the node itself
	var box: = [root]
	var close: = func():
		if closed[0] or not is_instance_valid(box[0]):
			return
		closed[0] = true
		var rr: Control = box[0]
		rr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t2: = rr.create_tween().set_parallel()
		t2.tween_property(rr, "scale", Vector2(0.3, 0.3), 0.3).set_trans(Tween.TRANS_QUAD)
		t2.tween_property(rr, "position", V8_NOTE_RECT.position - rr.size * 0.35, 0.3).set_trans(Tween.TRANS_QUAD)
		t2.tween_property(rr, "modulate:a", 0.0, 0.3)
		t2.chain().tween_callback(rr.queue_free)
		_v8_fortune_chip()
	_v8_ignore(root)
	_fortune_close = close
	await get_tree().create_timer(V8_FORTUNE_SECS).timeout
	if is_inside_tree():
		_v8_fold_fortune()

const V8_FORTUNE_SECS: = 2.4

func _v8_fortune_chip() -> void :
	# a long «Великая удача · <name>» does not fit the plate at 16 px: the rank folds into a small gold star
	var t: = "%s · %s" % [fortune.rank, fortune.name]
	if UI.font("body", 900).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 36.0 > V8_NOTE_RECT.size.x:
		t = "★ %s" % fortune.name
	v8_note(t)

func _skill_ready() -> void :
	skill_ready = true
	skill_charge = SKILL_NEED
	stage.set_charge(SKILL_NEED, SKILL_NEED)
	# 0.9: «Ульта готова»: the portrait glows (stage), a chime, her line names the ult
	var nm: = ult.ult_name() if ult else String(G.SKILLS[partner].name)
	_bubble("Ульта «%s» готова! Коснись меня." % nm)
	Sfx.play("reveal_sr", 1.3, -4)
	V9Feel.haptic("match")

func _use_skill() -> void :
	if ult == null or ult.busy:
		return
	await ult.begin()
	if is_inside_tree():
		_refresh()


# dev (screenshots): --v9_ult=1 casts the equipped outfit's ult as soon as the table is playable, auto-target, no
# aim window. --v9_cutin=full|short|off forces the clip (default full); --v9_ult_shots=0.1,0.5,… saves the clip
# at those times into --shots=<dir> as <name>_t<ms>.png; --v9_freeze=<s> holds the clip at that time;
# --v9_mirror=0|1 picks the strip's side; --v9_aim=1 opens the 2 s aim window. Dev runs save to a separate file.
func _v9_dev() -> void :
	var a: = {}
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--") and "=" in x:
			var kv: = x.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	if a.get("v9_ult_selftest", "") == "1":
		G.save_path = "user://dev_v9_ult.json"
		V9UltSelftest.run(self)
		return
	if a.get("v9_ult", "") != "1":
		return
	G.save_path = "user://dev_v9_ult.json"
	ult.force_mode = String(a.get("v9_cutin", "full"))
	# --v9_aim=1: open the 2 s aim window instead of the auto-target (screenshots of the prompt)
	ult.force_auto = a.get("v9_aim", "") != "1"
	if a.has("v9_ult_shots") and a.has("shots"):
		V9Cutin.dev_dir = String(a.shots)
		V9Cutin.dev_name = String(a.get("name", "ult"))
		V9Cutin.dev_shots = Array(String(a.v9_ult_shots).split(",")).map( func(x): return float(x))
	if a.has("v9_freeze"):
		V9Cutin.dev_freeze = float(a.v9_freeze)
	# --v9_mirror=0|1: which way the first strip enters (1 = art on the left, the default first cast)
	if a.has("v9_mirror"):
		V9Cutin._mirror_flip = a.v9_mirror != "1"
	while is_inside_tree() and not board.input_on:
		await get_tree().create_timer(0.05).timeout
	if not is_inside_tree():
		return
	await get_tree().create_timer(float(a.get("v9_delay", "0.4"))).timeout
	if not is_inside_tree():
		return
	skill_charge = SKILL_NEED
	_skill_ready()
	_use_skill()


func _open_gift(mid: Vector2) -> void :
	var r: = randi() % 4
	var text: = ""
	match r:
		0:
			var g: = 40 + randi() % 41
			G.S.gems += g
			gained += g
			text = "Под фишкой подарок: " + gems_text(g)
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
	# 0.9: nothing bursts over the tiles — a gold glint UNDER the board where the gift tile was, and the hearts and
	# sparkles pop at the HUD gem counter (outside the board rect)
	Fx.burst(_v9_under_board_fx(), mid, "sparkle", 16, Color(1, 0.86, 0.5), 0.8)
	var hud_at: = Vector2(70, 154)
	Fx.burst(fx_layer, hud_at, "sparkle", 18, Color(1, 0.86, 0.5), 0.6)
	Fx.burst(fx_layer, hud_at, "heart", 6, Color.WHITE, 0.6)
	main.toast(text, "gift")
	_refresh()

var _blitz_done: = false

func _blitz_end() -> void :
	if _blitz_done:
		return
	_blitz_done = true
	board.input_on = false
	var best: = int(G.S.get("blitz_best", 0))
	var record: = blitz_score > best
	if record:
		G.S.blitz_best = blitz_score
	var gems: = mini(150, blitz_score / 20)
	G.S.gems += gems
	var ba: = V8PlayRules.award("blitz", V8PlayRules.blitz_rp(blitz_score), boards_done > 0)
	_v8_saved = true
	_v8_end_overlays()
	Sfx.play("win")
	_blitz_result(record, best, gems, ba)



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
	# one slim line in the band slot: the set name (Playfair) + what it was (Nunito)
	var tf: = UI.font_for("title", 30, 900)
	var bf: = UI.font("body", 800)
	var tw_: = tf.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var sw: = bf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var w: = minf(W - 40.0, tw_ + sw + 18.0 + 56.0)
	var rib: = UI.rbox("plum", Rect2(0, 0, w, V8_BAND_H), V8_BAND_H * 0.5, 3, 8)
	rib.colors(Color(0.16, 0.08, 0.3, 0.96), Color(0.08, 0.04, 0.16, 0.96)).borders(Color("fff0b8"), Color("c58a2c"))
	var x: = (w - tw_ - sw - 18.0) * 0.5
	var t: = UI.title(name, 30, Color("ffe7a6"), Color("5a1a6a"))
	t.position = Vector2(x, 0)
	t.size = Vector2(tw_ + 4.0, V8_BAND_H)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rib.add_child(t)
	var sl: = UI.label(sub, 18, Color("e9dcff"), UI.DARK, 2, "body", 800)
	sl.position = Vector2(x + tw_ + 18.0, 0)
	sl.size = Vector2(maxf(10.0, w - (x + tw_ + 18.0) - 20.0), V8_BAND_H)
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rib.add_child(sl)
	v8_band(rib, 1.3, true, 1)
	if rib.is_inside_tree():
		UI.pop_in(rib, 0.0, 1.2)
		rib.shine(0.15)
	Sfx.play("reveal_sr", 1.1)
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
		_riichi_make()
		riichi_btn.pulse = true
		riichi_btn.shine_every = 1.2
		riichi_btn.pressed.connect(_declare_riichi)
		UI.pop_in(riichi_btn, 0.0, 0.3)
		Sfx.play("pop", 0.8)

func _check_riichi_force() -> void :
	riichi_offered = true
	_riichi_make()

# 0.9: the riichi offer takes the sound button's slot at the left end of the button row (a round gold-rim badge
# the size of the helps), so it never overlaps a booster; the sound toggle comes back once riichi is declared
func _riichi_make() -> void :
	var d: = 108.0
	var cx: = btn_sound.position.x + btn_sound.size.x * 0.5 if btn_sound else 117.0
	# 0.9: the same round lacquer disc as the helps beside it (gold rim, gloss), with a crimson core — the flat tan
	# «gold» disc read as a placeholder — and a centred two-line caption
	riichi_btn = JButton.make("", "graphite", Rect2(cx - d * 0.5, H - 170, d, d), null, 20, d * 0.5)
	riichi_btn.box.set_param("border", 4.0).set_param("gloss", 0.16)
	riichi_btn.box.colors(Color("c23a4e"), Color("5a0f1e")).borders(Color("ffe7a6"), Color("c58a2c"))
	var rt: String = V6Txt.s("play.riichi").to_lower()
	rt = rt.left(1).to_upper() + rt.substr(1)
	var rl: = UI.center_label(UI.label(rt, 22, Color("fff2d2"), Color("3a0812"), 5, "body", 900), Rect2(0, d * 0.5 - 30, d, 30))
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riichi_btn.add_child(rl)
	var rs: = UI.center_label(UI.label(V6Txt.s("play.riichi_sub"), 16, Color("ffe7a6"), Color("3a0812"), 4, "body", 900), Rect2(0, d * 0.5 + 2, d, 24))
	rs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riichi_btn.add_child(rs)
	riichi_btn.z_index = 40
	add_child(riichi_btn)
	if btn_sound:
		btn_sound.visible = false

func _declare_riichi() -> void :
	if riichi:
		return
	riichi = true
	riichi_btn.queue_free()
	riichi_btn = null
	if btn_sound:
		btn_sound.visible = true
	Sfx.play("fever", 1.15)
	var rib: = Common.ribbon(self, V6Txt.s("play.riichi"), Rect2(0, 0, 400, V8_BAND_H), "red", 34)
	remove_child(rib)
	v8_band(rib, 1.0, true, 1)
	if rib.is_inside_tree():
		UI.pop_in(rib, 0.0, 1.2)
	Fx.burst(fx_layer, rib.position + rib.size * 0.5, "sparkle", 50, Color(1, 0.5, 0.5), 1.6)
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
			var za: = V8PlayRules.award("zen", V8PlayRules.zen_rp(boards_done), true)
			Fx.float_text(fx_layer, Vector2(W * 0.5, 660), V8PlayRules.award_text(za), Color("a9d9c4"), 30)
			_v8_rank_float(za, Vector2(W * 0.5, 720))
		Sfx.play("win", 1.2, -6)
		# 0.9: petals and gold dust under the (now empty) board, not flat confetti over the next deal
		var ub: = _v9_under_board_fx()
		Fx.burst(ub, board_rect.get_center(), "petal", 24, Color(1, 0.8, 0.88), 1.3)
		Fx.burst(ub, board_rect.get_center(), "sparkle", 30, Color(1, 0.86, 0.5), 1.3)
		await get_tree().create_timer(0.8).timeout
		if not is_inside_tree():
			return
		cfg = _mode_cfg(boards_done)
		_make_board()
		board.deal()
		_refresh()
		return
	var secs: = now() - start_t
	var stars: = V8PlayRules.story_stars(fails, boosters_used)
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
	elif mode == "daily":
		reward = cfg.reward.gems + stars * 20
		var dm: = G.dailymap()
		var d: = int(G.today().substr(8, 2))
		if not d in dm.done.map( func(x): return int(x)):
			dm.done.append(d)
	if riichi:
		reward = reward * 2 + gained
	rp_before = int(G.S.rp)
	if mode != "trial":
		var yrp: = 0
		for y in yaku_list:
			yrp += _yaku_rp(y)
			if not y.begins_with("set:"):
				G.S.yaku_seen[y] = int(G.S.yaku_seen.get(y, 0)) + 1
		rp_gain = V8PlayRules.path_rp(stars, int(cfg.get("hard", 0)) if mode == "" else 0, yrp)
		var src: = "daily" if mode == "daily" else "path"
		rank_ups = G.add_rp(rp_gain, src)
		G.record_game(src, true)
		if src == "path":
			V8Starter.on_path_win()
	if mode != "trial":
		G.add_aff(partner, 10)
		G.task_add("levels")
		G.add_pass_xp(100)
		G.S.xp = int(G.S.xp) + 40
	G.S.gems += reward
	G.S.tut_done = true
	G.save()
	# 0.8: the win is saved: leaving now goes straight out, without «прогресс не сохранится» or a counted loss
	_v8_saved = true
	board.input_on = false
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return
	_victory(stars, reward, secs, first)

# 0.8: nothing from the match may draw over a result window (combo pill, banners, chips, speech bubbles).
var _v8_over: = false
# the result is awarded and saved (set before the short pause that leads into the result window)
var _v8_saved: = false
# a window over the running match (the overflow window): combo pill, banners, floats, toasts and the bubble go
var _v8_modal: = false
var _v8_modal_hidden: = []

func _v8_modal_open() -> void :
	_v8_modal = true
	_v8_fold_fortune()
	if v7combo:
		v7combo.stop()
	_v6_clear_tips()
	# banners and plaques drawn above the board (z ≥ 30) would show through the window: hide them until it closes
	for c in get_children():
		if c is Control and (c as Control).visible and (c as Control).z_index >= 30 and c != v7combo and c != riichi_btn and not c is JButton:
			(c as Control).visible = false
			_v8_modal_hidden.append(c)
	if fx_layer:
		for c in fx_layer.get_children():
			if c is Label:
				c.queue_free()
	var bub = V6HeroStage._shared_bubble
	if bub and is_instance_valid(bub):
		bub.queue_free()
	if main and main.overlay:
		for c in main.overlay.get_children():
			if c.has_meta("v8_toast"):
				c.queue_free()

func _v8_modal_close() -> void :
	_v8_modal = false
	for c in _v8_modal_hidden:
		if is_instance_valid(c):
			(c as Control).visible = true
	_v8_modal_hidden.clear()
	if v7combo and not _v8_over:
		v7combo.resume()

func _v8_end_overlays() -> void :
	_v8_over = true
	for b in [btn_hint, btn_undo, btn_shuffle, btn_sound]:
		if b:
			b.visible = false
	if v7combo:
		v7combo.stop()
	_v6_clear_tips()
	get_tree().call_group("v6_chip", "queue_free")
	# a hidden member of «v6_tip» keeps queued intro cards (V6Specials) from popping up over the result
	var blk: = Control.new()
	blk.name = "V8TipBlock"
	blk.visible = false
	blk.add_to_group("v6_tip")
	add_child(blk)
	for c in get_children():
		if c is CanvasItem and (c as CanvasItem).z_index > 0 and c != v7combo:
			(c as CanvasItem).visible = false
	if fx_layer:
		for c in fx_layer.get_children():
			if c is CanvasItem and (c as CanvasItem).z_index > 0:
				(c as CanvasItem).visible = false
	if stage:
		stage.visible = false
	if riichi_btn:
		riichi_btn.visible = false

# ---- 0.8 (spec 5): ONE result window for every mode (Путь, ежедневка, блиц, восхождение, этюд, смена, дуэль,
# ивент, турнир). Ribbon title → the content in one column on a panel (btn/panel nine-patch) → rank bar (was /
# now, +N, «Новый ранг» inside) → weekly-league line → buttons at the bottom, the main action (pink) on the right
# under the thumb. The heroine stands in the free column right of the content, under the panel, when her face fits.
#   var ctx: = v8_res_open("Время вышло")      ctx = {root, plate, y, w, hero}
#   v8_res_big / v8_res_line / v8_res_stars / v8_res_reward / v8_res_avatars / v8_res_rank (add to the column)
#   v8_res_close(ctx, hero_id, main_text, main_cb, alt_text, alt_cb)   sizes the panel, adds the buttons
const V8_RES_TOP: = 150.0
const V8_RES_PAD: = 24.0

func v8_res_open(title: String, pal: = "pink", fs: = 44) -> Dictionary:
	_v8_end_overlays()
	# the result is awarded and saved before this window opens: leaving now never counts a lost game
	_v8_saved = true
	var root: = Control.new()
	root.name = "V8Result"
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	# above the tiles (tray tiles draw at z 200+), below main.overlay (popups, toasts: z 400 in a match)
	root.z_index = 300
	add_child(root)
	var dim: = ColorRect.new()
	# 0.10 M0: the dim reaches the viewport edges past the content column (tablets)
	var dbr: = V10Layout.bleed_rect(self)
	dim.position = dbr.position
	dim.size = dbr.size
	dim.color = Color(0.06, 0.04, 0.07, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.8, 0.35)
	var rays: = Common.rays(root, Vector2(W * 0.5, 150), 1100, Color(1, 0.9, 0.6, 0.45), 14, 0.05, 0.55)
	rays.modulate.a = 0.0
	rays.create_tween().tween_property(rays, "modulate:a", 1.0, 0.5)
	var f: = UI.font("title", 900)
	while fs > 28 and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 470.0:
		fs -= 2
	var rib: = Common.ribbon(root, title, Rect2(W * 0.5 - 260, 34, 520, 100), pal, fs)
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.pop_in(rib, 0.1, 0.3)
	var plate: = Control.new()
	plate.name = "Plate"
	plate.position = Vector2(24, V8_RES_TOP)
	plate.size = Vector2(W - 48, 100)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plate)
	return {"root": root, "plate": plate, "y": 20.0, "w": W - 48.0, "rib": rib}

# a centred line in the column; shrinks to 16 px, then trims with «…» (never smaller than 16)
func v8_res_line(ctx: Dictionary, text: String, fs: = 20, col: = UI.INK, gap: = 6.0) -> Label:
	var w: float = ctx.w - V8_RES_PAD * 2.0
	var f: = UI.font("body", 900)
	while fs > 16 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs -= 1
	var h: = fs + 12.0
	var l: = UI.center_label(UI.label(text, fs, col, UI.DARK, 3, "body", 900), Rect2(V8_RES_PAD, ctx.y, w, h))
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	(ctx.plate as Control).add_child(l)
	ctx.y += h + gap
	return l

# a big number (score, floors, tips) with a small caption above it
func v8_res_big(ctx: Dictionary, text: String, caption: = "") -> Label:
	if caption != "":
		v8_res_line(ctx, caption, 18, UI.MUTED, 0.0)
	var l: = UI.center_label(UI.title(text, 72, Color("ffe7a6"), Color("5a1a6a")), Rect2(0, ctx.y - 6.0, ctx.w, 92))
	(ctx.plate as Control).add_child(l)
	UI.pop_in(l, 0.25, 1.5)
	ctx.y += 90.0
	return l

# three empty stars and the rule they follow under them; light them with v8_res_light_stars
func v8_res_stars(ctx: Dictionary, rule: String) -> Array:
	var nodes: = []
	var pw: float = ctx.w
	for i in 3:
		var s: = V8Art.star_rect(false, Rect2(pw * 0.5 - 52 + (i - 1) * 132, ctx.y + (0 if i == 1 else 16), 104, 104))
		(ctx.plate as Control).add_child(s)
		nodes.append(s)
	ctx.y += 122.0
	var f: = UI.font("body", 800)
	var w: float = pw - V8_RES_PAD * 2.0
	var txt: = rule
	if f.get_string_size(rule, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > w:
		txt = rule.replace(" · ", "\n")
	var lines: = txt.count("\n") + 1
	var rl: = UI.center_label(UI.label(txt, 16 if lines > 1 or f.get_string_size(rule, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x > w else 17, UI.MUTED, UI.DARK, 2, "body", 800), Rect2(V8_RES_PAD, ctx.y, w, 24.0 * lines))
	(ctx.plate as Control).add_child(rl)
	ctx.y += 24.0 * lines + 6.0
	return nodes

# 0.9 (spec §D): the stars are stamped one per beat (V9_BEAT): each drops from 2.3× onto its socket, lands with a
# thump, a gold ring, sparks, a haptic and a short dip of the panel (the dip at «Эффекты: полные» only)
func v8_res_light_stars(ctx: Dictionary, nodes: Array, n: int) -> void :
	await get_tree().create_timer(V9_STAR_AT).timeout
	var k: = mini(n, nodes.size())
	for i in k:
		if not is_inside_tree():
			return
		_v9_stamp_star(ctx, nodes[i], i, i == k - 1)
		await get_tree().create_timer(V9_BEAT).timeout

# the reward row: cur/<cur> art + «+N» (counted up by the caller or set at once) and, under it, the affection line
# with icon/heart. Returns {row, lbl}.
func v8_res_reward(ctx: Dictionary, n: int, aff: = "", cur: = "gem", note: = "") -> Dictionary:
	var w: float = ctx.w - V8_RES_PAD * 2.0
	var h: = 84.0
	var row: = UI.rbox("glass", Rect2(V8_RES_PAD, ctx.y, w, h), 24, 3, 8)
	row.borders(Color("ffe7a6"), Color("8a6a3a"))
	(ctx.plate as Control).add_child(row)
	row.add_child(V8Art.rect(V8Art.cur(cur), Rect2(10, 6, 72, 72)))
	var gl: = UI.label("+%d" % n, 40, Color("f2799f"), Color.WHITE, 6, "title", 900)
	gl.position = Vector2(92, -2 if aff != "" else 10)
	gl.size = Vector2(w - 100, 56)
	row.add_child(gl)
	if note != "":
		var nl: = UI.label(note, 18, UI.INK, UI.DARK, 3, "body", 900)
		nl.position = Vector2(220, 0 if aff != "" else 12)
		nl.size = Vector2(w - 232, 52)
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.clip_text = true
		row.add_child(nl)
	if aff != "":
		row.add_child(V8Art.rect(V8Art.icon("heart"), Rect2(94, 52, 26, 26)))
		var hl: = UI.label(aff, 18, Color("f7a8c4"), UI.DARK, 3, "body", 900)
		hl.position = Vector2(126, 50)
		hl.size = Vector2(w - 140, 28)
		hl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		hl.clip_text = true
		row.add_child(hl)
	ctx.y += h + 10.0
	return {"row": row, "lbl": gl}

# a row of heroine portraits (blessings of a climb, guests of a shift)
func v8_res_avatars(ctx: Dictionary, ids: Array, d: = 60.0, ring_of: = Callable()) -> void :
	if ids.is_empty():
		return
	var gap: = 8.0
	var x: float = (ctx.w - ids.size() * d - (ids.size() - 1) * gap) * 0.5
	for id in ids:
		var ring: String = ring_of.call(id) if ring_of.is_valid() else "gold"
		(ctx.plate as Control).add_child(Common.avatar(String(id), Rect2(x, ctx.y, d, d), ring))
		x += d + gap
	ctx.y += d + 10.0

# the rank bar and the league line. `a` = V8PlayRules.award() result; {} keeps rp_gain / rp_before / rank_ups
# as set by the caller (the Path victory)
func v8_res_rank(ctx: Dictionary, a: Dictionary, week_gain: = 0) -> Control:
	if not a.is_empty():
		rp_gain = int(a.get("rp", 0))
		rp_before = int(G.S.rp) - rp_gain
		rank_ups = a.get("ups", [])
	var x: = V8_RES_PAD
	var w: float = ctx.w - V8_RES_PAD * 2.0
	var box: = _v8_rank_block(ctx.plate, Rect2(x, ctx.y, w, 0))
	ctx.y += box.size.y + 8.0
	var li: = V8PlayRules.league_info()
	if not li.is_empty():
		_v8_league_row(ctx.plate, Rect2(x, ctx.y, w, 60), li, week_gain)
		ctx.y += 68.0
	ctx["rank_box"] = box
	return box

# a heroine's line under the result (event beat, etude comment): her portrait and the text on a cream card
func v8_res_say(ctx: Dictionary, hid: String, text: String) -> void :
	if text == "":
		return
	var w: float = ctx.w - V8_RES_PAD * 2.0
	var f: = UI.font("body", 800)
	var th: float = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w - 116.0, 18).y
	var h: = maxf(92.0, th + 24.0)
	var bub: = UI.rbox("cream", Rect2(V8_RES_PAD, ctx.y, w, h), 22, 3, 8)
	(ctx.plate as Control).add_child(bub)
	bub.add_child(Common.avatar(hid, Rect2(10, (h - 76.0) * 0.5, 76, 76), "gold"))
	var bl: = UI.label(text, 18, UI.INK)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bl.position = Vector2(98, 8)
	bl.size = Vector2(w - 112, h - 16)
	bub.add_child(bl)
	UI.slide_in(bub, Vector2(0, 20), 0.7, 0.4)
	ctx.y += h + 10.0

# sizes the panel to the column, adds the two buttons (main = pink, bottom right), places the heroine
func v8_res_close(ctx: Dictionary, hid: String, main_text: String, main_cb: Callable, alt_text: String, alt_cb: Callable, main_icon: Texture2D = null, alt_icon: Texture2D = null) -> Array:
	var root: Control = ctx.root
	var plate: Control = ctx.plate
	var h: float = ctx.y + 16.0
	plate.size.y = h
	# the panel art is resampled for a 300 px box (corner ornaments ≈ 50 px) and then stretched to the column
	var np: = V8Art.nine("panel", Rect2(0, 0, ctx.w, minf(h, 300.0)))
	np.size = Vector2(ctx.w, h)
	plate.add_child(np)
	plate.move_child(np, 0)
	plate.pivot_offset = plate.size * 0.5
	UI.pop_in(plate, 0.2, 0.85)
	var by: = H - 132.0
	# 0.8: one column grid for both rows: the secondary column (alt button, «Повтор» above it) is V8_RES_COL1 wide
	# from the left edge, the primary CTA takes the rest, so its 26 px caption fits without shrinking
	var bm: = JButton.make(main_text, "pink", Rect2(16.0 + V8_RES_COL1 + V8_RES_GAP, by, W - 32.0 - V8_RES_COL1 - V8_RES_GAP, 96), main_icon, 26)
	bm.shine_every = 2.5
	bm.pressed.connect(main_cb)
	root.add_child(bm)
	var ba: = JButton.make(alt_text, "lav", Rect2(16.0, by, V8_RES_COL1, 96), alt_icon, 26 if alt_icon == null else 28)
	ba.pressed.connect(alt_cb)
	root.add_child(ba)
	for b in [bm, ba]:
		if b.icon_rect:
			b.icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	UI.pop_in(bm, 0.9)
	UI.pop_in(ba, 1.0)
	ctx["by"] = by
	ctx["plate_end"] = plate.position.y + h
	# the heroine stands behind the panel and the buttons (right after the dim and the rays)
	if not Hero.RIGS.has(hid):
		hid = partner if Hero.RIGS.has(partner) else "mc"
	# 0.8: her emotion portrait (ctx.emo: the caller's choice; a win is happy, or shy once she is fond of the player).
	# A rank-up turns her surprised for a moment (_animate_rank). No emotion art: the rigged base portrait as before.
	var emo: String = String(ctx.get("emo", V8Art.win_emotion(hid)))
	_v8_res_bust = null
	if V8Art.has_emotion(hid, emo):
		var b: = _v8_res_bust_make(root, hid, emo, ctx.plate_end, by)
		ctx["bust"] = b
		if ctx.has("rank_box") and not ctx.get("own_rank_anim", false):
			var bx0: = [ctx.rank_box]
			get_tree().create_timer(0.9).timeout.connect( func():
				if is_inside_tree() and is_instance_valid(bx0[0]):
					_animate_rank(bx0[0]))
		return [bm, ba]
	var vh: = Hero.new().setup(hid, V8_HERO_H)
	vh.position = Vector2(W * 0.74, H + V8_HERO_DROP)
	vh.interactive = false
	root.add_child(vh)
	root.move_child(vh, 2)
	ctx["hero"] = vh
	_v8_place_hero(vh, hid, ctx.plate_end, by)
	if vh.visible:
		vh.react("big")
	if ctx.has("rank_box") and not ctx.get("own_rank_anim", false):
		var bx: = [ctx.rank_box]
		get_tree().create_timer(0.9).timeout.connect( func():
			if is_inside_tree() and is_instance_valid(bx[0]):
				_animate_rank(bx[0]))
	return [bm, ba]

# the result-window bust: in the free column right of the content, from under the panel down past the screen edge
# (the waist cut is off screen and fades), face centred in the column. Too little room for her face above the
# buttons: no bust, the window never shows a face cut by the buttons.
const V8_BUST_H: = 600.0
var _v8_res_bust: Control = null

func _v8_res_bust_make(root: Control, hid: String, emo: String, top: float, bottom: float) -> Control:
	var foot: = H + 30.0
	# 0.10 M0: on phones taller than 9:16 she grows into the extra height instead of leaving a dark gap
	var bh: = minf(V8_BUST_H + maxf(0.0, H - 1280.0) * 0.6, foot - (top + 6.0))
	if bh < 320.0:
		return null
	var k: = bh / 800.0
	var fw: = V8Art.emotion_face_w(hid, emo) * k
	var face: = V8Art.emotion_face(hid, emo)
	var at: = Vector2((V8_LEFT_COL + 16.0 + W) * 0.5, foot - bh + face.y * k)
	if at.y + fw * 0.75 > bottom - 4.0:
		return null
	var b: = V8Art.bust(hid, emo, size, at, fw, 0.08)
	root.add_child(b)
	root.move_child(b, 2)
	_v8_res_bust = b
	UI.slide_in(b, Vector2(110, 0), 0.25, 0.6)
	get_tree().create_timer(0.85).timeout.connect( func():
		if is_instance_valid(b):
			V8Art.bust_bounce(b, 0.03))
	return b

# the result bust changes expression (crossfade + a small bounce); back_after > 0 returns to the one before
func _v8_res_react(e: String, back_after: = 0.0) -> void :
	var b: = _v8_res_bust
	if b == null or not is_instance_valid(b) or not V8Art.has_emotion(String(b.get_meta("hero")), e):
		return
	var was: = V8Art.bust_emo(b)
	V8Art.bust_set(b, e, 0.34)
	V8Art.bust_bounce(b, 0.03)
	if back_after <= 0.0 or was == e:
		return
	await get_tree().create_timer(back_after).timeout
	if is_instance_valid(b) and V8Art.bust_emo(b) == V8Art.emo_name(e):
		V8Art.bust_set(b, was, 0.4)

# zen has no result window: a rank-up shows as a float over the table, never as a toast over the HUD
func _v8_rank_float(a: Dictionary, at: Vector2) -> void :
	var t: = V8PlayRules.rankup_text(a)
	if t != "":
		Fx.float_text(fx_layer, at, t, Color("ffd34d"), 28)
		Sfx.say(partner, "rankup")


# 0.8 victory (Путь, ежедневка, испытание): the shared result window. Stars (+ star rule) → stats → reward →
# shard / item → rank bar → league line → compact yaku; album / photo row and the buttons under the panel.
func _victory(stars: int, reward: int, secs: float, first: bool) -> void :
	print("VICTORY stars=%d" % stars)
	_v9_win_dev()
	Sfx.music("")
	Sfx.play("win")
	var ctx: = v8_res_open(V6Txt.s("play.win") if not riichi else V6Txt.s("play.win_riichi"), "pink" if not riichi else "red", 54 if not riichi else 42)
	ctx["own_rank_anim"] = true
	var root: Control = ctx.root
	var plate: Control = ctx.plate
	var pw: float = ctx.w
	# 0.9: the summon showcase's treatment instead of flat pink confetti bars — sakura petals and gold dust, on a
	# layer UNDER the title ribbon and the result panel (right above the dim, behind both in the tree), so nothing
	# crosses the title or the panel's text
	var wparts: = Control.new()
	wparts.size = size
	wparts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var under: = plate.get_index()
	if ctx.has("rib") and is_instance_valid(ctx.rib):
		under = mini(under, (ctx.rib as Node).get_index())
	root.add_child(wparts)
	root.move_child(wparts, under)
	Fx.burst(wparts, Vector2(W * 0.2, H * 0.14), "petal", 30, Color(1, 0.8, 0.88), 1.5)
	Fx.burst(wparts, Vector2(W * 0.8, H * 0.14), "petal", 30, Color(1, 0.8, 0.88), 1.5)
	Fx.burst(wparts, Vector2(W * 0.5, H * 0.12), "sparkle", 40, Color(1, 0.86, 0.5), 1.4)
	var star_nodes: = v8_res_stars(ctx, V8PlayRules.T.star_rule)
	v8_res_line(ctx, V8PlayRules.T.stats % [int(secs), boosters_used, fails], 19, UI.INK, 4.0)
	var rw: = v8_res_reward(ctx, 0, "+10 симпатии" if mode != "trial" else "")
	var rr: Control = rw.row
	var gl: Label = rw.lbl
	if first and cfg.reward.has("item"):
		var it: Dictionary = G.ITEM[cfg.reward.item]
		var ib: = UI.rbox("gold", Rect2(rr.size.x - 240, 6, 230, 72), 20, 3, 6)
		rr.add_child(ib)
		ib.add_child(UI.tex(G.item_tex(it), Rect2(6, 4, 64, 64)))
		var il: = UI.label(it.name, 17, Color.WHITE, Color("7a4a0c"), 4, "body", 900)
		il.position = Vector2(76, 4)
		il.size = Vector2(146, 64)
		il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		il.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ib.add_child(il)
		var nb: = UI.rbox("red", Rect2(144, -12, 80, 26), 13, 2, 4)
		ib.add_child(nb)
		nb.add_child(UI.center_label(UI.label(V6Txt.s("common.new"), 16, Color.WHITE), Rect2(0, 0, 80, 26)))
	if shards_found > 0 and cfg.has("shard"):
		var sh: String = cfg.shard
		var have: = mini(int(G.S.shards.get(sh, 0)), G.SHARDS_NEED)
		_v8_shard_line(plate, sh, have, Rect2(V8_RES_PAD, ctx.y, pw - V8_RES_PAD * 2.0, 40))
		ctx.y += 48.0
	var rank_box: Control = null
	if mode != "trial":
		rank_box = v8_res_rank(ctx, {})
	# 0.9: the yaku stamps come after the stars, the reward roll and the rank bar, one per beat
	_v9_yaku_at = V9_STAR_AT + V9_BEAT * mini(stars, 3) + (0.25 + V9_RANK_FILL if rank_box else 0.5)
	# (the chip tweens read _v9_yaku_at while they are built, so the computed beat holds; no reset afterwards)
	ctx.y = _v8_yaku_chips(plate, V8_RES_PAD, ctx.y, pw - V8_RES_PAD * 2.0) + 10.0
	# 0.8: the album chip («Альбом: +N марок») sits inside the panel, right under the yaku, not hanging off its edge
	var album_y: = -1.0
	if not (V7Album.st().new as Array).is_empty():
		album_y = ctx.y + 4.0
		ctx.y += 56.0

	var next_text: = V6Txt.s("play.next") if mode == "" else (V6Txt.s("common.to_home") if mode == "daily" else V6Txt.s("play.to_banner"))
	var summon_ok: = G.summon_open()
	var go_next: = func():
		if mode == "trial":
			main.go("summon", {"banner": _banner_of(partner)})
		elif mode == "daily":
			main.go("home")
		else:
			var nx: int = min(lvl + 1, G.LEVELS.size() - 1)
			main.go("levels", {"select": nx, "pick": true})
	var go_alt: = func():
		if G.summon_open():
			main.go("summon", {"banner": _banner_of(partner) if mode == "trial" else 1})
		else:
			main.go("home")
	var btns: = v8_res_close(ctx, partner, next_text, go_next, V6Txt.s("play.wishes") if summon_ok else V6Txt.s("common.to_home"), go_alt,
		null, V8Art.nav("wishes") if summon_ok else V8Art.nav("home"))
	victory_next_btn = btns[0]
	victory_summon_btn = btns[1]
	_v8_photo_row(root, stars, secs, ctx.plate_end, ctx.by, plate.position + Vector2(V8_RES_PAD, album_y) if album_y >= 0.0 else Vector2(-1, -1), pw - V8_RES_PAD * 2.0)
	_v8_res_settle(ctx, album_y)

	await v8_res_light_stars(ctx, star_nodes, stars)
	if not is_inside_tree():
		return
	Sfx.say(partner, "win")
	if _v8_res_bust and is_instance_valid(_v8_res_bust):
		V8Art.bust_bounce(_v8_res_bust, 0.03)
	_v9_roll(gl, reward + gained, 0.75)
	if reward + gained > 0:
		main.fly_gems(global_position + plate.position + rr.position + Vector2(46, 42), 8)
	if rank_box:
		await _animate_rank(rank_box)
	Sfx.music("menu")
	if first_unlock_summon:
		await get_tree().create_timer(1.6).timeout
		if is_inside_tree():
			_summon_unlocked()

# 0.8: with no heroine bust in the band under a short panel (no room for her face), the ribbon and the panel
# move down so the panel ends 24 px above the «Повтор» / «Фото» row instead of leaving the board showing through
func _v8_res_settle(ctx: Dictionary, album_y: float) -> void :
	if _v8_res_bust != null and is_instance_valid(_v8_res_bust):
		return
	if ctx.has("hero") and is_instance_valid(ctx.hero) and (ctx.hero as CanvasItem).visible:
		return
	var free: float = (float(ctx.by) - 76.0) - float(ctx.plate_end)
	if free <= 48.0:
		return
	var d: = free - 24.0
	var plate: Control = ctx.plate
	plate.position.y += d
	(ctx.rib as Control).position.y += d * 0.5
	ctx["plate_end"] = float(ctx.plate_end) + d
	if album_y >= 0.0:
		for c in (ctx.root as Control).get_children():
			if c is RBox and c.get_node_or_null("Hit") != null:
				(c as Control).position.y += d

# Блиц: the score, clean tables, record, crystals, then the rank bar and league line
func _blitz_result(record: bool, best: int, gems: int, ba: Dictionary) -> void :
	var ctx: = v8_res_open(V6Txt.s("play.time_up"))
	v8_res_big(ctx, str(blitz_score), "очки блица")
	v8_res_line(ctx, V6Txt.s("play.boards") % boards_done, 20, UI.INK, 2.0)
	v8_res_line(ctx, V6Txt.s("play.record_new") if record else V6Txt.s("play.record") % best, 22, Color("ffd34d") if record else Color("d9c4e6"))
	if gems > 0:
		v8_res_reward(ctx, gems)
	v8_res_rank(ctx, ba)
	if record:
		ctx["emo"] = "surprised"
	v8_res_close(ctx, partner, V6Txt.s("common.again"), func(): main.go("play", {"mode": "blitz", "partner": partner, "retry": randi()}),
		V6Txt.s("common.to_home"), func(): main.go("home"))
	if gems > 0:
		main.fly_gems(global_position + Vector2(W * 0.5, 420), 6)

const V8_HERO_H: = 760.0
const V8_HERO_DROP: = 250.0

# album chip, replay and photo buttons (V7Photo.victory_hook) moved into the column under the plate
# shard progress on a result window: the heroine's round portrait, «Осколок портрета · Рин», a 5-pip bar and «2/5»
# (not a full-width gold capsule, which read as a finished bar right above the rank bar)
func _v8_shard_line(parent: Control, sh: String, have: int, r: Rect2) -> void :
	var row: = Control.new()
	row.position = r.position
	row.size = r.size
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	row.add_child(Common.avatar(sh, Rect2(2, 0, 40, 40), "gold"))
	var full: = have >= G.SHARDS_NEED
	var pip_w: = 26.0
	var pip_gap: = 6.0
	var cnt_w: = 52.0
	var pips_w: = G.SHARDS_NEED * pip_w + (G.SHARDS_NEED - 1) * pip_gap
	var px: = r.size.x - cnt_w - pips_w
	var t: = "Портрет собран: %s" % G.HEROES[sh].name if full else "Осколок портрета · %s" % G.HEROES[sh].name
	var l: = UI.label(t, 18, Color("ffd98a") if full else Color.WHITE, UI.DARK, 3, "body", 900)
	l.position = Vector2(52, 0)
	l.size = Vector2(px - 52 - 10, r.size.y)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(l)
	for i in G.SHARDS_NEED:
		var on: = i < have
		var pip: = UI.rbox("gold" if on else "glass", Rect2(px + i * (pip_w + pip_gap), 13, pip_w, 14), 7, 2, 2)
		if not on:
			pip.colors(Color(0.16, 0.14, 0.18, 0.9), Color(0.1, 0.08, 0.11, 0.9))
		row.add_child(pip)
		if on and i == have - 1:
			UI.pop_in(pip, 0.9, 0.3)
	var cl: = UI.label("%d/%d" % [have, G.SHARDS_NEED], 20, Color("ffd98a"), UI.DARK, 3, "body", 900)
	cl.position = Vector2(r.size.x - cnt_w + 6, 0)
	cl.size = Vector2(cnt_w - 6, r.size.y)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(cl)

func _v8_photo_row(root: Control, stars: int, secs: float, plate_end: float, by: float, album_at: = Vector2(-1, -1), album_w: = 0.0) -> void :
	var n0: = root.get_child_count()
	V7Photo.victory_hook(self, root, stars, secs)
	var btns: = []
	var chip: Control = null
	for i in range(n0, root.get_child_count()):
		var c: = root.get_child(i)
		if c is JButton:
			btns.append(c)
		elif c is Control and chip == null:
			chip = c
	var row_y: = by - 76.0
	# 0.8: the album chip and the replay / photo row keep to the left column; the right column under the plate
	# is the heroine's (her face must never sit behind the chip)
	if chip and album_at.x >= 0.0:
		chip.position = album_at
		_v8_span_chip(chip, album_w)
	elif chip:
		chip.position = Vector2(16, minf(plate_end + 12.0, row_y - 54.0))
		_v8_narrow_chip(chip, V8_LEFT_COL)
	var x0: = 16.0
	for b in btns:
		var jb: JButton = b
		jb.position = Vector2(x0, row_y)
		x0 += jb.size.x + V8_RES_GAP

# 0.8: the in-panel album chip spans the content column like the rank and league rows (V8_RES_PAD … pw − PAD):
# the star sits inside its left cap, the label after it, the claim badge on the right edge
func _v8_span_chip(chip: Control, w: float) -> void :
	var h: = chip.size.y
	chip.size.x = w
	if chip is RBox:
		(chip as RBox).size = Vector2(w, h)
	var x0: = 12.0
	for c in chip.get_children():
		if c is TextureRect and (c as Control).position.x < 0.0:
			var ic: Control = c
			ic.position = Vector2(6, (h - (h + 4.0)) * 0.5)
			ic.size = Vector2(h + 4.0, h + 4.0)
			x0 = 6.0 + h + 4.0 + 6.0
	for c in chip.get_children():
		if not c is Control:
			continue
		var cc: Control = c
		if cc.name == "L":
			cc.position.x = x0
			cc.size.x = w - x0 - 52.0
		elif cc.name == "Hit":
			cc.size.x = w
		elif cc is RBox:
			# the claim badge (Common.badge): on the chip's right end, inside the panel
			cc.position = Vector2(w - 42.0, (h - cc.size.y) * 0.5)

const V8_LEFT_COL: = 440.0
const V8_RES_COL1: = 250.0
const V8_RES_GAP: = 10.0

func _v8_narrow_chip(chip: Control, w: float) -> void :
	if chip.size.x <= w:
		return
	chip.size.x = w
	var l = chip.get_node_or_null("L")
	if l is Label:
		var lb: Label = l
		lb.size.x = w - lb.position.x - 10.0
		var fs: = int(lb.label_settings.font_size) if lb.label_settings else 18
		var f: = UI.font("body", 900)
		while fs > 16 and f.get_string_size(lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > lb.size.x:
			fs -= 1
		if lb.label_settings:
			lb.label_settings.font_size = fs
		lb.clip_text = true
	for c in chip.get_children():
		if c is Control and c.name == "Hit":
			(c as Control).size.x = w
		elif c != l and c is Control and (c as Control).position.x > w - 40.0:
			(c as Control).position.x = w - 26.0

# the heroine of a result window: her face in the free column right of the content, between `top` (the end of
# the content above) and `bottom` (the top of the buttons). No room for the whole face: she is not shown, so
# the window never has a body with the face covered.
func _v8_place_hero(vh: Hero, hid: String, top: float, bottom: float) -> void :
	var rig: Dictionary = Hero.RIGS[hid] if Hero.RIGS.has(hid) else Hero.RIGS["mc"]
	var sc: float = V8_HERO_H / 1160.0
	var head_c: Vector2 = rig.head_c
	var feet: Vector2 = rig.feet
	var hr: float = rig.head_r
	var face_top: = (head_c.y - hr * 0.75 - feet.y) * sc
	var chin: = (head_c.y + hr * 0.8 - feet.y) * sc
	var y: = maxf(H + V8_HERO_DROP, top + 8.0 - face_top)
	if y + chin > bottom - 4.0:
		vh.visible = false
		return
	var hx: = (V8_LEFT_COL + 16.0 + W) * 0.5
	vh.position = Vector2(clampf(hx - (head_c.x - feet.x) * sc, 0.0, W), y)
	UI.slide_in(vh, Vector2(120, 0), 0.2, 0.6)

func _v8_rank_block(parent: Control, r: Rect2) -> Control:
	var before: = G.rank_of(rp_before)
	var after: = G.rank_of(int(G.S.rp))
	var up: = rank_ups.size() > 0
	var opened: = V8PlayRules.modes_opened(rp_before, int(G.S.rp)) if up else []
	var h: = 112.0 + (46.0 if up else 0.0) + (40.0 if not opened.is_empty() else 0.0)
	var box: = UI.rbox("glass", Rect2(r.position, Vector2(r.size.x, h)), 24, 3, 8)
	box.borders(Color("ffe7a6"), Color("c58a2c"))
	parent.add_child(box)
	var em: = Common.rank_emblem(box, Rect2(12, 12, 84, 84), after.tier, after.sub)
	em.name = "Em"
	var tl: = UI.label(after.title, 26, Color("fff1dc"), UI.DARK, 3, "body", 900)
	tl.position = Vector2(108, 6)
	tl.size = Vector2(r.size.x - 108 - 196, 36)
	tl.clip_text = true
	box.add_child(tl)
	# 0.9: the gain rolls up from +0 while the bar fills (_animate_rank)
	var gl: = UI.label(V8PlayRules.T.rank_gain % [0, V8PlayRules.points_word(0)] if rp_gain > 0 else V8PlayRules.T.rank_gain % [rp_gain, V8PlayRules.points_word(rp_gain)], 19, Color("ffd34d"), UI.DARK, 3, "body", 900)
	gl.position = Vector2(r.size.x - 206, 10)
	gl.size = Vector2(192, 30)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(gl)
	box.set_meta("gain_lbl", gl)
	var bw: = r.size.x - 108 - 16
	var f0: = 0.0 if up else clampf(float(before.into) / maxf(1.0, before.need), 0.0, 1.0)
	var f1: = clampf(float(after.into) / maxf(1.0, after.need), 0.0, 1.0)
	var bar: = Common.progress_bar(box, Rect2(108, 46, bw, 22), f0, "gold")
	var sub_t: = (V8PlayRules.T.rank_was % [before.title, int(before.into), int(before.need)]) + "   ·   " + (V8PlayRules.T.rank_now % [after.title, int(after.into), int(after.need)]) if up else (V8PlayRules.T.rank_now % [after.title, int(after.into), int(after.need)])
	var sub: = UI.label(sub_t, 16, UI.MUTED, UI.DARK, 2, "body", 800)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.position = Vector2(108, 74)
	sub.size = Vector2(bw, 26)
	sub.clip_text = true
	box.add_child(sub)
	if up:
		var gems: = 0
		for u in rank_ups:
			gems += int(u.gems)
		var pill: = UI.rbox("gold", Rect2(12, 108, r.size.x - 24, 38), 19, 2, 4)
		box.add_child(pill)
		pill.add_child(UI.center_label(UI.label("Новый ранг: %s · +%s" % [after.title, gems_text(gems)], 19, Color("3f2808"), Color(0, 0, 0, 0), 0, "body", 900), Rect2(0, 0, r.size.x - 24, 38)))
		pill.modulate.a = 0.0
		box.set_meta("pill", pill)
		if not opened.is_empty():
			var ol: = UI.center_label(UI.label(V8PlayRules.T.mode_open % ", ".join(opened), 18, Color("a9d9c4"), UI.DARK, 3, "body", 900), Rect2(12, 150, r.size.x - 24, 32))
			ol.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			box.add_child(ol)
	box.set_meta("bar", bar)
	box.set_meta("bar_w", bw - 6.0)
	box.set_meta("f1", f1)
	return box

# weekly league + quarter, two lines. Week points come from the tournament tables only, so with none yet the
# row says where they come from instead of showing a bare last place.
func _v8_league_row(parent: Control, r: Rect2, li: Dictionary, week_gain: = 0) -> void :
	var row: = UI.rbox("glass", r, 24, 2, 6)
	parent.add_child(row)
	# 0.8: the weekly league crest (league/*), not the rank medallion and not a generic trophy
	var wk = V8League.my_week()
	var ltier: = int((wk as Dictionary).get("league_tier", 0)) if wk is Dictionary else 0
	Common.league_emblem(row, Rect2(6, (r.size.y - 52) * 0.5, 52, 52), ltier)
	var col: Color = li.color if li.color is Color else Color("ffd98a")
	var t1: String
	if int(li.get("points", 0)) <= 0:
		t1 = V8PlayRules.T.league_none % [li.league_name, int(li.place), int(li.group_size)]
	else:
		t1 = V8PlayRules.T.league % [li.league_name, int(li.place), int(li.group_size)]
		if week_gain > 0:
			t1 += V8PlayRules.T.league_gain % [week_gain, V8PlayRules.points_word(week_gain)]
	var a: = UI.label(t1, 18, col.lightened(0.2), UI.DARK, 3, "body", 900)
	a.position = Vector2(60, 4)
	a.size = Vector2(r.size.x - 72, 26)
	a.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	a.clip_text = true
	row.add_child(a)
	# near the bottom of the quarter table (a new player) the row says what the points are for, not «1001 из 1001»
	var qt: = int(li.get("q_total", 1001))
	var t2: String = V8PlayRules.T.quarter % [UI.fmt(int(li.q_place)), UI.fmt(qt)] if V8League.quarter_shown({"place": int(li.q_place), "total": qt}) else V8League.Q_HIDDEN
	# 0.8: the rank card right above already says «+N очков ранга»; the league line does not repeat it
	var b: = UI.label(t2, 16, Color("a9d9c4"), UI.DARK, 3, "body", 900)
	b.position = Vector2(60, 30)
	b.size = Vector2(r.size.x - 72, 24)
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.clip_text = true
	row.add_child(b)

# compact yaku: one wrapped row of chips «Риичи +10»; returns the y under it
func _v8_yaku_chips(parent: Control, x: float, y: float, w: float) -> float:
	var hd: = UI.label(V8PlayRules.T.yaku_head, 16, Color("ffd98a"), UI.DARK, 2, "body", 900)
	hd.position = Vector2(x + 6, y)
	parent.add_child(hd)
	y += 24
	if yaku_list.is_empty():
		var nl: = UI.label(V8PlayRules.T.no_yaku, 17, UI.MUTED)
		nl.position = Vector2(x + 6, y)
		nl.size = Vector2(w - 12, 26)
		nl.clip_text = true
		parent.add_child(nl)
		return y + 28
	var f: = UI.font("body", 900)
	var cx: = x
	var rows: = 1
	# 0.8: the chips add up to the rank points of the bar: «Победа +N» (stars / difficulty) and then each yaku
	var parts: = []
	var ysum: = 0
	for yk in yaku_list:
		ysum += _yaku_rp(yk)
		parts.append("%s  +%d" % [_yaku_name(yk), _yaku_rp(yk)])
	var base: = rp_gain - mini(ysum, V8PlayRules.PATH_YAKU_CAP)
	if base > 0 and ysum <= V8PlayRules.PATH_YAKU_CAP:
		parts.push_front("Победа  +%d" % base)
	for i in parts.size():
		var txt: String = parts[i]
		var cw: = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 30.0
		if cx + cw > x + w and cx > x:
			if rows >= 3:
				break
			rows += 1
			cx = x
			y += 42
		var c: = UI.rbox("plum", Rect2(cx, y, cw, 36), 18, 2, 4)
		c.borders(Color("ffe7a6"), Color("8a6a3a"))
		# the room the stamp may take while it is scaled: from just past the chip before it (or the block's left
		# side) to the block's right side (_v9_stamp_chip)
		c.set_meta("yaku_lo", x if cx <= x else cx - 6.0)
		c.set_meta("yaku_hi", x + w)
		parent.add_child(c)
		c.add_child(UI.center_label(UI.label(txt, 17, Color("ffe7a6"), UI.DARK, 2, "body", 900), Rect2(0, 0, cw, 36)))
		# 0.9: stamped one by one on the beat (V9_YAKU_BEAT), from _v9_yaku_at (the victory sets it after the bar)
		c.modulate.a = 0.0
		var tw: Tween = c.create_tween()
		tw.tween_interval(_v9_yaku_at + i * V9_YAKU_BEAT)
		tw.tween_callback(_v9_stamp_chip.bind(c, i))
		cx += cw + 8.0
	return y + 36

func _animate_rank(box: Control) -> void :
	if not is_inside_tree() or mode == "trial":
		return
	await get_tree().create_timer(0.2).timeout
	if not is_inside_tree() or not is_instance_valid(box):
		return
	var fill: Control = box.get_meta("bar")
	if fill:
		# 0.9: the bar fills with sparks at its tip while «+N очков ранга» rolls up, then a shimmer runs along it
		var w: float = maxf(fill.size.y, float(box.get_meta("bar_w")) * float(box.get_meta("f1")))
		var tw: = fill.create_tween()
		tw.tween_method(_v9_rank_fill.bind(box, fill, fill.size.x, w, [0.0, -1]), 0.0, 1.0, V9_RANK_FILL).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_v9_rank_done.bind(box, fill))
	if rank_ups.size() > 0:
		var up: Dictionary = rank_ups[-1]
		var em: Control = box.get_node_or_null("Em")
		if em:
			UI.pop_in(em, 0.0, 2.0)
			Fx.burst(box, em.position + em.size * 0.5, "sparkle", 40, G.RANKS[int(up.tier)].color, 1.4)
		var pill: Control = box.get_meta("pill", null)
		if pill:
			pill.create_tween().tween_property(pill, "modulate:a", 1.0, 0.25)
			UI.pop_in(pill, 0.0, 0.8)
		Sfx.play("reveal_ssr" if int(up.sub) == 0 else "reveal_sr")
		Sfx.say(partner, "rankup")
		_v8_res_react("surprised", 1.6)
	await get_tree().create_timer(0.6).timeout

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
	var s: = UI.center_label(UI.label(V6Txt.s("play.unlock_d"), 19, Color("ffe7c4"), UI.DARK, 3, "body", 800), Rect2(20, 330, 620, 30))
	p.add_child(s)
	Sfx.play("reveal_sr")
	Fx.burst(p, Vector2(330, 190), "sparkle", 60, Color(1, 0.85, 0.5), 1.6)
	# the ten wishes are a gift: the wishes glyph (nav/wishes), not a gem that would read as a price; primary-art CTA
	unlock_go_btn = JButton.make(V6Txt.s("play.unlock_go"), "pink", Rect2(130, 410, 400, 100), V8Art.nav("wishes"), 36)
	unlock_go_btn.icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	unlock_go_btn.shine_every = 1.6
	unlock_go_btn.pulse = true
	unlock_go_btn.pressed.connect( func(): main.go("summon", {"banner": 1}))
	p.add_child(unlock_go_btn)

func dev_act(a: String) -> void :
	match a:
		"tapcard":
			# a tap on the portrait card (the same signal a finger sends)
			print("TAPCARD ready=%s input_on=%s busy=%s" % [skill_ready, board.input_on, ult.busy])
			stage.pressed.emit()
		"dealtap":
			# a real touch on a tile while the deal is still landing (the deal-skip check)
			var dt: Tile = null
			for t in board.tiles:
				if board.on_board(t):
					dt = t
			print("DEALTAP dealing=%s input_on=%s" % [board.dealing, board.input_on])
			if dt:
				var ev: = InputEventScreenTouch.new()
				ev.pressed = true
				ev.position = board.tile_layer.get_global_transform_with_canvas() * dt.home
				Input.parse_input_event(ev)
			var t0: = now()
			while board.dealing and now() - t0 < 3.0:
				await get_tree().process_frame
			print("DEALTAP table open after %.2f s" % (now() - t0))
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
		"toast":
			main.toast("Под фишкой подарок: 64 кристалла", "gem")
		"setband":
			_yaku_banner(G.CATS[0][2], V6Txt.s("play.set3") + G.CATS[0][3])
		"timeup":
			blitz_left = 0.01
		"cutin":
			_cutin()
		"emo_combo":
			stage.flash_emotion(_v8_combo_emotion(5))
		"emo_pout":
			stage.flash_emotion("pout")
		"emo_sad":
			stage.flash_emotion("sad")
		"duel_lose":
			if duel:
				duel.her += 4
				duel.finish()


# ---- 0.9 victory juice (spec §D): stamped stars and yaku, rolling counters, a shimmering rank bar ---------------
# Rhythm: stars from V9_STAR_AT, one per V9_BEAT → the reward rolls (V9_ROLL) → the rank bar fills (V9_RANK_FILL)
# → the yaku chips are stamped one per V9_YAKU_BEAT. Decor follows «Эффекты» (Fx.burst / ring scale or skip by
# themselves; panel dip at «полные» only, glows and shimmer not at «минимум»); the stamp, the sound and the haptic
# always play. Everything here is inside the result window: the match is over, the table takes no taps.
# Dev: --v9_win_shots=0.3,0.9,… --shots=<dir> [--name=n] saves <dir>/<n>_w<ms>.png that many seconds after the
# victory window opens (use with --v8_win=1 [--v8_yaku=1] [--v8_rankup=1]); --v9_win_quit=1 quits after the last;
# --v9_fx=full|mid|min sets «Эффекты» for the run (dev saves go to a separate file).
const V9_STAR_AT: = 0.6
const V9_BEAT: = 0.3
const V9_SLAM: = 0.13
const V9_ROLL: = 0.75
const V9_RANK_FILL: = 0.85
const V9_YAKU_BEAT: = 0.22
const V9_GOLD: = Color(1, 0.85, 0.4)
var _v9_yaku_at: = 1.3

func _v9_fx_sound(n: String, pitch: = 1.0, db: = 0.0) -> void :
	var fx: = get_node_or_null("/root/V6Fx")
	if fx and fx.has_method("sound"):
		fx.sound(n, pitch, db)

# a node's centre in the coordinates of `space` (both under the same unscaled canvas)
func _v9_centre_in(n: Control, space: Control) -> Vector2:
	var xf: = space.get_global_transform_with_canvas().affine_inverse() * n.get_global_transform_with_canvas()
	return xf * (n.size * 0.5)

func _v9_stamp_star(ctx: Dictionary, s: TextureRect, i: int, last: bool) -> void :
	if not is_instance_valid(s):
		return
	s.pivot_offset = s.size * 0.5
	s.texture = V8Art.star(true)
	s.modulate.a = 0.0
	s.scale = Vector2.ONE * 2.3
	s.rotation = -0.3 if i != 1 else 0.3
	var t: = s.create_tween().set_parallel()
	t.tween_property(s, "scale", Vector2.ONE * 0.9, V9_SLAM).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(s, "modulate:a", 1.0, V9_SLAM * 0.6)
	t.tween_property(s, "rotation", 0.0, V9_SLAM).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(_v9_star_impact.bind(ctx, s, i, last))
	t.chain().tween_property(s, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_v9_fx_sound("swoosh", 1.35 + 0.08 * i, -16.0)

func _v9_star_impact(ctx: Dictionary, s: TextureRect, i: int, last: bool) -> void :
	if not is_inside_tree() or not is_instance_valid(s):
		return
	var root: Control = ctx.root
	var plate: Control = ctx.plate
	var c: = _v9_centre_in(s, root)
	Sfx.play("star%d" % mini(i, 2))
	_v9_fx_sound("thump", 1.15 - 0.06 * i, -5.0)
	V9Feel.haptic("gold" if last and i >= 2 else "match")
	Fx.ring(root, c, Color(V9_GOLD.r, V9_GOLD.g, V9_GOLD.b, 0.9), 1.0 + 0.18 * i, 0.38)
	Fx.burst(root, c, "sparkle", 18 + 8 * i, V9_GOLD, 1.0 + 0.15 * i)
	if last and i >= 2:
		Fx.flash_glow(root, c, Color(1, 0.8, 0.45), 2.6, 0.45)
	# a warm glow stays under each stamped star and breathes
	if V9Feel.can_fx():
		var g: = TextureRect.new()
		g.texture = G.fx("glow")
		g.material = Fx.add_mat()
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		g.stretch_mode = TextureRect.STRETCH_SCALE
		g.size = s.size * 1.9
		g.position = s.position + s.size * 0.5 - g.size * 0.5
		g.pivot_offset = g.size * 0.5
		g.modulate = Color(1, 0.78, 0.35, 0.0)
		s.get_parent().add_child(g)
		s.get_parent().move_child(g, s.get_index())
		var gt: = g.create_tween()
		gt.tween_property(g, "modulate:a", 0.75, 0.12)
		gt.tween_property(g, "modulate:a", 0.38, 0.5)
		gt.tween_callback( func():
			if is_instance_valid(g):
				var lt: = g.create_tween().set_loops()
				lt.tween_property(g, "modulate:a", 0.5, 1.1).set_trans(Tween.TRANS_SINE)
				lt.tween_property(g, "modulate:a", 0.3, 1.1).set_trans(Tween.TRANS_SINE))
	# the panel takes the hit: a short dip and back
	if V9Feel.can_shake() and is_instance_valid(plate):
		var y0: float = plate.get_meta("v9_y0", plate.position.y)
		plate.set_meta("v9_y0", y0)
		var old = plate.get_meta("v9_dip") if plate.has_meta("v9_dip") else null
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
		plate.position.y = y0
		var dt: = plate.create_tween()
		plate.set_meta("v9_dip", dt)
		dt.tween_property(plate, "position:y", y0 + 3.0 + 2.0 * i, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		dt.tween_property(plate, "position:y", y0, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# a yaku chip stamped onto the panel: drops from up to 1.25×, lands with a click a semitone above the one before.
# 0.9: the stamp is clamped to its slot in the row (yaku_lo … yaku_hi, set by _v8_yaku_chips): the start scale
# shrinks to what that slot holds and the pivot slides so the scaled chip never covers the chip stamped before it,
# the panel's left frame or the block's right side; a long chip alone in its row drops without the tilt
const V9_STAMP_FROM: = 1.25

func _v9_stamp_chip(c: Control, i: int) -> void :
	if not is_instance_valid(c) or not is_inside_tree():
		return
	var w: = c.size.x
	var lo: = float(c.get_meta("yaku_lo", c.position.x))
	var hi: = float(c.get_meta("yaku_hi", c.position.x + w * V9_STAMP_FROM))
	# the scaled box is (left = x − p·(s−1), right = x + w·s − p·(s−1)); keep both inside [lo, hi]
	var s0: = clampf((hi - lo) / maxf(w, 1.0), 1.0, V9_STAMP_FROM)
	var px: = w * 0.5
	if s0 > 1.001:
		var p_min: = (c.position.x + w * s0 - hi) / (s0 - 1.0)
		var p_max: = (c.position.x - lo) / (s0 - 1.0)
		px = clampf(w * 0.5, maxf(0.0, p_min), minf(w, maxf(p_max, 0.0)))
	c.pivot_offset = Vector2(px, c.size.y * 0.5)
	c.scale = Vector2.ONE * s0
	# the tilt lifts a corner by w/2·sin(r) ≤ 1.5 px: with the 4.5 px of the 1.25× scale it stays inside the 6 px
	# row gap, so a stamp never touches the row above or below
	c.rotation = (-1.0 if i % 2 == 0 else 1.0) * minf(0.035, 3.0 / maxf(w, 1.0))
	var t: = c.create_tween().set_parallel()
	t.tween_property(c, "scale", Vector2.ONE * 0.94, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(c, "modulate:a", 1.0, 0.07)
	t.tween_property(c, "rotation", 0.0, 0.11)
	t.chain().tween_callback( func():
		if not is_instance_valid(c):
			return
		Sfx.play("star%d" % mini(i, 2), 1.1 * Sfx.combo_pitch(i + 1), -5.0)
		_v9_fx_sound("thump", 1.3, -12.0)
		V9Feel.haptic("select")
		var par: Node = c.get_parent()
		var at: = c.position + c.size * 0.5
		Fx.ring(par, at, Color(1, 0.9, 0.6, 0.6), 0.36 + c.size.x / 700.0, 0.28)
		Fx.burst(par, at, "sparkle", 8, Color(1, 0.9, 0.6), 0.7))
	t.chain().tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# a rolling counter: «+0» → «+to» with an ease-out, a tick a few times a second (rising), a punch and sparks at
# the end. fmt gets the formatted number (UI.fmt: 1 240).
func _v9_roll(l: Label, to: int, dur: = V9_ROLL, fmt: = "+%s") -> void :
	if not is_instance_valid(l):
		return
	l.text = fmt % "0"
	if to <= 0:
		return
	var st: = [-1, -1.0]
	var step: = func(k: float) -> void :
		var v: = int(round(to * k))
		if v == int(st[0]):
			return
		st[0] = v
		l.text = fmt % UI.fmt(v)
		var now_t: = Time.get_ticks_msec() / 1000.0
		if now_t - float(st[1]) >= 0.055:
			st[1] = now_t
			_v9_fx_sound("tick", 0.95 + 0.45 * k, -9.0)
	var tw: = l.create_tween()
	tw.tween_method(step, 0.0, 1.0, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback( func():
		if not is_instance_valid(l):
			return
		l.text = fmt % UI.fmt(to)
		_v9_fx_sound("reward_pop", 1.0, -6.0)
		V9Feel.haptic("match")
		# punch from the left edge: the number is left-aligned, so it swells in place
		l.pivot_offset = Vector2(0, l.size.y * 0.5)
		var pt: = l.create_tween()
		pt.tween_property(l, "scale", Vector2.ONE * 1.2, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pt.tween_property(l, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		var f: = l.get_theme_font("font") if l.label_settings == null else l.label_settings.font
		var fs: = l.label_settings.font_size if l.label_settings else 40
		var tw_x: = f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if f else 80.0
		Fx.burst(l.get_parent(), l.position + Vector2(tw_x * 0.5, l.size.y * 0.5), "sparkle", 16, Color(1, 0.8, 0.9), 0.9))

func _v9_rank_fill(k: float, box: Control, fill: Control, w0: float, w1: float, st: Array) -> void :
	if not is_instance_valid(fill) or not is_instance_valid(box):
		return
	fill.size.x = lerpf(w0, w1, k)
	var gl = box.get_meta("gain_lbl") if box.has_meta("gain_lbl") else null
	if is_instance_valid(gl) and gl is Label and rp_gain > 0:
		var v: = int(round(rp_gain * k))
		if v != int(st[1]):
			st[1] = v
			(gl as Label).text = V8PlayRules.T.rank_gain % [v, V8PlayRules.points_word(v)]
	# sparks off the tip of the bar while it moves, a soft tick with them
	var now_t: = Time.get_ticks_msec() / 1000.0
	if k < 0.98 and now_t - float(st[0]) >= 0.06 and w1 > w0 + 2.0:
		st[0] = now_t
		var bg: Control = fill.get_parent()
		var tip: = bg.position + fill.position + Vector2(fill.size.x - 2.0, fill.size.y * 0.5)
		Fx.burst(box, tip, "sparkle", 4, Color(1, 0.88, 0.5), 0.55)
		_v9_fx_sound("tick", 1.1 + 0.5 * k, -13.0)

func _v9_rank_done(box: Control, fill: Control) -> void :
	if not is_instance_valid(fill) or not is_instance_valid(box):
		return
	var bg: Control = fill.get_parent()
	var tip: = bg.position + fill.position + Vector2(fill.size.x - 2.0, fill.size.y * 0.5)
	Fx.ring(box, tip, Color(1, 0.88, 0.5, 0.85), 0.7, 0.32)
	Fx.burst(box, tip, "sparkle", 12, Color(1, 0.88, 0.5), 0.8)
	Sfx.play("sparkle", 1.15, -6.0)
	var gl = box.get_meta("gain_lbl") if box.has_meta("gain_lbl") else null
	if is_instance_valid(gl) and gl is Label:
		UI.punch(gl, 0.14)
	_v9_shimmer(fill)

# a band of light that runs along a filled bar every couple of seconds (decor: not at «минимум»)
func _v9_shimmer(fill: Control) -> void :
	if not V9Feel.can_fx() or not is_instance_valid(fill) or fill.size.x < 30.0:
		return
	fill.clip_contents = true
	var g: = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 0.98, 0.85, 0.75), Color(1, 1, 1, 0)])
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 4
	var sh: = TextureRect.new()
	sh.name = "V9Shimmer"
	sh.texture = gt
	sh.material = Fx.add_mat()
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.size = Vector2(64, fill.size.y)
	sh.position = Vector2(-70, 0)
	fill.add_child(sh)
	var t: = sh.create_tween().set_loops()
	t.tween_property(sh, "position:x", fill.size.x + 6.0, 0.75).from(-70.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_interval(1.6)

func _v9_win_dev() -> void :
	var a: = {}
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--") and "=" in x:
			var kv: = x.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	if not (a.has("v9_win_shots") and a.has("shots")):
		return
	var times: = Array(String(a.v9_win_shots).split(",")).map( func(x): return float(x))
	var t0: = 0.0
	for t in times:
		await get_tree().create_timer(maxf(0.0, t - t0)).timeout
		t0 = t
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_w%04d.png" % [a.shots, a.get("name", "win"), int(t * 1000.0)])
		print("V9WIN shot %.2f" % t)
	if a.get("v9_win_quit", "") == "1":
		get_tree().quit()
