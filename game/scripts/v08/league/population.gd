class_name V8Population
extends RefCounted

# 0.8 population: 1000 deterministic players for the weekly league and the quarter table.
# Nothing is stored in the save: every value comes from SEED, the player index and the time.
# Time t is the game clock (V7EventData.now_unix(): local wall time expressed as unix seconds).
#   V8Population.all() -> Array        players, index = id (0..COUNT-1)
#   V8Population.get_p(id) -> Dictionary {id, nick, avatar, hero, fav, tier, skill, q, base, days, shift, rpg}
#   V8Population.rp_at(id, t) -> int   rank points earned since the start of t's calendar quarter
#                                       (monotonic, smooth, slower at night in the player's local time)
#   V8Population.rank_rp(id, t) -> int career rank points (crest): base + rp_at
#   V8Population.tier_at(id, t) -> int G.RANKS tier
#   V8Population.week_points(id, t, league) -> int  weekly tournament points, growing smoothly through the week
#   V8Population.games_week(id, t, league) -> int   games since Monday (path + tournament tables)
#   V8Population.quarter(t) -> {key, start, end, num, year}
#   V8Population.quarter_rows(t) -> Array [[id, points], ...] sorted by points, best first
#   V8Population.avatar_view(img, hero, rect, _, top) -> Control   round face crop of an outfit in the gold frame (V8Art.avatar)

const COUNT: = 1000
const SEED: = 80817
const TIER_COUNT: = [320, 270, 190, 120, 70, 30]
const Q_RANGE: = [[60, 350], [200, 700], [450, 1400], [900, 2800], [2000, 6000], [4500, 16000]]
const RPG: = [22, 28, 34, 40, 48, 56]
const TOP_SPAN: = 3000

const HOURS: = [0.55, 0.32, 0.18, 0.1, 0.07, 0.07, 0.14, 0.38, 0.66, 0.78, 0.8, 0.88, 1.1, 1.08, 0.9, 0.9, 1.0, 1.12, 1.3, 1.6, 1.8, 1.8, 1.5, 1.0]

# outfit image -> [focus x, focus y, zoom] for a round face crop (Common.card_art)
# (mc_* / hana_base / hana_street: measured on the adult redraw — focus = the eyes-to-mouth centre raised by 0.15 face
# width, zoom = ≈2 face widths across the circle: the whole head, like the other heroines' crops)
const FACES: = {
	"hana_base": [0.518, 0.156, 4.72], "hana_beach": [0.545, 0.225, 4.6], "hana_gym": [0.52, 0.18, 4.6], "hana_street": [0.626, 0.184, 4.99],
	"hana_winter": [0.47, 0.175, 4.6], "mc_base": [0.513, 0.1164, 4.9], "mc_cafe": [0.508, 0.1336, 4.38], "mc_cozy": [0.515, 0.1117, 4.21], "mc_tutor": [0.375, 0.132, 4.25],
	"mc_dragon": [0.46, 0.2, 4.8], "nova_base": [0.5, 0.2, 4.8], "nova_offline": [0.5, 0.21, 5.0],
	"nova_ssr": [0.56, 0.25, 5.2], "rin_after": [0.55, 0.2, 5.0], "rin_agent": [0.5, 0.16, 4.8], "rin_base": [0.48, 0.17, 4.6],
	"rin_idol": [0.46, 0.19, 4.6], "rin_maid": [0.49, 0.14, 4.6], "rin_yukata": [0.52, 0.14, 4.8], "yue_ball": [0.5, 0.15, 4.8],
	"yue_base": [0.5, 0.16, 4.8], "yue_duel": [0.5, 0.21, 5.0], "yue_queen": [0.52, 0.18, 4.3],
}
# Outfit art used as league player avatars (mc/hana redrawn as clearly adult in 0.8; tutor art stays out)
const AVATARS: = ["hana_base", "hana_street", "hana_winter", "mc_base", "mc_cafe", "mc_cozy", "mc_dragon",
	"nova_base", "nova_offline", "rin_after", "rin_agent", "rin_base", "rin_idol", "rin_maid", "rin_yukata",
	"yue_ball", "yue_base", "yue_queen"]

# --- nickname dictionaries (no real people, no brands, no heroine or rank names) ---
const ADJ: = [["Тихий", "Тихая"], ["Сонный", "Сонная"], ["Лунный", "Лунная"], ["Рыжий", "Рыжая"], ["Хитрый", "Хитрая"],
	["Ночной", "Ночная"], ["Весёлый", "Весёлая"], ["Мятный", "Мятная"], ["Чайный", "Чайная"], ["Северный", "Северная"],
	["Ленивый", "Ленивая"], ["Добрый", "Добрая"], ["Звёздный", "Звёздная"], ["Снежный", "Снежная"], ["Кофейный", "Кофейная"],
	["Туманный", "Туманная"], ["Вишнёвый", "Вишнёвая"], ["Пушистый", "Пушистая"], ["Шустрый", "Шустрая"], ["Мудрый", "Мудрая"],
	["Дикий", "Дикая"], ["Тёплый", "Тёплая"], ["Смелый", "Смелая"], ["Озорной", "Озорная"], ["Сладкий", "Сладкая"],
	["Осенний", "Осенняя"], ["Весенний", "Весенняя"], ["Мягкий", "Мягкая"], ["Хмурый", "Хмурая"]]
const NOUN_M: = ["Лис", "Кот", "Ёж", "Филин", "Енот", "Барсук", "Тигр", "Сокол", "Пёс", "Ворон", "Чайник", "Пельмень", "Карп",
	"Журавль", "Гусь", "Бурундук", "Кит", "Медведь", "Фонарь", "Ветер", "Самурай", "Сэнсэй", "Странник", "Хомяк", "Пингвин",
	"Котёнок", "Лемур", "Дельфин", "Мотылёк", "Волк", "Суслик", "Тюлень"]
const NOUN_F: = ["Лиса", "Сова", "Кошка", "Панда", "Белка", "Вишня", "Луна", "Ласточка", "Цапля", "Звезда", "Мышка", "Рыбка",
	"Чашка", "Сакура", "Фея", "Птичка", "Слива", "Ягода", "Выдра", "Лисичка", "Капибара", "Тучка", "Снежинка", "Чайка",
	"Синица", "Пчёлка", "Бабочка", "Ромашка"]
const WORDS: = ["КотЧай", "Тофу", "Мандаринка", "Маття", "Кицунэ", "Пион", "Звёздочка", "Ветерок", "Хокку", "Иней", "Корица",
	"Марципан", "Кедр", "Северянка", "Ханами", "Данго", "Капучино", "Полночь", "Нори", "Рамэн", "Сливка", "Онигири", "Моти",
	"Пончик", "Зефирка", "Ириска", "Печенька", "Булочка", "Плюшка", "Сырник", "Вареник", "Блинчик", "Облачко", "Солнышко",
	"Карамелька", "Шишка", "Пуговка", "Фонарщик", "Мармеладка", "Черничка", "Брусничка", "Ёжик", "Совёнок", "Чаинка",
	"Васаби", "Мисо", "Удон", "Сэмпай", "Кохай", "Тэнпай", "Риичи", "Цумо", "Дора", "Хайтэй", "Иппацу", "Тюн", "Хаку",
	"Тихий_Пруд", "Лунный_Чай", "Чай_с_мятой", "Хризантема", "Светлячок", "Колибри", "Пряник"]
const WORD_SUF: = ["", "", "", "_%d", "%d", "-тян", "-кун", "-сан", "_ня", "_mj", "%d"]
const SYL: = ["ка", "ки", "ко", "са", "си", "со", "та", "то", "на", "ни", "но", "ми", "мо", "ма", "ра", "ру", "ро", "ю",
	"юки", "хи", "хо", "аи", "э", "рэ", "кэ", "мэ", "я", "нэ", "цу", "ку", "су", "фу", "ха", "мэй", "рю", "сё", "тя", "иро"]
const LAT: = ["Mochi", "Tofu", "Nyan", "Miso", "Udon", "Panda", "Koi", "Sakura", "Haru", "Yuki", "Kumo", "Matcha", "Boba",
	"Neko", "Kuma", "Hoshi", "Sora", "Shiro", "Kuro", "Tsuki", "Ume", "Ponzu", "Wasabi", "Dango", "Kaze", "Ame", "Kitsune",
	"Usagi", "Tora", "Inu", "Momiji", "Hotaru", "Taiyaki", "Ramen", "Onigiri", "Frost", "Ember", "Raven", "Comet", "Pebble",
	"Maple", "Willow", "Clover", "Biscuit", "Muffin", "Pudding", "Cookie", "Waffle", "Noodle", "Pickle", "Bunny", "Fox",
	"Owl", "Otter", "Moth", "Badger", "Wolf", "Crane", "Sparrow", "Teacup", "Kettle", "Lantern", "Dumpling", "Mango"]
const LAT_MJ: = ["Riichi", "Tsumo", "Ron", "Pon", "Chii", "Kan", "Dora", "Ippatsu", "Tenpai", "Haku", "Hatsu", "Chun",
	"Ura", "Mangan", "Haneman", "Yakuman", "Honitsu", "Chiitoi", "Tanyao", "Pinfu", "Kokushi", "Shanten", "Haitei"]
const LAT_PRE: = ["", "", "", "", "", "xX", "Lil", "Mr", "Miss", "Lady", "Sir", "Big", "Tiny", "Night", "Sleepy", "Lucky",
	"Silent", "Shy", "Mad", "Lazy", "Happy", "Grumpy", "Sneaky", "Cozy", "Wild", "Sweet", "Little", "Pro", "Noob"]
const LAT_SUF: = ["", "", "", "", "_", "x", "777", "%d", "%d", "%y", "chan", "kun", "san", "uwu", "owo", "_mj", "mj", "42", "_tea"]
const BANNED: = ["бамбук", "нефрит", "жемчуг", "золот", "дракон", "небожит", "bamboo", "jade", "pearl", "gold", "dragon", "celestial",
	"сука", "кака", "сиси", "срак", "жоп", "хуй", "хуе", "бля", "пизд", "ебат", "ебан", "дерьм", "говн", "мраз", "дура", "дурак",
	"лох", "чмо", "кусо", "нацист", "fuck", "shit", "sex", "porn", "nazi", "dick", "ass", "бот", "bot"]
const HERO_NICKS: = ["рин", "хана", "юэ", "нова", "маджонг", "rin", "hana", "yue", "nova", "mahjong"]
const TR: = {"а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "yo", "ж": "zh", "з": "z", "и": "i", "й": "y",
	"к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f", "х": "h",
	"ц": "ts", "ч": "ch", "ш": "sh", "щ": "sch", "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya"}

static var _pop: Array = []
static var _hc: Array = []
static var _plans: = {}
static var _qcache: = {}
static var _tiers: = {}
static var _rows: = {}


# ---------------------------------------------------------------- generation

static func all() -> Array:
	if _pop.is_empty():
		_generate()
	return _pop

static func get_p(id: int) -> Dictionary:
	var a: = all()
	return a[clampi(id, 0, a.size() - 1)]

static func nick(id: int) -> String:
	return String(get_p(id).nick)

static func tier_lo(t: int) -> int:
	var n: = 0
	for k in t:
		n += int(G.RANKS[k].per) * 3
	return n

static func tier_span(t: int) -> int:
	return TOP_SPAN if t >= G.RANKS.size() - 1 else int(G.RANKS[t].per) * 3

static func _generate() -> void:
	var rng: = RandomNumberGenerator.new()
	rng.seed = SEED
	var tiers: = []
	for t in TIER_COUNT.size():
		for k in TIER_COUNT[t]:
			tiers.append(t)
	_shuffle(tiers, rng)
	var seen: = {}
	_pop = []
	for i in COUNT:
		var tier: int = tiers[i]
		var nk: = ""
		var guard: = 0
		while guard < 200:
			guard += 1
			nk = _make_nick(rng)
			if nk.length() >= 3 and nk.length() <= 16 and not seen.has(nk.to_lower()) and _clean(nk):
				break
		if seen.has(nk.to_lower()):
			nk = "%s%d" % [nk.substr(0, 12), i]
		seen[nk.to_lower()] = true
		var hero: String = G.HERO_ORDER[rng.randi() % G.HERO_ORDER.size()]
		var outs: = AVATARS.filter(func(x): return String(x).begins_with(hero + "_"))
		var av: String = outs[rng.randi() % outs.size()]
		var fav: = hero if rng.randf() < 0.7 else String(G.HERO_ORDER[rng.randi() % G.HERO_ORDER.size()])
		var skill: = rng.randf()
		var qr: Array = Q_RANGE[tier]
		var q: = lerpf(float(qr[0]), float(qr[1]), clampf(pow(skill, 1.5) * 0.7 + rng.randf() * 0.3, 0.0, 1.0))
		var base: = int(tier_lo(tier) + rng.randf() * tier_span(tier) * 0.35)
		var sh: = 0.0
		var tzr: = rng.randf()
		if tzr > 0.7:
			sh = rng.randf_range(1.0, 5.0)
		elif tzr > 0.6:
			sh = rng.randf_range(-2.0, -0.5)
		sh += rng.randf_range(-1.5, 2.5)
		var a: = rng.randf_range(0.15, 0.4)
		var b: = rng.randf_range(0.08, 0.25)
		_pop.append({"id": i, "nick": nk, "avatar": av, "hero": hero, "fav": fav, "tier": tier, "skill": skill,
			"q": q, "base": base, "days": rng.randi_range(2, 7), "shift": sh, "rpg": RPG[tier] + rng.randi_range(-4, 6),
			"wa": a, "ww": TAU / rng.randf_range(9.0, 25.0), "wp": rng.randf() * TAU, "wb": b, "wq": rng.randf() * TAU})

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: = rng.randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

static func _clean(nk: String) -> bool:
	var low: = nk.to_lower()
	for b in BANNED:
		if b in low:
			return false
	var core: = low
	for sep in ["_", "-", ".", " "]:
		core = core.get_slice(sep, 0)
	core = core.rstrip("0123456789")
	return not core in HERO_NICKS

static func _pick(arr: Array, rng: RandomNumberGenerator):
	return arr[rng.randi() % arr.size()]

static func _num(rng: RandomNumberGenerator) -> String:
	var r: = rng.randf()
	if r < 0.5:
		return str(rng.randi_range(10, 99))
	if r < 0.8:
		return str(rng.randi_range(1, 9))
	return str(rng.randi_range(100, 999))

static func _translit(s: String) -> String:
	var out: = ""
	for ch in s.to_lower():
		out += TR.get(ch, ch)
	return out

# Public nick generator for the player (profile card «🎲»): same style as the population, valid for
# G.nick_error and never equal to a population nick.
static func random_nick(rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var taken: = {}
	for p in all():
		taken[String(p.nick).to_lower()] = true
	for _i in 40:
		var nk: = _make_nick(rng)
		if nk.length() >= 3 and nk.length() <= 16 and _clean(nk) and not taken.has(nk.to_lower()) and G.nick_error(nk) == "":
			return nk
	return V8Nicks.random(rng)

static func _make_nick(rng: RandomNumberGenerator) -> String:
	var r: = rng.randf()
	if r < 0.22:
		var fem: = rng.randf() < 0.5
		var adj: Array = _pick(ADJ, rng)
		var noun: String = _pick(NOUN_F if fem else NOUN_M, rng)
		var a: String = adj[1 if fem else 0]
		var st: = rng.randf()
		if st < 0.55:
			return a + noun
		if st < 0.8:
			return a + "_" + noun
		return a + noun + _num(rng)
	if r < 0.42:
		var w: String = _pick(WORDS, rng)
		var suf: String = _pick(WORD_SUF, rng)
		if "%d" in suf:
			suf = suf.replace("%d", _num(rng))
		return w + suf
	if r < 0.54:
		var n: = rng.randi_range(2, 3)
		var s: = ""
		for k in n:
			s += String(_pick(SYL, rng))
		s = s.capitalize()
		var t: = rng.randf()
		if t < 0.25:
			s += "-тян"
		elif t < 0.4:
			s += "_" + _num(rng)
		return s
	if r < 0.86:
		var core: String = _pick(LAT, rng) if rng.randf() < 0.65 else _pick(LAT_MJ, rng)
		var pre: String = _pick(LAT_PRE, rng)
		var suf2: String = _pick(LAT_SUF, rng)
		if suf2 == "%d":
			suf2 = _num(rng)
		elif suf2 == "%y":
			suf2 = str(rng.randi_range(1990, 2009))
		var mode: = rng.randf()
		if mode < 0.12:
			var c2: String = _pick(LAT_MJ, rng)
			return (core + "_" + c2).to_lower() if rng.randf() < 0.5 else core + c2
		if pre == "xX":
			return "xX" + core + "Xx"
		var s2: = pre + core + suf2
		if mode > 0.85:
			s2 = s2.to_lower()
		return s2
	var fem2: = rng.randf() < 0.5
	var adj2: Array = _pick(ADJ, rng)
	var noun2: String = _pick(NOUN_F if fem2 else NOUN_M, rng)
	var sep2: String = _pick(["_", ".", ""], rng)
	var s3: = _translit(adj2[1 if fem2 else 0]) + sep2 + _translit(noun2)
	if rng.randf() < 0.35:
		s3 += _num(rng)
	return s3


# ---------------------------------------------------------------- time helpers

static func _hours_cum() -> Array:
	if _hc.is_empty():
		var tot: = 0.0
		for h in HOURS:
			tot += h
		var acc: = 0.0
		_hc.append(0.0)
		for h in HOURS:
			acc += h / tot
			_hc.append(acc)
		_hc[24] = 1.0
	return _hc

# cumulative share of a day's activity up to local hour h (any real number, periodic)
static func _hinf(h: float) -> float:
	var hc: = _hours_cum()
	var d: = floorf(h / 24.0)
	var r: = h - d * 24.0
	var i: = clampi(int(r), 0, 23)
	var f: = r - i
	return d + lerpf(hc[i], hc[i + 1], f)

# share of the viewer's day [0..frac] played by someone whose local clock is `shift` hours ahead
static func _part(frac: float, shift: float) -> float:
	return clampf(_hinf(frac * 24.0 + shift) - _hinf(shift), 0.0, 1.0)

static func quarter(t: float) -> Dictionary:
	var day: = floori(t / 86400.0)
	if _qcache.has(day):
		return _qcache[day]
	var dt: = Time.get_datetime_dict_from_unix_time(int(t))
	var qi: = (int(dt.month) - 1) / 3
	var y: = int(dt.year)
	var s: = Time.get_unix_time_from_datetime_dict({"year": y, "month": qi * 3 + 1, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var e: = Time.get_unix_time_from_datetime_dict({"year": y + (1 if qi == 3 else 0), "month": 1 if qi == 3 else qi * 3 + 4, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var q: = {"key": "%dQ%d" % [y, qi + 1], "start": s, "end": e, "num": qi + 1, "year": y}
	if _qcache.size() > 64:
		_qcache.clear()
	_qcache[day] = q
	return q

static func week_start_day(t: float) -> int:
	var d: = floori(t / 86400.0)
	return d - posmod(d + 3, 7)


# ---------------------------------------------------------------- quarter rank points

static func _F(p: Dictionary, x: float) -> float:
	var ww: float = p.ww
	var w7: = TAU / 7.0
	return x - float(p.wa) / ww * cos(ww * x + float(p.wp)) - float(p.wb) / w7 * cos(w7 * x + float(p.wq))

static func q_total(id: int, qkey: String) -> float:
	var p: = get_p(id)
	var r: = RandomNumberGenerator.new()
	r.seed = hash("q|%d|%s" % [id, qkey])
	return float(p.q) * r.randf_range(0.8, 1.2)

# 0.8: not everyone plays from the first day of a quarter. Per player and quarter: the day they start
# playing it (0 for most; later for returning / new players; never for a few who sit this quarter out).
# So a fresh player who wins a few tables mid-quarter lands among the late starters, never last of 1 001.
const Q_INACTIVE: = 0.04
const Q_LATE: = 0.34
const Q_LATE_MAX: = 0.75

static func q_join(id: int, qkey: String, days: float) -> float:
	var r: = RandomNumberGenerator.new()
	r.seed = hash("j|%d|%s" % [id, qkey])
	var u: = r.randf()
	if u < Q_INACTIVE:
		return INF
	if u < Q_INACTIVE + Q_LATE:
		# whole days, so the local-time rhythm of rp_at stays aligned with the clock
		return floorf(r.randf_range(0.03, Q_LATE_MAX) * days)
	return 0.0

static func rp_at(id: int, t: float) -> int:
	var q: = quarter(t)
	var x: = (t - float(q.start)) / 86400.0
	if x <= 0.0:
		return 0
	var p: = get_p(id)
	var days: = (float(q.end) - float(q.start)) / 86400.0
	var join: = q_join(id, String(q.key), days)
	if x <= join:
		return 0
	# a late starter plays at their usual pace from the join day: the quarter total shrinks with the days left
	var span: = days - join
	x = minf(x - join, span)
	var rate: = q_total(id, q.key) * (span / days) / (_F(p, span) - _F(p, 0.0))
	var k: = floori(x)
	var fk: = _F(p, k)
	var val: = fk - _F(p, 0.0) + (_F(p, k + 1) - fk) * _part(x - k, float(p.shift))
	return maxi(0, int(rate * val))

# Career points for the crest. Below the top tier a quarter moves a player by at most ~0.7 of a tier
# (seasonal soft reset), so the rank spread stays «many Бамбук/Нефрит, few Дракон/Небожитель».
static func rank_rp(id: int, t: float) -> int:
	var p: = get_p(id)
	var tier: int = p.tier
	var got: = float(rp_at(id, t))
	if tier < G.RANKS.size() - 1:
		got *= minf(1.0, tier_span(tier) * 0.7 / maxf(1.0, float(p.q) * 1.2))
	else:
		got *= 0.4
	return int(p.base) + int(got)

static func tier_at(id: int, t: float) -> int:
	return int(G.rank_of(rank_rp(id, t)).tier)

# tiers of the whole population at time t (cached; used to pick weekly groups)
static func tiers_at(t: float) -> Array:
	var key: = int(t / 3600.0)
	if _tiers.has(key):
		return _tiers[key]
	var out: = []
	for i in COUNT:
		out.append(tier_at(i, t))
	if _tiers.size() > 16:
		_tiers.clear()
	_tiers[key] = out
	return out

static func quarter_rows(t: float) -> Array:
	var key: = int(t / 60.0)
	if _rows.has(key):
		return _rows[key]
	var out: = []
	for i in COUNT:
		out.append([i, rp_at(i, t)])
	out.sort_custom(func(a, b):
		if int(a[1]) == int(b[1]):
			return int(a[0]) < int(b[0])
		return int(a[1]) > int(b[1]))
	if _rows.size() > 8:
		_rows.clear()
	_rows[key] = out
	return out

# place among the population only (1-based); the player is inserted by V8League
static func quarter_place(id: int, t: float) -> int:
	var rows: = quarter_rows(t)
	for i in rows.size():
		if int(rows[i][0]) == id:
			return i + 1
	return rows.size()


# ---------------------------------------------------------------- weekly tournament points

static func _plan(id: int, wsd: int, league: int) -> Dictionary:
	var key: = "%d|%d|%d" % [id, wsd, league]
	if _plans.has(key):
		return _plans[key]
	var p: = get_p(id)
	var L: Dictionary = V7Ladder.league_def(league)
	var r: = RandomNumberGenerator.new()
	r.seed = hash("w|%d|%d" % [id, wsd])
	var idle: = r.randf() < float(L.idle)
	var days: int = p.days
	var w: = []
	var total: = 0.0
	for d in 7:
		var on: = r.randf() < (0.88 if d == 0 else float(days) / 7.0)
		if idle:
			on = d == 0 or r.randf() < 0.12
		var wd: = r.randf_range(0.6, 1.4) if on else 0.0
		w.append(wd)
		total += wd
	if total <= 0.0:
		w[0] = 1.0
		total = 1.0
	var my_tier: = tier_at(id, wsd * 86400.0)
	var u: = clampf(float(p.skill) * 0.75 + r.randf() * 0.35 - 0.05 + (my_tier - league) * 0.12, 0.0, 1.0)
	var f: = lerpf(float(L.f[0]), float(L.f[1]), u)
	var target: = 0.0
	for k in V7Ladder.TABLES:
		target += V7Ladder.table_par(k, wsd) * f * r.randf_range(0.9, 1.06)
	if idle:
		target *= r.randf_range(0.15, 0.5)
	var plan: = {"w": w, "total": total, "target": target, "gamma": r.randf_range(0.75, 1.2),
		"runs": r.randi_range(3, 4 + int(float(p.skill) * 6.0)) if not idle else r.randi_range(1, 2)}
	if _plans.size() > 4000:
		_plans.clear()
	_plans[key] = plan
	return plan

# share (0..1) of this week's play done by time t
static func week_share(id: int, t: float, league: int, wsd: = -1) -> float:
	if wsd < 0:
		wsd = week_start_day(t)
	var plan: = _plan(id, wsd, league)
	var x: = (t - wsd * 86400.0) / 3600.0
	if x <= 0.0:
		return 0.0
	if x >= 168.0:
		return 1.0
	var k: = floori(x / 24.0)
	var cum: = 0.0
	var w: Array = plan.w
	for j in k:
		cum += float(w[j])
	cum += float(w[k]) * _part(x / 24.0 - k, float(get_p(id).shift))
	return clampf(cum / float(plan.total), 0.0, 1.0)

# wsd: Monday (day number) of the week to read; by default the week that contains t.
# Pass it when t is the very end of a week (t = Monday 00:00 of the next week belongs to the next week).
static func week_points(id: int, t: float, league: int, wsd: = -1) -> int:
	if wsd < 0:
		wsd = week_start_day(t)
	var plan: = _plan(id, wsd, league)
	var c: = week_share(id, t, league, wsd)
	if c <= 0.0:
		return 0
	return int(round(float(plan.target) * pow(c, float(plan.gamma))))

static func games_week(id: int, t: float, league: int) -> int:
	var ws: = week_start_day(t) * 86400.0
	var qs: = float(quarter(t).start)
	var rp: = 0
	if ws >= qs:
		rp = rp_at(id, t) - rp_at(id, ws)
	else:
		rp = rp_at(id, t) + maxi(0, rp_at(id, qs - 1.0) - rp_at(id, ws))
	var plan: = _plan(id, week_start_day(t), league)
	var runs: = int(ceil(float(plan.runs) * week_share(id, t, league)))
	return maxi(0, int(round(float(rp) / float(get_p(id).rpg)))) + runs


# ---------------------------------------------------------------- avatars

static func face(img: String) -> Array:
	return FACES.get(img, [0.5, 0.18, 4.6])

static func my_avatar_img() -> String:
	var h: = String(G.profile().get("avatar", "mc"))
	if not G.HEROES.has(h):
		h = "mc"
	var oid: = String(G.S.get("outfit", {}).get(h, ""))
	if oid != "" and G.ITEM.has(oid):
		var it: Dictionary = G.ITEM[oid]
		if G.S.get("modest", false) and it.get("bold", false) and it.has("alt"):
			return String(it.alt)
		if it.has("img"):
			return G.item_img(it)
	return "%s_base" % h

# Round portrait in the gold avatar frame (V8Art.avatar). top = the Dragon/Celestial frame (V8Art.top_tier).
# `_ring` is kept for old callers and ignored.
static func avatar_view(img: String, hero: String, r: Rect2, _ring: = 3.0, top: = false) -> Control:
	var src: = img if ResourceLoader.exists("res://assets/outfits/%s.webp" % img) else (hero if G.HEROES.has(hero) else "mc")
	return V8Art.avatar(null, src, r, top)
