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
var shield_bar: V10AdventureVfx.ShieldBar
var squad: Array = []
var support_medals: Array = []
var hero_info_lbl: Label
var squad_btn: Control
var squad_modal: Control
var squad_edit: Array = []
var squad_slot: = 1
var _squad_card: Control
var _squad_prev_input: = false
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
	if not args.has("hero") and bool(st.get("squad_custom", false)):
		var h0: = String((st.squad as Array)[0])
		if Hero.RIGS.has(h0):
			hero_id = h0
	if not Hero.RIGS.has(hero_id):
		hero_id = "mc"
	if not bool(args.get("skip_stamina", false)):
		V10AdventureData.try_spend_stamina(main)
	squad = V10AdventureData.effective_squad(hero_id)
	battle = V10AdventureBattle.new(stage_idx, hero_id, squad, V10AdventureData.aff_bonuses(hero_id))
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

	mon_hp_bar = V10AdventureVfx.DelayedBar.new().setup(Rect2(lx, 114, lw, 28), Color("#F44E63"), Color("#A81D34"), Color("#F6D483"))
	mon_card.add_child(mon_hp_bar)
	mon_hp_lbl = _bar_lbl(mon_card, Rect2(lx, 112, lw, 30), "HP %d / %d" % [battle.mon_hp, battle.mon_max], 16)

	shield_bar = V10AdventureVfx.ShieldBar.new().setup(Rect2(lx, 146, lw, 24))
	shield_bar.set_state(battle.shield, battle.shield_max, battle.broken_turns, true)
	mon_card.add_child(shield_bar)

	var atk_r: = Rect2(lx, 174, lw, 24)
	mon_card.add_child(_pill_panel(atk_r, Color(0.05, 0.03, 0.09, 0.94), Color(0.85, 0.56, 0.32, 0.80), 8))
	atk_fill = ColorRect.new()
	atk_fill.color = Color("#F58A38")
	atk_fill.position = atk_r.position + Vector2(2, 2)
	atk_fill.size = atk_r.size - Vector2(4, 4)
	atk_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mon_card.add_child(atk_fill)
	atk_lbl = _bar_lbl(mon_card, Rect2(lx, 172, lw, 28), "Атака босса через %d" % battle.moves_left, 14)

	var db_box: = _pill_panel(Rect2(lx, 204, lw, ah - 214.0), Color(0.13, 0.06, 0.20, 0.92), acc.darkened(0.15), 12)
	mon_card.add_child(db_box)
	var db_icon: = "❄" if String(battle.m.debuff) == "freeze" else ("🐉" if String(battle.m.debuff) == "both" else "封")
	var db_str: = "%s Приём: %s — %s · Урон %d" % [db_icon, String(battle.m.debuff_name), String(battle.m.debuff_desc), int(battle.m.atk)]
	debuff_lbl = UI.label(db_str, 13, Color("#F4E4FA"), Color(0.07, 0.02, 0.10), 3, "body", 800)
	debuff_lbl.position = Vector2(lx + 10, 206)
	debuff_lbl.size = Vector2(lw - 20, ah - 218.0)
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
	var med_r: = Rect2(12, 12, 118, dock_h - 24.0 - 54.0)
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

	# Support goddesses: two compact gold medallions (48x48) under the lead portrait; a tap opens the squad window
	support_medals.clear()
	var sup_y: = dock_h - 12.0 - 48.0
	for i in 2:
		var sid: = String(squad[i + 1]) if squad.size() > i + 1 else ""
		var sm: = _build_support_medal(sid, Rect2(12.0 + float(i) * 58.0, sup_y, 48.0, 48.0))
		hero_dock.add_child(sm)
		support_medals.append(sm)

	# Top-right of Dock: Heroine Name + Perk + Hero HP DelayedBar
	var rx: = 142.0
	var rw: = dock_rect.size.x - rx - 12.0
	var syn: = V10AdventureData.active_synergy(squad) if squad.size() >= 2 else {}
	var h_info: = "%s · %s" % [V10AdventureData.hero_name(hero_id), String(syn.get("name", V10AdventureData.HERO_PERKS.get(hero_id, "")))]
	var hname_l: = UI.label(h_info, 14, Color("#FFF2DC"), Color(0.08, 0.03, 0.12), 4, "body", 900)
	hname_l.position = Vector2(rx, 11)
	hname_l.size = Vector2(rw - 226.0 - 92.0, 30)
	hname_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hname_l.clip_text = true
	hero_dock.add_child(hname_l)
	hero_info_lbl = hname_l

	squad_btn = _build_squad_button(Rect2(rx + rw - 218.0 - 88.0, 11, 82, 30))
	hero_dock.add_child(squad_btn)

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
	var u_dmg: int = int(V10AdventureData.calc_ult_damage(stage_idx, hero_id, battle.mods).damage)
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
		var broke: bool = bool(r.get("broke", false))
		var doubled: bool = bool(r.get("doubled", false))
		V10AdventureVfx.spawn_projectiles(fx_layer, from_pt, to_pt, orb_n, orb_col, func() -> void:
			_apply_pair_impact(dmg, combo, is_crit, killed, broke, doubled))


func _apply_pair_impact(dmg: int, combo: int, is_crit: bool, killed: bool, broke: bool = false, doubled: bool = false) -> void:
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
	if doubled:
		tag = "×2 " + tag
	var tcol: = Color("#FFE47A") if is_crit else Color("#FFA686")
	if doubled:
		tcol = Color("#FF6B7A")
	V10AdventureVfx.spawn_float_text(fx_layer, bc + Vector2(randf_range(-28.0, 18.0), -62.0), tag, tcol, 32 if (is_crit or doubled) else 26, 0.95)
	if broke:
		_play_shield_break(bc)
	_hit_monster(is_crit or doubled)
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
	if bool(bonus.get("broke", false)):
		_play_shield_break(bc)
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
	var ult_tag: = ("СУПЕРУДАР ×2 -%d!" if bool(r.get("doubled", false)) else "СУПЕРУДАР -%d!") % int(r.damage)
	V10AdventureVfx.spawn_float_text(fx_layer, bc + Vector2(0, -86), ult_tag, Color("#FFDF6B"), 36, 1.10)
	V10AdventureVfx.spawn_float_text(fx_layer, bc + Vector2(0, 56), "★ ОГЛУШЁН! ★", Color("#7CE2FF"), 28, 1.10)
	if bool(r.get("broke", false)):
		_play_shield_break(bc + Vector2(0, -20))
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
	var u_dmg: int = int(V10AdventureData.calc_ult_damage(stage_idx, hero_id, battle.mods).damage)
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
	if shield_bar != null:
		shield_bar.set_state(battle.shield, battle.shield_max, battle.broken_turns, instant_bars)
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
	var raid: Dictionary = {}
	if victory:
		Sfx.play("win", 1.0, -3.0)
		Sfx.say(hero_id, "win")
		rw = V10AdventureData.record_win(stage_idx, battle.dmg_total, null, battle.breaks)
		raid = rw.get("raid", {})
		V10Money.grant({"gems": int(rw.gems), "coins": int(rw.coins)}, "adventure")
		G.add_aff(hero_id, int(rw.aff))
		var gift_tier: = 1 if stage_idx < 2 else (2 if stage_idx < 4 else 3)
		var g_id: = V10AffCurve.award_boss_gift(gift_tier)
		var g_def: = V10AffCurve.gift_def(g_id)
		rw["gift_name"] = String(g_def.get("name", ""))
		G.save()
	else:
		Sfx.say(hero_id, "lose")
		raid = V10AdventureData.record_defeat(battle.dmg_total, null, battle.breaks, stage_idx)
		refunded = V10AdventureData.refund_defeat_stamina()
		G.save()
	V10AdventureData.submit_raid_score(stage_idx, battle.dmg_total)
	var raid_line: = "\nУрон за бой: %d · Рекорд: %d%s" % [battle.dmg_total, int(raid.get("best", battle.dmg_total)), (" · НОВЫЙ РЕКОРД!" if bool(raid.get("new_best", false)) else "")]
	var dim: = ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.08, 0.80)
	dim.size = Vector2(W, H)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(dim)
	var card: = _pill_panel(Rect2(44, H * 0.25, W - 88, 480), Color(0.11, 0.06, 0.17, 0.98), Color("#F6D483"), 22)
	dim.add_child(card)
	var t_lbl: = UI.label("БОСС ПОВЕРЖЕН!" if victory else "ПОРАЖЕНИЕ", 34, Color("#FFE28A") if victory else Color("#FF7B8A"), Color(0.08, 0.03, 0.12), 5, "body", 900)
	t_lbl.position = Vector2(16, 24)
	t_lbl.size = Vector2(card.size.x - 32, 46)
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(t_lbl)
	var refund_note: = ("\nВозвращено чая: +%d" % refunded) if refunded > 0 else ""
	var gift_note: = ("\nТрофей: Подарок «%s»" % String(rw.get("gift_name", ""))) if String(rw.get("gift_name", "")) != "" else ""
	var sub_txt: String = ("%s повержен!\nНаграда: +%d кристаллов · +%d монет · +%d симпатии%s%s" % [String(battle.m.name), int(rw.gems), int(rw.coins), int(rw.aff), gift_note, raid_line]) if victory else ("%s оказался сильнее.%s\nСнимай золотые пары и жми Суперудар внизу для оглушения!%s" % [String(battle.m.name), refund_note, raid_line])
	var sub: = UI.label(sub_txt, 20, Color("#F2E6D8"), Color(0.06, 0.03, 0.10), 3, "body", 800)
	sub.position = Vector2(24, 92)
	sub.size = Vector2(card.size.x - 48, 172)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(sub)
	var next_stage: int = int(rw.get("next_stage", stage_idx)) if victory else stage_idx
	var btn_txt: String = ("Следующий босс ›" if (victory and bool(rw.get("has_next", false))) else "Сразиться снова")
	var b1: = JButton.make(btn_txt, "gold", Rect2(44, 284, card.size.x - 88, 76), null, 24)
	b1.pressed.connect(func() -> void:
		if main != null:
			main.go("adventure", {"stage": next_stage, "hero": hero_id}))
	card.add_child(b1)
	var b2: = JButton.make("К столам", "graphite", Rect2(44, 374, card.size.x - 88, 64), null, 22)
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
		"squad":
			open_squad_modal()
		"shield_low":
			battle.shield = int(round(float(battle.shield_max) * 0.34))
			_refresh_hud(true)
		"shield_break":
			battle.shield = 1
			var br: Dictionary = battle.on_pair(1, false)
			_apply_pair_impact(int(br.damage), 1, false, false, bool(br.get("broke", false)), bool(br.get("doubled", false)))
		"combat_showcase":
			battle.shield = int(round(float(battle.shield_max) * 0.45))
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


# ── Squad: support medallions, «Отряд» button and the 3-goddess selection window ──────────────────────────────

func _play_shield_break(bc: Vector2) -> void:
	V10AdventureVfx.spawn_shield_break(fx_layer, bc)
	Sfx.play("reveal_ssr", 0.85, -2.0)
	_shake_screen(16.0, 0.32)


func _portrait_box(parent: Control, hid: String, r: Rect2, dim: bool = false) -> Control:
	var clip: = Control.new()
	clip.position = r.position
	clip.size = r.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(clip)
	var tex: Texture2D = V10AdventureData.hero_portrait(hid) if hid != "" else null
	if tex != null:
		var tr: = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.size = r.size
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if dim:
			tr.modulate = Color(0.30, 0.30, 0.36, 1.0)
		clip.add_child(tr)
	else:
		var plus: = UI.label("+" if hid == "" else hid.substr(0, 1).to_upper(), int(r.size.y * 0.5), Color("#E8C47E"), Color(0.06, 0.02, 0.08), 4, "body", 900)
		plus.size = r.size
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clip.add_child(plus)
	return clip


func _set_medal(root: Control, sid: String) -> void:
	for ch in root.get_children():
		root.remove_child(ch)
		ch.queue_free()
	root.set_meta("hero", sid)
	var plate: = _pill_panel(Rect2(Vector2(-3, -3), root.size + Vector2(6, 6)), Color(0.34, 0.22, 0.05, 0.96), Color("#FFE48F"), 10)
	root.add_child(plate)
	_portrait_box(root, sid, Rect2(Vector2.ZERO, root.size))
	root.add_child(_frame_only(Rect2(Vector2.ZERO, root.size), Color("#F6D483"), 6))


func _build_support_medal(sid: String, r: Rect2) -> Control:
	var root: = Control.new()
	root.position = r.position
	root.size = r.size
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_medal(root, sid)
	root.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			root.accept_event()
			open_squad_modal())
	return root


func _build_squad_button(r: Rect2) -> Control:
	var p: = _pill_panel(r, Color(0.40, 0.10, 0.20, 0.97), Color("#FFE48F"), 15)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var l: = UI.label("Отряд", 15, Color("#FFF2C8"), Color(0.10, 0.02, 0.08), 4, "body", 900)
	l.size = r.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	p.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			p.accept_event()
			open_squad_modal())
	return p


func _refresh_squad_ui() -> void:
	for i in support_medals.size():
		var sid: = String(squad[i + 1]) if squad.size() > i + 1 else ""
		_set_medal(support_medals[i] as Control, sid)
	if hero_info_lbl != null:
		var syn: = V10AdventureData.active_synergy(squad) if squad.size() >= 2 else {}
		hero_info_lbl.text = "%s · %s" % [V10AdventureData.hero_name(hero_id), String(syn.get("name", V10AdventureData.HERO_PERKS.get(hero_id, "")))]
	_refresh_ult_only()


func _card_label(parent: Control, txt: String, fs: int, col: Color, r: Rect2, center: bool = false, wrap: bool = false) -> Label:
	var l: = UI.label(txt, fs, col, Color(0.07, 0.02, 0.10), 3, "body", 800)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = r.position
	l.size = r.size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not wrap:
		l.clip_text = true
	parent.add_child(l)
	return l


func _slot_perk(i: int, hid: String) -> Array:
	if hid == "":
		return ["Пусто", "Выбери богиню из списка ниже."]
	if i == 0 and V10AdventureData.HERO_PERKS.has(hid):
		var um: Dictionary = V10AdventureData.HERO_ULTS.get(hid, {})
		return [String(V10AdventureData.HERO_PERKS[hid]), "Ульта: %s" % String(um.get("title", "Суперудар"))]
	var pk: Dictionary = V10AdventureData.perk_of(hid)
	return [String(pk.get("name", "")), String(pk.get("desc", ""))]


func open_squad_modal() -> void:
	if _ended or _ult_casting or modal_layer == null:
		return
	if squad_modal != null and is_instance_valid(squad_modal):
		return
	squad_edit = squad.duplicate()
	while squad_edit.size() < V10AdventureData.SQUAD_SIZE:
		squad_edit.append("")
	squad_slot = 1
	_squad_prev_input = board != null and is_instance_valid(board) and board.input_on
	if board != null and is_instance_valid(board):
		board.input_on = false
	var dim: = ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.08, 0.86)
	dim.size = Vector2(W, H)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(dim)
	squad_modal = dim
	_squad_card = null
	_squad_draw()


func squad_assign(hid: String) -> bool:
	if squad_edit.size() < V10AdventureData.SQUAD_SIZE:
		return false
	if not V10AdventureData.hero_available(hid):
		return false
	if squad_slot == 0 and not Hero.RIGS.has(hid):
		return false
	var cur_idx: = squad_edit.find(hid)
	if cur_idx == squad_slot:
		return false
	if cur_idx >= 0:
		var tmp: Variant = squad_edit[squad_slot]
		squad_edit[squad_slot] = hid
		squad_edit[cur_idx] = tmp
	else:
		squad_edit[squad_slot] = hid
	# the lead can never be empty: a swap that leaves slot 0 empty is undone
	if String(squad_edit[0]) == "":
		squad_edit[0] = squad_edit[squad_slot]
		squad_edit[squad_slot] = ""
	return true


func squad_edit_ids() -> Array:
	return squad_edit.filter(func(h: Variant) -> bool: return String(h) != "")


func _squad_draw() -> void:
	if squad_modal == null or not is_instance_valid(squad_modal):
		return
	if _squad_card != null and is_instance_valid(_squad_card):
		squad_modal.remove_child(_squad_card)
		_squad_card.queue_free()
	var cw: = W - 56.0
	var ch: = 814.0
	var cy: = maxf(16.0, (H - ch) * 0.5)
	var card: = _pill_panel(Rect2(28, cy, cw, ch), Color(0.10, 0.04, 0.16, 0.99), Color("#F6D483"), 22)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	squad_modal.add_child(card)
	_squad_card = card
	var inner: = cw - 32.0
	_card_label(card, "ОТРЯД БОГИНЬ", 30, Color("#FFE8B8"), Rect2(16, 12, inner, 40), true)
	_card_label(card, "Выбери слот, затем богиню. Ведущая бьёт ультой, поддержка даёт пассивный бонус.", 15, Color("#DCC8E8"), Rect2(16, 54, inner, 40), true, true)

	# 3 slots
	var sw: = (inner - 20.0) / 3.0
	for i in V10AdventureData.SQUAD_SIZE:
		var hid: = String(squad_edit[i])
		var sx: = 16.0 + float(i) * (sw + 10.0)
		var sel: = i == squad_slot
		var sp: = _pill_panel(Rect2(sx, 100, sw, 154), Color(0.22, 0.09, 0.28, 0.98) if sel else Color(0.12, 0.06, 0.18, 0.95), Color("#FFE48F") if sel else Color(0.62, 0.50, 0.30, 0.70), 14)
		sp.mouse_filter = Control.MOUSE_FILTER_STOP
		var slot_i: = i
		sp.gui_input.connect(func(e: InputEvent) -> void:
			if _is_tap(e):
				sp.accept_event()
				squad_slot = slot_i
				call_deferred("_squad_draw"))
		card.add_child(sp)
		_portrait_box(sp, hid, Rect2(8, 8, 72, 72))
		sp.add_child(_frame_only(Rect2(8, 8, 72, 72), Color("#F6D483"), 8))
		_card_label(sp, "ВЕДУЩАЯ" if i == 0 else "ПОДДЕРЖКА %d" % i, 12, Color("#FFD070") if i == 0 else Color("#C8B4F0"), Rect2(88, 8, sw - 94, 18))
		_card_label(sp, V10AdventureData.hero_name(hid) if hid != "" else "Пусто", 17, Color("#FFF2DC"), Rect2(88, 26, sw - 94, 24))
		var pk: Array = _slot_perk(i, hid)
		_card_label(sp, String(pk[0]), 12, Color("#FFE0A0"), Rect2(88, 52, sw - 94, 28), false, true)
		_card_label(sp, String(pk[1]), 13, Color("#EBDDF2"), Rect2(8, 88, sw - 16, 60), false, true)

	# active synergy
	var chosen: Array = squad_edit_ids()
	var syn: = V10AdventureData.active_synergy(chosen)
	var syn_box: = _pill_panel(Rect2(16, 264, inner, 66), Color(0.30, 0.18, 0.04, 0.95) if not syn.is_empty() else Color(0.12, 0.06, 0.16, 0.95), Color("#FFE48F") if not syn.is_empty() else Color(0.55, 0.45, 0.30, 0.6), 14)
	card.add_child(syn_box)
	var syn_title: = ("★ СИНЕРГИЯ · %s" % String(syn.name)) if not syn.is_empty() else "Синергии нет: собери отряд из 3 богинь"
	_card_label(syn_box, syn_title, 19, Color("#FFE680") if not syn.is_empty() else Color("#BFA8D0"), Rect2(14, 6, inner - 28, 28), true)
	_card_label(syn_box, String(syn.get("desc", "Три разные богини дают бонус Трио Гармонии.")), 14, Color("#FFF3D6"), Rect2(14, 34, inner - 28, 26), true)

	var all_syn: Array[String] = []
	for sdef in V10AdventureData.SQUAD_SYNERGIES:
		if bool(sdef.get("trio", false)):
			continue
		var names: Array[String] = []
		for a in (sdef.all as Array):
			names.append(V10AdventureData.hero_name(String(a)))
		var any_n: Array[String] = []
		for a in (sdef.any as Array):
			any_n.append(V10AdventureData.hero_name(String(a)))
		if not any_n.is_empty():
			names.append("/".join(any_n))
		all_syn.append("%s (%s)" % [String(sdef.name), " + ".join(names)])
	_card_label(card, "Все синергии: " + " · ".join(all_syn), 12, Color("#BFA8D0"), Rect2(16, 336, inner, 52), false, true)

	# roster grid (10 goddesses)
	var cell_w: = (inner - 32.0) / 5.0
	var ids: Array = V10AdventureData.SUPPORT_PERKS.keys()
	for k in ids.size():
		var hid2: = String(ids[k])
		var col: = k % 5
		var row: = k / 5
		var cx: = 16.0 + float(col) * (cell_w + 8.0)
		var cell_y: = 394.0 + float(row) * 148.0
		var avail: = V10AdventureData.hero_available(hid2)
		var slot_of: = squad_edit.find(hid2)
		var cell: = _pill_panel(Rect2(cx, cell_y, cell_w, 140), Color(0.14, 0.07, 0.20, 0.95), Color("#FFE48F") if slot_of >= 0 else Color(0.55, 0.45, 0.30, 0.55), 12)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		var hid_c: = hid2
		cell.gui_input.connect(func(e: InputEvent) -> void:
			if _is_tap(e):
				cell.accept_event()
				if squad_assign(hid_c):
					call_deferred("_squad_draw")
				else:
					V9Feel.deny(cell)
					var why: = "Богиня ещё не открыта" if not V10AdventureData.hero_available(hid_c) else "Ведущей нужна поза в бою"
					V10AdventureVfx.spawn_float_text(squad_modal, Vector2(W * 0.5, cell.get_global_rect().position.y - 20.0), why, Color("#FFD670"), 20, 0.8))
		card.add_child(cell)
		var pbx: = (cell_w - 88.0) * 0.5
		_portrait_box(cell, hid2, Rect2(pbx, 6, 88, 88), not avail)
		cell.add_child(_frame_only(Rect2(pbx, 6, 88, 88), Color("#F6D483") if avail else Color(0.5, 0.45, 0.4, 0.8), 8))
		if slot_of >= 0:
			var badge: = _pill_panel(Rect2(pbx - 4, 2, 24, 24), Color("#D9384A"), Color("#FFE48F"), 12)
			cell.add_child(badge)
			var bl: = UI.label("%d" % (slot_of + 1), 14, Color.WHITE, Color(0.1, 0.0, 0.04), 3, "body", 900)
			bl.size = badge.size
			bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.add_child(bl)
		_card_label(cell, V10AdventureData.hero_name(hid2), 14, Color("#FFF2DC") if avail else Color("#9A8CA8"), Rect2(0, 98, cell_w, 20), true)
		var pn: = String(V10AdventureData.perk_of(hid2).get("name", ""))
		_card_label(cell, pn if avail else "Не открыта", 11, Color("#FFD890") if avail else Color("#8A7C98"), Rect2(2, 118, cell_w - 4, 18), true)

	var done_b: = JButton.make("Готово", "gold", Rect2(16, 700, inner * 0.6 - 6.0, 64), null, 24)
	done_b.pressed.connect(squad_commit)
	card.add_child(done_b)
	var close_b: = JButton.make("Закрыть", "graphite", Rect2(16.0 + inner * 0.6 + 6.0, 700, inner * 0.4 - 6.0, 64), null, 22)
	close_b.pressed.connect(squad_close)
	card.add_child(close_b)
	_card_label(card, "Смена ведущей начинает бой заново, смена поддержки применяется сразу.", 12, Color("#A898B8"), Rect2(16, 776, inner, 30), true, true)


func squad_close() -> void:
	if squad_modal != null and is_instance_valid(squad_modal):
		squad_modal.queue_free()
	squad_modal = null
	_squad_card = null
	if not _ended and not _ult_casting and board != null and is_instance_valid(board):
		board.input_on = true


func squad_commit() -> void:
	var chosen: Array = squad_edit_ids()
	if chosen.is_empty():
		squad_close()
		return
	var lead: = String(chosen[0])
	V10AdventureData.set_squad(chosen)
	G.save()
	var same: = chosen == squad
	squad_close()
	if same:
		return
	if lead != hero_id and main != null and main.has_method("go"):
		main.go("adventure", {"stage": stage_idx, "hero": lead, "skip_stamina": true})
		return
	squad = chosen
	battle.set_squad(squad, V10AdventureData.aff_bonuses(hero_id))
	_refresh_squad_ui()


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
