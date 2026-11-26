class_name V10AdventureSelftest
extends Control

# Automated selftest for 0.11.0 Omniheroes Monster Battle RPG Mode ("adventure").
# Run: Godot --headless --audio-driver Dummy --path game res://scripts/v10/adventure/adventure_selftest.tscn '--' '--adventure_selftest=1'

var _pass: = 0
var _fail: = 0


class _MockStamina:
	var tea: = 30
	var cap_v: = 120
	var sheet_opened: = 0

	func current() -> int:
		return tea

	func cap() -> int:
		return cap_v

	func can_spend(cost: int) -> bool:
		return tea >= cost

	func spend(cost: int, _reason: String = "") -> bool:
		if tea < cost:
			return false
		tea -= cost
		return true

	func refund(amount: int) -> void:
		tea = mini(cap_v, tea + amount)

	func open_sheet(_m) -> void:
		sheet_opened += 1


func _check(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		printerr("ADVENTURE_SELFTEST FAIL: %s" % msg)


func _ready() -> void:
	await get_tree().process_frame
	_run()
	print("ADVENTURE_SELFTEST %d/%d" % [_pass, _pass + _fail])
	await get_tree().process_frame
	get_tree().quit(0 if _fail == 0 else 1)


func _run() -> void:
	# 1. Data integrity (6 monsters, valid arts & boards)
	_check(V10AdventureData.count() >= 6, "at least 6 monsters defined")
	for i in V10AdventureData.count():
		var m: Dictionary = V10AdventureData.monster_at(i)
		_check(String(m.id) != "", "monster %d id non-empty" % i)
		_check(int(m.hp) >= 100, "monster %d hp valid" % i)
		_check(int(m.atk) > 0 and int(m.cadence) >= 3, "monster %d atk/cadence valid" % i)
		_check(V10AdventureData.monster_texture(String(m.id)) != null, "monster %d texture loads" % i)
		var bcfg: Dictionary = V10AdventureData.board_cfg(i, 0)
		_check(int(bcfg.get("cols", 0)) >= 5 and int(bcfg.get("faces", 0)) >= 7, "monster %d board cfg valid" % i)

	# 2. Combat math: pair, combo, crit, ult multi-hit, monster counter-attack debuff metadata, win/lose
	var bt: = V10AdventureBattle.new(0, "mc")
	var hp0: = bt.mon_hp
	var r1: = bt.on_pair(1, false)
	_check(int(r1.damage) > 0 and bt.mon_hp == hp0 - int(r1.damage), "pair damages monster")
	var r2: = bt.on_pair(4, true)
	_check(bool(r2.crit) and int(r2.damage) > int(r1.damage) * 2, "gold combo deals crit damage")
	_check(bt.ult > 0, "matching charges ult")

	for _k in 8:
		if bt.over:
			break
		bt.on_pair(2, false)
	if not bt.over and bt.ult_ready():
		var u_hp: = bt.mon_hp
		var ur: = bt.use_ult()
		_check(int(ur.damage) >= 100 and bt.mon_hp < u_hp, "ult deals massive damage")
		_check((ur.get("hits", []) as Array).size() == 3 and bool(ur.get("cleansed", false)), "ult returns 3-hit burst + cleanse flag")
		_check(bt.stun == V10AdventureData.ULT_STUN_TURNS, "ult stuns monster")

	var bt2: = V10AdventureBattle.new(2, "rin")
	bt2.ult = V10AdventureData.ULT_MAX
	bt2.use_ult()
	var h_before: = bt2.hero_hp
	var cadence: = int(bt2.m.cadence)
	var hit_ev: = {}
	for _k in cadence:
		hit_ev = bt2.on_move()
	_check(bool(hit_ev.get("stunned", false)) and bt2.hero_hp == h_before, "stun prevents monster attack")

	bt2.stun = 0
	for _k in cadence:
		hit_ev = bt2.on_move()
	_check(bool(hit_ev.get("attack", false)) and bt2.hero_hp < h_before, "monster attacks heroine after cadence")
	_check(String(hit_ev.get("debuff", "")) == "freeze" and bt2.debuffs_applied == 1, "monster attack carries debuff payload")

	var bt3: = V10AdventureBattle.new(5, "nova")
	for _k in 20:
		if bt3.over:
			break
		bt3.on_overflow()
	_check(bt3.over and not bt3.won and bt3.hero_hp == 0, "repeated overflow defeats heroine")

	# 3. Save persistence, progression & soft V10Stamina hook + .ogv resolver
	var fake_s: = {}
	var st: = V10AdventureData.ensure(fake_s)
	_check(int(st.stage) == 0 and int(st.best_stage) == 0, "default save initialized")
	var rw: = V10AdventureData.record_win(0, 180, fake_s)
	_check(bool(rw.first_clear) and int(rw.gems) > 0 and int(st.stage) == 1 and int(st.best_stage) == 1, "first clear unlocks stage 1")
	var info: = V10AdventureData.hub_card_info(fake_s)
	_check(String(info.screen) == "adventure" and int(info.stage) == 1, "hub_card_info reflects progression")

	_check(V10AdventureData.STAMINA_COST == 15 and V10AdventureData.STAMINA_DEFEAT_REFUND == 10, "stamina cost=15 and refund=10 configured")
	var mock_st: = _MockStamina.new()
	V10AdventureData._stamina_mock = mock_st
	_check(V10AdventureData.try_spend_stamina(null) and mock_st.tea == 15, "try_spend_stamina spends 15 tea")
	_check(V10AdventureData.try_spend_stamina(null) and mock_st.tea == 0, "second adventure spend reaches 0 tea")
	_check(not V10AdventureData.try_spend_stamina(self) and mock_st.sheet_opened == 1, "insufficient tea blocks entry and opens stamina sheet")
	_check(V10AdventureData.refund_defeat_stamina() == 10 and mock_st.tea == 10, "defeat refunds 10 tea")
	V10AdventureData._stamina_mock = null

	_check(V10AdventureData.ult_video_path("mc").ends_with("mc.ogv"), "mc ult video resolves to mc.ogv")
	_check(V10AdventureData.ult_video_path("mc", "o_dragon").ends_with("o_dragon.ogv"), "o_dragon outfit resolves to o_dragon.ogv")

	# 4. Omniheroes VFX state: DelayedBar white trail, Bezier projectiles, 0.55s SlashFx, 0.90s ComboBanner
	var dbar: = V10AdventureVfx.DelayedBar.new().setup(Rect2(0, 0, 300, 28), Color.RED, Color.DARK_RED)
	dbar.set_frac(1.0, true)
	dbar.set_frac(0.52, false)
	_check(is_equal_approx(dbar.cur_frac, 0.52) and is_equal_approx(dbar.trail_frac, 1.0), "DelayedBar captures white damage trail at 1.0")
	dbar.step_bar(0.25)
	_check(dbar.trail_frac > 0.98, "DelayedBar holds white damage trail during hold window")
	dbar.step_bar(1.10)
	_check(is_equal_approx(dbar.trail_frac, 0.52), "DelayedBar smoothly drains white trail to cur_frac")
	dbar.free()

	var vfx_box: = Control.new()
	add_child(vfx_box)
	var arrived_hits: = [0]
	var orbs: = V10AdventureVfx.spawn_projectiles(vfx_box, Vector2(200, 900), Vector2(540, 200), 3, Color.GOLD, func() -> void:
		arrived_hits[0] += 1)
	_check(orbs.size() == 3, "spawn_projectiles launches 3 curved Bezier orbs")
	for _step in 16:
		for o in orbs:
			if is_instance_valid(o):
				(o as Node)._process(0.04)
	_check(arrived_hits[0] == 1, "Bezier energy orbs reach boss and fire impact callback")

	var slash: = V10AdventureVfx.spawn_slash(vfx_box, Vector2(540, 200), Color.GOLD, 2)
	_check(slash != null and is_equal_approx(slash.dur, 0.55) and slash.slashes.size() == 2, "SlashFx lingers 0.55s with twin diagonal arcs")

	var cban: = V10AdventureVfx.ComboBanner.new().setup(Rect2(160, 320, 400, 58))
	vfx_box.add_child(cban)
	cban.trigger(3, true, 1.5)
	cban.step_banner(0.85)
	_check(cban.is_showing() and cban.modulate.a > 0.99, "ComboBanner holds full visibility through 0.90s window")
	cban.step_banner(0.60)
	_check(not cban.is_showing(), "ComboBanner fades out cleanly after hold")
	vfx_box.free()

	# 5. Real TrayBoard freeze & fog debuffs + Ultimate cleanse
	var tb: = TrayBoard.new()
	add_child(tb)
	tb.setup(V10AdventureData.board_cfg(2, 0))
	var frz: = V10AdventureVfx.apply_board_debuff(tb, "freeze", 2)
	var fog: = V10AdventureVfx.apply_board_debuff(tb, "fog", 2)
	_check(frz.size() == 2 and frz[0].ice >= 1, "freeze debuff freezes 2 tiles on TrayBoard with ice>=1")
	_check(fog.size() == 2 and V10AdventureVfx.active_debuff_count(tb) == 4, "fog + freeze attach 4 visible debuff overlays on TrayBoard")
	V10AdventureVfx.tick_board_fog(tb)
	var cleansed_n: = V10AdventureVfx.cleanse_board_debuffs(tb)
	_check(cleansed_n >= 4 and V10AdventureVfx.active_debuff_count(tb) == 0, "Ultimate cleanse removes all freeze & fog debuffs from TrayBoard")
	tb.free()

	# 6. Full 20:9 (720x1600) V10AdventureScreen layout: 210x210 top boss & bottom 1-thumb Ult dock
	var scr: = V10AdventureScreen.new()
	scr.size = Vector2(720, 1600)
	add_child(scr)
	scr.build(null, {"stage": 2, "hero": "mc", "skip_stamina": true})
	_check(scr.mon_clip != null and scr.mon_clip.size == Vector2(210, 210), "top boss portrait showcased at 210x210")
	_check(scr.dock_rect.position.y > 1350.0 and scr.ult_btn != null and scr.ult_btn.size.x >= 300.0, "heroine Ult dock placed at bottom for 1-thumb reach")
	scr.dev_act("combat_showcase")
	_check(scr.mon_hp_bar.trail_frac > scr.mon_hp_bar.cur_frac and scr.combo_banner.is_showing(), "combat_showcase activates delayed HP white bar & combo banner")
	_check(V10AdventureVfx.active_debuff_count(scr.board) > 0, "combat_showcase applies visible debuffs to TrayBoard")
	scr.free()
