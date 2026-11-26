class_name V10AdventureBattle
extends RefCounted

# V10AdventureBattle — pure combat state of one monster fight (no nodes, no timers; fully unit-testable).
# The screen feeds it events from the TrayBoard: on_pair() for every matched pair, on_move() for every tile
# put into the tray, on_overflow() when the tray overflows, use_ult() when the heroine ultimate is fired.

var stage: = 0
var hero: = "mc"
var m: = {}
var mon_hp: = 0
var mon_max: = 0
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
var over: = false
var won: = false


func _init(stage_idx: int = 0, hero_id: String = "mc") -> void:
	stage = clampi(stage_idx, 0, V10AdventureData.count() - 1)
	hero = hero_id
	m = V10AdventureData.monster_at(stage)
	mon_max = int(m.hp)
	mon_hp = mon_max
	moves_left = int(m.cadence)


func ult_ready() -> bool:
	return not over and ult >= V10AdventureData.ULT_MAX


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


func on_pair(combo: int, gold: bool) -> Dictionary:
	if over:
		return {"damage": 0, "crit": false, "killed": false}
	var r: Dictionary = V10AdventureData.calc_pair_damage(combo, gold, hero)
	mon_hp -= int(r.damage)
	dmg_total += int(r.damage)
	pairs += 1
	best_combo = maxi(best_combo, combo)
	if bool(r.crit):
		crits += 1
	ult = mini(V10AdventureData.ULT_MAX, ult + int(r.ult_gain))
	hero_hp = mini(V10AdventureData.HERO_MAX_HP, hero_hp + int(r.heal))
	_check_end()
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
	_check_end()
	return {"attack": true, "damage": d, "stunned": false, "lost": over and not won}


func on_overflow() -> Dictionary:
	if over:
		return {}
	var d: = V10AdventureData.calc_monster_attack(stage, true)
	hero_hp -= d
	hits_taken += 1
	moves_left = int(m.cadence)
	_check_end()
	return {"attack": true, "damage": d, "overflow": true, "lost": over and not won}


func use_ult() -> Dictionary:
	if not ult_ready():
		return {}
	var r: Dictionary = V10AdventureData.calc_ult_damage(stage, hero)
	ult = 0
	ults_used += 1
	mon_hp -= int(r.damage)
	dmg_total += int(r.damage)
	stun = int(r.stun_turns)
	hero_hp = mini(V10AdventureData.HERO_MAX_HP, hero_hp + int(r.heal))
	_check_end()
	r["killed"] = won
	return r


func hp_frac() -> float:
	return clampf(float(mon_hp) / float(maxi(1, mon_max)), 0.0, 1.0)


func hero_frac() -> float:
	return clampf(float(hero_hp) / float(V10AdventureData.HERO_MAX_HP), 0.0, 1.0)


func ult_frac() -> float:
	return clampf(float(ult) / float(V10AdventureData.ULT_MAX), 0.0, 1.0)


func attack_frac() -> float:
	return clampf(1.0 - float(moves_left) / float(maxi(1, int(m.cadence))), 0.0, 1.0)
