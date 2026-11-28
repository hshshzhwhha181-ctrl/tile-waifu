class_name TWBattleMath
extends RefCounted

# TWBattleMath (P74 / BATTLE_ULT_SPEC §1.4-§1.7, §2.2, Appendix R T10):
# 100% pure integer basis-point combat math (bp_scale = 10000, energy_scale = 1000, shield_scale = 1000).
# Uses deterministic `mul_bp(a, bp)` with floor division and a fixed multiplication order so x86_64 and
# arm64 produce bit-for-bit identical outcomes. Zero floating-point transcendentals (no pow/exp/log/sin/cos/randf).

const BP: int = 10000
const ENERGY_SCALE: int = 1000
const SHIELD_SCALE: int = 1000

# Precomputed integer XP table generated from round(18 * L^1.5) for L=1..89 (Appendix R T10).
# Cumulative sums reproduce Lv20=12086, Lv40=70595, Lv60=196610, Lv70=289922, Lv80=405733, Lv90=545611.
const XP_STEP_TABLE: Array = [
	18, 51, 94, 144, 201, 265, 333, 407, 486, 569,
	657, 748, 844, 943, 1046, 1152, 1262, 1375, 1491, 1610,
	1732, 1857, 1985, 2116, 2250, 2386, 2525, 2667, 2811, 2958,
	3107, 3258, 3412, 3569, 3727, 3888, 4051, 4216, 4384, 4554,
	4726, 4899, 5075, 5254, 5434, 5616, 5800, 5986, 6174, 6364,
	6556, 6750, 6945, 7143, 7342, 7543, 7746, 7951, 8157, 8366,
	8576, 8787, 9001, 9216, 9433, 9651, 9872, 10093, 10317, 10542,
	10769, 10997, 11227, 11458, 11691, 11926, 12162, 12400, 12639, 12880,
	13122, 13366, 13611, 13858, 14106, 14356, 14607, 14859, 15113,
]


static func mul_bp(a: int, bp: int) -> int:
	# Deterministic integer floor(a * bp / 10000).
	var prod: int = a * bp
	if prod >= 0:
		return prod / BP
	return -(((-prod) + BP - 1) / BP)


static func xp_step(level: int) -> int:
	if level < 1 or level > XP_STEP_TABLE.size():
		return 0
	return int(XP_STEP_TABLE[level - 1])


static func xp_cum(level: int) -> int:
	if level <= 1:
		return 0
	var lim: int = mini(level - 1, XP_STEP_TABLE.size())
	var acc: int = 0
	for i in lim:
		acc += int(XP_STEP_TABLE[i])
	return acc


# ------------------------------------------------------------------ Suits & faces (0..35)

static func suit_of_face(face: int) -> String:
	if face >= 0 and face <= 8:
		return "man"
	if face >= 9 and face <= 17:
		return "pin"
	if face >= 18 and face <= 26:
		return "sou"
	return "honor"


static func rank_of_face(face: int) -> int:
	if face >= 0 and face <= 26:
		return (face % 9) + 1
	return 0


# ------------------------------------------------------------------ Patterns ("Узоры", §1.5.3)

static func pattern(history: Array, bal: Dictionary = {}) -> Dictionary:
	# Evaluates the last <= 6 matched pairs and returns the single highest-bonus pattern.
	# Each entry in `history`: {"suit": String, "face": int, "rank": int}
	var n: int = history.size()
	if n == 0:
		return {"id": "", "dmg_bonus_bp": 0, "energy_bonus_milli": 0}
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var pcfg: Dictionary = b.get("patterns", {})
	var last: Dictionary = history[n - 1]
	var last_suit: String = String(last.get("suit", "honor"))
	var last_face: int = int(last.get("face", -1))

	var best_id: String = ""
	var best_bp: int = 0
	var best_en: int = 0

	# 1. Pure hand ("Чистая рука"): 6 consecutive non-honor pairs of the same suit
	if n >= 6 and last_suit != "honor":
		var same6: bool = true
		for i in range(n - 6, n):
			if String(history[i].get("suit", "")) != last_suit:
				same6 = false
				break
		if same6:
			var p_pure: Dictionary = pcfg.get("pure", {"dmg_bonus_bp": 8000, "energy_bonus_milli": 20000})
			var bp_val: int = int(p_pure.get("dmg_bonus_bp", 8000))
			if bp_val > best_bp:
				best_id = "pure"
				best_bp = bp_val
				best_en = int(p_pure.get("energy_bonus_milli", 20000))

	# 2. Ladder ("Ступени"): 3 consecutive non-honor pairs of same suit with ranks r, r+1, r+2
	if n >= 3 and last_suit != "honor":
		var h0: Dictionary = history[n - 3]
		var h1: Dictionary = history[n - 2]
		var h2: Dictionary = history[n - 1]
		if String(h0.get("suit", "")) == last_suit and String(h1.get("suit", "")) == last_suit:
			var r0: int = int(h0.get("rank", 0))
			var r1: int = int(h1.get("rank", 0))
			var r2: int = int(h2.get("rank", 0))
			if r0 >= 1 and r1 == r0 + 1 and r2 == r1 + 1:
				var p_lad: Dictionary = pcfg.get("ladder", {"dmg_bonus_bp": 3500, "energy_bonus_milli": 0})
				var bp_val: int = int(p_lad.get("dmg_bonus_bp", 3500))
				if bp_val > best_bp:
					best_id = "ladder"
					best_bp = bp_val
					best_en = int(p_lad.get("energy_bonus_milli", 0))

	# 3. Kan ("Кан"): current pair has same face as previous pair
	if n >= 2 and last_face >= 0:
		var prev_face: int = int(history[n - 2].get("face", -2))
		if prev_face == last_face:
			var p_kan: Dictionary = pcfg.get("kan", {"dmg_bonus_bp": 2500, "energy_bonus_milli": 0})
			var bp_val: int = int(p_kan.get("dmg_bonus_bp", 2500))
			if bp_val > best_bp:
				best_id = "kan"
				best_bp = bp_val
				best_en = int(p_kan.get("energy_bonus_milli", 0))

	# 4. One suit ("Одномастка"): 3 consecutive non-honor pairs of the same suit
	if n >= 3 and last_suit != "honor":
		if String(history[n - 3].get("suit", "")) == last_suit and String(history[n - 2].get("suit", "")) == last_suit:
			var p_one: Dictionary = pcfg.get("one_suit", {"dmg_bonus_bp": 2000, "energy_bonus_milli": 0})
			var bp_val: int = int(p_one.get("dmg_bonus_bp", 2000))
			if bp_val > best_bp:
				best_id = "one_suit"
				best_bp = bp_val
				best_en = int(p_one.get("energy_bonus_milli", 0))

	return {"id": best_id, "dmg_bonus_bp": best_bp, "energy_bonus_milli": best_en}


# ------------------------------------------------------------------ Combat formulas (§1.4 - §1.7)

static func combo_mult_bp(combo: int, extra_step_bp: int = 0, bal: Dictionary = {}) -> int:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var c: Dictionary = b.get("combat", {})
	var cap: int = int(c.get("combo_cap", 6))
	var step: int = int(c.get("combo_step_bp", 2500)) + extra_step_bp
	var steps: int = clampi(combo - 1, 0, cap)
	return BP + step * steps


static func resonance_bp(hero_aura: String, suit: String, honor_resonant: bool = false, bal: Dictionary = {}) -> int:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var c: Dictionary = b.get("combat", {})
	if suit == "honor":
		return int(c.get("res_full_bp", 10000)) if honor_resonant else int(c.get("honor_pair_bp", 7000))
	if hero_aura == suit:
		return int(c.get("res_full_bp", 10000))
	return int(c.get("res_off_bp", 4000))


static func pair_damage(squad: Array, suit: String, combo: int, pattern_bonus_bp: int,
		ctx: Dictionary = {}, bal: Dictionary = {}) -> Dictionary:
	# Exact deterministic multiplication order (BU §1.5.1, T10):
	#   raw = sum_i mul_bp(atk_i, res_bp(aura_i, suit))
	#   dmg = mul_bp(raw, pair_norm_bp)
	#   dmg = mul_bp(dmg, combo_mult_bp)
	#   dmg = mul_bp(dmg, BP + pattern_bonus_bp)
	#   -> weak/resist -> fever -> buff -> gold_crit -> mark -> passive_pair_bonus -> break -> from_ult
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var c: Dictionary = b.get("combat", {})
	var sb: Dictionary = b.get("shield_and_boss", {})
	var honor_res: bool = bool(ctx.get("honor_resonant", false))

	var raw: int = 0
	var resonant_heroes: Array = []
	for h in squad:
		var haura: String = String(h.get("aura", ""))
		var rbp: int = resonance_bp(haura, suit, honor_res, b)
		raw += mul_bp(int(h.get("atk", 0)), rbp)
		if (suit == "honor" and honor_res) or (suit != "honor" and haura == suit):
			resonant_heroes.append(String(h.get("hero_id", h.get("id", ""))))

	var dmg: int = mul_bp(raw, int(c.get("pair_norm_bp", 3500)))
	var cm_bp: int = combo_mult_bp(combo, int(ctx.get("combo_step_bonus_bp", 0)), b)
	dmg = mul_bp(dmg, cm_bp)
	dmg = mul_bp(dmg, BP + maxi(0, pattern_bonus_bp))

	var weak_suit: String = String(ctx.get("weak", ""))
	var resist_suit: String = String(ctx.get("resist", ""))
	if weak_suit != "" and suit == weak_suit:
		dmg = mul_bp(dmg, int(c.get("weak_mult_bp", 12500)))
	if resist_suit != "" and suit == resist_suit:
		dmg = mul_bp(dmg, int(c.get("resist_mult_bp", 8500)))
	if bool(ctx.get("fever", false)):
		dmg = mul_bp(dmg, int(c.get("fever_dmg_bp", 13000)))
	if bool(ctx.get("buff", false)):
		dmg = mul_bp(dmg, int(c.get("support_buff_bp", 12500)))
	if bool(ctx.get("gold", false)):
		var g_bp: int = int(ctx.get("gold_crit_bp", c.get("gold_crit_bp", 15000)))
		dmg = mul_bp(dmg, g_bp)
	var mark_bp: int = int(ctx.get("mark_bp", BP))
	if mark_bp != BP:
		dmg = mul_bp(dmg, mark_bp)
	var pair_bonus_bp: int = int(ctx.get("pair_dmg_bonus_bp", 0))
	if pair_bonus_bp > 0:
		dmg = mul_bp(dmg, BP + pair_bonus_bp)
	if bool(ctx.get("broken", false)):
		dmg = mul_bp(dmg, int(sb.get("break_mult_bp", 20000)))
	if bool(ctx.get("from_ult", false)):
		dmg = mul_bp(dmg, int(c.get("ult_pair_dmg_bp", 5000)))

	return {"raw": raw, "dmg": dmg, "combo_mult_bp": cm_bp, "resonant": resonant_heroes}


static func energy_gain_milli(hero: Dictionary, suit: String, combo: int, fever: bool,
		honor_resonant: bool = false, bal: Dictionary = {}) -> int:
	# Pure energy gain in milli-energy (1000 = 1.0 energy, 100000 = 100.0 ult cost).
	# Independent of outfit tier/stars/bond (AT-B06).
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var c: Dictionary = b.get("combat", {})
	var base_m: int = int(c.get("energy_pair_milli", 2400))
	var enr_bp: int = int(hero.get("energy_mult_bp", hero.get("enr_bp", BP)))
	var g: int = mul_bp(base_m, enr_bp)
	if suit == "honor":
		var h_mult: int = int(c.get("energy_res_bp", 16000)) if honor_resonant else int(c.get("energy_honor_bp", 12000))
		g = mul_bp(g, h_mult)
	elif String(hero.get("aura", "")) == suit:
		g = mul_bp(g, int(c.get("energy_res_bp", 16000)))
	var cap: int = int(c.get("combo_cap", 6))
	var c_steps: int = clampi(combo - 1, 0, cap)
	g += int(c.get("energy_combo_milli", 200)) * c_steps
	if fever:
		g = mul_bp(g, int(c.get("fever_energy_bp", 15000)))
	return g


static func ult_damage(hero: Dictionary, ctx: Dictionary = {}, bal: Dictionary = {}) -> int:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var prog: Dictionary = b.get("progression", {})
	var sb: Dictionary = b.get("shield_and_boss", {})
	var c: Dictionary = b.get("combat", {})
	var re: Dictionary = b.get("role_effects", {})

	var atk: int = int(hero.get("atk", 0))
	var m_bp: int = int(hero.get("ult_dmg_bp", 30000))
	var sk_lv: int = maxi(1, int(hero.get("ult_level", hero.get("skill", 1))))
	var sk_bp: int = BP + int(prog.get("skill_ult_step_bp", 600)) * (sk_lv - 1)

	var ud: int = mul_bp(atk, m_bp)
	ud = mul_bp(ud, sk_bp)

	var weak_suit: String = String(ctx.get("weak", ""))
	var resist_suit: String = String(ctx.get("resist", ""))
	var haura: String = String(hero.get("aura", ""))
	if bool(ctx.get("apply_aura_weakness", false)):
		if weak_suit != "" and haura == weak_suit:
			ud = mul_bp(ud, int(c.get("weak_mult_bp", 12500)))
		elif resist_suit != "" and haura == resist_suit:
			ud = mul_bp(ud, int(c.get("resist_mult_bp", 8500)))

	if bool(ctx.get("broken", false)):
		ud = mul_bp(ud, int(sb.get("break_mult_bp", 20000)))
		if bool(ctx.get("atk_broken_bonus", false)):
			ud = mul_bp(ud, int(re.get("atk_broken_bonus_bp", 12500)))

	var team_ult_bonus_bp: int = int(ctx.get("team_ult_dmg_bonus_bp", 0))
	if team_ult_bonus_bp > 0:
		ud = mul_bp(ud, BP + team_ult_bonus_bp)

	var twist_bp: int = int(ctx.get("twist_dmg_bp", BP))
	if twist_bp != BP:
		ud = mul_bp(ud, twist_bp)

	return ud


static func shield_damage_milli(is_ult: bool, has_brk_in_squad: bool, caster_role: String,
		fever: bool, bonus_bp: int = 0, mult_bp: int = BP, bal: Dictionary = {}) -> int:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var sb: Dictionary = b.get("shield_and_boss", {})
	var c: Dictionary = b.get("combat", {})
	var dmg: int = int(sb.get("shield_ult_milli", 4000)) if is_ult else int(sb.get("shield_pair_milli", 1000))
	if is_ult:
		if caster_role == "BRK":
			dmg = mul_bp(dmg, int(sb.get("shield_brk_ult_bp", 15000)))
	else:
		if has_brk_in_squad:
			dmg = mul_bp(dmg, int(sb.get("shield_brk_team_bp", 12500)))
		if fever:
			dmg = mul_bp(dmg, int(c.get("fever_shield_bp", 16000)))
		if bonus_bp > 0:
			dmg = mul_bp(dmg, BP + bonus_bp)
		if mult_bp != BP:
			dmg = mul_bp(dmg, mult_bp)
	return dmg


static func boss_cast_damage(ref_team_hp: int, wave_idx: int, cast_num: int,
		boss_atk_bp: int = -1, bal: Dictionary = {}) -> int:
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var sb: Dictionary = b.get("shield_and_boss", {})
	var atk_bp: int = boss_atk_bp if boss_atk_bp >= 0 else int(sb.get("boss_atk_bp", 4000))
	var d: int = mul_bp(ref_team_hp, atk_bp)
	d = mul_bp(d, BP + int(sb.get("enrage_per_wave_bp", 8000)) * maxi(0, wave_idx))
	var heavy_every: int = maxi(1, int(sb.get("boss_heavy_every", 3)))
	if cast_num > 0 and (cast_num % heavy_every) == 0:
		d = mul_bp(d, int(sb.get("boss_heavy_bp", 18000)))
	return d


static func team_pair_power_x10(squad: Array, bal: Dictionary = {}) -> int:
	# Pure integer expected combo-1 pair power x10 under neutral suit distribution (81% suits / 19% honor).
	var b: Dictionary = bal if not bal.is_empty() else TWBattleData.balance()
	var c: Dictionary = b.get("combat", {})
	var auras: Array = b.get("auras", ["man", "pin", "sou"])
	var suit_prob_bp: int = int(b.get("sim", {}).get("suit_prob_bp", 8100))
	var honor_prob_bp: int = BP - suit_prob_bp
	var norm_bp: int = int(c.get("pair_norm_bp", 3500))
	var suit_sum: int = 0
	for s in auras:
		var r_s: int = 0
		for h in squad:
			r_s += mul_bp(int(h.get("atk", 0)), resonance_bp(String(h.get("aura", "")), String(s), false, b))
		suit_sum += mul_bp(r_s, norm_bp)
	var avg_suit_x10: int = (suit_sum * 10) / maxi(1, auras.size())
	var r_h: int = 0
	for h in squad:
		r_h += mul_bp(int(h.get("atk", 0)), resonance_bp(String(h.get("aura", "")), "honor", false, b))
	var honor_x10: int = mul_bp(r_h, norm_bp) * 10
	return mul_bp(avg_suit_x10, suit_prob_bp) + mul_bp(honor_x10, honor_prob_bp)
