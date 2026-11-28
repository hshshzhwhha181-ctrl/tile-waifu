class_name TWBattleEvents
extends RefCounted

# TWBattleEvents (P74 / BATTLE_ULT_SPEC §1.10.1, Appendix R T10):
# Pure event vocabulary and constructors for Layer B combat core (TWBattle).
# Every event is a plain serializable Dictionary {"type": ..., "tick": int, ...}.

const BATTLE_START: = "BATTLE_START"
const PAIR_STRIKE: = "PAIR_STRIKE"
const COMBO_STEP: = "COMBO_STEP"
const FEVER_ON: = "FEVER_ON"
const FEVER_OFF: = "FEVER_OFF"
const PATTERN: = "PATTERN"
const ENERGY: = "ENERGY"
const ULT_READY: = "ULT_READY"
const ULT_AIM: = "ULT_AIM"
const ULT_CAST: = "ULT_CAST"
const SHIELD_HIT: = "SHIELD_HIT"
const SHIELD_BREAK: = "SHIELD_BREAK"
const BOSS_CAST: = "BOSS_CAST"
const TEAM_HIT: = "TEAM_HIT"
const HEAL: = "HEAL"
const WAVE_CLEAR: = "WAVE_CLEAR"
const ENRAGE: = "ENRAGE"
const TRAY_OVERFLOW: = "TRAY_OVERFLOW"
const VICTORY: = "VICTORY"
const DEFEAT: = "DEFEAT"

const ALL_TYPES: = [
	BATTLE_START, PAIR_STRIKE, COMBO_STEP, FEVER_ON, FEVER_OFF, PATTERN,
	ENERGY, ULT_READY, ULT_AIM, ULT_CAST, SHIELD_HIT, SHIELD_BREAK,
	BOSS_CAST, TEAM_HIT, HEAL, WAVE_CLEAR, ENRAGE, TRAY_OVERFLOW,
	VICTORY, DEFEAT,
]


static func make(type_id: String, tick: int, payload: Dictionary = {}) -> Dictionary:
	var ev: Dictionary = {"type": type_id, "tick": tick}
	for k in payload:
		ev[k] = payload[k]
	return ev
