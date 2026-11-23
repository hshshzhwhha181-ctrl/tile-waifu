class_name V7Ladder
extends RefCounted












# 0.8: the weekly league uses the six G.RANKS tiers (Бамбук … Небожитель) instead of Медная … Лунная.
# Group = the player + 19 players of V8Population with a close rank, picked by week and profile id (V8League).
# Promotion: top UP; demotion: bottom DOWN, never in the first league week and never below
# (the player's G.RANKS tier − 1). A week without a single table keeps the league.
# backend: socket for a future server. If set and it has group(t, prog) -> Array of rows
# {name, hero, score, me[, avatar, pid]}, its rows replace the population; submit(t, k, score, best) is called
# after every table. quarter(t) -> {rows, me} may replace the quarter table (see V8League.quarter_table).

const GROUP: = 20
const UP: = 5
const DOWN: = 3
const TABLES: = 3


const PAIR: = 10
const COMBO: = 4
const COMBO_CAP: = 10
const GOLD: = 20
const CLEAR: = 400
const TIME: = 300
const TIME_RATE: = 2.0
const CLEAN: = 150
const OVERFLOW: = 150
const BOOSTER: = 40

const LEAGUES: = [
	{"name": "Лига Бамбука", "short": "Бамбук", "color": Color("7fd18b"), "f": [0.22, 0.8], "idle": 0.3, "gems": [300, 220, 160, 90, 40]}, 
	{"name": "Лига Нефрита", "short": "Нефрит", "color": Color("3fd6b0"), "f": [0.35, 0.9], "idle": 0.22, "gems": [450, 320, 230, 130, 60]}, 
	{"name": "Лига Жемчуга", "short": "Жемчуг", "color": Color("e9e4ff"), "f": [0.5, 0.98], "idle": 0.15, "gems": [650, 460, 330, 180, 80]}, 
	{"name": "Лига Золота", "short": "Золото", "color": Color("ffc93c"), "f": [0.62, 1.04], "idle": 0.1, "gems": [900, 640, 450, 250, 110]}, 
	{"name": "Лига Дракона", "short": "Дракон", "color": Color("ff5a7a"), "f": [0.72, 1.1], "idle": 0.06, "gems": [1300, 900, 620, 340, 150]}, 
	{"name": "Лига Небожителей", "short": "Небожитель", "color": Color("c9a2ff"), "f": [0.8, 1.14], "idle": 0.04, "gems": [1700, 1200, 820, 450, 200]}, 
]

const PRIZES: = ["h_winter", "r_yukata", "o_cozy", "n_offline"]
const PRIZE_OWNED_GEMS: = 300

static var backend = null


static func now() -> float:
	return V7EventData.now_unix()

static func week_day() -> int:
	var d: = V7EventData.day_of(now())
	return d - posmod(d + 3, 7)

static func week_key(d: int) -> String:
	return "w%d" % d

static func progress_of(t: Dictionary) -> float:
	return clampf((now() - int(t.start) * 86400.0) / (7.0 * 86400.0), 0.0, 1.0)

static func left_secs() -> float:
	return (week_day() + 7) * 86400.0 - now()

static func prize_of(start_day: int) -> String:
	return PRIZES[posmod(start_day / 7, PRIZES.size())]


static func league_def(i: int) -> Dictionary:
	return LEAGUES[clampi(i, 0, LEAGUES.size() - 1)]

static func st() -> Dictionary:
	var r: = V7EventData.root()
	var t: Dictionary = r.tour
	var wd: = week_day()
	var wk: = week_key(wd)
	var migrating: = not t.is_empty() and int(t.get("v8", 0)) < 1
	if migrating:
		t["league"] = clampi(int(t.get("league", 0)), 0, LEAGUES.size() - 1)
		t["v8"] = 1
	var ls: = V8League.state()
	# 0.8: the first week is the first week played in 0.8 (the current one), also for a 0.7 player whose last
	# tournament week is stale: that week is protected from demotion, and so is the settling of the 0.7 week
	if String(ls.first_week) == "":
		ls.first_week = wk
	if t.get("week", "") != wk:
		var league: = int(t.get("league", 0))
		if t.get("week", "") != "":
			# the 0.7 week is settled as a first week too (zone_in shows no «down» for it)
			var keep: = String(ls.first_week)
			if migrating:
				ls.first_week = String(t.get("week", ""))
			league = _settle(r, t)
			ls.first_week = keep
		t = {"week": wk, "start": wd, "league": league, "group": V8League.group_seed(), "best": [0, 0, 0], "runs": 0, 
			"best_place": 0, "history": t.get("history", []), "v8": 1}
		r.tour = t
		V8League.snap_week(wk)
	return t

static func my_score(t: Dictionary) -> int:
	var n: = 0
	for b in t.best:
		n += int(b)
	return n


static func table_cfg(k: int, start_day: int) -> Dictionary:
	var shapes: = [["heart", "ring", "butterfly", "diamond"], ["cross", "towers", "pyramid", "rect"], ["butterfly", "diamond", "pyramid", "heart"]]
	var w: = start_day / 7
	var mech: String = [["gold", "", "hidden", "gold"], ["hidden", "gold,hidden", "ice", "hidden"], ["ice,gold", "gold,hidden", "ice,hidden", "gold,ice"]][k][posmod(w, 4)]
	var names: = ["Первый стол", "Второй стол", "Финальный стол"]
	var cfg: = {
		"name": "Турнир · %s" % names[k], "code": "T-%d" % (k + 1), "bg": ["bg_festival", "bg_palace", "bg_neon"][k], 
		"fx": ["lanterns", "fireflies", "rain"][k], "tint": Color(1, 1, 1), "hero": "mc", 
		"shape": shapes[k][posmod(w, 4)], "cols": [6, 6, 7][k], "rows": [7, 7, 8][k], "layers": [3, 4, 4][k], 
		"fill": [0.65, 0.65, 0.68][k], "faces": [11, 13, 15][k], "mech": mech, "hard": k, "seed": start_day * 131 + k * 7919 + 17, 
		"gold": 4 if "gold" in mech else 0, "ice": 4 if "ice" in mech else 0, "hidden": "hidden" in mech, 
		"reward": {"gems": 0}, "goal": "Очки: пары, серии, золото, скорость", 
		"intro": "Этот стол у всех один и тот же на всю неделю. В зачёт идёт лучший результат.", 
	}
	return cfg

static var _par_cache: = {}
static func table_pairs(k: int, start_day: int) -> int:
	var key: = "%d:%d" % [start_day, k]
	if not _par_cache.has(key):
		_par_cache[key] = TrayBoard.gen_layout(table_cfg(k, start_day)).size() / 2
	return int(_par_cache[key])

static func table_par(k: int, start_day: int) -> int:
	return table_pairs(k, start_day) * (PAIR + COMBO * 2) + CLEAR + CLEAN + TIME / 3

static func score_pair(combo: int, gold: bool) -> int:
	return PAIR + COMBO * mini(maxi(combo - 1, 0), COMBO_CAP) + (GOLD if gold else 0)

static func score_finish(cleared: bool, secs: float, boosters: int, overflows: int) -> Dictionary:
	var parts: = []
	if cleared:
		parts.append(["Стол очищен", CLEAR])
		parts.append(["Скорость", maxi(0, int(TIME - TIME_RATE * secs))])
		if boosters == 0 and overflows == 0:
			parts.append(["Чистая партия", CLEAN])
	if boosters > 0:
		parts.append(["Помощь ×%d" % boosters, - BOOSTER * boosters])
	if overflows > 0:
		parts.append(["Переполнения ×%d" % overflows, - OVERFLOW * overflows])
	var n: = 0
	for p in parts:
		n += int(p[1])
	return {"total": n, "parts": parts}


static func group(t: Dictionary, prog: = -1.0) -> Array:
	if prog < 0.0:
		prog = progress_of(t)
	if backend != null and backend.has_method("group"):
		var g = backend.group(t, prog)
		if g is Array and not g.is_empty():
			return g
	return V8League.group_rows(t, int(t.start) * 86400.0 + prog * 7.0 * 86400.0)

static func place_of(rows: Array) -> int:
	for i in rows.size():
		if rows[i].me:
			return i + 1
	return rows.size()


static func submit(k: int, score: int) -> Dictionary:
	var t: = st()
	var before: = place_of(group(t))
	var old: = int(t.best[k])
	t.runs = int(t.runs) + 1
	if score > old:
		t.best[k] = score
	var after: = place_of(group(t))
	if int(t.best_place) == 0 or after < int(t.best_place):
		t.best_place = after
	if backend != null and backend.has_method("submit"):
		backend.submit(t, k, score, int(t.best[k]))
	G.save()
	return {"best": int(t.best[k]), "improved": score > old, "old": old, "place_before": before, "place_after": after}

static func zone(place: int, league: int) -> String:
	return zone_in(place, league, week_key(week_day()))

static func zone_in(place: int, league: int, wk: String) -> String:
	if place <= UP and league < LEAGUES.size() - 1:
		return "up"
	if place > GROUP - DOWN and V8League.can_demote(league, wk):
		return "down"
	return ""

static func place_gems(place: int, league: int) -> int:
	var g: Array = league_def(league).gems
	if place == 1:
		return g[0]
	if place <= 3:
		return g[1]
	if place <= 5:
		return g[2]
	if place <= 10:
		return g[3]
	return g[4]


static func _settle(r: Dictionary, t: Dictionary) -> int:
	var league: = int(t.get("league", 0))
	var score: = my_score(t)
	if score <= 0:
		return league
	var rows: = group(t, 1.0)
	var place: = place_of(rows)
	var gems: = place_gems(place, league)
	var prize: String = prize_of(int(t.start))
	var prize_new: = false
	var prize_gems: = 0
	if place <= 3:
		if G.owns(prize):
			prize_gems = PRIZE_OWNED_GEMS
		else:
			G.give(prize)
			prize_new = true
	G.S.gems += gems + prize_gems
	var z: = zone_in(place, league, String(t.week))
	var nl: = league + (1 if z == "up" else (-1 if z == "down" else 0))
	nl = clampi(nl, 0, LEAGUES.size() - 1)
	var h: Array = t.get("history", [])
	h.append({"week": t.week, "league": league, "place": place, "score": score})
	while h.size() > 12:
		h.pop_front()
	r.pending.append({"type": "tour_end", "league": league, "new_league": nl, "place": place, "score": score, "gems": gems, 
		"prize": prize if place <= 3 else "", "prize_new": prize_new, "prize_gems": prize_gems, "top": rows.slice(0, 3).map( func(x): return x.name)})
	t["history"] = h
	return nl
