class_name V7Ladder
extends RefCounted












const GROUP: = 20
const UP: = 5
const DOWN: = 5
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
	{"name": "Медная лига", "short": "Медь", "color": Color("d99a6c"), "f": [0.22, 0.8], "idle": 0.3, "gems": [300, 220, 160, 90, 40]}, 
	{"name": "Серебряная лига", "short": "Серебро", "color": Color("d6dce8"), "f": [0.35, 0.9], "idle": 0.22, "gems": [450, 320, 230, 130, 60]}, 
	{"name": "Золотая лига", "short": "Золото", "color": Color("ffc93c"), "f": [0.5, 0.98], "idle": 0.15, "gems": [650, 460, 330, 180, 80]}, 
	{"name": "Нефритовая лига", "short": "Нефрит", "color": Color("3fd6b0"), "f": [0.62, 1.04], "idle": 0.1, "gems": [900, 640, 450, 250, 110]}, 
	{"name": "Лунная лига", "short": "Луна", "color": Color("c9a2ff"), "f": [0.72, 1.1], "idle": 0.06, "gems": [1300, 900, 620, 340, 150]}, 
]

const PRIZES: = ["h_winter", "r_yukata", "o_cozy", "n_offline"]
const PRIZE_OWNED_GEMS: = 300

const NAMES: = ["Сакура_77", "КотЧай", "ЛуннаяЛиса", "Тофу", "Мандаринка", "Дракончик", "Неон_Рэй", "Маття", "Кицунэ", "Бамбук", 
	"Пион", "Звёздочка", "Ветерок", "Хокку", "Мидори", "Акира", "Юки", "Сора", "Рэн", "Тихий_Пруд", "Фонарщик", "Пельмень", 
	"Чайник", "Шиба", "ОблачныйКит", "Иней", "Ласточка", "Корица", "Марципан", "Кайто", "Харуто", "Наоми", "Ирис", "Мира", 
	"Тэцу", "Лотос", "Ворон", "Кедр", "Северянка", "Momo", "Riku", "Nyan", "Ли_Мэй", "Чжу", "Ханами", "Фуго", "Данго", 
	"Капучино", "Полночь", "Синица", "Сэнсэй_Ку", "Аки", "Нори", "Рамэн", "Сливка", "Фея_пар", "Феникс", "Тануки"]

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


static func st() -> Dictionary:
	var r: = V7EventData.root()
	var t: Dictionary = r.tour
	var wd: = week_day()
	var wk: = week_key(wd)
	if t.get("week", "") != wk:
		var league: = int(t.get("league", 0))
		if t.get("week", "") != "":
			league = _settle(r, t)
		t = {"week": wk, "start": wd, "league": league, "group": randi() % 100000, "best": [0, 0, 0], "runs": 0, 
			"best_place": 0, "history": t.get("history", [])}
		r.tour = t
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


static func _bots(t: Dictionary) -> Array:
	var rng: = RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d" % [t.week, int(t.league), int(t.group)])
	var L: Dictionary = LEAGUES[int(t.league)]
	var names: Array = NAMES.duplicate()
	var out: = []
	for i in GROUP - 1:
		var ni: = rng.randi() % names.size()
		var nm: String = names[ni]
		names.remove_at(ni)
		var f: = rng.randf_range(L.f[0], L.f[1])
		var idle: = rng.randf() < float(L.idle)
		var tables: = TABLES if not idle else rng.randi_range(0, 1)
		var early: = rng.randf() < 0.5
		var ev: = []
		for k in tables:
			var tt: = rng.randf_range(0.02, 0.55) if early else rng.randf_range(0.25, 0.97)
			var pts: = int(table_par(k, int(t.start)) * f * rng.randf_range(0.86, 1.08) * (0.5 if idle else 1.0))
			if rng.randf() < 0.35:
				var imp: = int(pts * rng.randf_range(0.05, 0.15))
				ev.append([tt, pts - imp])
				ev.append([minf(0.99, tt + rng.randf_range(0.1, 0.4)), imp])
			else:
				ev.append([tt, pts])
		out.append({"name": nm, "hero": G.HERO_ORDER[rng.randi() % G.HERO_ORDER.size()], "ev": ev})
	return out

static func _bot_score(b: Dictionary, prog: float) -> int:
	var n: = 0
	for e in b.ev:
		if float(e[0]) <= prog:
			n += int(e[1])
	return n


static func group(t: Dictionary, prog: = -1.0) -> Array:
	if prog < 0.0:
		prog = progress_of(t)
	if backend != null and backend.has_method("group"):
		var g = backend.group(t, prog)
		if g is Array and not g.is_empty():
			return g
	var rows: = []
	for b in _bots(t):
		rows.append({"name": b.name, "hero": b.hero, "score": _bot_score(b, prog), "me": false})
	rows.append({"name": "Ты", "hero": G.S.partner, "score": my_score(t), "me": true})
	rows.sort_custom( func(a, b):
		if int(a.score) == int(b.score):
			return a.me
		return int(a.score) > int(b.score))
	return rows

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
	if place <= UP and league < LEAGUES.size() - 1:
		return "up"
	if place > GROUP - DOWN and league > 0:
		return "down"
	return ""

static func place_gems(place: int, league: int) -> int:
	var g: Array = LEAGUES[league].gems
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
	var z: = zone(place, league)
	var nl: = league + (1 if z == "up" else (-1 if z == "down" else 0))
	var h: Array = t.get("history", [])
	h.append({"week": t.week, "league": league, "place": place, "score": score})
	while h.size() > 12:
		h.pop_front()
	r.pending.append({"type": "tour_end", "league": league, "new_league": nl, "place": place, "score": score, "gems": gems, 
		"prize": prize if place <= 3 else "", "prize_new": prize_new, "prize_gems": prize_gems, "top": rows.slice(0, 3).map( func(x): return x.name)})
	t["history"] = h
	return nl
