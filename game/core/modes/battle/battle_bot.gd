class_name TWBattleBot
extends RefCounted

# TWBattleBot (P75 / BATTLE_ULT_SPEC §1.8.1, §3.6, Appendix R T10 & T24):
# Pure integer battle bot reading the EXACT same `balance.json` as `design/specs/sim/battle_sim.py`.
# Provides:
#   1. `play_sim_fight(...)`   - drives real `TWBattle` using the balance.json statistical model (AT-B07..B09).
#   2. `play_board_fight(...)` - drives real `TWBattle` + real certified `TWBoard` tile-by-tile (autobattle §1.8.1, AT-B16).
#   3. `run_batch(...)`        - deterministic Monte-Carlo runner returning integer basis-point summaries.
# Zero floating-point transcendentals (no pow/exp/log/sin/cos/randf/randfn), zero Node/UI/G.

const BP: int = 10000


static func build_profile_squad(profile_key: String, hero_names: Array = [], bal: Dictionary = {},
		twist_id: String = "", twist_tier: String = "minor") -> Array:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var sim: Dictionary = b.get("sim", {})
	var names: Array = hero_names if not hero_names.is_empty() else sim.get("squad_std", ["hana", "nova", "mc", "rin", "kohaku"])
	var prof: Dictionary = sim.get("profiles", {}).get(profile_key, {})
	if prof.is_empty():
		prof = {"level": 60, "tal_bp": 3000, "skill": 8, "outfits": [], "bond": 10, "collection": 0}
	var outfits: Array = prof.get("outfits", [])
	var flags: Dictionary = b.get("flags", {})
	var use_b_tal: bool = bool(flags.get("paid_accelerators_enabled", false)) and prof.has("tal_bp_variant_b")
	var tal_bp: int = int(prof.get("tal_bp_variant_b", prof.get("tal_bp", 0))) if use_b_tal else int(prof.get("tal_bp", 0))

	var specs: Array = []
	for i in names.size():
		var hid: String = String(names[i])
		var tier: String = "BASE"
		var stars: int = 0
		if i < outfits.size() and outfits[i] is Array and outfits[i].size() >= 2:
			tier = String(outfits[i][0])
			stars = int(outfits[i][1])
		var spec: Dictionary = {
			"hero_id": hid,
			"level": int(prof.get("level", 60)),
			"talisman_atk_bp": tal_bp,
			"ult_level": int(prof.get("skill", 8)),
			"passive_level": int(prof.get("skill", 8)),
			"outfit_tier": tier,
			"outfit_stars": stars,
			"album_count": int(prof.get("collection", 0)),
			"bond_level": int(prof.get("bond", 10)),
		}
		if twist_id != "" and i == 0:
			spec["twist_id"] = twist_id
			spec["twist_tier"] = twist_tier
		specs.append(spec)
	return specs


static func calibrated_normal_stage(bal: Dictionary = {}, difficulty: String = "normal") -> Dictionary:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var sb: Dictionary = b.get("shield_and_boss", {})
	var p0_specs: Array = build_profile_squad("P0 F2P-max", [], b)
	var bt_ref: TWBattle = TWBattle.create(1, p0_specs, {"boss_hp": 100000, "enable_hero_passives": false}, b)
	var ref_hp: int = bt_ref.team_max_hp
	var tpp_x10: int = TWBattleMath.team_pair_power_x10(bt_ref.squad, b)
	var k_bp: int = int(sb.get("k_normal_bp", 1120000))
	var boss_hp: int = TWBattleMath.mul_bp(tpp_x10, k_bp) / 10
	return {
		"boss_hp": boss_hp,
		"ref_team_hp": ref_hp,
		"difficulty": difficulty,
		"waves": sb.get("waves_default", [36, 24]).duplicate(),
		"cadence": int(sb.get("boss_cadence_default", 6)),
		"shield_units": int(sb.get("shield_units_default", 16)),
		"enable_hero_passives": false,
		"enable_hero_riders": false,
	}


static func should_smart_ult(bt: TWBattle, hero_idx: int, tray_len: int, strict_smart: bool = true) -> bool:
	if hero_idx < 0 or hero_idx >= bt.squad.size():
		return false
	var ult_cost: int = int(bt.bal.get("combat", {}).get("ult_cost_milli", 100000))
	var h: Dictionary = bt.squad[hero_idx]
	if int(h.energy) < ult_cost:
		return false
	if not strict_smart:
		return true
	var role: String = String(h.role)
	if role == "HEAL":
		return (bt.team_hp * BP) < (bt.team_max_hp * 7000)
	var sb: Dictionary = bt.bal.get("shield_and_boss", {})
	var eff_cadence: int = maxi(
		int(sb.get("boss_cadence_min", 3)),
		bt.boss_cadence - int(sb.get("boss_cadence_enrage_step", 2)) * bt.wave_idx
	)
	if tray_len >= 3:
		return true
	if (bt.team_hp * BP) < (bt.team_max_hp * 6000):
		return true
	if bt.boss_clock >= eff_cadence - 1:
		return true
	# Also fire offensive/breaker/support ults when boss is broken or high HP
	if bt.broken_hits > 0 or role == "ATK" or role == "BRK" or role == "SUP":
		return true
	return false


static func play_sim_fight(bal: Dictionary, squad_specs: Array, stage_cfg: Dictionary,
		skill: String, rng: TWRng, auto_ults: bool = true) -> Dictionary:
	var sim: Dictionary = bal.get("sim", {})
	var auras: Array = bal.get("auras", ["man", "pin", "sou"])
	var combo_p: int = int(sim.get("combo_p_bp", {}).get(skill, 6800))
	var overflow_p: int = int(sim.get("overflow_p_bp", {}).get(skill, 100))
	var suit_prob_bp: int = int(sim.get("suit_prob_bp", 8100))
	var ladder_p_bp: int = int(sim.get("ladder_sim_p_bp", 600))
	var kan_p_bp: int = int(sim.get("kan_sim_p_bp", 400))
	var rate_milli: int = maxi(1000, int(sim.get("pair_rate_milli", {}).get(skill, 11000)))
	var step_ms: int = (60 * 1000 * 1000) / rate_milli

	var bt: TWBattle = TWBattle.create(rng.rand_i31(), squad_specs, stage_cfg, bal)
	bt.start()

	var total_budget: int = 0
	var bounds: Array = []
	for w in bt.waves:
		total_budget += int(w)
		bounds.append(total_budget)

	var suit_hist: Array = []
	var t_ms: int = 0
	var saw_full_mode: bool = false
	var pat_cfg: Dictionary = bal.get("patterns", {})
	var ult_cost: int = int(bal.get("combat", {}).get("ult_cost_milli", 100000))

	while bt.pairs_done < total_budget and not bt.over:
		# Wave boundary transition (mirror battle_sim.py: reset combo & advance enrage wave without bonus clear dmg
		# unless explicit_wave_clear is requested)
		if bounds.size() > 1:
			for bi in range(bounds.size() - 1):
				if bt.pairs_done == int(bounds[bi]) and bt.wave_idx == bi:
					if bool(stage_cfg.get("sim_wave_clear_bonus", false)):
						bt.step({"type": "WAVE_CLEAR", "tnow_ms": t_ms})
					else:
						bt.wave_idx = bi + 1
						bt.wave_pairs = 0
						bt.combo = 0
		if bt.over:
			break

		t_ms += step_ms
		var suit: String = "honor"
		if rng.below(BP) < suit_prob_bp:
			suit = String(auras[rng.below(auras.size())])
		suit_hist.append(suit)

		var combo_cont: bool = bt.combo > 0 and rng.below(BP) < combo_p

		# Statistical pattern roll matching battle_sim.py
		var best_pat: String = ""
		var best_bp: int = 0
		var hn: int = suit_hist.size()
		if hn >= 3 and suit != "honor" and suit_hist[hn - 1] == suit_hist[hn - 2] and suit_hist[hn - 2] == suit_hist[hn - 3]:
			var b1: int = int(pat_cfg.get("one_suit", {}).get("dmg_bonus_bp", 2000))
			if b1 > best_bp:
				best_bp = b1
				best_pat = "one_suit"
		if rng.below(BP) < ladder_p_bp:
			var b2: int = int(pat_cfg.get("ladder", {}).get("dmg_bonus_bp", 3500))
			if b2 > best_bp:
				best_bp = b2
				best_pat = "ladder"
		if rng.below(BP) < kan_p_bp:
			var b3: int = int(pat_cfg.get("kan", {}).get("dmg_bonus_bp", 2500))
			if b3 > best_bp:
				best_bp = b3
				best_pat = "kan"
		if hn >= 6 and suit != "honor":
			var all6: bool = true
			for k in range(hn - 6, hn):
				if suit_hist[k] != suit:
					all6 = false
					break
			if all6:
				var b4: int = int(pat_cfg.get("pure", {}).get("dmg_bonus_bp", 8000))
				if b4 > best_bp:
					best_bp = b4
					best_pat = "pure"

		bt.step({
			"type": "PAIR",
			"suit": suit,
			"combo_continue": combo_cont,
			"pattern_override": best_pat,
			"tnow_ms": t_ms,
		})
		if bt.over:
			break

		if auto_ults:
			for i in bt.squad.size():
				if int(bt.squad[i].energy) >= ult_cost and not bt.over:
					if bool(bt.squad[i].needs_aim):
						bt.step({"type": "ULT_AIM", "hero_idx": i, "tnow_ms": t_ms})
					var evs: Array = bt.step({
						"type": "ULT_CAST",
						"hero_idx": i,
						"target": {"auto": true},
						"ult_id": String(bt.squad[i].ult_id),
						"variant": "base",
						"show_mode": "assist",
						"tnow_ms": t_ms,
					})
					for ev in evs:
						if String(ev.get("type", "")) == TWBattleEvents.ULT_CAST and String(ev.get("mode", "")) == "full":
							saw_full_mode = true

		if not bt.over and rng.below(BP) < overflow_p:
			bt.step({"type": "OVERFLOW", "tnow_ms": t_ms})

	return {
		"won": bt.won,
		"stars": bt.stars(),
		"pairs": bt.pairs_done,
		"waves": bt.wave_idx + 1,
		"secs_x10": t_ms / 100,
		"ult_dmg": bt.ult_dmg_total,
		"pair_dmg": bt.pair_dmg_total,
		"ults": bt.ults_used,
		"hp_left_bp": (bt.team_hp * BP) / maxi(1, bt.team_max_hp),
		"boss_left": bt.boss_hp,
		"state_hash": bt.state_hash(),
		"saw_full_mode": saw_full_mode,
	}


static func play_board_fight(bt: TWBattle, board: TWBoard, rng: TWRng, smart_ult: bool = true) -> Dictionary:
	# Real-board autobattle (§1.8.1, AT-B16): plays TWBoard with solver_move/best_move and feeds real pairs to TWBattle.
	var ab: Dictionary = bt.bal.get("sim", {}).get("autobattle", {"pair_rate_milli": 7000, "combo_p_bp": 4500})
	var rate_milli: int = maxi(1000, int(ab.get("pair_rate_milli", 7000)))
	var step_ms: int = (60 * 1000 * 1000) / rate_milli
	var combo_p: int = int(ab.get("combo_p_bp", 4500))

	if bt.state == TWBattle.ST_INIT:
		bt.start()
	var t_ms: int = 0
	var saw_full_mode: bool = false
	var guard_moves: int = 0
	var max_moves: int = maxi(200, board.n * 4)

	while not bt.over and not board.cleared and not board.failed and guard_moves < max_moves:
		guard_moves += 1
		var mv: int = board.solver_move()
		if mv < 0:
			mv = board.best_move()
		if mv < 0:
			break
		var bevs: Array = board.tap(mv)
		for bev in bevs:
			var btype: String = String(bev.get("t", ""))
			if btype == TWBoardEvents.MATCH:
				t_ms += step_ms
				var f: int = int(bev.get("face", 0))
				var is_g: bool = bool(bev.get("gold", false))
				var c_cont: bool = bt.combo > 0 and rng.below(BP) < combo_p
				bt.step({
					"type": "PAIR",
					"face": f,
					"gold": is_g,
					"combo_continue": c_cont,
					"tnow_ms": t_ms,
				})
				if bt.over:
					break
				for i in bt.squad.size():
					if not bt.over and should_smart_ult(bt, i, board.tray.size(), smart_ult):
						if bool(bt.squad[i].needs_aim):
							bt.step({"type": "ULT_AIM", "hero_idx": i, "tnow_ms": t_ms})
						var uevs: Array = bt.step({
							"type": "ULT_CAST",
							"hero_idx": i,
							"target": {"auto": true},
							"ult_id": String(bt.squad[i].ult_id),
							"variant": "base",
							"show_mode": "assist",
							"tnow_ms": t_ms,
						})
						for uev in uevs:
							if String(uev.get("type", "")) == TWBattleEvents.ULT_CAST and String(uev.get("mode", "")) == "full":
								saw_full_mode = true
			elif btype == TWBoardEvents.TRAY_FULL:
				bt.step({"type": "OVERFLOW", "tnow_ms": t_ms})
				if not bt.over:
					board.failed = false
					board.return_tray(board.tray.size())
		if board.cleared and not bt.over:
			bt.step({"type": "WAVE_CLEAR", "tnow_ms": t_ms})

	return {
		"won": bt.won,
		"stars": bt.stars(),
		"pairs": bt.pairs_done,
		"ults": bt.ults_used,
		"board_cleared": board.cleared,
		"saw_full_mode": saw_full_mode,
		"state_hash": bt.state_hash(),
	}


static func run_batch(bal: Dictionary, n: int, squad_specs: Array, stage_cfg: Dictionary,
		skill: String, seed_: int, auto_ults: bool = true) -> Dictionary:
	var rng: TWRng = TWRng.make(seed_, 75)
	var wins: int = 0
	var star3: int = 0
	var win_pairs_sum: int = 0
	var all_pairs_sum: int = 0
	var ults_sum: int = 0
	var hp_win_sum: int = 0
	var ult_dmg_sum: int = 0
	var tot_dmg_sum: int = 0
	var saw_full: bool = false

	for _i in n:
		var r: Dictionary = play_sim_fight(bal, squad_specs, stage_cfg, skill, rng, auto_ults)
		all_pairs_sum += int(r.pairs)
		ults_sum += int(r.ults)
		ult_dmg_sum += int(r.ult_dmg)
		tot_dmg_sum += int(r.ult_dmg) + int(r.pair_dmg)
		if bool(r.saw_full_mode):
			saw_full = true
		if bool(r.won):
			wins += 1
			win_pairs_sum += int(r.pairs)
			hp_win_sum += int(r.hp_left_bp)
			if int(r.stars) >= 3:
				star3 += 1

	var denom_n: int = maxi(1, n)
	var denom_w: int = maxi(1, wins)
	return {
		"n": n,
		"wins": wins,
		"win_bp": (wins * BP) / denom_n,
		"star3_bp": (star3 * BP) / denom_n,
		"avg_pairs_x100": (win_pairs_sum * 100) / denom_w if wins > 0 else (all_pairs_sum * 100) / denom_n,
		"avg_ults_x100": (ults_sum * 100) / denom_n,
		"ult_share_bp": (ult_dmg_sum * BP) / maxi(1, tot_dmg_sum),
		"avg_hp_left_bp": hp_win_sum / denom_w if wins > 0 else 0,
		"saw_full_mode": saw_full,
	}
