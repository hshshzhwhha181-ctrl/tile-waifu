class_name V10Pagoda
extends RefCounted

# Пагода Луны (spec R2): the endless tower that replaces «Лунная лестница» (V6 climb). Pure logic + save data.
#
# Save: S.v10_pagoda = {best: {"<heat>": floors}, best_score, week: {id, floors, score, offered},
#                       miles: [5, 10, …], runs, cos: [ids], run: {} | {...}, migrated}
# A run (persisted in S.v10_pagoda.run, so leaving between floors keeps it):
#   {mode:"pagoda", floor (the floor being played, 1-based), lives, partner, seed, curses:{id:lvl} (the scroll,
#    fixed at the start), forced:{id:lvl} (the tower's own curse every 10th floor), bless:{id:n}, offer:[ids]
#    (blessings waiting to be picked), chests, petals_done, cleared, week}
#
# Flow for the play adapter / screen:
#   V10Pagoda.st()                                   save block (migrates V6 climb_best / climb_miles once)
#   V10Pagoda.is_open()                              Золото I, or the first Пик, or a 0.7–0.9 climber
#   V10Pagoda.new_run(partner, curses)               validated scroll -> run (also stored as st().run)
#   V10Pagoda.floor_cfg(run) / floor_rules(run)      board cfg (V6 floor ladder + curses) and V10Mods rules
#   V10Pagoda.on_overflow(run, fl) / on_timeout(run) a lantern goes out (or the shield forgives)
#   V10Pagoda.floor_clear(run, res)                  rewards, chest, miles, weekly offering, forced curse, offer
#   V10Pagoda.pick_blessing(run, id)                 1 of 3 after a floor
#   V10Pagoda.end_run(run)                           score = floors × (1 + 0.1 × Жар), records, cosmetics
# No paid help anywhere in the Pagoda: no continue, no paid boosters (spec R2 selftest «платной помощи нет»).

const U: = preload("res://scripts/v10/tower/tower_util.gd")
const M: = preload("res://scripts/v10/tower/mods.gd")
const D: = preload("res://scripts/v10/tower/mods_data.gd")

const BASE_HELPS: = {"hint": 1, "undo": 1, "shuffle": 1}  # per floor, before blessings / curses
const PAID_HELP: = false
const GUARD_EVERY: = 5

# cosmetics (registered in V10ProfileCos by the integrator; never sold)
const COS: = [
	{"id": "frame_moon_heat", "kind": "frame", "name": "Лунный жар", "heat": 8, "floor": 10},
	{"id": "title_pagoda_mistress", "kind": "title", "name": "Хозяйка Пагоды", "heat": 16, "floor": 15},
	{"id": "edge_pagoda_flame", "kind": "tile_edge", "name": "Пламя Пагоды", "heat": 32, "floor": 20},
]

const DEFAULTS: = {"best": {}, "best_score": 0, "week": {"id": -1, "floors": 0, "score": 0, "offered": 0, "heat": 0},
	"miles": [], "runs": 0, "cos": [], "run": {}, "migrated": false}

static var _test_S = null  # selftests inject a save dict

static func save() -> Dictionary:
	return _test_S if _test_S != null else G.S

static func st() -> Dictionary:
	var S: = save()
	var d: Dictionary = S.get("v10_pagoda", {})
	for k in DEFAULTS:
		if not d.has(k):
			var v = DEFAULTS[k]
			d[k] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	S["v10_pagoda"] = d
	if not bool(d.migrated):
		_migrate(S, d)
	return d

# 0.6–0.9 «Лунная лестница» -> Пагода: the best floor becomes the heat-0 record; the old miles count as taken
# for every new mile at or below the old best, so nothing is paid twice (spec R2 «без повторной выдачи вех»)
static func _migrate(S: Dictionary, d: Dictionary) -> void:
	d.migrated = true
	var v6: Dictionary = S.get("v6_modes", {})
	var old_best: = int(v6.get("climb_best", 0))
	var old_miles: Array = v6.get("climb_miles", [])
	var paid_to: = old_best
	for m in old_miles:
		paid_to = maxi(paid_to, int(m))
	if old_best > 0:
		d.best["0"] = maxi(int(d.best.get("0", 0)), old_best)
		d.best_score = maxi(int(d.best_score), floor_score(old_best, 0))
	for m in U.econ("pagoda.miles"):
		if int(m[0]) <= paid_to and not int(m[0]) in (d.miles as Array):
			d.miles.append(int(m[0]))
	d.runs = int(d.runs) + int(v6.get("climb_runs", 0))

static func gold_rank_index() -> int:
	for t in G.RANKS.size():
		if String(G.RANKS[t].name) == "Золото":
			return t * 3
	return 9

# Spec R2: opens at Золото I or after the first Пик. A player who already climbed in 0.6–0.9 keeps it.
static func is_open() -> bool:
	var S: = save()
	if G.rank_index(int(S.get("rp", 0))) >= gold_rank_index():
		return true
	if bool(S.get("v10_peak_first", false)) or int(S.get("v10_peaks_done", 0)) > 0:
		return true
	var v6: Dictionary = S.get("v6_modes", {})
	return int(v6.get("climb_runs", 0)) > 0 or int(v6.get("climb_best", 0)) > 0

static func locked_text() -> String:
	return "Откроется на ранге Золото I или после первого Пика"

# ---------------------------------------------------------------- run

static func new_run(partner: String, curses: Dictionary, seed_v: = -1) -> Dictionary:
	var v: = M.validate(curses)
	if not v.ok:
		return {"error": v.reason}
	var d: = st()
	var now: = U.now_utc()
	if seed_v < 0:
		seed_v = posmod(hash("pagoda|%d|%d" % [now, int(d.runs)]), 1000000)
	var run: = {"mode": "pagoda", "floor": 1, "lives": 3, "partner": partner, "seed": seed_v,
		"curses": curses.duplicate(), "forced": {}, "bless": {}, "offer": [], "chests": 0, "petals_done": false,
		"cleared": 0, "week": U.week_id(now)}
	run.lives = int(M.resolve(run).lives)
	d.runs = int(d.runs) + 1
	d.run = run
	return run

static func current_run() -> Dictionary:
	return st().run

static func has_run() -> bool:
	return not (st().run as Dictionary).is_empty()

static func heat_chosen(run: Dictionary) -> int:
	return M.heat(run.get("curses", {}))

static func floor_rules(run: Dictionary) -> Dictionary:
	return M.resolve(run)

static func is_guard(f: int) -> bool:
	return f % GUARD_EVERY == 0

const FLOOR_NAMES: = ["Нижний сад", "Чайная терраса", "Мост фонарей", "Лунная галерея", "Драконьи ступени", "Неоновый ярус"]

# the V6 floor ladder (layout growth, shapes, ice, secret tiles, guards) + the curses / blessings of the run
static func floor_cfg(run: Dictionary) -> Dictionary:
	var f: = int(run.floor)
	var compat: = {"floor": f, "seed": int(run.seed), "bless": {}, "partner": String(run.partner), "lamps": int(run.lives)}
	var c: = V6ModesData.floor_cfg(compat)
	var rules: = M.resolve(run)
	var target: = mini(28 + f * 3, 92) + (8 if is_guard(f) else 0)
	c["v10_target"] = target
	c = M.on_cfg(c, rules)
	if int(rules.greedy) > 0:
		c = V6ModesData.fit_seed(c, int(c.v10_target), 6)
	var li: = (f - 1) % FLOOR_NAMES.size()
	var guard: = is_guard(f)
	c.name = "Этаж %d%s" % [f, " · Страж" if guard else ""]
	c.goal = ("Страж этажа: сундук за победу" if guard else FLOOR_NAMES[li]) + " · фонарей: %d" % int(run.lives)
	if f == 1:
		c.intro = "Пагода Луны: переполненный лоток гасит фонарь, но этаж продолжается. Каждый пятый этаж охраняет Страж с сундуком."
	elif guard:
		c.intro = "Страж этажа: больше слоёв и тайные фишки. Сундук того стоит."
	elif f % D.FORCED_EVERY == 0:
		c.intro = "Этаж %d. Пагода разгорается: ещё одно проклятие до конца восхождения." % f
	else:
		c.intro = "Этаж %d. Благословения богинь действуют до конца восхождения." % f
	c.reward = {"gems": 0}
	c["mode"] = "pagoda"
	c["seed_locked"] = true
	return c

static func helps(run: Dictionary) -> Dictionary:
	return M.helps(M.resolve(run), BASE_HELPS)

# an overflow: fl is the floor's own state (shield use); returns {lose_life, return_n, run_over, lives}
static func on_overflow(run: Dictionary, fl: Dictionary) -> Dictionary:
	var res: = M.on_overflow(M.resolve(run), fl)
	if res.lose_life:
		run.lives = int(run.lives) - 1
	res["lives"] = int(run.lives)
	res["run_over"] = int(run.lives) <= 0
	return res

# the hourglass ran out: a lantern goes out (no shield: the shield is for overflows), the clock refills to half
static func on_timeout(run: Dictionary) -> Dictionary:
	run.lives = int(run.lives) - 1
	return {"lose_life": true, "lives": int(run.lives), "run_over": int(run.lives) <= 0, "refill": 0.5}

static func floor_score(cleared: int, h: int) -> int:
	return int(round(float(cleared) * M.mult(h) * 100.0))

# Floor cleared. res = {secs, pairs, max_combo} (informational). Returns
# {floor, reward:{gems, coins, petals}, chest, miles:[[floor, gems]], offering, record, forced:[id,lvl]|[], offer:[ids], score}
static func floor_clear(run: Dictionary, res: = {}) -> Dictionary:
	var d: = st()
	var f: = int(run.floor)
	var out: = {"floor": f, "reward": {}, "chest": false, "miles": [], "offering": 0, "forced": [], "offer": []}
	var rw: = {}
	if is_guard(f):
		out.chest = true
		run.chests = int(run.chests) + 1
		rw = U.reward_add(rw, {"coins": int(U.econ("pagoda.guard_coins_base")) + int(U.econ("pagoda.guard_coins_per_floor")) * f})
		if not bool(run.petals_done):
			run.petals_done = true
			rw = U.reward_add(rw, {"petals": int(U.econ("pagoda.guard_petals"))})
		var rules: = M.resolve(run)
		run.lives = mini(int(run.lives) + 1, int(rules.lives_max))
	for m in U.econ("pagoda.miles"):
		if f >= int(m[0]) and not int(m[0]) in (d.miles as Array):
			d.miles.append(int(m[0]))
			out.miles.append([int(m[0]), int(m[1])])
			rw = U.reward_add(rw, {"gems": int(m[1])})
	run.cleared = f
	# the week's table and the weekly offering (<= 60 gems a week, by the best floor of the week)
	var wid: = U.week_id(U.now_utc())
	if int(d.week.id) != wid:
		d.week = {"id": wid, "floors": 0, "score": 0, "offered": 0, "heat": 0}
	var h: = heat_chosen(run)
	d.week.floors = maxi(int(d.week.floors), f)
	if floor_score(f, h) > int(d.week.score):
		d.week.score = floor_score(f, h)
		d.week["heat"] = h
	var due: = 0
	for o in U.econ("pagoda.offering"):
		if int(d.week.floors) >= int(o[0]):
			due = maxi(due, int(o[1]))
	if due > int(d.week.offered):
		out.offering = due - int(d.week.offered)
		d.week.offered = due
		rw = U.reward_add(rw, {"gems": out.offering})
	out.reward = rw
	out.score = floor_score(f, h)
	out.record = f > int(d.best.get(str(h), 0))
	# the next floor; every 10th floor the tower adds a curse (shown with «вспыхнул Жар» before the floor)
	run.floor = f + 1
	if int(run.floor) % D.FORCED_EVERY == 0:
		var fc: = M.forced_curse(run, U.rng(int(run.seed), "forced%d" % int(run.floor)))
		if not fc.is_empty():
			run.forced[fc[0]] = int(fc[1])
			out.forced = fc
	run.offer = M.offer_blessings(run, U.rng(int(run.seed), "bless%d" % f))
	out.offer = run.offer
	out["cosmetics"] = _check_cos(run)
	return out

static func pick_blessing(run: Dictionary, id: String) -> bool:
	if not id in (run.get("offer", []) as Array):
		return false
	M.take_blessing(run, id)
	run.offer = []
	return true

static func skip_blessing(run: Dictionary) -> void:
	run.offer = []

# cosmetics: a run with chosen heat >= H that cleared floor >= F (both conditions, spec R2)
static func _check_cos(run: Dictionary) -> Array:
	var d: = st()
	var h: = heat_chosen(run)
	var got: = []
	for c in COS:
		if h >= int(c.heat) and int(run.cleared) >= int(c.floor) and not String(c.id) in (d.cos as Array):
			d.cos.append(String(c.id))
			got.append(String(c.id))
	return got

# the run ends (all lanterns out, or the player leaves the tower for good)
static func end_run(run: Dictionary) -> Dictionary:
	var d: = st()
	var h: = heat_chosen(run)
	var floors: = int(run.get("cleared", 0))
	var score: = floor_score(floors, h)
	var key: = str(h)
	var rec_heat: = floors > int(d.best.get(key, 0))
	if rec_heat:
		d.best[key] = floors
	var rec_score: = score > int(d.best_score)
	if rec_score:
		d.best_score = score
	d.run = {}
	return {"floors": floors, "heat": h, "mult": M.mult(h), "score": score, "record_heat": rec_heat,
		"record_score": rec_score, "cos": d.cos.duplicate(), "week_score": int(d.week.score)}

# the scroll screen: «Жар 12 · очки ×2,2»
static func heat_text(h: int) -> String:
	return "Жар %d · очки %s" % [h, U.fmt_mult(M.mult(h))]

static func best_for_heat(h: int) -> int:
	return int(st().best.get(str(h), 0))

static func cos_defs() -> Array:
	return COS.duplicate(true)
