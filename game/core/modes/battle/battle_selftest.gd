class_name TWBattleSelftest
extends RefCounted

# TWBattleSelftest (P75 / BATTLE_ULT_SPEC §3.6, §12.1, Appendix R T24):
# Pure core selftest for Layer B bot & balance verification (AT-B07, AT-B08, AT-B09, AT-B16).
# Reads the EXACT same `balance.json` as `design/specs/sim/battle_sim.py`.
# Gates (`win_p0_mid_normal_bp`, `ttk_p0_mid_normal_pairs`, `ult_share_bp`) are checked as
# hypotheses while `gates.calibrated == false` (Appendix R T24).
# Zero Node / Control / G. / BATTLE_INT_ONLY violations.

const BP: int = 10000


static func run(runs_per_case: int = 400) -> Dictionary:
	var st: Dictionary = {"ok": 0, "total": 0, "fails": []}
	var chk := func(cond: bool, what: String) -> void:
		st["total"] = int(st["total"]) + 1
		if cond:
			st["ok"] = int(st["ok"]) + 1
		else:
			(st["fails"] as Array).append(what)
			print("  FAIL ", what)

	TWBattleData.clear_cache()
	var bal: Dictionary = TWBattleData.balance()
	chk.call(not bal.is_empty(), "balance.json loaded from TWBattleData.BALANCE_PATH")

	# 1. Single-file contract with battle_sim.py & Appendix R flags
	var flags: Dictionary = bal.get("flags", {})
	var gates: Dictionary = bal.get("gates", {})
	chk.call(String(flags.get("variant", "")) == "A", "balance.json variant == A")
	chk.call(not bool(flags.get("outfit_stats_enabled", true)), "balance.json outfit_stats_enabled == false")
	chk.call(not bool(flags.get("bond_stats_enabled", true)), "balance.json bond_stats_enabled == false")
	chk.call(not bool(flags.get("publish_sim_numbers_in_rules", true)), "balance.json publish_sim_numbers_in_rules == false (T24)")
	chk.call(not bool(gates.get("calibrated", true)), "balance.json gates.calibrated == false (gates activate post-beta, T24)")
	chk.call(int(bal.get("shield_and_boss", {}).get("k_normal_bp", 0)) == 1120000, "balance.json k_normal_bp == 1120000")

	# Check byte-for-byte parity with repo canonical data/battle/balance.json when running from repo tree
	var mirror_bytes: PackedByteArray = TWBattleData.raw_bytes(TWBattleData.BALANCE_PATH)
	var repo_bal_path: String = "res://../data/battle/balance.json"
	if FileAccess.file_exists(repo_bal_path):
		var canon_bytes: PackedByteArray = TWBattleData.raw_bytes(repo_bal_path)
		chk.call(mirror_bytes == canon_bytes and mirror_bytes.size() > 0,
			"single-source contract: res://core/modes/battle/data/balance.json == data/battle/balance.json (%d bytes)" % mirror_bytes.size())

	var norm_stage: Dictionary = TWBattleBot.calibrated_normal_stage(bal, "normal")

	# 2. AT-B09: Sim parity on real TWBattle integer core (P0 F2P-max mid normal + ult share + Variant A parity)
	var sq_p0: Array = TWBattleBot.build_profile_squad("P0 F2P-max", [], bal)
	var res_p0: Dictionary = TWBattleBot.run_batch(bal, runs_per_case, sq_p0, norm_stage, "mid", 7509)
	var win_lo: int = int(gates.get("win_p0_mid_normal_bp", [9000, 9700])[0])
	var win_hi: int = int(gates.get("win_p0_mid_normal_bp", [9000, 9700])[1])
	var ttk_lo: int = int(gates.get("ttk_p0_mid_normal_pairs", [26, 32])[0]) * 100
	var ttk_hi: int = int(gates.get("ttk_p0_mid_normal_pairs", [26, 32])[1]) * 100
	print("  AT-B09 P0(mid,normal,n=%d): win_bp=%d [%d..%d] ttk_x100=%d [%d..%d] 3*_bp=%d ults_x100=%d" % [
		runs_per_case, int(res_p0.win_bp), win_lo, win_hi, int(res_p0.avg_pairs_x100), ttk_lo, ttk_hi,
		int(res_p0.star3_bp), int(res_p0.avg_ults_x100)
	])
	chk.call(int(res_p0.win_bp) >= win_lo and int(res_p0.win_bp) <= win_hi,
		"AT-B09: win(P0, mid, normal) in [%d, %d] bp (got %d)" % [win_lo, win_hi, int(res_p0.win_bp)])
	chk.call(int(res_p0.avg_pairs_x100) >= ttk_lo and int(res_p0.avg_pairs_x100) <= ttk_hi,
		"AT-B09: TTK(P0, mid, normal) in [%d, %d] x100 pairs (got %d)" % [ttk_lo, ttk_hi, int(res_p0.avg_pairs_x100)])

	# Ult share over fixed 36-pair infinite boss (matches battle_sim.py T7)
	var stage_36: Dictionary = norm_stage.duplicate(true)
	stage_36["boss_hp"] = 1000000000
	stage_36["waves"] = [36]
	stage_36["boss_atk_bp"] = 0
	var res_u36: Dictionary = TWBattleBot.run_batch(bal, maxi(100, runs_per_case / 2), sq_p0, stage_36, "mid", 7577)
	var us_lo: int = int(gates.get("ult_share_bp", [4200, 5500])[0])
	var us_hi: int = int(gates.get("ult_share_bp", [4200, 5500])[1])
	print("  AT-B09 ult_share(36p): ult_share_bp=%d [%d..%d] ults_x100=%d" % [
		int(res_u36.ult_share_bp), us_lo, us_hi, int(res_u36.avg_ults_x100)
	])
	chk.call(int(res_u36.ult_share_bp) >= us_lo and int(res_u36.ult_share_bp) <= us_hi,
		"AT-B09: ult_share(36p) in [%d, %d] bp (got %d)" % [us_lo, us_hi, int(res_u36.ult_share_bp)])

	# Variant A parity inside TWBattleBot: P0+ F2P-long == P3 whale (bit-for-bit identical outcomes on same seed!)
	var sq_p0p: Array = TWBattleBot.build_profile_squad("P0+ F2P-long", [], bal)
	var sq_p3: Array = TWBattleBot.build_profile_squad("P3 whale", [], bal)
	var res_p0p: Dictionary = TWBattleBot.run_batch(bal, maxi(100, runs_per_case / 2), sq_p0p, norm_stage, "mid", 7501)
	var res_p3: Dictionary = TWBattleBot.run_batch(bal, maxi(100, runs_per_case / 2), sq_p3, norm_stage, "mid", 7501)
	chk.call(int(res_p0p.win_bp) == int(res_p3.win_bp) and int(res_p0p.avg_pairs_x100) == int(res_p3.avg_pairs_x100),
		"AT-B09 Variant A parity: P0+ F2P-long == P3 whale (win %d vs %d, ttk %d vs %d)" % [
			int(res_p0p.win_bp), int(res_p3.win_bp), int(res_p0p.avg_pairs_x100), int(res_p3.avg_pairs_x100)
		])

	# 3. AT-B07: Same roles (ATK+BRK+SUP+HEAL+GRD), different heroines -> TTK spread <= 300 bp (3%)
	var role_squads: Array = [
		["hana",  "nova",    "mc",     "rin",  "kohaku"],
		["yue",   "nova",    "mc",     "rin",  "kohaku"],
		["zlata", "nova",    "mc",     "rin",  "kohaku"],
		["hana",  "tsubame", "mc",     "rin",  "kohaku"],
		["hana",  "nova",    "shirin", "rin",  "kohaku"],
		["hana",  "nova",    "mc",     "miel", "kohaku"],
	]
	var role_ttks: Array = []
	var role_min: int = 2147483647
	var role_max: int = 0
	var role_sum: int = 0
	for sq_names in role_squads:
		var specs: Array = TWBattleBot.build_profile_squad("P0 F2P-max", sq_names, bal)
		var r_role: Dictionary = TWBattleBot.run_batch(bal, maxi(600, runs_per_case), specs, norm_stage, "mid", 7507)
		var t_val: int = int(r_role.avg_pairs_x100)
		role_ttks.append(t_val)
		role_min = mini(role_min, t_val)
		role_max = maxi(role_max, t_val)
		role_sum += t_val
	var role_mean: int = maxi(1, role_sum / role_squads.size())
	var role_spread_bp: int = ((role_max - role_min) * BP) / role_mean
	var role_max_bp: int = int(gates.get("role_spread_max_bp", 300))
	print("  AT-B07 role_swap TTK_x100=%s min=%d max=%d spread_bp=%d (gate <= %d)" % [
		str(role_ttks), role_min, role_max, role_spread_bp, role_max_bp
	])
	chk.call(role_spread_bp <= role_max_bp,
		"AT-B07: same-roles different-heroines TTK spread <= %d bp (got %d bp)" % [role_max_bp, role_spread_bp])

	# 4. AT-B08: Twists T1..T8 spread <= 300 bp (3%) for both minor (S) and major (SSR/SSRP)
	var twist_ids: Array = ["T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8"]
	var twist_max_bp: int = int(gates.get("twist_spread_max_bp", 300))
	for tier in ["minor", "major"]:
		var t_vals: Array = []
		var t_min: int = 2147483647
		var t_max: int = 0
		var t_sum: int = 0
		for tid in twist_ids:
			var t_specs: Array = TWBattleBot.build_profile_squad("P0 F2P-max", [], bal, tid, tier)
			var r_tw: Dictionary = TWBattleBot.run_batch(bal, runs_per_case, t_specs, norm_stage, "mid", 7508)
			var tv: int = int(r_tw.avg_pairs_x100)
			t_vals.append(tv)
			t_min = mini(t_min, tv)
			t_max = maxi(t_max, tv)
			t_sum += tv
		var t_mean: int = maxi(1, t_sum / twist_ids.size())
		var t_spread_bp: int = ((t_max - t_min) * BP) / t_mean
		print("  AT-B08 twists(%s) TTK_x100=%s min=%d max=%d spread_bp=%d (gate <= %d)" % [
			tier, str(t_vals), t_min, t_max, t_spread_bp, twist_max_bp
		])
		chk.call(t_spread_bp <= twist_max_bp,
			"AT-B08: twists (%s) T1..T8 TTK spread <= %d bp (got %d bp)" % [tier, twist_max_bp, t_spread_bp])

	# 5. AT-B16: Autobattle on real certified TWBoard (20 boards: assist-only ults, deterministic replay, wins)
	var ab_wins: int = 0
	var ab_full_leaks: int = 0
	var ab_det_ok: bool = true
	var ab_stage: Dictionary = {
		"boss_hp": 18000,
		"ref_team_hp": 1400,
		"waves": [36],
		"enable_hero_passives": true,
		"enable_hero_riders": true,
	}
	var ab_specs: Array = TWBattleBot.build_profile_squad("P0- F2P-mid", [], bal)
	for bseed in range(1, 21):
		var bcfg: Dictionary = {"shape": "rect", "cols": 5, "rows": 6, "layers": 3, "fill": 0.72, "faces": 10, "slots": 5, "seed": 7516 + bseed}
		var bd1: TWBoard = TWBoard.from_cfg(bcfg)
		var bt1: TWBattle = TWBattle.create(7516 + bseed, ab_specs, ab_stage, bal)
		var r1: Dictionary = TWBattleBot.play_board_fight(bt1, bd1, TWRng.make(7516 + bseed, 1), true)
		if bool(r1.won):
			ab_wins += 1
		if bool(r1.saw_full_mode):
			ab_full_leaks += 1
		# Determinism check on first 5 seeds
		if bseed <= 5:
			var bd2: TWBoard = TWBoard.from_cfg(bcfg)
			var bt2: TWBattle = TWBattle.create(7516 + bseed, ab_specs, ab_stage, bal)
			var r2: Dictionary = TWBattleBot.play_board_fight(bt2, bd2, TWRng.make(7516 + bseed, 1), true)
			if int(r1.state_hash) != int(r2.state_hash):
				ab_det_ok = false
	print("  AT-B16 real-board autobattle: wins=%d/20 full_ult_leaks=%d deterministic=%s" % [ab_wins, ab_full_leaks, str(ab_det_ok)])
	chk.call(ab_wins == 20, "AT-B16: real-board autobattle wins 20/20 calibrated boards (got %d)" % ab_wins)
	chk.call(ab_full_leaks == 0, "AT-B16: autobattle never triggers full ult cutscene (assist only)")
	chk.call(ab_det_ok, "AT-B16: real-board autobattle is 100% deterministic")

	return st
