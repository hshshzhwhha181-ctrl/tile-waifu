class_name V10MjTriplesSave
extends RefCounted

# Сейв Троек: G.S["v10_mj_triples"] = {level, stars, boosters_open} (+ best, wins, plays — статистика режима).
# SAVE_VER не трогаем: поле добавляется по DEFAULTS через st() (как V6ModesData.st()), регистрацию делает интегратор.
#   level          — следующий уровень к игре (1…120; после 120 остаётся 120, режим «пройдено»)
#   stars          — {"<уровень>": 0…3} лучший результат
#   boosters_open  — ["return3", "magnet", "slot", "shuffle"] — открытые бустеры (по уровням 5 / 9 / 15 / 22)

const KEY: = "v10_mj_triples"
const DEFAULTS: = {"level": 1, "stars": {}, "boosters_open": [], "best": 0, "wins": 0, "plays": 0}
const GATES: = {"return3": 5, "magnet": 9, "slot": 15, "shuffle": 22}
const ORDER: = ["return3", "magnet", "slot", "shuffle"]
const NAMES: = {"return3": "Вернуть 3", "magnet": "Магнит", "slot": "+1 ячейка", "shuffle": "Перемешать"}
const SALON_K: = 0.5
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
		if not d.has(k):
			d[k] = DEFAULTS[k].duplicate(true) if DEFAULTS[k] is Dictionary or DEFAULTS[k] is Array else DEFAULTS[k]
	d.level = clampi(int(d.level), 1, V10MjTriplesGen.COUNT)
	return d


# бустеры, открытые для этого уровня (по воротам), в порядке ряда помощи
static func open_for(level: int) -> Array:
	var out: = []
	for b in ORDER:
		if level >= int(GATES[b]):
			out.append(b)
	return out


# бустер, который открывается ровно на этом уровне (одна реплика героини, UX §2 п.7), или ""
static func new_at(level: int) -> String:
	for b in ORDER:
		if int(GATES[b]) == level:
			return b
	return ""


static func stars_of(d: Dictionary, level: int) -> int:
	return int((d.stars as Dictionary).get(str(level), 0))


static func total_stars(d: Dictionary) -> int:
	var n: = 0
	for k in (d.stars as Dictionary):
		n += int(d.stars[k])
	return n


# звёзды: ★ — стол чист; ★★ — без помощи (бустеры, Магнит, Приём не в счёт); ★★★ — и лоток ни разу не дошёл до 6
static func stars_for(win: bool, helped: bool, max_tray: int) -> int:
	if not win:
		return 0
	if helped:
		return 1
	return 3 if max_tray < 6 else 2


# награды Троек: Путь × 0,5 (вторая петля, а не замена). Базу Пути заменяет интегратор (V10Econ), здесь — оценка.
static func path_reward(level: int) -> Dictionary:
	var hard: = 0
	match V10MjTriplesGen.band_kind(level):
		"hard":
			hard = 1
		"peak":
			hard = 2
	return {"coins": 40 + level * 2 + hard * 30, "aff": 2 + hard}


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


# записать партию; возвращает {stars_gain, salon_stars, first_clear, opened: [бустеры, открытые следующим уровнем]}
static func record(d: Dictionary, level: int, win: bool, stars: int, score: int) -> Dictionary:
	d.plays = int(d.plays) + 1
	var before: = stars_of(d, level)
	var out: = {"stars_gain": 0, "salon_stars": 0.0, "first_clear": false, "opened": []}
	if not win:
		return out
	d.wins = int(d.wins) + 1
	d.best = maxi(int(d.best), score)
	out.first_clear = before == 0
	if stars > before:
		d.stars[str(level)] = stars
		out.stars_gain = stars - before
	out.salon_stars = float(out.stars_gain) * SALON_K
	if level >= int(d.level) and level < V10MjTriplesGen.COUNT:
		d.level = level + 1
	var nxt: = int(d.level)
	for b in open_for(nxt):
		if not (d.boosters_open as Array).has(b):
			(d.boosters_open as Array).append(b)
			(out.opened as Array).append(b)
	return out


static func sync_open(d: Dictionary) -> void:
	for b in open_for(int(d.level)):
		if not (d.boosters_open as Array).has(b):
			(d.boosters_open as Array).append(b)
