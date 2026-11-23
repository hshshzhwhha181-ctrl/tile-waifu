class_name V8LeagueSelftest
extends RefCounted

# Headless checks for the 0.8 population and leagues: --league_selftest=1 (exit code 1 on failure).
# Works on a throw-away G.S (default state); the real save is never written (G.demo is on while it runs).
# Prints the weekly group at Monday 00:30, Monday 12:00, Wednesday 12:00 and Sunday 20:00 of a fixed week.

static var bad: = 0
static var total: = 0

const WEEK_MON: = "2026-11-23"
const MY_ID: = "5eed0001"


static func _check(name: String, ok: bool, info: = "") -> void:
	total += 1
	if not ok:
		bad += 1
		printerr("LEAGUE FAIL %s %s" % [name, info])

static func _ts(s: String) -> float:
	return float(Time.get_unix_time_from_datetime_string(s))


static func run() -> int:
	bad = 0
	total = 0
	var saved_s: Dictionary = G.S
	var saved_demo: bool = G.demo
	var saved_backend = V7Ladder.backend
	G.demo = true
	V7Ladder.backend = null
	G.S = G.default_state()
	G.S.profile.id = MY_ID
	G.S.profile.nick = "Тестер"
	G.S.profile_done = true
	G.S.rp = 600
	_population()
	_week()
	_quarter()
	_fresh_quarter()
	_migration()
	_settle()
	_api()
	G.S = saved_s
	G.demo = saved_demo
	V7Ladder.backend = saved_backend
	V8Population._tiers.clear()
	V8Population._rows.clear()
	var line: = "LEAGUE SELFTEST %d/%d" % [total - bad, total]
	print(line)
	printerr(line)
	return bad


# ---------------------------------------------------------------- population

static func _population() -> void:
	var pop: = V8Population.all()
	_check("population size", pop.size() == V8Population.COUNT)
	var seen: = {}
	var dup: = 0
	var bad_len: = 0
	var bad_word: = 0
	var counts: = [0, 0, 0, 0, 0, 0]
	var heroes: = {}
	var latin: = 0
	for p in pop:
		var n: String = p.nick
		if seen.has(n.to_lower()):
			dup += 1
		seen[n.to_lower()] = true
		if n.length() < 3 or n.length() > 16:
			bad_len += 1
		var low: = n.to_lower()
		if not V8Population._clean(n) or "бот" in low or "bot" in low or "ИИ" in n or n == "AI" or "AI_" in n:
			bad_word += 1
		counts[int(p.tier)] += 1
		heroes[p.hero] = int(heroes.get(p.hero, 0)) + 1
		var lat: = true
		for ch in n:
			if ch.unicode_at(0) >= 0x400 and ch.unicode_at(0) <= 0x4ff:
				lat = false
		if lat:
			latin += 1
		_check("avatar exists %s" % p.avatar, ResourceLoader.exists("res://assets/outfits/%s.webp" % p.avatar))
	_check("nicks unique", dup == 0, "dups=%d" % dup)
	_check("nick length 3..16", bad_len == 0, "bad=%d" % bad_len)
	_check("nicks clean (no rank/heroine names, no bot marks)", bad_word == 0, "bad=%d" % bad_word)
	_check("tier counts", counts == V8Population.TIER_COUNT, str(counts))
	_check("many low, few high", counts[0] + counts[1] > 500 and counts[4] + counts[5] < 120, str(counts))
	_check("russian and latin nicks mixed", latin > 250 and latin < 750, "latin=%d" % latin)
	_check("all heroines used", heroes.size() == G.HERO_ORDER.size(), str(heroes))
	_check("deterministic", V8Population.nick(17) == String(pop[17].nick))
	var sample: = []
	for i in range(0, 1000, 25):
		sample.append(String(pop[i].nick))
	print("LEAGUE nicks: " + ", ".join(sample))
	print("LEAGUE base tiers %s · latin %d · heroes %s" % [str(counts), latin, str(heroes)])
	var q: = V8Population.quarter(_ts(WEEK_MON + "T12:00:00"))
	for label in ["start", "mid", "end"]:
		var at: float = float(q.start) + 3600.0 if label == "start" else ((float(q.start) + float(q.end)) * 0.5 if label == "mid" else float(q.end) - 60.0)
		var tc: = [0, 0, 0, 0, 0, 0]
		for t in V8Population.tiers_at(at):
			tc[int(t)] += 1
		print("LEAGUE rank distribution at quarter %s: %s" % [label, str(tc)])
		if label == "mid":
			_check("mid-quarter: Бамбук+Нефрит is the largest share", tc[0] + tc[1] > tc[3] + tc[4] + tc[5], str(tc))


# ---------------------------------------------------------------- week

static func _table(title: String, rows: Array) -> void:
	print("LEAGUE ---- %s ----" % title)
	for i in rows.size():
		var r: Dictionary = rows[i]
		var tier: = -1 if r.me else V8Population.tier_at(int(r.pid), _ts(WEEK_MON + "T00:00:00"))
		print("LEAGUE %2d. %-18s %-10s %6d%s" % [i + 1, String(r.name), "—" if tier < 0 else String(G.RANKS[tier].name), int(r.score), "  ← ты" if r.me else ""])

static func _week() -> void:
	var t0: = _ts(WEEK_MON + "T00:00:00")
	var wsd: = V8Population.week_start_day(t0)
	_check("fixed week starts on Monday", wsd * 86400.0 == t0)
	var league: = 1
	var t: = {"week": V7Ladder.week_key(wsd), "start": wsd, "league": league, "best": [0, 0, 0], "runs": 0, "best_place": 0, "history": [], "v8": 1}
	var ids: = V8League.group_ids(wsd, league)
	_check("group has 19 others", ids.size() == V7Ladder.GROUP - 1, str(ids.size()))
	var uniq: = {}
	for id in ids:
		uniq[id] = true
	_check("group ids unique", uniq.size() == ids.size())
	_check("group deterministic", V8League.group_ids(wsd, league) == ids)
	var near: = 0
	for id in ids:
		if absi(V8Population.tier_at(id, t0) - league) <= 1:
			near += 1
	_check("group close rank (±1 tier)", near == ids.size(), "%d/%d" % [near, ids.size()])
	var other: = V8League.group_ids(wsd + 7, league)
	var same: = 0
	for id in other:
		if uniq.has(id):
			same += 1
	_check("next week gives a new group", same < 10, "overlap %d" % same)
	G.S.profile.id = "0000beef"
	var ids2: = V8League.group_ids(wsd, league)
	G.S.profile.id = MY_ID
	_check("another player id gives another group", ids2 != ids)
	var times: = [["Понедельник 00:30", WEEK_MON + "T00:30:00", [0, 0, 0]], ["Понедельник 12:00", WEEK_MON + "T12:00:00", [900, 0, 0]],
		["Среда 12:00", "2026-11-25T12:00:00", [1250, 1100, 0]], ["Воскресенье 20:00", "2026-11-29T20:00:00", [1400, 1350, 1500]]]
	var nonzero: = []
	for tm in times:
		t.best = tm[2]
		var rows: = V8League.group_rows(t, _ts(tm[1]))
		_table("Лига %s · %s" % [V7Ladder.league_def(league).short, tm[0]], rows)
		_check("rows %s: 20 rows" % tm[0], rows.size() == V7Ladder.GROUP)
		var nz: = 0
		var sorted_ok: = true
		for i in rows.size():
			if int(rows[i].score) > 0 and not rows[i].me:
				nz += 1
			if i > 0 and int(rows[i].score) > int(rows[i - 1].score):
				sorted_ok = false
			if int(rows[i].score) < 0:
				sorted_ok = false
		nonzero.append(nz)
		_check("rows %s sorted, no negatives" % tm[0], sorted_ok)
	print("LEAGUE non-zero rivals: Mon 00:30 %d, Mon 12:00 %d, Wed %d, Sun %d (of 19)" % nonzero)
	var nine: = 0
	for id in ids:
		if V8Population.week_points(id, _ts(WEEK_MON + "T09:00:00"), league) > 0:
			nine += 1
	print("LEAGUE non-zero rivals Monday 09:00: %d of 19" % nine)
	_check("Monday morning most rivals already have points", nine >= 10, "%d" % nine)
	_check("Monday noon most rivals have points", nonzero[1] >= 12, str(nonzero[1]))
	_check("Wednesday nearly everyone has points", nonzero[2] >= 16, str(nonzero[2]))
	_check("points grow during the week", true)
	var worst_jump: = 0.0
	var mono: = true
	for id in ids:
		var prev: = 0
		var fin: = maxi(1, V8Population.week_points(id, t0 + 7 * 86400.0, league, wsd))
		for s in range(0, 7 * 96 + 1):
			var v: = V8Population.week_points(id, t0 + s * 900.0, league, wsd)
			if v < prev:
				mono = false
			worst_jump = maxf(worst_jump, float(v - prev) / fin)
			prev = v
	_check("week points monotonic", mono)
	_check("week points smooth (max 15-min step < 6% of the week)", worst_jump < 0.06, "%.3f" % worst_jump)
	print("LEAGUE biggest 15-minute step: %.2f%% of a weekly total" % (worst_jump * 100.0))
	var top_end: = V8League.group_rows(t, t0 + 7 * 86400.0)
	var par: = 0
	for k in V7Ladder.TABLES:
		par += V7Ladder.table_par(k, wsd)
	print("LEAGUE week par %d · end of week: 1st %d, 5th %d, 15th %d" % [par, int(top_end[0].score), int(top_end[4].score), int(top_end[14].score)])
	_check("week end scores in a sane range", int(top_end[0].score) < par * 1.4 and int(top_end[0].score) > par * 0.4)


# ---------------------------------------------------------------- quarter

static func _quarter() -> void:
	var at: = _ts(WEEK_MON + "T12:00:00")
	var q: = V8Population.quarter(at)
	_check("quarter key", String(q.key) == "2026Q4", String(q.key))
	_check("quarter start", float(q.start) == _ts("2026-10-01T00:00:00"))
	_check("quarter end", float(q.end) == _ts("2027-01-01T00:00:00"))
	var mono: = true
	var zero_start: = true
	var worst: = 0.0
	for id in range(0, 1000, 20):
		var prev: = 0
		if V8Population.rp_at(id, float(q.start)) != 0:
			zero_start = false
		# 0.8: late starters (V8Population.q_join) play a shorter quarter at their usual pace, so a step is measured
		# against the player's full-quarter pace (q_total), not against their smaller final total
		var fin: = maxi(1, int(V8Population.q_total(id, String(q.key))))
		var s: = float(q.start)
		while s < float(q.end):
			var v: = V8Population.rp_at(id, s)
			if v < prev:
				mono = false
			worst = maxf(worst, float(v - prev) / fin)
			prev = v
			s += 3 * 3600.0
	_check("quarter rp starts at 0", zero_start)
	_check("quarter rp monotonic", mono)
	_check("quarter rp smooth (3-hour step < 1.5% of the quarter pace)", worst < 0.015, "%.4f" % worst)
	var sum_night: = 0
	var sum_eve: = 0
	for id in range(0, 1000, 5):
		sum_night += V8Population.rp_at(id, _ts(WEEK_MON + "T05:00:00")) - V8Population.rp_at(id, _ts(WEEK_MON + "T03:00:00"))
		sum_eve += V8Population.rp_at(id, _ts(WEEK_MON + "T21:00:00")) - V8Population.rp_at(id, _ts(WEEK_MON + "T19:00:00"))
	_check("daily rhythm: evening busier than night", sum_eve > sum_night * 3, "night %d eve %d" % [sum_night, sum_eve])
	G.S.rp = 5000
	V8League.state().q = String(q.key)
	V8League.state().q_start_rp = 4000
	var qt: = V8League.quarter_table(at)
	var rows: Array = qt.rows
	_check("quarter top-100", rows.size() == V8League.TOP)
	var sorted_ok: = true
	for i in range(1, rows.size()):
		if int(rows[i].points) > int(rows[i - 1].points) or int(rows[i].place) != i + 1:
			sorted_ok = false
	_check("quarter rows sorted with places", sorted_ok)
	_check("quarter total 1001", int(qt.total) == 1001)
	_check("my quarter points", int(qt.me.points) == 1000, str(qt.me.points))
	var src: = V8Population.quarter_rows(at)
	var above: = 0
	for r in src:
		if int(r[1]) > 1000:
			above += 1
	_check("my quarter place", int(qt.me.place) == above + 1, "%d vs %d" % [int(qt.me.place), above + 1])
	print("LEAGUE quarter %s at %s: 1st %s %d · 10th %d · 100th %d · median %d · me #%d with %d" % [q.key, WEEK_MON, rows[0].name, int(rows[0].points), int(rows[9].points), int(rows[99].points), int(src[500][1]), int(qt.me.place), int(qt.me.points)])
	V8League.state().q_start_rp = 5000 - int(src[0][1]) - 10
	var qt2: = V8League.quarter_table(at)
	_check("me on top of the quarter", int(qt2.me.place) == 1 and bool(qt2.rows[0].me))
	_check("me listed once in top-100", qt2.rows.filter(func(x): return x.me).size() == 1 and qt2.rows.size() == 100)
	G.S.rp = 600


# A fresh player: quarter points = all rank points since the quarter start (q_start_rp = 0). With one or a few
# wins they land among the late starters of the quarter, never last of 1 001 (some players have not played yet).
static func _fresh_quarter() -> void:
	var q: = V8Population.quarter(_ts(WEEK_MON + "T12:00:00"))
	var qs: = float(q.start)
	var days: = (float(q.end) - qs) / 86400.0
	for d in [1.0, 3.0, 7.0, 30.0, 53.0, days - 0.5]:
		var at: float = qs + float(d) * 86400.0
		var src: = V8Population.quarter_rows(at)
		var zeros: = src.filter(func(x): return int(x[1]) == 0).size()
		_check("quarter day %d: someone has not played yet" % int(d), zeros >= 10, str(zeros))
		var one: = 1 + V8League._count_above(src, 18)
		var few: = 1 + V8League._count_above(src, 60)
		print("LEAGUE fresh player at quarter day %d: one win (18) #%d, three wins (60) #%d, not started %d" % [int(d), one, few, zeros])
		_check("quarter day %d: one win is never last" % int(d), one < V8League.TOTAL - 5, str(one))
		_check("quarter day %d: more wins, better place" % int(d), few <= one)
		if d <= 7.0:
			_check("quarter day %d: a few wins early is not the very top" % int(d), few > 10, str(few))
	G.S.erase("v8_league")
	G.S.rp = 0
	var ls: = V8League.state()
	_check("fresh player quarter starts at 0 rp", int(ls.q_start_rp) == 0)
	G.S.rp = 600


# ---------------------------------------------------------------- migration

static func _migration() -> void:
	var names: = ["Бамбук", "Нефрит", "Жемчуг", "Золото", "Дракон"]
	for old in 5:
		G.S.erase("v7_event")
		G.S.erase("v8_league")
		var r: = V7EventData.root()
		var wd: = V7Ladder.week_day()
		r.tour = {"week": V7Ladder.week_key(wd), "start": wd, "league": old, "group": 4242, "best": [0, 0, 0], "runs": 0, "best_place": 0, "history": []}
		var t: = V7Ladder.st()
		_check("migrate league %d keeps index" % old, int(t.league) == old)
		_check("migrate league %d → %s" % [old, names[old]], String(V7Ladder.league_def(int(t.league)).short) == names[old])
		_check("migrate league %d flagged" % old, int(t.get("v8", 0)) == 1)
		_check("migrate league %d first week set" % old, String(V8League.state().first_week) == String(t.week))
	G.S.erase("v7_event")
	G.S.erase("v8_league")
	var r2: = V7EventData.root()
	var wd2: = V7Ladder.week_day()
	r2.tour = {"week": V7Ladder.week_key(wd2 - 7), "start": wd2 - 7, "league": 3, "group": 77, "best": [0, 0, 0], "runs": 0, "best_place": 0, "history": []}
	var t2: = V7Ladder.st()
	_check("old 0.7 week rolls over into 0.8 week", String(t2.week) == V7Ladder.week_key(wd2) and int(t2.league) == 3)
	# a 0.7 player whose last tournament week is stale and who finished it at the bottom: neither that week
	# nor the first 0.8 week demotes (rp 600 = Жемчуг, so league 3 could otherwise drop to 2)
	G.S.erase("v7_event")
	G.S.erase("v8_league")
	G.S.rp = 600
	var r3: = V7EventData.root()
	r3.tour = {"week": V7Ladder.week_key(wd2 - 14), "start": wd2 - 14, "league": 3, "group": 77, "best": [1, 0, 0], "runs": 1, "best_place": 0, "history": []}
	var t3: = V7Ladder.st()
	_check("stale 0.7 week: settled without demotion", int(t3.league) == 3, str(t3.league))
	_check("stale 0.7 week: current week is the first week", String(V8League.state().first_week) == String(t3.week))
	_check("stale 0.7 week: no demotion this week", not V8League.can_demote(3, String(t3.week)) and V7Ladder.zone_in(20, 3, String(t3.week)) == "")
	var pend3: Array = r3.pending
	_check("stale 0.7 week: result shown, league kept", pend3.size() == 1 and int(pend3[0].new_league) == 3)
	_check("6 leagues on G.RANKS", V7Ladder.LEAGUES.size() == G.RANKS.size())
	for i in G.RANKS.size():
		_check("league %d named after rank" % i, String(V7Ladder.LEAGUES[i].short) == String(G.RANKS[i].name))


# ---------------------------------------------------------------- settle

static func _past(league: int, best: Array) -> Dictionary:
	var wd: = V7Ladder.week_day() - 7
	return {"week": V7Ladder.week_key(wd), "start": wd, "league": league, "group": 0, "best": best, "runs": 1, "best_place": 0, "history": [], "v8": 1}

static func _settle() -> void:
	G.S.erase("v7_event")
	G.S.erase("v8_league")
	var r: = V7EventData.root()
	var ls: = V8League.state()
	ls.first_week = "w1"
	G.S.rp = 200
	var nl: = V7Ladder._settle(r, _past(1, [99999, 99999, 99999]))
	_check("top place promotes", nl == 2, str(nl))
	nl = V7Ladder._settle(r, _past(5, [99999, 99999, 99999]))
	_check("no promotion above Небожитель", nl == 5, str(nl))
	nl = V7Ladder._settle(r, _past(2, [1, 0, 0]))
	_check("bottom-3 demotes", nl == 1, str(nl))
	nl = V7Ladder._settle(r, _past(2, [0, 0, 0]))
	_check("a week without play keeps the league", nl == 2, str(nl))
	G.S.rp = 1000
	nl = V7Ladder._settle(r, _past(2, [1, 0, 0]))
	_check("no demotion below rank tier − 1", nl == 2, "rank tier %d, league %d" % [int(G.rank_of(1000).tier), nl])
	nl = V7Ladder._settle(r, _past(3, [1, 0, 0]))
	_check("demotion down to rank tier − 1 allowed", nl == 2, str(nl))
	G.S.rp = 200
	var p: = _past(2, [1, 0, 0])
	ls.first_week = p.week
	nl = V7Ladder._settle(r, p)
	_check("no demotion in the first week", nl == 2, str(nl))
	_check("down zone hidden in the first week", V7Ladder.zone_in(20, 2, p.week) == "")
	ls.first_week = "w1"
	_check("down zone shown otherwise", V7Ladder.zone_in(20, 2, p.week) == "down")
	_check("down zone only bottom-3", V7Ladder.zone_in(17, 2, p.week) == "" and V7Ladder.zone_in(18, 2, p.week) == "down")
	_check("up zone top-5", V7Ladder.zone_in(5, 2, p.week) == "up" and V7Ladder.zone_in(6, 2, p.week) == "")
	var pend: Array = r.pending
	_check("settle writes week results", pend.size() >= 5 and String(pend[0].type) == "tour_end")


# ---------------------------------------------------------------- API

static func _api() -> void:
	G.S.erase("v7_event")
	G.S.erase("v8_league")
	G.S.rp = 600
	var w: = V8League.my_week()
	for k in ["league_tier", "place", "points", "group_size"]:
		_check("my_week has %s" % k, w.has(k))
	_check("my_week group 20", int(w.group_size) == 20)
	var q: = V8League.my_quarter()
	for k in ["place", "total", "points"]:
		_check("my_quarter has %s" % k, q.has(k))
	_check("my_quarter total", int(q.total) == 1001)
	_check("my_quarter place range", int(q.place) >= 1 and int(q.place) <= 1001)
	print("LEAGUE my_week %s" % str(w))
	print("LEAGUE my_quarter %s" % str(q))
	var c: = V8League.card_info(7)
	for k in ["name", "avatar", "tier", "league", "q_place", "fav", "games"]:
		_check("card has %s" % k, c.has(k))
	_check("card has no AI mark", not ("ИИ" in str(c)) and not ("бот" in str(c).to_lower()))
	var me: = V8League.card_info(-1)
	_check("my card", bool(me.me) and String(me.name) == "Тестер")
	print("LEAGUE card #7 %s" % str(c))
