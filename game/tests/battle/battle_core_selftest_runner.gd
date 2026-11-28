extends Control

# Runner for P74 battle core selftest: AT-B01, AT-B03, AT-B04, AT-B05 (40 cases), AT-B06, AT-B15, AT-U10, T10 XP table, ULT_AIM journal.
# Run via godot_lock.ps1:
#   & $env:GODOT_BIN --headless --audio-driver Dummy --path game res://tests/battle/battle_core_selftest.tscn

var _ok: int = 0
var _total: int = 0
var _fails: Array = []


func _chk(cond: bool, what: String) -> void:
	_total += 1
	if cond:
		_ok += 1
	else:
		_fails.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	await get_tree().process_frame
	_run_all()
	var tag: String = "OK" if _ok == _total else "FAIL"
	print("BATTLE_CORE_SELFTEST %d/%d %s" % [_ok, _total, tag])
	get_tree().quit(0 if _ok == _total else 1)


func _run_all() -> void:
	TWBattleData.clear_cache()
	var bal: Dictionary = TWBattleData.balance()
	_test_t10_xp_table(bal)
	_test_at_b01_layer_a_isolation(bal)
	_test_at_b03_squad_stats(bal)
	_test_at_b05_formula_table_40(bal)
	_test_at_b06_energy_start_and_gain(bal)
	_test_at_b15_enrage_overflow_wave_clear(bal)
	_test_at_b04_and_at_u10_replay_determinism(bal)


func _test_t10_xp_table(bal: Dictionary) -> void:
	_chk(TWBattleMath.xp_cum(1) == 0, "T10 XP table: Lv1 == 0")
	_chk(TWBattleMath.xp_cum(20) == 12086, "T10 XP table: Lv20 == 12086")
	_chk(TWBattleMath.xp_cum(40) == 70595, "T10 XP table: Lv40 == 70595")
	_chk(TWBattleMath.xp_cum(60) == 196610, "T10 XP table: Lv60 == 196610")
	_chk(TWBattleMath.xp_cum(70) == 289922, "T10 XP table: Lv70 == 289922")
	_chk(TWBattleMath.xp_cum(80) == 405733, "T10 XP table: Lv80 == 405733")
	_chk(TWBattleMath.xp_cum(90) == 545611, "T10 XP table: Lv90 == 545611")
	var json_steps: Array = bal.get("progression", {}).get("xp_step", [])
	var table_match: bool = json_steps.size() == TWBattleMath.XP_STEP_TABLE.size()
	if table_match:
		for i in json_steps.size():
			if int(json_steps[i]) != int(TWBattleMath.XP_STEP_TABLE[i]):
				table_match = false
				break
	_chk(table_match, "T10 XP table: embedded XP_STEP_TABLE matches balance.json 89/89")
	_chk(TWBattleMath.mul_bp(1000, 3500) == 350, "mul_bp(1000, 3500) == 350")
	_chk(TWBattleMath.mul_bp(999, 3500) == 349, "mul_bp floor(999 * 3500 / 10000) == 349")
	_chk(TWBattleMath.mul_bp(-1, 5000) == -1, "mul_bp negative floor(-0.5) == -1")


func _test_at_b01_layer_a_isolation(bal: Dictionary) -> void:
	# AT-B01: 500 Layer A (TWBoard) seeds produce 0 difference regardless of Layer B outfits / talismans / Bond.
	var diffs: int = 0
	for s in range(1, 501):
		var cfg_a: Dictionary = {"shape": "rect", "cols": 4, "rows": 4, "layers": 2, "fill": 0.75, "faces": 6, "seed": s}
		var b1: TWBoard = TWBoard.from_cfg(cfg_a)
		# Compute Layer B whale squad stats between runs to prove zero shared global mutation into Layer A
		var _w: Dictionary = TWBattleProgress.compute_hero_stats("hana", {
			"level": 60, "talisman_atk_bp": 4300, "outfit_tier": "SSRP", "outfit_stars": 5, "album_count": 24, "bond_level": 10
		}, bal, {"outfit_stats_enabled": true, "bond_stats_enabled": true})
		var b2: TWBoard = TWBoard.from_cfg(cfg_a)
		if b1.state_hash() != b2.state_hash():
			diffs += 1
			continue
		# Play 6 deterministic solver moves on both boards and assert exact parity
		for _step in 6:
			var m1: int = b1.solver_move()
			var m2: int = b2.solver_move()
			if m1 != m2:
				diffs += 1
				break
			if m1 < 0:
				break
			b1.tap(m1)
			b2.tap(m2)
		if b1.state_hash() != b2.state_hash():
			diffs += 1
	_chk(diffs == 0, "AT-B01: Layer A TWBoard 500 seeds x different Layer B outfits/talismans/Bond => 0 diff (got %d)" % diffs)


func _test_at_b03_squad_stats(bal: Dictionary) -> void:
	var sq_specs: Array = [
		{"hero_id": "hana", "level": 60, "talisman_atk_bp": 4000, "outfit_tier": "SSRP", "outfit_stars": 5, "album_count": 12, "bond_level": 10},
		{"hero_id": "nova", "level": 60, "talisman_atk_bp": 4000, "outfit_tier": "SSR", "outfit_stars": 5, "album_count": 12, "bond_level": 10},
	]
	var bt_a: TWBattle = TWBattle.create(7403, sq_specs, {"boss_hp": 50000}, bal)
	var bt_f2p: TWBattle = TWBattle.create(7403, [
		{"hero_id": "hana", "level": 60, "talisman_atk_bp": 4000},
		{"hero_id": "nova", "level": 60, "talisman_atk_bp": 4000},
	], {"boss_hp": 50000}, bal)
	_chk(int(bt_a.squad[0].atk) == int(bt_f2p.squad[0].atk) and int(bt_a.squad[1].atk) == int(bt_f2p.squad[1].atk),
		"AT-B03 in TWBattle: Variant A defaults ignore outfit/stars/album/bond")
	var bt_b: TWBattle = TWBattle.create(7403, sq_specs, {"boss_hp": 50000}, bal, {"outfit_stats_enabled": true, "bond_stats_enabled": true})
	_chk(int(bt_b.squad[0].atk) > int(bt_a.squad[0].atk), "AT-B03 in TWBattle: Variant B flags apply bonuses cleanly")


func _test_at_b05_formula_table_40(bal: Dictionary) -> void:
	# AT-B05: 40 exact combat formula verification cases (BU §1.4 - §1.7).
	var sq: Array = [
		{"hero_id": "hana",   "role": "ATK",  "aura": "man", "atk": 1000, "hp": 800,  "energy_mult_bp": 10000, "ult_dmg_bp": 90000, "ult_level": 1},
		{"hero_id": "nova",   "role": "BRK",  "aura": "pin", "atk": 850,  "hp": 900,  "energy_mult_bp": 10000, "ult_dmg_bp": 55000, "ult_level": 1},
		{"hero_id": "mc",     "role": "SUP",  "aura": "sou", "atk": 600,  "hp": 1000, "energy_mult_bp": 11500, "ult_dmg_bp": 30000, "ult_level": 1},
		{"hero_id": "rin",    "role": "HEAL", "aura": "sou", "atk": 500,  "hp": 1100, "energy_mult_bp": 10000, "ult_dmg_bp": 25000, "ult_level": 1},
		{"hero_id": "kohaku", "role": "GRD",  "aura": "man", "atk": 550,  "hp": 1300, "energy_mult_bp": 10000, "ult_dmg_bp": 30000, "ult_level": 1},
	]
	var tally: Array = [0, 0] # [ok, n] - Array captured by reference in GDScript 4 closures

	# Helper to tally each case inside the 40-case table
	var check_eq := func(got: int, want: int, label: String) -> void:
		tally[1] = int(tally[1]) + 1
		if got == want:
			tally[0] = int(tally[0]) + 1
		else:
			print("  AT-B05 FAIL %s: got=%d want=%d" % [label, got, want])

	# Cases 1-4: suit/honor base pair strike (combo 1, no pattern)
	# man: 1000*1 + 850*0.4 + 600*0.4 + 500*0.4 + 550*1 = 1000+340+240+200+550 = 2330; *0.35 = 815
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 1, 0, {}, bal).dmg), 815, "C01 man c1")
	# pin: 1000*0.4 + 850*1 + 600*0.4 + 500*0.4 + 550*0.4 = 400+850+240+200+220 = 1910; *0.35 = 668
	check_eq.call(int(TWBattleMath.pair_damage(sq, "pin", 1, 0, {}, bal).dmg), 668, "C02 pin c1")
	# sou: 400 + 340 + 600 + 500 + 220 = 2060; *0.35 = 721
	check_eq.call(int(TWBattleMath.pair_damage(sq, "sou", 1, 0, {}, bal).dmg), 721, "C03 sou c1")
	# honor: (700 + 595 + 420 + 350 + 385) = 2450; *0.35 = 857
	check_eq.call(int(TWBattleMath.pair_damage(sq, "honor", 1, 0, {}, bal).dmg), 857, "C04 honor c1")

	# Case 5: honor resonant all (MC leader/ult): (1000+850+600+500+550)=3500; *0.35 = 1225
	check_eq.call(int(TWBattleMath.pair_damage(sq, "honor", 1, 0, {"honor_resonant": true}, bal).dmg), 1225, "C05 honor resonant")

	# Cases 6-12: combo scaling c=2..7 and cap at c=10 (all on man base=815)
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 2, 0, {}, bal).dmg), 1018, "C06 man c2 x1.25")
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 3, 0, {}, bal).dmg), 1222, "C07 man c3 x1.50")
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 4, 0, {}, bal).dmg), 1426, "C08 man c4 x1.75")
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 5, 0, {}, bal).dmg), 1630, "C09 man c5 x2.00")
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 6, 0, {}, bal).dmg), 1833, "C10 man c6 x2.25")
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 7, 0, {}, bal).dmg), 2037, "C11 man c7 x2.50")
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 12, 0, {}, bal).dmg), 2037, "C12 man c12 capped x2.50")

	# Cases 13-17: patterns ("Узоры") recognition & bonus damage
	var h_one: Array = [{"suit": "man", "face": 0, "rank": 1}, {"suit": "man", "face": 4, "rank": 5}, {"suit": "man", "face": 7, "rank": 8}]
	var p_one: Dictionary = TWBattleMath.pattern(h_one, bal)
	check_eq.call(int(p_one.dmg_bonus_bp), 2000, "C13 pattern one_suit +2000bp")

	var h_kan: Array = [{"suit": "man", "face": 0, "rank": 1}, {"suit": "man", "face": 4, "rank": 5}, {"suit": "man", "face": 4, "rank": 5}]
	var p_kan: Dictionary = TWBattleMath.pattern(h_kan, bal)
	check_eq.call(int(p_kan.dmg_bonus_bp), 2500, "C14 pattern kan beats one_suit +2500bp")

	var h_lad: Array = [{"suit": "pin", "face": 10, "rank": 2}, {"suit": "pin", "face": 11, "rank": 3}, {"suit": "pin", "face": 12, "rank": 4}]
	var p_lad: Dictionary = TWBattleMath.pattern(h_lad, bal)
	check_eq.call(int(p_lad.dmg_bonus_bp), 3500, "C15 pattern ladder +3500bp")

	var h_pure: Array = [
		{"suit": "sou", "face": 18, "rank": 1}, {"suit": "sou", "face": 19, "rank": 2}, {"suit": "sou", "face": 20, "rank": 3},
		{"suit": "sou", "face": 21, "rank": 4}, {"suit": "sou", "face": 22, "rank": 5}, {"suit": "sou", "face": 23, "rank": 6},
	]
	var p_pure: Dictionary = TWBattleMath.pattern(h_pure, bal)
	check_eq.call(int(p_pure.dmg_bonus_bp), 8000, "C16 pattern pure beats ladder +8000bp")
	check_eq.call(int(p_pure.energy_bonus_milli), 20000, "C17 pattern pure +20000 milli-energy")

	# Cases 18-26: individual & combined combat multipliers on man c1 (base=815)
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 1, 2000, {}, bal).dmg), 978, "C18 one_suit 815*1.2=978")
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 1, 0, {"weak": "man"}, bal).dmg), 1018, "C19 weak 815*1.25=1018")
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 1, 0, {"resist": "man"}, bal).dmg), 692, "C20 resist 815*0.85=692")
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 1, 0, {"fever": true}, bal).dmg), 1059, "C21 fever 815*1.30=1059")
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 1, 0, {"buff": true}, bal).dmg), 1018, "C22 buff 815*1.25=1018")
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 1, 0, {"gold": true}, bal).dmg), 1222, "C23 gold 815*1.50=1222")
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 1, 0, {"broken": true}, bal).dmg), 1630, "C24 broken 815*2.00=1630")
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 1, 0, {"from_ult": true}, bal).dmg), 407, "C25 from_ult 815*0.50=407")
	# Stacked chain: man c4 (1426) -> pat+35% (1925) -> weak 1.25 (2406) -> fever 1.3 (3127) -> buff 1.25 (3908) -> broken 2.0 (7816)
	check_eq.call(int(TWBattleMath.pair_damage(sq, "man", 4, 3500, {"weak": "man", "fever": true, "buff": true, "broken": true}, bal).dmg), 7816, "C26 stacked chain")

	# Cases 27-34: ult damage across 5 roles, skill levels, broken, ATK broken rider, Kohaku passive
	check_eq.call(TWBattleMath.ult_damage(sq[0], {}, bal), 9000, "C27 ATK ult Lv1 1000*9.0")
	check_eq.call(TWBattleMath.ult_damage(sq[1], {}, bal), 4675, "C28 BRK ult Lv1 850*5.5")
	check_eq.call(TWBattleMath.ult_damage(sq[2], {}, bal), 1800, "C29 SUP ult Lv1 600*3.0")
	check_eq.call(TWBattleMath.ult_damage(sq[3], {}, bal), 1250, "C30 HEAL ult Lv1 500*2.5")
	check_eq.call(TWBattleMath.ult_damage(sq[4], {}, bal), 1650, "C31 GRD ult Lv1 550*3.0")
	var hana_lv10: Dictionary = sq[0].duplicate()
	hana_lv10["ult_level"] = 10
	# 9000 * 1.54 = 13860
	check_eq.call(TWBattleMath.ult_damage(hana_lv10, {}, bal), 13860, "C32 ATK ult Lv10 x1.54")
	# broken x2.0 -> 18000; atk_broken_bonus x1.25 -> 22500
	check_eq.call(TWBattleMath.ult_damage(sq[0], {"broken": true, "atk_broken_bonus": true}, bal), 22500, "C33 ATK ult broken +25% rider")
	# Kohaku passive +4%: 9000 * 1.04 = 9360
	check_eq.call(TWBattleMath.ult_damage(sq[0], {"team_ult_dmg_bonus_bp": 400}, bal), 9360, "C34 Kohaku team ult +4%")

	# Cases 35-38: shield damage & boss cast damage
	check_eq.call(TWBattleMath.shield_damage_milli(false, true, "", true, 0, 10000, bal), 2000, "C35 shield pair brk+fever=2000")
	check_eq.call(TWBattleMath.shield_damage_milli(true, true, "BRK", false, 0, 10000, bal), 6000, "C36 shield ult BRK=6000")
	# boss cast: ref=4000, wave=0, cast=1 -> 1600; wave=1 (x1.8) -> 2880; wave=1 heavy cast=3 (x1.8) -> 5184
	check_eq.call(TWBattleMath.boss_cast_damage(4000, 0, 1, 4000, bal), 1600, "C37 boss cast normal w0")
	check_eq.call(TWBattleMath.boss_cast_damage(4000, 1, 3, 4000, bal), 5184, "C38 boss cast enrage w1 heavy c3")

	# Cases 39-40: face->suit/rank mapping & energy gain formula
	check_eq.call(1 if (TWBattleMath.suit_of_face(0) == "man" and TWBattleMath.suit_of_face(9) == "pin" and TWBattleMath.suit_of_face(18) == "sou" and TWBattleMath.suit_of_face(27) == "honor" and TWBattleMath.rank_of_face(17) == 9) else 0, 1, "C39 face->suit/rank mapping")
	# SUP (enr 1.15) resonant sou, combo 3 (c_steps=2 -> +400), fever (x1.5):
	# base 2400 * 1.15 = 2760; * 1.6 = 4416; + 400 = 4816; * 1.5 = 7224
	check_eq.call(TWBattleMath.energy_gain_milli(sq[2], "sou", 3, true, false, bal), 7224, "C40 SUP resonant c3 fever energy=7224")

	_chk(int(tally[1]) == 40 and int(tally[0]) == 40, "AT-B05: 40-case combat formula table exact integer match (%d/%d)" % [int(tally[0]), int(tally[1])])


func _test_at_b06_energy_start_and_gain(bal: Dictionary) -> void:
	# AT-B06: 10 heroines x 3 outfit tiers x Bond 0/10 -> start=40000 (40) and gain independent of outfit/bond.
	var hero_ids: Array = ["mc", "rin", "hana", "yue", "nova", "tsubame", "miel", "kohaku", "shirin", "zlata"]
	var outfits: Array = [
		{"outfit_tier": "BASE", "outfit_stars": 0, "bond_level": 0},
		{"outfit_tier": "S",    "outfit_stars": 5, "bond_level": 5},
		{"outfit_tier": "SSRP", "outfit_stars": 5, "bond_level": 10},
	]
	var all_start_40: bool = true
	var all_gain_same: bool = true
	for hid in hero_ids:
		var ref_gain: int = -1
		for of in outfits:
			# Test even with Variant B flags forced on: energy must STILL never depend on outfit or bond!
			var spec: Dictionary = of.duplicate()
			spec["hero_id"] = hid
			spec["level"] = 60
			var bt: TWBattle = TWBattle.create(7406, [spec], {"boss_hp": 100000}, bal, {"outfit_stats_enabled": true, "bond_stats_enabled": true})
			if int(bt.squad[0].energy) != 40000:
				all_start_40 = false
			var g: int = TWBattleMath.energy_gain_milli(bt.squad[0], "man", 4, true, false, bal)
			if ref_gain < 0:
				ref_gain = g
			elif g != ref_gain:
				all_gain_same = false
	_chk(all_start_40, "AT-B06: all 10 heroines x 3 outfits start at energy == 40000 (40)")
	_chk(all_gain_same, "AT-B06: energy gain independent of outfit/stars/Bond for all 10 heroines")


func _test_at_b15_enrage_overflow_wave_clear(bal: Dictionary) -> void:
	# AT-B15: wave clear (-12% boss max HP, +30 energy), enrage (wave 2 ATK x1.8, cadence 6->4), overflow (-15% team HP, ward absorbs)
	var sq_kohaku: Array = [{"hero_id": "kohaku", "level": 60, "talisman_atk_bp": 3000}]
	var bt_w: TWBattle = TWBattle.create(7415, sq_kohaku, {"boss_hp": 100000, "waves": [36, 24]}, bal)
	bt_w.start()
	_chk(bt_w.tray_wards == 1, "Kohaku leader starts with 1 tray ward")
	var ev_ov1: Array = bt_w.step({"type": "OVERFLOW", "tnow_ms": 1000})
	_chk(bt_w.team_hp == bt_w.team_max_hp and bt_w.tray_wards == 0 and bool(ev_ov1[0].ward_absorbed), "AT-B15: tray ward absorbs first overflow")
	var ev_ov2: Array = bt_w.step({"type": "OVERFLOW", "tnow_ms": 2000})
	var expected_ov_dmg: int = TWBattleMath.mul_bp(bt_w.team_max_hp, 1500)
	_chk(bt_w.team_hp == bt_w.team_max_hp - expected_ov_dmg and int(ev_ov2[0].dmg) == expected_ov_dmg, "AT-B15: tray overflow deals 15% team max HP")

	var e_before: int = int(bt_w.squad[0].energy)
	var hp_before: int = bt_w.boss_hp
	var ev_wc: Array = bt_w.step({"type": "WAVE_CLEAR", "tnow_ms": 3000})
	var expected_wc_dmg: int = TWBattleMath.mul_bp(bt_w.boss_max_hp, 1200)
	_chk(bt_w.boss_hp == hp_before - expected_wc_dmg, "AT-B15: wave clear deals 12% boss max HP")
	_chk(int(bt_w.squad[0].energy) == mini(100000, e_before + 30000), "AT-B15: wave clear grants +30 energy")
	_chk(bt_w.wave_idx == 1, "AT-B15: wave advances to wave 1 (Enrage)")
	var saw_enrage: bool = false
	for ev in ev_wc:
		if String(ev.type) == TWBattleEvents.ENRAGE and int(ev.boss_atk_mult_bp) == 18000:
			saw_enrage = true
	_chk(saw_enrage, "AT-B15: ENRAGE event emitted with 18000 bp (x1.8)")


func _test_at_b04_and_at_u10_replay_determinism(bal: Dictionary) -> void:
	# Build a deterministic 90-pair action journal including ULT_AIM, ULT_CAST, OVERFLOW, WAVE_CLEAR, PAUSE/RESUME.
	var sq: Array = [
		{"hero_id": "hana",   "level": 60, "talisman_atk_bp": 3000, "ult_level": 8, "twist_id": "T2", "twist_tier": "minor"},
		{"hero_id": "nova",   "level": 60, "talisman_atk_bp": 3000, "ult_level": 8, "twist_id": "T6", "twist_tier": "major"},
		{"hero_id": "mc",     "level": 60, "talisman_atk_bp": 3000, "ult_level": 8, "twist_id": "T4", "twist_tier": "minor"},
		{"hero_id": "rin",    "level": 60, "talisman_atk_bp": 3000, "ult_level": 8, "twist_id": "T5", "twist_tier": "minor"},
		{"hero_id": "kohaku", "level": 60, "talisman_atk_bp": 3000, "ult_level": 8, "twist_id": "T3", "twist_tier": "minor"},
	]
	var stage: Dictionary = {"boss_hp": 2000000, "waves": [36, 36, 36], "weak": "man", "resist": "pin"}

	# Generate 90-pair journal by driving a live reference run
	var gen: TWBattle = TWBattle.create(7410, sq, stage, bal)
	gen.start()
	var rng: TWRng = TWRng.make(7410, 99)
	var actions: Array = []
	var t_ms: int = 0
	var aim_logged: int = 0
	var cast_logged: int = 0
	for p in range(1, 91):
		t_ms += 2200 + rng.below(1800)
		var face: int = rng.below(36)
		var act_p: Dictionary = {"type": "PAIR", "face": face, "gold": (p % 11) == 0, "tnow_ms": t_ms}
		actions.append(act_p)
		gen.step(act_p)
		if gen.over:
			break
		if p == 20:
			var p1: Dictionary = {"type": "PAUSE"}
			var p2: Dictionary = {"type": "RESUME"}
			actions.append(p1)
			actions.append(p2)
			gen.step(p1)
			gen.step(p2)
		if p == 36 or p == 72:
			var wc: Dictionary = {"type": "WAVE_CLEAR", "tnow_ms": t_ms + 500}
			actions.append(wc)
			gen.step(wc)
			if gen.over:
				break
		if p == 45:
			var ov: Dictionary = {"type": "OVERFLOW", "tnow_ms": t_ms + 300}
			actions.append(ov)
			gen.step(ov)
			if gen.over:
				break
		var ready: Array = gen.ult_ready_indices()
		if not ready.is_empty():
			var hidx: int = int(ready[0])
			if bool(gen.squad[hidx].needs_aim):
				var aim_act: Dictionary = {"type": "ULT_AIM", "hero_idx": hidx, "tnow_ms": t_ms + 100}
				actions.append(aim_act)
				gen.step(aim_act)
				aim_logged += 1
			var cast_act: Dictionary = {
				"type": "ULT_CAST", "hero_idx": hidx, "target": {"auto": true},
				"ult_id": String(gen.squad[hidx].ult_id), "variant": "base", "show_mode": "full", "tnow_ms": t_ms + 200
			}
			actions.append(cast_act)
			gen.step(cast_act)
			cast_logged += 1
			if gen.over:
				break

	var ref_hash: int = gen.state_hash()
	var saw_aim_in_journal: bool = false
	for j in gen.journal:
		if String(j.get("type", "")) == "ULT_AIM":
			saw_aim_in_journal = true
			break
	_chk(aim_logged > 0 and saw_aim_in_journal, "T10: ULT_AIM recorded in battle journal (count=%d)" % aim_logged)
	_chk(cast_logged >= 5, "90-pair replay fired >= 5 ults (got %d)" % cast_logged)

	# AT-B04: replay 3 times -> identical hash
	var b04_ok: bool = true
	for _r in 3:
		var bt: TWBattle = TWBattle.create(7410, sq, stage, bal)
		bt.replay(actions)
		if bt.state_hash() != ref_hash:
			b04_ok = false
	_chk(b04_ok, "AT-B04: 3 independent replays produce identical state_hash (0x%08X)" % ref_hash)

	# Snapshot/restore mid-battle parity
	var bt_snap: TWBattle = TWBattle.create(7410, sq, stage, bal)
	bt_snap.start()
	var mid_idx: int = actions.size() / 2
	for i in mid_idx:
		bt_snap.step(actions[i])
	var snap: Dictionary = bt_snap.snapshot()
	var bt_rest: TWBattle = TWBattle.create(7410, sq, stage, bal)
	bt_rest.restore(snap)
	for i in range(mid_idx, actions.size()):
		bt_rest.step(actions[i])
	_chk(bt_rest.state_hash() == ref_hash, "AT-B04: snapshot/restore mid-battle matches full replay hash")

	# AT-U10: replay with full / assist / off / skip -> bit-for-bit identical core state_hash
	var hashes: Dictionary = {}
	var u10_ok: bool = true
	for mode in ["full", "assist", "off", "skip"]:
		var bt_m: TWBattle = TWBattle.create(7410, sq, stage, bal)
		bt_m.replay(actions, mode)
		var hm: int = bt_m.state_hash()
		hashes[mode] = hm
		if hm != ref_hash:
			u10_ok = false
	print("  AT-B04/AT-U10 golden_hash=0x%08X pairs=%d ults=%d aims=%d modes=%s" % [
		ref_hash, gen.pairs_done, gen.ults_used, aim_logged, str(hashes)
	])
	_chk(u10_ok, "AT-U10: replay hash identical across full / assist / off / skip modes")
