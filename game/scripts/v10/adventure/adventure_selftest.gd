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
	_check(scr.shield_bar != null and scr.shield_bar.size.y >= 20.0, "boss shield bar is built under the boss HP bar")
	_check(scr.support_medals.size() == 2 and (scr.support_medals[0] as Control).size == Vector2(48, 48) and (scr.support_medals[1] as Control).size == Vector2(48, 48), "two 48x48 support medallions sit in the dock")
	_check(scr.squad_btn != null, "dock has the Отряд button")
	scr.free()
	_run_squad()


func _approx(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


# 0.12: squad of 3 goddesses, passives, synergies, boss shield break (×2), raid score
func _run_squad() -> void:
	var D: = V10AdventureData
	# 7. data: shields on every monster, 10 support perks
	var prev_sh: = 0
	for i in D.count():
		var sm: Dictionary = D.monster_at(i)
		var smx: = int(sm.get("shield_max", 0))
		_check(smx >= 60 and smx <= 140 and smx >= prev_sh, "monster %d shield_max %d in 60..140 and rising" % [i, smx])
		prev_sh = smx
	_check(D.SUPPORT_PERKS.size() == 10, "SUPPORT_PERKS covers all 10 heroines")
	for hid in ["mc", "rin", "hana", "yue", "nova", "tsubame", "miel", "kohaku", "shirin", "zlata"]:
		var pk: Dictionary = D.perk_of(hid)
		var nums: = 0
		for k in pk:
			if k != "name" and k != "desc":
				nums += 1
		_check(String(pk.get("name", "")) != "" and String(pk.get("desc", "")) != "" and nums >= 1, "support perk of %s has name, desc and a numeric bonus" % hid)

	# 8. synergies
	_check(String(D.active_synergy(["mc", "rin", "yue"]).get("id", "")) == "salon_owners", "mc+rin gives Хозяйки Салона")
	_check(String(D.active_synergy(["yue", "nova", "mc"]).get("id", "")) == "moon_storm", "yue+nova gives Лунный Шторм")
	_check(String(D.active_synergy(["hana", "zlata", "mc"]).get("id", "")) == "fire_east", "hana+zlata gives Огонь Востока")
	_check(String(D.active_synergy(["kohaku", "hana", "nova"]).get("id", "")) == "fire_east", "hana+kohaku gives Огонь Востока")
	_check(String(D.active_synergy(["tsubame", "miel", "nova"]).get("id", "")) == "night_swallows", "tsubame+miel gives Сладкая Доставка")
	_check(String(D.active_synergy(["kohaku", "shirin", "nova"]).get("id", "")) == "temple_caravan", "kohaku+shirin gives Храм и Караван")
	_check(String(D.active_synergy(["hana", "rin", "nova"]).get("id", "")) == "trio_harmony", "any 3 goddesses give Трио Гармонии")
	_check(String(D.active_synergy(["tsubame", "shirin", "zlata"]).get("id", "")) == "trio_harmony", "wave-1 trio gets Трио Гармонии too")
	_check(D.active_synergy(["mc", "mc"]).is_empty() and D.active_synergy(["mc", "rin"]).get("id", "") == "salon_owners", "duplicates give nothing, a duo still counts specific synergy")

	# 9. squad mods math
	var m1: = D.squad_mods(["mc", "rin", "yue"])
	_check(_approx(float(m1.get("dmg_mult", 0.0)), 0.12) and int(m1.get("heal_gold", 0)) == 3 and _approx(float(m1.get("crit_add", 0.0)), 0.15), "squad mods add support perks and the synergy (lead founder perk is not duplicated)")
	var m2: = D.squad_mods(["zlata", "hana", "nova"])
	_check(int(m2.get("dmg_flat", 0)) == 5 and _approx(float(m2.get("shield_mult", 0.0)), 0.35) and _approx(float(m2.get("combo_step_add", 0.0)), 0.05), "wave-1 lead keeps her own perk plus fire_east shield bonus")
	var base_p: = D.calc_pair_damage(1, false, "mc")
	_check(int(base_p.damage) == 20 and int(base_p.shield) == 12 and int(base_p.ult_gain) == 17, "baseline pair: 20 damage, 12 shield, 17 ult (mc)")
	var gold_p: = D.calc_pair_damage(1, true, "mc")
	_check(int(gold_p.damage) == 44 and int(gold_p.shield) == 25, "baseline gold pair: 44 damage, 25 shield")
	_check(int(D.calc_pair_damage(1, false, "mc", {"dmg_mult": 0.12}).damage) == 22, "dmg_mult 0.12 raises 20 to 22")
	_check(int(D.calc_pair_damage(1, true, "mc", {"crit_add": 0.30}).damage) == 50, "crit_add 0.30 makes a gold pair 50")
	_check(int(D.calc_pair_damage(1, false, "mc", {"shield_flat": 3}).shield) == 15 and int(D.calc_pair_damage(1, true, "mc", {"shield_gold": 6}).shield) == 31, "shield_flat and shield_gold add to shield damage")
	_check(int(D.calc_pair_damage(1, false, "mc", {"shield_mult": 0.35}).shield) == 16, "shield_mult 0.35 turns 12 into 16")
	_check(int(D.calc_pair_damage(1, false, "mc", {"ult_gain_flat": 2}).ult_gain) == 19 and int(D.calc_pair_damage(1, true, "rin", {"heal_gold": 3}).heal) == 9, "ult_gain_flat and heal_gold apply")
	_check(int(D.calc_ult_damage(0, "mc").shield) == 45 and int(D.calc_ult_damage(0, "mc", {"shield_mult": 0.35}).shield) == 61 and int(D.calc_ult_damage(0, "mc", {"ult_dmg_flat": 12}).damage) == 127, "ult chips 45 shield (61 with fire_east) and ult_dmg_flat adds 12")

	# 10. shield break
	var bt: = V10AdventureBattle.new(0, "mc")
	bt.mon_hp = 100000
	bt.mon_max = 100000
	_check(bt.shield == 60 and bt.shield_max == 60 and bt.broken_turns == 0, "fresh boss has full shield and no break")
	var rp: = bt.on_pair(1, false)
	_check(bt.shield == 48 and not bool(rp.broke) and not bool(rp.doubled), "a normal pair removes 12 shield")
	var rg: = bt.on_pair(1, true)
	_check(bt.shield == 23 and not bool(rg.broke), "a gold pair removes 25 shield")
	bt.on_pair(1, false)
	var rb: = bt.on_pair(1, false)
	_check(bt.shield == 60 and bool(rb.broke) and bt.broken_turns == 3 and bt.breaks == 1, "shield 0 breaks: broken_turns 3, shield refills to max")
	_check(bt.stun >= 1, "shield break stuns the boss for a turn")
	var rd: = bt.on_pair(1, false)
	_check(bool(rd.doubled) and int(rd.damage) == 40 and bt.broken_turns == 2 and bt.shield == 60, "broken boss takes ×2 damage and the shield stays full")
	bt.on_pair(1, false)
	var rd3: = bt.on_pair(1, true)
	_check(int(rd3.damage) == 88 and bt.broken_turns == 0 and bt.shield == 60, "gold pair is ×2 too, the third doubled hit ends the break")
	var rafter: = bt.on_pair(1, false)
	_check(not bool(rafter.doubled) and int(rafter.damage) == 20 and bt.shield == 48, "after the break damage is normal and the shield chips again")
	bt.ult = D.ULT_MAX
	bt.shield = 30
	var ru: = bt.use_ult()
	_check(bool(ru.broke) and bt.broken_turns == 3 and bt.shield == 60 and bt.stun >= D.ULT_STUN_TURNS, "ult (45 shield) can break the shield and keeps its stun")
	bt.ult = D.ULT_MAX
	var ru2: = bt.use_ult()
	_check(bool(ru2.doubled) and int(ru2.damage) == int(D.calc_ult_damage(0, "mc").damage) * 2 and bt.broken_turns == 2, "ult during a break deals ×2 and uses one turn")
	var bt_k: = V10AdventureBattle.new(0, "mc")
	bt_k.mon_hp = 1
	bt_k.shield = 1
	var rk: = bt_k.on_pair(1, false)
	_check(bool(rk.killed) and not bool(rk.broke), "a killing blow does not trigger a break")
	var bt_s: = V10AdventureBattle.new(0, "mc")
	bt_s.mon_hp = 100000
	bt_s.mon_max = 100000
	bt_s.on_pair(1, true)
	bt_s.on_pair(1, true)
	var rs: = bt_s.on_pair(1, true)
	_check(bt_s.breaks == 1 and bool(rs.broke) and bt_s.shield_frac() == 1.0 and is_equal_approx(bt_s.hp_frac(), 1.0 - float(bt_s.dmg_total) / 100000.0), "three gold pairs break shield 60 and fractions stay consistent")
	var st_ev: = {}
	for _k in int(bt.m.cadence):
		st_ev = bt.on_move()
	_check(bool(st_ev.get("stunned", false)) or bool(st_ev.get("attack", false)), "boss turn after a break resolves as stun or attack")

	# 11. squad battle
	var bs: = V10AdventureBattle.new(0, "mc", ["mc", "rin", "yue"])
	_check(String(bs.synergy.get("id", "")) == "salon_owners" and bs.squad.size() == 3, "squad battle picks the active synergy")
	var rps: = bs.on_pair(1, false)
	_check(int(rps.damage) == 22, "Хозяйки Салона raise the pair to 22")
	var rgs: = bs.on_pair(1, true)
	_check(int(rgs.heal) == 3 and bs.mods.has("crit_add"), "rin support heals 3 on a gold pair, yue adds crit")
	var bf: = V10AdventureBattle.new(0, "hana", ["hana", "zlata", "nova"])
	var rf: = bf.on_pair(1, false)
	_check(String(bf.synergy.get("id", "")) == "fire_east" and int(rf.shield) > 12 and bf.shield == 60 - int(rf.shield), "fire_east removes more shield per pair")
	var bt_aff: = V10AdventureBattle.new(0, "mc", [], {"atk_bonus": 0.2})
	_check(int(bt_aff.on_pair(1, false).damage) == 24 and int(V10AdventureBattle.new(0, "mc").on_pair(1, false).damage) == 20, "affection bonus is optional and never leaks into the default math")
	var bt_solo: = V10AdventureBattle.new(0, "mc", ["mc"])
	_check(bt_solo.synergy.is_empty() and bt_solo.squad.size() == 1, "a one-goddess squad has no synergy and is not padded")

	# 12. squad & raid persistence
	var fs: = {}
	var sd: = D.ensure(fs)
	_check((sd.squad as Array) == ["mc", "rin", "yue"] and int(sd.best_raid_dmg) == 0 and not bool(sd.squad_custom), "default save: squad mc/rin/yue and best_raid_dmg 0")
	_check(D.set_squad(["hana", "nova", "bogus", "hana"], fs) == ["hana", "nova", "mc"] and bool(sd.squad_custom), "set_squad validates ids, removes duplicates and pads to 3")
	fs["v10_adventure"]["squad"] = "garbage"
	_check(D.ensure(fs).squad == ["mc", "rin", "yue"], "a corrupt squad in the save is repaired on load")
	D.set_squad(["hana", "nova", "mc"], fs)
	_check(D.squad_for_lead("nova", fs) == ["nova", "hana", "mc"] and D.squad_for_lead("rin", fs) == ["rin", "hana", "nova"], "squad_for_lead rotates or replaces the lead")
	var rr1: = D.record_raid(0, 500, 2, fs)
	_check(bool(rr1.new_best) and int(sd.best_raid_dmg) == 500 and int(sd.shield_breaks) == 2, "record_raid stores the best raid damage and shield breaks")
	var rr2: = D.record_raid(0, 300, 0, fs)
	_check(not bool(rr2.new_best) and int(sd.best_raid_dmg) == 500, "a weaker raid does not replace the record")
	var rr3: = D.record_raid(1, 800, 0, fs)
	_check(bool(rr3.new_best) and int(rr3.stage_best) == 800 and int((sd.raid_stage_best as Dictionary).get("paper_oni", 0)) == 500, "raid record is kept per stage and overall")
	var rw2: = D.record_win(2, 900, fs, 1)
	_check(int(sd.best_raid_dmg) == 900 and bool(rw2.raid.new_best), "record_win feeds the raid score")
	var rl: = D.record_defeat(1200, fs, 0, 3)
	_check(int(sd.best_raid_dmg) == 1200 and bool(rl.new_best), "record_defeat feeds the raid score too")

	# 13. online hook (soft dependency)
	var OnMock: = GDScript.new()
	OnMock.source_code = "extends RefCounted\nvar logged := true\nvar got := []\nfunc is_logged_in() -> bool:\n\treturn logged\nfunc submit_raid_score(stage_idx: int, damage: int) -> void:\n\tgot.append([stage_idx, damage])\n"
	OnMock.reload()
	var mock = OnMock.new()
	D._online_mock = mock
	_check(D.submit_raid_score(3, 777) and mock.got == [[3, 777]], "raid score is sent when the online client is logged in")
	mock.logged = false
	_check(not D.submit_raid_score(3, 888) and mock.got.size() == 1, "raid score is not sent while logged out")
	D._online_mock = RefCounted.new()
	_check(not D.submit_raid_score(3, 999), "a client without the API is ignored without errors")
	D._online_mock = null

	# 14. VFX: shield bar + shard burst + slow-mo constants
	var sbar: = V10AdventureVfx.ShieldBar.new().setup(Rect2(0, 0, 300, 24))
	add_child(sbar)
	sbar.set_state(60, 60, 0, true)
	_check(not sbar.is_blinking() and is_equal_approx(sbar.frac(), 1.0) and sbar.label_text().contains("60 / 60"), "ShieldBar shows the full shield")
	sbar.set_state(25, 60, 0)
	_check(sbar.trail_frac > sbar.frac() and sbar.label_text().contains("25 / 60"), "ShieldBar keeps a trail when the shield drops")
	sbar.set_state(60, 60, 3)
	_check(sbar.is_blinking() and sbar.label_text().contains("ПРОБИТИЕ ×2"), "ShieldBar blinks and says ПРОБИТИЕ ×2 during a break")
	sbar.free()
	var fxl: = Control.new()
	add_child(fxl)
	var burst: = V10AdventureVfx.spawn_shield_break(fxl, Vector2(500, 300), false)
	_check(burst != null and burst.shards.size() >= 20, "spawn_shield_break launches a burst of gold shards")
	burst.step(0.2)
	_check(burst.shards[0].p != Vector2.ZERO and Engine.time_scale == 1.0, "shards fly out and no slow-mo is left running")
	_check(is_equal_approx(V10AdventureVfx.SHIELD_SLOWMO_SEC, 0.11) and is_equal_approx(V10AdventureVfx.SHIELD_SLOWMO_SCALE, 0.25), "slow-mo is 110 ms at time_scale 0.25")
	fxl.free()

	# 15. screen: squad window, shield HUD in a real break
	var old_shards: Dictionary = (G.S.shards as Dictionary).duplicate()
	G.S.shards["rin"] = 9999
	G.S.shards["hana"] = 9999
	var scr2: = V10AdventureScreen.new()
	scr2.size = Vector2(720, 1600)
	add_child(scr2)
	scr2.build(null, {"stage": 0, "hero": "mc", "skip_stamina": true})
	_check(scr2.squad.size() >= 3 and String(scr2.squad[0]) == "mc", "owned goddesses fill the squad with mc as lead")
	scr2.open_squad_modal()
	_check(scr2.squad_modal != null and scr2._squad_card != null, "Отряд opens the squad selection window")
	scr2.squad_slot = 2
	_check(scr2.squad_assign("rin") and String(scr2.squad_edit[2]) == "rin" and String(scr2.squad_edit[1]) == "hana", "assigning a goddess puts her in the selected slot and swaps")
	_check(not scr2.squad_assign("zlata"), "a goddess that is not owned cannot be assigned")
	_check(not scr2.squad_assign("rin") and scr2.squad_edit_ids().size() == 3, "assigning the goddess already in this slot changes nothing")
	scr2.squad_commit()
	_check(scr2.squad_modal == null and String(scr2.squad[1]) == "hana" and (D.get_squad() as Array).has("hana"), "commit saves the squad and closes the window")
	_check(String(scr2.battle.synergy.get("id", "")) != "" and scr2.battle.squad.size() >= 3, "battle gets the new squad immediately")
	scr2.battle.shield = 1
	scr2.dev_act("shield_break")
	_check(scr2.battle.broken_turns == 3 and scr2.battle.breaks == 1 and scr2.shield_bar.is_blinking(), "screen reflects a shield break on the HUD")
	G.S.shards = old_shards
	G.S.v10_adventure.squad = ["mc", "rin", "yue"]
	G.S.v10_adventure.squad_custom = false
	scr2.free()
