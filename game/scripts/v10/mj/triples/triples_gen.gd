class_name V10MjTriplesGen
extends RefCounted

# V10MjTriplesGen — 120 уровней Троек (docs/MODES.md §4.2): 12 глав × 10, пила
#   1 лёгкий · 2 обычный · 3 обычный · 4 сложный · 5 передышка · 6 обычный · 7 сложный · 8 пик · 9 передышка · 10 босс
# Главы 1–2 без пиков (пик → сложный), боссы глав 1–4 — «сложный», 5–12 — «пик».
#
# Стол = TrayBoard.gen_layout(cfg) (те же формы и засев, что в Пути), обрезанный до кратного трём сверху.
# Рычаги сложности (одно число x ∈ [0; 1.4] на уровень):
#   kinds  — число разных лиц (меньше видов → больше случайных совпадений → легче);
#   hold   — сколько троек сертификат держит открытыми одновременно (1…3, лоток по сертификату ≤ 2·hold ≤ 6);
#   spread — как далеко по порядку снятия (и значит по ярусам) разнесены три копии;
#   dig    — доля ходов сертификата «вглубь» (копии ложатся в разные ярусы).
# Сертификат = порядок снятия, при котором лоток на 7 ни разу не переполняется. Он строится вместе с лицами
# (лица назначаются по порядку снятия) и проверяется проигрышем через V10MjTriplesRules.replay.
# Бот casual (bot_play) играет уровень RUNS раз; запекание (--triples_bake=1) подбирает сид и x так, чтобы доля его
# побед попала в полосу уровня, и пишет game/data/mj/triples/bake.json.

const CHAPTERS: = 12
const PER: = 10
const COUNT: = CHAPTERS * PER
const BAKE_PATH: = "res://data/mj/triples/bake.json"
const RUNS: = 40
const SAW: = ["easy", "normal", "normal", "hard", "rest", "normal", "hard", "peak", "rest", "boss"]
const BANDS: = {
	"easy": [0.85, 1.0],
	"normal": [0.65, 0.95],
	"hard": [0.35, 0.65],
	"peak": [0.12, 0.35],
}
const KIND_X: = {"easy": 0.05, "rest": 0.05, "normal": 0.35, "hard": 0.7, "peak": 1.0, "boss": 0.8}
const KIND_NAME: = {"easy": "Лёгкий", "normal": "Обычный", "hard": "Сложный", "peak": "Очень сложный"}

const SHAPES: = ["rect", "diamond", "heart", "butterfly", "cross", "ring", "pyramid", "towers", "hourglass", "arch",
	"flower", "bowl", "frame", "chevron", "islands", "fan", "wings", "gem"]
const BOSS_SHAPES: = ["crown", "lantern", "torii", "pagoda", "star", "moon", "fan", "flower", "gem", "wings", "heart", "butterfly"]
const UPPERS: = ["", "peak", "rows", "checker", "walls", "ring"]
# хозяйки глав — их тема лотка и героиня на краю стола, если игрок не выбрал партнёршу
const CHAPTER_HOST: = ["hana", "mc", "rin", "hana", "yue", "nova", "mc", "rin", "hana", "yue", "nova", "hana"]

static var _bake: = {}
static var _bake_loaded: = false


# ── расписание ───────────────────────────────────────────────────────────────

static func chapter_of(i: int) -> int:
	return (i - 1) / PER


static func slot_of(i: int) -> int:
	return (i - 1) % PER


static func kind_of(i: int) -> String:
	var c: = chapter_of(i)
	var k: String = SAW[slot_of(i)]
	if k == "peak" and c < 2:
		k = "hard"
	return k


# полоса бота для уровня: передышка = лёгкий; босс = сложный (главы 1–4) или пик (5–12)
static func band_kind(i: int) -> String:
	var k: = kind_of(i)
	match k:
		"rest":
			return "easy"
		"boss":
			return "hard" if chapter_of(i) < 4 else "peak"
	return k


static func band(i: int) -> Array:
	return BANDS[band_kind(i)]


static func difficulty_name(i: int) -> String:
	return KIND_NAME[band_kind(i)]


static func is_boss(i: int) -> bool:
	return slot_of(i) == PER - 1


# ── параметры ────────────────────────────────────────────────────────────────

static func params(i: int, x: float, salt: int) -> Dictionary:
	var c: = chapter_of(i)
	var k: = kind_of(i)
	var prog: = float(c) / float(CHAPTERS - 1)
	var target: = 36 + c * 6
	match k:
		"hard":
			target += 9
		"peak", "boss":
			target += 15
		"rest", "easy":
			target -= 6
	if i == 1:
		target = 27
	target = clampi(target, 24, 117)
	var shape: String
	if k == "boss":
		shape = BOSS_SHAPES[c % BOSS_SHAPES.size()]
	elif i <= 2:
		shape = "rect"
	else:
		shape = SHAPES[(i * 7 + c) % SHAPES.size()]
	var xc: = clampf(x, -0.5, 1.4)
	return {
		"i": i, "chapter": c, "kind": k, "x": xc, "salt": salt,
		"seed": 9001 + i * 131 + salt * 7919,
		"target": target, "shape": shape,
		"upper": UPPERS[(i + c) % UPPERS.size()] if c >= 1 else "",
		"layers_max": 2 + mini(3, (c + 2) / 3) + (1 if k in ["peak", "boss"] and c >= 3 else 0),
		"kinds_k": maxf(0.12, lerpf(0.34, 0.95, minf(xc, 1.0)) + 0.1 * maxf(0.0, xc - 1.0) + 0.05 * prog + 0.4 * minf(0.0, xc)),
		"hold": clampi(1 + int(round(maxf(0.0, minf(xc, 1.0)) * 2.0)), 1, 3),
		"p_open": clampf(lerpf(0.1, 0.85, minf(xc, 1.0)) + 0.1 * maxf(0.0, xc - 1.0), 0.0, 0.95),
		"spread": clampf(lerpf(0.0, 0.75, minf(xc, 1.0)) + 0.2 * maxf(0.0, xc - 1.0), 0.0, 1.0),
		"dig": clampf(lerpf(0.1, 0.7, minf(xc, 1.0)), 0.0, 0.95),
		"hidden": c >= 4 and k in ["hard", "peak", "boss"],
		"host": CHAPTER_HOST[c],
	}


# раскладка: ищем cfg TrayBoard.gen_layout, чьё число фишек ближе всего к цели, затем обрезаем до кратного 3
static var _layout_cache: = {}

static func layout(p: Dictionary) -> Array:
	var ck: = "%d|%d|%s|%s|%d" % [int(p.seed), int(p.target), p.shape, p.upper, int(p.layers_max)]
	if _layout_cache.has(ck):
		var hit: Array = _layout_cache[ck]
		p["shape_used"] = hit[1]
		return (hit[0] as Array).duplicate()
	var best: Array = []
	var best_d: = 1 << 30
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(p.seed)
	var shapes: = [String(p.shape)]
	for fb in ["rect", "diamond", "pyramid", "heart"]:
		if not shapes.has(fb):
			shapes.append(fb)
	for si in shapes.size():
		for fill in [0.7, 0.9]:
			for layers in range(2, int(p.layers_max) + 1):
				for cols in [4, 5, 6]:
					for rows in [5, 6, 7, 8, 9]:
						var cfg: = {"seed": int(p.seed), "cols": cols, "rows": rows, "layers": layers,
							"fill": fill, "shape": shapes[si], "upper": p.upper}
						var ps: Array = TrayBoard.gen_layout(cfg)
						var n: = ps.size() - ps.size() % 3
						var d: = absi(n - int(p.target)) * 4 + (0 if layers == int(p.layers_max) else 3) \
							+ absi(cols * 3 - rows * 2) + (0 if si == 0 else 100) + (0 if fill < 0.8 else 6)
						if n >= 18 and d < best_d:
							best_d = d
							best = ps
							p["shape_used"] = shapes[si]
		if best_d < 100:
			break
	# обрезка сверху (верхний ярус, затем дальний угол) до кратного трём
	var pos: Array = best.duplicate()
	while pos.size() % 3 != 0:
		var top: = 0
		for k in pos.size():
			var a: Vector3i = pos[k]
			var b: Vector3i = pos[top]
			if a.z > b.z or (a.z == b.z and a.y * 100 + a.x > b.y * 100 + b.x):
				top = k
		pos.remove_at(top)
	pos.sort_custom(func(a, b): return a.z * 100000 + a.y * 100 + a.x < b.z * 100000 + b.y * 100 + b.x)
	if _layout_cache.size() > 400:
		_layout_cache.clear()
	_layout_cache[ck] = [pos.duplicate(), String(p.get("shape_used", p.shape))]
	return pos


# полный уровень: раскладка + лица + сертификат
static func build(i: int, x: = -99.0, salt: = -1) -> Dictionary:
	if x <= -9.0 or salt < 0:
		var bk: = bake_entry(i)
		if x <= -9.0:
			x = float(bk.get("x", KIND_X[kind_of(i)]))
		if salt < 0:
			salt = int(bk.get("salt", 0))
	var p: = params(i, x, salt)
	var pos: = layout(p)
	var n: = pos.size()
	var groups_n: = n / 3
	var kinds: = clampi(int(round(groups_n * float(p.kinds_k))), mini(4, groups_n), mini(groups_n, 36))
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(p.seed) * 31 + 17
	var all: = range(36)
	# детерминированное перемешивание лиц
	for k in range(all.size() - 1, 0, -1):
		var j: = rng.randi() % (k + 1)
		var tmp = all[k]
		all[k] = all[j]
		all[j] = tmp
	var fset: Array = all.slice(0, kinds)
	var avail: = {}
	for g in groups_n:
		var f: int = fset[g % kinds]
		avail[f] = int(avail.get(f, 0)) + 3
	var base: = V10MjTriplesRules.make(pos, PackedInt32Array(range(n)))
	var hold: int = p.hold
	var cap: = mini(6, 2 * hold)
	var faces: = PackedInt32Array()
	var order: Array[int] = []
	var groups: Array = []
	for attempt in 60:
		order = base.removal_order(rng, float(p.dig))
		faces = V10MjTriplesRules.assign_greedy(order, [], 0, avail, cap, hold, float(p.p_open), float(p.spread), rng, groups)
		if not faces.is_empty():
			break
	var tile_faces: = PackedInt32Array()
	tile_faces.resize(n)
	var tile_group: = PackedInt32Array()
	tile_group.resize(n)
	for k in order.size():
		tile_faces[order[k]] = faces[k]
		tile_group[order[k]] = int(groups[k]) if k < groups.size() else 0
	return {
		"i": i, "params": p, "pos": pos, "faces": tile_faces, "groups": tile_group, "order": order,
		"n": n, "kinds": kinds, "hold": hold, "kind": kind_of(i), "band_kind": band_kind(i),
		"band": band(i), "hidden": p.hidden, "shape": String(p.get("shape_used", p.shape)), "host": p.host, "seed": p.seed,
		"ok": not faces.is_empty(),
	}


static func certificate_ok(lv: Dictionary) -> bool:
	return bool(lv.get("ok", false)) and V10MjTriplesRules.replay(lv.pos, lv.faces, lv.order, V10MjTriplesRules.SLOTS)


# группы для «Магнита»: n целых групп сертификата, самые закопанные (вытягивать спрятанное полезнее всего).
# Любые целые группы можно снять, не ломая сертификат: свобода монотонна, а лоток по сертификату только легчает.
static func magnet_groups(lv: Dictionary, n: = 3) -> Array:
	var r: = V10MjTriplesRules.make(lv.pos, lv.faces)
	var score: = {}
	for t in lv.n:
		var g: int = lv.groups[t]
		score[g] = float(score.get(g, 0.0)) + r.cnt[t] + Vector3i(lv.pos[t]).z * 0.5
	var gs: Array = score.keys()
	gs.sort_custom(func(a, b): return score[a] > score[b] or (score[a] == score[b] and a < b))
	var out: Array = []
	for g in gs.slice(0, n):
		var tri: Array = []
		for t in lv.n:
			if lv.groups[t] == g:
				tri.append(t)
		out.append(tri)
	return out


# ── бот casual ───────────────────────────────────────────────────────────────
# Видит не всё (каждая свободная фишка замечена с вероятностью SEE), иногда ошибается (SLIP — случайная фишка).
# Иначе: добить тройку → пара к одиночке в лотке → начать масть, у которой видно ≥ 2 (если есть место) → любая.
const SEE: = 0.72
const SLIP: = 0.1

static func bot_play(r0: V10MjTriplesRules, rng: RandomNumberGenerator) -> bool:
	var r: = r0.clone()
	var guard: = 0
	while not r.won and not r.lost and guard < 1000:
		guard += 1
		var fr: = r.frees
		if fr.is_empty():
			return false
		var seen: Array[int] = []
		for t in fr:
			if rng.randf() < SEE:
				seen.append(t)
		if seen.is_empty():
			seen.append(fr[rng.randi() % fr.size()])
		var pick_i: = -1
		if rng.randf() < SLIP:
			pick_i = seen[rng.randi() % seen.size()]
		else:
			var tc: = {}
			for t in r.tray:
				tc[r.face[t]] = int(tc.get(r.face[t], 0)) + 1
			var vis: = {}
			for t in seen:
				var f: = r.face[t]
				if not vis.has(f):
					vis[f] = []
				(vis[f] as Array).append(t)
			var room: = r.slots - r.tray.size()
			for want in [2, 1]:
				if pick_i >= 0:
					break
				for f in vis:
					if int(tc.get(f, 0)) == want and (want == 2 or room >= 2):
						pick_i = vis[f][0]
						break
			if pick_i < 0 and room >= 3:
				for f in vis:
					if (vis[f] as Array).size() >= 2 and int(tc.get(f, 0)) == 0:
						pick_i = vis[f][0]
						break
			if pick_i < 0:
				pick_i = seen[rng.randi() % seen.size()]
		r.pick(pick_i)
	return r.won


static func bot_rate(lv: Dictionary, runs: = RUNS) -> float:
	var r: = V10MjTriplesRules.make(lv.pos, lv.faces)
	var wins: = 0
	for k in runs:
		var rng: = RandomNumberGenerator.new()
		rng.seed = int(lv.i) * 100003 + k * 7717 + 5
		if bot_play(r, rng):
			wins += 1
	return float(wins) / float(runs)


# ── запекание ────────────────────────────────────────────────────────────────

static func calibrate(i: int, log_cb: Callable = Callable()) -> Dictionary:
	var b: = band(i)
	var x: float = KIND_X[kind_of(i)]
	var best: = {}
	var best_d: = INF
	for it in 30:
		var lv: = build(i, x, it)
		if not certificate_ok(lv):
			continue
		var rate: = bot_rate(lv)
		var mid: = (float(b[0]) + float(b[1])) * 0.5
		var d: = 0.0
		if rate < float(b[0]):
			d = float(b[0]) - rate
		elif rate > float(b[1]):
			d = rate - float(b[1])
		var e: = {"i": i, "x": snappedf(x, 0.001), "salt": it, "rate": rate, "n": lv.n, "kinds": lv.kinds,
			"hold": lv.hold, "shape": lv.shape, "kind": lv.kind, "band": b, "in_band": d == 0.0,
			"cert": lv.order.size()}
		if d + absf(rate - mid) * 0.01 < best_d:
			best_d = d + absf(rate - mid) * 0.01
			best = e
		if d == 0.0:
			break
		# шаг к полосе: легче — вниз, тяжелее — вверх
		var stp: = clampf(d * 0.9, 0.05, 0.25)
		x = clampf(x + (stp if rate > float(b[1]) else -stp), -0.5, 1.4)
	if log_cb.is_valid():
		log_cb.call(best)
	return best


static func bake(path: = BAKE_PATH, log_cb: Callable = Callable()) -> Dictionary:
	var levels: Array = []
	var miss: = 0
	for i in range(1, COUNT + 1):
		var e: = calibrate(i, log_cb)
		levels.append(e)
		if not bool(e.get("in_band", false)):
			miss += 1
	var d: = {"version": 1, "runs": RUNS, "see": SEE, "slip": SLIP, "count": COUNT, "miss": miss, "levels": levels}
	var abs_path: = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f: = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))
		f.close()
	_bake = {}
	_bake_loaded = false
	return d


static func bake_data() -> Dictionary:
	if not _bake_loaded:
		_bake_loaded = true
		_bake = {}
		if FileAccess.file_exists(BAKE_PATH):
			var j = JSON.parse_string(FileAccess.get_file_as_string(BAKE_PATH))
			if j is Dictionary:
				_bake = j
	return _bake


static func bake_entry(i: int) -> Dictionary:
	var d: = bake_data()
	var lv: Array = d.get("levels", [])
	if i >= 1 and i <= lv.size() and lv[i - 1] is Dictionary:
		return lv[i - 1]
	return {}
