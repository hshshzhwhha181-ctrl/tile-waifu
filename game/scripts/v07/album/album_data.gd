class_name V7AlbumData
extends RefCounted



const FACE_NAMES: = ["Сакура", "Слива", "Хризантема", "Подсолнух", "Тюльпан", "Клевер", "Клён", 
	"Луна", "Звезда", "Солнце", "Радуга", "Снежинка", "Огонь", "Вода", "Молния", 
	"Данго", "Торт", "Клубника", "Персик", "Вишня", "Лимон", "Матча", "Бабл-ти", 
	"Бант", "Алмаз", "Корона", "Колокольчик", "Фурин", "Фонарь", 
	"Кошка", "Кролик", "Лиса", "Панда", "Дракон", "Карп кои", "Бабочка"]


const TIERS: = [1, 10, 30]
const TIER_NAMES: = ["Бронза", "Серебро", "Золото"]
const TIER_COLORS: = [Color("d69a6a"), Color("d9dde6"), Color("f2cd6e")]



const SUITS: = [
	{"id": "suit0", "cat": 0, "name": "Букет", "bonus": "+1 подсказка в каждой партии", "key": "hint", "gems": 150, "gold_gems": 400}, 
	{"id": "suit1", "cat": 1, "name": "Небосвод", "bonus": "+1 смешивание в каждой партии", "key": "shuffle", "gems": 150, "gold_gems": 400}, 
	{"id": "suit2", "cat": 2, "name": "Сладкоежка", "bonus": "+10% кристаллов за пары", "key": "gems", "gems": 150, "gold_gems": 400}, 
	{"id": "suit3", "cat": 3, "name": "Сокровищница", "bonus": "Золотые пары дают на ×1 больше", "key": "gold", "gems": 150, "gold_gems": 400}, 
	{"id": "suit4", "cat": 4, "name": "Зверинец", "bonus": "Окно комбо +0,5 секунды", "key": "combo", "gems": 150, "gold_gems": 400}, 
]


const SKIN_SETS: = [
	{"id": "skins_day", "name": "Дневной сервиз", "items": ["s_sakura", "s_mint", "s_lemon"], "bonus": "+1 отмена в каждой партии", "key": "undo", "gems": 200}, 
	{"id": "skins_night", "name": "Ночной сервиз", "items": ["s_night", "s_neon", "s_gold"], "bonus": "+10% кристаллов за пары", "key": "gems", "gems": 300}, 
]


const TABLES: = [
	{"id": "default", "name": "Графит и роза", "desc": "Стол хозяйки «Пяти ветров»", "unlock": "free"}, 
	{"id": "play", "name": "Нефритовый шёлк", "desc": "Чайный сад", "unlock": "boss:0", "item": "b_tea"}, 
	{"id": "bg_teahouse", "name": "Иней и серебро", "desc": "Чайная во льду", "unlock": "boss:1"}, 
	{"id": "bg_festival", "name": "Алый бархат", "desc": "Фестиваль фонарей", "unlock": "boss:2", "item": "b_fest"}, 
	{"id": "bg_palace", "name": "Лунный индиго", "desc": "Лунный дворец", "unlock": "boss:3", "item": "b_palace"}, 
	{"id": "bg_shrine", "name": "Драконья киноварь", "desc": "Драконье святилище", "unlock": "boss:4"}, 
	{"id": "bg_neon", "name": "Неоновая сетка", "desc": "Неоновая ночь", "unlock": "boss:5", "item": "b_neon"}, 
]
const TABLE_SETS: = [
	{"id": "tables4", "name": "Гость четырёх столов", "need": 4, "bonus": "Окно комбо +0,5 секунды", "key": "combo", "gems": 200}, 
	{"id": "tables7", "name": "Хозяин всех столов", "need": 7, "bonus": "+10% кристаллов за пары", "key": "gems", "gems": 500}, 
]


const FRAMES: = [
	{"id": "rose", "name": "Роза", "trim": Color("e3a1b0"), "deep": Color("5a2433"), "unlock": "free"}, 
	{"id": "graphite", "name": "Графит", "trim": Color("e8c47e"), "deep": Color("16131a"), "unlock": "free"}, 
	{"id": "moon", "name": "Лунное золото", "trim": Color("f2cd6e"), "deep": Color("1c1838"), "unlock": "suits:3"}, 
	{"id": "neon", "name": "Неон", "trim": Color("49e3ff"), "deep": Color("0a0b1c"), "unlock": "tables:4"}, 
]
const FILTERS: = [
	{"id": "none", "name": "Без фильтра"}, 
	{"id": "warm", "name": "Тёплый вечер"}, 
	{"id": "night", "name": "Ночь"}, 
	{"id": "film", "name": "Плёнка"}, 
]

static func suit_faces(cat: int) -> Array:
	var r: = []
	for f in range(G.CATS[cat][0], G.CATS[cat][1] + 1):
		r.append(f)
	return r

static func tier_of(n: int) -> int:

	var t: = 0
	for i in TIERS.size():
		if n >= TIERS[i]:
			t = i + 1
	return t
