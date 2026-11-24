class_name V10Tele
extends RefCounted

# V10Tele — counters of the current week for the weekly letter (docs/0.10-spec.md Р10). Pairs and taps are counted
# in memory and written to the save at the end of the game (flush), not on every pair (§2.6).
#
#   V10Tele.note_game(r)   r from the game_ended hook: {won, mode, pairs, best_combo, secs, hard, stars, hints, undos,
#                          fever, ults, new_level, ranked, duel}. Losses and the hour are recorded only as counters
#                          that the letter NEVER uses (black list), so tests can prove they are ignored.
#   V10Tele.add(kind, n = 1)   any other counter: touches, gifts, replies, floors, outfits, daily, tasks
#   V10Tele.flush()            writes the in-memory delta to S.v10_tele.cur; rolls the week on Monday 04:00
#   V10Tele.prev_week() -> {week, c}   the finished week for V10WeekLetter

static var _mem: = {}


static func st() -> Dictionary:
	return V10RitSave.st("v10_tele")


static func _roll(key: String) -> Dictionary:
	var s: = st()
	var wk: = V10RitClock.week_key(key)
	if str(s.first_key) == "":
		s.first_key = key
	if str(s.week) != wk:
		if str(s.week) != "":
			# only the week right before this one becomes «prev»; older silence leaves prev empty
			if V10RitClock.days_between(str(s.week), wk) == 7:
				s.prev_week = str(s.week)
				s.prev = s.cur
			else:
				s.prev_week = V10RitClock.add_days(wk, -7)
				s.prev = {}
		s.week = wk
		s.cur = {}
	return s.cur


static func add(kind: String, n: = 1) -> void:
	_mem[kind] = int(_mem.get(kind, 0)) + n


static func _max(kind: String, v: int) -> void:
	_mem["max_" + kind] = maxi(int(_mem.get("max_" + kind, 0)), v)


static func _min(kind: String, v: int) -> void:
	var k: = "min_" + kind
	_mem[k] = v if not _mem.has(k) else mini(int(_mem[k]), v)


static func note_game(r: Dictionary, key: = "", hour: = -1) -> void:
	key = key if key != "" else V10RitClock.day_key()
	hour = hour if hour >= 0 else V10RitClock.local_hour()
	var won: = bool(r.get("won", false))
	add("pairs", int(r.get("pairs", 0)))
	if not won:
		add("losses")            # never used by the letter (black list)
		flush(key)
		return
	add("wins")
	if hour < 6:
		add("night_wins")        # never used by the letter (black list)
	elif hour < 12:
		add("morning")
	_max("best_combo", int(r.get("best_combo", 0)))
	if int(r.get("secs", 0)) > 0:
		_min("fast_win", int(r.get("secs", 0)))
	if bool(r.get("hard", false)):
		add("hard_wins")
	if int(r.get("stars", 0)) >= 3:
		add("stars3")
	if int(r.get("hints", 0)) == 0:
		add("no_hint_wins")
	if int(r.get("undos", 0)) == 0:
		add("no_undo_wins")
	add("fever", int(r.get("fever", 0)))
	add("ults", int(r.get("ults", 0)))
	if bool(r.get("new_level", false)):
		add("levels")
	if bool(r.get("duel", false)):
		add("duel_wins")
	_mem["mode_" + str(r.get("mode", "path"))] = 1
	_mem["day_" + key] = 1
	add("run_cur")
	flush(key)


static func flush(key: = "") -> void:
	key = key if key != "" else V10RitClock.day_key()
	var cur: = _roll(key)
	for k in _mem:
		var v: int = int(_mem[k])
		if k.begins_with("max_"):
			cur[k] = maxi(int(cur.get(k, 0)), v)
		elif k.begins_with("min_"):
			cur[k] = v if not cur.has(k) else mini(int(cur[k]), v)
		elif k.begins_with("mode_") or k.begins_with("day_"):
			cur[k] = 1
		else:
			cur[k] = int(cur.get(k, 0)) + v
	if _mem.has("losses"):
		cur["run_cur"] = 0
	cur["max_run"] = maxi(int(cur.get("max_run", 0)), int(cur.get("run_cur", 0)))
	_mem.clear()


static func prev_week(key: = "") -> Dictionary:
	key = key if key != "" else V10RitClock.day_key()
	_roll(key)
	var s: = st()
	return {"week": str(s.prev_week), "c": s.prev}


static func reset_mem() -> void:
	_mem.clear()
