class_name V10Journey
extends RefCounted

# Странствие (spec R3): the weekly run of 5 boards (4 tables + the boss) on the shared modifier engine.
# One week = one seed for everyone: the same tables, the same theme, the same boss (Monday 04:00 MSK).
#
# Save: S.v10_journey = {week, attempts (used this week), best: {score, boards}, claimed: {gems, tickets, petals,
#                        pass_xp}, run: {} | {...}}
# A run: {mode:"journey", week, practice, board (0..4), hearts, bless:{id:n}, curses:{id:1}, extra_eff:[theme],
#         scores:[per board], offer:[ids], curse_offer:[ids], tricks_done}
#
#   V10Journey.week_info()                 {week, theme, boss, attempts_left, refresh_text, countdown}
#   V10Journey.start(partner, practice)    the attempt is spent HERE (spec: «списывается при старте забега»)
#   V10Journey.board_cfg(run)              the board of the week (same for every player and attempt)
#   V10Journey.board_rules(run)            V10Mods rules (normalized: base blessings only, ult at base strength)
#   V10Journey.boss_tricks(run, pairs)     the boss board: her «подлость» twice, each after a cut-in
#   V10Journey.on_overflow(run, fl)        −1 heart and the same table again (or the shield forgives)
#   V10Journey.board_clear(run, res)       board score, blessings 1 of 3, optional curse 1 of 2 (+15% score)
#   V10Journey.finish(run)                 total, tier, rewards for the best attempt of the week (once per week)

const U: = preload("res://core/modes/tower/tower_util.gd")
const M: = preload("res://core/modes/tower/mods.gd")
const D: = preload("res://core/modes/tower/mods_data.gd")

const BOARDS: = 5
const HEARTS: = 3
const TIERS: = ["Бронза", "Серебро", "Золото"]
const BASE_HELPS: = {"hint": 1, "undo": 1, "shuffle": 0}
const PAID_HELP: = false

# 8 themes of the week (calligraphy title on the scroll); `eff` is applied to every board of the week
const THEMES: = [
	{"id": "mist", "name": "Неделя тумана", "line": "Пятая часть стола в тумане, пока не снимешь 6 пар", "eff": {"fog": 1}},
	{"id": "ice", "name": "Неделя льда", "line": "Четыре фишки на каждом столе скованы льдом", "eff": {"guards": 4}},
	{"id": "lanterns", "name": "Неделя фонарей", "line": "Больше золота на столах", "eff": {"gold_extra": 4}},
	{"id": "wind", "name": "Неделя ветра", "line": "Каждый стол начинается с одной снятой пары", "eff": {"start_pairs": 1}},
	{"id": "shadow", "name": "Неделя теней", "line": "Фишки под другими лежат рубашкой вверх", "eff": {"shroud": 1}},
	{"id": "sand", "name": "Неделя песка", "line": "Песочные часы: 3 секунды на каждую фишку", "eff": {"time_per_tile": 3.0}},
	{"id": "tea", "name": "Неделя чая", "line": "Комбо держится на 1,5 с дольше", "eff": {"combo_window": 1.5}},
	{"id": "stars", "name": "Неделя звёзд", "line": "Столы больше, видов фишек больше", "eff": {"greedy": 1}},
]

# the boss's «подлость» (spec R3: from V6Duel skills); the boss board plays it twice, each after a cut-in.
# op: veil (faces of N free tiles hidden for S s), frost (N free tiles under ice), gust (faces of N free tiles
# swapped among themselves, solvability kept by TrayBoard.reassign_faces), smoke (a fog bank until P pairs)
const BOSS: = {
	"mc": {"name": "Восточный ветер", "line": "Ветер перемешал шесть свободных фишек", "op": {"op": "gust", "n": 6}},
	"rin": {"name": "Чайная церемония", "line": "Три свободные фишки покрылись инеем", "op": {"op": "frost", "n": 3}},
	"hana": {"name": "Эстафета", "line": "Четыре фишки скрылись на пять секунд", "op": {"op": "veil", "n": 4, "secs": 5.0}},
	"yue": {"name": "Лунная вуаль", "line": "Лица четырёх свободных фишек спрятаны на пять секунд", "op": {"op": "veil", "n": 4, "secs": 5.0}},
	"nova": {"name": "Перехват", "line": "Облако помех над столом, пока не снимешь 4 пары", "op": {"op": "smoke", "share": 0.25, "pairs": 4}},
	"tsubame": {"name": "Дымовая шашка", "line": "Дым над частью стола, пока не снимешь 4 пары", "op": {"op": "smoke", "share": 0.25, "pairs": 4}},
	"miel": {"name": "Глазурь", "line": "Три свободные фишки залиты глазурью", "op": {"op": "frost", "n": 3}},
	"lian": {"name": "Водоворот", "line": "Течение перемешало шесть свободных фишек", "op": {"op": "gust", "n": 6}},
	"jess": {"name": "Пыльная буря", "line": "Пыль скрыла четыре фишки на пять секунд", "op": {"op": "veil", "n": 4, "secs": 5.0}},
	"tsuru": {"name": "Пар онсэна", "line": "Пар над частью стола, пока не снимешь 4 пары", "op": {"op": "smoke", "share": 0.25, "pairs": 4}},
	"kohaku": {"name": "Лисий морок", "line": "Шесть свободных фишек поменялись местами", "op": {"op": "gust", "n": 6}},
	"shirin": {"name": "Мираж", "line": "Четыре фишки дрожат в мареве пять секунд", "op": {"op": "veil", "n": 4, "secs": 5.0}},
	"mari": {"name": "Шквал", "line": "Шквал перемешал шесть свободных фишек", "op": {"op": "gust", "n": 6}},
	"hibana": {"name": "Гром", "line": "Три свободные фишки оглушены", "op": {"op": "frost", "n": 3}},
	"nemi": {"name": "Чаща", "line": "Ветви закрыли часть стола, пока не снимешь 4 пары", "op": {"op": "smoke", "share": 0.25, "pairs": 4}},
	"zlata": {"name": "Жар-перо", "line": "Сияние скрыло четыре фишки на пять секунд", "op": {"op": "veil", "n": 4, "secs": 5.0}},
	"minamo": {"name": "Прилив", "line": "Волна перемешала шесть свободных фишек", "op": {"op": "gust", "n": 6}},
	"kira": {"name": "Помехи радара", "line": "Помехи над частью стола, пока не снимешь 4 пары", "op": {"op": "smoke", "share": 0.25, "pairs": 4}},
	"vesper": {"name": "Алая ночь", "line": "Ночь спрятала четыре фишки на пять секунд", "op": {"op": "veil", "n": 4, "secs": 5.0}},
	"sigrid": {"name": "Изморозь", "line": "Три свободные фишки покрылись инеем", "op": {"op": "frost", "n": 3}},
}
# the boss plays her trick after these shares of the board's pairs
const TRICK_AT: = [0.3, 0.6]

# difficulty of the 5 boards (tuned with the bots: expert 5/5 >= 35%, casual 10–25%, see --journey_sweep):
# per board [cols, rows, layers, faces, tiles target]; the boss board adds BOSS_ADD
const BOARD_DIFF: = [[5, 6, 3, 10, 52], [6, 6, 3, 12, 61], [6, 7, 4, 14, 70], [7, 7, 4, 16, 79], [7, 8, 5, 18, 88]]
const BOSS_ADD: = {"layers": 1, "faces": 2, "target": 10}
# the tuned step on top of BOARD_DIFF (bot sweep 2026-11-24, 100 runs per bot and preset, --journey_sweep=1):
# chosen: expert 5/5 95%, casual 17% (target 32 -> 18%; fill 0.135 -> 15–26%; fill 0.14 -> 6%; fill 0.12 -> 33%).
# Secret tiles and a little ice from the first board; the boss board adds BOSS_ADD.
const TUNED: = {"faces": 19, "layers": 2, "target": 30, "hidden_from": 0, "ice_from": 0, "fill": 0.13, "size": 1}
# selftest sweeps override this (the game never changes it)
static var tune: = TUNED.duplicate()

const DEFAULTS: = {"week": -1, "attempts": 0, "best": {"score": 0, "boards": 0}, "claimed": {}, "run": {}}

static var _test_S = null

static func save() -> Dictionary:
	return _test_S if _test_S != null else G.S

static func st() -> Dictionary:
	var S: = save()
	var d: Dictionary = S.get("v10_journey", {})
	for k in DEFAULTS:
		if not d.has(k):
			var v = DEFAULTS[k]
			d[k] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	S["v10_journey"] = d
	var wid: = U.week_id(U.now_utc())
	if int(d.week) != wid:
		# a new week: attempts, best and claims start over; an unfinished run of the old week is dropped
		d.week = wid
		d.attempts = 0
		d.best = {"score": 0, "boards": 0}
		d.claimed = {}
		d.run = {}
	return d

static func gate_index() -> int:
	for t in G.RANKS.size():
		if String(G.RANKS[t].name) == "Нефрит":
			return t * 3
	return 3

static func is_open() -> bool:
	return G.rank_index(int(save().get("rp", 0))) >= gate_index()

static func locked_text() -> String:
	return "Откроется на ранге Нефрит I"

# ---------------------------------------------------------------- the week

static func week_seed(wid: int) -> int:
	return posmod(hash("journey|%d" % wid), 1000000007)

static func theme(wid: int) -> Dictionary:
	return THEMES[posmod(wid, THEMES.size())]

# the boss: the goddess of the current banner phase when V10 banners say so (hook), else by turn among the
# released goddesses (spec R3)
static func boss(wid: int) -> String:
	var rel: = U.released()
	var ph: = String(save().get("v10_phase_hero", ""))
	if ph != "" and ph in rel:
		return ph
	return String(rel[posmod(wid, rel.size())])

static func attempts_max() -> int:
	return int(U.econ("journey.attempts"))

static func attempts_left() -> int:
	return maxi(0, attempts_max() - int(st().attempts))

static func week_info() -> Dictionary:
	var d: = st()
	var wid: = int(d.week)
	var th: = theme(wid)
	var b: = boss(wid)
	var now: = U.now_utc()
	return {"week": wid, "theme": th, "boss": b, "boss_name": U.hero_name(b), "trick": BOSS.get(b, BOSS.mc),
		"attempts_left": attempts_left(), "attempts_max": attempts_max(),
		"refresh_text": U.week_refresh_text(wid), "countdown": U.show_countdown(wid, now),
		"secs_left": U.week_end(wid) - now, "best": d.best.duplicate(),
		# the Afisha row: «Странствие · Неделя тумана · попытки 2/2 · обновится в пн, 30 ноября, 04:00 МСК»
		"afisha": "Странствие · %s · попытки %d/%d · обновится в %s" % [th.name, attempts_left(), attempts_max(), U.week_refresh_text(wid)]}

# ---------------------------------------------------------------- the run

# The attempt is spent at the start; leaving and restarting never gives more attempts. Practice: no rewards,
# no table, unlimited.
static func start(partner: String, practice: = false) -> Dictionary:
	var d: = st()
	if not practice:
		if attempts_left() <= 0:
			return {"error": "Попытки этой недели закончились. Тренировка открыта"}
		d.attempts = int(d.attempts) + 1
	var wid: = int(d.week)
	var run: = {"mode": "journey" if not practice else "practice", "week": wid, "practice": practice, "board": 0,
		"hearts": HEARTS, "partner": partner, "bless": {}, "curses": {}, "extra_eff": [theme(wid).eff],
		"scores": [], "offer": [], "curse_offer": [], "attempt": int(d.attempts)}
	# a practice run is not saved: it must never overwrite an unfinished real attempt (already paid for)
	if not practice:
		d.run = run
	return run

static func current_run() -> Dictionary:
	var d: = st()
	var r: Dictionary = d.run
	if not r.is_empty() and (int(r.get("hearts", 0)) <= 0 or int(r.get("board", 0)) >= BOARDS):
		# Auto-finalize any dead (0-heart) or already-completed run so it can never be re-entered
		finish(r)
		return {}
	return r

static func board_rules(run: Dictionary) -> Dictionary:
	var r: = M.resolve(run)
	r.lives = int(run.hearts)
	return r

static func helps(run: Dictionary) -> Dictionary:
	return M.helps(board_rules(run), BASE_HELPS)

# The 5 boards of the week: shapes and seeds from the week seed only (never from the attempt or the player).
static func board_cfg(run: Dictionary) -> Dictionary:
	return board_cfg_for(int(run.week), int(run.board), run)

static func board_cfg_for(wid: int, b: int, run: = {}) -> Dictionary:
	var ws: = week_seed(wid)
	var r: = U.rng(ws, "board%d" % b)
	var shapes: = ["rect", "heart", "diamond", "butterfly", "cross", "ring", "pyramid", "towers"]
	var boss_b: = b == BOARDS - 1
	var bh: = boss(wid)
	var bd: Array = BOARD_DIFF[clampi(b, 0, BOARD_DIFF.size() - 1)]
	var locs: Array = G.LOCS
	var L: Dictionary = locs[posmod(ws + b, locs.size())]
	var c: = {
		"name": ("Странствие · стол %d/%d" % [b + 1, BOARDS]) if not boss_b else "Странствие · %s" % U.hero_name(bh),
		"code": "", "bg": L.bg, "fx": L.fx, "tint": L.tint, "hero": String(run.get("partner", "mc")),
		"shape": shapes[r.randi() % shapes.size()], "cols": int(bd[0]) + int(tune.get("size", 0)), "rows": int(bd[1]) + int(tune.get("size", 0)),
		"layers": mini(6, int(bd[2]) + int(tune.layers) + (int(BOSS_ADD.layers) if boss_b else 0)), "fill": minf(0.92, 0.66 + 0.02 * b + float(tune.get("fill", 0.0))),
		"faces": mini(30, int(bd[3]) + int(tune.faces) + (int(BOSS_ADD.faces) if boss_b else 0)),
		"mech": "", "hard": 1 if boss_b else 0, "seed": r.randi(), "gold": 2, "ice": 0 if b < int(tune.ice_from) else 1, "hidden": b >= int(tune.hidden_from),
		"reward": {"gems": 0}, "goal": "Странствие · сердец: %d" % int(run.get("hearts", HEARTS)),
		"intro": theme(wid).line if b == 0 else ("Босс недели: %s. Её подлость: %s." % [U.hero_name(bh), String(BOSS.get(bh, BOSS.mc).name)] if boss_b else "Стол %d из %d." % [b + 1, BOARDS]),
		"mode": "journey", "seed_locked": true, "normalized": true,
	}
	var target: = int(bd[4]) + int(tune.target) + (int(BOSS_ADD.target) if boss_b else 0)
	c = V6ModesData.fit_seed(c, target, 4)
	c["v10_target"] = target
	if not run.is_empty():
		c = M.on_cfg(c, board_rules(run))
		if int(M.resolve(run).greedy) > 0:
			c = V6ModesData.fit_seed(c, int(c.v10_target), 6)
	if boss_b:
		c["boss"] = bh
		c["boss_trick"] = BOSS.get(bh, BOSS.mc).duplicate(true)
	return c

# boss board: which tricks fire after the player's `pairs` of `total` pairs (each once; run.tricks_done counts)
static func boss_tricks(run: Dictionary, pairs: int, total: int) -> Array:
	if int(run.board) != BOARDS - 1:
		return []
	var done: = int(run.get("tricks_done", 0))
	var out: = []
	for k in range(done, TRICK_AT.size()):
		if pairs >= int(ceil(float(total) * float(TRICK_AT[k]))):
			out.append(BOSS.get(boss(int(run.week)), BOSS.mc).op.duplicate(true))
			done = k + 1
	run.tricks_done = done
	return out

# an overflow: the shield forgives (the tray comes back), else −1 heart and the same table from the start
static func on_overflow(run: Dictionary, fl: Dictionary) -> Dictionary:
	var res: = M.on_overflow(board_rules(run), fl)
	if res.lose_life:
		run.hearts = maxi(0, int(run.hearts) - 1)
		run.tricks_done = 0
	res["restart"] = bool(res.lose_life) and int(run.hearts) > 0
	res["run_over"] = int(run.hearts) <= 0
	res["hearts"] = int(run.hearts)
	return res

static func on_timeout(run: Dictionary) -> Dictionary:
	run.hearts = maxi(0, int(run.hearts) - 1)
	run.tricks_done = 0
	return {"lose_life": true, "restart": int(run.hearts) > 0, "run_over": int(run.hearts) <= 0, "hearts": int(run.hearts)}

static func curse_mult(run: Dictionary) -> float:
	return 1.0 + D.JOURNEY_CURSE_BONUS * float((run.get("curses", {}) as Dictionary).size())

# score of one board: a base that grows to the boss, combo and speed, × the curses taken before it
static func board_score(b: int, secs: float, max_combo: int, run: Dictionary) -> int:
	var base: = 1200 + 150 * b + (300 if b == BOARDS - 1 else 0)
	var combo: = mini(300, 20 * max_combo)
	var speed: = maxi(0, 450 - int(secs * 2.0))
	return int(round(float(base + combo + speed) * curse_mult(run)))

# res = {secs, max_combo}; returns {score, total, boards, done, offer:[ids], curse_offer:[ids]}
static func board_clear(run: Dictionary, res: Dictionary) -> Dictionary:
	var b: = int(run.board)
	var sc: = board_score(b, float(res.get("secs", 120.0)), int(res.get("max_combo", 0)), run)
	run.scores.append(sc)
	run.board = b + 1
	run.tricks_done = 0
	var done: = int(run.board) >= BOARDS
	if not done:
		run.offer = M.offer_blessings(run, U.rng(week_seed(int(run.week)) + int(run.get("attempt", 0)) * 7919, "bless%d" % b))
		run.curse_offer = M.offer_curses(run, U.rng(week_seed(int(run.week)) + int(run.get("attempt", 0)) * 7919, "curse%d" % b))
	else:
		run.offer = []
		run.curse_offer = []
	return {"score": sc, "total": total(run), "boards": int(run.board), "done": done, "offer": run.offer, "curse_offer": run.curse_offer}

static func pick_blessing(run: Dictionary, id: String) -> bool:
	if not id in (run.get("offer", []) as Array):
		return false
	M.take_blessing(run, id)
	run.offer = []
	return true

# optional: one of two curses for +15% score on every later board
static func take_curse(run: Dictionary, id: String) -> bool:
	if not id in (run.get("curse_offer", []) as Array):
		return false
	run.curses[id] = 1
	run.curse_offer = []
	return true

static func total(run: Dictionary) -> int:
	var t: = 0
	for s in run.get("scores", []):
		t += int(s)
	return t

static func tier_of(score: int) -> int:
	var ts: Array = U.econ("journey.tier_score")
	var t: = -1
	for i in ts.size():
		if score >= int(ts[i]):
			t = i
	return t

static func tier_name(t: int) -> String:
	return TIERS[t] if t >= 0 and t < TIERS.size() else ""

# rewards owed for a (boards, score) result, as a total for the week
static func rewards_for(boards: int, score: int) -> Dictionary:
	var rw: = {}
	var g: = 0
	for bg in U.econ("journey.boards_gems"):
		if boards >= int(bg[0]):
			g = maxi(g, int(bg[1]))
	var t: = tier_of(score)
	if t >= 0:
		g += int((U.econ("journey.tier_gems") as Array)[t])
	if g > 0:
		rw.gems = g
	if boards >= BOARDS:
		rw.tickets = int(U.econ("journey.full_tickets"))
		rw.petals = int(U.econ("journey.full_petals"))
		rw.pass_xp = int(U.econ("journey.full_pass_xp"))
	return rw

# the run ends (5/5 or no hearts left). Rewards are for the BEST attempt of the week and paid once: a better
# second attempt pays only the difference. Place in the table never changes rewards.
static func finish(run: Dictionary) -> Dictionary:
	var d: = st()
	var boards: = int(run.board)
	var score: = total(run)
	var out: = {"boards": boards, "score": score, "tier": tier_of(score), "tier_name": tier_name(tier_of(score)),
		"reward": {}, "practice": bool(run.practice), "record": false}
	if bool(run.practice):
		return out
	d.run = {}
	if int(run.week) != int(d.week):
		return out
	if score > int(d.best.score) or boards > int(d.best.boards):
		out.record = score > int(d.best.score)
		d.best.score = maxi(int(d.best.score), score)
		d.best.boards = maxi(int(d.best.boards), boards)
	var owed: = rewards_for(int(d.best.boards), int(d.best.score))
	var pay: = {}
	for k in owed:
		var diff: = int(owed[k]) - int(d.claimed.get(k, 0))
		if diff > 0:
			pay[k] = diff
			d.claimed[k] = int(owed[k])
	out.reward = pay
	return out

# budget check (spec §2.3): the most a week can ever pay
static func week_budget() -> Dictionary:
	return rewards_for(BOARDS, 1 << 30)
