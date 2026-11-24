class_name V6Worlds
extends RefCounted






const PER_WORLD: = 8
const CORE_AT: = [0, 2, 4, 6]
const BOSS_AT: = 7


const LOOK: = [
	{"art": "w1", "sub": "Глава 1", "accent": Color("ff9cc0"), "deep": Color("7a2346"), "path": Color("fff1c9"), "glow": Color("ffd36b"), "fog": Color(1.0, 0.86, 0.9)}, 
	{"art": "w2", "sub": "Глава 2", "accent": Color("9fd8ff"), "deep": Color("1d4a7a"), "path": Color("eaf6ff"), "glow": Color("bfe9ff"), "fog": Color(0.86, 0.93, 1.0)}, 
	{"art": "w3", "sub": "Глава 3", "accent": Color("ffb35c"), "deep": Color("7a3a0c"), "path": Color("ffe6b8"), "glow": Color("ffb347"), "fog": Color(1.0, 0.85, 0.72)}, 
	{"art": "w4", "sub": "Глава 4", "accent": Color("b9a6ff"), "deep": Color("3f2a7a"), "path": Color("f1ecff"), "glow": Color("d9ccff"), "fog": Color(0.88, 0.85, 1.0)}, 
	{"art": "w5", "sub": "Глава 5", "accent": Color("ff7a6b"), "deep": Color("6a1020"), "path": Color("ffe0cf"), "glow": Color("ff9a5c"), "fog": Color(1.0, 0.8, 0.78)}, 
	{"art": "w6", "sub": "Глава 6 · событие", "accent": Color("4fe3ff"), "deep": Color("1a2a6e"), "path": Color("d9fbff"), "glow": Color("49e3ff"), "fog": Color(0.75, 0.9, 1.0)}, 
]


const EXTRA: = [
	[["hourglass", 5, 7, 2, 0.7, 6, "", 0], ["arch", 6, 6, 3, 0.75, 7, "", 0, "rows"], ["flower", 6, 7, 3, 0.75, 8, "~", 0, "peak"]], 
	[["lantern", 6, 7, 3, 0.7, 9, "ice", 0], ["frame", 6, 7, 3, 0.65, 10, "ice", 0, "walls"], ["star", 7, 8, 4, 0.75, 11, "hidden", 1, "peak"]], 
	[["fan", 7, 7, 3, 0.75, 11, "gold", 0, "rows"], ["islands", 8, 8, 4, 0.85, 12, "", 0], ["chevron", 8, 9, 4, 0.85, 12, "hidden,gold", 0]], 
	[["moon", 8, 9, 3, 0.9, 13, "hidden", 0], ["gem", 8, 9, 4, 0.8, 13, "gold", 0, "peak"], ["wings", 7, 8, 4, 0.7, 14, "ice,hidden", 1, "checker"]], 
	[["torii", 8, 8, 4, 0.8, 15, "ice", 0, "peak"], ["arch", 8, 8, 4, 0.8, 15, "gold,hidden", 0, "checker"], ["pagoda", 7, 9, 5, 0.7, 16, "ice,gold", 1, "peak"]], 
	[["chevron", 8, 9, 5, 0.9, 17, "gold", 0, "peak"], ["frame", 7, 8, 4, 0.55, 17, "hidden,ice", 0, "rows"], ["flower", 8, 9, 5, 0.9, 18, "gold,ice", 1, "peak"]], 
]


const BOSS: = [
	{"stage": ["crown", 7, 8, 4, 0.7, 10, "gold", 1, "peak"], "hero": "mc", "title": "Партия с хозяйкой", 
		"line": "Покажи свою лучшую партию. Я не буду поддаваться, честно-честно."}, 
	{"stage": ["lantern", 7, 8, 4, 0.7, 13, "ice,hidden", 1, "walls"], "hero": "rin", "title": "Чайная церемония Рин", 
		"line": "Каждое движение должно быть точным. Как у меня, когда я завариваю улун."}, 
	{"stage": ["torii", 8, 9, 5, 0.9, 15, "gold,hidden", 1, "walls"], "hero": "hana", "title": "Забег Ханы", 
		"line": "Кто первый очистит стол, тот угощает! Чур не отставать!"}, 
	{"stage": ["bowl", 8, 9, 5, 0.75, 16, "gold,ice", 2, "walls"], "hero": "yue", "title": "Лунный суд Юэ", 
		"line": "Луна видит каждую фишку. Посмотрим, видишь ли ты."}, 
	{"stage": ["wings", 8, 9, 5, 0.75, 17, "gold,ice,hidden", 2, "peak"], "hero": "mc", "title": "Пробуждение дракона", 
		"line": "В этом святилище я другая. Готова встретить императрицу?"}, 
	{"stage": ["star", 8, 9, 5, 0.7, 18, "gold,ice,hidden", 2, "peak"], "hero": "nova", "title": "Взлом Новы", 
		"line": "Я уже взломала этот стол. Попробуй успеть раньше."}, 
]


const CHEST_MID: = {"gems": 120, "coins": 300, "shard": 1}
const CHEST_STAR: = {"gems": 300, "coins": 800, "shard": 2}
const STAR_NEED: = 20


static func stages(w: int, L: Dictionary) -> Array:
	var core: Array = L.stages
	var out: = []
	var last_mech: = ""
	var ex: Array = EXTRA[w] if w < EXTRA.size() else []
	var ci: = 0
	var ei: = 0
	for s in PER_WORLD:
		var st: Array
		if s == BOSS_AT and w < BOSS.size():
			st = (BOSS[w].stage as Array).duplicate()
		elif s in CORE_AT and ci < core.size():
			st = (core[ci] as Array).duplicate()
			ci += 1
		elif ei < ex.size():
			st = (ex[ei] as Array).duplicate()
			ei += 1
		elif ci < core.size():
			st = (core[ci] as Array).duplicate()
			ci += 1
		else:
			continue
		if st[6] == "~":
			st[6] = last_mech
		last_mech = st[6]
		out.append(st)
	return out


static func decorate(lv: Dictionary, st: Array, w: int, s: int) -> void :
	lv["world"] = w
	lv["upper"] = st[8] if st.size() > 8 else ""
	lv["boss"] = s == BOSS_AT
	if lv.boss and w < BOSS.size():
		var b: Dictionary = BOSS[w]
		lv["boss_hero"] = b.hero
		lv["boss_title"] = b.title
		lv["boss_line"] = b.line
		lv["world_name"] = lv.name
		lv["name"] = b.title
		lv.reward["gems"] = int(lv.reward.gems) + 200


static func world_count() -> int:
	return G.LEVELS.size() / PER_WORLD

static func level_index(w: int, s: int) -> int:
	return w * PER_WORLD + s

static func world_stars(w: int) -> int:
	var n: = 0
	for s in PER_WORLD:
		n += G.level_stars(level_index(w, s))
	return n

static func world_open(w: int) -> bool:
	return level_index(w, 0) < int(G.S.unlocked)

static func cleared(i: int) -> bool:

	return G.level_stars(i) > 0 or i + 1 < int(G.S.unlocked)

static func state() -> Dictionary:
	if not G.S.has("v6_map") or not (G.S.v6_map is Dictionary):
		G.S["v6_map"] = {"chests": {}, "seen": int(G.S.get("unlocked", 1))}
	var m: Dictionary = G.S.v6_map
	if not m.has("chests"):
		m["chests"] = {}
	if not m.has("seen"):
		m["seen"] = int(G.S.unlocked)
	return m

static func chest_id(w: int, kind: String) -> String:
	return "%d%s" % [w, kind]

static func chest_opened(w: int, kind: String) -> bool:
	return state().chests.has(chest_id(w, kind))

static func chest_ready(w: int, kind: String) -> bool:
	if chest_opened(w, kind):
		return false
	if kind == "mid":
		return cleared(level_index(w, 3))
	return world_stars(w) >= STAR_NEED

static func chest_need_text(w: int, kind: String) -> String:
	if kind == "mid":
		return "Пройди партию %d-4" % (w + 1)
	return "Собери %d★ в главе (сейчас %d)" % [STAR_NEED, world_stars(w)]

static func chest_reward(kind: String) -> Dictionary:
	return CHEST_MID if kind == "mid" else CHEST_STAR


static func open_chest(w: int, kind: String) -> Dictionary:
	var r: Dictionary = chest_reward(kind).duplicate()
	var shard_hero: String = G.LOCS[w].shard if w < G.LOCS.size() else "rin"
	r["hero"] = shard_hero
	G.S.gems = int(G.S.gems) + int(r.gems)
	G.S.coins = int(G.S.coins) + int(r.coins)
	G.S.shards[shard_hero] = int(G.S.shards.get(shard_hero, 0)) + int(r.shard)
	state().chests[chest_id(w, kind)] = true
	G.save()
	return r


static func migrate_index(old: int) -> int:
	var w: = old / 4
	var s: = old % 4
	return w * PER_WORLD + CORE_AT[s]
