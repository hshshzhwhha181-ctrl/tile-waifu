class_name V10MjCubeSave
extends RefCounted

# Сейв Куба: G.S["v10_mj_cube"] (SAVE_VER не трогаем: поле появляется по DEFAULTS через st(), как V6ModesData.st()).
#   level   — следующая фигура (1…40; после 40 остаётся 40)
#   stars   — {"<фигура>": 0…3} лучший результат
#   relics  — витрина: ["mc", "rin", …] — реликвии, полученные за фигуру-главу (8, 16, 24, 32, 40)
#   best, wins, plays — статистика; moves — {"<фигура>": лучший счёт ходов}
# Награды экран не начисляет: rewards() — оценка для result.rewards, начисляет интегратор (V10Econ/V10Wallet).

const KEY: = "v10_mj_cube"
const DEFAULTS: = {"level": 1, "stars": {}, "relics": [], "best": 0, "wins": 0, "plays": 0, "moves": {}}
const HELP: = ["hint", "undo", "shuffle"]
const NAMES: = {"hint": "Подсказка", "undo": "Отмена", "shuffle": "Перемешать"}
const HELP_N: = {"hint": 3, "undo": 5, "shuffle": 2}
const HELP_BOSS: = {"hint": 4, "undo": 8, "shuffle": 3}
const PATH_K: = 0.5


static func st(S = null) -> Dictionary:
	if S == null:
		S = G.S
	if not (S is Dictionary):
		return DEFAULTS.duplicate(true)
	var d = S.get(KEY)
	if not (d is Dictionary):
		d = DEFAULTS.duplicate(true)
		S[KEY] = d
	for k in DEFAULTS:
		if not d.has(k) or typeof(d[k]) != typeof(DEFAULTS[k]):
			d[k] = DEFAULTS[k].duplicate(true) if DEFAULTS[k] is Dictionary or DEFAULTS[k] is Array else DEFAULTS[k]
	d.level = clampi(int(d.level), 1, V10MjCubeShapes.COUNT)
	var clean: = []
	for h in d.relics:
		if String(h) in V10MjCubeShapes.HOSTS and not clean.has(String(h)):
			clean.append(String(h))
	d.relics = clean
	return d


static func ensure(S = null) -> Dictionary:
	return st(S)


static func help_for(level: int) -> Dictionary:
	return (HELP_BOSS if V10MjCubeShapes.is_boss(level) else HELP_N).duplicate()


static func stars_of(d: Dictionary, level: int) -> int:
	return int((d.stars as Dictionary).get(str(level), 0))


static func total_stars(d: Dictionary) -> int:
	var n: = 0
	for k in (d.stars as Dictionary):
		n += int(d.stars[k])
	return n


# stars by moves (MODES §4.4): ★ cleared; ★★ moves ≤ par2; ★★★ moves ≤ par3 (pairs + 1)
static func stars_for(win: bool, moves: int, par3: int, par2: int) -> int:
	if not win:
		return 0
	if moves <= par3:
		return 3
	if moves <= par2:
		return 2
	return 1


static func path_reward(level: int) -> Dictionary:
	var hard: = 0
	match V10MjCubeShapes.kind_of(level):
		"hard":
			hard = 1
		"boss":
			hard = 2
	return {"coins": 60 + level * 3 + hard * 30, "aff": 2 + hard}


static func rewards(level: int, win: bool, first_clear: bool) -> Dictionary:
	if not win:
		return {"coins": 0, "gems": 0, "petals": 0, "aff": 0}
	var p: = path_reward(level)
	return {
		"coins": int(round(float(p.coins) * PATH_K)),
		"gems": 0,
		"petals": 0,
		"aff": maxi(1, int(round(float(p.aff) * PATH_K))),
		"first_clear": first_clear,
	}


# the relic a figure gives on its first win: the chapter host's, only for the chapter figure (8th)
static func relic_of(level: int) -> String:
	return V10MjCubeShapes.host_of(level) if V10MjCubeShapes.is_boss(level) else ""


# write a finished match; → {stars_gain, first_clear, relic (hero id or ""), relic_new}
static func record(d: Dictionary, level: int, win: bool, stars: int, score: int, moves: int) -> Dictionary:
	d.plays = int(d.plays) + 1
	var out: = {"stars_gain": 0, "first_clear": false, "relic": "", "relic_new": false}
	if not win:
		return out
	var before: = stars_of(d, level)
	d.wins = int(d.wins) + 1
	d.best = maxi(int(d.best), score)
	out.first_clear = before == 0
	if stars > before:
		d.stars[str(level)] = stars
		out.stars_gain = stars - before
	var mk: = str(level)
	if not (d.moves as Dictionary).has(mk) or moves < int(d.moves[mk]):
		d.moves[mk] = moves
	var rel: = relic_of(level)
	if rel != "":
		out.relic = rel
		if not (d.relics as Array).has(rel):
			(d.relics as Array).append(rel)
			out.relic_new = true
	if level >= int(d.level) and level < V10MjCubeShapes.COUNT:
		d.level = level + 1
	return out


# the showcase (profile cosmetics): five relics, collected or not, and the chapter progress
static func showcase(d: Dictionary) -> Array:
	var out: = []
	for ch in V10MjCubeShapes.HOSTS.size():
		var h: String = V10MjCubeShapes.HOSTS[ch]
		var done: = 0
		for k in V10MjCubeShapes.PER:
			if stars_of(d, ch * V10MjCubeShapes.PER + k + 1) > 0:
				done += 1
		out.append({"hero": h, "name": V10MjCubeRelic.NAMES[h], "have": (d.relics as Array).has(h), "done": done,
			"of": V10MjCubeShapes.PER, "figure": (ch + 1) * V10MjCubeShapes.PER})
	return out
