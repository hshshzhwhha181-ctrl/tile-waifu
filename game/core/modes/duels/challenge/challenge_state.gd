class_name V10ChallengeState
extends RefCounted

# «Вызов по коду»: the module's save key S.v10_challenge (created and repaired lazily here; SAVE_VER untouched)
# and its reward rules.
#
#   S.v10_challenge = {
#     ver: 1,
#     list: [ ≤ 20 entries, newest first ]   {core, kind:"sent"|"taken", mode, gen, key, title, author,
#                                              author_t, author_stars, my_t, my_stars, result:""|"win"|"lose",
#                                              tries, at, rewarded}
#     own: [ ≤ 200 cores ]                     every code this profile made (its own codes never pay)
#     day: {key, n}                            rewarded wins on that day (V10Meta day, 04:00 phone time)
#     paid: [ ≤ 200 cores ]                    codes that already paid once
#     stats: {sent, taken, wins}
#   }
#
# REWARD (spec R5): beating the author of SOMEONE ELSE's code pays +5 crystals, at most 3 times a day, once per
# code, never for a code this profile made, never while the phone clock was moved back. «Beating» = a cleaner
# time with no fewer stars (helps cost stars, so a helped run cannot outrun a clean one). The numbers come from
# economy.json (challenge.win_gems / challenge.daily_cap) once V10Econ carries them.
#
#   st() · bind(S) · register_save()
#   record_sent(p, info) · record_taken(d, info) -> entry · find(core) · is_own(core) · entries()
#   beats(my_t, my_s, author_t, author_s) -> bool
#   finish(core, my_t, my_s) -> {won, delta, reward:{gems}, reason, entry}     (also applies the reward)
#   rewards_left() -> int

const U: = preload("res://scripts/v10/duels/challenge/challenge_util.gd")

const KEY: = "v10_challenge"
const LIST_MAX: = 20
const OWN_MAX: = 200
const DEFAULTS: = {"ver": 1, "list": [], "own": [], "day": {"key": "", "n": 0}, "paid": [], "stats": {"sent": 0, "taken": 0, "wins": 0}}
const WIN_GEMS: = 5
const DAILY_CAP: = 3

static var _bound = null


static func bind(S) -> void:
	_bound = S


static func save() -> Dictionary:
	if _bound is Dictionary:
		return _bound
	var gg: = U.g()
	if gg and gg.get("S") is Dictionary:
		return gg.S
	if _bound == null:
		_bound = {}
	return _bound


static func st() -> Dictionary:
	var S: = save()
	if not (S.get(KEY) is Dictionary):
		S[KEY] = DEFAULTS.duplicate(true)
	var d: Dictionary = S[KEY]
	for k in DEFAULTS:
		if not d.has(k) or typeof(d[k]) != typeof(DEFAULTS[k]):
			d[k] = (DEFAULTS[k] as Variant)
			if d[k] is Dictionary or d[k] is Array:
				d[k] = d[k].duplicate(true)
	for k in ["key", "n"]:
		if not (d.day as Dictionary).has(k):
			d.day[k] = DEFAULTS.day[k]
	for k in ["sent", "taken", "wins"]:
		d.stats[k] = int(d.stats.get(k, 0))
	return d


static func register_save() -> void:
	var sv: = U.cls("V10Save")
	if sv:
		sv.call("register", KEY, DEFAULTS.duplicate(true))


static func win_gems() -> int:
	return int(U.econ_num("challenge.win_gems", WIN_GEMS))


static func daily_cap() -> int:
	return int(U.econ_num("challenge.daily_cap", DAILY_CAP))

# ---------------------------------------------------------------- list

static func entries() -> Array:
	return st().list


static func find(core: String) -> Dictionary:
	for e in st().list:
		if String(e.get("core", "")) == core:
			return e
	return {}


static func is_own(core: String) -> bool:
	return core in st().own


static func _put(e: Dictionary) -> void:
	var d: = st()
	var keep: = []
	for x in d.list:
		if not (String(x.get("core", "")) == String(e.core) and String(x.get("kind", "")) == String(e.kind)):
			keep.append(x)
	keep.push_front(e)
	while keep.size() > LIST_MAX:
		keep.pop_back()
	d.list = keep


# info = {title, mode_name, table}
static func record_sent(p: Dictionary, core: String, info: Dictionary) -> Dictionary:
	var d: = st()
	if not core in d.own:
		d.own.push_front(core)
		while d.own.size() > OWN_MAX:
			d.own.pop_back()
	d.stats.sent = int(d.stats.sent) + 1
	var e: = {"core": core, "kind": "sent", "mode": int(p.mode), "gen": int(p.gen), "key": int(p.key),
		"title": String(info.get("title", "")), "author": U.my_nick(), "author_t": int(p.tenths),
		"author_stars": int(p.stars), "my_t": int(p.tenths), "my_stars": int(p.stars), "result": "", "tries": 0,
		"at": U.now_unix(), "rewarded": false}
	_put(e)
	return e


# d = a decoded code ({core, mode, gen, key, tenths, stars, nick}); info = {title}
static func record_taken(dc: Dictionary, info: Dictionary) -> Dictionary:
	var old: = find(String(dc.core))
	if not old.is_empty() and String(old.kind) == "taken":
		old.at = U.now_unix()
		_put(old)
		return old
	var d: = st()
	d.stats.taken = int(d.stats.taken) + 1
	var e: = {"core": String(dc.core), "kind": "taken", "mode": int(dc.mode), "gen": int(dc.gen), "key": int(dc.key),
		"title": String(info.get("title", "")), "author": String(dc.get("nick", "")), "author_t": int(dc.tenths),
		"author_stars": int(dc.stars), "my_t": 0, "my_stars": 0, "result": "", "tries": 0, "at": U.now_unix(),
		"rewarded": false}
	_put(e)
	return e

# ---------------------------------------------------------------- results and rewards

static func beats(my_t: int, my_s: int, author_t: int, author_s: int) -> bool:
	return my_t < author_t and my_s >= author_s


static func rewards_left() -> int:
	var d: = st()
	var today: = U.day_key()
	if String(d.day.key) != today:
		return daily_cap()
	return maxi(0, daily_cap() - int(d.day.n))


# why a win would not pay (empty = it pays)
static func no_pay_reason(core: String) -> String:
	if is_own(core):
		return "own"
	if core in st().paid:
		return "paid"
	if not U.clock_ok():
		return "clock"
	if rewards_left() <= 0:
		return "cap"
	return ""


const REASON_TEXT: = {
	"own": "Свой вызов — без награды",
	"paid": "Награда за этот вызов уже получена",
	"clock": "Часы телефона переведены назад: награда подождёт",
	"cap": "Награды за вызовы на сегодня получены, новые — с 04:00",
	"lose": "",
}


# the end of a challenge run: records the try and the best result, pays the reward through V10ChallengeUtil
static func finish(dc: Dictionary, my_t: int, my_s: int) -> Dictionary:
	var core: = String(dc.core)
	var e: = find(core)
	if e.is_empty() or String(e.kind) != "taken":
		e = record_taken(dc, {"title": String(dc.get("title", ""))})
	var won: = beats(my_t, my_s, int(dc.tenths), int(dc.stars))
	e.tries = int(e.get("tries", 0)) + 1
	e.at = U.now_unix()
	if int(e.my_t) == 0 or my_t < int(e.my_t) or (my_t == int(e.my_t) and my_s > int(e.my_stars)):
		e.my_t = my_t
		e.my_stars = my_s
	if won:
		e.result = "win"
	elif String(e.result) != "win":
		e.result = "lose"
	var res: = {"won": won, "delta": my_t - int(dc.tenths), "my_t": my_t, "my_stars": my_s,
		"author_t": int(dc.tenths), "author_stars": int(dc.stars), "reward": {}, "reason": "", "entry": e}
	var d: = st()
	if won:
		d.stats.wins = int(d.stats.wins) + 1
		var why: = no_pay_reason(core)
		res.reason = why
		if why == "":
			var today: = U.day_key()
			if String(d.day.key) != today:
				d.day = {"key": today, "n": 0}
			d.day.n = int(d.day.n) + 1
			d.paid.push_front(core)
			while d.paid.size() > OWN_MAX:
				d.paid.pop_back()
			e.rewarded = true
			res.reward = {"gems": win_gems()}
			U.apply_rewards(res.reward, "challenge_win")
	else:
		res.reason = "lose"
	_put(e)
	U.save_game()
	return res
