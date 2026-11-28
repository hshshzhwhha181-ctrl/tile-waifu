class_name V10MjConnectSave
extends RefCounted

# Сейв Связей: G.S["v10_mj_connect"] (MODES §4.3, §7.1).
# SAVE_VER не трогаем: поле создаётся и чинится идемпотентно через st().
# Награды экран не начисляет: record() возвращает оценки для result.rewards.

const KEY: = "v10_mj_connect"
const DEFAULTS: = {
	"ver": 1,
	"level": 1,
	"stars": {},
	"best_time": {},
	"ranks_paid": 0,
	"cosmetics": [],
	"best": 0,
	"wins": 0,
	"plays": 0,
}

const RANKS: = [15, 45, 90, 150, 220]
const RANK_NAMES: = ["I", "II", "III", "IV", "V"]
const RANK_GEMS: = 30
const RANK_GIFTS: = {1: "frame_connect", 3: "title_weaver", 5: "thread_gold"}
const GIFT_NAMES: = {
	"frame_connect": "Рамка «Знак Связей»",
	"title_weaver": "Титул «Хранительница нити»",
	"thread_gold": "Золотая нить",
}
const PATH_K: = 0.5
const SALON_K: = 0.5
const HELP: = ["hint", "undo", "shuffle"]
const HELP_NAMES: = {"hint": "Подсказка", "undo": "Отмена", "shuffle": "Перемешать"}


static func st(S = null) -> Dictionary:
	if S == null:
		var tree: = Engine.get_main_loop() as SceneTree
		var g = tree.root.get_node_or_null("G") if tree and tree.root else null
		S = g.S if g and g.get("S") is Dictionary else null
	if not (S is Dictionary):
		return DEFAULTS.duplicate(true)
	var d = S.get(KEY)
	if not (d is Dictionary):
		d = DEFAULTS.duplicate(true)
		S[KEY] = d
	for k in DEFAULTS:
		if not d.has(k) or typeof(d[k]) != typeof(DEFAULTS[k]) and not (DEFAULTS[k] is int and d[k] is float):
			d[k] = DEFAULTS[k].duplicate(true) if DEFAULTS[k] is Dictionary or DEFAULTS[k] is Array else DEFAULTS[k]
	d.level = clampi(int(d.level), 1, V10MjConnectGen.COUNT)
	d.ranks_paid = clampi(int(d.ranks_paid), 0, RANKS.size())
	d.wins = maxi(0, int(d.wins))
	d.plays = maxi(0, int(d.plays))
	d.best = maxi(0, int(d.best))
	return d


static func ensure(S: Dictionary) -> Dictionary:
	return st(S)


static func stars_of(d: Dictionary, level: int) -> int:
	return int((d.stars as Dictionary).get(str(level), 0))


static func total_stars(d: Dictionary) -> int:
	var n: = 0
	for k in (d.stars as Dictionary):
		n += int(d.stars[k])
	return n


# Звёзды (MODES §4.3): время и без перемешиваний (автоперемешивание снимает звезду)
static func stars_for(win: bool, shuffles: int, time_s: int, par_s: int) -> int:
	if not win:
		return 0
	if shuffles > 0:
		return 1
	return 3 if time_s <= maxi(30, par_s) else 2


static func rank_of(sum: int) -> int:
	var r: = 0
	for t in RANKS:
		if sum >= t:
			r += 1
	return r


static func rank_text(r: int) -> String:
	return "Знак Связей %s" % RANK_NAMES[r - 1] if r > 0 and r <= RANK_NAMES.size() else "Знак Связей"


static func rank_progress(d: Dictionary) -> Dictionary:
	var sum: = total_stars(d)
	var r: = rank_of(sum)
	var need: int = RANKS[r] if r < RANKS.size() else RANKS[-1]
	return {"rank": r, "have": sum, "need": need}


static func base_reward(level: int) -> Dictionary:
	var L: = V10MjConnectGen.level(level - 1)
	var hard: = 0
	match String(L.tier):
		"hard":
			hard = 1
		"peak", "boss":
			hard = 2
	return {"coins": 40 + level * 2 + hard * 26, "aff": 2 + hard}


static func rewards(level: int, win: bool, first_clear: bool, extra_gems: = 0) -> Dictionary:
	if not win:
		return {"coins": 0, "gems": 0, "petals": 0, "aff": 0}
	var p: = base_reward(level)
	return {
		"coins": int(round(float(p.coins) * PATH_K)),
		"gems": extra_gems,
		"petals": 0,
		"aff": maxi(1, int(round(float(p.aff) * PATH_K))),
		"first_clear": first_clear,
	}


static func record(d: Dictionary, level: int, win: bool, stars: int, score: int, time_s: int) -> Dictionary:
	d.plays = int(d.plays) + 1
	var before: = stars_of(d, level)
	var out: = {"stars_gain": 0, "salon_stars": 0.0, "first_clear": false, "rank_up": 0, "gifts": [], "gems": 0}
	if not win:
		return out
	d.wins = int(d.wins) + 1
	d.best = maxi(int(d.best), score)
	out.first_clear = before == 0
	var lk: = str(level)
	if stars > before:
		d.stars[lk] = stars
		out.stars_gain = stars - before
	if time_s > 0 and (not (d.best_time as Dictionary).has(lk) or time_s < int(d.best_time[lk])):
		d.best_time[lk] = time_s
	out.salon_stars = float(out.stars_gain) * SALON_K
	if level >= int(d.level) and level < V10MjConnectGen.COUNT:
		d.level = level + 1
	var r: = rank_of(total_stars(d))
	while int(d.ranks_paid) < r:
		d.ranks_paid = int(d.ranks_paid) + 1
		out.gems = int(out.gems) + RANK_GEMS
		out.rank_up = int(d.ranks_paid)
		if RANK_GIFTS.has(int(d.ranks_paid)):
			var g: String = RANK_GIFTS[int(d.ranks_paid)]
			if not (d.cosmetics as Array).has(g):
				(d.cosmetics as Array).append(g)
			(out.gifts as Array).append(g)
	return out
