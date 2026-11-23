class_name V6ModesData
extends RefCounted




static func st() -> Dictionary:
	var d: Dictionary = G.S.get("v6_modes", {})
	for k in DEFAULTS:
		if not d.has(k):
			d[k] = DEFAULTS[k].duplicate() if DEFAULTS[k] is Dictionary or DEFAULTS[k] is Array else DEFAULTS[k]
	G.S["v6_modes"] = d
	return d

const DEFAULTS: = {
	"climb_best": 0, "climb_runs": 0, "climb_miles": [], 
	"etude_stars": {}, 
	"shift_best": 0, "shift_runs": 0, "shift_served": 0, 
	"seen": [], 
}

static func etude_stars(i: int) -> int:
	return int(st().etude_stars.get(str(i), 0))

static func etude_total() -> int:
	var n: = 0
	for k in st().etude_stars:
		n += int(st().etude_stars[k])
	return n

static func etude_open(i: int) -> bool:
	return i == 0 or etude_stars(i - 1) > 0


const LAMPS_START: = 3
const LAMPS_MAX: = 5
const SLOTS_MAX: = 6

const CLIMB_MILES: = [[5, 150], [10, 300], [15, 500], [20, 800], [30, 1200]]
const FLOOR_NAMES: = ["Нижний сад", "Чайная терраса", "Мост фонарей", "Лунная галерея", "Драконьи ступени", "Неоновый ярус"]


const BLESS: = {
	"lamp": {"hero": "mc", "name": "Тёплое слово", "desc": "+1 фонарь", "plus": "+2 фонаря"}, 
	"tips": {"hero": "mc", "name": "Шпаргалка", "desc": "+2 подсказки", "plus": "+3 подсказки"}, 
	"cup": {"hero": "rin", "name": "Лишняя чашка", "desc": "+1 место в лотке", "plus": "+1 место и +1 отмена"}, 
	"pause": {"hero": "rin", "name": "Чайная пауза", "desc": "+3 отмены", "plus": "+4 отмены"}, 
	"breath": {"hero": "hana", "name": "Второе дыхание", "desc": "Комбо держится на 1,5 с дольше", "plus": "Комбо держится на 2,5 с дольше"}, 
	"warmup": {"hero": "hana", "name": "Разминка", "desc": "Каждый этаж начинается с одной снятой пары", "plus": "Каждый этаж начинается с двух снятых пар"}, 
	"silver": {"hero": "yue", "name": "Лунное серебро", "desc": "На этажах больше золота, золото ×2", "plus": "Больше золота, золото ×3"}, 
	"clear": {"hero": "yue", "name": "Ясная ночь", "desc": "Тайные фишки открыты, льда нет", "plus": "Тайных и льда нет, +1 подсказка"}, 
	"backdoor": {"hero": "nova", "name": "Бэкдор", "desc": "+1 смешивание на каждом этаже", "plus": "+2 смешивания на каждом этаже"}, 
	"overclock": {"hero": "nova", "name": "Разгон", "desc": "Умение героини готово наполовину в начале этажа", "plus": "Умение героини готово в начале этажа"}, 
}
const BLESS_ONCE: = ["clear"]
const BLESS_CAP: = {"cup": 2, "lamp": 99}

static func new_run(partner: String) -> Dictionary:
	return {"floor": 1, "lamps": LAMPS_START, "slots": 4, "bless": {}, "hint": 2, "undo": 2, "shuffle": 1, 
		"gems": 0, "partner": partner, "seed": randi() % 1000000, "chests": 0}

static func bless_plus(id: String) -> bool:
	return G.hero_unlocked(BLESS[id].hero)

static func bless_offer(run: Dictionary) -> Array:
	var pool: = []
	for id in BLESS:
		var n: = int(run.bless.get(id, 0))
		if id in BLESS_ONCE and n > 0:
			continue
		if n >= int(BLESS_CAP.get(id, 3)):
			continue
		if id == "lamp" and int(run.lamps) >= LAMPS_MAX:
			continue
		pool.append(id)
	pool.shuffle()

	var own: = pool.filter( func(i): return bless_plus(i))
	var out: = pool.slice(0, 3)
	if not own.is_empty() and out.filter( func(i): return bless_plus(i)).is_empty():
		out[2] = own[0]
	return out

static func floor_cfg(run: Dictionary) -> Dictionary:
	var f: = int(run.floor)
	var li: = (f - 1) % G.LOCS.size()
	var L: Dictionary = G.LOCS[li]
	var guard: = f % 5 == 0
	var r: = RandomNumberGenerator.new()
	r.seed = int(run.seed) * 31 + f * 7919
	var shapes: = ["rect", "heart", "diamond", "butterfly", "cross", "ring", "pyramid", "towers"]
	var silver: = int(run.bless.get("silver", 0))
	var clear: = int(run.bless.get("clear", 0)) > 0
	var gold: = (4 if f >= 3 else 0) + silver * 4
	var ice: = 0 if clear or f < 4 else mini(3 + f / 3, 9)
	var hidden: = not clear and (guard or (f >= 6 and f % 3 == 0))
	var cols: = 5 + mini(2, f / 4)
	var rows: = 6 + mini(2, f / 3)
	var layers: = 2 + mini(3, (f + 1) / 3) + (1 if guard else 0)
	var c: = {
		"name": "Этаж %d%s" % [f, " · Страж" if guard else ""], "code": "", "bg": L.bg, "fx": L.fx, "tint": L.tint, "hero": run.partner, 
		"shape": shapes[r.randi() % shapes.size()], "cols": cols, "rows": rows, "layers": mini(layers, 6), 
		"fill": minf(0.6 + f * 0.012, 0.78), "faces": mini(7 + f, 18), "mech": "", "hard": 1 if guard else 0, 
		"seed": r.randi(), "gold": gold, "ice": ice, "hidden": hidden, "reward": {"gems": 0}, 
		"goal": ("Страж этажа: сундук за победу" if guard else FLOOR_NAMES[li]) + " · фонарей: %d" % int(run.lamps), 
		"intro": "Лунная лестница: переполненный лоток гасит фонарь, но этаж продолжается. Каждый пятый этаж охраняет страж с сундуком." if f == 1 else ("Страж этажа: больше слоёв и тайные фишки. Сундук того стоит." if guard else "Этаж %d. Благословения героинь действуют до конца восхождения." % f), 
	}
	return fit_seed(c, mini(28 + f * 3, 92) + (8 if guard else 0), 6)


static func fit_seed(c: Dictionary, target: int, tol: int) -> Dictionary:
	var best: = int(c.seed)
	var best_d: = 9999
	for k in 40:
		var sd: = int(c.seed) + k * 104729
		c.seed = sd
		var n: = TrayBoard.gen_layout(c).size()
		var d: = absi(n - target)
		if d < best_d:
			best_d = d
			best = sd
		if d <= tol:
			break
	c.seed = best
	return c

static func floor_gems(f: int) -> int:
	return 20 + f * 5


const ETUDES: = 30
const ETUDE_CHAPTERS: = ["Ученица", "Мастер", "Наставница"]
const ETUDE_SLOTS: = 3

static func etude_cfg(i: int) -> Dictionary:

	var shapes: = ["rect", "diamond", "heart", "pyramid", "butterfly", "ring", "cross", "towers"]
	var ch: = i / 10
	var target: = 16 + i * 2
	var cols: = 4 + mini(3, i / 8)
	var rows: = 5 + mini(3, i / 7)
	var layers: = 2 + mini(3, i / 6)
	var c: = {
		"name": "Этюд %d · %s" % [i + 1, ETUDE_CHAPTERS[ch]], "code": "", "bg": ["bg_teahouse", "bg_shrine", "bg_palace"][ch], 
		"fx": ["petals", "mist", "fireflies"][ch], "tint": Color(0.96, 0.95, 1.0), "hero": "mc", 
		"shape": shapes[(i * 3 + ch) % shapes.size()], "cols": cols, "rows": rows, "layers": layers, 
		"fill": 0.6, "faces": 36, "mech": "", "hard": 0, "seed": 900001 + i * 7717, 
		"gold": 0, "ice": 0, "hidden": false, "reward": {"gems": 0}, 
		"goal": "Лоток на 3 места · каждая пара одна такая", 
		"intro": "Этюд: все пары разные, лоток на три места. Отмена бесплатна, но без отмен будет три звезды. Думай, где прячется близнец.", 
	}
	return fit_seed(c, target, 2)

static func etude_first_gems(i: int) -> int:
	return 40 + (i / 3) * 10


const SHIFT_TABLES: = 3
const GUESTS: = ["mc", "rin", "hana", "yue", "nova"]

const TASTE: = {
	"mc": {"cats": [2, 0], "pat": 55.0, "tip": 1.0}, 
	"rin": {"cats": [0, 3], "pat": 60.0, "tip": 1.1}, 
	"hana": {"cats": [2, 4], "pat": 38.0, "tip": 1.2}, 
	"yue": {"cats": [1, 3], "pat": 50.0, "tip": 1.3}, 
	"nova": {"cats": [4, 1], "pat": 42.0, "tip": 1.25}, 
}
const ORDER_LINES: = {
	"mc": ["Мне что-нибудь сладкое, пожалуйста!", "Можно букет к чаю?"], 
	"rin": ["Цветы и что-нибудь ценное. Я подожду.", "Только без спешки, ладно?"], 
	"hana": ["Быстрее, у меня тренировка!", "Сладкое и зверушек, бегом!"], 
	"yue": ["Небо в чашке. И немного золота.", "Луна сегодня капризная."], 
	"nova": ["Зверьки и звёзды. Время пошло.", "Я засекла таймер."], 
}
const THANKS: = {
	"mc": ["Ура, спасибо!", "Ты лучшая официантка этой улицы!"], 
	"rin": ["Идеально. Оставлю щедрые чаевые.", "Ровно то, что я хотела."], 
	"hana": ["Вот это скорость!", "Есть! Побежала!"], 
	"yue": ["Как красиво сервировано…", "Луна довольна."], 
	"nova": ["Принято. Чаевые переведены.", "Неплохо. Даже очень."], 
}
const LEAVE: = {
	"mc": "Ой, мне пора… в другой раз!", "rin": "Чай остыл. Зайду позже.", "hana": "Не дождалась, убегаю!", 
	"yue": "Луна зашла. До встречи.", "nova": "Таймер истёк. Пока.", 
}

static func shift_cfg(table: int, partner: String) -> Dictionary:
	var r: = RandomNumberGenerator.new()
	r.randomize()
	var shapes: = ["rect", "heart", "diamond", "butterfly", "ring"]
	return {
		"name": "Смена в чайной · стол %d/%d" % [table + 1, SHIFT_TABLES], "code": "", "bg": "bg_teahouse", "fx": "petals", 
		"tint": Color(1, 0.97, 0.94), "hero": partner, "shape": shapes[r.randi() % shapes.size()], 
		"cols": 6, "rows": 6 + mini(table, 1), "layers": 3 + mini(table, 1), "fill": 0.68, "faces": 14 + table * 2, 
		"mech": "", "hard": 0, "seed": r.randi(), "gold": 2, "ice": 0, "hidden": false, "reward": {"gems": 0}, 
		"goal": "Выполняй заказы гостий · чаевые = кристаллы", 
		"intro": "Гостьи заказывают пары из своей категории: цветы, небо, сладости, сокровища или зверей. Собери пару нужной категории, и заказ уйдёт к ней.", 
	}


# ---- 0.8: modes open by the player's single rank (G.RANKS). [tier, sub]; "daily" is open from the start.
const GATES: = {
	"daily": [0, 0], 
	"blitz": [0, 2], 
	"zen": [1, 0], 
	"duel": [1, 1], 
	"etude": [1, 2], 
	"shift": [2, 0], 
	"climb": [2, 1], 
}

static func gate_index(id: String) -> int:
	var g: Array = GATES.get(id, [0, 0])
	return int(g[0]) * 3 + int(g[1])

static func gate_title(id: String) -> String:
	var g: Array = GATES.get(id, [0, 0])
	return G.rank_title(int(g[0]), int(g[1]))

# a 0.7 player who already has progress in a mode keeps it open (no taking away what was played)
static func _played(id: String) -> bool:
	var s: = st()
	match id:
		"blitz":
			return int(G.S.get("blitz_best", 0)) > 0
		"climb":
			return int(s.climb_runs) > 0 or int(s.climb_best) > 0
		"etude":
			return etude_total() > 0
		"shift":
			return int(s.shift_runs) > 0 or int(s.shift_best) > 0
		"duel":
			var hs = G.S.get("v6_heroines", {})
			return hs is Dictionary and not (hs.get("duel_wins", {}) as Dictionary).is_empty()
	return false

static func mode_open(id: String) -> bool:
	return G.rank_index(int(G.S.get("rp", 0))) >= gate_index(id) or _played(id)

static func locked_text(id: String) -> String:
	return "Откроется на ранге %s" % gate_title(id)


# V8League (Stream B): "my_week" / "my_quarter".
static func league(fn: String) -> Dictionary:
	match fn:
		"my_week":
			return V8League.my_week()
		"my_quarter":
			return V8League.my_quarter()
	return {}
