class_name V10Streak
extends RefCounted

# V10Streak — «Серия чая» with forgiveness (docs/0.10-spec.md Р3).
#
# RULES
#   * A day (from 04:00 phone time) counts when it has ≥1 win in any mode: on_win() from the game_ended hook.
#   * Tea leaves: +1 every Monday (weekly_leaf), max 2, 1 as a gift on the first run. Never sold.
#   * check() (home build, day roll, resume) looks at the days missed since the last counted day:
#       leaves ≥ missed      → leaves cover ALL of them (spent only on full cover), streak intact   → event "forgiven"
#       1 uncovered day      → the bowl cools: repair = 2 wins above the usual daily win within 48 h → "cooled"
#                              done in time → "warmed"; window passed → reset (leaves kept)
#       2+ uncovered days    → reset; leaves are kept                                                 → "reset"
#     A reset keeps best and never takes milestones back; n restarts from the wins after the gap.
#   * Milestones (once per lifetime): 3 → 50 кр; 7 → 100 кр + подсказка; 14 → 1 билет; 30 → рамка «Чайный мастер I»;
#     60 → 200 кр + рамка II; 100 → анимированная пиала (значок); 365 → титул «Год у стола»; after 30 every +30 → 50 кр.
#     A milestone also gives +10 симпатии партнёру (hard Bond source «рубеж серии»).
#   * Clock moved back (clock_ok false): wins wait in st.pending and are applied by the next check() with a good clock.
#
# API
#   V10Streak.check(key = today) -> Array[event]       idempotent per day; events also queue in st.events for the UI
#   V10Streak.on_win(key = today) -> Dictionary        {new_day, n, milestones:[{n, rewards}], repair:{need, got}, pending}
#   V10Streak.view(key = today) -> Dictionary          everything the chip / sheet draw (state, n, best, leaves, cal…)
#   V10Streak.take_events() -> Array                   events for the UI since the last call (forgiven/cooled/…)
#   V10Streak.calendar(key, weeks = 5) -> Array        [{key, state: win|leaf|warm|miss|today|future|none, n?}]
# State S.v10_streak — see V10RitSave.defaults().

const LEAF_MAX: = 2
const REPAIR_NEED: = 2
const HIST_DAYS: = 35
const MILESTONES: = {
	3: {"gems": 50},
	7: {"gems": 100, "hints": 1},
	14: {"tickets": 1},
	30: {"frame": "tea_master_1"},
	60: {"gems": 200, "frame": "tea_master_2"},
	100: {"badge": "tea_bowl_master"},
	365: {"title": "year_at_table"},
}
const MILESTONE_AFF: = 10
const RULE_TEXT: = "Листья: +1 каждый понедельник, максимум 2. Лист закрывает пропуск, только если листьев хватает на все пропущенные дни. Листья не продаются"
const FRAME_NAMES: = {"tea_master_1": "Чайный мастер I", "tea_master_2": "Чайный мастер II"}


static func st() -> Dictionary:
	return V10RitSave.st("v10_streak")


static func _today(key: String) -> String:
	return key if key != "" else V10RitClock.day_key()


static func milestone_rewards(n: int) -> Dictionary:
	if MILESTONES.has(n):
		return MILESTONES[n].duplicate(true)
	if n > 30 and n % 30 == 0:
		return {"gems": 50}
	return {}


static func next_milestone(n: int) -> int:
	for m in [3, 7, 14, 30, 60, 100, 365]:
		if m > n:
			return m
	return (n / 30 + 1) * 30


# ── day roll ───────────────────────────────────────────────────────────────────────────────────────────────────

static func weekly_leaf(key: String) -> int:
	var s: = st()
	var wk: = V10RitClock.week_key(key)
	if not s.gift:
		s.gift = true
		s.leaves = mini(LEAF_MAX, int(s.leaves) + 1)
		s.leaf_week = wk
		return 1
	if str(s.leaf_week) == "":
		s.leaf_week = wk
		return 0
	var weeks: = V10RitClock.days_between(str(s.leaf_week), wk) / 7
	if weeks <= 0:
		return 0
	s.leaf_week = wk
	var before: = int(s.leaves)
	s.leaves = mini(LEAF_MAX, before + weeks)
	if int(s.leaves) > before:
		s.leaf_new_key = key
	return int(s.leaves) - before


static func grant_leaf(n: = 1) -> void:
	var s: = st()
	s.leaves = mini(LEAF_MAX, int(s.leaves) + n)


static func _ev(kind: String, data: = {}) -> Dictionary:
	var e: = {"kind": kind}
	e.merge(data)
	st().events.append(e)
	return e


static func check(key: = "") -> Array:
	key = _today(key)
	var s: = st()
	var out: = []
	if not V10RitClock.clock_ok():
		return out
	_flush_pending()
	weekly_leaf(key)
	if str(s.checked_key) == key:
		return out
	s.checked_key = key
	# an open repair window that ran out
	var rp: Dictionary = s.repair
	if not rp.is_empty() and V10RitClock.days_between(str(rp.until), key) >= 0:
		s.repair = {}
		_reset(key)
		out.append(_ev("reset", {"best": int(s.best), "why": "repair_late"}))
	var last: = str(s.last_win_key)
	if int(s.n) <= 0 or last == "":
		_trim(key)
		return out
	var missed: = V10RitClock.days_between(last, key) - 1
	if missed <= 0:
		_trim(key)
		return out
	var miss_keys: = []
	for i in missed:
		miss_keys.append(V10RitClock.add_days(last, i + 1))
	if int(s.leaves) >= missed:
		s.leaves = int(s.leaves) - missed
		for k in miss_keys:
			s.hist[k] = "leaf"
		s.last_win_key = V10RitClock.add_days(key, -1)
		out.append(_ev("forgiven", {"days": missed, "leaves": int(s.leaves)}))
	elif missed == 1 and (s.repair as Dictionary).is_empty():
		s.hist[miss_keys[0]] = "miss"
		s.repair = {"need": REPAIR_NEED, "got": 0, "day": miss_keys[0], "until": V10RitClock.add_days(key, 2),
			"from": key, "n": int(s.n)}
		out.append(_ev("cooled", {"until": str(s.repair.until)}))
	else:
		for k in miss_keys:
			s.hist[k] = "miss"
		s.repair = {}
		_reset(key)
		out.append(_ev("reset", {"best": int(s.best), "why": "gap"}))
	_trim(key)
	return out


static func _reset(key: String) -> void:
	var s: = st()
	# n restarts from the run of won days after the last gap (a win today before the reset still counts)
	var run: = 0
	var k: = key if str(s.hist.get(key, "")) != "" else V10RitClock.add_days(key, -1)
	while s.hist.get(k, "") in ["win", "leaf", "warm"]:
		if s.hist[k] == "win" or s.hist[k] == "warm":
			run += 1
		k = V10RitClock.add_days(k, -1)
	s.n = run
	if run == 0:
		s.last_win_key = ""


# ── wins ───────────────────────────────────────────────────────────────────────────────────────────────────────

static func on_win(key: = "") -> Dictionary:
	key = _today(key)
	var s: = st()
	if not V10RitClock.clock_ok():
		s.pending.append({"kind": "win", "key": key})
		return {"new_day": false, "pending": true, "n": int(s.n)}
	_flush_pending()
	check(key)
	return _apply_win(key)


static func _apply_win(key: String) -> Dictionary:
	var s: = st()
	var res: = {"new_day": false, "n": int(s.n), "milestones": [], "repair": {}, "pending": false, "warmed": false}
	var rp: Dictionary = s.repair
	if str(s.hist.get(key, "")) == "win":
		if not rp.is_empty():
			rp.got = int(rp.got) + 1
			res.repair = {"need": int(rp.need), "got": int(rp.got)}
			if int(rp.got) >= int(rp.need):
				s.hist[str(rp.day)] = "warm"
				s.repair = {}
				res.warmed = true
				# the warmed day joins the run: the streak continues as if nothing happened
				s.n = int(s.n) + 1
				res.n = int(s.n)
				_ev("warmed", {"n": int(s.n)})
				res.milestones = _milestones()
		return res
	s.hist[key] = "win"
	s.last_win_key = key
	s.n = int(s.n) + 1
	s.best = maxi(int(s.best), int(s.n))
	res.new_day = true
	res.n = int(s.n)
	if not rp.is_empty():
		res.repair = {"need": int(rp.need), "got": int(rp.got)}
	res.milestones = _milestones()
	_ev("win", {"n": int(s.n)})
	_trim(key)
	return res


static func _milestones() -> Array:
	var s: = st()
	s.best = maxi(int(s.best), int(s.n))
	var out: = []
	for m in range(1, int(s.n) + 1):
		var r: = milestone_rewards(m)
		if r.is_empty() or m in s.got:
			continue
		s.got.append(m)
		r["aff"] = {V10RitBridge.partner(): MILESTONE_AFF}
		for f in ["frame"]:
			if r.has(f):
				V10RitBridge.register_frame(str(r[f]), FRAME_NAMES.get(str(r[f]), "Чайный мастер"), "streak")
		V10RitBridge.grant(r, "streak_milestone")
		out.append({"n": m, "rewards": r})
		_ev("milestone", {"n": m, "rewards": r})
	return out


static func _flush_pending() -> void:
	var s: = st()
	if (s.pending as Array).is_empty() or not V10RitClock.clock_ok():
		return
	var p: Array = s.pending.duplicate()
	s.pending = []
	for e in p:
		if e is Dictionary and str(e.get("kind", "")) == "win":
			_apply_win(str(e.key))


static func _trim(key: String) -> void:
	var s: = st()
	var keep: = V10RitClock.add_days(key, -HIST_DAYS)
	for k in s.hist.keys():
		if str(k) < keep:
			s.hist.erase(k)
	while (s.events as Array).size() > 12:
		s.events.pop_front()


static func take_events() -> Array:
	var s: = st()
	var e: Array = s.events.duplicate()
	s.events = []
	return e


# ── views ──────────────────────────────────────────────────────────────────────────────────────────────────────

static func state_of(key: = "") -> String:
	var s: = st()
	if not (s.repair as Dictionary).is_empty():
		return "cold"
	if int(s.n) <= 0:
		return "empty"
	return "warm" if str(s.hist.get(_today(key), "")) == "win" else "waiting"


static func view(key: = "") -> Dictionary:
	key = _today(key)
	var s: = st()
	var rp: Dictionary = s.repair
	var v: = {"n": int(s.n), "best": int(s.best), "leaves": int(s.leaves), "state": state_of(key),
		"today_won": str(s.hist.get(key, "")) == "win", "next": next_milestone(int(s.n)), "repair": {}}
	if not rp.is_empty():
		v.repair = {"need": int(rp.need), "got": int(rp.got), "until": str(rp.until),
			"text": "Серию можно согреть: %d %s до %s" % [int(rp.need) - int(rp.got),
				"победа" if int(rp.need) - int(rp.got) == 1 else "победы", V10RitClock.fmt_until(str(rp.until))]}
	return v


static func calendar(key: = "", weeks: = 5) -> Array:
	key = _today(key)
	var s: = st()
	var start: = V10RitClock.add_days(V10RitClock.week_key(key), -7 * (weeks - 1))
	var out: = []
	for i in weeks * 7:
		var k: = V10RitClock.add_days(start, i)
		var stt: = str(s.hist.get(k, ""))
		if k > key:
			stt = "future"
		elif k == key and stt == "":
			stt = "today"
		elif stt == "":
			stt = "none"
		out.append({"key": k, "state": stt, "day": int(k.substr(8, 2)), "today": k == key})
	return out
