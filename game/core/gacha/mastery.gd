class_name V10Mastery
extends RefCounted

# V10Mastery — outfit mastery I–IV (spec Г8). Every pair taken while the outfit is worn grows its bar (×2 while
# «Отдых» is on; pairs from the heroine's Приём count too). Pairs are counted in memory during the match and
# written to S.mastery once, at the end of the match (flush). Cosmetic only: no power in ranked.
#   I   300  — 3 recolour palettes (a toast)
#   II  1000 — portrait backdrop        ┐
#   III 2500 — 5 lines and a frame      ├ gong + full-screen card with «Примерить»
#   IV  5000 — «Пробуждённый» art (SSR only, 1.0) ┘
#
#   var m: = V10Mastery.new(); m.on_pair(outfit, rested)     hook V10Hooks.pair_taken
#   m.flush(S, rar_of) -> Array[{outfit, from, to}]          hook V10Hooks.game_ended; level-ups to show
#   V10Mastery.level(points, rar) -> int  0..4 (IV only for SSR)
#   V10Mastery.progress(points, rar) -> {lv, cur, need, frac, next_text}
#   V10Mastery.set_palette(S, outfit, idx) -> bool           palette 0 = original, 1..3 after level I

const THRESH: = [300, 1000, 2500, 5000]
const ROMAN: = ["", "I", "II", "III", "IV"]
const REWARD: = ["", "3 палитры наряда", "Фон портрета", "5 реплик и рамка", "Пробуждённый арт"]
const PALETTES: = 3
# palette recolours (hue shift, saturation, value) for the card_art shader uniform `palette_idx`
const PAL_HSV: = [Vector3(0, 1, 1), Vector3(0.08, 1.05, 1.0), Vector3(-0.12, 0.9, 1.04), Vector3(0.5, 0.85, 0.98)]

var pending: = {}


func on_pair(outfit: String, rested: bool = false, n: int = 1) -> void:
	if outfit == "":
		return
	pending[outfit] = int(pending.get(outfit, 0)) + n * (2 if rested else 1)


static func max_level(rar: String) -> int:
	return 4 if rar == "SSR" else 3


static func level(points: int, rar: String) -> int:
	var lv: = 0
	for i in max_level(rar):
		if points >= THRESH[i]:
			lv = i + 1
	return lv


static func progress(points: int, rar: String) -> Dictionary:
	var lv: = level(points, rar)
	var mx: = max_level(rar)
	if lv >= mx:
		return {"lv": lv, "cur": points, "need": THRESH[mx - 1], "frac": 1.0, "next_text": "Мастерство полное"}
	var lo: int = 0 if lv == 0 else THRESH[lv - 1]
	var hi: int = THRESH[lv]
	return {"lv": lv, "cur": points, "need": hi, "frac": clampf(float(points - lo) / float(hi - lo), 0.0, 1.0),
		"next_text": "%s: ещё %d пар · %s" % [ROMAN[lv + 1], hi - points, REWARD[lv + 1]]}


static func data(S: Dictionary) -> Dictionary:
	if not (S.get("mastery") is Dictionary):
		S["mastery"] = {}
	return S.mastery


static func points(S: Dictionary, outfit: String) -> int:
	return int(data(S).get(outfit, {}).get("p", 0))


func flush(S: Dictionary, rar_of: Callable) -> Array:
	var ups: = []
	for o in pending:
		var rar: = String(rar_of.call(o))
		var d: Dictionary = data(S).get(o, {"p": 0, "pal": 0})
		var before: = level(int(d.p), rar)
		d.p = int(d.p) + int(pending[o])
		d["pal"] = int(d.get("pal", 0))
		data(S)[o] = d
		var after: = level(int(d.p), rar)
		if after > before:
			ups.append({"outfit": o, "from": before, "to": after, "big": after >= 2})
	pending.clear()
	return ups


static func set_palette(S: Dictionary, outfit: String, idx: int, rar: String) -> bool:
	if idx < 0 or idx > PALETTES:
		return false
	if idx > 0 and level(points(S, outfit), rar) < 1:
		return false
	var d: Dictionary = data(S).get(outfit, {"p": 0, "pal": 0})
	d["pal"] = idx
	data(S)[outfit] = d
	return true


static func palette(S: Dictionary, outfit: String) -> int:
	return int(data(S).get(outfit, {}).get("pal", 0))
