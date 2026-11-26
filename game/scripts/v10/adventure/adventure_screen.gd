class_name V10AdventureScreen
extends Control

# V10AdventureScreen — 0.11.0 Omniheroes-Grade Monster Battle RPG ("Приключение: Битва с монстрами").
# - Top Arena: Grand Boss Stage (210x210 Yokai Boss portrait + living elemental BossAura + glowing "БОСС" crown emblem,
#   DelayedBar HP with white-gold damage trail, Attack Countdown + incoming debuff preview, stage selector arrows).
# - Center: 5-slot Mahjong Tray + solvable TrayBoard with real visible boss debuffs ("Пелена офуда" & "Заморозка").
# - Bottom Battle Dock (1-thumb reach): Heroine Portrait Medallion + Hero HP DelayedBar + Large Glowing Gold-Crimson
#   ULT Button (triggers fullscreen .ogv video / anime CG slash cutscene) + compact Подсказка / Перемешать buttons.

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
var arena_rect: Rect2
var dock_rect: Rect2

var shake_root: Control
var fx_layer: Control
var modal_layer: Control
var hurt_flash: ColorRect
var combo_banner: V10AdventureVfx.ComboBanner

var mon_card: Control
var mon_aura: V10AdventureVfx.BossAura
var mon_crown: V10AdventureVfx.CrownEmblem
var mon_clip: Control
var mon_art: TextureRect
var mon_hp_bar: V10AdventureVfx.DelayedBar
var mon_hp_lbl: Label
var atk_fill: ColorRect
var atk_lbl: Label
var debuff_lbl: Label
var stage_lbl: Label
var prev_stage_btn: Panel
var next_stage_btn: Panel
var stamina_lbl: Label

var hero_dock: Control
var hero_medallion: Control
var hero_ready_glow: Panel
var hero_art: TextureRect
var hero_hp_bar: V10AdventureVfx.DelayedBar
var hero_hp_lbl: Label
var ult_btn: V10AdventureVfx.UltButton

var _tray_prev: = 0
var _t: = 0.0
var _ended: = false
var _mon_base_pos: = Vector2.ZERO
var _mon_clip_base: = Vector2.ZERO
var _dock_base_pos: = Vector2.ZERO
var _btn_lock_ms: = 0
var _hitstop_end_ms: = 0
var _ult_casting: = false


func _exit_tree() -> void:
	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0


func build(m, args: Dictionary = {}) -> void:
	main = m
	W = size.x if size.x > 0.0 else 720.0
	H = size.y if size.y > 0.0 else 1280.0
	if main != null and main.has_method("show_chrome"):
		main.show_chrome(false, false)
	var st: Dictionary = V10AdventureData.st()
	stage_idx = clampi(int(args.get("stage", st.get("stage", 0))), 0, V10AdventureData.count() - 1)
	hero_id = String(args.get("hero", G.S.get("partner", "mc")))
	if not Hero.RIGS.has(hero_id):
		hero_id = "mc"
	if not bool(args.get("skip_stamina", false)):
		V10AdventureData.try_spend_stamina(main)
	battle = V10AdventureBattle.new(stage_idx, hero_id)
	Sfx.music("play")
	_build_backdrop()
	shake_root = Control.new()
	shake_root.size = Vector2(W, H)
	shake_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shake_root)
	_build_header()
	_build_arena()
	_build_bottom_dock()
	_build_tray_and_board()
	fx_layer = Control.new()
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.size = Vector2(W, H)
	fx_layer.z_index = 260
	add_child(fx_layer)
	combo_banner = V10AdventureVfx.ComboBanner.new().setup(Rect2(W * 0.5 - 196.0, arena_rect.end.y - 26.0, 392.0, 58.0))
	combo_banner.z_index = 265
	add_child(combo_banner)
	modal_layer = Control.new()
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_layer.size = Vector2(W, H)
	modal_layer.z_index = 320
	add_child(modal_layer)
	_refresh_hud(true)


func _build_backdrop() -> void:
	var bg_name: String = String(battle.m.get("bg", "bg_shrine"))
	Common.backdrop(self, bg_name, Vector2(W, H), 1.2, 0.88)
	var shade: = ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.09, 0.50)
	var br: = V10Layout.bleed_rect(self)
	shade.position = br.position
	shade.size = br.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	Fx.ambient(self, String(battle.m.get("fx", "lanterns")), Vector2(W, H))
	hurt_flash = ColorRect.new()
	hurt_flash.color = Color(0.95, 0.12, 0.22, 0.0)
	hurt_flash.position = br.position
	hurt_flash.size = br.size
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_flash.z_index = 250
	add_child(hurt_flash)


func _build_header() -> void:
	var top_y: = 8.0
	var back_p: = _pill_panel(Rect2(14, top_y, 52, 52), Color(0.12, 0.06, 0.18, 0.92), Color("#E8C47E"), 26)
	back_p.mouse_filter = Control.MOUSE_FILTER_STOP
	back_p.add_child(V8Art.rect(V8Art.icon("back"), Rect2(10, 10, 32, 32)))
	back_p.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			back_p.accept_event()
			_go_back())
	shake_root.add_child(back_p)

	var hdr_title: = UI.label("ОХОТА НА ЁКАЕВ · ПРИКЛЮЧЕНИЕ", 19, Color("#FFE8B8"), Color(0.08, 0.03, 0.12, 0.96), 4, "body", 900)
	hdr_title.position = Vector2(74, top_y + 4)
	hdr_title.size = Vector2(W - 246, 26)
	hdr_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	shake_root.add_child(hdr_title)

	stamina_lbl = UI.label(V10AdventureData.stamina_badge_text(), 14, Color("#D8F5C8"), Color(0.06, 0.02, 0.10), 3, "body", 800)
	stamina_lbl.position = Vector2(74, top_y + 29)
	stamina_lbl.size = Vector2(W - 246, 20)
	shake_root.add_child(stamina_lbl)

	var flee_p: = _pill_panel(Rect2(W - 172, top_y + 4, 96, 44), Color(0.16, 0.08, 0.22, 0.90), Color(0.82, 0.68, 0.44, 0.78), 22)
	flee_p.mouse_filter = Control.MOUSE_FILTER_STOP
	var fl_l: = UI.label("К столам", 14, Color("#F2DEC0"), Color(0.08, 0.03, 0.12), 3, "body", 800)
	fl_l.size = flee_p.size
	fl_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fl_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flee_p.add_child(fl_l)
	flee_p.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			flee_p.accept_event()
			_go_back())
	shake_root.add_child(flee_p)

	var mute_p: = _pill_panel(Rect2(W - 66, top_y, 52, 52), Color(0.12, 0.06, 0.18, 0.92), Color("#E8C47E"), 26)
	mute_p.mouse_filter = Control.MOUSE_FILTER_STOP
	var mic: = V8Art.rect(V8Art.icon("sound" if (main != null and main.has_method("is_audio_on") and main.is_audio_on()) else "sound_off"), Rect2(10, 10, 32, 32))
	mic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mute_p.add_child(mic)
	mute_p.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			mute_p.accept_event()
			if main != null and main.has_method("toggle_master_mute"):
				var on: bool = main.toggle_master_mute()
				mic.texture = V8Art.icon("sound" if on else "sound_off"))
	shake_root.add_child(mute_p)


func _build_arena() -> void:
	var ay: = 66.0
	var ah: = 278.0 + clampf((H - 1280.0) * 0.10, 0.0, 32.0)
	arena_rect = Rect2(14, ay, W - 28, ah)
	var acc: Color = battle.m.get("accent", Color("#E85A4F"))
	var arena_bg: = _pill_panel(arena_rect, Color(0.09, 0.04, 0.15, 0.90), acc.lerp(Color("#F4C86A"), 0.55), 20)
	shake_root.add_child(arena_bg)

	mon_card = Control.new()
	mon_card.position = arena_rect.position
	mon_card.size = arena_rect.size
	mon_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mon_base_pos = mon_card.position
	shake_root.add_child(mon_card)

	# Left column: Stage Selector Arrows + Boss Identity + Delayed HP Bar + Countdown + Debuff Indicator
	var lx: = 16.0
	var lw: = arena_rect.size.x - 258.0

	prev_stage_btn = _pill_panel(Rect2(lx, 12, 42, 38), Color(0.16, 0.08, 0.24, 0.95), Color("#E8C47E"), 12)
	prev_stage_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var pl: = UI.label("‹", 26, Color("#FFEAB3"), Color(0.08, 0.02, 0.10), 4, "body", 900)
	pl.size = prev_stage_btn.size
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prev_stage_btn.add_child(pl)
	prev_stage_btn.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			prev_stage_btn.accept_event()
			_switch_stage(stage_idx - 1))
	mon_card.add_child(prev_stage_btn)

	var cleared_mark: = " · ✓" if V10AdventureData.is_stage_cleared(stage_idx) else ""
	var st_txt: = "ЭТАП %d/%d · %s%s" % [stage_idx + 1, V10AdventureData.count(), String(battle.m.element).to_upper(), cleared_mark]
	stage_lbl = UI.label(st_txt, 15, Color("#FFE6A8"), Color(0.08, 0.02, 0.12), 4, "body", 900)
	stage_lbl.position = Vector2(lx + 48, 12)
	stage_lbl.size = Vector2(lw - 96, 38)
	stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mon_card.add_child(stage_lbl)

	next_stage_btn = _pill_panel(Rect2(lx + lw - 42, 12, 42, 38), Color(0.16, 0.08, 0.24, 0.95), Color("#E8C47E"), 12)
	next_stage_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var nl: = UI.label("›", 26, Color("#FFEAB3"), Color(0.08, 0.02, 0.10), 4, "body", 900)
	nl.size = next_stage_btn.size
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_stage_btn.add_child(nl)
	next_stage_btn.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			next_stage_btn.accept_event()
			_switch_stage(stage_idx + 1))
	mon_card.add_child(next_stage_btn)

	var mname: = UI.label(String(battle.m.name), 26, acc.lightened(0.38), Color(0.07, 0.02, 0.11), 5, "body", 900)
	mname.position = Vector2(lx, 54)
	mname.size = Vector2(lw, 34)
	mname.clip_text = true
	mon_card.add_child(mname)

	var mtitle: = UI.label(String(battle.m.title), 14, Color("#DECBE8"), Color(0.07, 0.02, 0.11), 3, "body", 700)
	mtitle.position = Vector2(lx, 88)
	mtitle.size = Vector2(lw, 22)
	mtitle.clip_text = true
	mon_card.add_child(mtitle)

	mon_hp_bar = V10AdventureVfx.DelayedBar.new().setup(Rect2(lx, 118, lw, 32), Color("#F44E63"), Color("#A81D34"), Color("#F6D483"))
	mon_card.add_child(mon_hp_bar)
	mon_hp_lbl = _bar_lbl(mon_card, Rect2(lx, 116, lw, 34), "HP %d / %d" % [battle.mon_hp, battle.mon_max], 16)

	var atk_r: = Rect2(lx, 158, lw, 26)
	mon_card.add_child(_pill_panel(atk_r, Color(0.05, 0.03, 0.09, 0.94), Color(0.85, 0.56, 0.32, 0.80), 8))
	atk_fill = ColorRect.new()
	atk_fill.color = Color("#F58A38")
	atk_fill.position = atk_r.position + Vector2(2, 2)
	atk_fill.size = atk_r.size - Vector2(4, 4)
	atk_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mon_card.add_child(atk_fill)
	atk_lbl = _bar_lbl(mon_card, Rect2(lx, 156, lw, 28), "Атака босса через %d" % battle.moves_left, 14)

	var db_box: = _pill_panel(Rect2(lx, 192, lw, ah - 204.0), Color(0.13, 0.06, 0.20, 0.92), acc.darkened(0.15), 12)
	mon_card.add_child(db_box)
	var db_icon: = "❄" if String(battle.m.debuff) == "freeze" else ("🐉" if String(battle.m.debuff) == "both" else "封")
	var db_str: = "%s Приём: %s — %s · Урон %d" % [db_icon, String(battle.m.debuff_name), String(battle.m.debuff_desc), int(battle.m.atk)]
	debuff_lbl = UI.label(db_str, 14, Color("#F4E4FA"), Color(0.07, 0.02, 0.10), 3, "body", 800)
	debuff_lbl.position = Vector2(lx + 10, 195)
	debuff_lbl.size = Vector2(lw - 20, ah - 210.0)
	debuff_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	debuff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mon_card.add_child(debuff_lbl)

	# Right showcase: 256x256 Living Elemental BossAura + 210x210 Boss Portrait + Glowing "БОСС" CrownEmblem
	var p_sz: = 210.0
	var px: = arena_rect.size.x - p_sz - 16.0
	var py: = (ah - p_sz) * 0.5 + 8.0
	mon_aura = V10AdventureVfx.BossAura.new().setup(Rect2(px - 24.0, py - 24.0, p_sz + 48.0, p_sz + 48.0), acc, true)
	mon_card.add_child(mon_aura)

	mon_clip = Control.new()
	mon_clip.position = Vector2(px, py)
	mon_clip.size = Vector2(p_sz, p_sz)
	mon_clip.pivot_offset = mon_clip.size * 0.5
	mon_clip.clip_contents = true
	mon_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mon_clip_base = mon_clip.position
	mon_card.add_child(mon_clip)

	mon_art = TextureRect.new()
	mon_art.texture = V10AdventureData.monster_texture(String(battle.m.id))
	mon_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mon_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mon_art.size = mon_clip.size
	mon_art.pivot_offset = mon_clip.size * 0.5
	mon_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mon_clip.add_child(mon_art)
	mon_clip.add_child(_frame_only(Rect2(0, 0, p_sz, p_sz), acc.lightened(0.18), 16))

	var crown_txt: = "АРХИБОСС" if bool(battle.m.boss) else "БОСС"
	mon_crown = V10AdventureVfx.CrownEmblem.new().setup(Rect2(px + (p_sz - 134.0) * 0.5, maxf(6.0, py - 18.0), 134.0, 30.0), crown_txt, acc)
	mon_card.add_child(mon_crown)


func _build_bottom_dock() -> void:
	var dock_h: = 168.0 + clampf((H - 1280.0) * 0.05, 0.0, 16.0)
	var dock_y: = H - dock_h - 10.0
	dock_rect = Rect2(14, dock_y, W - 28, dock_h)
	hero_dock = Control.new()
	hero_dock.position = dock_rect.position
	hero_dock.size = dock_rect.size
	hero_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock_base_pos = hero_dock.position
	shake_root.add_child(hero_dock)

	hero_dock.add_child(_pill_panel(Rect2(Vector2.ZERO, dock_rect.size), Color(0.10, 0.04, 0.16, 0.94), Color("#E8C47E"), 20))

	# Left: Heroine Portrait Medallion (tappable to cast Ult when ready!)
	var med_r: = Rect2(12, 12, 118, dock_h - 24.0)
	hero_ready_glow = _pill_panel(med_r.grow(5.0), Color(1.0, 0.72, 0.24, 0.26), Color("#FFE48F"), 18)
	hero_ready_glow.visible = false
	hero_dock.add_child(hero_ready_glow)

	hero_medallion = Control.new()
	hero_medallion.position = med_r.position
	hero_medallion.size = med_r.size
	hero_medallion.pivot_offset = med_r.size * 0.5
	hero_medallion.clip_contents = true
	hero_medallion.mouse_filter = Control.MOUSE_FILTER_STOP
	hero_medallion.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			hero_medallion.accept_event()
			if battle.ult_ready():
				_try_cast_ult()
			else:
				V9Feel.press(hero_medallion, "tap", "button")
				Sfx.say(hero_id, "match"))
	hero_dock.add_child(hero_medallion)

	hero_art = TextureRect.new()
	var eq: = G.equipped(hero_id)
	hero_art.texture = G.art_tex(G.ITEM[eq]) if (eq != "" and G.ITEM.has(eq)) else V8Art.emotion(hero_id, "happy")
	hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero_art.size = med_r.size
	hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_medallion.add_child(hero_art)
	hero_dock.add_child(_frame_only(med_r, Color("#F6D483"), 14))

	# Top-right of Dock: Heroine Name + Perk + Hero HP DelayedBar
	var rx: = 142.0
	var rw: = dock_rect.size.x - rx - 12.0
	var h_info: = "%s · %s" % [String(G.HEROES[hero_id].name), String(V10AdventureData.HERO_PERKS.get(hero_id, ""))]
	var hname_l: = UI.label(h_info, 15, Color("#FFF2DC"), Color(0.08, 0.03, 0.12), 4, "body", 900)
	hname_l.position = Vector2(rx, 11)
	hname_l.size = Vector2(rw - 226.0, 30)
	hname_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hname_l.clip_text = true
	hero_dock.add_child(hname_l)

	var hp_r: = Rect2(rx + rw - 218.0, 12, 218.0, 28.0)
	hero_hp_bar = V10AdventureVfx.DelayedBar.new().setup(hp_r, Color("#46DC8C"), Color("#1E9658"), Color("#B8E8C8"))
	hero_dock.add_child(hero_hp_bar)
	hero_hp_lbl = _bar_lbl(hero_dock, Rect2(hp_r.position.x, hp_r.position.y - 1, hp_r.size.x, hp_r.size.y + 2), "♥ HP 100 / 100", 14)

	# Thumb Row: Large Glowing Gold-Crimson ULT Button + Compact Подсказка / Перемешать Stack
	var row_y: = 48.0
	var row_h: = dock_h - row_y - 12.0
	var util_w: = 192.0
	var ult_w: = rw - util_w - 10.0
	var u_meta: Dictionary = V10AdventureData.HERO_ULTS.get(hero_id, V10AdventureData.HERO_ULTS.mc)
	var u_dmg: int = int(V10AdventureData.calc_ult_damage(stage_idx, hero_id).damage)
	ult_btn = V10AdventureVfx.UltButton.new().setup(Rect2(rx, row_y, ult_w, row_h), String(u_meta.title), u_dmg, u_meta.accent)
	ult_btn.triggered.connect(_try_cast_ult)
	hero_dock.add_child(ult_btn)

	var bh_half: = (row_h - 8.0) * 0.5
	var ux: = rx + ult_w + 10.0
	var hint_b: = JButton.make("Подсказка", "graphite", Rect2(ux, row_y, util_w, bh_half), null, 18)
	hint_b.pressed.connect(func() -> void:
		if not _ended and board != null and is_instance_valid(board):
			board.hint())
	hero_dock.add_child(hint_b)

	var shuf_b: = JButton.make("Перемешать", "graphite", Rect2(ux, row_y + bh_half + 8.0, util_w, bh_half), null, 18)
	shuf_b.pressed.connect(func() -> void:
		if not _ended and board != null and is_instance_valid(board):
			board.shuffle_board())
	hero_dock.add_child(shuf_b)


func _build_tray_and_board() -> void:
	var ty: = arena_rect.end.y + 12.0
	var th: = 96.0 + clampf((H - 1280.0) * 0.03, 0.0, 10.0)
	var slots_n: = 5
	var sw: = 112.0
	var gap: = 10.0
	var total_w: = slots_n * sw + (slots_n - 1) * gap
	var x0: = (W - total_w) * 0.5
	shake_root.add_child(_pill_panel(Rect2(x0 - 14, ty - 6, total_w + 28, th + 12), Color(0.08, 0.05, 0.12, 0.90), Color("#C99C4C"), 16))
	slot_rects.clear()
	for i in slots_n:
		var r: = Rect2(x0 + i * (sw + gap), ty, sw, th)
		slot_rects.append(r)
		shake_root.add_child(_pill_panel(r, Color(0.05, 0.03, 0.08, 0.92), Color(0.75, 0.62, 0.38, 0.55), 10))
	var by: = ty + th + 14.0
	var bh: = maxf(380.0, dock_rect.position.y - by - 12.0)
	board_rect = Rect2(18, by, W - 36, bh)
	shake_root.add_child(_pill_panel(board_rect.grow(5.0), Color(0.06, 0.14, 0.11, 0.88), Color("#D4AC5E"), 18))
	_spawn_board()


func _spawn_board() -> void:
	if board != null and is_instance_valid(board):
		board.queue_free()
	board = TrayBoard.new()
	board.slots = slot_rects.size()
	shake_root.add_child(board)
	board.setup(V10AdventureData.board_cfg(stage_idx, wave))
	board.fit_into(board_rect)
	board.slot_pos.clear()
	for r in slot_rects:
		board.slot_pos.append(get_global_transform_with_canvas() * (r as Rect2).get_center())
	board.slot_size = (slot_rects[0] as Rect2).size.x * 0.88
	board.reveal_free()
	board.input_on = true
	_tray_prev = 0
	board.matched.connect(_on_match)
	board.tray_changed.connect(_on_tray_changed)
	board.failed.connect(_on_overflow)
	board.cleared.connect(_on_board_cleared)


func _process(delta: float) -> void:
	if _hitstop_end_ms > 0 and Time.get_ticks_msec() >= _hitstop_end_ms:
		_hitstop_end_ms = 0
		Engine.time_scale = 1.0
	_t += delta
	if mon_art != null and is_instance_valid(mon_art) and not _ended:
		var s: = 1.0 + sin(_t * 2.3) * 0.028
		mon_art.scale = Vector2(s, s)
	if hero_ready_glow != null and is_instance_valid(hero_ready_glow) and hero_ready_glow.visible:
		hero_ready_glow.modulate.a = 0.65 + 0.35 * sin(_t * 4.5)


func _boss_center() -> Vector2:
	if mon_card != null and mon_clip != null:
		return mon_card.position + mon_clip.position + mon_clip.size * 0.5
	return Vector2(W - 135.0, 200.0)


func _hero_center() -> Vector2:
	if hero_dock != null and hero_medallion != null:
		return hero_dock.position + hero_medallion.position + hero_medallion.size * 0.5
	return Vector2(85.0, H - 96.0)


func _switch_stage(target_idx: int) -> void:
	if _ended or _ult_casting:
		return
	if target_idx < 0 or target_idx >= V10AdventureData.count():
		V9Feel.deny(prev_stage_btn if target_idx < 0 else next_stage_btn)
		return
	if target_idx > stage_idx and not V10AdventureData.is_stage_unlocked(target_idx):
		V9Feel.deny(next_stage_btn)
		V10AdventureVfx.spawn_float_text(fx_layer, Vector2(W * 0.5, arena_rect.end.y - 16.0), "Победи текущего босса!", Color("#FFD670"), 22, 0.80)
		return
	if main != null and main.has_method("go"):
		main.go("adventure", {"stage": target_idx, "hero": hero_id, "skip_stamina": true})


func _on_match(mid: Vector2, combo: int, gold: bool, _shard: String) -> void:
	if _ended:
		return
	V10AdventureVfx.tick_board_fog(board)
	var r: Dictionary = battle.on_pair(combo, gold)
	var dmg: int = int(r.get("damage", 0))
	var is_crit: bool = bool(r.get("crit", false))
	var mult: float = float(r.get("combo_mult", 1.0))
	var from_pt: = V10Layout.local_of(self, mid)
	var to_pt: = _boss_center()
	var orb_col: = Color("#FFE066") if is_crit else Color(battle.m.get("accent", Color("#FF9E7D"))).lerp(Color("#FFB86C"), 0.55)
	var orb_n: = 3 if (is_crit or combo >= 3) else 2
	if combo >= 2 or is_crit:
		combo_banner.trigger(combo, is_crit, mult)
	if int(r.get("heal", 0)) > 0:
		V10AdventureVfx.spawn_float_text(fx_layer, _hero_center() + Vector2(36, -34), "+%d HP" % int(r.heal), Color("#5CE89B"), 24, 0.90)
	_refresh_ult_only()
	if dmg > 0:
		var killed: bool = bool(r.get("killed", false))
		V10AdventureVfx.spawn_projectiles(fx_layer, from_pt, to_pt, orb_n, orb_col, func() -> void:
			_apply_pair_impact(dmg, combo, is_crit, killed))


func _apply_pair_impact(dmg: int, combo: int, is_crit: bool, killed: bool) -> void:
	if not is_inside_tree():
		return
	var bc: = _boss_center()
	var slash_col: = Color("#FFE066") if is_crit else Color("#FF5E78")
	var slash_n: = 2 if (is_crit or combo >= 3) else 1
	V10AdventureVfx.spawn_slash(fx_layer, bc, slash_col, slash_n, V10AdventureVfx.SLASH_HOLD_DUR)
	V10AdventureVfx.spawn_shockwave(fx_layer, bc, slash_col, 155.0 if is_crit else 118.0, is_crit)
	if V9Feel.can_fx():
		Fx.burst(fx_layer, bc, "sparkle", 18 if is_crit else 10, slash_col, 1.05 if is_crit else 0.85)
		Fx.flash_glow(fx_layer, bc, slash_col.lightened(0.25), 1.9 if is_crit else 1.3, 0.34)
	if is_crit:
		Sfx.play("reveal_sr", 1.15, -4.0)
		_start_hitstop(V10AdventureVfx.HITSTOP_SEC)
		_shake_screen(11.0, 0.24)
	var tag: = ("КРИТ -%d!" % dmg) if is_crit else ("-%d" % dmg)
	var tcol: = Color("#FFE47A") if is_crit else Color("#FFA686")
	V10AdventureVfx.spawn_float_text(fx_layer, bc + Vector2(randf_range(-28.0, 18.0), -62.0), tag, tcol, 32 if is_crit else 26, 0.95)
	_hit_monster(is_crit)
	_refresh_hud(false)
	if killed and not _ended:
		get_tree().create_timer(0.52).timeout.connect(func() -> void:
			if is_inside_tree() and not _ended:
				_finish(true))


func _on_tray_changed() -> void:
	if _ended or board == null:
		return
	var cur_n: int = board.tray.size()
	if cur_n > _tray_prev:
		var ev: Dictionary = battle.on_move()
		_handle_enemy_event(ev)
	_tray_prev = cur_n
	_refresh_hud(false)


func _on_overflow() -> void:
	if _ended:
		return
	var ev: Dictionary = battle.on_overflow()
	_handle_enemy_event(ev)
	if not _ended and board != null and is_instance_valid(board):
		board.return_tray(mini(3, board.tray.size()))
		_tray_prev = board.tray.size()
	_refresh_hud(false)


func _on_board_cleared() -> void:
	if _ended:
		return
	var bonus: Dictionary = battle.on_pair(3, true)
	var bc: = _boss_center()
	V10AdventureVfx.spawn_slash(fx_layer, bc, Color("#FFE066"), 2, V10AdventureVfx.SLASH_HOLD_DUR)
	V10AdventureVfx.spawn_shockwave(fx_layer, bc, Color("#FFE066"), 165.0, true)
	V10AdventureVfx.spawn_float_text(fx_layer, bc + Vector2(0, -70), "ЗАЛП -%d!" % int(bonus.damage), Color("#FFE066"), 34, 1.0)
	_hit_monster(true)
	_refresh_hud(false)
	if battle.over:
		get_tree().create_timer(0.45).timeout.connect(func() -> void:
			if is_inside_tree() and not _ended:
				_finish(battle.won))
	else:
		wave += 1
		_spawn_board()


func _try_cast_ult() -> void:
	if _ended or _ult_casting or not battle.ult_ready():
		return
	var r: Dictionary = battle.use_ult()
	if r.is_empty():
		return
	_ult_casting = true
	if board != null and is_instance_valid(board):
		board.input_on = false
	var line_txt: = Sfx.say(hero_id, "fever")
	Sfx.duck(-8.0, 2.0)
	Sfx.play("reveal_ssr", 1.0, -3.0)
	_refresh_ult_only()
	var eq: = G.equipped(hero_id)
	var vid_p: = V10AdventureData.ult_video_path(hero_id, eq)
	var cg_tex: = V10AdventureData.ult_cg_texture(hero_id, eq)
	var u_meta: Dictionary = V10AdventureData.HERO_ULTS.get(hero_id, V10AdventureData.HERO_ULTS.mc)
	var h_name: = String(G.HEROES.get(hero_id, {"name": "Героиня"}).name)
	var cut: = V10AdventureVfx.UltCutscene.new().setup(
		V10Layout.bleed_rect(self), hero_id, h_name, String(u_meta.title), line_txt, u_meta.accent, vid_p, cg_tex
	)
	modal_layer.add_child(cut)
	cut.impact.connect(func() -> void:
		if is_inside_tree():
			_apply_ult_impact(r))
	cut.finished.connect(func() -> void:
		_ult_casting = false
		if not is_inside_tree():
			return
		if bool(r.get("killed", false)):
			get_tree().create_timer(0.55).timeout.connect(func() -> void:
				if is_inside_tree() and not _ended:
					_finish(true))
		elif not _ended and board != null and is_instance_valid(board):
			board.input_on = true)


func _apply_ult_impact(r: Dictionary) -> void:
	var bc: = _boss_center()
	var u_meta: Dictionary = V10AdventureData.HERO_ULTS.get(hero_id, V10AdventureData.HERO_ULTS.mc)
	var acc: Color = u_meta.accent
	_start_hitstop(V10AdventureVfx.HITSTOP_SEC)
	_shake_screen(18.0, 0.36)
	V10AdventureVfx.spawn_slash(fx_layer, bc, acc, 5, 0.82)
	V10AdventureVfx.spawn_shockwave(fx_layer, bc, Color("#FFE48F"), 210.0, true)
	if V9Feel.can_fx():
		Fx.burst(fx_layer, bc, "firework", 26, Color("#FFE48F"), 1.15)
		Fx.burst(fx_layer, bc, "sparkle", 22, acc, 1.2)
		Fx.flash_glow(fx_layer, bc, Color("#FFF4CC"), 2.6, 0.48)
	Sfx.play("summon_boom", 1.0, -2.0)
	var hits: Array = r.get("hits", [])
	for i in hits.size():
		var h_val: int = int(hits[i])
		var off: = Vector2(-64.0 + float(i) * 64.0, -26.0 - float(i % 2) * 28.0)
		get_tree().create_timer(float(i) * 0.09).timeout.connect(func() -> void:
			if is_inside_tree():
				V10AdventureVfx.spawn_float_text(fx_layer, bc + off, "-%d!" % h_val, Color("#FFE680"), 26, 0.85))
	V10AdventureVfx.spawn_float_text(fx_layer, bc + Vector2(0, -86), "СУПЕРУДАР -%d!" % int(r.damage), Color("#FFDF6B"), 36, 1.10)
	V10AdventureVfx.spawn_float_text(fx_layer, bc + Vector2(0, 56), "★ ОГЛУШЁН! ★", Color("#7CE2FF"), 28, 1.10)
	var cleansed: = V10AdventureVfx.cleanse_board_debuffs(board)
	if cleansed > 0:
		V10AdventureVfx.spawn_float_text(fx_layer, board_rect.get_center() + Vector2(0, -40), "ОЧИЩЕНИЕ ЧАР!", Color("#9CF6E8"), 24, 0.90)
	if int(r.get("heal", 0)) > 0:
		V10AdventureVfx.spawn_float_text(fx_layer, _hero_center() + Vector2(48, -38), "+%d HP" % int(r.heal), Color("#5CE89B"), 26, 0.95)
	_hit_monster(true)
	_refresh_hud(false)


func _handle_enemy_event(ev: Dictionary) -> void:
	if ev.is_empty():
		return
	if bool(ev.get("stunned", false)):
		Sfx.play("sparkle", 1.2, -5.0)
		V10AdventureVfx.spawn_shockwave(fx_layer, _boss_center(), Color("#7CE2FF"), 120.0, false)
		V10AdventureVfx.spawn_float_text(fx_layer, _boss_center() + Vector2(0, -48), "ОГЛУШЁН · ХОД ПРОПУЩЕН!", Color("#7CE2FF"), 24, 0.95)
		return
	if bool(ev.get("attack", false)):
		_play_boss_counter(ev)


func _play_boss_counter(ev: Dictionary) -> void:
	var dmg: int = int(ev.get("damage", 0))
	var db_kind: String = String(ev.get("debuff", battle.m.get("debuff", "fog")))
	var db_name: String = String(ev.get("debuff_name", battle.m.get("debuff_name", "Чары ёкая")))
	var db_cnt: int = int(ev.get("debuff_count", battle.m.get("debuff_count", 2)))
	var lost: bool = bool(ev.get("lost", false))

	# Phase 1: 0.25s Red Telegraph Flash
	if hurt_flash != null:
		hurt_flash.color = Color(0.95, 0.12, 0.22, 0.30)
		var ftw: = hurt_flash.create_tween()
		ftw.tween_property(hurt_flash, "color:a", 0.08, 0.22)
	if mon_clip != null:
		mon_clip.modulate = Color(1.65, 0.55, 0.55, 1.0)
	V10AdventureVfx.spawn_float_text(fx_layer, _boss_center() + Vector2(-40, -68), "⚠ %s!" % db_name.to_upper(), Color("#FF6B7A"), 24, 0.95)
	Sfx.play("summon_charge", 0.78, -4.0)

	# Phase 2 (after 0.25s telegraph): Boss Portrait Lunges Forward + Crimson Shockwave + Debuff Curse on TrayBoard!
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		Sfx.play("deny", 0.82, -2.0)
		if mon_clip != null and is_instance_valid(mon_clip):
			mon_clip.modulate = Color.WHITE
			mon_clip.position = _mon_clip_base
			var ltw: = mon_clip.create_tween().set_parallel()
			ltw.tween_property(mon_clip, "position", _mon_clip_base + Vector2(-42.0, 58.0), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ltw.tween_property(mon_clip, "scale", Vector2(1.22, 1.22), 0.11)
			ltw.chain().set_parallel()
			ltw.tween_property(mon_clip, "position", _mon_clip_base, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			ltw.tween_property(mon_clip, "scale", Vector2.ONE, 0.22)
		var lunge_pt: = _boss_center() + Vector2(-36.0, 48.0)
		V10AdventureVfx.spawn_shockwave(fx_layer, lunge_pt, Color("#FF3B4E"), 190.0, true)
		_shake_screen(14.0, 0.28)
		_hit_hero()
		V10AdventureVfx.spawn_float_text(fx_layer, _hero_center() + Vector2(54, -42), "-%d HP!" % dmg, Color("#FF5C6C"), 30, 0.95)
		_refresh_hud(false)
		if not lost and board != null and is_instance_valid(board):
			var cursed_tiles: = V10AdventureVfx.apply_board_debuff(board, db_kind, db_cnt)
			var curse_col: = Color("#7CE2FF") if db_kind == "freeze" else Color("#C678FF")
			for t in cursed_tiles:
				if is_instance_valid(t):
					var tp: = V10Layout.local_of(self, t.get_global_transform_with_canvas().origin)
					V10AdventureVfx.spawn_projectiles(fx_layer, lunge_pt, tp, 2, curse_col, func() -> void:
						if is_inside_tree() and V9Feel.can_fx():
							Fx.burst(fx_layer, tp, "sparkle", 8, curse_col, 0.7))
		if lost and not _ended:
			get_tree().create_timer(0.42).timeout.connect(func() -> void:
				if is_inside_tree() and not _ended:
					_finish(false)))


func _start_hitstop(dur_sec: float = V10AdventureVfx.HITSTOP_SEC) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Engine.time_scale = 0.08
	_hitstop_end_ms = Time.get_ticks_msec() + int(round(dur_sec * 1000.0))


func _shake_screen(amount: float = 12.0, dur: float = 0.25) -> void:
	if shake_root == null or not is_instance_valid(shake_root):
		return
	Fx.shake(shake_root, amount, dur)


func _hit_monster(heavy: bool = false) -> void:
	if mon_card == null or not is_instance_valid(mon_card):
		return
	mon_card.position = _mon_base_pos
	var dx: = 18.0 if heavy else 10.0
	var tw: = mon_card.create_tween()
	tw.tween_property(mon_card, "position:x", _mon_base_pos.x + dx, 0.05)
	tw.tween_property(mon_card, "position:x", _mon_base_pos.x - dx * 0.65, 0.06)
	tw.tween_property(mon_card, "position:x", _mon_base_pos.x, 0.09)
	if mon_art != null:
		mon_art.modulate = Color(1.9, 0.86, 0.86, 1.0)
		mon_art.create_tween().tween_property(mon_art, "modulate", Color.WHITE, 0.24)


func _hit_hero() -> void:
	if hero_dock != null and is_instance_valid(hero_dock):
		hero_dock.position = _dock_base_pos
		var tw: = hero_dock.create_tween()
		tw.tween_property(hero_dock, "position:x", _dock_base_pos.x - 12.0, 0.05)
		tw.tween_property(hero_dock, "position:x", _dock_base_pos.x + 10.0, 0.06)
		tw.tween_property(hero_dock, "position:x", _dock_base_pos.x, 0.08)
	if hurt_flash != null:
		hurt_flash.color = Color(0.95, 0.14, 0.22, 0.38)
		hurt_flash.create_tween().tween_property(hurt_flash, "color:a", 0.0, 0.34)


func _refresh_ult_only() -> void:
	var uf: = battle.ult_frac()
	var rdy: = battle.ult_ready()
	var u_dmg: int = int(V10AdventureData.calc_ult_damage(stage_idx, hero_id).damage)
	if ult_btn != null:
		ult_btn.set_state(uf, rdy, u_dmg)
	if hero_ready_glow != null:
		hero_ready_glow.visible = rdy


func _refresh_hud(instant_bars: bool = false) -> void:
	if hero_hp_bar != null:
		hero_hp_bar.set_frac(battle.hero_frac(), instant_bars)
	if hero_hp_lbl != null:
		hero_hp_lbl.text = "♥ HP %d / %d" % [battle.hero_hp, V10AdventureData.HERO_MAX_HP]
	_refresh_ult_only()
	if mon_hp_bar != null:
		mon_hp_bar.set_frac(battle.hp_frac(), instant_bars)
	if mon_hp_lbl != null:
		mon_hp_lbl.text = "HP %d / %d" % [battle.mon_hp, battle.mon_max]
	var cad: = maxi(1, int(battle.m.cadence))
	var full_w: = arena_rect.size.x - 258.0 - 4.0
	if atk_fill != null:
		var prog: = 1.0 - float(battle.moves_left) / float(cad)
		atk_fill.size.x = maxf(0.0, full_w * clampf(prog, 0.08, 1.0))
		atk_fill.color = Color("#7CE2FF") if battle.stun > 0 else (Color("#FF3B4E") if battle.moves_left <= 2 else Color("#F58A38"))
	if atk_lbl != null:
		atk_lbl.text = "★ Оглушён (%d х.)" % battle.stun if battle.stun > 0 else "Удар босса через %d" % battle.moves_left
	if mon_aura != null:
		mon_aura.stunned = battle.stun > 0
		mon_aura.danger = (battle.stun <= 0 and battle.moves_left <= 2)
	if prev_stage_btn != null:
		prev_stage_btn.modulate.a = 1.0 if stage_idx > 0 else 0.38
	if next_stage_btn != null:
		var unl: = V10AdventureData.is_stage_unlocked(stage_idx + 1)
		next_stage_btn.modulate.a = 1.0 if unl else 0.42
	if stamina_lbl != null:
		stamina_lbl.text = V10AdventureData.stamina_badge_text()


func _finish(victory: bool) -> void:
	if _ended:
		return
	_ended = true
	Engine.time_scale = 1.0
	if board != null and is_instance_valid(board):
		board.input_on = false
	var rw: Dictionary = {}
	var refunded: = 0
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
		refunded = V10AdventureData.refund_defeat_stamina()
		G.save()
	var dim: = ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.08, 0.80)
	dim.size = Vector2(W, H)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(dim)
	var card: = _pill_panel(Rect2(44, H * 0.25, W - 88, 436), Color(0.11, 0.06, 0.17, 0.98), Color("#F6D483"), 22)
	dim.add_child(card)
	var t_lbl: = UI.label("БОСС ПОВЕРЖЕН!" if victory else "ПОРАЖЕНИЕ", 34, Color("#FFE28A") if victory else Color("#FF7B8A"), Color(0.08, 0.03, 0.12), 5, "body", 900)
	t_lbl.position = Vector2(16, 24)
	t_lbl.size = Vector2(card.size.x - 32, 46)
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(t_lbl)
	var refund_note: = ("\nВозвращено чая: +%d" % refunded) if refunded > 0 else ""
	var sub_txt: String = ("%s повержен!\nНаграда: +%d кристаллов · +%d монет · +%d симпатии" % [String(battle.m.name), int(rw.gems), int(rw.coins), int(rw.aff)]) if victory else ("%s оказался сильнее.%s\nСнимай золотые пары и жми Суперудар внизу для оглушения!" % [String(battle.m.name), refund_note])
	var sub: = UI.label(sub_txt, 20, Color("#F2E6D8"), Color(0.06, 0.03, 0.10), 3, "body", 800)
	sub.position = Vector2(24, 92)
	sub.size = Vector2(card.size.x - 48, 138)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(sub)
	var next_stage: int = int(rw.get("next_stage", stage_idx)) if victory else stage_idx
	var btn_txt: String = ("Следующий босс ›" if (victory and bool(rw.get("has_next", false))) else "Сразиться снова")
	var b1: = JButton.make(btn_txt, "gold", Rect2(44, 248, card.size.x - 88, 76), null, 24)
	b1.pressed.connect(func() -> void:
		if main != null:
			main.go("adventure", {"stage": next_stage, "hero": hero_id}))
	card.add_child(b1)
	var b2: = JButton.make("К столам", "graphite", Rect2(44, 338, card.size.x - 88, 64), null, 22)
	b2.pressed.connect(_go_back)
	card.add_child(b2)


func _go_back() -> void:
	Engine.time_scale = 1.0
	if main != null:
		main.go("tables")


func dev_act(act: String) -> void:
	match act:
		"ult_ready":
			battle.ult = V10AdventureData.ULT_MAX
			_refresh_hud(false)
		"combat_showcase":
			battle.ult = V10AdventureData.ULT_MAX
			battle.mon_hp = maxi(20, int(round(float(battle.mon_max) * 0.58)))
			battle.moves_left = 2
			_refresh_hud(false)
			V10AdventureVfx.apply_board_debuff(board, "both", 4)
			var bc: = _boss_center()
			var from_pt: = board_rect.get_center() + Vector2(-40.0, 20.0)
			V10AdventureVfx.spawn_projectiles(fx_layer, from_pt, bc, 3, Color("#FFE066"), Callable())
			for ch in fx_layer.get_children():
				if ch is V10AdventureVfx.EnergyOrb:
					var eo: = ch as V10AdventureVfx.EnergyOrb
					eo.delay = 0.0
					for _s in 6:
						eo._process(0.032)
			var sl: = V10AdventureVfx.spawn_slash(fx_layer, bc, Color("#FFE066"), 2, V10AdventureVfx.SLASH_HOLD_DUR)
			if sl != null:
				sl._process(0.14)
			var sw: = V10AdventureVfx.spawn_shockwave(fx_layer, bc, Color("#FFE066"), 165.0, true)
			if sw != null:
				sw._process(0.12)
			combo_banner.trigger(3, true, 1.50)
			V10AdventureVfx.spawn_float_text(fx_layer, bc + Vector2(-58, -18), "КРИТ -66!", Color("#FFE47A"), 34, 1.2)
		"ult_cast":
			battle.ult = V10AdventureData.ULT_MAX
			_refresh_hud(false)
			_try_cast_ult()
		"boss_lunge":
			_play_boss_counter({"attack": true, "damage": 13, "debuff": "both", "debuff_name": "Дыхание Дракона", "debuff_count": 3, "lost": false})


func _bar_lbl(parent: Control, r: Rect2, txt: String, fs: int = 15) -> Label:
	var l: = UI.label(txt, fs, Color.WHITE, Color(0.06, 0.02, 0.10), 4, "body", 900)
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
