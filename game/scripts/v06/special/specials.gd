class_name V6Specials
extends Node





const NAMES: = {
	"gift": ["Шкатулка", "Собери пару фишек с коробочкой: внутри случайный подарок."],  # v10-clarity: no «бант» (a tile picture) 
	"lock": ["Замок и ключ", "Фишку под замком не взять. Собери пару с ключом того же цвета, и замки откроются."], 
	"chain": ["Цепь", "Число на цепи: сколько пар убрать с поля, и она спадёт сама."], 
	"joker": ["Джокер", "Встаёт в пару к любой фишке в лотке. Второй джокер станет её двойником."], 
	"bomb": ["Хлопушка", "Собери пару с хлопушкой, и она снесёт до трёх соседних пар."], 
}
const EVENTS: = {
	"starfall": ["Звездопад", "10 секунд каждая пара даёт втрое больше"], 
	"giftdrop": ["Подарок с неба", "Собери пару с коробочкой"], 
	"wind": ["Попутный ветер", "Ветер уносит две пары"], 
	"golden": ["Золотой дождь", "Три пары стали золотыми"], 
	"challenge": ["Вызов Маджонг-тян", "Собери 3 пары за 12 секунд"], 
}
const STREAK_STEP: = 6

var play
var board: V6SpecialBoard
var plan: = {}
var event_at: = -1
var event_done: = false
var streak: = 0
var star_until: = -1.0
var star_bonus: = 0.0
var ch_until: = -1.0
var ch_count: = 0
var ch_pill: Control
var ch_lbl: Label
var blocked_tips: = 0


static func hook(p) -> void :
	if not (p.board is V6SpecialBoard):
		return
	var c: V6Specials = p.get_node_or_null("V6Specials")
	if c == null:
		c = V6Specials.new()
		c.name = "V6Specials"
		c.play = p
		p.add_child(c)
	c.bind(p.board)

static func data() -> Dictionary:
	if not G.S.has("v6_special"):
		G.S["v6_special"] = {"seen": {}, "events": 0, "gifts": 0}
	return G.S["v6_special"]


static func plan_for(cfg: Dictionary, mode: String) -> Dictionary:
	var p: = {"gift": 0, "lock": 0, "lock_n": 1, "chain": 0, "joker": 0, "bomb": 0, "event": false, "streak": true, "pool": ["starfall", "giftdrop"]}
	for a in OS.get_cmdline_user_args():
		if a == "--special=off":
			p.streak = false
			return p
		if a.begins_with("--special=") and mode == "":

			var ks: = a.substr(10).split(",")
			for k in ["gift", "lock", "chain", "joker", "bomb"]:
				if k in ks or "all" in ks:
					p[k] = 1
			p.lock_n = 2
			p.event = "event" in ks or "all" in ks
			p.pool = ["starfall", "giftdrop", "wind", "golden", "challenge"]
			return p
	if mode == "blitz":
		p.gift = 1
		p.bomb = 1
		p.streak = false
		return p
	if mode == "zen":
		p.gift = 1
		p.joker = 1
		return p
	if not mode in ["", "daily", "trial"]:
		p.gift = 1
		return p
	var parts: = str(cfg.get("code", "")).split("-")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		p.gift = 1
		return p
	var w: = int(parts[0])
	var s: = int(parts[1])
	var boss: = bool(cfg.get("boss", false))
	match w:
		1:
			if s == 1:
				p.streak = false
				return p
			p.gift = 1 if s < 5 else 2
			p.event = s >= 3
		2:
			p.gift = 1
			p.lock = 1
			p.lock_n = 1 if s < 4 else 2
			p.event = true
			p.pool = ["starfall", "giftdrop", "wind"]
		3:
			p.gift = 1
			p.chain = 1 if s < 4 else 2
			p.lock = 1 if s % 2 == 0 else 0
			p.event = true
			p.pool = ["starfall", "giftdrop", "wind", "golden", "challenge"]
		4:
			p.gift = 1
			p.joker = 1
			p.chain = 1 if s % 2 == 1 else 0
			p.lock = 1 if s % 2 == 0 else 0
			p.event = true
			p.pool = ["starfall", "giftdrop", "wind", "golden", "challenge"]
		5:
			p.gift = 1
			p.bomb = 1 if s < 5 else 2
			p.joker = s % 2
			p.lock = 1 if s % 2 == 0 else 0
			p.chain = 1 if s % 2 == 1 else 0
			p.event = true
			p.pool = ["starfall", "giftdrop", "wind", "golden", "challenge"]
		_:
			p.gift = 1
			p.lock = 1
			p.lock_n = 2
			p.chain = 1 + int(s >= 4)
			p.joker = 1
			p.bomb = 1
			p.event = true
			p.pool = ["starfall", "giftdrop", "wind", "golden", "challenge"]
	if boss:
		p.gift += 1
		match w:
			2: p.lock_n += 1
			3: p.chain += 1
			5: p.bomb += 1
			6: p.lock += 1
	return p

func _mode() -> String:
	return str(play.get("mode")) if "mode" in play else ""

func bind(b: V6SpecialBoard) -> void :
	board = b
	var tut: bool = play.get("tut") if "tut" in play else false
	plan = plan_for(play.cfg if "cfg" in play else {}, _mode())
	if tut:
		plan = {"streak": false}
	board.apply_specials(plan)
	board.special.connect(_on_special)
	board.matched.connect(_on_matched)
	board.denied.connect( func(_t): _break_streak())
	board.failed.connect(_break_streak)
	board.tray_changed.connect( func():
		if board.tray.size() >= 3:
			_break_streak())
	streak = 0
	event_done = not plan.get("event", false)
	var np: = board.tiles.size() / 2
	event_at = int(np * randf_range(0.35, 0.55))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--special_event="):
			event_at = 1
			event_done = false
	_intro_new()

func _process(_dt: float) -> void :
	if board == null or not is_instance_valid(board):
		return
	if star_until > 0.0 and G.time >= star_until:
		_end_starfall()
	if ch_until > 0.0:
		var left: = ch_until - G.time
		if ch_lbl:
			ch_lbl.text = "Вызов: %d/3 · %d с" % [ch_count, maxi(0, ceili(left))]
		if left <= 0.0:
			_end_challenge(false)
	if not event_done and board.input_on and board.pairs_done >= event_at and board.board_count() >= 8:
		event_done = true
		_fire_event()


func _fx() -> Node:
	return play.fx_layer if "fx_layer" in play and play.fx_layer else play

func _gems(n: int, pos: Vector2) -> void :
	if _mode() == "trial":
		return
	G.S.gems += n
	if "gained" in play:
		play.gained += n
	if play.main and play.main.has_method("fly_gems"):
		play.main.fly_gems(pos, clampi(n / 15, 2, 8))

func _need() -> int:
	return int(play.SKILL_NEED) if "SKILL_NEED" in play else 8

func _refresh() -> void :
	if play.has_method("_refresh"):
		play._refresh()

func _toast(text: String, icon: = "gift") -> void :
	if play.main and play.main.has_method("toast"):
		play.main.toast(text, icon)

func _banner(title: String, sub: String, pal: = "gold") -> void :
	# 0.9: never over the tiles — a one-line plaque in the play screen's band slot under the board
	if play.has_method("v8_notice"):
		if play.v8_notice(title + ((" · " + sub) if sub != "" else "")):
			return
	var W: float = play.size.x
	var H: float = play.size.y
	var rib: = Common.ribbon(play, title, Rect2(W * 0.5 - 250, H * 0.42, 500, 84), pal, 36)
	rib.z_index = 40
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rib.pivot_offset = rib.size * 0.5
	if sub != "":
		var l: = UI.center_label(UI.label(sub, 22, Color.WHITE, Color("3f1a3a"), 6, "body", 900), Rect2(-60, 88, 620, 40))
		rib.add_child(l)
	UI.pop_in(rib, 0.0, 0.3)
	var t: Tween = rib.create_tween()
	t.tween_interval(1.7)
	t.tween_property(rib, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(rib, "scale", Vector2(1.2, 1.2), 0.3)
	t.tween_callback(rib.queue_free)


func _intro_new() -> void :
	var seen: Dictionary = data().seen
	var fresh: Array = board.kinds().filter( func(k): return not seen.has(k))
	if fresh.is_empty():
		return
	while is_inside_tree() and board and is_instance_valid(board) and not board.input_on:
		await get_tree().create_timer(0.2).timeout
	if not is_inside_tree():
		return
	for k in fresh:
		while is_inside_tree() and not get_tree().get_nodes_in_group("v6_tip").is_empty():
			await get_tree().create_timer(0.3).timeout
		if not is_inside_tree():
			return
		seen[k] = true
		_card(k)
		await get_tree().create_timer(6.2).timeout
		if not is_inside_tree():
			return

func _card(kind: String) -> void :
	var W: float = play.size.x
	var H: float = play.size.y
	# 0.8: in the band of the action buttons under the table (play.v8_bottom_card), like the intro tip
	var c: = UI.rbox("cream", Rect2(20, H - 186 - 112, W - 40, 112), 24, 3, 10)
	c.add_to_group("v6_tip")
	c.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.z_index = 35
	play.add_child(c)
	if play.has_method("v8_bottom_card"):
		play.v8_bottom_card(c)

	var holder: = Node2D.new()
	holder.position = Vector2(64, 56)
	holder.scale = Vector2(1.05, 1.05)
	c.add_child(holder)
	var t: = Tile.new()
	t.face = 4 + randi() % 20
	t.build(G.skin_look())
	t.mat.set_shader_parameter("dim", 0.0)
	holder.add_child(t)
	if kind == "joker":
		t.face_spr.visible = false
	t.add_child(V6SpecIcon.new(kind, V6SpecIcon.group_color(0), 5))
	if kind == "lock":
		var t2: = Tile.new()
		t2.face = t.face
		t2.build(G.skin_look())
		t2.mat.set_shader_parameter("dim", 0.0)
		t2.position = Vector2(30, 8)
		t2.scale = Vector2(0.62, 0.62)
		holder.add_child(t2)
		t2.add_child(V6SpecIcon.new("key", V6SpecIcon.group_color(0)))
	var nm: = UI.label("Новинка · " + NAMES[kind][0], 20, Color("ffd977"), UI.DARK, 4, "body", 900)
	nm.position = Vector2(128, 10)
	nm.size = Vector2(W - 200, 28)
	c.add_child(nm)
	var l: = UI.label(NAMES[kind][1], 18, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(128, 40)
	l.size = Vector2(W - 200, 66)
	c.add_child(l)
	UI.slide_in(c, Vector2(0, 40), 0.0, 0.35)
	Sfx.play("pop", 1.1, -4)
	var tw: Tween = c.create_tween()
	tw.tween_interval(3.8)
	tw.tween_property(c, "modulate:a", 0.0, 0.4)
	tw.tween_callback(c.queue_free)


func _on_special(kind: String, d: Dictionary) -> void :
	match kind:
		"gift":
			_open_box(d.pos)
		"blocked":
			var t: Tile = d.tile
			var p: Vector2 = board.tile_layer.get_global_transform_with_canvas() * t.position
			var s: Dictionary = board.spec.get(t, {})
			var txt: = "Нужен ключ" if d.kind == "lock" else "Ещё %d %s" % [int(s.get("n", 0)), V8PlayRules.plural(int(s.get("n", 0)), "пара", "пары", "пар")]
			Fx.float_text(_fx(), p + Vector2(0, -30), txt, Color("ffe7a6"), 24, Color("3f1a3a"))
		"unlock":
			Fx.float_text(_fx(), d.pos + Vector2(0, -40), "Замки открыты!", V6SpecIcon.group_color(int(d.group)).lightened(0.3), 32, Color("3f1a3a"))
			Sfx.play("reveal_r", 1.2, -4)
		"unchain":
			Fx.burst(_fx(), d.pos, "sparkle", 14, Color(0.85, 0.85, 1.0), 0.6)
			Sfx.play("clack1", 0.7, -2)
			Sfx.play("sparkle", 1.2, -6)
		"joker":
			Sfx.play("reveal_sr", 1.4, -6)
		"blast":
			_blast_fx(d)

func _blast_fx(d: Dictionary) -> void :
	for p in d.at:
		Fx.flash_glow(_fx(), p, Color(1.0, 0.7, 0.3), 3.2, 0.4)
		Fx.ring(_fx(), p, Color(1.0, 0.6, 0.3), 2.4, 0.45)
		Fx.burst(_fx(), p, "firework", 40, Color(1.0, 0.65, 0.3), 1.0)
		Fx.burst(_fx(), p, "sparkle", 24, Color(1.0, 0.9, 0.5), 1.2)
	Sfx.play("summon_boom", 1.5, -6)
	Sfx.play("clack0", 0.8, -2)
	Fx.shake(board, 9.0, 0.28)
	var n: int = d.pairs
	if n > 0:
		Fx.float_text(_fx(), d.pos + Vector2(0, -60), "Бабах! +%d пары" % n, Color("ffcf7a"), 38, Color("7a2310"))
		_gems(6 * n, d.pos)
		if "skill_charge" in play and not play.skill_ready:
			play.skill_charge = mini(play.skill_charge + n, _need() - 1)
	_refresh()

func _on_matched(mid: Vector2, combo: int, gold: bool, shard: String) -> void :
	# 0.9: pairs taken by an ult neither feed «Счастливая серия» (whose rewards charge the next ult) nor the
	# 3-pair challenge (spec §B: from_ult pairs do not charge the ult)
	if play and play.get("v9_from_ult") == true:
		return
	if star_until > 0.0:
		Fx.burst(_fx(), mid, "sparkle", 18, Color(1.0, 0.95, 0.6), 1.2)
	if ch_until > 0.0:
		ch_count += 1
		if ch_count >= 3:
			_end_challenge(true)
	if not plan.get("streak", true):
		return
	streak += 1
	if streak % STREAK_STEP == 0:
		_streak_reward(mid)

func _break_streak() -> void :
	streak = 0


func _streak_reward(mid: Vector2) -> void :
	var tier: = streak / STREAK_STEP
	var txt: = ""
	match tier:
		1:
			_gems(20, mid)
			txt = "+20"
		2:
			_gems(30, mid)
			if "hint_n" in play:
				play.hint_n += 1
			txt = "+30 и подсказка"
		_:
			_gems(40 + 10 * tier, mid)
			if "skill_charge" in play and not play.skill_ready:
				play.skill_charge = mini(play.skill_charge + 3, _need() - 1)
			txt = "+%d и заряд умения" % (40 + 10 * tier)
	var W: float = play.size.x
	# 0.9: the streak plaque goes to the band slot under the board, not over the tiles
	if play.has_method("v8_notice") and play.v8_notice("Чистый ритм ×%d · %s" % [streak, txt]):
		Sfx.play("star1", 1.1, -2)
		_refresh()
		return
	var l: = UI.title("Чистый ритм ×%d" % streak, 38, Color("fff6d8"), Color("3c8a4a"))
	l.size = Vector2(560, 64)
	var sy: float = (play.board_rect.get_center().y + 40.0) if "board_rect" in play else 300.0
	l.position = Vector2(W * 0.5 - 280, sy)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(280, 32)
	l.z_index = 31
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(l)
	var sub: = UI.center_label(UI.label(txt, 22, Color.WHITE, Color("1f5e49"), 5, "body", 900), Rect2(0, 56, 560, 34))
	l.add_child(sub)
	l.scale = Vector2(0.4, 0.4)
	var t: Tween = l.create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.1)
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)
	Fx.burst(_fx(), Vector2(W * 0.5, sy + 30), "sparkle", 30, Color(0.6, 1.0, 0.7), 1.0)
	Sfx.play("star1", 1.1, -2)
	_refresh()


func _open_box(pos: Vector2) -> void :
	data().gifts = int(data().get("gifts", 0)) + 1
	var roll: = randi() % 100
	var kind: = "gems"
	if roll < 38: kind = "gems"
	elif roll < 52: kind = "hint"
	elif roll < 63: kind = "undo"
	elif roll < 70: kind = "shuffle"
	elif roll < 80: kind = "skill"
	elif roll < 88: kind = "heart"
	elif roll < 95: kind = "star"
	else: kind = "jackpot"
	if _mode() == "trial" and kind in ["gems", "jackpot", "heart"]:
		kind = "hint"
	var icon: = "gem"
	var txt: = ""
	match kind:
		"gems":
			var g: = 30 + randi() % 51
			_gems(g, pos)
			txt = "%d кристаллов" % g
		"jackpot":
			_gems(200, pos)
			txt = "Джекпот: 200 кристаллов!"
			Fx.burst(_fx(), pos, "confetti", 70, Color.WHITE, 1.3)
			Sfx.play("reveal_ssr", 1.0, -2)
		"hint":
			if "hint_n" in play:
				play.hint_n += 1
			icon = "hint"
			txt = "Подсказка"
		"undo":
			if "undo_n" in play:
				play.undo_n += 1
			icon = "undo"
			txt = "Отмена хода"
		"shuffle":
			if "shuffle_n" in play:
				play.shuffle_n += 1
			icon = "shuffle"
			txt = "Перемешивание"
		"skill":
			icon = "star"
			txt = "Умение готово"
			if "skill_ready" in play and not play.skill_ready and play.has_method("_skill_ready"):
				play.skill_charge = int(play.SKILL_NEED) if "SKILL_NEED" in play else 8
				# 0.8: the heroine says «… готово» once the reward float has faded, not at the same moment
				get_tree().create_timer(1.6).timeout.connect( func():
					if is_instance_valid(play) and play.is_inside_tree() and not play.skill_ready and not bool(play.get("_v8_over")):
						play._skill_ready())
			else:
				_gems(40, pos)
				txt = "40 кристаллов"
				icon = "gem"
		"heart":
			var h: String = play.partner if "partner" in play else "mc"
			G.add_aff(h, 10)
			icon = "heart"
			txt = "+10 симпатии %s" % G.HEROES[h].name
		"star":
			icon = "star"
			txt = "Кристаллы ×2 на 8 с"
			_starfall(8.0, 1.0, false)

	# 0.8: a gift opened in the tray shows its reward over the top of the table and floats down into it,
	# never up into the HUD band (goal plate, luck chip, gem counter)
	# 0.9: a gift opened in the tray pops in its tray slot (no rise into the HUD) and its reward line goes to the
	# heroine's bubble beside the portrait — nothing lands on the board's tiles
	var top: float = play.board_rect.position.y if "board_rect" in play else 0.0
	var rise: = 90.0
	var in_tray: = pos.y < top + 60.0
	if in_tray:
		pos.x = clampf(pos.x, 60.0, play.size.x - 60.0)
		rise = 0.0
	var box: = TextureRect.new()
	box.texture = V8Art.icon("gift")
	box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box.size = Vector2(96, 96)
	box.pivot_offset = Vector2(48, 48)
	box.position = pos - Vector2(48, 48)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.z_index = 45
	play.add_child(box)
	box.scale = Vector2(0.2, 0.2)
	var t: Tween = box.create_tween()
	t.tween_property(box, "scale", Vector2(1.15, 1.15), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(box, "rotation", 0.18, 0.06)
	t.tween_property(box, "rotation", -0.18, 0.08)
	t.tween_property(box, "rotation", 0.12, 0.07)
	t.tween_property(box, "rotation", 0.0, 0.06)
	t.tween_callback( func():
		# one hero effect: a palette glow (≤70% value) + sparkles, no confetti over the HUD
		if V9Feel.can_fx():
			Fx.flash_glow(_fx(), pos, Color.from_hsv(0.1, 0.45, 0.7, 0.8), 1.4, 0.3)
			Fx.burst(_fx(), pos, "sparkle", int(14 * V9Feel.fx_scale()), Color(1, 0.85, 0.95), 0.9)
		Sfx.play("reveal_sr", 1.2, -2)
		var rw: = TextureRect.new()
		rw.texture = Common.ui_icon(icon)
		rw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rw.size = Vector2(84, 84)
		rw.pivot_offset = Vector2(42, 42)
		rw.position = pos - Vector2(42, 42)
		rw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rw.z_index = 46
		play.add_child(rw)
		var r: Tween = rw.create_tween()
		r.tween_property(rw, "position:y", rw.position.y - rise, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		r.parallel().tween_property(rw, "scale", Vector2(1.2, 1.2), 0.25)
		r.tween_interval(0.4)
		r.tween_property(rw, "modulate:a", 0.0, 0.3)
		r.tween_callback(rw.queue_free)
		if in_tray:
			if play.get("stage") and is_instance_valid(play.stage) and play.stage.has_method("say_text"):
				play.stage.say_text(txt, 2.4, false)
			else:
				_float_down(Vector2(play.size.x * 0.5, top - 40.0), txt)
		else:
			Fx.float_text(_fx(), pos + Vector2(0, -30), txt, Color("ffe7a6"), 28, Color("7a2346")))
	t.tween_property(box, "scale", Vector2(1.6, 1.6), 0.12)
	t.parallel().tween_property(box, "modulate:a", 0.0, 0.12)
	t.tween_callback(box.queue_free)
	# 0.8: the reward floats up from the box itself; no toast saying the same over the HUD
	_refresh()


func _float_down(at: Vector2, txt: String) -> void :
	var l: = UI.label(txt, 28, Color("ffe7a6"), Color("7a2346"), 8, "body", 900)
	l.position = at - Vector2(150, 30)
	l.size = Vector2(300, 60)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(150, 30)
	l.scale = Vector2(0.3, 0.3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx().add_child(l)
	var t: Tween = l.create_tween()
	t.tween_property(l, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "scale", Vector2.ONE, 0.1)
	t.parallel().tween_property(l, "position:y", l.position.y + 40, 0.9).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.25)
	t.tween_callback(l.queue_free)


func _fire_event() -> void :
	var pool: Array = plan.get("pool", ["starfall"])
	var force: = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--special_event="):
			force = a.substr(16)
	var ev: String = force if force != "" else pool[randi() % pool.size()]
	data().events = int(data().get("events", 0)) + 1
	var W: float = play.size.x
	var H: float = play.size.y
	_banner(EVENTS[ev][0], EVENTS[ev][1], "gold" if ev != "challenge" else "pink")
	Sfx.play("combo", 0.9)
	match ev:
		"starfall":
			_starfall(10.0, 2.0, true)
		"giftdrop":
			var prs: = board.free_pairs(1)
			if prs.is_empty():
				_starfall(10.0, 2.0, true)
				return
			for t in prs[0]:
				var p: Vector2 = board.tile_layer.get_global_transform_with_canvas() * t.position
				_drop_from_sky(p)
			await get_tree().create_timer(0.55).timeout
			if is_instance_valid(board):
				var pr: Array = prs[0].filter( func(t): return is_instance_valid(t) and t.alive)
				if pr.size() == 2:
					board.make_gift(pr)
		"wind":
			_gust()
			await get_tree().create_timer(0.5).timeout
			if is_instance_valid(board) and board.input_on:
				board.auto_pairs(2)
		"golden":
			var prs: = board.free_pairs(3)
			for i in prs.size():
				var pr: Array = prs[i]
				get_tree().create_timer(0.3 + i * 0.2).timeout.connect( func():
					if not is_instance_valid(board):
						return
					board.make_gold(pr)
					for t in pr:
						if is_instance_valid(t):
							Fx.burst(board.tile_layer, t.position, "sparkle", 14, Color(1, 0.85, 0.3), 0.6)
					Sfx.play("gem", 1.2, -6))
			if "gold_total" in play:
				play.gold_total += prs.size()
		"challenge":
			ch_count = 0
			ch_until = G.time + 12.0 + 1.5
			# 0.8: left column under the combo pill (the band right of it belongs to the speech bubble)
			var cy: float = maxf(384.0, float(play.board_rect.position.y) + 66.0) if "board_rect" in play else 384.0
			ch_pill = UI.rbox("pink", Rect2(20, cy, 300, 48), 24, 3, 8)
			ch_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ch_pill.z_index = 33
			play.add_child(ch_pill)
			ch_lbl = UI.center_label(UI.label("", 22, Color.WHITE, Color("7a2346"), 5, "body", 900), Rect2(0, 0, 300, 48))
			ch_pill.add_child(ch_lbl)
			UI.pop_in(ch_pill, 0.0, 0.5)

func _drop_from_sky(to: Vector2) -> void :
	var g: = TextureRect.new()
	g.texture = V8Art.icon("gift")
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.size = Vector2(70, 70)
	g.pivot_offset = Vector2(35, 35)
	g.position = Vector2(to.x - 35, -80)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.z_index = 44
	play.add_child(g)
	var t: Tween = g.create_tween()
	t.tween_property(g, "position:y", to.y - 35, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(g, "rotation", TAU, 0.5)
	t.tween_callback( func():
		Fx.burst(_fx(), to, "sparkle", 16, Color(1, 0.8, 0.9), 0.7)
		Sfx.play("pop", 1.0, -2))
	t.tween_property(g, "scale", Vector2(0.3, 0.3), 0.12)
	t.parallel().tween_property(g, "modulate:a", 0.0, 0.12)
	t.tween_callback(g.queue_free)

func _gust() -> void :
	var W: float = play.size.x
	Sfx.play("whoosh", 0.8)
	for i in 5:
		var y: = randf_range(380, play.size.y - 300)
		var p: = CPUParticles2D.new()
		p.texture = G.fx("petal")
		p.amount = 26
		p.lifetime = 1.3
		p.one_shot = true
		p.explosiveness = 0.6
		p.direction = Vector2(1, -0.1)
		p.spread = 12
		p.initial_velocity_min = 700
		p.initial_velocity_max = 1000
		p.gravity = Vector2(0, 60)
		p.scale_amount_min = 0.3
		p.scale_amount_max = 0.7
		p.angular_velocity_min = -400
		p.angular_velocity_max = 400
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(10, 60)
		p.position = Vector2(-30, y)
		p.z_index = 32
		play.add_child(p)
		p.emitting = true
		p.finished.connect(p.queue_free)

func _starfall(secs: float, bonus: float, rain: bool) -> void :
	if star_until > 0.0:
		star_until = maxf(star_until, G.time + secs)
		return
	star_until = G.time + secs
	star_bonus = bonus
	if "gem_bonus" in play:
		play.gem_bonus += bonus
	if rain:
		var W: float = play.size.x
		var p: = CPUParticles2D.new()
		p.name = "V6Starfall"
		p.texture = G.fx("sparkle")
		p.material = Fx.add_mat()
		p.amount = 40
		p.lifetime = 2.2
		p.direction = Vector2(0.2, 1)
		p.spread = 8
		p.initial_velocity_min = 380
		p.initial_velocity_max = 620
		p.gravity = Vector2.ZERO
		p.scale_amount_min = 0.15
		p.scale_amount_max = 0.45
		p.color = Color(1, 0.92, 0.6)
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(W * 0.55, 10)
		p.position = Vector2(W * 0.5, -20)
		p.z_index = 5
		play.add_child(p)
		p.emitting = true

func _end_starfall() -> void :
	star_until = -1.0
	if "gem_bonus" in play:
		play.gem_bonus -= star_bonus
	star_bonus = 0.0
	var p: Node = play.get_node_or_null("V6Starfall")
	if p:
		p.emitting = false
		get_tree().create_timer(2.5).timeout.connect(p.queue_free)

func _end_challenge(won: bool) -> void :
	ch_until = -1.0
	var pos: = Vector2(play.size.x * 0.5, 330)
	if won:
		_gems(60, pos)
		if "hint_n" in play:
			play.hint_n += 1
		_banner("Вызов принят!", "+60 кристаллов и подсказка", "mint")
		Sfx.play("win", 1.3, -6)
	else:
		Fx.float_text(_fx(), pos + Vector2(0, 40), "Не успели, не страшно", Color("ffe7a6"), 26, Color("3f1a3a"))
	if ch_pill and is_instance_valid(ch_pill):
		var c: = ch_pill
		var t: Tween = c.create_tween()
		t.tween_property(c, "modulate:a", 0.0, 0.3)
		t.tween_callback(c.queue_free)
	ch_pill = null
	ch_lbl = null
	_refresh()
