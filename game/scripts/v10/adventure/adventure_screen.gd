class_name V10AdventureScreen
extends Control

# V10AdventureScreen — Wave 3 Monster Battle RPG Mode ("Приключение: Битва с монстрами").
# Top arena: Heroine (HP + Ult gauge) vs Animated Yokai Boss (HP + Attack cadence + Higgsfield art).
# Center: Real solvable TrayBoard mahjong pairs dealing damage, gold crits, combo multipliers, and Ult burst.

var main
var W: = 720.0
var H: = 1280.0
var stage_idx: = 0
var hero_id: = "mc"
var wave: = 0
var battle: V10AdventureBattle
var board: TrayBoard
var slot_rects: Array = []
var board_rect: Rect2
var fx_layer: Control
var modal_layer: Control

var hero_card: Control
var hero_hp_fill: ColorRect
var hero_hp_lbl: Label
var ult_fill: ColorRect
var ult_btn: Panel
var ult_lbl: Label

var mon_card: Control
var mon_art: TextureRect
var mon_hp_fill: ColorRect
var mon_hp_lbl: Label
var atk_fill: ColorRect
var atk_lbl: Label
var stage_lbl: Label
var hurt_flash: ColorRect

var _tray_prev: = 0
var _t: = 0.0
var _ended: = false
var _mon_base_pos: = Vector2.ZERO
var _hero_base_pos: = Vector2.ZERO
var _btn_lock_ms: = 0


func build(m, args: Dictionary = {}) -> void:
	main = m
	W = size.x
	H = size.y
	if main != null and main.has_method("show_chrome"):
		main.show_chrome(false, false)
	var st: Dictionary = V10AdventureData.st()
	stage_idx = clampi(int(args.get("stage", st.get("stage", 0))), 0, V10AdventureData.count() - 1)
	hero_id = String(args.get("hero", G.S.get("partner", "mc")))
	if not Hero.RIGS.has(hero_id):
		hero_id = "mc"
	battle = V10AdventureBattle.new(stage_idx, hero_id)
	Sfx.music("play")
	_build_backdrop()
	_build_header()
	_build_arena()
	_build_tray_and_board()
	_build_bottom_bar()
	fx_layer = Control.new()
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.size = Vector2(W, H)
	fx_layer.z_index = 260
	add_child(fx_layer)
	modal_layer = Control.new()
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_layer.size = Vector2(W, H)
	modal_layer.z_index = 320
	add_child(modal_layer)
	_refresh_hud()


func _build_backdrop() -> void:
	var bg_name: String = String(battle.m.get("bg", "bg_shrine"))
	Common.backdrop(self, bg_name, size, 1.2, 0.85)
	var shade: = ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.09, 0.56)
	var br: = V10Layout.bleed_rect(self)
	shade.position = br.position
	shade.size = br.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	Fx.ambient(self, String(battle.m.get("fx", "lanterns")), size)
	hurt_flash = ColorRect.new()
	hurt_flash.color = Color(0.95, 0.14, 0.22, 0.0)
	hurt_flash.position = br.position
	hurt_flash.size = br.size
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_flash.z_index = 250
	add_child(hurt_flash)


func _build_header() -> void:
	var top_y: = 10.0
	var back_p: = _pill_panel(Rect2(16, top_y, 58, 58), Color(0.11, 0.06, 0.16, 0.90), Color("e8c47e"), 29)
	back_p.mouse_filter = Control.MOUSE_FILTER_STOP
	back_p.add_child(V8Art.rect(V8Art.icon("back"), Rect2(13, 13, 32, 32)))
	back_p.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			back_p.accept_event()
			_go_back())
	add_child(back_p)
	var title_str: = "Этап %d/%d · %s" % [stage_idx + 1, V10AdventureData.count(), String(battle.m.name)]
	var badge: = "БОСС" if bool(battle.m.boss) else String(battle.m.element).to_upper()
	stage_lbl = UI.label("%s  [%s]" % [title_str, badge], 22, Color("ffe8b8"), Color(0.08, 0.03, 0.12, 0.96), 4, "body", 900)
	stage_lbl.position = Vector2(84, top_y + 6)
	stage_lbl.size = Vector2(W - 168, 46)
	stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(stage_lbl)
	var mute_p: = _pill_panel(Rect2(W - 74, top_y, 58, 58), Color(0.11, 0.06, 0.16, 0.90), Color("e8c47e"), 29)
	mute_p.mouse_filter = Control.MOUSE_FILTER_STOP
	var mic: = V8Art.rect(V8Art.icon("sound" if (main != null and main.has_method("is_audio_on") and main.is_audio_on()) else "sound_off"), Rect2(13, 13, 32, 32))
	mic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mute_p.add_child(mic)
	mute_p.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			mute_p.accept_event()
			if main != null and main.has_method("toggle_master_mute"):
				var on: bool = main.toggle_master_mute()
				mic.texture = V8Art.icon("sound" if on else "sound_off"))
	add_child(mute_p)


func _build_arena() -> void:
	var ay: = 76.0
	var ah: = 296.0
	var arena_bg: = _pill_panel(Rect2(14, ay, W - 28, ah), Color(0.09, 0.05, 0.14, 0.86), Color("c99c4c"), 18)
	add_child(arena_bg)

	# Left: Heroine card + HP + Ult
	var hw: = 292.0
	hero_card = Control.new()
	hero_card.position = Vector2(26, ay + 12)
	hero_card.size = Vector2(hw, ah - 24)
	hero_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_base_pos = hero_card.position
	add_child(hero_card)
	var hclip: = Control.new()
	hclip.position = Vector2(4, 4)
	hclip.size = Vector2(126, 176)
	hclip.clip_contents = true
	hclip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_card.add_child(hclip)
	var htr: = TextureRect.new()
	var eq: = G.equipped(hero_id)
	htr.texture = G.art_tex(G.ITEM[eq]) if (eq != "" and G.ITEM.has(eq)) else V8Art.emotion(hero_id, "happy")
	htr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	htr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	htr.size = hclip.size
	htr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hclip.add_child(htr)
	hero_card.add_child(_frame_only(Rect2(2, 2, 130, 180), Color("f4d182"), 12))
	var hname: = UI.label(String(G.HEROES[hero_id].name), 20, Color("fff2dc"), Color(0.08, 0.03, 0.12), 4, "body", 900)
	hname.position = Vector2(140, 8)
	hname.size = Vector2(148, 28)
	hero_card.add_child(hname)
	var perk_l: = UI.label(String(V10AdventureData.HERO_PERKS.get(hero_id, "")), 14, Color("e6c8a8"), Color(0.08, 0.03, 0.12), 3, "body", 700)
	perk_l.position = Vector2(140, 38)
	perk_l.size = Vector2(148, 52)
	perk_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_card.add_child(perk_l)
	hero_hp_fill = _bar(hero_card, Rect2(140, 106, 146, 22), Color("38c878"))
	hero_hp_lbl = _bar_lbl(hero_card, Rect2(140, 104, 146, 26), "HP 100/100")
	ult_fill = _bar(hero_card, Rect2(140, 142, 146, 20), Color("f5c542"))
	var ul_cap: = _bar_lbl(hero_card, Rect2(140, 140, 146, 24), "УЛЬТА 0/100")
	ul_cap.name = "UltCap"

	ult_btn = _pill_panel(Rect2(4, 194, hw - 8, 66), Color(0.45, 0.16, 0.28, 0.92), Color("f6d483"), 14)
	ult_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	ult_lbl = UI.label("УЛЬТА ЗАРЯЖАЕТСЯ", 18, Color("ffe8b8"), Color(0.1, 0.03, 0.12), 4, "body", 900)
	ult_lbl.size = ult_btn.size
	ult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ult_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ult_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ult_btn.add_child(ult_lbl)
	ult_btn.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			ult_btn.accept_event()
			_try_cast_ult())
	hero_card.add_child(ult_btn)

	# Center VS emblem
	var vs_l: = UI.label("VS", 28, Color("ffcf70"), Color(0.22, 0.05, 0.14), 5, "body", 900)
	vs_l.position = Vector2(W * 0.5 - 30, ay + 96)
	vs_l.size = Vector2(60, 42)
	vs_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(vs_l)

	# Right: Monster card + HP + Attack Countdown
	var mw: = 328.0
	mon_card = Control.new()
	mon_card.position = Vector2(W - mw - 24, ay + 12)
	mon_card.size = Vector2(mw, ah - 24)
	mon_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mon_base_pos = mon_card.position
	add_child(mon_card)
	var mclip: = Control.new()
	mclip.position = Vector2(mw - 166, 8)
	mclip.size = Vector2(160, 160)
	mclip.clip_contents = true
	mclip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mon_card.add_child(mclip)
	mon_art = TextureRect.new()
	mon_art.texture = V10AdventureData.monster_texture(String(battle.m.id))
	mon_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mon_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mon_art.size = mclip.size
	mon_art.pivot_offset = mclip.size * 0.5
	mon_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mclip.add_child(mon_art)
	var acc: Color = battle.m.get("accent", Color("e85a4f"))
	mon_card.add_child(_frame_only(Rect2(mw - 168, 6, 164, 164), acc, 14))
	var mname: = UI.label(String(battle.m.name), 20, acc.lightened(0.35), Color(0.08, 0.03, 0.12), 4, "body", 900)
	mname.position = Vector2(0, 8)
	mname.size = Vector2(mw - 178, 54)
	mname.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mon_card.add_child(mname)
	var msub: = UI.label(String(battle.m.debuff_desc), 14, Color("d8c4e4"), Color(0.08, 0.03, 0.12), 3, "body", 700)
	msub.position = Vector2(0, 68)
	msub.size = Vector2(mw - 178, 64)
	msub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mon_card.add_child(msub)
	mon_hp_fill = _bar(mon_card, Rect2(0, 192, mw - 4, 28), Color("e04556"))
	mon_hp_lbl = _bar_lbl(mon_card, Rect2(0, 190, mw - 4, 32), "HP 160/160")
	atk_fill = _bar(mon_card, Rect2(0, 230, mw - 4, 24), Color("f08a38"))
	atk_lbl = _bar_lbl(mon_card, Rect2(0, 228, mw - 4, 28), "Удар через 6 ходов")


func _build_tray_and_board() -> void:
	var ty: = 384.0
	var th: = 104.0
	var slots_n: = 5
	var sw: = 112.0
	var gap: = 10.0
	var total_w: = slots_n * sw + (slots_n - 1) * gap
	var x0: = (W - total_w) * 0.5
	add_child(_pill_panel(Rect2(x0 - 14, ty - 8, total_w + 28, th + 16), Color(0.08, 0.05, 0.12, 0.90), Color("c99c4c"), 16))
	slot_rects.clear()
	for i in slots_n:
		var r: = Rect2(x0 + i * (sw + gap), ty, sw, th)
		slot_rects.append(r)
		add_child(_pill_panel(r, Color(0.05, 0.03, 0.08, 0.92), Color(0.75, 0.62, 0.38, 0.55), 10))
	var by: = ty + th + 22.0
	var bh: = maxf(460.0, H - by - 116.0)
	board_rect = Rect2(18, by, W - 36, bh)
	add_child(_pill_panel(board_rect.grow(6.0), Color(0.06, 0.14, 0.11, 0.88), Color("d4ac5e"), 18))
	_spawn_board()


func _spawn_board() -> void:
	if board != null and is_instance_valid(board):
		board.queue_free()
	board = TrayBoard.new()
	board.slots = slot_rects.size()
	add_child(board)
	board.setup(V10AdventureData.board_cfg(stage_idx, wave))
	board.fit_into(board_rect)
	board.slot_pos.clear()
	for r in slot_rects:
		board.slot_pos.append(get_global_transform() * (r as Rect2).get_center())
	board.slot_size = (slot_rects[0] as Rect2).size.x * 0.88
	_tray_prev = 0
	board.matched.connect(_on_match)
	board.tray_changed.connect(_on_tray_changed)
	board.failed.connect(_on_overflow)
	board.cleared.connect(_on_board_cleared)


func _build_bottom_bar() -> void:
	var by: = H - 96.0
	var hint_b: = JButton.make("Подсказка", "graphite", Rect2(24, by, 210, 68), null, 20)
	hint_b.pressed.connect(func() -> void:
		if not _ended and board != null and is_instance_valid(board):
			board.hint())
	add_child(hint_b)
	var shuf_b: = JButton.make("Перемешать", "graphite", Rect2(254, by, 212, 68), null, 20)
	shuf_b.pressed.connect(func() -> void:
		if not _ended and board != null and is_instance_valid(board):
			board.shuffle())
	add_child(shuf_b)
	var flee_b: = JButton.make("Отступить", "glass", Rect2(486, by, 210, 68), null, 20)
	flee_b.pressed.connect(_go_back)
	add_child(flee_b)


func _process(delta: float) -> void:
	_t += delta
	if mon_art != null and is_instance_valid(mon_art) and not _ended:
		var s: = 1.0 + sin(_t * 2.4) * 0.025
		mon_art.scale = Vector2(s, s)


func _on_match(mid: Vector2, combo: int, gold: bool, _shard: String) -> void:
	if _ended:
		return
	var r: Dictionary = battle.on_pair(combo, gold)
	var dmg: int = int(r.get("damage", 0))
	if dmg > 0:
		var tag: String = ("КРИТ -%d!" % dmg) if bool(r.get("crit", false)) else ("-%d" % dmg)
		var col: Color = Color("ffe066") if bool(r.get("crit", false)) else Color("ff9e7d")
		_float_text(mon_card.position + Vector2(180, 70), tag, col, 30 if bool(r.get("crit", false)) else 24)
		_hit_monster()
		if V9Feel.can_fx():
			Fx.burst(fx_layer, V10Layout.local_of(self, mid), "sparkle", 14 if gold else 8, col, 0.9)
	if int(r.get("heal", 0)) > 0:
		_float_text(hero_card.position + Vector2(80, 60), "+%d HP" % int(r.heal), Color("5ce89b"), 22)
	_refresh_hud()
	if bool(r.get("killed", false)):
		_finish(true)


func _on_tray_changed() -> void:
	if _ended or board == null:
		return
	var cur_n: int = board.tray.size()
	if cur_n > _tray_prev:
		var ev: Dictionary = battle.on_move()
		_handle_enemy_event(ev)
	_tray_prev = cur_n
	_refresh_hud()


func _on_overflow() -> void:
	if _ended:
		return
	var ev: Dictionary = battle.on_overflow()
	_handle_enemy_event(ev)
	if not _ended and board != null and is_instance_valid(board):
		board.return_from_tray(mini(3, board.tray.size()))
		_tray_prev = board.tray.size()
	_refresh_hud()


func _on_board_cleared() -> void:
	if _ended:
		return
	var bonus: Dictionary = battle.on_pair(3, true)
	_float_text(mon_card.position + Vector2(160, 40), "ЗАЛП -%d!" % int(bonus.damage), Color("ffe066"), 32)
	_hit_monster()
	_refresh_hud()
	if battle.over:
		_finish(battle.won)
	else:
		wave += 1
		_spawn_board()


func _try_cast_ult() -> void:
	if _ended or not battle.ult_ready():
		return
	var r: Dictionary = battle.use_ult()
	if r.is_empty():
		return
	Sfx.say(hero_id, "fever")
	Sfx.play("reveal_ssr", 1.0, -4.0)
	_float_text(mon_card.position + Vector2(120, 48), "УЛЬТА -%d!" % int(r.damage), Color("ffdf6b"), 36)
	if int(r.get("heal", 0)) > 0:
		_float_text(hero_card.position + Vector2(70, 50), "+%d HP" % int(r.heal), Color("5ce89b"), 24)
	_hit_monster(true)
	_refresh_hud()
	if bool(r.get("killed", false)):
		_finish(true)


func _handle_enemy_event(ev: Dictionary) -> void:
	if ev.is_empty():
		return
	if bool(ev.get("stunned", false)):
		_float_text(mon_card.position + Vector2(150, 40), "ОГЛУШЁН!", Color("7ce2ff"), 24)
		return
	if bool(ev.get("attack", false)):
		var dmg: int = int(ev.get("damage", 0))
		Sfx.play("deny", 0.85, -3.0)
		_float_text(hero_card.position + Vector2(80, 60), "-%d HP" % dmg, Color("ff5c6c"), 28)
		_hit_hero()
		if bool(ev.get("lost", false)):
			_finish(false)


func _hit_monster(heavy: bool = false) -> void:
	if mon_card == null or not is_instance_valid(mon_card):
		return
	mon_card.position = _mon_base_pos
	var dx: = 16.0 if heavy else 9.0
	var tw: = mon_card.create_tween()
	tw.tween_property(mon_card, "position:x", _mon_base_pos.x + dx, 0.05)
	tw.tween_property(mon_card, "position:x", _mon_base_pos.x - dx * 0.6, 0.06)
	tw.tween_property(mon_card, "position:x", _mon_base_pos.x, 0.08)
	if mon_art != null:
		mon_art.modulate = Color(1.8, 0.85, 0.85, 1.0)
		mon_art.create_tween().tween_property(mon_art, "modulate", Color.WHITE, 0.22)


func _hit_hero() -> void:
	if hero_card != null and is_instance_valid(hero_card):
		hero_card.position = _hero_base_pos
		var tw: = hero_card.create_tween()
		tw.tween_property(hero_card, "position:x", _hero_base_pos.x - 10.0, 0.05)
		tw.tween_property(hero_card, "position:x", _hero_base_pos.x + 8.0, 0.06)
		tw.tween_property(hero_card, "position:x", _hero_base_pos.x, 0.08)
	if hurt_flash != null:
		hurt_flash.color.a = 0.34
		hurt_flash.create_tween().tween_property(hurt_flash, "color:a", 0.0, 0.32)


func _refresh_hud() -> void:
	if hero_hp_fill != null:
		hero_hp_fill.size.x = 146.0 * battle.hero_frac()
	if hero_hp_lbl != null:
		hero_hp_lbl.text = "HP %d/%d" % [battle.hero_hp, V10AdventureData.HERO_MAX_HP]
	var uf: = clampf(float(battle.ult) / float(V10AdventureData.ULT_MAX), 0.0, 1.0)
	if ult_fill != null:
		ult_fill.size.x = 146.0 * uf
	var ucap: Label = hero_card.get_node_or_null("UltCap") if hero_card != null else null
	if ucap != null:
		ucap.text = "УЛЬТА %d%%" % int(round(uf * 100.0))
	if ult_btn != null and ult_lbl != null:
		var rdy: = battle.ult_ready()
		ult_lbl.text = "★ УЛЬТА ГОТОВА! ★" if rdy else "Заряд ульты: %d%%" % int(round(uf * 100.0))
		ult_btn.modulate = Color(1.15, 1.08, 0.92, 1.0) if rdy else Color(0.75, 0.72, 0.78, 0.85)
	if mon_hp_fill != null:
		mon_hp_fill.size.x = 320.0 * battle.hp_frac()
	if mon_hp_lbl != null:
		mon_hp_lbl.text = "HP %d/%d" % [battle.mon_hp, battle.mon_max]
	var cad: = maxi(1, int(battle.m.cadence))
	if atk_fill != null:
		var prog: = 1.0 - float(battle.moves_left) / float(cad)
		atk_fill.size.x = 320.0 * clampf(prog, 0.06, 1.0)
	if atk_lbl != null:
		atk_lbl.text = "Оглушён (%d)" % battle.stun if battle.stun > 0 else "Удар босса через %d" % battle.moves_left


func _finish(victory: bool) -> void:
	if _ended:
		return
	_ended = true
	if board != null and is_instance_valid(board):
		board.input_on = false
	var rw: Dictionary = {}
	if victory:
		Sfx.play("win", 1.0, -3.0)
		Sfx.say(hero_id, "win")
		rw = V10AdventureData.record_win(stage_idx, battle.dmg_total)
		V10Money.grant({"gems": int(rw.gems), "coins": int(rw.coins)}, "adventure")
		G.add_aff(hero_id, int(rw.aff))
		G.save()
	else:
		Sfx.say(hero_id, "lose")
		V10AdventureData.record_defeat(battle.dmg_total)
		G.save()
	var dim: = ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.08, 0.78)
	dim.size = Vector2(W, H)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(dim)
	var card: = _pill_panel(Rect2(44, H * 0.25, W - 88, 430), Color(0.11, 0.06, 0.17, 0.98), Color("f6d483"), 22)
	dim.add_child(card)
	var t_lbl: = UI.label("МОНСТР ПОВЕРЖЕН!" if victory else "ПОРАЖЕНИЕ", 34, Color("ffe28a") if victory else Color("ff7b8a"), Color(0.08, 0.03, 0.12), 5, "body", 900)
	t_lbl.position = Vector2(16, 26)
	t_lbl.size = Vector2(card.size.x - 32, 46)
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(t_lbl)
	var sub_txt: String = ("%s повержен!\nНаграда: +%d кристаллов · +%d монет · +%d симпатии" % [String(battle.m.name), int(rw.gems), int(rw.coins), int(rw.aff)]) if victory else ("%s оказался сильнее.\nСнимай золотые пары и копи ульту для оглушения!" % String(battle.m.name))
	var sub: = UI.label(sub_txt, 21, Color("f2e6d8"), Color(0.06, 0.03, 0.10), 3, "body", 800)
	sub.position = Vector2(24, 96)
	sub.size = Vector2(card.size.x - 48, 130)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(sub)
	var next_stage: int = int(rw.get("next_stage", stage_idx)) if victory else stage_idx
	var btn_txt: String = ("Следующий босс ›" if (victory and bool(rw.get("has_next", false))) else "Сразиться снова")
	var b1: = JButton.make(btn_txt, "gold", Rect2(44, 246, card.size.x - 88, 76), null, 24)
	b1.pressed.connect(func() -> void:
		if main != null:
			main.go("adventure", {"stage": next_stage, "hero": hero_id}))
	card.add_child(b1)
	var b2: = JButton.make("К столам", "graphite", Rect2(44, 336, card.size.x - 88, 64), null, 22)
	b2.pressed.connect(_go_back)
	card.add_child(b2)


func _go_back() -> void:
	if main != null:
		main.go("tables")


func _float_text(pos: Vector2, txt: String, col: Color, fs: int) -> void:
	if fx_layer == null or not is_instance_valid(fx_layer):
		return
	var l: = UI.label(txt, fs, col, Color(0.08, 0.02, 0.10), 5, "body", 900)
	l.position = pos
	fx_layer.add_child(l)
	var tw: = l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", pos.y - 54.0, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.72).set_delay(0.18)
	tw.chain().tween_callback(l.queue_free)


func _bar(parent: Control, r: Rect2, col: Color) -> ColorRect:
	parent.add_child(_pill_panel(r, Color(0.05, 0.03, 0.09, 0.94), Color(0.72, 0.58, 0.36, 0.70), 8))
	var fill: = ColorRect.new()
	fill.color = col
	fill.position = r.position + Vector2(2, 2)
	fill.size = r.size - Vector2(4, 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	return fill


func _bar_lbl(parent: Control, r: Rect2, txt: String) -> Label:
	var l: = UI.label(txt, 15, Color.WHITE, Color(0.06, 0.02, 0.10), 3, "body", 900)
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _pill_panel(r: Rect2, bg: Color, border: Color, rad: int) -> Panel:
	var p: = Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(rad)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _frame_only(r: Rect2, border: Color, rad: int) -> Panel:
	return _pill_panel(r, Color(0, 0, 0, 0), border, rad)


func _is_tap(e: InputEvent) -> bool:
	var ok: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
	if not ok:
		return false
	var now_ms: = Time.get_ticks_msec()
	if now_ms - _btn_lock_ms < 220:
		return false
	_btn_lock_ms = now_ms
	return true
