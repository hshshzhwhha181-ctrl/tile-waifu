class_name V10LevelGen
extends RefCounted

# 0.10 «Путь на 1000 партий»: a deterministic generator for 10 worlds x 100 levels.
#
#  level(i)  -> the level dict (TrayBoard cfg + map metadata), no board payload — cheap, for the map screen.
#  build(i)  -> level(i) + "v10" board payload (faces/steps/ice/secret/gold/shard/specials per tile, aligned with
#               TrayBoard.setup tile order) + "cert" (a take order that clears the board under the real rules).
#
# Same index + same salt => byte-identical level on every device (own RNG, own hash; TrayBoard.gen_layout is
# seeded from cfg.seed). The salt table (data/v10/levels/levels_bake.json) is written by the bake run of the
# selftest: the bot picks, per level, the seed that lands in the tier's pass-rate band (CEO_PLAN §3).
#
# Curve («пила» per chapter of 10, CEO_PLAN §3, IDEAS 5.2):
#   pos 1 easy · 2 normal · 3 normal · 4 hard · 5 easy (breather) · 6 normal · 7 hard · 8 PEAK very hard ·
#   9 normal (breather) · 10 BOSS (hard → very hard → legendary at 50 and 100 of a world).

const Sim = preload("res://scripts/v10/levels/level_sim.gd")

const VERSION: = 1
const WORLDS: = 10
const PER_WORLD: = 100
const CHAPTER: = 10
const TOTAL: = WORLDS * PER_WORLD
const BAKE_PATH: = "res://data/v10/levels/levels_bake.json"

const TIERS: = ["tutorial", "easy", "normal", "hard", "very_hard", "legendary"]
const TIER_NAMES: = {"tutorial": "Обучение", "easy": "Лёгкий", "normal": "Обычный", "hard": "Сложный",
	"very_hard": "Очень сложный", "legendary": "Легендарный"}
# index into G.HARD_NAMES ["", "Сложный", "Очень сложный"] for the existing badges
const TIER_HARD: = {"tutorial": 0, "easy": 0, "normal": 0, "hard": 1, "very_hard": 2, "legendary": 2}
# target pass rate of the «regular» bot (proxy for CEO_PLAN bands: training 90-98, hard 35-50, very hard 15-30,
# legendary 5-15 — the bot is a proxy, real bands come from telemetry)
const BANDS: = {"tutorial": [0.90, 1.0], "easy": [0.85, 1.0], "normal": [0.65, 0.95], "hard": [0.35, 0.65],
	"very_hard": [0.12, 0.35], "legendary": [0.03, 0.15]}
const SAW: = ["easy", "normal", "normal", "hard", "easy", "normal", "hard", "very_hard", "normal", "boss"]

# board parameters per tier: [min, max] interpolated by progress through the 1000 levels
const TP: = {
	"tutorial": {"layers": [2, 2], "rows": [6, 6], "cols": [5, 5], "fill": [0.70, 0.70], "nf": [5, 6], "D": 1, "open": [0.0, 0.0], "old": 0.0, "strict": [0.0, 0.0], "dig": 0.0, "min": 18},
	"easy": {"layers": [2, 3], "rows": [6, 8], "cols": [5, 6], "fill": [0.65, 0.75], "nf": [6, 12], "D": 2, "open": [0.10, 0.25], "old": 0.3, "strict": [0.0, 0.15], "dig": 0.1, "min": 26},
	"normal": {"layers": [3, 4], "rows": [7, 8], "cols": [6, 6], "fill": [0.65, 0.80], "nf": [10, 18], "D": 2, "open": [0.25, 0.40], "old": 0.5, "strict": [0.25, 0.45], "dig": 0.2, "min": 36},
	"hard": {"layers": [3, 5], "rows": [8, 9], "cols": [6, 6], "fill": [0.75, 0.85], "nf": [16, 28], "D": 3, "open": [0.35, 0.50], "old": 0.7, "strict": [0.60, 0.80], "dig": 0.3, "min": 48},
	"very_hard": {"layers": [4, 5], "rows": [9, 9], "cols": [6, 6], "fill": [0.80, 0.90], "nf": [24, 36], "D": 3, "open": [0.45, 0.60], "old": 0.85, "strict": [0.85, 0.95], "dig": 0.4, "min": 58},
	"legendary": {"layers": [5, 5], "rows": [9, 9], "cols": [6, 6], "fill": [0.85, 0.95], "nf": [28, 34], "D": 3, "open": [0.40, 0.50], "old": 0.9, "strict": [0.85, 0.9], "dig": 0.5, "min": 66},
}

const SHAPES_ALL: = ["rect", "heart", "diamond", "butterfly", "cross", "ring", "pyramid", "towers",
	"hourglass", "arch", "flower", "crown", "bowl", "lantern", "frame", "chevron", "star", "torii", "islands",
	"moon", "fan", "pagoda", "gem", "wings"]
const UPPERS: = ["", "peak", "walls", "checker", "rows", "ring"]

# world = arc of 100 levels. art reuses the 0.6 backdrops until the new ones land (see README).
const WORLD: = [
	{"name": "Чайный сад", "hero": "mc", "shard": "rin", "bg": "play", "fx": "petals", "art": "w1",
		"shapes": ["rect", "heart", "flower", "butterfly", "hourglass", "arch", "diamond"], "sig": {"gold": 3, "gift": 2, "ice": 1, "hidden": 1},
		"guests": ["mc", "rin", "hana"], "legend": "Партия с хозяйкой"},
	{"name": "Чайная во льду", "hero": "rin", "shard": "rin", "bg": "bg_teahouse", "fx": "snow", "art": "w2",
		"shapes": ["lantern", "frame", "cross", "ring", "star", "rect", "pyramid"], "sig": {"ice": 4, "lock": 3, "gold": 1, "chain": 1},
		"guests": ["rin", "tsuru", "sigrid"], "legend": "Чайная церемония Рин"},
	{"name": "Фестиваль фонарей", "hero": "hana", "shard": "hana", "bg": "bg_festival", "fx": "lanterns", "art": "w3",
		"shapes": ["fan", "islands", "chevron", "heart", "towers", "butterfly", "lantern"], "sig": {"gift": 3, "chain": 3, "bomb": 2, "gold": 1},
		"guests": ["hana", "miel", "hibana"], "legend": "Забег Ханы"},
	{"name": "Лунный дворец", "hero": "yue", "shard": "yue", "bg": "bg_palace", "fx": "fireflies", "art": "w4",
		"shapes": ["moon", "gem", "wings", "pyramid", "ring", "diamond", "bowl"], "sig": {"hidden": 4, "gold": 2, "joker": 2, "lock": 1},
		"guests": ["yue", "lian", "minamo"], "legend": "Лунный суд Юэ"},
	{"name": "Драконье святилище", "hero": "mc", "shard": "yue", "bg": "bg_shrine", "fx": "mist", "art": "w5",
		"shapes": ["torii", "arch", "pagoda", "towers", "cross", "crown", "gem"], "sig": {"lock": 3, "chain": 3, "ice": 2, "hidden": 1},
		"guests": ["mc", "kohaku", "tsubame"], "legend": "Пробуждение дракона"},
	{"name": "Неоновая ночь", "hero": "nova", "shard": "nova", "bg": "bg_neon", "fx": "rain", "art": "w6",
		"shapes": ["chevron", "frame", "flower", "star", "rect", "wings", "islands"], "sig": {"hidden": 3, "ice": 3, "gold": 2, "bomb": 1},
		"guests": ["nova", "kira", "jess"], "legend": "Взлом Новы"},
	{"name": "Храм Тысячи врат", "hero": "kohaku", "shard": "kohaku", "bg": "bg_shrine", "fx": "petals", "art": "w7",
		"shapes": ["torii", "pagoda", "lantern", "crown", "cross", "fan", "hourglass"], "sig": {"lock": 4, "joker": 2, "chain": 2, "gift": 1},
		"guests": ["kohaku", "tsubame", "nemi"], "legend": "Тысяча врат Кохаку"},
	{"name": "Жемчужный дворец", "hero": "minamo", "shard": "minamo", "bg": "bg_palace", "fx": "fireflies", "art": "w8",
		"shapes": ["bowl", "moon", "ring", "flower", "gem", "islands", "heart"], "sig": {"ice": 4, "chain": 3, "gold": 2, "hidden": 1},
		"guests": ["minamo", "mari", "lian"], "legend": "Жемчужный суд Минамо"},
	{"name": "Алая ночь", "hero": "vesper", "shard": "vesper", "bg": "bg_neon", "fx": "rain", "art": "w9",
		"shapes": ["wings", "crown", "star", "frame", "towers", "chevron", "diamond"], "sig": {"hidden": 4, "lock": 3, "chain": 2, "ice": 1},
		"guests": ["vesper", "shirin", "hibana"], "legend": "Бал графини Веспер"},
	{"name": "Царство Жар-птицы", "hero": "zlata", "shard": "zlata", "bg": "bg_festival", "fx": "lanterns", "art": "w10",
		"shapes": ["fan", "flower", "wings", "pagoda", "crown", "star", "heart"], "sig": {"gold": 2, "ice": 2, "hidden": 2, "lock": 2, "chain": 2, "gift": 1},
		"guests": ["zlata", "sigrid", "kira"], "legend": "Жар-птица"},
]

# new mechanic every 15-30 levels (IDEAS 5.2); the intro level carries only that mechanic and a calm tier.
# index -> mechanic (0-based level index)
const INTRO: = {15: "gold", 30: "ice", 50: "gift", 70: "hidden", 100: "lock", 125: "chain", 150: "joker",
	180: "bomb", 210: "lock2", 240: "chain_long", 270: "ice_heavy", 300: "starset"}
const INTRO_LINES: = {
	"gold": "Золотые фишки — дар луны: каждая золотая пара приносит больше кристаллов.",
	"ice": "Перевёртыш лежит рубашкой вверх: первое касание переворачивает, второе берёт в лоток.",
	"gift": "Пара с бантом — шкатулка с подарком внутри.",
	"hidden": "Тайные фишки покажут лицо, только когда ты их освободишь.",
	"lock": "Под замком фишку не взять. Собери пару с ключом того же цвета.",
	"chain": "Число на цепи — сколько пар убрать, и она спадёт сама.",
	"joker": "Джокер встаёт в пару к любой фишке в лотке.",
	"bomb": "Хлопушка в паре сносит до трёх соседних пар.",
	"lock2": "Теперь замков два цвета — и у каждого свой ключ.",
	"chain_long": "Длинные цепи: считай пары заранее.",
	"ice_heavy": "Целый стол перевёртышей. Запоминай, что открыла.",
	"starset": "Звёздный набор: почти все фишки разные. Думай на два хода вперёд.",
}
# helpers make a board easier: only on calm tiers
const HELPERS: = ["joker", "bomb"]
const COSMETIC: = ["gold", "gift"]
const MECH_COUNT: = {"tutorial": [0, 0], "easy": [0, 1], "normal": [1, 2], "hard": [1, 2], "very_hard": [2, 3], "legendary": [2, 3]}

static var _bake: = {}
static var _bake_loaded: = false


# ------------------------------------------------------------------ public

static func count() -> int:
	return TOTAL


static func world_of(i: int) -> int:
	return i / PER_WORLD


static func code(i: int) -> String:
	return "%d-%d" % [i / PER_WORLD + 1, i % PER_WORLD + 1]


static func tier_of(i: int) -> String:
	var w: = i / PER_WORLD
	var l: = i % PER_WORLD
	var c: = l / CHAPTER
	var p: = l % CHAPTER
	if w == 0 and l < 6:
		return "tutorial"
	if l == PER_WORLD - 1 or (w >= 2 and l == 49):
		return "legendary"
	var t: String = SAW[p]
	if t == "boss":
		t = "hard" if c < 4 else "very_hard"
	if INTRO.has(i) and TIERS.find(t) > TIERS.find("normal"):
		t = "normal"
	if w == 0:
		# the first arc ramps in: no peaks before chapter 3
		if c < 2:
			t = {"hard": "normal", "very_hard": "normal"}.get(t, t)
		elif c == 2:
			t = {"very_hard": "hard"}.get(t, t)
	return t


# The bot pass rate the bake aims for: inside the tier band, drifting from its upper to its lower part over the
# 10 arcs, so every arc is a little harder than the last at the same tier.
static func target_rate(i: int) -> float:
	var b: Array = BANDS[tier_of(i)]
	var w: = float(i / PER_WORLD) / float(WORLDS - 1)
	return lerpf(float(b[0]), float(b[1]), 0.65 - 0.3 * w)


static func is_boss(i: int) -> bool:
	return i % CHAPTER == CHAPTER - 1


static func is_peak(i: int) -> bool:
	return i % CHAPTER == 7 and tier_of(i) == "very_hard"


static func salt_of(i: int) -> int:
	_load_bake()
	var s: Array = _bake.get("salt", [])
	return int(s[i]) if i < s.size() else 0


static func baked_metrics(i: int) -> Dictionary:
	_load_bake()
	var m: Array = _bake.get("metrics", [])
	return m[i] if i < m.size() and m[i] is Dictionary else {}


static func set_bake(d: Dictionary) -> void:
	_bake = d
	_bake_loaded = true


static func _load_bake() -> void:
	if _bake_loaded:
		return
	_bake_loaded = true
	_bake = {}
	if not FileAccess.file_exists(BAKE_PATH):
		return
	var txt: = FileAccess.get_file_as_string(BAKE_PATH)
	var d = JSON.parse_string(txt)
	if d is Dictionary and int(d.get("version", 0)) == VERSION:
		_bake = d


# mechanics introduced strictly before level i (plus the one introduced at i)
static func mechs_known(i: int) -> Array:
	var out: = []
	for k in INTRO:
		if int(k) <= i:
			out.append(INTRO[k])
	return out


# The level dict: everything the map screen and TrayBoard.setup need, no per-tile payload.
static func level(i: int, salt: int = -1, assist: bool = false) -> Dictionary:
	return _level(i, salt, assist)[0]


# [level dict, positions] — build() reuses the positions the tile-count fit already computed
static func _level(i: int, salt: int, assist: bool = false) -> Array:
	if i < 0 or i >= TOTAL:
		# a «next level» past the last arc must not crash the map / play screen (WORLD[w] out of range)
		push_error("V10LevelGen: level index %d out of 0..%d" % [i, TOTAL - 1])
		i = clampi(i, 0, TOTAL - 1)
	if salt < 0:
		salt = salt_of(i)
	var w: = i / PER_WORLD
	var l: = i % PER_WORLD
	var c: = l / CHAPTER
	var p: = l % CHAPTER
	var W: Dictionary = WORLD[w]
	var tier: = tier_of(i)
	var rng: = RandomNumberGenerator.new()
	rng.seed = _hash(i * 7919 + salt * 104729 + VERSION * 13 + 1 + (999331 if assist else 0))
	var g: = float(i) / float(TOTAL - 1)
	# «облегчённая раздача» after two fails (CEO_PLAN №4): the same level and mechanics, board parameters two
	# tiers calmer (an unbaked seed varies a lot, one step is not reliably easier)
	var ptier: = tier
	if assist:
		ptier = TIERS[maxi(1, TIERS.find(tier) - 2)]
	var T: Dictionary = TP[ptier]
	var boss: = is_boss(i)
	var legend: = tier == "legendary"

	var shape: String
	if boss:
		shape = ["crown", "lantern", "torii", "bowl", "wings", "star", "pagoda", "gem", "moon", "flower"][(c + w * 3) % 10]
	else:
		var pool: Array = W.shapes
		shape = pool[rng.randi() % pool.size()] if rng.randf() < 0.8 else SHAPES_ALL[rng.randi() % SHAPES_ALL.size()]
	var upper: String = ""
	if tier in ["hard", "very_hard", "legendary"]:
		upper = ["peak", "walls", "checker", "rows", "ring"][rng.randi() % 5]
	elif tier == "normal" and rng.randf() < 0.5:
		upper = ["peak", "rows", "checker"][rng.randi() % 3]
	var j: = rng.randf() * 0.25 - 0.125
	var layers: = int(round(_lerp2(T.layers, clampf(g + j, 0.0, 1.0))))
	if tier == "tutorial" and not assist:
		layers = 1 if l < 3 else 2   # first taps on a flat table
	var rows: = int(round(_lerp2(T.rows, clampf(g + j, 0.0, 1.0))))
	var cols: = int(round(_lerp2(T.cols, clampf(g + j, 0.0, 1.0))))
	var fill: = snappedf(_lerp2(T.fill, clampf(g + j, 0.0, 1.0)), 0.01)
	var nf: = int(round(_lerp2(T.nf, clampf(g + j, 0.0, 1.0))))
	if boss and tier != "legendary":
		layers = mini(layers + 1, 6)
	var openp: = _lerp2(T.open, clampf(g + j, 0.0, 1.0))
	var strict: = _lerp2(T.strict, clampf(g + j, 0.0, 1.0))

	# mechanics
	var known: = mechs_known(i)
	var mech: = []
	if INTRO.has(i):
		mech.append(INTRO[i])
	else:
		var lo_hi: Array = MECH_COUNT[tier]
		var want: = rng.randi_range(int(lo_hi[0]), int(lo_hi[1]))
		var cand: = []
		for m in known:
			var base: String = _base_mech(m)
			if base in HELPERS and tier in ["hard", "very_hard", "legendary"]:
				continue
			var wt: = 1.0 + float(W.sig.get(base, 0))
			# freshly introduced mechanics are practised for ~12 levels
			for k in INTRO:
				if INTRO[k] == m and i - int(k) > 0 and i - int(k) <= 12:
					wt += 6.0
			if m in ["lock2", "chain_long", "ice_heavy", "starset"]:
				wt *= 0.6
			cand.append([m, wt])
		for _k in want:
			if cand.is_empty():
				break
			var tot: = 0.0
			for cw in cand:
				tot += float(cw[1])
			var r: = rng.randf() * tot
			for ci in cand.size():
				r -= float(cand[ci][1])
				if r <= 0.0 or ci == cand.size() - 1:
					mech.append(cand[ci][0])
					cand.remove_at(ci)
					break
	if "starset" in mech:
		nf = 36
	var base_mech: = []
	for m in mech:
		var b: = _base_mech(m)
		if not b in base_mech:
			base_mech.append(b)

	var gold: int = (4 + 2 * (w / 2)) if "gold" in base_mech else 0
	var ice: = 0
	if "ice" in base_mech:
		ice = 3 + w
		if "ice_heavy" in mech:
			ice = 10 + w
	var hidden: bool = "hidden" in base_mech
	var plan: = {"gift": 0, "lock": 0, "lock_n": 1, "chain": 0, "joker": 0, "bomb": 0, "event": i >= 20, "streak": i > 0,
		"pool": ["starfall", "giftdrop"] if i < 100 else ["starfall", "giftdrop", "wind", "golden", "challenge"]}
	if "gift" in base_mech or boss:
		plan.gift = 1 + int(boss)
	if "lock" in base_mech:
		plan.lock = 2 if "lock2" in mech else 1
		plan.lock_n = 1 + int(tier in ["very_hard", "legendary"] or "lock2" in mech)
	if "chain" in base_mech:
		plan.chain = 2 if ("chain_long" in mech or tier in ["very_hard", "legendary"]) else 1
	if "joker" in base_mech:
		plan.joker = 1
	if "bomb" in base_mech:
		plan.bomb = 1
	if tier == "tutorial" or tier == "legendary":
		plan.event = false

	var guests: Array = W.guests
	var boss_hero: String = W.hero if (legend or c == CHAPTER - 1) else str(guests[c % guests.size()])
	var title: = ""
	if legend:
		title = str(W.legend) if l == PER_WORLD - 1 else "Легенда: %s" % W.name
	elif boss:
		title = "Босс главы %d" % (c + 1)
	# 0.10-spec §2.3: Path pays crystals on the FIRST clear only — 2 + 2×★, Сложный +3, Очень сложный +6,
	# Пик 30, Легендарный 150 (the chapter chest is a separate source). `gems` excludes the star part.
	# The old per-win formula (100 + 2i, up to ~2600 per replayable win) would blow the 400/day free cap.
	var gems: int = 2 + {"tutorial": 0, "easy": 0, "normal": 0, "hard": 3, "very_hard": 6, "legendary": 0}[tier]
	if is_peak(i):
		gems = 30
	elif legend:
		gems = 150

	var mech_flags: = []
	for m in ["gold", "ice", "hidden"]:
		if m in base_mech:
			mech_flags.append(m)
	var out: = {
		"v10": {}, "v10_id": i, "v10_version": VERSION, "v10_salt": salt, "assist": assist,
		"code": code(i), "world": w, "num": l + 1, "chapter": c, "pos": p,
		"name": str(W.name), "loc": w, "stage": l, "bg": W.bg, "fx": W.fx, "art": W.art,
		"hero": ready_hero(str(W.hero), w), "shard": ready_hero(str(W.shard), w), "hero_v10": W.hero, "shard_v10": W.shard,
		"tier": tier, "tier_name": TIER_NAMES[tier], "hard": TIER_HARD[tier],
		"boss": boss, "peak": is_peak(i), "legend": legend, "boss_hero": ready_hero(boss_hero, w) if boss or legend else "",
		"boss_hero_v10": boss_hero if boss or legend else "", "boss_title": title,
		"intro": INTRO.get(i, ""), "intro_line": INTRO_LINES.get(INTRO.get(i, ""), ""),
		"shape": shape, "cols": cols, "rows": rows, "layers": layers, "fill": fill, "faces": nf, "upper": upper,
		"seed": _hash(i * 31 + salt * 7 + 5 + (7777 if assist else 0)) % 1000000007,
		"mech": ",".join(mech_flags), "mechs": mech, "gold": gold, "ice": ice, "hidden": hidden,
		"v10_plan": plan, "D": int(T.D), "open": snappedf(openp, 0.01), "old": float(T.old),
		"strict": snappedf(strict, 0.01), "dig": float(T.dig),
		"reward": {"gems": gems, "per_star": 2, "first_only": true},
		# CEO_PLAN №4 / 0.10-spec П1: the assist deal is offered after 2 fails, but never on Peaks and Legendary
		"assist_ok": not (is_peak(i) or legend),
	}
	var pos: = _fit_tiles(out, int(T.min))
	return [out, pos]


# Grow small boards up to the tier's minimum tile count (shapes and upper patterns can thin a layout a lot).
static func _fit_tiles(lv: Dictionary, need: int) -> Array:
	var pos: = positions(lv)
	var n: = pos.size()
	var step: = 0
	while n < need and step < 6:
		match step:
			0:
				lv.fill = minf(0.95, float(lv.fill) + 0.1)
			1:
				lv.layers = mini(int(lv.layers) + 1, 6)
			2:
				lv.rows = 9
				lv.cols = 6
			3:
				lv.upper = ""
			4:
				# a fuller silhouette of the same family before the plain plateau
				lv.shape = ["heart", "diamond", "pyramid", "towers", "butterfly"][int(lv.seed) % 5]
			5:
				lv.shape = "rect"
		step += 1
		pos = positions(lv)
		n = pos.size()
	lv["tiles"] = n
	return pos


# Heroines with art and a rig in the build today (G.HEROES / Hero.RIGS). Roster-20 heroines are kept in the *_v10
# fields and swapped in by adding them here once their art lands; until then each arc falls back to a founder.
const READY_HEROES: = ["mc", "rin", "hana", "yue", "nova"]
const FALLBACK: = ["mc", "rin", "hana", "yue", "mc", "nova", "yue", "rin", "nova", "hana"]


static func ready_hero(id: String, w: int) -> String:
	return id if id in READY_HEROES else str(FALLBACK[w])


static func _base_mech(m: String) -> String:
	match m:
		"lock2":
			return "lock"
		"chain_long":
			return "chain"
		"ice_heavy":
			return "ice"
		"starset":
			return ""
	return m


static func _lerp2(a: Array, t: float) -> float:
	return lerpf(float(a[0]), float(a[1]), t)


static func _hash(x: int) -> int:
	var h: = (x + 0x9E3779B9) & 0xFFFFFFFF
	h = ((h ^ (h >> 16)) * 0x85EBCA6B) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 0xC2B2AE35) & 0xFFFFFFFF
	h = (h ^ (h >> 16)) & 0x7FFFFFFF
	return h


# Positions exactly as TrayBoard.setup builds its `tiles` (gen_layout, drop the first top-most tile when odd, sort).
static func positions(cfg: Dictionary) -> Array:
	var pos: Array = TrayBoard.gen_layout(cfg)
	if pos.size() % 2 == 1:
		var top: = 0
		for k in pos.size():
			if pos[k].z > pos[top].z:
				top = k
		pos.remove_at(top)
	pos.sort_custom( func(a, b): return a.z * 100000 + a.y * 100 + a.x < b.z * 100000 + b.y * 100 + b.x)
	return pos


# Full level with the per-tile payload. `sim` may be passed in to reuse buffers (the selftest does).
static func build(i: int, salt: int = -1, sim = null, assist: bool = false) -> Dictionary:
	var lvp: = _level(i, salt, assist)
	var lv: Dictionary = lvp[0]
	var pos: Array = lvp[1]
	if sim == null:
		sim = Sim.new()
	sim.build(pos)
	sim.tag = "%d:%d:%d:%d" % [int(lv.v10_id), int(lv.v10_salt), int(lv.seed), int(assist)]
	var n: int = sim.n
	var rng: = RandomNumberGenerator.new()
	rng.seed = _hash(int(lv.seed) * 3 + 77)

	# 1) a removal order: a free tile each step (any such order is a valid take order); with probability `dig`
	#    the most recently freed tile, which digs into stacks instead of peeling the board evenly
	sim.reset()
	var order: = PackedInt32Array()
	var digp: float = lv.dig
	while order.size() < n:
		var fr: PackedInt32Array = sim.freel
		var t: int = fr[rng.randi() % fr.size()]
		if rng.randf() < digp:
			for x in fr:
				if sim.free_since[x] > sim.free_since[t]:
					t = x
		sim.clock = order.size() + 1
		order.append(t)
		sim.remove(t)
	var fsince: PackedInt32Array = sim.free_since.duplicate()
	var take_at: = PackedInt32Array()
	take_at.resize(n)
	for k in n:
		take_at[order[k]] = k

	# 2) pair the order with a bounded tray: open (hold) / close (pair with a held tile). «Strict» closes pick a
	#    held tile that was taken before this one became free — then the two never lie free together, so the
	#    player has to hold tiles in the tray instead of spotting pairs (CEO_PLAN §3: «глубина лотка»).
	var D: int = lv.D
	var openp: float = lv.open
	var oldp: float = lv.old
	var strict: float = lv.strict
	var held: = []
	var partner: = PackedInt32Array()
	partner.resize(n)
	partner.fill(-1)
	var open_cnt: = PackedInt32Array()   # tiles held before order[k] is taken
	open_cnt.resize(n)
	var exposed: = 0
	for k in n:
		var t: = order[k]
		open_cnt[k] = held.size()
		var rem: = n - k - 1
		var sc: = []
		for hi in held.size():
			if fsince[t] > take_at[held[hi]]:
				sc.append(hi)
		var do_open: bool
		if held.is_empty():
			do_open = true
		elif held.size() >= D or rem < held.size() + 1:
			do_open = false
		elif sc.is_empty():
			do_open = rng.randf() < maxf(openp, strict)
		else:
			do_open = rng.randf() < openp
		if do_open:
			held.append(t)
		else:
			var ch: = []
			if not sc.is_empty() and rng.randf() < strict:
				ch = sc
			else:
				for hi in held.size():
					ch.append(hi)
			var hi: int = ch[0] if rng.randf() < oldp else ch[rng.randi() % ch.size()]
			var o: int = held[hi]
			held.remove_at(hi)
			partner[t] = o
			partner[o] = t
			if fsince[t] <= take_at[o]:
				exposed += 1

	# 3) faces: each pair gets a face that no held tile shows when it opens; strict levels also keep two pairs of
	#    one face from ever lying free (or free + in the tray) at the same time
	var nf: = clampi(int(lv.faces), 4, 36)
	var pool: = []
	for f in 36:
		pool.append(f)
	_shuffle(pool, rng)
	pool = pool.slice(0, nf)
	var last_end: = {}
	for f in pool:
		last_end[f] = -1
	var face: = PackedInt32Array()
	face.resize(n)
	face.fill(-1)
	var step: = PackedInt32Array()
	step.resize(n)
	var cur: = PackedInt32Array()
	var fp: = 0
	var nstep: = 0
	var done_before: = PackedInt32Array()  # pairs completed before order[k]
	done_before.resize(n)
	var done: = 0
	var overlaps: = 0
	for k in n:
		var t: = order[k]
		done_before[k] = done
		var o: = partner[t]
		if take_at[o] > k:
			# opening tile: its pair is visible from `start` until its closer is taken
			var start: = mini(fsince[t], fsince[o])
			var end: = take_at[o]
			var f: = -1
			if rng.randf() < strict:
				for q in nf:
					var cf: int = pool[(fp + q) % nf]
					if int(last_end[cf]) < start and not cur.has(cf):
						f = cf
						fp += q + 1
						break
			if f < 0:
				var tries: = 0
				f = pool[fp % nf]
				while cur.has(f) and tries < nf:
					fp += 1
					tries += 1
					f = pool[fp % nf]
				fp += 1
				if int(last_end[f]) >= start:
					overlaps += 1
			last_end[f] = maxi(int(last_end[f]), end)
			face[t] = f
			face[o] = f
			cur.append(f)
			step[t] = nstep
			step[o] = nstep
			nstep += 1
		else:
			cur.remove_at(cur.find(face[t]))
			done += 1
	var npairs: = n / 2

	# 4) shard / gold / ice / hidden — the same rules as TrayBoard._assign, on certificate pairs
	var closing: = []   # pairs in completion order: [opener, closer]
	for k in n:
		var t: = order[k]
		if take_at[partner[t]] < k:
			closing.append([partner[t], t])
	var shard: = PackedByteArray()
	shard.resize(n)
	var gold: = PackedByteArray()
	gold.resize(n)
	var ice: = PackedByteArray()
	ice.resize(n)
	var secret: = PackedByteArray()
	secret.resize(n)
	var shard_pair: = -1
	if str(lv.get("shard", "")) != "" and npairs > 4:
		shard_pair = npairs - 2 - rng.randi() % 3
		for t in closing[shard_pair]:
			shard[t] = 1
			face[t] = 100
	var n_gold: int = lv.gold
	if n_gold > 0:
		var cand: = []
		for pi in closing.size():
			if pi != shard_pair:
				cand.append(pi)
		_shuffle(cand, rng)
		for q in mini(n_gold / 2, cand.size()):
			for t in closing[cand[q]]:
				gold[t] = 1
	var n_ice: = int(round(float(lv.ice) * 1.5))
	if n_ice > 0:
		var top: = []
		var rest: = []
		for t in n:
			if shard[t] == 0 and gold[t] == 0:
				if (sim.cov_by[t] as Array).is_empty():
					top.append(t)
				else:
					rest.append(t)
		_shuffle(top, rng)
		_shuffle(rest, rng)
		var n_top: = mini(top.size(), maxi(1, int(n_ice * 0.6)))
		for q in n_top:
			ice[top[q]] = 1
		for q in mini(n_ice - n_top, rest.size()):
			ice[rest[q]] = 1
	if lv.hidden:
		for t in n:
			if not (sim.cov_by[t] as Array).is_empty() and shard[t] == 0 and ice[t] == 0:
				secret[t] = 1

	# 5) specials (V6SpecialBoard kinds) on certificate pairs, so the take order stays valid
	var spec: = []   # [a, b, kind, arg]
	var plan: Dictionary = lv.v10_plan
	if npairs >= 8:
		var used: = {}
		var budget: = maxi(1, npairs / 3)
		var ok_pair: = func(pi: int) -> bool:
			if used.has(pi) or pi == shard_pair:
				return false
			for t in closing[pi]:
				if gold[t] == 1 or ice[t] == 1 or shard[t] == 1:
					return false
			return true
		var comp_k: = func(pi: int) -> int:
			return take_at[closing[pi][1]]
		var first_k: = func(pi: int) -> int:
			return take_at[closing[pi][0]]
		var pick: = func(filter: Callable) -> int:
			var c: = []
			for pi in closing.size():
				if ok_pair.call(pi) and filter.call(pi):
					c.append(pi)
			if c.is_empty():
				return -1
			var r: int = c[rng.randi() % c.size()]
			used[r] = true
			return r
		for gi in int(plan.lock):
			if budget < 2:
				break
			var kp: int = pick.call( func(pi): return comp_k.call(pi) >= int(n * 0.05) and comp_k.call(pi) <= int(n * 0.45))
			if kp < 0:
				break
			spec.append([closing[kp][0], closing[kp][1], Sim.K_KEY, gi])
			budget -= 1
			var kc: int = comp_k.call(kp)
			for _q in maxi(1, int(plan.lock_n)):
				var lp: int = pick.call( func(pi): return first_k.call(pi) > kc + 4)
				if lp < 0:
					break
				spec.append([closing[lp][0], closing[lp][1], Sim.K_LOCK, gi])
				budget -= 1
		var long_chain: bool = "chain_long" in lv.mechs
		for _q in int(plan.chain):
			if budget < 1:
				break
			var cp: int = pick.call( func(pi): return done_before[first_k.call(pi)] >= (6 if long_chain else 3) and float(first_k.call(pi)) >= n * 0.2)
			if cp < 0:
				break
			var pd: int = done_before[first_k.call(cp)]
			var cn: = clampi(int(pd * (0.9 if long_chain else 0.6)), 3, mini(pd, 12 if long_chain else 9))
			spec.append([closing[cp][0], closing[cp][1], Sim.K_CHAIN, cn])
			budget -= 1
		for _q in int(plan.joker):
			if budget < 1:
				break
			var jp: int = pick.call( func(pi):
				var a: int = closing[pi][0]
				var b: int = closing[pi][1]
				return take_at[b] == take_at[a] + 1 and open_cnt[take_at[a]] == 0 and secret[a] == 0 and secret[b] == 0 \
					and float(take_at[a]) >= n * 0.2 and float(take_at[a]) <= n * 0.8)
			if jp < 0:
				break
			spec.append([closing[jp][0], closing[jp][1], Sim.K_JOKER, 0])
			budget -= 1
		for _q in int(plan.bomb):
			if budget < 1:
				break
			var bp: int = pick.call( func(pi): return float(comp_k.call(pi)) >= n * 0.1 and float(comp_k.call(pi)) <= n * 0.7)
			if bp < 0:
				break
			spec.append([closing[bp][0], closing[bp][1], Sim.K_BOMB, 0])
			budget -= 1
		for _q in int(plan.gift):
			if budget < 1:
				break
			var gp: int = pick.call( func(pi): return float(comp_k.call(pi)) >= n * 0.1)
			if gp < 0:
				break
			spec.append([closing[gp][0], closing[gp][1], Sim.K_GIFT, 0])
			budget -= 1

	var flat_pos: = PackedInt32Array()
	for p in pos:
		flat_pos.append(p.x)
		flat_pos.append(p.y)
		flat_pos.append(p.z)
	lv.v10 = {"n": n, "pos": flat_pos, "face": face, "step": step, "ice": ice, "secret": secret, "gold": gold, "shard": shard,
		"spec": spec, "cert": order}
	lv["cert"] = order
	lv["gen_stats"] = {"exposed": exposed, "face_overlaps": overlaps}
	return lv


# Load a built level into a sim (content arrays) — used by the verifier and the bots.
static func load_into(sim, lv: Dictionary) -> void:
	var b: Dictionary = lv.v10
	var tag: = "%d:%d:%d:%d" % [int(lv.get("v10_id", -1)), int(lv.get("v10_salt", 0)), int(lv.get("seed", 0)), int(lv.get("assist", false))]
	if sim.tag != tag or sim.n != int(b.n):
		var pos: = []
		var fp: PackedInt32Array = b.pos
		for k in int(b.n):
			pos.append(Vector3i(fp[3 * k], fp[3 * k + 1], fp[3 * k + 2]))
		sim.build(pos)
		sim.tag = tag
	sim.face0 = (b.face as PackedInt32Array).duplicate()
	sim.ice0 = (b.ice as PackedByteArray).duplicate()
	sim.secret0 = (b.secret as PackedByteArray).duplicate()
	sim.kind.fill(0)
	sim.arg.fill(0)
	sim.mate.fill(-1)
	for e in b.spec:
		for t in [e[0], e[1]]:
			sim.kind[t] = e[2]
			sim.arg[t] = e[3]
			if e[2] == Sim.K_JOKER:
				sim.face0[t] = Sim.JOKER
		sim.mate[e[0]] = e[1]
		sim.mate[e[1]] = e[0]


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for k in range(a.size() - 1, 0, -1):
		var r: = rng.randi() % (k + 1)
		var tmp = a[k]
		a[k] = a[r]
		a[r] = tmp
