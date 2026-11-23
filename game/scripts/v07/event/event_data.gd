class_name V7EventData
extends RefCounted





const EPOCH: = "2026-11-16"
const DAYS: = 14
const NODES: = 12
const BOSS_NODES: = [3, 7, 11]
const FEATURED_BONUS: = 0.5
const LEFTOVER_RATE: = 0.5
const OUTFIT_PRICE: = 1800


const EVENTS: = [
	{"id": "yue", "name": "Лунная терраса", "hero": "yue", "cur": "Лунные капли", "cur1": "лунная капля", "icon": "cur_yue", 
		"bg": "bg_palace", "fx": "fireflies", "tint": Color(0.93, 0.92, 1.0), "art": "cg_yue", "mech": ["hidden", "gold", "", "hidden,gold"], 
		"outfit": {"id": "ev_yue", "name": "Лунная терраса", "rar": "SSR"}, 
		"color": Color("b8a6ff"), 
		"pitch": "Юэ зовёт на балкон дворца: двенадцать лунных столов, капли росы и платье, которое шьют только раз в сезон.", 
		"lines": ["Полнолуние бывает раз в месяц, а такой вечер раз в сезон. Сыграешь со мной на террасе?", "Половина пути. Луна уже над крышами, а ты ни разу не торопилась. Мне это нравится.", "Последний стол. Если выиграешь, я надену то платье ещё раз, только для тебя."]}, 
	{"id": "nova", "name": "Неоновый заезд", "hero": "nova", "cur": "Чипы", "cur1": "чип", "icon": "cur_nova", 
		"bg": "bg_neon", "fx": "rain", "tint": Color(0.9, 0.95, 1.05), "art": "cg_nova", "mech": ["ice", "gold", "hidden", "ice,gold"], 
		"outfit": {"id": "ev_nova", "name": "Ночной заезд", "rar": "SSR"}, 
		"color": Color("4fe3ff"), 
		"pitch": "Нова взломала вывески квартала и устроила ночную гонку по столам. Чипы с каждой партии, байк и куртка в лавке.", 
		"lines": ["Двенадцать столов, двенадцать светофоров. Я уже прошила каждый. Догоняй.", "Полпути. Чипов хватит на что-нибудь красивое, поверь технарю.", "Финишная прямая. Выиграешь, прокачу тебя до рассвета."]}, 
	{"id": "rin", "name": "Вечер светлячков", "hero": "rin", "cur": "Светлячки", "cur1": "светлячок", "icon": "cur_rin", 
		"bg": "bg_teahouse", "fx": "fireflies", "tint": Color(0.95, 1.0, 0.96), "art": "cg_rin", "mech": ["", "ice", "gold", "ice,hidden"], 
		"outfit": {"id": "ev_rin", "name": "Юката светлячков", "rar": "SSR"}, 
		"color": Color("8fe0a8"), 
		"pitch": "Рин открывает веранду чайной у пруда. Каждый чистый стол выпускает светлячков, а за них в лавке ждёт её вечерняя юката.", 
		"lines": ["Чай заварен, светлячки проснулись. Садись, сыграем без спешки.", "Слышишь, как тихо? Ты играешь всё спокойнее. Это лучший комплимент чаю.", "Последний стол на веранде. Потом посидим просто так, хорошо?"]}, 
	{"id": "hana", "name": "Закатная эстафета", "hero": "hana", "cur": "Медали", "cur1": "медаль", "icon": "cur_hana", 
		"bg": "bg_street", "fx": "petals", "tint": Color(1.0, 0.95, 0.9), "art": "cg_hana", "mech": ["gold", "", "hidden", "gold,ice"], 
		"outfit": {"id": "ev_hana", "name": "Закатная пробежка", "rar": "SSR"}, 
		"color": Color("ffb35c"), 
		"pitch": "Хана тренируется на крыше до заката и зовёт тебя в эстафету: двенадцать этапов, медали и её любимая беговая форма.", 
		"lines": ["Разминка окончена! Двенадцать этапов до заката. Не отставай!", "Половина дистанции, а ты даже не запыхалась. Уважаю.", "Финальный этап! Солнце садится, бежим вместе!"]}, 
	{"id": "mc", "name": "Чайная после закрытия", "hero": "mc", "cur": "Чайные листья", "cur1": "чайный лист", "icon": "cur_mc", 
		"bg": "play", "fx": "petals", "tint": Color(1, 0.97, 0.95), "art": "cg_mc", "mech": ["", "hidden", "gold", "ice,gold"], 
		"outfit": {"id": "ev_mc", "name": "Хозяйка после закрытия", "rar": "SSR"}, 
		"color": Color("ff8fb8"), 
		"pitch": "Гости ушли, фонари притушены. Маджонг-тян раскладывает партии только для своих. Чайные листья и её домашний наряд.", 
		"lines": ["Табличку «закрыто» я уже повесила. Теперь стол только наш.", "Знаешь, после закрытия фишки звучат иначе. Тише и честнее.", "Последняя партия вечера. Проиграешь, моешь чашки. Шучу. Наверное."]}, 
]


const SHOP: = [
	{"id": "outfit", "kind": "outfit", "price": OUTFIT_PRICE, "lim": 1}, 
	{"id": "shard", "kind": "shard", "price": 150, "lim": 5, "name": "Осколок портрета"}, 
	{"id": "gems", "kind": "gems", "n": 100, "price": 120, "lim": 10, "name": "100 кристаллов"}, 
	{"id": "coins", "kind": "coins", "n": 1000, "price": 60, "lim": 10, "name": "1000 монет"}, 
]

const MILES: = [
	{"at": 300, "gems": 100}, {"at": 700, "shards": 2}, {"at": 1200, "gems": 200}, 
	{"at": 1800, "coins": 3000}, {"at": 2500, "gems": 300}, {"at": 3200, "gems": 500}, 
]


static func now_unix() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--event_now="):
			var s: = a.substr(12)
			if s.length() == 10:
				s += "T12:00:00"
			return Time.get_unix_time_from_datetime_string(s)
	return Time.get_unix_time_from_system() + Time.get_time_zone_from_system().get("bias", 0) * 60.0

static func day_of(unix: float) -> int:
	return floori(unix / 86400.0)

static func epoch_day() -> int:
	return day_of(Time.get_unix_time_from_datetime_string(EPOCH + "T00:00:00"))

static func cycle() -> int:
	return floori(float(day_of(now_unix()) - epoch_day()) / DAYS)

static func def_of(c: int) -> Dictionary:
	return EVENTS[posmod(c, EVENTS.size())]

static func cur_def() -> Dictionary:
	return def_of(cycle())

static func key_of(c: int) -> String:
	return "ev%d" % c


static func left_secs() -> float:
	var end_day: = epoch_day() + (cycle() + 1) * DAYS
	return end_day * 86400.0 - now_unix()

static func left_text(secs: float) -> String:
	var d: = int(secs) / 86400
	var h: = (int(secs) % 86400) / 3600
	if d > 0:
		return "%d д %d ч" % [d, h]
	var m: = (int(secs) % 3600) / 60
	return "%d ч %d мин" % [h, m]

static func today_key() -> String:
	return Time.get_date_string_from_unix_time(int(now_unix()))


static func root() -> Dictionary:
	var d: Dictionary = G.S.get("v7_event", {})
	if not d.has("ev"):
		d["ev"] = {}
	if not d.has("tour"):
		d["tour"] = {}
	if not d.has("pending"):
		d["pending"] = []
	if not d.has("owned_ev"):
		d["owned_ev"] = []
	G.S["v7_event"] = d
	return d


static func st() -> Dictionary:
	var r: = root()
	var ev: Dictionary = r.ev
	var k: = key_of(cycle())
	if ev.get("key", "") != k:
		if ev.get("key", "") != "":
			_close_event(r, ev)
		ev = {"key": k, "def": cur_def().id, "cur": 0, "earned": 0, "nodes": {}, "bought": {}, "miles": [], "daily": "", "intro": false, "bis": 0, "seen": false}
		r.ev = ev
	return ev

static func _close_event(r: Dictionary, ev: Dictionary) -> void :
	var left: = int(ev.get("cur", 0))
	var gems: = int(round(left * LEFTOVER_RATE))
	G.S.gems += gems
	var def: Dictionary = {}
	for e in EVENTS:
		if e.id == ev.get("def", ""):
			def = e
	r.pending.append({"type": "event_end", "name": def.get("name", "Ивент"), "left": left, "gems": gems, 
		"nodes": (ev.get("nodes", {}) as Dictionary).size(), "outfit": G.owns(def.get("outfit", {}).get("id", ""))})

static func cur() -> int:
	return int(st().cur)

static func node_stars(i: int) -> int:
	return int(st().nodes.get(str(i), 0))

static func node_open(i: int) -> bool:
	return i == 0 or node_stars(i - 1) > 0

static func cleared_count() -> int:
	var n: = 0
	for i in NODES:
		if node_stars(i) > 0:
			n += 1
	return n

static func total_stars() -> int:
	var n: = 0
	for i in NODES:
		n += node_stars(i)
	return n

static func bought(id: String) -> int:
	return int(st().bought.get(id, 0))


static func limited_items() -> Array:
	var out: = []
	for e in EVENTS:
		out.append({"id": e.outfit.id, "cat": "outfit", "hero": e.hero, "rar": e.outfit.rar, "name": e.outfit.name, 
			"img": "../v07/event/%s_card" % e.art, "nogacha": true, "limited": true, "event": e.id})
	return out


const SHAPES: = ["rect", "heart", "diamond", "butterfly", "ring", "cross", "pyramid", "towers", "heart", "butterfly", "diamond", "pyramid"]

static func node_cfg(i: int, def: Dictionary, partner: String, replay_seed: = -1) -> Dictionary:
	var boss: bool = i in BOSS_NODES
	var t: = float(i) / (NODES - 1)
	var mech: String = def.mech[i % def.mech.size()]
	if boss:
		mech = def.mech[3]
	var c: = key_of(cycle())
	var sd: = (hash(c + def.id) % 100000 + 1) * 31 + i * 977
	if replay_seed >= 0:
		sd = replay_seed
	var cfg: = {
		"name": "%s · стол %d" % [def.name, i + 1], "code": "E-%d" % (i + 1), "bg": def.bg, "fx": def.fx, "tint": def.tint, "hero": def.hero, 
		"shape": SHAPES[i % SHAPES.size()], "cols": 5 + int(t * 2.2), "rows": 6 + int(t * 2.2), "layers": 2 + int(t * 3.0) + (1 if boss else 0), 
		"fill": 0.62 + t * 0.1, "faces": 8 + int(t * 8) + (1 if boss else 0), 
		"mech": mech, "hard": (2 if i == NODES - 1 else 1) if boss else 0, "seed": sd, 
		"gold": 4 if "gold" in mech else 0, "ice": 3 + int(t * 3) if "ice" in mech else 0, "hidden": "hidden" in mech, 
		"reward": {"gems": 0}, "goal": "Очисти стол · %s за каждую пару с героиней ивента" % def.cur, 
		"intro": def.pitch if i == 0 else ("Сложный стол: награда больше." if boss else "Каждый стол ивента платит %s. С героиней ивента на 50%% больше." % def.cur.to_lower()), 
	}
	cfg.layers = mini(int(cfg.layers), 5)
	return cfg


static func clear_reward(i: int, stars: int, first: bool, partner: String, def: Dictionary) -> Dictionary:
	var base: = (60 + 12 * i + (60 if i in BOSS_NODES else 0)) if first else (36 + 4 * mini(i, 11))
	base += stars * 10
	var parts: = [["Стол", base]]
	var total: = base
	if partner == def.hero:
		var b: = int(round(base * FEATURED_BONUS))
		parts.append(["Героиня ивента", b])
		total += b
	var ev: = st()
	if ev.daily != today_key():
		parts.append(["Первая партия дня", total])
		total *= 2
	return {"total": total, "parts": parts}

static func add_cur(n: int) -> Array:

	var ev: = st()
	ev.cur = int(ev.cur) + n
	ev.earned = int(ev.earned) + n
	ev.daily = today_key()
	var got: = []
	for k in MILES.size():
		var m: Dictionary = MILES[k]
		if int(ev.earned) >= int(m.at) and not k in ev.miles.map( func(x): return int(x)):
			ev.miles.append(k)
			_pay(m, cur_def())
			got.append(m)
	return got

static func _pay(m: Dictionary, def: Dictionary) -> void :
	G.S.gems += int(m.get("gems", 0))
	G.S.coins += int(m.get("coins", 0))
	if m.has("shards"):
		G.S.shards[def.hero] = int(G.S.shards.get(def.hero, 0)) + int(m.shards)

static func mile_text(m: Dictionary, def: Dictionary) -> String:
	if m.has("gems"):
		return "%d кристаллов" % int(m.gems)
	if m.has("coins"):
		return "%d монет" % int(m.coins)
	if m.has("shards"):
		return "%d осколка: %s" % [int(m.shards), G.HEROES[def.hero].name]
	return ""


static func buy(item: Dictionary) -> String:
	var ev: = st()
	var def: = cur_def()
	if bought(item.id) >= int(item.lim):
		return "Уже куплено"
	if item.kind == "outfit" and G.owns(def.outfit.id):
		return "Наряд уже твой"
	if int(ev.cur) < int(item.price):
		return "Не хватает: %s" % def.cur.to_lower()
	ev.cur = int(ev.cur) - int(item.price)
	ev.bought[item.id] = bought(item.id) + 1
	match item.kind:
		"outfit":
			G.give(def.outfit.id)
			var r: = root()
			if not def.outfit.id in r.owned_ev:
				r.owned_ev.append(def.outfit.id)
		"shard":
			G.S.shards[def.hero] = int(G.S.shards.get(def.hero, 0)) + 1
		"gems":
			G.S.gems += int(item.n)
		"coins":
			G.S.coins += int(item.n)
	G.save()
	return ""
