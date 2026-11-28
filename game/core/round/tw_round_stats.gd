class_name TWRoundStats
extends RefCounted

# TWRoundStats (P20 / WP7): the counters of a round, built from the TWBoard event stream instead of play.gd's member variables
# (gained, max_combo, last_combo, denies, fails, gold_got, sets_done, fever, blitz points ...). The v11 match screen feeds every
# event list the board returns into `feed`; at the end `stats()` is the dictionary TWRound.resolve() takes. No G, no scene tree.

const FEVER_COMBO: = 5
const FEVER_SECS: = 8.0

var mode: = ""
var gold_mult: = 5
var gem_bonus: = 0.0
var first_pairs_bonus: = 0
var fever_until: = -1.0
var gained: = 0                         # crystals paid for pairs so far
var pairs: = 0
var max_combo: = 0
var last_combo: = 0
var denies: = 0
var fails: = 0
var gold_total: = 0
var gold_got: = 0
var tiles: = 0
var max_tray: = 0
var blitz_score: = 0
var boards_done: = 0
var set_state: = {"cat_streak": 0, "cat_last": -1, "sets_done": []}
var shards: = 0
var gifts: = 0
var pair_log: Array = []                # [{gain, combo, gold, fever}] one per pair, in order


# a fresh round on `board` (TWBoard). `lo` = TWBoosters.loadout(...) (or {} for the defaults)
func begin(board: TWBoard, mode_: String, lo: Dictionary = {}) -> TWRoundStats:
	mode = mode_
	gold_mult = int(lo.get("gold_mult", 5))
	gem_bonus = float(lo.get("gem_bonus", 0.0))
	first_pairs_bonus = int(lo.get("first_pairs_bonus", 0))
	tiles = board.n
	var g: = 0
	for i in board.n:
		if board.gold0[i] != 0:
			g += 1
	gold_total = g / 2
	return self


func fever_on(t: float) -> bool:
	return t < fever_until


# one event list of the board (tap / undo / return_tray / shuffle). `t` = the board's clock now.
func feed(events: Array, t: float) -> void:
	for e in events:
		match String(e.get("t", "")):
			"MATCH":
				_pair(e, t)
			"DENY":
				denies += 1
			"TRAY_FULL":
				fails += 1
			"GIFT":
				gifts += 1


func _pair(e: Dictionary, t: float) -> void:
	var combo: = int(e.get("combo", 1))
	var gold: = bool(e.get("gold", false))
	var fever: = fever_on(t)
	var g: = TWRewards.pair_gain(combo, fever, gold, gold_mult, gem_bonus, first_pairs_bonus, mode)
	first_pairs_bonus = int(g.first_pairs_bonus)
	var gain: = int(g.gain)
	blitz_score += TWRewards.pair_score(mode, combo)
	gained += gain
	pairs += 1
	max_combo = maxi(max_combo, combo)
	last_combo = combo
	if gold:
		gold_got += 1
	if String(e.get("shard", "")) == "":
		var bonus: = TWRewards.set_step(set_state, TWRewards.face_cat(int(e.get("face", -1))))
		gained += bonus
	else:
		shards += 1
	if combo >= FEVER_COMBO and not fever:
		fever_until = t + FEVER_SECS
	pair_log.append({"gain": gain, "combo": combo, "gold": gold, "fever": fever})


# the dictionary TWRound.resolve() takes. `extra` overrides / adds keys (hero, seed, level, riichi, rival ...)
func stats(board: TWBoard, secs: float, event: String, extra: Dictionary = {}) -> Dictionary:
	var d: = {"event": event, "secs": secs, "tiles": tiles, "fails": fails, "boosters_used": 0, "max_combo": max_combo, "last_combo": last_combo,
		"denies": denies, "max_tray": board.max_tray if board != null else max_tray, "gold_total": gold_total, "gold_got": gold_got,
		"sets_done": (set_state.sets_done as Array).duplicate(), "riichi": false, "gained": gained, "blitz_score": blitz_score,
		"boards_done": boards_done}
	d.merge(extra, true)
	return d
