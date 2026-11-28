extends Control

# Runner for P78 battle progression selftest (AT-B03, AT-B11, W15 catch-up, Variant A/B flags).
# Run via godot_lock.ps1:
#   & $env:GODOT_BIN --headless --audio-driver Dummy --path game res://tests/battle/progress_selftest.tscn

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
	print("BATTLE_PROGRESS_SELFTEST %d/%d %s" % [_ok, _total, tag])
	get_tree().quit(0 if _ok == _total else 1)


func _run_all() -> void:
	TWBattleData.clear_cache()
	var bal: Dictionary = TWBattleData.balance()
	var pd: Dictionary = TWBattleData.progress()
	var roles: Dictionary = TWBattleData.roles()
	var heroes: Dictionary = TWBattleData.heroes()

	_chk(not bal.is_empty(), "balance.json loaded")
	_chk(not pd.is_empty(), "progress.json loaded")
	_chk(not roles.is_empty(), "roles.json loaded")
	_chk(not heroes.is_empty(), "heroes_battle.json loaded")

	# 1. Default Variant A flags & no hero shards
	var flags: Dictionary = bal.get("flags", {})
	_chk(not bool(flags.get("outfit_stats_enabled", true)), "default outfit_stats_enabled is false")
	_chk(not bool(flags.get("bond_stats_enabled", true)), "default bond_stats_enabled is false")
	_chk(not bool(flags.get("paid_accelerators_enabled", true)), "default paid_accelerators_enabled is false")
	_chk(not bool(pd.get("hero_shards_enabled", true)), "hero_shards_enabled is false (no heroine shards)")

	# 2. Integer XP table exact match (BU 2.2 & T10)
	_chk(TWBattleProgress.cumulative_xp(1, bal) == 0, "XP Lv1 == 0")
	_chk(TWBattleProgress.cumulative_xp(20, bal) == 12086, "XP Lv20 == 12086")
	_chk(TWBattleProgress.cumulative_xp(40, bal) == 70595, "XP Lv40 == 70595")
	_chk(TWBattleProgress.cumulative_xp(60, bal) == 196610, "XP Lv60 == 196610")
	_chk(TWBattleProgress.cumulative_xp(70, bal) == 289922, "XP Lv70 == 289922")
	_chk(TWBattleProgress.cumulative_xp(80, bal) == 405733, "XP Lv80 == 405733")
	_chk(TWBattleProgress.cumulative_xp(90, bal) == 545611, "XP Lv90 == 545611")
	_chk(TWBattleProgress.level_for_xp(196610, 60, bal) == 60, "level_for_xp(196610) == 60")
	_chk(TWBattleProgress.level_for_xp(196609, 60, bal) == 59, "level_for_xp(196609) == 59")
	_chk(TWBattleProgress.level_for_xp(545611, 90, bal) == 90, "level_for_xp(545611) == 90")
	_chk(TWBattleProgress.level_up_coins(196610, pd) == 19661, "level_up_coins = xp / 10")

	# 3. Ascensions A0..A4
	_chk(TWBattleProgress.ascension_cap(0, pd) == 20, "A0 cap == 20")
	_chk(TWBattleProgress.ascension_cap(1, pd) == 30, "A1 cap == 30")
	_chk(TWBattleProgress.ascension_cap(2, pd) == 40, "A2 cap == 40")
	_chk(TWBattleProgress.ascension_cap(3, pd) == 50, "A3 cap == 50")
	_chk(TWBattleProgress.ascension_cap(4, pd) == 60, "A4 cap == 60")
	_chk(TWBattleProgress.total_seals_for_ascension(4, pd) == 44, "A0->A4 total seals == 44")
	var hs: Dictionary = {"level": 19, "ascension": 0, "skills": {"ult": 1, "passive": 1, "leader": 1}}
	var wallet: Dictionary = {"seals": 44, "coins": 50000, "scrolls_T1": 26, "scrolls_T2": 72, "scrolls_T3": 29}
	_chk(not bool(TWBattleProgress.ascend_hero(hs, wallet, 4, pd).ok), "ascend blocked below cap")
	hs["level"] = 20
	var asc_r: Dictionary = TWBattleProgress.ascend_hero(hs, wallet, 4, pd)
	_chk(bool(asc_r.ok) and int(hs.ascension) == 1 and int(wallet.seals) == 40, "A0->A1 succeeds and spends 4 seals")

	# 4. Skills (BU 2.3)
	var sk_tot: Dictionary = TWBattleProgress.total_skill_costs(pd)
	_chk(int(sk_tot.T1) == 26 and int(sk_tot.T2) == 72 and int(sk_tot.T3) == 29, "skill scroll totals T1=26 T2=72 T3=29")
	_chk(int(sk_tot.coins) == 2540, "skill coins total == 127*20 == 2540")
	_chk(TWBattleProgress.max_skill_level("ult", 29, pd) == 4, "ult cap at Lv29 == floor(29/6) == 4")
	_chk(TWBattleProgress.max_skill_level("leader", 29, pd) == 1, "leader locked below Lv30")
	_chk(TWBattleProgress.max_skill_level("leader", 30, pd) == 5, "leader unlocked at Lv30")
	hs["level"] = 60
	var up_r: Dictionary = TWBattleProgress.upgrade_skill(hs, "ult", wallet, pd)
	_chk(bool(up_r.ok) and int(hs.skills.ult) == 2 and int(wallet.scrolls_T1) == 23, "ult 1->2 spends 3 T1 scrolls")

	# 5. Talismans & sets (BU 2.4)
	_chk(TWBattleProgress.talisman_total_powder(12, pd) == 6500, "common talisman powder Lv12 == 6500")
	_chk(TWBattleProgress.talisman_total_powder(16, pd) == 14960, "rare talisman powder Lv16 == 14960")
	_chk(TWBattleProgress.talisman_total_powder(20, pd) == 28700, "epic talisman powder Lv20 == 28700")
	var eq_tals: Array = [
		{"slot": "comb", "rarity": "epic", "level": 20, "set": "crimson_thread", "substats": {"atk_bp": 400}},
		{"slot": "pendant", "rarity": "epic", "level": 20, "set": "crimson_thread", "substats": {"atk_bp": 300}},
		{"slot": "ribbon", "rarity": "epic", "level": 20, "set": "crimson_thread", "substats": {}},
		{"slot": "charm", "rarity": "epic", "level": 20, "set": "crimson_thread", "substats": {}},
	]
	var sb: Dictionary = TWBattleProgress.active_set_bonuses(eq_tals, pd)
	_chk(int(sb.bonuses.get("atk_bp", 0)) == 800 and int(sb.bonuses.get("fever_extra_pairs", 0)) == 2, "4pc crimson_thread bonuses")
	_chk(TWBattleProgress.aggregate_talisman_atk_bp(eq_tals, pd, bal) == 3500, "aggregate talisman ATK == 2000+400+300+800=3500 bp")

	# 6. AT-B03: 50 generated heroines across ALL 4 (outfit_stats_enabled, bond_stats_enabled) flag combinations
	_test_at_b03(bal)

	# 7. AT-B11: 100,000 Workshop pity runs
	_test_at_b11(pd)

	# 8. W15 Catch-up & D30 Ch4 >= 60% beta metric
	_test_w15_catchup(bal)


func _test_at_b03(bal: Dictionary) -> void:
	var rng: TWRng = TWRng.make(7803, 1)
	var hero_ids: Array = ["hana", "nova", "mc", "rin", "kohaku", "yue", "tsubame", "miel", "shirin", "zlata"]
	var tiers: Array = ["BASE", "VOW", "S", "SSR", "SSRP"]
	var obase: Dictionary = {"BASE": 0, "VOW": 0, "S": 400, "SSR": 800, "SSRP": 1000}
	var ostep: Dictionary = {"BASE": 0, "VOW": 0, "S": 100, "SSR": 200, "SSRP": 250}
	var combos: Array = [
		{"outfit_stats_enabled": false, "bond_stats_enabled": false},
		{"outfit_stats_enabled": true,  "bond_stats_enabled": false},
		{"outfit_stats_enabled": false, "bond_stats_enabled": true},
		{"outfit_stats_enabled": true,  "bond_stats_enabled": true},
	]
	var all_exact: bool = true
	var variant_a_zero: bool = true
	var variant_b_positive: bool = false
	var max_rel_err_milli: int = 0

	for i in 50:
		var hid: String = hero_ids[i % hero_ids.size()]
		var lv: int = 1 + rng.below(60)
		var tal_bp: int = rng.below(4301)
		var tier: String = tiers[rng.below(tiers.size())]
		var stars: int = rng.below(6)
		var album: int = rng.below(30)
		var bond: int = rng.below(11)
		var spec: Dictionary = {
			"level": lv,
			"talisman_atk_bp": tal_bp,
			"outfit_tier": tier,
			"outfit_stars": stars,
			"album_count": album,
			"bond_level": bond,
		}
		var st_def: Dictionary = TWBattleProgress.compute_hero_stats(hid, spec, bal)
		var st_naked: Dictionary = TWBattleProgress.compute_hero_stats(hid, {"level": lv, "talisman_atk_bp": tal_bp}, bal)
		if int(st_def.atk) != int(st_naked.atk) or int(st_def.hp) != int(st_naked.hp) or int(st_def.mon_atk_bp) != 0 or int(st_def.bond_bp) != 0:
			variant_a_zero = false

		for fl in combos:
			var got: Dictionary = TWBattleProgress.compute_hero_stats(hid, spec, bal, fl)
			var rdef: Dictionary = bal["roles"][bal["heroes"][hid]["role"]]
			var lv_bp: int = 10000 + 1000 * (lv - 1)
			var base_atk: int = TWBattleProgress.mul_bp(int(rdef["atk1"]), lv_bp)
			var base_hp: int = TWBattleProgress.mul_bp(int(rdef["hp1"]), lv_bp)
			var tal_hp_bp: int = TWBattleProgress.mul_bp(tal_bp, 9000)
			var atk_t: int = TWBattleProgress.mul_bp(base_atk, 10000 + tal_bp)
			var hp_t: int = TWBattleProgress.mul_bp(base_hp, 10000 + tal_hp_bp)
			var cap_bp: int = 2800 if bool(fl.outfit_stats_enabled) else 0
			var o_atk: int = (int(obase[tier]) + int(ostep[tier]) * stars) if bool(fl.outfit_stats_enabled) else 0
			var alb: int = mini(600, 25 * album) if bool(fl.outfit_stats_enabled) else 0
			var o_hp: int = TWBattleProgress.mul_bp(o_atk, 6000)
			var cap_hp: int = TWBattleProgress.mul_bp(cap_bp, 6000)
			var mon_a: int = mini(cap_bp, o_atk + alb)
			var mon_h: int = mini(cap_hp, o_hp + alb)
			var b_bp: int = (50 * bond) if bool(fl.bond_stats_enabled) else 0
			var ref_atk: int = TWBattleProgress.mul_bp(atk_t, 10000 + mon_a + b_bp)
			var ref_hp: int = TWBattleProgress.mul_bp(hp_t, 10000 + mon_h + b_bp)
			if int(got.atk) != ref_atk or int(got.hp) != ref_hp:
				all_exact = false
			if bool(fl.outfit_stats_enabled) and bool(fl.bond_stats_enabled) and int(got.atk) > int(st_def.atk):
				variant_b_positive = true
			if ref_atk > 0:
				var diff: int = absi(int(got.atk) - ref_atk)
				max_rel_err_milli = maxi(max_rel_err_milli, (diff * 1000) / ref_atk)

	_chk(all_exact, "AT-B03: 50 heroines x 4 flag combos exact integer formula match (max_err=%d)" % max_rel_err_milli)
	_chk(variant_a_zero, "AT-B03: default flags (false/false) give 0 outfit & 0 bond stats")
	_chk(variant_b_positive, "AT-B03: enabled flags (true/true) apply outfit/album/bond bonuses up to CAP")


func _test_at_b11(pd: Dictionary) -> void:
	_chk(TWBattleProgress.workshop_epic_rate_bp(13, pd) == 400, "AT-B11: attempt 14 base epic rate == 400 bp")
	_chk(TWBattleProgress.workshop_epic_rate_bp(14, pd) == 600, "AT-B11: attempt 15 soft pity == 600 bp")
	_chk(TWBattleProgress.workshop_epic_rate_bp(22, pd) == 2200, "AT-B11: attempt 23 soft pity == 2200 bp")
	_chk(TWBattleProgress.workshop_epic_rate_bp(23, pd) == 10000, "AT-B11: attempt 24 hard pity == 10000 bp")

	var rng: TWRng = TWRng.make(7811, 1)
	var pity: int = 0
	var max_streak: int = 0
	var base_runs: int = 0
	var base_epics: int = 0
	var total_epics: int = 0
	var reset_ok: bool = true
	var focus_hits: int = 0
	var runs: int = 100000

	for _i in runs:
		var r: Dictionary = TWBattleProgress.roll_workshop(pity, rng, "east_wind", pd)
		var pb: int = int(r.pity_before)
		if pb < 14:
			base_runs += 1
			if String(r.rarity) == "epic":
				base_epics += 1
		if String(r.set) == "east_wind":
			focus_hits += 1
		if String(r.rarity) == "epic":
			total_epics += 1
			var streak: int = pb + 1
			if streak > max_streak:
				max_streak = streak
			if int(r.pity_after) != 0:
				reset_ok = false
		pity = int(r.pity_after)

	var base_rate_bp: int = (base_epics * 10000) / maxi(1, base_runs)
	var focus_share_bp: int = (focus_hits * 10000) / runs
	var avg_runs_x10: int = (runs * 10) / maxi(1, total_epics)
	print("  AT-B11 stats: runs=%d epics=%d max_streak=%d base_rate_bp=%d avg_runs=%.1f focus_bp=%d" % [
		runs, total_epics, max_streak, base_rate_bp, float(avg_runs_x10) / 10.0, focus_share_bp
	])
	_chk(max_streak <= 24, "AT-B11: hard pity epic <= 24 runs (max_streak=%d)" % max_streak)
	_chk(base_rate_bp >= 350 and base_rate_bp <= 450, "AT-B11: base epic rate 400 +-50 bp (got %d bp)" % base_rate_bp)
	_chk(reset_ok, "AT-B11: pity resets to 0 on every epic drop")
	_chk(focus_share_bp >= 3800 and focus_share_bp <= 4200, "AT-B11: weekly focus set weight x2 (~4000 bp, got %d)" % focus_share_bp)


func _test_w15_catchup(bal: Dictionary) -> void:
	_chk(TWBattleProgress.catchup_xp_mult_bp(40, 50, bal) == 20000, "W15: x2 XP at lag == 10")
	_chk(TWBattleProgress.catchup_xp_mult_bp(41, 50, bal) == 10000, "W15: x1 XP at lag == 9")
	_chk(TWBattleProgress.catchup_powder_mult_bp(20, 30, bal) == 20000, "W15: x2 powder at lag == 10")
	_chk(TWBattleProgress.catchup_powder_mult_bp(21, 30, bal) == 10000, "W15: x1 powder at lag == 9")

	var h_lag: Dictionary = {"level": 20, "xp": TWBattleProgress.cumulative_xp(20, bal)}
	var r_xp: Dictionary = TWBattleProgress.apply_xp_with_catchup(h_lag, 5000, 35, 60, bal)
	_chk(bool(r_xp.catchup_active) and int(r_xp.effective_xp) == 10000, "W15: apply_xp_with_catchup doubles XP when lagging")

	var r_pw: Dictionary = TWBattleProgress.apply_powder_with_catchup(1800, 20, 35, bal)
	_chk(bool(r_pw.catchup_active) and int(r_pw.effective_powder) == 3600, "W15: apply_powder_with_catchup doubles powder")

	_chk(TWBattleProgress.sync_new_hero_level([40, 38, 36], 60, bal) == 38, "W15: new hero syncs to squad average (38)")

	var g_ok: Dictionary = TWBattleProgress.claim_pre_cap_raise_gift(7, false, bal)
	var g_dup: Dictionary = TWBattleProgress.claim_pre_cap_raise_gift(5, true, bal)
	var g_early: Dictionary = TWBattleProgress.claim_pre_cap_raise_gift(8, false, bal)
	_chk(bool(g_ok.ok) and int(g_ok.xp) == 60000, "W15: pre-cap-raise gift grants 60000 XP within 7d")
	_chk(not bool(g_dup.ok), "W15: pre-cap-raise gift blocked if already claimed")
	_chk(not bool(g_early.ok), "W15: pre-cap-raise gift blocked outside 7d window")

	var accel: Dictionary = TWBattleProgress.buy_paid_accelerator("xp_pack", bal)
	_chk(not bool(accel.ok), "W15/R.1: paid accelerators disabled in Variant A")

	# Beta P1 metric check: F2P-mid cohort reaching Chapter 4 (Lv31 enter / Lv38 clear) by D30 >= 60%
	var rng: TWRng = TWRng.make(7815, 1)
	var cohort_n: int = 200
	var reached_ch4: int = 0
	var base_mid: int = int(bal["sim"]["daily_xp_income"]["mid"])
	for _p in cohort_n:
		# Triangular-like integer sample around mid F2P with 3.5..6.0 days/wk attendance (5000..12000 eff XP/day)
		var u1: int = rng.below(3501)
		var u2: int = rng.below(3501)
		var daily_xp: int = 5000 + u1 + u2
		if daily_xp > base_mid:
			daily_xp = base_mid
		var squad: Array = [
			{"level": 1, "xp": 0},
			{"level": 1, "xp": 0},
			{"level": 1, "xp": 0},
		]
		for _d in 30:
			var max_lv: int = 1
			for h in squad:
				max_lv = maxi(max_lv, int(h.level))
			if squad.size() < 4 and max_lv >= 24:
				var lvs: Array = []
				for h in squad:
					lvs.append(int(h.level))
				var slv: int = TWBattleProgress.sync_new_hero_level(lvs, 60, bal)
				squad.append({"level": slv, "xp": TWBattleProgress.cumulative_xp(slv, bal)})
			# Feed lagging heroines first, else advance lead
			var rem: int = daily_xp
			while rem > 0:
				var step_xp: int = mini(1000, rem)
				rem -= step_xp
				var cur_max: int = 1
				for h in squad:
					cur_max = maxi(cur_max, int(h.level))
				var pick: int = -1
				for idx in squad.size():
					if int(squad[idx].level) < 38 and (cur_max - int(squad[idx].level)) >= 10:
						if pick < 0 or int(squad[idx].level) < int(squad[pick].level):
							pick = idx
				if pick < 0:
					for idx in squad.size():
						if int(squad[idx].level) < 38:
							if pick < 0 or int(squad[idx].level) > int(squad[pick].level):
								pick = idx
				if pick < 0:
					break
				TWBattleProgress.apply_xp_with_catchup(squad[pick], step_xp, cur_max, 60, bal)
		var min_lv: int = 999
		for h in squad:
			min_lv = mini(min_lv, int(h.level))
		if squad.size() >= 4 and min_lv >= 31:
			reached_ch4 += 1
	var share_bp: int = (reached_ch4 * 10000) / cohort_n
	print("  W15 F2P-mid D30 Ch4 cohort: %d/%d (%d bp, target >= 6000 bp)" % [reached_ch4, cohort_n, share_bp])
	_chk(share_bp >= 6000, "W15 beta P1 metric: F2P-mid Ch4 by D30 >= 6000 bp (got %d)" % share_bp)
