class_name V10HandState
extends RefCounted

# «Чтение руки» — the save key S.v10_hand, the day rules, rewards, cosmetics, share text, glossary. Static.
#
# SAVE  S.v10_hand (created / repaired lazily by st(); SAVE_VER is never bumped; register_save() hands the defaults
#       to V10Save when that class exists):
#   {ver, day, done, correct, kind, hidden_at_guess, mult, gems,     the last played day and its guess
#    streak, best_streak, total_correct, played,                     verdicts over time
#    school,                                                         played days counted for «С подсказкой» (≤ 7)
#    today: {key, taken: [kinds], closed},                           progress of the current day (restored on re-entry)
#    lessons: {"1": mask, …},                                        «Разбор ожиданий» (bit i = task i solved)
#    cos: [ids], hist: [{d, c, h, m, hero}] (≤ 30), intro}
# DAY   One guess a day. The day is V10Meta.day_key() (04:00 phone time; monotonic: it never goes below the last
#       key seen). A day is PLAYED when its guess was made — and every key before the last played day counts as
#       played too, so moving the clock back (or V10Meta.clock_ok() == false with an unbound meta state) never
#       reopens a day. Moving the clock forward only lets the player meet a later day early, never twice.
# REWARD verdict at guess time: right → 10 / 20 / 30 crystals for boldness ×1 / ×2 / ×3 (closed cards ≥7 ×3, 4–6 ×2,
#       else ×1); wrong → 5. Affection +2 to the heroine of the day (soft source). One guess a day caps the module
#       at 30 crystals a day. Applied once by V10Hand.guess through V10HandUtil.grant.
# COS   frame «Читающая руки» (fr_palm) and title t_palm after 30 right guesses — both already in V10ProfileCos;
#       cos_defs() is the same definition for builds where the profile lane registers nothing.

const U: = preload("res://core/modes/palm/hand_util.gd")
const T: = preload("res://core/modes/palm/hand_text.gd")

const KEY: = "v10_hand"
const VER: = 1
const HIST_MAX: = 30
const COS_IDS: = ["fr_palm", "t_palm"]

static var _test_S = null   # selftests and demos: a plain dict standing in for G.S
static var _mem: = {}


static func defaults() -> Dictionary:
	return {"ver": VER, "day": "", "done": false, "correct": false, "kind": -1, "hidden_at_guess": 0, "mult": 1, "gems": 0,
		"streak": 0, "best_streak": 0, "total_correct": 0, "played": 0, "school": 0,
		"today": {"key": "", "taken": [], "closed": false}, "lessons": {}, "cos": [], "hist": [], "intro": false}


static func save_root() -> Dictionary:
	if _test_S is Dictionary:
		return _test_S
	if U.g_ok() and G.S is Dictionary:
		return G.S
	return _mem


static func st() -> Dictionary:
	var S: = save_root()
	if not (S.get(KEY) is Dictionary):
		S[KEY] = defaults()
	return repair(S[KEY])


static func register_save() -> void:
	var sv: = U.cls("V10Save")
	if sv and U.has_fn(sv, "register"):
		sv.call("register", KEY, defaults())


# fills missing keys and fixes types and ranges in place (a hand-edited or old save never breaks the screen)
static func repair(d: Dictionary) -> Dictionary:
	var df: = defaults()
	for k in df:
		if not d.has(k):
			d[k] = df[k].duplicate(true) if (df[k] is Dictionary or df[k] is Array) else df[k]
	d.ver = VER
	d.day = str(d.day) if (d.day is String or d.day is StringName) else ""
	for k in ["done", "correct", "intro"]:
		d[k] = bool(d[k]) if (d[k] is bool or d[k] is int or d[k] is float) else false
	for k in ["kind", "hidden_at_guess", "mult", "gems", "streak", "best_streak", "total_correct", "played", "school"]:
		d[k] = int(d[k]) if (d[k] is int or d[k] is float) else int(df[k])
	d.kind = clampi(d.kind, -1, 33)
	d.hidden_at_guess = clampi(d.hidden_at_guess, 0, 13)
	d.mult = clampi(d.mult, 1, 3)
	for k in ["gems", "streak", "best_streak", "total_correct", "played"]:
		d[k] = maxi(0, d[k])
	d.school = clampi(d.school, 0, int(U.econ("hand.school_days")))
	d.best_streak = maxi(d.best_streak, d.streak)
	d.played = maxi(d.played, d.total_correct)
	if not (d.today is Dictionary):
		d.today = df.today.duplicate(true)
	var td: Dictionary = d.today
	td["key"] = str(td.get("key", "")) if (td.get("key") is String) else ""
	var tk: = []
	if td.get("taken") is Array:
		for x in td.taken:
			if (x is int or x is float) and int(x) >= 0 and int(x) < 34:
				tk.append(int(x))
	td["taken"] = tk
	td["closed"] = bool(td.get("closed", false)) if (td.get("closed") is bool) else false
	if not (d.lessons is Dictionary):
		d.lessons = {}
	for k in (d.lessons as Dictionary).keys():
		var v = d.lessons[k]
		d.lessons[k] = clampi(int(v), 0, 7) if (v is int or v is float) else 0
	if not (d.cos is Array):
		d.cos = []
	d.cos = (d.cos as Array).filter(func(x): return x is String and x in COS_IDS)
	if not (d.hist is Array):
		d.hist = []
	d.hist = (d.hist as Array).filter(func(x): return x is Dictionary)
	while (d.hist as Array).size() > HIST_MAX:
		(d.hist as Array).pop_front()
	return d


# ---------------------------------------------------------------- gate and day

static func gate_level() -> int:
	return int(U.econ("hand.gate_level"))


# open from L30 (UX §3.5); once played it stays open
static func is_open() -> bool:
	if int(st().played) > 0:
		return true
	return int(save_root().get("unlocked", 1)) >= gate_level()


static func lock_text() -> String:
	return T.LOCK % gate_level()


static func today_key() -> String:
	return U.day_key()


static func played_day(key: String) -> bool:
	var s: = st()
	var last: = String(s.day)
	if last == "":
		return false
	if key < last:
		return true
	return key == last and bool(s.done)


# {state: open | done | locked, key, text, sub}
static func status(key: String = "") -> Dictionary:
	if key == "":
		key = today_key()
	if not is_open():
		return {"state": "locked", "key": key, "text": lock_text(), "sub": ""}
	if played_day(key):
		return {"state": "done", "key": key, "text": T.DONE_TODAY, "sub": T.NEXT_HAND}
	return {"state": "open", "key": key, "text": T.MODE_LINE, "sub": ""}


static func can_guess(key: String = "") -> bool:
	return String(status(key).state) == "open"


static func school_on() -> bool:
	return int(st().school) < int(U.econ("hand.school_days"))


# ---------------------------------------------------------------- numbers

static func mult_for(hidden: int) -> int:
	if hidden >= 7:
		return 3
	if hidden >= 4:
		return 2
	return 1


static func gems_for(right: bool, mult: int) -> int:
	if not right:
		return int(U.econ("hand.gems_wrong"))
	var g: Array = U.econ("hand.gems")
	return int(g[clampi(mult, 1, 3) - 1])


# the verdict of a day goes into the save; returns the cosmetics unlocked by it
static func record(key: String, right: bool, kind: int, hidden: int, mult: int, gems: int, hero: String) -> Array:
	var s: = st()
	s.day = key
	s.done = true
	s.correct = right
	s.kind = kind
	s.hidden_at_guess = hidden
	s.mult = mult
	s.gems = gems
	s.played = int(s.played) + 1
	s.school = mini(int(s.school) + 1, int(U.econ("hand.school_days")))
	if right:
		s.streak = int(s.streak) + 1
		s.total_correct = int(s.total_correct) + 1
	else:
		s.streak = 0
	s.best_streak = maxi(int(s.best_streak), int(s.streak))
	(s.hist as Array).append({"d": key, "c": right, "h": hidden, "m": mult, "hero": hero})
	while (s.hist as Array).size() > HIST_MAX:
		(s.hist as Array).pop_front()
	var fresh: = []
	if int(s.total_correct) >= int(U.econ("hand.cos_correct")):
		for id in COS_IDS:
			if not (id in s.cos):
				(s.cos as Array).append(id)
				fresh.append(id)
	return fresh


# the day's progress (pairs taken, table closed) — restored when the player comes back the same day
static func today_state(key: String) -> Dictionary:
	var td: Dictionary = st().today
	if String(td.key) != key:
		td.key = key
		td.taken = []
		td.closed = false
	return td


# ---------------------------------------------------------------- words

# «Чтение руки · 24 ноября · догадка верна · закрыто 8 из 13 · серия 4» — no tile name, no answer, no form
static func share_text(key: String, right: bool, hidden: int, streak: int) -> String:
	var s: = T.SHARE % [T.MODE, U.date_text(key), T.SHARE_RIGHT if right else T.SHARE_WRONG, hidden]
	if right and streak >= 2:
		s += T.SHARE_STREAK % streak
	return s


static func intro_key() -> String:
	return "hand_intro"


static func intro_line(h: String) -> String:
	return T.intro(h)


static func glossary() -> Array:
	return T.GLOSSARY.duplicate(true)


# ---------------------------------------------------------------- cosmetics (V10ProfileCos is the one registry)

static func cos_defs() -> Array:
	var src: = {"type": "grant", "event": "palm", "hint": "Угадай 30 рук в «Чтении руки»"}
	return [
		{"id": "fr_palm", "kind": "frame", "name": "Читающая руки", "tier": "S", "src": src.duplicate(),
			"look": {"base": "ring", "metal": "d9c8ff", "petal": "f0e6ff", "deco": "moon", "deco_col": "e6dcff", "glow": "b9a2ff"}},
		{"id": "t_palm", "kind": "title", "name": "Читающий руки", "tier": "S", "src": src.duplicate()},
	]


# registers the two entries when the profile lane does not have them yet (its own catalogue already does)
static func register_cos() -> Array:
	var pc: = U.cls("V10ProfileCos")
	var out: = []
	if pc == null:
		return out
	for e in cos_defs():
		if not bool(pc.call("has", e.id, "")):
			out.append(String(pc.call("register", e)))
	return out
