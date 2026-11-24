class_name V10Seven
extends RefCounted

# V10Seven — «Семь встреч» (spec Г4): 7 days of coming in (not in a row; one per day_key, day starts 04:00 phone
# time), each claimed in the morning tray (V10Tray provider). 10 tickets in all.
# S.seven = {days: ["YYYY-MM-DD"…≤7], claimed: [bool×7]}
#
#   V10Seven.visit(S, day_key) -> bool          count today's visit (true when it is a new day)
#   V10Seven.claimable(S) -> Array[int]         day indices ready to claim
#   V10Seven.claim(S, i, give: Callable) -> Dictionary   grants REWARDS[i] through give(kind, id_or_amount), once
#   V10Seven.done(S) -> bool                    all 7 claimed (the tray stops offering)
#   V10Seven.tray_items(S) -> Array             provider rows for the morning tray: {id, icon, text, claim:Callable}

const REWARDS: = [
	{"kind": "tickets", "n": 2, "text": "2 билета желания", "icon": "ticket"},
	{"kind": "gems", "n": 150, "text": "150 кристаллов", "icon": "gem"},
	{"kind": "tickets", "n": 3, "text": "3 билета желания", "icon": "ticket"},
	{"kind": "coins", "n": 500, "text": "500 монет", "icon": "coin"},
	{"kind": "tickets", "n": 2, "text": "2 билета желания", "icon": "ticket"},
	{"kind": "item", "id": "s_lemon", "text": "Фишки «Лимон»", "icon": "tiles"},
	{"kind": "tickets", "n": 3, "text": "3 билета и фон «Первый вечер»", "icon": "ticket", "extra": {"kind": "cos", "id": "cb_first_evening"}},
]


static func st(S: Dictionary) -> Dictionary:
	var s = S.get("seven")
	if not (s is Dictionary):
		s = {}
	if not (s.get("days") is Array):
		s["days"] = []
	if not (s.get("claimed") is Array) or s.claimed.size() != 7:
		s["claimed"] = [false, false, false, false, false, false, false]
	S["seven"] = s
	return s


static func tickets_total() -> int:
	var n: = 0
	for r in REWARDS:
		if r.kind == "tickets":
			n += int(r.n)
	return n


static func visit(S: Dictionary, day: String) -> bool:
	var s: = st(S)
	if s.days.size() >= 7 or day in s.days:
		return false
	s.days.append(day)
	return true


static func claimable(S: Dictionary) -> Array:
	var s: = st(S)
	var out: = []
	for i in s.days.size():
		if not bool(s.claimed[i]):
			out.append(i)
	return out


static func claim(S: Dictionary, i: int, give: Callable) -> Dictionary:
	var s: = st(S)
	if i < 0 or i >= s.days.size() or bool(s.claimed[i]):
		return {}
	s.claimed[i] = true
	var r: Dictionary = REWARDS[i]
	give.call(r)
	if r.has("extra"):
		give.call(r.extra)
	return r


static func done(S: Dictionary) -> bool:
	return not (false in st(S).claimed)


static func tray_items(S: Dictionary, give: Callable) -> Array:
	var out: = []
	for i in claimable(S):
		var r: Dictionary = REWARDS[i]
		out.append({"id": "seven_%d" % i, "icon": r.icon, "title": "Семь встреч · день %d" % (i + 1), "text": r.text,
			"claim": func(): return claim(S, i, give)})
	return out
