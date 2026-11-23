class_name V8Nicks
extends RefCounted

# Small nickname generator for the profile card (🎲 «случайный»).
# Russian and Latin nicks in mobile-game style, built from neutral word lists:
# no real people's names, no brands. Every result passes G.nick_error().
#   V8Nicks.random()            -> random nick
#   V8Nicks.random(rng)         -> with your own RandomNumberGenerator (deterministic by seed)
# V8Population (Stream B) may reuse V8Nicks.from_seed(seed).

const RU_ADJ: = [
	"Лунный", "Тихий", "Чайный", "Ночной", "Звёздный", "Ленивый", "Хитрый", "Сонный", "Весёлый", "Снежный",
	"Ветреный", "Рыжий", "Северный", "Мятный", "Бумажный", "Янтарный", "Медовый", "Туманный", "Смелый", "Дикий",
]
const RU_ADJ_F: = [
	"Лунная", "Тихая", "Чайная", "Ночная", "Звёздная", "Ленивая", "Хитрая", "Сонная", "Весёлая", "Снежная",
	"Ветреная", "Рыжая", "Северная", "Мятная", "Бумажная", "Янтарная", "Медовая", "Туманная", "Смелая", "Дикая",
]
const RU_NOUN: = [
	"Кот", "Лис", "Дракон", "Журавль", "Фонарь", "Ветер", "Панда", "Енот", "Филин", "Тигр",
	"Карп", "Барсук", "Ёж", "Бамбук", "Самурай", "Странник", "Мастер", "Пион", "Чайник", "Дракончик",
]
const RU_NOUN_F: = [
	"Сова", "Лиса", "Луна", "Сакура", "Кошка", "Звезда", "Чашка", "Панда", "Лилия", "Слива",
	"Тень", "Белка", "Рыбка", "Птица", "Гейша", "Фея", "Комета", "Волна", "Нота", "Искра",
]
const LAT_A: = [
	"Moon", "Tea", "Night", "Star", "Lucky", "Silent", "Neon", "Snow", "Jade", "Amber",
	"Red", "Wild", "Sleepy", "Pixel", "Paper", "Mint", "Honey", "Storm", "Tiny", "Shadow",
]
const LAT_B: = [
	"Fox", "Cat", "Tile", "Dragon", "Crane", "Lotus", "Panda", "Tiger", "Owl", "Koi",
	"Sakura", "Ronin", "Ninja", "Bamboo", "Wind", "Lantern", "Dumpling", "Comet", "Mochi", "Kitsune",
]
const SYL: = ["ka", "ri", "no", "mi", "ra", "to", "ya", "shi", "ko", "ne", "su", "ha", "yu", "ki", "mo", "ta", "chi", "ro", "na", "fu"]


static func random(rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for _i in 12:
		var n: = _make(rng)
		if _ok(n):
			return n
	return "Гость%d" % rng.randi_range(100, 999)


static func from_seed(s: int) -> String:
	var rng: = RandomNumberGenerator.new()
	rng.seed = s
	return random(rng)


static func _pick(rng: RandomNumberGenerator, a: Array) -> String:
	return str(a[rng.randi_range(0, a.size() - 1)])


static func _make(rng: RandomNumberGenerator) -> String:
	var kind: = rng.randi_range(0, 9)
	match kind:
		0, 1:
			return _pick(rng, RU_ADJ) + _pick(rng, RU_NOUN)
		2, 3:
			var i: = rng.randi_range(0, RU_ADJ_F.size() - 1)
			return str(RU_ADJ_F[i]) + "_" + _pick(rng, RU_NOUN_F)
		4:
			return _pick(rng, RU_NOUN) + str(rng.randi_range(7, 99))
		5, 6:
			return _pick(rng, LAT_A) + _pick(rng, LAT_B)
		7:
			return (_pick(rng, LAT_A) + "_" + _pick(rng, LAT_B)).to_lower()
		8:
			return _pick(rng, LAT_B) + str(rng.randi_range(10, 999))
		_:
			var s: = ""
			for k in rng.randi_range(2, 3):
				s += _pick(rng, SYL)
			return s.capitalize().replace(" ", "") + str(rng.randi_range(1, 99))


static func _ok(n: String) -> bool:
	return G.nick_error(n) == ""
