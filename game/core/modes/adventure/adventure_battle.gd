class_name V10AdventureBattle
extends RefCounted

# V10AdventureBattle — pure combat state of one monster fight (no nodes, no timers; fully unit-testable).
# The screen feeds it events from the tray_board: on_pair() for every matched pair, on_move() for every tile
# put into the tray, on_overflow() when the tray overflows, use_ult() when the heroine ultimate is fired.
#
# 0.12: the squad (lead + 2 supports) adds passive bonuses and a synergy (mods), and every boss carries a
# «Щит стойкости»: pairs and the ult chip it away; at 0 it breaks (ПРОБИТИЕ): the boss is stunned for a turn and
# takes ×2 damage from the next BREAK_TURNS hits (a hit = a matched pair or an ult), then the shield refills.

var stage: = 0
var hero: = "mc"
var squad: Array = []
var mods: Dictionary = {}
var synergy: Dictionary = {}
var _aff: Dictionary = {}
var m: = {}
var mon_hp: = 0
var mon_max: = 0
var shield: = 0
var shield_max: = 0
var broken_turns: = 0
var breaks: = 0
var hero_hp: = V10AdventureData.HERO_MAX_HP
var ult: = 0
var moves_left: = 6
var stun: = 0
var dmg_total: = 0
var pairs: = 0
var crits: = 0
var best_combo: = 0
var ults_used: = 0
var hits_taken: = 0
var debuffs_applied: = 0
var debuffs_cleansed: = 0
var over: = false
var won: = false


# squad_ids: [lead, support1, support2] or [] (no squad bonuses, the classic deterministic math);
# aff: optional V10AffCurve bonuses of the lead ({atk_bonus, crit_bonus, ult_haste}).
func _init(stage_idx: int = 0, hero_id: String = "mc", squad_ids: Array = [], aff: Dictionary = {}) -> void:
	stage = clampi(stage_idx, 0, V10AdventureData.count() - 1)
	hero = hero_id
	m = V10AdventureData.monster_at(stage)
	mon_max = int(m.hp)
	mon_hp = mon_max
	shield_max = int(m.get("shield_max", 80))
	shield = shield_max
	moves_left = int(m.cadence)
	set_squad(squad_ids, aff)


# (Re)computes the squad bonuses; a fight in progress keeps its HP, shield and ult.
func set_squad(squad_ids: Array, aff: Dictionary = {}) -> void:
	squad = []
	synergy = {}
	mods = {}
	if not squad_ids.is_empty():
		squad = V10AdventureData.normalize_squad(squad_ids, hero, false)
		synergy = V10AdventureData.active_synergy(squad)
		mods = V10AdventureData.squad_mods(squad, aff)
	elif not aff.is_empty():
		mods = V10AdventureData.squad_mods([hero], aff)
	_aff = aff


func ult_ready() -> bool:
	return not over and ult >= V10AdventureData.ULT_MAX


func is_broken() -> bool:
	return broken_turns > 0


func dmg_mult() -> int:
	return V10AdventureData.BREAK_MULT if broken_turns > 0 else 1


func _check_end() -> void:
	if over:
		return
	if mon_hp <= 0:
		mon_hp = 0
		over = true
		won = true
	elif hero_hp <= 0:
		hero_hp = 0
		over = true
		won = false


# Applies shield damage (or consumes one broken turn). Returns true when this hit broke the shield.
func _hit_shield(amount: int, was_broken: bool) -> bool:
	if was_broken:
		broken_turns = maxi(0, broken_turns - 1)
		return false
	shield = maxi(0, shield - maxi(0, amount))
	if shield > 0:
		return false
	breaks += 1
	broken_turns = V10AdventureData.BREAK_TURNS
	shield = shield_max
	stun = maxi(stun, V10AdventureData.BREAK_STUN)
	return true


func on_pair(combo: int, gold: bool) -> Dictionary:
	if over:
		return {"damage": 0, "crit": false, "killed": false, "broke": false, "doubled": false, "shield": shield}
	var r: Dictionary = V10AdventureData.calc_pair_damage(combo, gold, hero, mods)
	var doubled: = broken_turns > 0
	var dmg: int = int(r.damage) * dmg_mult()
	r["damage"] = dmg
	mon_hp -= dmg
	dmg_total += dmg
	pairs += 1
	best_combo = maxi(best_combo, combo)
	if bool(r.crit):
		crits += 1
	ult = mini(V10AdventureData.ULT_MAX, ult + int(r.ult_gain))
	hero_hp = mini(V10AdventureData.HERO_MAX_HP, hero_hp + int(r.heal))
	r["doubled"] = doubled
	r["broke"] = false
	_check_end()
	if not over:
		r["broke"] = _hit_shield(int(r.shield), doubled)
	r["shield_left"] = shield
	r["killed"] = won
	return r


# a tile went into the tray (one player move). Returns {} or {"attack": true, "damage": n, "stunned": bool}
func on_move() -> Dictionary:
	if over:
		return {}
	moves_left -= 1
	if moves_left > 0:
		return {}
	moves_left = int(m.cadence)
	if stun > 0:
		stun -= 1
		return {"attack": false, "stunned": true}
	var d: = V10AdventureData.calc_monster_attack(stage, false)
	hero_hp -= d
	hits_taken += 1
	debuffs_applied += 1
	_check_end()
	return {
		"attack": true,
		"damage": d,
		"stunned": false,
		"debuff": String(m.get("debuff", "fog")),
		"debuff_name": String(m.get("debuff_name", "")),
		"debuff_count": int(m.get("debuff_count", 2)),
		"lost": over and not won,
	}


func on_overflow() -> Dictionary:
	if over:
		return {}
	var d: = V10AdventureData.calc_monster_attack(stage, true)
	hero_hp -= d
	hits_taken += 1
	debuffs_applied += 1
	moves_left = int(m.cadence)
	_check_end()
	return {
		"attack": true,
		"damage": d,
		"overflow": true,
		"debuff": String(m.get("debuff", "fog")),
		"debuff_name": String(m.get("debuff_name", "")),
		"debuff_count": int(m.get("debuff_count", 2)),
		"lost": over and not won,
	}


func use_ult() -> Dictionary:
	if not ult_ready():
		return {}
	var r: Dictionary = V10AdventureData.calc_ult_damage(stage, hero, mods)
	ult = 0
	ults_used += 1
	debuffs_cleansed += 1
	var doubled: = broken_turns > 0
	var total_dmg: int = int(r.damage) * dmg_mult()
	r["damage"] = total_dmg
	mon_hp -= total_dmg
	dmg_total += total_dmg
	stun = int(r.stun_turns)
	hero_hp = mini(V10AdventureData.HERO_MAX_HP, hero_hp + int(r.heal))
	_check_end()
	r["doubled"] = doubled
	r["broke"] = false
	if not over:
		r["broke"] = _hit_shield(int(r.shield), doubled)
		if bool(r.broke):
			stun = maxi(stun, V10AdventureData.BREAK_STUN)
	var h1: int = int(round(float(total_dmg) * 0.28))
	var h2: int = int(round(float(total_dmg) * 0.33))
	var h3: int = maxi(1, total_dmg - h1 - h2)
	r["hits"] = [h1, h2, h3]
	r["cleansed"] = true
	r["killed"] = won
	r["shield_left"] = shield
	return r


func hp_frac() -> float:
	return clampf(float(mon_hp) / float(maxi(1, mon_max)), 0.0, 1.0)


func shield_frac() -> float:
	return clampf(float(shield) / float(maxi(1, shield_max)), 0.0, 1.0)


func hero_frac() -> float:
	return clampf(float(hero_hp) / float(V10AdventureData.HERO_MAX_HP), 0.0, 1.0)


func ult_frac() -> float:
	return clampf(float(ult) / float(V10AdventureData.ULT_MAX), 0.0, 1.0)


func attack_frac() -> float:
	return clampf(1.0 - float(moves_left) / float(maxi(1, int(m.cadence))), 0.0, 1.0)
