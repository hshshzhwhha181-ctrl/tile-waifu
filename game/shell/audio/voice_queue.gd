class_name TWVoiceQueue
extends RefCounted

# TWVoiceQueue (P30 / WP10, GDD V11 8.5): the arbiter of heroine voice lines. Pure logic, no nodes, no clock of its own:
# every call takes `now` (seconds), so it runs the same in the game, in a selftest and in a load simulator.
#
#   request(hero, kind, now, dur = 1.2, opts = {}) -> Dictionary   a line wants to speak
#       {"verdict": "play"|"queued"|"dropped", "reason": String, "line_id": String, "prio": int,
#        "interrupted": String (the cut line, on a preempting play), "replaced": String (a queued line this one displaced)}
#   tick(now) -> Dictionary        call every frame: the current line ended -> the waiting one starts ({} when nothing starts)
#   note_touch(hero, now) -> bool  touch_spam detector: true on the 3rd touch inside 1.3 s (the caller then asks for touch_spam)
#   current() / pending() / busy(now)  inspection
#
# Rules (all from GDD 8.5, the numbers are constants below):
#   - never more than ONE voice at a time;
#   - priority ron > tsumo > riichi > pon/chi/kan > anything else;
#   - a higher priority CUTS the voice that is speaking; an equal or lower one waits in a queue of depth 1;
#     when the single waiting place is taken the LOWER priority is thrown away (equal priority: the one already waiting stays);
#   - a waiting line goes stale after STALE_S: a reaction that comes two seconds late is worse than silence;
#   - cooldowns: the same line of the same heroine 4 s; the same category of the same heroine 60 s (chatter categories only,
#     see CHATTER: calls like ron/riichi/pon/win/fail are events the player is waiting for and are never muted by a category
#     cooldown); a rare line (opts.rare) needs a 1/20 roll; touch_spam = 3 touches in 1.3 s.
#   Cooldowns start when a line really starts to play, so a line that was dropped or displaced does not burn its cooldown.

const PRIO_RON: = 100
const PRIO_TSUMO: = 90
const PRIO_RIICHI: = 80
const PRIO_MELD: = 70
const PRIO_OTHER: = 10
const PRIO_BY_KIND: = {"ron": PRIO_RON, "tsumo": PRIO_TSUMO, "riichi": PRIO_RIICHI, "pon": PRIO_MELD, "chi": PRIO_MELD, "kan": PRIO_MELD}

const LINE_COOLDOWN_S: = 4.0
const CATEGORY_COOLDOWN_S: = 60.0
const RARE_CHANCE: = 0.05
const TOUCH_SPAM_N: = 3
const TOUCH_SPAM_WINDOW_S: = 1.3
const STALE_S: = 2.0
const DEFAULT_DUR_S: = 1.2

# categories that are chatter (60 s per heroine); everything else (match calls, results, system lines) is an event
const CHATTER: = ["idle", "touch", "combo", "hint", "shuffle", "tray", "match", "gift"]

var _cur: Dictionary = {}
var _pend: Dictionary = {}
var _line_at: Dictionary = {}   # "hero/line_id" -> start time
var _cat_at: Dictionary = {}    # "hero/category" -> start time
var _touches: Dictionary = {}   # hero -> Array[float]
var rng: = RandomNumberGenerator.new()
var stats: = {"play": 0, "queued": 0, "dropped": 0, "interrupted": 0, "expired": 0}


func _init(seed_value: int = 20241130) -> void:
	rng.seed = seed_value


static func priority_of(kind: String) -> int:
	return int(PRIO_BY_KIND.get(kind, PRIO_OTHER))


# "combo_t1" -> "combo", "touch_head_2" -> "touch", "idle_warm_1" -> "idle", "login_morning" -> "login"
static func category_of(kind: String) -> String:
	var i: = kind.find("_")
	return kind if i < 0 else kind.substr(0, i)


static func is_chatter(kind: String) -> bool:
	return CHATTER.has(category_of(kind))


func current() -> Dictionary:
	return _cur


func pending() -> Dictionary:
	return _pend


func busy(now: float) -> bool:
	return not _cur.is_empty() and now < float(_cur["end"])


func reset() -> void:
	_cur = {}
	_pend = {}
	_line_at.clear()
	_cat_at.clear()
	_touches.clear()


func _drop(reason: String, line_id: String, prio: int) -> Dictionary:
	stats["dropped"] += 1
	return {"verdict": "dropped", "reason": reason, "line_id": line_id, "prio": prio}


func _start(e: Dictionary, now: float) -> void:
	e["start"] = now
	e["end"] = now + float(e["dur"])
	_cur = e
	_line_at["%s/%s" % [e["hero"], e["line_id"]]] = now
	_cat_at["%s/%s" % [e["hero"], e["category"]]] = now
	stats["play"] += 1


func cooldown_left(hero: String, kind: String, line_id: String, now: float) -> float:
	var left: = 0.0
	var k1: = "%s/%s" % [hero, line_id]
	if _line_at.has(k1):
		left = maxf(left, LINE_COOLDOWN_S - (now - float(_line_at[k1])))
	if is_chatter(kind):
		var k2: = "%s/%s" % [hero, category_of(kind)]
		if _cat_at.has(k2):
			left = maxf(left, CATEGORY_COOLDOWN_S - (now - float(_cat_at[k2])))
	return maxf(left, 0.0)


# opts: ctx ("lobby"|"match", carried into the entry), line_id (default = kind), prio (default priority_of(kind)), rare (bool), roll (float 0..1, for tests; default rng)
func request(hero: String, kind: String, now: float, dur: float = DEFAULT_DUR_S, opts: Dictionary = {}) -> Dictionary:
	var line_id: String = String(opts.get("line_id", kind))
	var prio: int = int(opts.get("prio", priority_of(kind)))
	_expire(now)
	if cooldown_left(hero, kind, line_id, now) > 0.0:
		var in_line: = _line_at.has("%s/%s" % [hero, line_id]) and now - float(_line_at["%s/%s" % [hero, line_id]]) < LINE_COOLDOWN_S
		return _drop("line_cooldown" if in_line else "category_cooldown", line_id, prio)
	if bool(opts.get("rare", false)):
		var roll: = float(opts["roll"]) if opts.has("roll") else rng.randf()
		if roll >= RARE_CHANCE:
			return _drop("rare_roll", line_id, prio)
	if not _pend.is_empty() and _pend["hero"] == hero and _pend["line_id"] == line_id:
		return _drop("duplicate", line_id, prio)
	var e: = {"hero": hero, "kind": kind, "line_id": line_id, "category": category_of(kind), "prio": prio,
			"dur": maxf(dur, 0.05), "ctx": String(opts.get("ctx", "lobby")), "asked": now, "start": -1.0, "end": -1.0}
	if not busy(now):
		_start(e, now)
		_pend = {}
		return {"verdict": "play", "reason": "", "line_id": line_id, "prio": prio, "entry": e}
	if prio > int(_cur["prio"]):
		var cut: String = String(_cur["line_id"])
		stats["interrupted"] += 1
		_start(e, now)
		return {"verdict": "play", "reason": "preempt", "line_id": line_id, "prio": prio, "interrupted": cut, "entry": e}
	# it has to wait: the single waiting place keeps the higher priority, the lower one is thrown away
	if _pend.is_empty():
		_pend = e
		stats["queued"] += 1
		return {"verdict": "queued", "reason": "", "line_id": line_id, "prio": prio}
	if prio > int(_pend["prio"]):
		var old: String = String(_pend["line_id"])
		_pend = e
		stats["queued"] += 1
		stats["dropped"] += 1
		return {"verdict": "queued", "reason": "replaced_lower", "line_id": line_id, "prio": prio, "replaced": old}
	return _drop("queue_full_lower_priority" if prio < int(_pend["prio"]) else "queue_full", line_id, prio)


func _expire(now: float) -> void:
	if not _pend.is_empty() and now - float(_pend["asked"]) > STALE_S:
		_pend = {}
		stats["expired"] += 1


# the voice that was speaking has finished: start the waiting line, if it is still fresh. {} = nothing starts.
func tick(now: float) -> Dictionary:
	if busy(now):
		return {}
	if not _cur.is_empty():
		_cur = {}
	_expire(now)
	if _pend.is_empty():
		return {}
	var e: Dictionary = _pend
	_pend = {}
	# the cooldown may have been taken by an identical line that played while this one waited
	if cooldown_left(String(e["hero"]), String(e["kind"]), String(e["line_id"]), now) > 0.0:
		stats["dropped"] += 1
		return {}
	_start(e, now)
	return {"verdict": "play", "reason": "dequeued", "line_id": e["line_id"], "prio": e["prio"], "entry": e}


# stop the voice that is speaking (screen change, voice switched off) and forget the waiting line
func cut(now: float) -> void:
	_cur = {}
	_pend = {}


func note_touch(hero: String, now: float) -> bool:
	var a: Array = _touches.get(hero, [])
	a.append(now)
	while not a.is_empty() and now - float(a[0]) > TOUCH_SPAM_WINDOW_S:
		a.pop_front()
	if a.size() >= TOUCH_SPAM_N:
		_touches[hero] = []
		return true
	_touches[hero] = a
	return false
