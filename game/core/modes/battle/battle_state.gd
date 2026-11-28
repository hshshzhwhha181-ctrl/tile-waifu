class_name TWBattle
extends RefCounted

# TWBattle (P74 / BATTLE_ULT_SPEC §1.4-§1.10, §7.6-§7.7, Appendix R T10):
# Pure, 100% integer Layer B combat state machine: `(seed, squad, stage, actions[]) -> events + state_hash`.
#   - Zero Node / Control / timers / Engine / global randf. Time arrives strictly as `tnow_ms: int` from shell.
#   - All multiplications use TWBattleMath.mul_bp (floor) in fixed order for x86/arm64 bit-exact parity.
#   - `ULT_AIM` is logged in `journal` and emits `TWBattleEvents.ULT_AIM` (T10).
#   - `ULT_CAST` applies effects immediately in core; presentation mode ("full"/"assist"/"off"/"skip")
#     never alters state or `state_hash()` (AT-U10).

const E = preload("res://core/modes/battle/battle_events.gd")

const ST_INIT: = "INIT"
const ST_INTRO: = "INTRO"
const ST_PLAYING: = "PLAYING"
const ST_ULT_AIM: = "ULT_AIM"
const ST_ULT_CINEMATIC: = "ULT_CINEMATIC"
const ST_CAST: = "CAST"
const ST_WAVE_CLEAR: = "WAVE_CLEAR"
const ST_PAUSED: = "PAUSED"
const ST_END: = "END"

const BP: int = 10000
const BOSS_MECHANICS: Array = ["seal", "fog", "ice", "chain", "dark"]

var seed_val: int = 1
var rng: TWRng
var bal: Dictionary = {}
var heroes_data: Dictionary = {}
var flags_override: Dictionary = {}
var stage_cfg: Dictionary = {}

var state: String = ST_INIT
var prev_state: String = ST_PLAYING
var tick: int = 0
var over: bool = false
var won: bool = false
var defeat_reason: String = ""

var squad: Array = []          # Array of hero combat dicts (atk, hp, role, aura, energy, skills, twist...)
var team_max_hp: int = 1
var team_hp: int = 1
var guard_hp: int = 0
var guard_casts_left: int = 0
var seal_immunity_casts: int = 0
var tray_wards: int = 0
var tray_jokers: int = 0

var boss_max_hp: int = 1
var boss_hp: int = 1
var ref_team_hp: int = 1
var boss_atk_bp: int = 4000
var boss_cadence: int = 6
var boss_clock: int = 0
var boss_casts: int = 0
var skip_boss_casts: int = 0
var boss_weak: String = ""
var boss_resist: String = ""
var boss_mechanic_pool: Array = ["seal", "fog", "ice"]
var assist_used: bool = false

var shield_max_milli: int = 16000
var shield_milli: int = 16000
var broken_hits: int = 0
var stun_casts: int = 0

var waves: Array = [36, 24]
var wave_idx: int = 0
var wave_pairs: int = 0
var wave_cleared_flags: Array = []

var combo: int = 0
var best_combo: int = 0
var last_match_ms: int = -1000000
var fever_pairs: int = 0
var buff_pairs: int = 0
var honor_resonant_ult_pairs: int = 0
var yue_gold_pairs_left: int = 0
var burn_dmg: int = 0
var burn_pairs: int = 0
var mark_bp: int = BP
var mark_pairs: int = 0
var pending_ult_aim_idx: int = -1

var pairs_done: int = 0
var ults_used: int = 0
var pair_dmg_total: int = 0
var ult_dmg_total: int = 0
var history: Array = []        # last <= 6 pairs: {"suit", "face", "rank"}
var journal: Array = []        # full action log for deterministic replay

# Squad-wide passive/leader cache (all integer)
var _has_brk: bool = false
var _leader_id: String = ""
var _leader_honor_resonant: bool = false
var _fever_threshold: int = 10
var _fever_bonus_pairs: int = 0
var _combo_step_bonus_bp: int = 0
var _pair_dmg_bonus_bp: int = 0
var _team_ult_dmg_bonus_bp: int = 0
var _gold_crit_bonus_bp: int = 0
var _pair_shield_bonus_bp: int = 0
var _gold_pair_shield_bonus_bp: int = 0
var _ally_energy_per_pair_milli: int = 0
var _lowest_ally_energy_per_pair_milli: int = 0
var _rin_gold_heal_bp: int = 0
var _rin_leader_cleanse: int = 0
var _tsubame_every_n: int = 0
var _yue_gold_every_n: int = 0
var _zlata_melt_every_n: int = 0
var _healer_count: int = 0


static func create(seed_: int, squad_specs: Array, stage_: Dictionary,
		bal_: Dictionary = {}, flags_ovr: Dictionary = {}) -> TWBattle:
	var b: TWBattle = TWBattle.new()
	b.seed_val = seed_
	b.rng = TWRng.make(seed_, 74)
	b.bal = bal_ if not bal_.is_empty() else TWBattleData.balance()
	b.heroes_data = TWBattleData.heroes().get("heroes", {})
	b.flags_override = flags_ovr.duplicate(true)
	b.stage_cfg = stage_.duplicate(true)
	b._init_squad(squad_specs)
	b._init_stage()
	return b


func _init_squad(squad_specs: Array) -> void:
	squad = []
	var c: Dictionary = bal.get("combat", {})
	var start_energy: int = int(c.get("energy_start_milli", 40000))
	team_max_hp = 0
	for idx in squad_specs.size():
		var raw: Dictionary = squad_specs[idx]
		var hid: String = String(raw.get("hero_id", raw.get("id", "hana")))
		var st: Dictionary = TWBattleProgress.compute_hero_stats(hid, raw, bal, flags_override)
		var atk_val: int = int(raw.get("atk_override", st.atk))
		var hp_val: int = int(raw.get("hp_override", st.hp))
		if raw.has("atk_scale_bp"):
			atk_val = maxi(1, TWBattleMath.mul_bp(atk_val, int(raw["atk_scale_bp"])))
		if raw.has("hp_scale_bp"):
			hp_val = maxi(1, TWBattleMath.mul_bp(hp_val, int(raw["hp_scale_bp"])))
		var hmeta: Dictionary = heroes_data.get(hid, {})
		var ult_meta: Dictionary = hmeta.get("ult", {})
		var entry: Dictionary = {
			"hero_id": hid,
			"role": String(raw.get("role", st.role)),
			"aura": String(raw.get("aura", st.aura)),
			"level": int(st.level),
			"atk": atk_val,
			"hp": hp_val,
			"energy_mult_bp": int(st.energy_mult_bp),
			"ult_dmg_bp": int(ult_meta.get("dmg_bp", st.ult_dmg_bp)),
			"ult_level": maxi(1, int(raw.get("ult_level", raw.get("skill", 1)))),
			"passive_level": maxi(1, int(raw.get("passive_level", raw.get("skill", 1)))),
			"leader_level": maxi(1, int(raw.get("leader_level", 1))),
			"needs_aim": bool(ult_meta.get("needs_aim", false)),
			"aim_kind": String(ult_meta.get("aim_kind", "")),
			"twist_id": String(raw.get("twist_id", "")),
			"twist_tier": String(raw.get("twist_tier", "minor")),
			"ult_id": String(raw.get("ult_id", hid + "_base")),
			"energy": start_energy,
			"is_guest": bool(raw.get("is_guest", false)),
		}
		squad.append(entry)
		team_max_hp += hp_val
	team_max_hp = maxi(1, team_max_hp)
	team_hp = team_max_hp
	_compile_passives_and_leader()


func _compile_passives_and_leader() -> void:
	var c: Dictionary = bal.get("combat", {})
	_has_brk = false
	_leader_id = ""
	_leader_honor_resonant = false
	_fever_threshold = int(c.get("fever_combo", 10))
	_fever_bonus_pairs = 0
	_combo_step_bonus_bp = 0
	_pair_dmg_bonus_bp = 0
	_team_ult_dmg_bonus_bp = 0
	_gold_crit_bonus_bp = 0
	_pair_shield_bonus_bp = 0
	_gold_pair_shield_bonus_bp = 0
	_ally_energy_per_pair_milli = 0
	_lowest_ally_energy_per_pair_milli = 0
	_rin_gold_heal_bp = 0
	_rin_leader_cleanse = 0
	_tsubame_every_n = 0
	_yue_gold_every_n = 0
	_zlata_melt_every_n = 0
	_healer_count = 0

	var use_passives: bool = bool(stage_cfg.get("enable_hero_passives", true))
	for i in squad.size():
		var h: Dictionary = squad[i]
		var hid: String = String(h.hero_id)
		if String(h.role) == "BRK":
			_has_brk = true
		if String(h.role) == "HEAL":
			_healer_count += 1
		if not use_passives:
			continue
		var hmeta: Dictionary = heroes_data.get(hid, {})
		var p: Dictionary = hmeta.get("passive", {}).get("params", {})
		match hid:
			"mc":
				_ally_energy_per_pair_milli += int(p.get("ally_energy_milli", 300))
			"rin":
				_rin_gold_heal_bp += int(p.get("gold_pair_heal_bp", 100))
			"hana":
				_combo_step_bonus_bp += int(p.get("combo_step_bonus_bp", 500))
			"yue":
				_gold_crit_bonus_bp += int(p.get("gold_crit_bonus_bp", 1500))
			"nova":
				_pair_shield_bonus_bp += int(p.get("pair_shield_bonus_bp", 1500))
			"tsubame":
				_tsubame_every_n = int(p.get("every_n_pairs", 6))
			"miel":
				_lowest_ally_energy_per_pair_milli += int(p.get("lowest_ally_energy_milli", 500))
			"kohaku":
				_team_ult_dmg_bonus_bp += int(p.get("team_ult_dmg_bonus_bp", 400))
			"shirin":
				_gold_pair_shield_bonus_bp += int(p.get("gold_pair_shield_bonus_bp", 1000))
			"zlata":
				_pair_dmg_bonus_bp += int(p.get("pair_dmg_bonus_bp", 300))

		# Leader skill active only for slot 0 (non-guest, level >= 30 or forced)
		if i == 0 and not bool(h.is_guest):
			_leader_id = hid
			var lcfg: Dictionary = hmeta.get("leader", {})
			var unlock_lv: int = int(lcfg.get("unlock_level", 30))
			if int(h.level) >= unlock_lv or bool(stage_cfg.get("force_leader_active", false)):
				var lp: Dictionary = lcfg.get("params", {})
				match hid:
					"mc":
						_leader_honor_resonant = bool(lp.get("honor_resonant_all", true))
					"rin":
						_rin_leader_cleanse = int(lp.get("cleanse_seals", 1))
					"hana":
						_fever_threshold = int(lp.get("fever_combo_threshold", 8))
					"yue":
						_yue_gold_every_n = int(lp.get("gold_pair_every_n", 8))
					"shirin":
						_fever_bonus_pairs = int(lp.get("fever_extra_pairs", 2))
					"zlata":
						_zlata_melt_every_n = int(lp.get("every_n_pairs", 6))


func _init_stage() -> void:
	var sb: Dictionary = bal.get("shield_and_boss", {})
	var diff_key: String = String(stage_cfg.get("difficulty", "normal"))
	var dcfg: Dictionary = sb.get("difficulties", {}).get(diff_key, {"hp_bp": BP, "atk_bp": BP})
	var base_boss_hp: int = maxi(1, int(stage_cfg.get("boss_hp", 75995)))
	boss_max_hp = maxi(1, TWBattleMath.mul_bp(base_boss_hp, int(dcfg.get("hp_bp", BP))))
	assist_used = bool(stage_cfg.get("assist_mode", false))
	if assist_used:
		var red_bp: int = int(sb.get("assist_hp_reduction_bp", 1500))
		boss_max_hp = maxi(1, TWBattleMath.mul_bp(boss_max_hp, BP - red_bp))
	boss_hp = boss_max_hp

	var base_ref_hp: int = int(stage_cfg.get("ref_team_hp", team_max_hp))
	ref_team_hp = maxi(1, TWBattleMath.mul_bp(base_ref_hp, int(dcfg.get("atk_bp", BP))))
	boss_atk_bp = int(stage_cfg.get("boss_atk_bp", sb.get("boss_atk_bp", 4000)))
	boss_cadence = maxi(int(sb.get("boss_cadence_min", 3)), int(stage_cfg.get("cadence", sb.get("boss_cadence_default", 6))))
	boss_weak = String(stage_cfg.get("weak", ""))
	boss_resist = String(stage_cfg.get("resist", ""))
	boss_mechanic_pool = stage_cfg.get("mechanics", ["seal", "fog", "ice"]).duplicate()
	if boss_mechanic_pool.is_empty():
		boss_mechanic_pool = ["seal"]

	var sh_units: int = maxi(1, int(stage_cfg.get("shield_units", sb.get("shield_units_default", 16))))
	shield_max_milli = sh_units * TWBattleMath.SHIELD_SCALE
	shield_milli = shield_max_milli

	waves = stage_cfg.get("waves", sb.get("waves_default", [36, 24])).duplicate()
	if waves.is_empty():
		waves = [36]
	wave_idx = 0
	wave_pairs = 0
	wave_cleared_flags = []
	for _i in waves.size():
		wave_cleared_flags.append(false)

	# Apply start-of-battle leader skills (Nova / Tsubame / Miel / Kohaku)
	if bool(stage_cfg.get("enable_hero_passives", true)) and not squad.is_empty():
		var lead: Dictionary = squad[0]
		var unlock_lv: int = 30
		if not bool(lead.is_guest) and (int(lead.level) >= unlock_lv or bool(stage_cfg.get("force_leader_active", false))):
			match String(lead.hero_id):
				"nova":
					shield_milli = maxi(1, TWBattleMath.mul_bp(shield_milli, BP - 1000))
				"tsubame":
					skip_boss_casts = 1
				"miel":
					tray_jokers = 1
				"kohaku":
					tray_wards = 1


func start() -> Array:
	if state != ST_INIT:
		return []
	state = ST_PLAYING
	tick += 1
	return [E.make(E.BATTLE_START, tick, {
		"seed": seed_val,
		"boss_hp": boss_hp,
		"team_hp": team_hp,
		"shield_milli": shield_milli,
		"waves": waves.duplicate(),
	})]


func step(action: Dictionary) -> Array:
	if state == ST_INIT:
		start()
	var atype: String = String(action.get("type", ""))
	if atype == "PAUSE":
		if state != ST_PAUSED and state != ST_END:
			prev_state = state
			state = ST_PAUSED
		journal.append(action.duplicate(true))
		return []
	if atype == "RESUME":
		if state == ST_PAUSED:
			state = prev_state
		journal.append(action.duplicate(true))
		return []
	if over or state == ST_END:
		return []

	journal.append(action.duplicate(true))
	tick += 1
	match atype:
		"PAIR":
			return _on_pair(action)
		"ULT_AIM":
			return _on_ult_aim(action)
		"ULT_CAST":
			return _on_ult_cast(action)
		"OVERFLOW":
			return _on_overflow(action)
		"WAVE_CLEAR":
			return _on_wave_clear(action)
		_:
			return []


func _on_pair(action: Dictionary) -> Array:
	var events: Array = []
	var c: Dictionary = bal.get("combat", {})
	var sb: Dictionary = bal.get("shield_and_boss", {})
	var re: Dictionary = bal.get("role_effects", {})
	var ult_cost: int = int(c.get("ult_cost_milli", 100000))

	var face: int = int(action.get("face", -1))
	var suit: String = String(action.get("suit", TWBattleMath.suit_of_face(face) if face >= 0 else "man"))
	var rank: int = int(action.get("rank", TWBattleMath.rank_of_face(face) if face >= 0 else 0))
	var from_ult: bool = bool(action.get("from_ult", false))
	var tnow_ms: int = int(action.get("tnow_ms", last_match_ms + 1000))

	if not from_ult:
		pairs_done += 1
		wave_pairs += 1
		var win_ms: int = int(c.get("combo_window_ms", 5000))
		if action.has("combo_continue"):
			combo = (combo + 1) if (bool(action["combo_continue"]) and combo > 0) else 1
		else:
			combo = (combo + 1) if (combo > 0 and (tnow_ms - last_match_ms) < win_ms) else 1
		last_match_ms = tnow_ms
		best_combo = maxi(best_combo, combo)
		events.append(E.make(E.COMBO_STEP, tick, {"combo": combo}))
		if combo >= _fever_threshold and fever_pairs == 0:
			fever_pairs = int(c.get("fever_pairs", 6)) + _fever_bonus_pairs
			events.append(E.make(E.FEVER_ON, tick, {"pairs": fever_pairs}))

		history.append({"suit": suit, "face": face, "rank": rank})
		if history.size() > 6:
			history.remove_at(0)

	var pat: Dictionary = {"id": "", "dmg_bonus_bp": 0, "energy_bonus_milli": 0}
	if not from_ult:
		if action.has("pattern_override"):
			var pid: String = String(action["pattern_override"])
			if pid != "":
				var pdef: Dictionary = bal.get("patterns", {}).get(pid, {})
				pat = {"id": pid, "dmg_bonus_bp": int(pdef.get("dmg_bonus_bp", 0)), "energy_bonus_milli": int(pdef.get("energy_bonus_milli", 0))}
		else:
			pat = TWBattleMath.pattern(history, bal)
		if String(pat.id) != "":
			events.append(E.make(E.PATTERN, tick, {"id": pat.id, "dmg_bonus_bp": pat.dmg_bonus_bp}))
			var pat_en: int = int(pat.energy_bonus_milli)
			if pat_en > 0:
				for i in squad.size():
					squad[i]["energy"] = mini(ult_cost, int(squad[i]["energy"]) + pat_en)

	var is_gold: bool = bool(action.get("gold", false))
	if not from_ult and _yue_gold_every_n > 0 and (pairs_done % _yue_gold_every_n) == 0:
		is_gold = true
	var gold_crit_bp: int = int(c.get("gold_crit_bp", 15000)) + _gold_crit_bonus_bp
	if not from_ult and yue_gold_pairs_left > 0:
		is_gold = true
		gold_crit_bp = int(c.get("yue_gold_crit_bp", 22000)) + _gold_crit_bonus_bp
		yue_gold_pairs_left -= 1

	var honor_res: bool = _leader_honor_resonant or (honor_resonant_ult_pairs > 0)
	var was_broken: bool = broken_hits > 0
	var pctx: Dictionary = {
		"honor_resonant": honor_res,
		"combo_step_bonus_bp": _combo_step_bonus_bp,
		"weak": boss_weak,
		"resist": boss_resist,
		"fever": fever_pairs > 0,
		"buff": buff_pairs > 0,
		"gold": is_gold,
		"gold_crit_bp": gold_crit_bp,
		"mark_bp": mark_bp if mark_pairs > 0 else BP,
		"pair_dmg_bonus_bp": _pair_dmg_bonus_bp,
		"broken": was_broken,
		"from_ult": from_ult,
	}
	var strike: Dictionary = TWBattleMath.pair_damage(squad, suit, maxi(1, combo), int(pat.dmg_bonus_bp), pctx, bal)
	var dmg: int = int(strike.dmg)
	boss_hp = maxi(0, boss_hp - dmg)
	if from_ult:
		ult_dmg_total += dmg
	else:
		pair_dmg_total += dmg
	if not from_ult:
		if buff_pairs > 0:
			buff_pairs -= 1
		if honor_resonant_ult_pairs > 0:
			honor_resonant_ult_pairs -= 1
		if mark_pairs > 0:
			mark_pairs -= 1
			if mark_pairs == 0:
				mark_bp = BP
		if was_broken:
			broken_hits = maxi(0, broken_hits - 1)
	events.append(E.make(E.PAIR_STRIKE, tick, {
		"suit": suit, "dmg": dmg, "combo": combo, "pattern": pat.id,
		"res": strike.resonant, "gold": is_gold, "from_ult": from_ult,
	}))

	# Active burn DoT (Zlata ult or T2 twist)
	if not from_ult and burn_pairs > 0 and boss_hp > 0:
		boss_hp = maxi(0, boss_hp - burn_dmg)
		ult_dmg_total += burn_dmg
		burn_pairs -= 1

	if from_ult:
		_check_victory(events)
		return events

	# Shield hit (pair)
	if boss_hp > 0:
		var sh_bonus: int = _pair_shield_bonus_bp + (_gold_pair_shield_bonus_bp if is_gold else 0)
		var sh_mult: int = 20000 if (_tsubame_every_n > 0 and (pairs_done % _tsubame_every_n) == 0) else BP
		var sh_dmg: int = TWBattleMath.shield_damage_milli(false, _has_brk, "", fever_pairs > 0, sh_bonus, sh_mult, bal)
		_apply_shield_damage(sh_dmg, events)

	# Energy gain (strictly capped at ult_cost; unaffected by outfit/bond per AT-B06)
	var low_idx: int = _lowest_energy_index()
	for i in squad.size():
		var h: Dictionary = squad[i]
		var prev_e: int = int(h.energy)
		var g: int = TWBattleMath.energy_gain_milli(h, suit, combo, fever_pairs > 0, honor_res, bal)
		g += _ally_energy_per_pair_milli
		if i == low_idx:
			g += _lowest_ally_energy_per_pair_milli
		var new_e: int = mini(ult_cost, prev_e + g)
		h["energy"] = new_e
		events.append(E.make(E.ENERGY, tick, {"hero": h.hero_id, "value": new_e}))
		if prev_e < ult_cost and new_e >= ult_cost:
			events.append(E.make(E.ULT_READY, tick, {"hero": h.hero_id, "hero_idx": i}))

	# Fever countdown
	if fever_pairs > 0:
		fever_pairs -= 1
		if fever_pairs == 0:
			events.append(E.make(E.FEVER_OFF, tick, {}))

	# Healer passive & Rin gold-pair heal
	var heal_tot: int = 0
	if _healer_count > 0:
		heal_tot += TWBattleMath.mul_bp(team_max_hp, int(re.get("heal_passive_bp", 30))) * _healer_count
	if is_gold and _rin_gold_heal_bp > 0:
		heal_tot += TWBattleMath.mul_bp(team_max_hp, _rin_gold_heal_bp)
	if heal_tot > 0 and team_hp < team_max_hp:
		var before_hp: int = team_hp
		team_hp = mini(team_max_hp, team_hp + heal_tot)
		events.append(E.make(E.HEAL, tick, {"amount": team_hp - before_hp, "team_hp": team_hp}))

	if _check_victory(events):
		return events

	# Boss clock
	boss_clock += 1
	var eff_cadence: int = maxi(
		int(sb.get("boss_cadence_min", 3)),
		boss_cadence - int(sb.get("boss_cadence_enrage_step", 2)) * wave_idx
	)
	if boss_clock >= eff_cadence and boss_hp > 0:
		boss_clock = 0
		_do_boss_cast(events)

	# Auto wave transition if pair budget of current wave reached
	var cur_wave_budget: int = int(waves[wave_idx]) if wave_idx < waves.size() else 36
	if not over and wave_pairs >= cur_wave_budget and bool(stage_cfg.get("auto_wave_advance", false)):
		events.append_array(_on_wave_clear({"tnow_ms": tnow_ms}))

	return events


func _on_ult_aim(action: Dictionary) -> Array:
	var hidx: int = int(action.get("hero_idx", -1))
	if hidx < 0 or hidx >= squad.size():
		return []
	var ult_cost: int = int(bal.get("combat", {}).get("ult_cost_milli", 100000))
	if int(squad[hidx].energy) < ult_cost:
		return []
	state = ST_ULT_AIM
	pending_ult_aim_idx = hidx
	return [E.make(E.ULT_AIM, tick, {
		"hero_idx": hidx,
		"hero": squad[hidx].hero_id,
		"aim_kind": squad[hidx].aim_kind,
		"timeout_ms": int(bal.get("combat", {}).get("ult_aim_timeout_ms", 2000)),
	})]


func _on_ult_cast(action: Dictionary) -> Array:
	var hidx: int = int(action.get("hero_idx", pending_ult_aim_idx))
	if hidx < 0 or hidx >= squad.size():
		return []
	var c: Dictionary = bal.get("combat", {})
	var sb: Dictionary = bal.get("shield_and_boss", {})
	var re: Dictionary = bal.get("role_effects", {})
	var ult_cost: int = int(c.get("ult_cost_milli", 100000))
	var h: Dictionary = squad[hidx]
	if int(h.energy) < ult_cost:
		return []

	var events: Array = []
	state = ST_ULT_CINEMATIC
	pending_ult_aim_idx = -1
	h["energy"] = 0
	ults_used += 1

	var hid: String = String(h.hero_id)
	var hmeta: Dictionary = heroes_data.get(hid, {})
	var rider: Dictionary = hmeta.get("ult", {}).get("rider", {})
	var use_riders: bool = bool(stage_cfg.get("enable_hero_riders", true))
	var is_vow: bool = String(action.get("variant", "base")) == "vow" or String(action.get("ult_id", h.ult_id)).ends_with("_vow")

	var was_broken: bool = broken_hits > 0
	var dmg: int = 0
	if not is_vow:
		var uctx: Dictionary = {
			"broken": was_broken,
			"atk_broken_bonus": use_riders and rider.has("broken_bonus_bp"),
			"team_ult_dmg_bonus_bp": _team_ult_dmg_bonus_bp,
			"weak": boss_weak,
			"resist": boss_resist,
		}
		dmg = TWBattleMath.ult_damage(h, uctx, bal)
		boss_hp = maxi(0, boss_hp - dmg)
		ult_dmg_total += dmg
		if was_broken:
			broken_hits = maxi(0, broken_hits - 1)

	var board_eff: Array = []
	var battle_eff: Dictionary = {"dmg": dmg}

	if is_vow:
		# VOW ult: normalized 15% heal + 2 casts seal immunity, no damage/impact (BU §4.2)
		var vh: int = TWBattleMath.mul_bp(team_max_hp, int(re.get("vow_heal_ult_bp", 1500)))
		var b_hp: int = team_hp
		team_hp = mini(team_max_hp, team_hp + vh)
		seal_immunity_casts = maxi(seal_immunity_casts, 2)
		battle_eff["heal"] = team_hp - b_hp
		battle_eff["seal_immunity_casts"] = 2
		if team_hp > b_hp:
			events.append(E.make(E.HEAL, tick, {"amount": team_hp - b_hp, "team_hp": team_hp}))
	else:
		# Shield damage from ult
		if boss_hp > 0:
			if use_riders and rider.has("shield_shred_bp"):
				var shred: int = TWBattleMath.mul_bp(shield_max_milli, int(rider.shield_shred_bp))
				_apply_shield_damage(shred, events)
			else:
				var sh_u: int = TWBattleMath.shield_damage_milli(true, _has_brk, String(h.role), fever_pairs > 0, 0, BP, bal)
				_apply_shield_damage(sh_u, events)

		# Role / hero riders
		var role_id: String = String(h.role)
		if use_riders and not rider.is_empty():
			if rider.has("team_buff_pairs"):
				buff_pairs = maxi(buff_pairs, int(rider.team_buff_pairs))
			if rider.has("honor_resonant_pairs"):
				honor_resonant_ult_pairs = maxi(honor_resonant_ult_pairs, int(rider.honor_resonant_pairs))
			if rider.has("ally_energy_milli"):
				var ae: int = int(rider.ally_energy_milli)
				for j in squad.size():
					if j != hidx:
						squad[j]["energy"] = mini(ult_cost, int(squad[j]["energy"]) + ae)
			if rider.has("lowest_ally_energy_milli"):
				var li: int = _lowest_energy_index(hidx)
				if li >= 0:
					squad[li]["energy"] = mini(ult_cost, int(squad[li]["energy"]) + int(rider.lowest_ally_energy_milli))
			if rider.has("heal_bp"):
				var ha: int = TWBattleMath.mul_bp(team_max_hp, int(rider.heal_bp))
				var before_hp: int = team_hp
				team_hp = mini(team_max_hp, team_hp + ha)
				battle_eff["heal"] = team_hp - before_hp
				if team_hp > before_hp:
					events.append(E.make(E.HEAL, tick, {"amount": team_hp - before_hp, "team_hp": team_hp}))
			if rider.has("barrier_bp"):
				guard_hp = maxi(guard_hp, TWBattleMath.mul_bp(team_max_hp, int(rider.barrier_bp)))
				guard_casts_left = maxi(guard_casts_left, int(rider.get("barrier_casts", 2)))
				battle_eff["barrier"] = guard_hp
			if rider.has("seal_immunity_casts"):
				seal_immunity_casts = maxi(seal_immunity_casts, int(rider.seal_immunity_casts))
			if rider.has("stun_casts"):
				stun_casts = maxi(stun_casts, int(rider.stun_casts))
			if rider.has("combo_bonus"):
				combo += int(rider.combo_bonus)
				best_combo = maxi(best_combo, combo)
			if rider.has("next_gold_pairs"):
				yue_gold_pairs_left = maxi(yue_gold_pairs_left, int(rider.next_gold_pairs))
			if rider.has("ignite_fever_pairs"):
				if fever_pairs == 0:
					fever_pairs = int(rider.ignite_fever_pairs) + _fever_bonus_pairs
					events.append(E.make(E.FEVER_ON, tick, {"pairs": fever_pairs}))
				fever_pairs += int(rider.get("extend_fever_pairs", 0))
			if rider.has("burn_atk_bp"):
				burn_dmg = TWBattleMath.mul_bp(int(h.atk), int(rider.burn_atk_bp))
				burn_pairs = int(rider.get("burn_pairs", 6))
			if rider.has("add_tray_joker"):
				tray_jokers += int(rider.add_tray_joker)
				board_eff.append("add_tray_joker")
			if rider.has("add_tray_ward"):
				tray_wards += int(rider.add_tray_ward)
				board_eff.append("add_tray_ward")
			if bool(rider.get("cleanse_all_board", false)):
				board_eff.append("cleanse_all")
			if bool(rider.get("reveal_row", false)):
				board_eff.append("reveal_row")
			if bool(rider.get("melt_line", false)):
				board_eff.append("melt_line")
			if int(rider.get("remove_ult_pairs", 0)) > 0:
				board_eff.append("remove_pairs:%d" % int(rider.remove_ult_pairs))
		else:
			# Generic role fallback (mirrors battle_sim.py directly)
			if role_id == "SUP":
				buff_pairs = int(c.get("support_buff_pairs", 8))
				var sup_e: int = int(c.get("sup_ult_ally_energy_milli", 20000))
				for j in squad.size():
					squad[j]["energy"] = mini(ult_cost, int(squad[j]["energy"]) + sup_e)
			elif role_id == "HEAL":
				var ha2: int = TWBattleMath.mul_bp(team_max_hp, int(re.get("heal_ult_bp", 2500)))
				var before2: int = team_hp
				team_hp = mini(team_max_hp, team_hp + ha2)
				if team_hp > before2:
					events.append(E.make(E.HEAL, tick, {"amount": team_hp - before2, "team_hp": team_hp}))
			elif role_id == "GRD":
				guard_hp = TWBattleMath.mul_bp(team_max_hp, int(re.get("guard_ult_bp", 2000)))
				guard_casts_left = 2
			elif role_id == "BRK":
				stun_casts = maxi(stun_casts, 1)

		# Apply equal-value twist T1..T8 if equipped
		_apply_twist(h, hidx, events, battle_eff)

	# Note: `show_mode` is echoed to shell for playback policy, NEVER affects core state or state_hash (AT-U10).
	events.append(E.make(E.ULT_CAST, tick, {
		"ult_id": String(action.get("ult_id", h.ult_id)),
		"hero": hid,
		"hero_idx": hidx,
		"variant": String(action.get("variant", "vow" if is_vow else "base")),
		"board_effect": board_eff,
		"battle_effect": battle_eff,
		"mode": String(action.get("show_mode", "full")),
	}))

	state = ST_PLAYING
	_check_victory(events)
	return events


func _apply_twist(h: Dictionary, hidx: int, events: Array, battle_eff: Dictionary) -> void:
	var tid: String = String(h.get("twist_id", ""))
	if tid == "":
		return
	var twists: Dictionary = bal.get("twists", {})
	if not twists.has(tid) or boss_hp <= 0:
		return
	var tier: String = String(h.get("twist_tier", "minor"))
	var tw: Dictionary = twists[tid].get(tier, {})
	if tw.is_empty():
		return
	var c: Dictionary = bal.get("combat", {})
	var ult_cost: int = int(c.get("ult_cost_milli", 100000))
	battle_eff["twist"] = tid

	match tid:
		"T1":
			var ex_n: int = int(tw.get("extra_ult_pairs", 1))
			var ex_raw: int = 0
			for x in squad:
				ex_raw += TWBattleMath.mul_bp(int(x.atk), int(c.get("honor_pair_bp", 7000)))
			var ex_dmg: int = TWBattleMath.mul_bp(TWBattleMath.mul_bp(ex_raw, int(c.get("pair_norm_bp", 3500))), int(c.get("ult_pair_dmg_bp", 5000))) * ex_n
			ex_dmg += TWBattleMath.mul_bp(int(h.atk), int(tw.get("bonus_atk_bp", 0)))
			boss_hp = maxi(0, boss_hp - ex_dmg)
			ult_dmg_total += ex_dmg
		"T2":
			burn_dmg = TWBattleMath.mul_bp(int(h.atk), int(tw.get("atk_bp", 1500)))
			burn_pairs = int(tw.get("pairs", 3))
		"T3":
			guard_hp += TWBattleMath.mul_bp(team_max_hp, int(tw.get("barrier_bp", 800)))
			guard_casts_left = maxi(guard_casts_left, 1)
			var bd3: int = TWBattleMath.mul_bp(int(h.atk), int(tw.get("bonus_atk_bp", 0)))
			boss_hp = maxi(0, boss_hp - bd3)
			ult_dmg_total += bd3
		"T4":
			var ae4: int = int(tw.get("ally_energy_milli", 8000))
			for j in squad.size():
				if j != hidx:
					squad[j]["energy"] = mini(ult_cost, int(squad[j]["energy"]) + ae4)
			var bd4: int = TWBattleMath.mul_bp(int(h.atk), int(tw.get("bonus_atk_bp", 0)))
			boss_hp = maxi(0, boss_hp - bd4)
			ult_dmg_total += bd4
		"T5":
			var h5: int = TWBattleMath.mul_bp(team_max_hp, int(tw.get("heal_bp", 600)))
			team_hp = mini(team_max_hp, team_hp + h5)
			var bd5: int = TWBattleMath.mul_bp(int(h.atk), int(tw.get("bonus_atk_bp", 0)))
			boss_hp = maxi(0, boss_hp - bd5)
			ult_dmg_total += bd5
		"T6":
			var sh6: int = TWBattleMath.mul_bp(shield_max_milli, int(tw.get("shield_pct_bp", 1500)))
			_apply_shield_damage(sh6, events)
			var bd6: int = TWBattleMath.mul_bp(int(h.atk), int(tw.get("bonus_atk_bp", 0)))
			boss_hp = maxi(0, boss_hp - bd6)
			ult_dmg_total += bd6
		"T7":
			fever_pairs += int(tw.get("fever_pairs", 1))
			var bd7: int = TWBattleMath.mul_bp(int(h.atk), int(tw.get("bonus_atk_bp", 0)))
			boss_hp = maxi(0, boss_hp - bd7)
			ult_dmg_total += bd7
		"T8":
			mark_bp = int(tw.get("dmg_mult_bp", 11000))
			mark_pairs = int(tw.get("pairs", 3))


func _apply_shield_damage(amount_milli: int, events: Array) -> void:
	var sb: Dictionary = bal.get("shield_and_boss", {})
	shield_milli -= maxi(0, amount_milli)
	events.append(E.make(E.SHIELD_HIT, tick, {"amount": amount_milli, "shield_left": maxi(0, shield_milli)}))
	if shield_milli <= 0:
		broken_hits = int(sb.get("break_hits", 3))
		stun_casts = maxi(stun_casts, int(sb.get("break_stun", 1)))
		shield_milli = shield_max_milli
		events.append(E.make(E.SHIELD_BREAK, tick, {"broken_hits": broken_hits, "stun_casts": stun_casts}))


func _do_boss_cast(events: Array) -> void:
	state = ST_CAST
	boss_casts += 1
	if skip_boss_casts > 0:
		skip_boss_casts -= 1
		events.append(E.make(E.BOSS_CAST, tick, {"mechanic": "skipped", "dmg": 0, "tiles": []}))
		state = ST_PLAYING
		return
	if stun_casts > 0:
		stun_casts -= 1
		events.append(E.make(E.BOSS_CAST, tick, {"mechanic": "stunned", "dmg": 0, "tiles": []}))
		state = ST_PLAYING
		return

	var mech: String = String(boss_mechanic_pool[(boss_casts - 1) % boss_mechanic_pool.size()])
	if mech == "seal" and seal_immunity_casts > 0:
		seal_immunity_casts -= 1
		mech = "seal_blocked"
	elif mech == "seal" and _rin_leader_cleanse > 0:
		mech = "seal_cleansed"

	var raw_d: int = TWBattleMath.boss_cast_damage(ref_team_hp, wave_idx, boss_casts, boss_atk_bp, bal)
	var d: int = raw_d
	if guard_hp > 0:
		var ab: int = mini(guard_hp, d)
		guard_hp -= ab
		d -= ab
		if guard_casts_left > 0:
			guard_casts_left -= 1
			if guard_casts_left == 0:
				guard_hp = 0
	team_hp = maxi(0, team_hp - d)
	events.append(E.make(E.BOSS_CAST, tick, {"mechanic": mech, "dmg": d, "raw_dmg": raw_d, "tiles": []}))
	if d > 0:
		events.append(E.make(E.TEAM_HIT, tick, {"dmg": d, "team_hp": team_hp, "source": "boss_cast"}))
	state = ST_PLAYING
	if team_hp <= 0:
		_finish_defeat("team_hp_zero", events)


func _on_overflow(_action: Dictionary) -> Array:
	var events: Array = []
	var sb: Dictionary = bal.get("shield_and_boss", {})
	combo = 0
	if tray_wards > 0:
		tray_wards -= 1
		events.append(E.make(E.TRAY_OVERFLOW, tick, {"dmg": 0, "ward_absorbed": true}))
		return events
	var d: int = TWBattleMath.mul_bp(team_max_hp, int(sb.get("overflow_dmg_bp", 1500)))
	team_hp = maxi(0, team_hp - d)
	events.append(E.make(E.TRAY_OVERFLOW, tick, {"dmg": d, "ward_absorbed": false}))
	events.append(E.make(E.TEAM_HIT, tick, {"dmg": d, "team_hp": team_hp, "source": "tray_overflow"}))
	if team_hp <= 0:
		_finish_defeat("team_hp_zero", events)
	return events


func _on_wave_clear(_action: Dictionary) -> Array:
	var events: Array = []
	var c: Dictionary = bal.get("combat", {})
	var ult_cost: int = int(c.get("ult_cost_milli", 100000))
	state = ST_WAVE_CLEAR

	# Board clear bonus: -12% boss max HP (once per wave) + 30 energy to each heroine (BU §1.5.4)
	if wave_idx < wave_cleared_flags.size() and not bool(wave_cleared_flags[wave_idx]):
		wave_cleared_flags[wave_idx] = true
		var clear_dmg: int = TWBattleMath.mul_bp(boss_max_hp, int(c.get("board_clear_boss_hp_bp", 1200)))
		boss_hp = maxi(0, boss_hp - clear_dmg)
		pair_dmg_total += clear_dmg
		var clear_en: int = int(c.get("board_clear_energy_milli", 30000))
		for i in squad.size():
			squad[i]["energy"] = mini(ult_cost, int(squad[i]["energy"]) + clear_en)
		events.append(E.make(E.WAVE_CLEAR, tick, {"wave": wave_idx, "bonus_dmg": clear_dmg, "energy_gain": clear_en}))

	if _check_victory(events):
		return events

	if wave_idx + 1 >= waves.size():
		_finish_defeat("boss_survived", events)
		return events

	wave_idx += 1
	wave_pairs = 0
	combo = 0
	state = ST_PLAYING
	events.append(E.make(E.ENRAGE, tick, {
		"wave": wave_idx,
		"boss_atk_mult_bp": BP + int(bal.get("shield_and_boss", {}).get("enrage_per_wave_bp", 8000)) * wave_idx,
	}))
	return events


func _check_victory(events: Array) -> bool:
	if boss_hp > 0:
		return false
	over = true
	won = true
	state = ST_END
	events.append(E.make(E.VICTORY, tick, {
		"stars": stars(),
		"pairs": pairs_done,
		"hp_left": team_hp,
		"hp_left_bp": (team_hp * BP) / maxi(1, team_max_hp),
	}))
	return true


func _finish_defeat(reason: String, events: Array) -> void:
	over = true
	won = false
	defeat_reason = reason
	state = ST_END
	events.append(E.make(E.DEFEAT, tick, {"reason": reason, "boss_hp_left": boss_hp}))


func _lowest_energy_index(exclude_idx: int = -1) -> int:
	var best_i: int = -1
	var best_e: int = 2147483647
	for i in squad.size():
		if i == exclude_idx:
			continue
		var e: int = int(squad[i].energy)
		if e < best_e:
			best_e = e
			best_i = i
	return best_i


func stars() -> int:
	if not won:
		return 0
	if assist_used:
		return 1
	var sb: Dictionary = bal.get("shield_and_boss", {})
	var min_hp_bp: int = int(sb.get("star2_min_hp_bp", 5000))
	var max_p3: int = int(sb.get("star3_max_pairs", 32))
	var hp_ok: bool = (team_hp * BP) >= (team_max_hp * min_hp_bp)
	if not hp_ok:
		return 1
	return 3 if pairs_done <= max_p3 else 2


func ult_ready_indices() -> Array:
	var ult_cost: int = int(bal.get("combat", {}).get("ult_cost_milli", 100000))
	var out: Array = []
	for i in squad.size():
		if int(squad[i].energy) >= ult_cost:
			out.append(i)
	return out


func replay(actions: Array, show_mode_override: String = "") -> Array:
	var all_events: Array = []
	if state == ST_INIT:
		all_events.append_array(start())
	for a in actions:
		var act: Dictionary = a.duplicate(true)
		if show_mode_override != "" and String(act.get("type", "")) == "ULT_CAST":
			act["show_mode"] = show_mode_override
		all_events.append_array(step(act))
	return all_events


func state_hash() -> int:
	var h: int = TWRng.FNV_BASIS
	h = TWRng.fnv(h, tick)
	h = TWRng.fnv(h, 1 if over else 0)
	h = TWRng.fnv(h, 1 if won else 0)
	h = TWRng.fnv(h, stars())
	h = TWRng.fnv(h, wave_idx)
	h = TWRng.fnv(h, wave_pairs)
	h = TWRng.fnv(h, boss_hp)
	h = TWRng.fnv(h, boss_max_hp)
	h = TWRng.fnv(h, shield_milli)
	h = TWRng.fnv(h, broken_hits)
	h = TWRng.fnv(h, stun_casts)
	h = TWRng.fnv(h, boss_clock)
	h = TWRng.fnv(h, boss_casts)
	h = TWRng.fnv(h, team_hp)
	h = TWRng.fnv(h, team_max_hp)
	h = TWRng.fnv(h, guard_hp)
	h = TWRng.fnv(h, guard_casts_left)
	h = TWRng.fnv(h, seal_immunity_casts)
	h = TWRng.fnv(h, tray_wards)
	h = TWRng.fnv(h, tray_jokers)
	h = TWRng.fnv(h, combo)
	h = TWRng.fnv(h, best_combo)
	h = TWRng.fnv(h, fever_pairs)
	h = TWRng.fnv(h, buff_pairs)
	h = TWRng.fnv(h, honor_resonant_ult_pairs)
	h = TWRng.fnv(h, yue_gold_pairs_left)
	h = TWRng.fnv(h, burn_dmg)
	h = TWRng.fnv(h, burn_pairs)
	h = TWRng.fnv(h, mark_bp)
	h = TWRng.fnv(h, mark_pairs)
	h = TWRng.fnv(h, pairs_done)
	h = TWRng.fnv(h, ults_used)
	h = TWRng.fnv(h, pair_dmg_total)
	h = TWRng.fnv(h, ult_dmg_total)
	h = TWRng.fnv(h, pending_ult_aim_idx)
	h = TWRng.fnv(h, int(rng.state & 0xFFFFFFFF))
	for m in squad:
		h = TWRng.fnv(h, int(m.atk))
		h = TWRng.fnv(h, int(m.hp))
		h = TWRng.fnv(h, int(m.energy))
	return h


func snapshot() -> Dictionary:
	var sq_copy: Array = []
	for m in squad:
		sq_copy.append(m.duplicate(true))
	return {
		"seed_val": seed_val,
		"rng_state": rng.state,
		"state": state,
		"prev_state": prev_state,
		"tick": tick,
		"over": over,
		"won": won,
		"defeat_reason": defeat_reason,
		"squad": sq_copy,
		"team_max_hp": team_max_hp,
		"team_hp": team_hp,
		"guard_hp": guard_hp,
		"guard_casts_left": guard_casts_left,
		"seal_immunity_casts": seal_immunity_casts,
		"tray_wards": tray_wards,
		"tray_jokers": tray_jokers,
		"boss_max_hp": boss_max_hp,
		"boss_hp": boss_hp,
		"ref_team_hp": ref_team_hp,
		"boss_atk_bp": boss_atk_bp,
		"boss_cadence": boss_cadence,
		"boss_clock": boss_clock,
		"boss_casts": boss_casts,
		"skip_boss_casts": skip_boss_casts,
		"shield_max_milli": shield_max_milli,
		"shield_milli": shield_milli,
		"broken_hits": broken_hits,
		"stun_casts": stun_casts,
		"wave_idx": wave_idx,
		"wave_pairs": wave_pairs,
		"wave_cleared_flags": wave_cleared_flags.duplicate(),
		"combo": combo,
		"best_combo": best_combo,
		"last_match_ms": last_match_ms,
		"fever_pairs": fever_pairs,
		"buff_pairs": buff_pairs,
		"honor_resonant_ult_pairs": honor_resonant_ult_pairs,
		"yue_gold_pairs_left": yue_gold_pairs_left,
		"burn_dmg": burn_dmg,
		"burn_pairs": burn_pairs,
		"mark_bp": mark_bp,
		"mark_pairs": mark_pairs,
		"pending_ult_aim_idx": pending_ult_aim_idx,
		"pairs_done": pairs_done,
		"ults_used": ults_used,
		"pair_dmg_total": pair_dmg_total,
		"ult_dmg_total": ult_dmg_total,
		"history": history.duplicate(true),
	}


func restore(snap: Dictionary) -> void:
	seed_val = int(snap.seed_val)
	rng.state = int(snap.rng_state)
	state = String(snap.state)
	prev_state = String(snap.prev_state)
	tick = int(snap.tick)
	over = bool(snap.over)
	won = bool(snap.won)
	defeat_reason = String(snap.defeat_reason)
	squad = []
	for m in snap.squad:
		squad.append(m.duplicate(true))
	team_max_hp = int(snap.team_max_hp)
	team_hp = int(snap.team_hp)
	guard_hp = int(snap.guard_hp)
	guard_casts_left = int(snap.guard_casts_left)
	seal_immunity_casts = int(snap.seal_immunity_casts)
	tray_wards = int(snap.tray_wards)
	tray_jokers = int(snap.tray_jokers)
	boss_max_hp = int(snap.boss_max_hp)
	boss_hp = int(snap.boss_hp)
	ref_team_hp = int(snap.ref_team_hp)
	boss_atk_bp = int(snap.boss_atk_bp)
	boss_cadence = int(snap.boss_cadence)
	boss_clock = int(snap.boss_clock)
	boss_casts = int(snap.boss_casts)
	skip_boss_casts = int(snap.skip_boss_casts)
	shield_max_milli = int(snap.shield_max_milli)
	shield_milli = int(snap.shield_milli)
	broken_hits = int(snap.broken_hits)
	stun_casts = int(snap.stun_casts)
	wave_idx = int(snap.wave_idx)
	wave_pairs = int(snap.wave_pairs)
	wave_cleared_flags = snap.wave_cleared_flags.duplicate()
	combo = int(snap.combo)
	best_combo = int(snap.best_combo)
	last_match_ms = int(snap.last_match_ms)
	fever_pairs = int(snap.fever_pairs)
	buff_pairs = int(snap.buff_pairs)
	honor_resonant_ult_pairs = int(snap.honor_resonant_ult_pairs)
	yue_gold_pairs_left = int(snap.yue_gold_pairs_left)
	burn_dmg = int(snap.burn_dmg)
	burn_pairs = int(snap.burn_pairs)
	mark_bp = int(snap.mark_bp)
	mark_pairs = int(snap.mark_pairs)
	pending_ult_aim_idx = int(snap.pending_ult_aim_idx)
	pairs_done = int(snap.pairs_done)
	ults_used = int(snap.ults_used)
	pair_dmg_total = int(snap.pair_dmg_total)
	ult_dmg_total = int(snap.ult_dmg_total)
	history = snap.history.duplicate(true)
	_compile_passives_and_leader()
