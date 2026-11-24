class_name V10WeekLetter
extends RefCounted

# V10WeekLetter — «Письмо недели» (docs/0.10-spec.md Р10). Mondays after 04:00 the partner writes 3 facts of the
# previous week, each of a different kind, from a WHITE list only (V10RitLines.FACTS, 24 kinds). Never: absence,
# losses, night play (00–06), spending, ads, comparison with other players. A week with 0 wins → no letter.
#
#   V10WeekLetter.facts(c) -> Array          all eligible facts [{kind, n, text, w}] of a counters dict
#   V10WeekLetter.compose(c, h, seed) -> {}  {h, ev:"week", subj, open, facts:[3 texts], close, sign, body} or {}
#   V10WeekLetter.due(key) -> {}             the letter to deliver now (once per week), else {}; marks it sent
#   V10WeekLetter.BLACK                      counter kinds that must never reach the text (selftest)

const BLACK: = ["losses", "night_wins", "spent", "absent_days", "rank_drop"]

# kind -> [counter key, minimum to be worth a line, weight]
const SRC: = {
	"wins": ["wins", 1, 1.0], "best_combo": ["max_best_combo", 5, 3.0], "pairs": ["pairs", 30, 1.0],
	"stars3": ["stars3", 2, 2.0], "levels": ["levels", 2, 2.0], "days": ["_days", 3, 1.5],
	"fever": ["fever", 2, 1.5], "ults": ["ults", 2, 2.0], "hard_wins": ["hard_wins", 1, 2.5],
	"fast_win": ["min_fast_win", 1, 2.0], "no_hint_wins": ["no_hint_wins", 2, 1.5],
	"no_undo_wins": ["no_undo_wins", 2, 1.2], "modes": ["_modes", 2, 1.5], "daily": ["daily", 2, 1.5],
	"tasks": ["tasks", 2, 1.2], "touches": ["touches", 3, 2.0], "gifts": ["gifts", 1, 2.5],
	"replies": ["replies", 1, 2.0], "duel_wins": ["duel_wins", 1, 2.0], "floors": ["floors", 1, 2.0],
	"streak": ["streak", 3, 2.0], "morning": ["morning", 2, 1.2], "run": ["max_run", 3, 2.2],
	"outfits": ["outfits", 1, 2.5],
}


static func _val(c: Dictionary, key: String) -> int:
	if key == "_days":
		var n: = 0
		for k in c:
			if str(k).begins_with("day_"):
				n += 1
		return n
	if key == "_modes":
		var m: = 0
		for k in c:
			if str(k).begins_with("mode_"):
				m += 1
		return m
	return int(c.get(key, 0))


static func facts(c: Dictionary) -> Array:
	var out: = []
	for kind in SRC:
		var src: Array = SRC[kind]
		var n: = _val(c, str(src[0]))
		if n < int(src[1]):
			continue
		out.append({"kind": kind, "n": n, "w": float(src[2]),
			"text": V10RitLines.fmt(str(V10RitLines.FACTS[kind]), n)})
	return out


static func compose(c: Dictionary, h: String, seed: = 0) -> Dictionary:
	if int(c.get("wins", 0)) <= 0:
		return {}
	var all: = facts(c)
	if all.is_empty():
		return {}
	var rng: = RandomNumberGenerator.new()
	rng.seed = hash(seed)
	var pool: = all.duplicate()
	var picked: = []
	while picked.size() < 3 and not pool.is_empty():
		var tot: = 0.0
		for f in pool:
			tot += float(f.w)
		var r: = rng.randf() * tot
		var idx: = 0
		for i in pool.size():
			r -= float(pool[i].w)
			if r <= 0.0:
				idx = i
				break
		picked.append(pool[idx])
		pool.remove_at(idx)
	var op: = V10RitLines.pick("week_open", h, seed)
	var cl: = V10RitLines.pick("week_close", h, seed / 3 + 1)
	var texts: = []
	for f in picked:
		texts.append(str(f.text))
	var body: = op + "\n\n" + "\n".join(PackedStringArray(texts.map(func(t): return "• " + t))) + "\n\n" + cl
	return {"h": h, "ev": "week", "subj": "Письмо недели", "open": op, "facts": texts, "kinds": picked.map(func(f): return f.kind),
		"close": cl, "sign": V10RitBridge.short_name(h), "body": body}


static func due(key: = "", h: = "") -> Dictionary:
	key = key if key != "" else V10RitClock.day_key()
	h = h if h != "" else V10RitBridge.partner()
	var s: = V10Tele.st()
	var pw: = V10Tele.prev_week(key)
	var wk: = V10RitClock.week_key(key)
	if str(s.sent_week) == wk or str(pw.week) == "":
		return {}
	s.sent_week = wk
	var c: Dictionary = (pw.c as Dictionary).duplicate()
	c["streak"] = int(V10Streak.st().n)
	return compose(c, h, V10RitClock.day_index(key))
