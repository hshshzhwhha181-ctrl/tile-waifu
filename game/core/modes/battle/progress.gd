class_name TWBattleProgress
extends RefCounted

# TWBattleProgress (P78 / BATTLE_ULT_SPEC §2, Appendix R R.1 & W15):
# Pure, 100% integer (basis-point floor) progression engine for Layer B ("Бой"):
#   - No heroine shards (only level, ascension, 3 skills, 4 talisman slots + sets, workshop pity).
#   - Variant A defaults from balance.json: outfit_stats_enabled=false, bond_stats_enabled=false,
#     paid_accelerators_enabled=false (all flags testable with explicit overrides).
#   - W15 Catch-up: x2 XP & powder for heroines lagging >= 10 levels behind squad max,
#     free sync of a new heroine to squad average level, and pre-cap-raise XP gift.
#   - Zero floating-point transcendentals (no pow/exp/log/sin/cos/randf/randfn).

const BP: int = 10000


static func mul_bp(a: int, bp: int) -> int:
	# Deterministic integer multiply in basis points with floor semantics (non-negative combat math).
	var prod: int = a * bp
	if prod >= 0:
		return prod / BP
	return -(((-prod) + BP - 1) / BP)


# ------------------------------------------------------------------ XP & levels (integer table)

static func xp_step_table(bal: Dictionary = {}) -> Array:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var prog: Dictionary = b.get("progression", {})
	return prog.get("xp_step", [])


static func xp_cum_table(bal: Dictionary = {}) -> Array:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var prog: Dictionary = b.get("progression", {})
	return prog.get("xp_cum", [])


static func xp_to_next(level: int, bal: Dictionary = {}) -> int:
	var steps: Array = xp_step_table(bal)
	if level < 1 or level > steps.size():
		return 0
	return int(steps[level - 1])


static func cumulative_xp(level: int, bal: Dictionary = {}) -> int:
	var cum: Array = xp_cum_table(bal)
	if level < 1 or cum.is_empty():
		return 0
	var idx: int = mini(level - 1, cum.size() - 1)
	return int(cum[idx])


static func level_for_xp(total_xp: int, level_cap: int = 60, bal: Dictionary = {}) -> int:
	var cum: Array = xp_cum_table(bal)
	if cum.is_empty():
		return 1
	var max_lv: int = clampi(level_cap, 1, cum.size())
	var lv: int = 1
	while lv < max_lv and total_xp >= int(cum[lv]):
		lv += 1
	return lv


static func level_up_coins(xp_amount: int, pdata: Dictionary = {}) -> int:
	var pd: Dictionary = pdata if not pdata.is_empty() else TWBattleData.progress()
	var div: int = maxi(1, int(pd.get("level_coin_divisor", 10)))
	return maxi(0, xp_amount) / div


# ------------------------------------------------------------------ Ascensions (A0..A4 launch, A5..A7 m4-m12)

static func ascension_entry(stage: int, pdata: Dictionary = {}) -> Dictionary:
	var pd: Dictionary = pdata if not pdata.is_empty() else TWBattleData.progress()
	var list: Array = pd.get("ascensions", [])
	for e in list:
		if int(e.get("stage", -1)) == stage:
			return e
	return {}


static func ascension_cap(stage: int, pdata: Dictionary = {}) -> int:
	var e: Dictionary = ascension_entry(stage, pdata)
	return int(e.get("level_cap", 20))


static func total_seals_for_ascension(target_stage: int, pdata: Dictionary = {}) -> int:
	var pd: Dictionary = pdata if not pdata.is_empty() else TWBattleData.progress()
	var total: int = 0
	for e in pd.get("ascensions", []):
		var st: int = int(e.get("stage", 0))
		if st >= 1 and st <= target_stage:
			total += int(e.get("seals_cost", 0))
	return total


static func can_ascend(hero_state: Dictionary, wallet: Dictionary, max_stage: int = 4, pdata: Dictionary = {}) -> Dictionary:
	var cur_a: int = int(hero_state.get("ascension", 0))
	if cur_a >= max_stage:
		return {"ok": false, "reason": "max_ascension"}
	var cur_cap: int = ascension_cap(cur_a, pdata)
	if int(hero_state.get("level", 1)) < cur_cap:
		return {"ok": false, "reason": "level_below_cap", "need_level": cur_cap}
	var nxt: Dictionary = ascension_entry(cur_a + 1, pdata)
	if nxt.is_empty():
		return {"ok": false, "reason": "missing_stage"}
	var seals_need: int = int(nxt.get("seals_cost", 0))
	var coins_need: int = int(nxt.get("coins_cost", 0))
	if int(wallet.get("seals", 0)) < seals_need:
		return {"ok": false, "reason": "not_enough_seals", "need": seals_need}
	if int(wallet.get("coins", 0)) < coins_need:
		return {"ok": false, "reason": "not_enough_coins", "need": coins_need}
	return {"ok": true, "next_stage": cur_a + 1, "next_cap": int(nxt.get("level_cap", cur_cap)), "seals": seals_need, "coins": coins_need}


static func ascend_hero(hero_state: Dictionary, wallet: Dictionary, max_stage: int = 4, pdata: Dictionary = {}) -> Dictionary:
	var chk: Dictionary = can_ascend(hero_state, wallet, max_stage, pdata)
	if not bool(chk.get("ok", false)):
		return chk
	wallet["seals"] = int(wallet.get("seals", 0)) - int(chk.seals)
	wallet["coins"] = int(wallet.get("coins", 0)) - int(chk.coins)
	hero_state["ascension"] = int(chk.next_stage)
	return chk


# ------------------------------------------------------------------ Skills (ult 1..10, passive 1..10, leader 1..5)

static func max_skill_level(skill_kind: String, hero_level: int, pdata: Dictionary = {}) -> int:
	var pd: Dictionary = pdata if not pdata.is_empty() else TWBattleData.progress()
	var sk: Dictionary = pd.get("skills", {}).get(skill_kind, {})
	if sk.is_empty():
		return 1
	var hard_max: int = int(sk.get("max_level", 1))
	if skill_kind == "leader":
		var unlock_lv: int = int(sk.get("unlock_hero_level", 30))
		return hard_max if hero_level >= unlock_lv else 1
	var div: int = maxi(1, int(sk.get("hero_level_divisor", 6)))
	return clampi(maxi(1, hero_level / div), 1, hard_max)


static func skill_upgrade_cost(skill_kind: String, to_level: int, pdata: Dictionary = {}) -> Dictionary:
	var pd: Dictionary = pdata if not pdata.is_empty() else TWBattleData.progress()
	var skills_cfg: Dictionary = pd.get("skills", {})
	var sk: Dictionary = skills_cfg.get(skill_kind, {})
	var coin_per: int = int(skills_cfg.get("coin_per_scroll", 20))
	for row in sk.get("costs", []):
		if int(row.get("to_level", 0)) == to_level:
			var sc: int = int(row.get("scrolls", 0))
			return {"ok": true, "tier": String(row.get("tier", "T1")), "scrolls": sc, "coins": sc * coin_per}
	return {"ok": false, "reason": "invalid_level"}


static func total_skill_costs(pdata: Dictionary = {}) -> Dictionary:
	var pd: Dictionary = pdata if not pdata.is_empty() else TWBattleData.progress()
	var skills_cfg: Dictionary = pd.get("skills", {})
	var coin_per: int = int(skills_cfg.get("coin_per_scroll", 20))
	var out: Dictionary = {"T1": 0, "T2": 0, "T3": 0, "coins": 0}
	for kind in ["ult", "passive", "leader"]:
		var sk: Dictionary = skills_cfg.get(kind, {})
		for row in sk.get("costs", []):
			var t: String = String(row.get("tier", "T1"))
			var sc: int = int(row.get("scrolls", 0))
			out[t] = int(out.get(t, 0)) + sc
			out["coins"] = int(out.coins) + sc * coin_per
	return out


static func upgrade_skill(hero_state: Dictionary, skill_kind: String, wallet: Dictionary, pdata: Dictionary = {}) -> Dictionary:
	var hero_lv: int = int(hero_state.get("level", 1))
	var skills_map: Dictionary = hero_state.get("skills", {"ult": 1, "passive": 1, "leader": 1})
	var cur_lv: int = int(skills_map.get(skill_kind, 1))
	var cap_lv: int = max_skill_level(skill_kind, hero_lv, pdata)
	if cur_lv >= cap_lv:
		return {"ok": false, "reason": "skill_cap_reached", "cap": cap_lv}
	var cost: Dictionary = skill_upgrade_cost(skill_kind, cur_lv + 1, pdata)
	if not bool(cost.get("ok", false)):
		return cost
	var tier_key: String = "scrolls_" + String(cost.tier)
	if int(wallet.get(tier_key, 0)) < int(cost.scrolls):
		return {"ok": false, "reason": "not_enough_scrolls", "tier": cost.tier, "need": cost.scrolls}
	if int(wallet.get("coins", 0)) < int(cost.coins):
		return {"ok": false, "reason": "not_enough_coins", "need": cost.coins}
	wallet[tier_key] = int(wallet.get(tier_key, 0)) - int(cost.scrolls)
	wallet["coins"] = int(wallet.get("coins", 0)) - int(cost.coins)
	skills_map[skill_kind] = cur_lv + 1
	hero_state["skills"] = skills_map
	return {"ok": true, "skill": skill_kind, "level": cur_lv + 1, "cost": cost}


# ------------------------------------------------------------------ Talismans, sets & Workshop pity (AT-B11)

static func talisman_powder_cost_step(next_level: int, pdata: Dictionary = {}) -> int:
	if next_level < 1:
		return 0
	var pd: Dictionary = pdata if not pdata.is_empty() else TWBattleData.progress()
	var factor: int = int(pd.get("talismans", {}).get("powder_cost_factor", 10))
	return factor * next_level * next_level


static func talisman_total_powder(max_level: int, pdata: Dictionary = {}) -> int:
	var tot: int = 0
	for l in range(1, max_level + 1):
		tot += talisman_powder_cost_step(l, pdata)
	return tot


static func talisman_main_stat_bp(rarity: String, level: int, pdata: Dictionary = {}) -> int:
	var pd: Dictionary = pdata if not pdata.is_empty() else TWBattleData.progress()
	var rcfg: Dictionary = pd.get("talismans", {}).get("rarities", {}).get(rarity, {})
	if rcfg.is_empty():
		return 0
	var max_lv: int = maxi(1, int(rcfg.get("max_level", 12)))
	var max_bp: int = int(rcfg.get("main_stat_max_bp", 1200))
	var lv: int = clampi(level, 0, max_lv)
	return (max_bp * lv) / max_lv


static func active_set_bonuses(equipped_talismans: Array, pdata: Dictionary = {}) -> Dictionary:
	var pd: Dictionary = pdata if not pdata.is_empty() else TWBattleData.progress()
	var sets_cfg: Dictionary = pd.get("talismans", {}).get("sets", {})
	var counts: Dictionary = {}
	for t in equipped_talismans:
		if t is Dictionary:
			var sid: String = String(t.get("set", ""))
			if sid != "":
				counts[sid] = int(counts.get(sid, 0)) + 1
	var merged: Dictionary = {}
	var active_tags: Array = []
	for sid in counts:
		var n: int = int(counts[sid])
		var scfg: Dictionary = sets_cfg.get(sid, {})
		if n >= 2 and scfg.has("bonus_2pc"):
			active_tags.append(sid + ":2")
			for k in scfg.bonus_2pc:
				merged[k] = int(merged.get(k, 0)) + int(scfg.bonus_2pc[k])
		if n >= 4 and scfg.has("bonus_4pc"):
			active_tags.append(sid + ":4")
			for k in scfg.bonus_4pc:
				merged[k] = int(merged.get(k, 0)) + int(scfg.bonus_4pc[k])
	return {"bonuses": merged, "active": active_tags, "counts": counts}


static func aggregate_talisman_atk_bp(equipped_talismans: Array, pdata: Dictionary = {}, bal: Dictionary = {}) -> int:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var cap_bp: int = int(b.get("progression", {}).get("talisman_max_bp", 4300))
	var atk_bp: int = 0
	for t in equipped_talismans:
		if not (t is Dictionary):
			continue
		var slot_id: String = String(t.get("slot", ""))
		var rarity: String = String(t.get("rarity", "common"))
		var lv: int = int(t.get("level", 0))
		if slot_id == "comb":
			atk_bp += talisman_main_stat_bp(rarity, lv, pdata)
		var subs: Dictionary = t.get("substats", {})
		if subs.has("atk_bp"):
			atk_bp += int(subs["atk_bp"])
	var sb: Dictionary = active_set_bonuses(equipped_talismans, pdata)
	atk_bp += int(sb.bonuses.get("atk_bp", 0))
	return mini(cap_bp, maxi(0, atk_bp))


static func workshop_epic_rate_bp(pity_counter: int, pdata: Dictionary = {}) -> int:
	var pd: Dictionary = pdata if not pdata.is_empty() else TWBattleData.progress()
	var pity_cfg: Dictionary = pd.get("talismans", {}).get("workshop_pity", {})
	var base_epic: int = int(pity_cfg.get("base_rates_bp", {}).get("epic", 400))
	var soft_start: int = int(pity_cfg.get("soft_pity_start_run", 15))
	var soft_step: int = int(pity_cfg.get("soft_pity_step_bp", 200))
	var hard_run: int = int(pity_cfg.get("hard_pity_run", 24))
	var attempt: int = maxi(0, pity_counter) + 1
	if attempt >= hard_run:
		return BP
	if attempt >= soft_start:
		return mini(BP, base_epic + soft_step * (attempt - soft_start + 1))
	return base_epic


static func roll_workshop(pity_counter: int, rng: TWRng, focus_set: String = "", pdata: Dictionary = {}) -> Dictionary:
	var pd: Dictionary = pdata if not pdata.is_empty() else TWBattleData.progress()
	var tal_cfg: Dictionary = pd.get("talismans", {})
	var pity_cfg: Dictionary = tal_cfg.get("workshop_pity", {})
	var base_rare: int = int(pity_cfg.get("base_rates_bp", {}).get("rare", 2600))
	var epic_bp: int = workshop_epic_rate_bp(pity_counter, pd)
	var rare_bp: int = mini(base_rare, BP - epic_bp)
	var roll: int = rng.below(BP)
	var rarity: String = "common"
	var next_pity: int = pity_counter + 1
	if roll < epic_bp:
		rarity = "epic"
		if bool(pity_cfg.get("reset_on_epic", true)):
			next_pity = 0
	elif roll < epic_bp + rare_bp:
		rarity = "rare"

	# Pick slot uniformly
	var slots: Array = tal_cfg.get("slots", [])
	var slot_id: String = "comb"
	if not slots.is_empty():
		var sidx: int = rng.below(slots.size())
		slot_id = String(slots[sidx].get("id", "comb"))

	# Pick set with weekly focus weight multiplier (integer weighted pick)
	var sets_dict: Dictionary = tal_cfg.get("sets", {})
	var set_ids: Array = sets_dict.keys()
	set_ids.sort()
	var focus_mult: int = maxi(1, int(pity_cfg.get("weekly_focus_weight_mult", 2)))
	var total_w: int = 0
	for sid in set_ids:
		total_w += focus_mult if String(sid) == focus_set else 1
	var set_id: String = ""
	if total_w > 0:
		var wr: int = rng.below(total_w)
		var acc: int = 0
		for sid in set_ids:
			acc += focus_mult if String(sid) == focus_set else 1
			if wr < acc:
				set_id = String(sid)
				break

	return {
		"rarity": rarity,
		"slot": slot_id,
		"set": set_id,
		"pity_before": pity_counter,
		"pity_after": next_pity,
		"epic_rate_bp": epic_bp,
		"hard_pity_triggered": (pity_counter + 1) >= int(pity_cfg.get("hard_pity_run", 24)),
	}


# ------------------------------------------------------------------ W15 Catch-up ("догонялка", Appendix R)

static func catchup_xp_mult_bp(hero_level: int, squad_max_level: int, bal: Dictionary = {}) -> int:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var cu: Dictionary = b.get("catchup", {})
	if not bool(cu.get("enabled", true)):
		return BP
	var thr: int = int(cu.get("lag_levels_threshold", 10))
	if squad_max_level - hero_level >= thr:
		return int(cu.get("xp_mult_bp", 20000))
	return BP


static func catchup_powder_mult_bp(hero_level: int, squad_max_level: int, bal: Dictionary = {}) -> int:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var cu: Dictionary = b.get("catchup", {})
	if not bool(cu.get("enabled", true)):
		return BP
	var thr: int = int(cu.get("lag_levels_threshold", 10))
	if squad_max_level - hero_level >= thr:
		return int(cu.get("powder_mult_bp", 20000))
	return BP


static func apply_xp_with_catchup(hero_state: Dictionary, raw_xp: int, squad_max_level: int,
		level_cap: int = 60, bal: Dictionary = {}) -> Dictionary:
	var cur_lv: int = int(hero_state.get("level", 1))
	var mult_bp: int = catchup_xp_mult_bp(cur_lv, squad_max_level, bal)
	var eff_xp: int = mul_bp(maxi(0, raw_xp), mult_bp)
	var new_xp: int = int(hero_state.get("xp", cumulative_xp(cur_lv, bal))) + eff_xp
	var new_lv: int = level_for_xp(new_xp, level_cap, bal)
	hero_state["xp"] = new_xp
	hero_state["level"] = new_lv
	return {
		"raw_xp": raw_xp,
		"mult_bp": mult_bp,
		"effective_xp": eff_xp,
		"catchup_active": mult_bp > BP,
		"level_before": cur_lv,
		"level_after": new_lv,
	}


static func apply_powder_with_catchup(raw_powder: int, hero_level: int, squad_max_level: int, bal: Dictionary = {}) -> Dictionary:
	var mult_bp: int = catchup_powder_mult_bp(hero_level, squad_max_level, bal)
	var eff_powder: int = mul_bp(maxi(0, raw_powder), mult_bp)
	return {
		"raw_powder": raw_powder,
		"mult_bp": mult_bp,
		"effective_powder": eff_powder,
		"catchup_active": mult_bp > BP,
	}


static func sync_new_hero_level(squad_levels: Array, level_cap: int = 60, bal: Dictionary = {}) -> int:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var cu: Dictionary = b.get("catchup", {})
	if not bool(cu.get("enabled", true)) or not bool(cu.get("sync_new_hero_to_squad_avg", true)):
		return 1
	if squad_levels.is_empty():
		return 1
	var sum_lv: int = 0
	for lv in squad_levels:
		sum_lv += maxi(1, int(lv))
	var avg_lv: int = sum_lv / squad_levels.size()
	return clampi(avg_lv, 1, maxi(1, level_cap))


static func claim_pre_cap_raise_gift(days_until_cap_raise: int, already_claimed: bool, bal: Dictionary = {}) -> Dictionary:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var cu: Dictionary = b.get("catchup", {})
	if not bool(cu.get("enabled", true)):
		return {"ok": false, "reason": "catchup_disabled", "xp": 0}
	if already_claimed:
		return {"ok": false, "reason": "already_claimed", "xp": 0}
	var window_days: int = int(cu.get("pre_cap_raise_gift_days_before", 7))
	if days_until_cap_raise < 0 or days_until_cap_raise > window_days:
		return {"ok": false, "reason": "outside_window", "xp": 0}
	return {"ok": true, "xp": int(cu.get("pre_cap_raise_gift_xp", 60000))}


static func buy_paid_accelerator(kind: String, bal: Dictionary = {}) -> Dictionary:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var flags: Dictionary = b.get("flags", {})
	if not bool(flags.get("paid_accelerators_enabled", false)):
		return {"ok": false, "reason": "paid_accelerators_disabled_in_variant_a", "kind": kind}
	return {"ok": true, "kind": kind}


# ------------------------------------------------------------------ Heroine combat stats (BU §2.6, AT-B03)

static func effective_flags(bal: Dictionary = {}, flags_override: Dictionary = {}) -> Dictionary:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var f: Dictionary = b.get("flags", {}).duplicate(true)
	for k in flags_override:
		f[k] = flags_override[k]
	return f


static func compute_hero_stats(hero_id: String, spec: Dictionary, bal: Dictionary = {}, flags_override: Dictionary = {}) -> Dictionary:
	# Computes exact integer ATK and HP per BATTLE_ULT_SPEC §2.6 & Appendix R R.1:
	#   stat(L) = stat1 * (10000 + level_step_bp * (L - 1)) / 10000
	#   ATK = stat_atk(L) * (1 + T_atk) * (1 + min(CAP, outfit_atk + album) + bond)
	#   HP  = stat_hp(L)  * (1 + 0.9*T_atk) * (1 + min(CAP*0.6, 0.6*outfit_atk + album) + bond)
	# All multiplications use deterministic integer mul_bp with floor.
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var prog: Dictionary = b.get("progression", {})
	var flags: Dictionary = effective_flags(b, flags_override)
	var hdef: Dictionary = b.get("heroes", {}).get(hero_id, {})
	var role: String = String(spec.get("role", hdef.get("role", "ATK")))
	var aura: String = String(spec.get("aura", hdef.get("aura", "man")))
	var rdef: Dictionary = b.get("roles", {}).get(role, {"atk1": 100, "hp1": 80, "energy_mult_bp": BP, "ult_dmg_bp": 90000})

	var level: int = clampi(int(spec.get("level", 1)), 1, int(prog.get("level_cap_max", 90)))
	var lv_bp: int = BP + int(prog.get("level_step_bp", 1000)) * (level - 1)
	var base_atk: int = mul_bp(int(rdef.get("atk1", 100)), lv_bp)
	var base_hp: int = mul_bp(int(rdef.get("hp1", 80)), lv_bp)

	var tal_max_bp: int = int(prog.get("talisman_max_bp", 4300))
	var tal_atk_bp: int = clampi(int(spec.get("talisman_atk_bp", 0)), 0, tal_max_bp)
	var tal_hp_bp: int = mul_bp(tal_atk_bp, int(prog.get("talisman_hp_ratio_bp", 9000)))
	var atk_tal: int = mul_bp(base_atk, BP + tal_atk_bp)
	var hp_tal: int = mul_bp(base_hp, BP + tal_hp_bp)

	var outfit_enabled: bool = bool(flags.get("outfit_stats_enabled", false))
	var bond_enabled: bool = bool(flags.get("bond_stats_enabled", false))

	var cap_bp: int = 0
	if outfit_enabled:
		cap_bp = int(flags_override.get("monetizable_cap_bp", prog.get("monetizable_cap_bp_variant_b", 2800)))
	var outfit_atk_bp: int = 0
	var album_bp: int = 0
	if outfit_enabled and cap_bp > 0:
		var tier: String = String(spec.get("outfit_tier", "BASE"))
		var stars: int = clampi(int(spec.get("outfit_stars", 0)), 0, int(prog.get("outfit_max_stars", 5)))
		var obase: Dictionary = prog.get("outfit_base_bp", {})
		var ostep: Dictionary = prog.get("outfit_star_step_bp", {})
		outfit_atk_bp = int(obase.get(tier, 0)) + int(ostep.get(tier, 0)) * stars
		var album_count: int = maxi(0, int(spec.get("album_count", 0)))
		album_bp = mini(
			int(prog.get("collection_cap_bp", 600)),
			int(prog.get("collection_per_outfit_bp", 25)) * album_count
		)
	var hp_ratio_bp: int = int(prog.get("outfit_hp_ratio_bp", 6000))
	var outfit_hp_bp: int = mul_bp(outfit_atk_bp, hp_ratio_bp)
	var cap_hp_bp: int = mul_bp(cap_bp, hp_ratio_bp)
	var mon_atk_bp: int = mini(cap_bp, outfit_atk_bp + album_bp)
	var mon_hp_bp: int = mini(cap_hp_bp, outfit_hp_bp + album_bp)

	var bond_bp: int = 0
	if bond_enabled:
		var bond_lv: int = clampi(int(spec.get("bond_level", 0)), 0, int(prog.get("bond_max_lv", 10)))
		bond_bp = int(prog.get("bond_per_lv_bp", 50)) * bond_lv

	var final_atk: int = mul_bp(atk_tal, BP + mon_atk_bp + bond_bp)
	var final_hp: int = mul_bp(hp_tal, BP + mon_hp_bp + bond_bp)

	return {
		"hero_id": hero_id,
		"role": role,
		"aura": aura,
		"level": level,
		"base_atk": base_atk,
		"base_hp": base_hp,
		"atk": final_atk,
		"hp": final_hp,
		"talisman_atk_bp": tal_atk_bp,
		"talisman_hp_bp": tal_hp_bp,
		"mon_atk_bp": mon_atk_bp,
		"mon_hp_bp": mon_hp_bp,
		"bond_bp": bond_bp,
		"outfit_stats_enabled": outfit_enabled,
		"bond_stats_enabled": bond_enabled,
		"energy_mult_bp": int(rdef.get("energy_mult_bp", BP)),
		"ult_dmg_bp": int(rdef.get("ult_dmg_bp", 90000)),
	}
