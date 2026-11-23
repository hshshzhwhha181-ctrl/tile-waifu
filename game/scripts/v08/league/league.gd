class_name V8League
extends RefCounted

# 0.8 weekly league + quarter table on top of V8Population.
# Public API for home / profile (Stream C, D):
#   V8League.my_week() -> {league_tier, place, points, group_size, league_name, league_short, color, zone, left_secs, played}
#   V8League.my_quarter() -> {place, total: 1001, points, key, title, left_secs}
#   V8League.quarter_table(t = -1) -> {rows: top 100 [{pid, name, hero, avatar, points, place, me}], me: {...}, total}
#   V8League.open_card(main, pid, ctx = {})   player card popup (pid = -1 for the player)
# State in the save (S.v8_league): {q, q_start_rp, first_week, q_last, q_hist}. Quarter points of the player =
# rank points earned since the start of the quarter: S.rp − q_start_rp (never below 0).

const TOTAL: = V8Population.COUNT + 1
const TOP: = 100
const ROMAN_Q: = ["I", "II", "III", "IV"]
const TXT: = {
	"week": "Неделя",
	"quarter": "Квартал",
	"quarter_title": "%s квартал %d",
	"left": "До конца: %s",
	"left_week": "До конца недели: %s",
	"of_total": "из %s",
	"pts": "%s очков",
	"rp_pts": "%s очков ранга",
	"q_note": "Очки ранга за квартал во всех режимах",
	"top": "Топ-100 квартала",
	"group": "Группа · %d игроков",
	"up_zone": "▲ зона повышения выше",
	"down_zone": "▼ зона понижения ниже",
	"no_play": "Ещё не сыграно",
	"you": "Ты",
}

static var _me_cache: = {}


static func now() -> float:
	return V7EventData.now_unix()

static func state() -> Dictionary:
	var d = G.S.get("v8_league")
	if not (d is Dictionary):
		d = {}
		G.S["v8_league"] = d
	if not d.has("q"):
		d["q"] = ""
	if not d.has("q_start_rp"):
		d["q_start_rp"] = int(G.S.get("rp", 0))
	if not d.has("first_week"):
		d["first_week"] = ""
	if not d.has("q_last"):
		d["q_last"] = {}
	if not (d.get("q_hist") is Array):
		d["q_hist"] = []
	return d

# deterministic group number for the save (kept for the backend socket and old readers)
static func group_seed() -> int:
	return posmod(hash(String(G.profile().get("id", ""))), 100000)

static func can_demote(league: int, wk: String) -> bool:
	if league <= 0:
		return false
	var ls: = state()
	if wk == String(ls.first_week) or String(ls.first_week) == "":
		return false
	var rank_tier: = int(G.rank_of(int(G.S.get("rp", 0))).tier)
	return league - 1 >= rank_tier - 1


# ---------------------------------------------------------------- week

static func group_ids(wsd: int, league: int) -> Array:
	var tiers: = V8Population.tiers_at(wsd * 86400.0)
	var rng: = RandomNumberGenerator.new()
	rng.seed = hash("g|%d|%d|%s" % [wsd, league, String(G.profile().get("id", ""))])
	var same: = []
	var near: = []
	var far: = []
	for i in tiers.size():
		var d: = absi(int(tiers[i]) - league)
		if d == 0:
			same.append(i)
		elif d == 1:
			near.append(i)
		else:
			far.append(i)
	V8Population._shuffle(same, rng)
	V8Population._shuffle(near, rng)
	V8Population._shuffle(far, rng)
	far.sort_custom(func(a, b): return absi(int(tiers[a]) - league) < absi(int(tiers[b]) - league))
	var need: = V7Ladder.GROUP - 1
	var out: = []
	var n_same: = mini(same.size(), 12 + rng.randi_range(0, 4))
	out.append_array(same.slice(0, n_same))
	out.append_array(near.slice(0, mini(near.size(), need - out.size())))
	if out.size() < need:
		out.append_array(same.slice(n_same, n_same + need - out.size()))
	if out.size() < need:
		out.append_array(far.slice(0, need - out.size()))
	return out

static func my_row(t: Dictionary) -> Dictionary:
	return {"pid": -1, "name": G.nick(), "hero": _my_hero(), "avatar": V8Population.my_avatar_img(), "score": V7Ladder.my_score(t), "me": true}

static func group_rows(t: Dictionary, at: float) -> Array:
	var wsd: = int(t.start)
	var league: = int(t.league)
	at = clampf(at, wsd * 86400.0, (wsd + 7) * 86400.0)
	var rows: = []
	for id in group_ids(wsd, league):
		var p: = V8Population.get_p(id)
		rows.append({"pid": id, "name": p.nick, "hero": p.hero, "avatar": p.avatar, "score": V8Population.week_points(id, at, league, wsd), "me": false})
	rows.append(my_row(t))
	rows.sort_custom(func(a, b):
		if int(a.score) == int(b.score):
			if a.me != b.me:
				return a.me
			return int(a.pid) < int(b.pid)
		return int(a.score) > int(b.score))
	return rows

static func my_week() -> Dictionary:
	var t: = V7Ladder.st()
	var rows: = V7Ladder.group(t)
	var place: = V7Ladder.place_of(rows)
	var L: = V7Ladder.league_def(int(t.league))
	return {"league_tier": int(t.league), "place": place, "points": V7Ladder.my_score(t), "group_size": rows.size(),
		"league_name": L.name, "league_short": L.short, "color": L.color, "zone": V7Ladder.zone(place, int(t.league)),
		"left_secs": V7Ladder.left_secs(), "played": V7Ladder.my_score(t) > 0}


# ---------------------------------------------------------------- quarter

static func _roll_quarter(t: float) -> Dictionary:
	var q: = V8Population.quarter(t)
	var ls: = state()
	if String(ls.q) != String(q.key):
		# archive the finished quarter with its final points (rp earned up to the roll; G.add_rp rolls first,
		# so nothing earned in the new quarter leaks into the old one or gets lost)
		if String(ls.q) != "":
			var fin: = maxi(0, int(G.S.get("rp", 0)) - int(ls.q_start_rp))
			var last: Dictionary = ls.q_last if ls.q_last is Dictionary else {}
			var place: = int(last.get("place", 0)) if String(last.get("q", "")) == String(ls.q) else 0
			var prev: = V8Population.quarter(float(q.start) - 1.0)
			if String(prev.key) == String(ls.q):
				place = 1 + _count_above(V8Population.quarter_rows(float(prev.end) - 1.0), fin)
			var h: Array = ls.q_hist
			h.append({"q": String(ls.q), "place": place, "points": fin})
			while h.size() > 8:
				h.pop_front()
		ls.q = q.key
		ls.q_start_rp = int(G.S.get("rp", 0))
		ls.q_last = {}
	return q

static func my_q_points() -> int:
	_roll_quarter(now())
	return maxi(0, int(G.S.get("rp", 0)) - int(state().q_start_rp))

static func quarter_title(q: Dictionary) -> String:
	return TXT.quarter_title % [ROMAN_Q[clampi(int(q.num) - 1, 0, 3)], int(q.year)]

static func quarter_table(at: = -1.0) -> Dictionary:
	if at < 0.0:
		at = now()
	var q: = _roll_quarter(at)
	var mine: = my_q_points()
	if V7Ladder.backend != null and V7Ladder.backend.has_method("quarter"):
		var b = V7Ladder.backend.quarter(at)
		if b is Dictionary and b.has("rows") and b.has("me"):
			return b
	var src: = V8Population.quarter_rows(at)
	var rows: = []
	var my_place: = 0
	var k: = 0
	while rows.size() < TOP and (k < src.size() or my_place == 0):
		if my_place == 0 and (k >= src.size() or mine >= int(src[k][1])):
			my_place = rows.size() + 1
			rows.append(_my_qrow(mine, my_place))
			continue
		var id: = int(src[k][0])
		var p: = V8Population.get_p(id)
		rows.append({"pid": id, "name": p.nick, "hero": p.hero, "avatar": p.avatar, "points": int(src[k][1]),
			"place": rows.size() + 1, "tier": V8Population.tier_at(id, at), "me": false})
		k += 1
	if my_place == 0:
		my_place = 1 + _count_above(src, mine)
	var me: = _my_qrow(mine, my_place)
	var ls: = state()
	ls.q_last = {"q": q.key, "place": my_place, "points": mine}
	return {"rows": rows, "me": me, "total": TOTAL, "q": q}

static func _count_above(src: Array, mine: int) -> int:
	var lo: = 0
	var hi: = src.size()
	while lo < hi:
		var mid: = (lo + hi) / 2
		if int(src[mid][1]) > mine:
			lo = mid + 1
		else:
			hi = mid
	return lo

static func _my_qrow(points: int, place: int) -> Dictionary:
	return {"pid": -1, "name": G.nick(), "hero": _my_hero(), "avatar": V8Population.my_avatar_img(), "points": points,
		"place": place, "tier": int(G.rank_of(int(G.S.get("rp", 0))).tier), "me": true}

static func my_quarter() -> Dictionary:
	var at: = now()
	var q: = _roll_quarter(at)
	var mine: = my_q_points()
	var place: = 1 + _count_above(V8Population.quarter_rows(at), mine)
	state().q_last = {"q": q.key, "place": place, "points": mine}
	return {"place": place, "total": TOTAL, "points": mine, "key": q.key, "title": quarter_title(q), "left_secs": float(q.end) - at}

# 0.8: one rule for every screen that shows the player's quarter place (victory, profile, modes, home):
# the place is shown only inside the top 80% of the table. Below that cut a new player sees what the points
# are for, never «#1 001 из 1 001».
const Q_SHOW_FRAC: = 0.8
const Q_HIDDEN: = "Очки ранга идут в рейтинг квартала"
const Q_HIDDEN_SHORT: = "идут в рейтинг квартала"

static func quarter_shown(q: Dictionary) -> bool:
	var place: = int(q.get("place", 0))
	var total: = int(q.get("total", TOTAL))
	return place > 0 and place <= int(total * Q_SHOW_FRAC)

# «#821 из 1 001», or "" below the cut
static func quarter_place_text(q: Dictionary) -> String:
	if not quarter_shown(q):
		return ""
	return "#%s из %s" % [UI.fmt(int(q.get("place", 0))), UI.fmt(int(q.get("total", TOTAL)))]

# quarter place (1..1001) of a population player, counting the player in
static func pop_quarter_place(id: int, at: = -1.0) -> int:
	if at < 0.0:
		at = now()
	var pts: = V8Population.rp_at(id, at)
	var place: = V8Population.quarter_place(id, at)
	if my_q_points() >= pts:
		place += 1
	return place


# ---------------------------------------------------------------- card

static func _my_hero() -> String:
	var h: = String(G.profile().get("avatar", "mc"))
	return h if G.HEROES.has(h) else "mc"

static func card_info(pid: int, ctx: = {}) -> Dictionary:
	var at: = now()
	var t: = V7Ladder.st()
	if pid < 0:
		var mq: = my_quarter()
		var ri: = G.rank_of(int(G.S.get("rp", 0)))
		return {"me": true, "name": G.nick(), "hero": _my_hero(), "avatar": V8Population.my_avatar_img(),
			"tier": int(ri.tier), "sub": int(ri.sub), "rank": String(ri.title), "league": int(t.league),
			"q_place": int(mq.place), "fav": String(G.S.get("partner", _my_hero())), "games": _my_games_week(), "week_points": V7Ladder.my_score(t)}
	var p: = V8Population.get_p(pid)
	var rr: = G.rank_of(V8Population.rank_rp(pid, at))
	var league: = int(ctx.get("league", -1))
	if league < 0:
		league = clampi(V8Population.tier_at(pid, V8Population.week_start_day(at) * 86400.0), 0, V7Ladder.LEAGUES.size() - 1)
	return {"me": false, "name": String(p.nick), "hero": String(p.hero), "avatar": String(p.avatar), "tier": int(rr.tier),
		"sub": int(rr.sub), "rank": String(rr.title), "league": league, "q_place": pop_quarter_place(pid, at),
		"fav": String(p.fav), "games": V8Population.games_week(pid, at, league), "week_points": V8Population.week_points(pid, at, league)}

# games this week: every mode reports G.record_game (Stream E); the total is snapshotted when the week starts
# (V7Ladder.st() calls snap_week on the week roll).
static func _games_total() -> int:
	var total: = 0
	var stats = G.S.get("stats", {})
	if stats is Dictionary:
		for k in stats:
			if stats[k] is Dictionary:
				total += int(stats[k].get("games", 0))
	return total

static func snap_week(wk: String) -> void:
	var ls: = state()
	if String(ls.get("gw_week", "")) != wk:
		ls["gw_week"] = wk
		ls["gw_base"] = _games_total()

static func _my_games_week() -> int:
	var t: = V7Ladder.st()
	snap_week(String(t.week))
	return maxi(_games_total() - int(state().get("gw_base", 0)), int(t.get("runs", 0)))

static func open_card(main, pid: int, ctx: = {}) -> void:
	V8PlayerCard.open(main, card_info(pid, ctx))
