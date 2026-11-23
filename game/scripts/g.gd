extends Node


const SAVE_PATH: = "user://save.json"

const HEROES: = {
	"mc": {"name": "Маджонг-тян", "title": "Хозяйка «Пяти ветров»", "color": Color("ff8fb8")}, 
	"rin": {"name": "Рин", "title": "Мастер чая", "color": Color("b48cff")}, 
	"hana": {"name": "Хана", "title": "Капитан эстафеты", "color": Color("ffb35c")}, 
	"yue": {"name": "Юэ", "title": "Лунная принцесса", "color": Color("8fb4ff")}, 
	"nova": {"name": "Нова", "title": "Нетраннер", "color": Color("4fe3ff")}, 
}
const HERO_ORDER: = ["mc", "rin", "hana", "yue", "nova"]


var ITEMS: = [
	{"id": "o_base", "cat": "outfit", "hero": "mc", "rar": "R", "name": "Ципао наставницы", "img": "mc_base", "start": true}, 
	{"id": "o_tutor", "cat": "outfit", "hero": "mc", "rar": "SR", "name": "Репетитор после уроков", "img": "mc_tutor"}, 
	{"id": "o_cafe", "cat": "outfit", "hero": "mc", "rar": "SR", "name": "Официантка чайной", "img": "mc_cafe"}, 
	{"id": "o_dragon", "cat": "outfit", "hero": "mc", "rar": "SSR", "name": "Императрица дракона", "img": "mc_dragon"}, 
	{"id": "r_base", "cat": "outfit", "hero": "rin", "rar": "R", "name": "Мастер чая", "img": "rin_base"}, 
	{"id": "r_maid", "cat": "outfit", "hero": "rin", "rar": "SR", "name": "Горничная", "img": "rin_maid"}, 
	{"id": "r_after", "cat": "outfit", "hero": "rin", "rar": "SR", "name": "После работы", "img": "rin_after"}, 
	{"id": "r_agent", "cat": "outfit", "hero": "rin", "rar": "SSR", "name": "Городской агент", "img": "rin_agent"}, 
	{"id": "r_idol", "cat": "outfit", "hero": "rin", "rar": "SSR", "name": "Звёздная айдол", "img": "rin_idol"}, 
	{"id": "h_base", "cat": "outfit", "hero": "hana", "rar": "R", "name": "Спортивный стиль", "img": "hana_base"}, 
	{"id": "h_street", "cat": "outfit", "hero": "hana", "rar": "SR", "name": "Уличный раннер", "img": "hana_street"}, 
	{"id": "h_beach", "cat": "outfit", "hero": "hana", "rar": "SR", "name": "Летний пляж", "img": "hana_beach", "bold": true, "alt": "hana_base"}, 
	{"id": "h_gym", "cat": "outfit", "hero": "hana", "rar": "SSR", "name": "Чемпионка зала", "img": "hana_gym", "bold": true, "alt": "hana_street"}, 
	{"id": "y_base", "cat": "outfit", "hero": "yue", "rar": "SR", "name": "Лунная принцесса", "img": "yue_base"}, 
	{"id": "y_duel", "cat": "outfit", "hero": "yue", "rar": "SSR", "name": "Драконья дуэлянтка", "img": "yue_duel", "bold": true, "alt": "yue_base"}, 
	{"id": "y_queen", "cat": "outfit", "hero": "yue", "rar": "SSR", "name": "Королева лунной ночи", "img": "yue_queen"}, 
	{"id": "n_base", "cat": "outfit", "hero": "nova", "rar": "SR", "name": "Нетраннер", "img": "nova_base"}, 
	{"id": "n_ssr", "cat": "outfit", "hero": "nova", "rar": "SSR", "name": "Неоновый форсаж", "img": "nova_ssr", "bold": true, "alt": "nova_base"}, 

	{"id": "o_cozy", "cat": "outfit", "hero": "mc", "rar": "SR", "name": "Уютный вечер", "img": "mc_cozy", "shop": 680, "nogacha": true}, 
	{"id": "r_yukata", "cat": "outfit", "hero": "rin", "rar": "SR", "name": "Летняя юката", "img": "rin_yukata", "shop": 680, "nogacha": true}, 
	{"id": "h_winter", "cat": "outfit", "hero": "hana", "rar": "SR", "name": "Зимний каток", "img": "hana_winter", "shop": 680, "nogacha": true}, 
	{"id": "n_offline", "cat": "outfit", "hero": "nova", "rar": "SSR", "name": "Офлайн-выходной", "img": "nova_offline", "shop": 1280, "nogacha": true}, 
	{"id": "y_ball", "cat": "outfit", "hero": "yue", "rar": "SSR", "name": "Лунный бал", "img": "yue_ball", "pass": true, "nogacha": true}, 
	{"id": "s_sakura", "cat": "skin", "rar": "R", "name": "Фишки «Сакура»", "tile": 0, "start": true}, 
	{"id": "s_mint", "cat": "skin", "rar": "R", "name": "Фишки «Мята»", "tile": 5, "start": true}, 
	{"id": "s_lemon", "cat": "skin", "rar": "R", "name": "Фишки «Лимон»", "tile": 20}, 
	{"id": "s_night", "cat": "skin", "rar": "SR", "name": "Фишки «Полночь»", "tile": 7}, 
	{"id": "s_neon", "cat": "skin", "rar": "SR", "name": "Фишки «Неон»", "tile": 35}, 
	{"id": "s_gold", "cat": "skin", "rar": "SSR", "name": "Золото дракона", "tile": 25}, 
	{"id": "b_tea", "cat": "bg", "rar": "R", "name": "Фон «Чайный сад»", "bg": "play"}, 
	{"id": "b_palace", "cat": "bg", "rar": "SR", "name": "Фон «Лунный дворец»", "bg": "bg_palace"}, 
	{"id": "b_neon", "cat": "bg", "rar": "SSR", "name": "Фон «Неоновый город»", "bg": "bg_neon"}, 
	{"id": "b_fest", "cat": "bg", "rar": "R", "name": "Фон «Фестиваль»", "bg": "bg_festival"}, 
]
var ITEM: = {}

const TILE_NAMES: = ["sakura", "plum", "chrysanthemum", "sunflower", "tulip", "clover", "maple", "moon", "star", "sun", "rainbow", "snowflake", "fire", "water", "lightning", "dango", "cake", "strawberry", "peach", "cherry", "lemon", "matcha", "bubbletea", "bow", "diamond", "crown", "bell", "windchime", "lantern", "cat", "rabbit", "fox", "panda", "dragon", "koi", "butterfly"]



const LOCS: = [
	{"name": "Чайный сад", "bg": "play", "fx": "petals", "tint": Color(1, 1, 1), "hero": "mc", "shard": "rin", "item": "s_mint", 
		"intro": "Свободная фишка уходит в лоток, две одинаковые исчезают. Мест четыре — держи хотя бы одно пустым.", 
		"stages": [["rect", 5, 6, 2, 0.7, 6, "", 0], ["heart", 5, 6, 2, 0.75, 7, "", 0], ["diamond", 5, 6, 3, 0.6, 8, "gold", 0], ["butterfly", 6, 6, 3, 0.65, 9, "hidden", 1]]}, 
	{"name": "Чайная во льду", "bg": "bg_teahouse", "fx": "snow", "tint": Color(0.92, 0.97, 1.0), "hero": "rin", "shard": "rin", "item": "b_tea", 
		"intro": "Фишки рубашкой вверх: первое касание переворачивает фишку, второе берёт её в лоток.", 
		"stages": [["rect", 6, 6, 3, 0.6, 9, "ice", 0], ["cross", 6, 7, 3, 0.6, 9, "", 0], ["ring", 6, 7, 3, 0.65, 10, "ice", 0], ["pyramid", 7, 8, 4, 0.6, 11, "ice,hidden", 1]]}, 
	{"name": "Фестиваль фонарей", "bg": "bg_festival", "fx": "lanterns", "tint": Color(1, 0.95, 0.9), "hero": "hana", "shard": "hana", "item": "b_fest", 
		"intro": "Серия пар запускает фейерверк над крышами. Держи в лотке не больше двух разных фишек.", 
		"stages": [["butterfly", 6, 7, 3, 0.65, 11, "", 0], ["heart", 6, 7, 3, 0.7, 11, "gold", 0], ["towers", 7, 8, 4, 0.6, 12, "hidden", 0], ["diamond", 6, 7, 4, 0.7, 13, "gold,ice", 1]]}, 
	{"name": "Лунный дворец", "bg": "bg_palace", "fx": "fireflies", "tint": Color(0.93, 0.92, 1.0), "hero": "yue", "shard": "yue", "item": "s_night", 
		"intro": "Золотые фишки — дар луны, ×5 кристаллов. Тайные покажут лицо, только когда их освободишь.", 
		"stages": [["pyramid", 7, 8, 4, 0.6, 13, "gold", 0], ["ring", 6, 7, 4, 0.6, 13, "hidden", 0], ["butterfly", 6, 7, 4, 0.65, 14, "ice", 0], ["cross", 7, 8, 5, 0.7, 15, "gold,hidden", 2]]}, 
	{"name": "Драконье святилище", "bg": "bg_shrine", "fx": "mist", "tint": Color(1, 0.95, 0.95), "hero": "mc", "shard": "yue", "item": "s_gold", 
		"intro": "Здесь хранится Звёздный набор: все фишки разные. Думай на два хода вперёд.", 
		"stages": [["diamond", 6, 7, 4, 0.75, 15, "ice", 0], ["towers", 7, 8, 5, 0.65, 15, "gold", 0], ["heart", 6, 7, 5, 0.7, 16, "hidden,ice", 1], ["rect", 6, 7, 5, 0.75, 17, "gold,ice,hidden", 2]]}, 
	{"name": "Неоновая ночь", "bg": "bg_neon", "fx": "rain", "tint": Color(0.9, 0.95, 1.05), "hero": "nova", "shard": "nova", "item": "s_neon", 
		"intro": "Нова взломала вывески квартала. Золото, перевёртыши и тайные фишки — всё разом.", 
		"stages": [["rect", 6, 7, 5, 0.7, 17, "gold", 0], ["butterfly", 6, 7, 5, 0.7, 17, "hidden", 0], ["ring", 6, 7, 5, 0.7, 18, "ice,gold", 1], ["pyramid", 7, 8, 5, 0.75, 18, "gold,ice,hidden", 2]]}, 
]
const SHAPE_NAMES: = {"rect": "Плато", "heart": "Сердце", "diamond": "Ромб", "butterfly": "Бабочка", "cross": "Крест", "ring": "Кольцо", "pyramid": "Пагода", "towers": "Две башни"}
const HARD_NAMES: = ["", "Сложный", "Очень сложный"]
var LEVELS: = []

func _build_levels() -> void :
	LEVELS.clear()
	for li in LOCS.size():
		var L: Dictionary = LOCS[li]
		var stl: Array = V6Worlds.stages(li, L)
		for si in stl.size():
			var st: Array = stl[si]
			var mech: String = st[6]
			var n: = LEVELS.size()
			var lv: = {
				"name": L.name, "loc": li, "stage": si, "code": "%d-%d" % [li + 1, si + 1], 
				"bg": L.bg, "fx": L.fx, "tint": L.tint, "hero": L.hero, "shard": L.shard, 
				"shape": st[0], "cols": st[1], "rows": st[2], "layers": st[3], "fill": st[4], "faces": st[5], 
				"mech": mech, "hard": st[7], "seed": 11 + n * 11, 
				"gold": (4 + 2 * (li / 2)) if "gold" in mech else 0, 
				"ice": (3 + li) if "ice" in mech else 0, 
				"hidden": "hidden" in mech, 
				"reward": {"gems": 100 + n * 10 + st[7] * 60}, 
				"goal": "Очисти стол и найди осколок портрета: %s" % HEROES[L.shard].name, 
				"intro": L.intro, 
			}
			V6Worlds.decorate(lv, st, li, si)
			if si == stl.size() - 1:
				lv.reward["item"] = L.item
			if n == 0:
				lv.reward["item"] = "s_lemon"
			LEVELS.append(lv)


func level_feature(lv: Dictionary) -> String:
	var parts: = [V6Layouts.shape_name(lv.shape)]
	if lv.gold > 0:
		parts.append("золото")
	if lv.ice > 0:
		parts.append("перевёртыши")
	if lv.hidden:
		parts.append("тайные фишки")
	parts.append("%d слоя" % lv.layers if lv.layers < 5 else "%d слоёв" % lv.layers)
	return " · ".join(parts)


const RANKS: = [
	{"name": "Бамбук", "color": Color("7fd18b"), "dark": Color("2f6b3a"), "per": 60, "gems": 150}, 
	{"name": "Нефрит", "color": Color("3fd6b0"), "dark": Color("16614f"), "per": 100, "gems": 250}, 
	{"name": "Жемчуг", "color": Color("e9e4ff"), "dark": Color("5b4f8a"), "per": 150, "gems": 400}, 
	{"name": "Золото", "color": Color("ffc93c"), "dark": Color("7a4a0c"), "per": 220, "gems": 600}, 
	{"name": "Дракон", "color": Color("ff5a7a"), "dark": Color("6a1030"), "per": 300, "gems": 900}, 
	{"name": "Небожитель", "color": Color("c9a2ff"), "dark": Color("3f1f7a"), "per": 400, "gems": 1200}, 
]
const ROMAN: = ["I", "II", "III"]


func rank_of(rp: int) -> Dictionary:
	var left: = rp
	for t in RANKS.size():
		var per: int = RANKS[t].per
		var subs: = 3 if t < RANKS.size() - 1 else 999
		for s in subs:
			if left < per:
				return {"tier": t, "sub": s, "into": left, "need": per, "title": rank_title(t, s)}
			left -= per
	return {"tier": RANKS.size() - 1, "sub": 0, "into": 0, "need": 1, "title": RANKS[-1].name}

func rank_title(t: int, s: int) -> String:
	if t == RANKS.size() - 1:
		return "%s %d" % [RANKS[t].name, s + 1]
	return "%s %s" % [RANKS[t].name, ROMAN[s]]

func rank_index(rp: int) -> int:
	var r: = rank_of(rp)
	return r.tier * 3 + r.sub


func add_rp(n: int) -> Array:
	var before: = rank_index(int(S.rp))
	S.rp = int(S.rp) + n
	var ups: = []
	var after: = rank_index(int(S.rp))
	for k in range(before + 1, after + 1):
		var t: = mini(k / 3, RANKS.size() - 1)
		var s: = k - t * 3
		var g: int = RANKS[t].gems if s == 0 else 50 * (t + 1)
		S.gems += g
		ups.append({"tier": t, "sub": s, "gems": g})
	return ups


const CATS: = [[0, 6, "Букет", "цветы"], [7, 14, "Небосвод", "небо"], [15, 22, "Сладкоежка", "сладости"], [23, 28, "Сокровищница", "сокровища"], [29, 35, "Зверинец", "звери"]]
const YAKU: = {
	"clean": {"name": "Чистая рука", "rp": 15, "desc": "без помощи и переполнений"}, 
	"calm": {"name": "Пустой лоток", "rp": 12, "desc": "в лотке не больше двух фишек"}, 
	"sharp": {"name": "Без промаха", "rp": 8, "desc": "ни одного касания по закрытой"}, 
	"swift": {"name": "Молния", "rp": 10, "desc": "очень быстрая победа"}, 
	"riichi": {"name": "Риичи", "rp": 20, "desc": "объявлено и выиграно, награда ×2"}, 
	"dragon": {"name": "Пробуждение дракона", "rp": 15, "desc": "комбо ×7"}, 
	"goldvein": {"name": "Золотая жила", "rp": 6, "desc": "все золотые пары"}, 
	"finale": {"name": "Финальный аккорд", "rp": 6, "desc": "последняя пара в комбо"}, 
	"set": {"name": "Тройка", "rp": 8, "desc": "три пары одной масти подряд"}, 
}

func face_cat(f: int) -> int:
	for i in CATS.size():
		if f >= CATS[i][0] and f <= CATS[i][1]:
			return i
	return -1



const SKIN_LOOK: = {
	"s_sakura": {"side": Color("e8789f"), "rim": Color("f6dfe6"), "tint": Color(1, 1, 1)}, 
	"s_mint": {"side": Color("3f9c7c"), "rim": Color("e6d3b3"), "tint": Color(1, 1, 1)}, 
	"s_lemon": {"side": Color("e3b53a"), "rim": Color("fff1c9"), "tint": Color(1, 1, 0.97)}, 
	"s_night": {"side": Color("232a52"), "rim": Color("c9a55a"), "tint": Color(0.97, 0.97, 1.03)}, 
	"s_neon": {"side": Color("3b2a6e"), "rim": Color("49e3ff"), "tint": Color(1, 1, 1), "neon": true}, 
	"s_gold": {"side": Color("a8741c"), "rim": Color("ffe08a"), "tint": Color(1.04, 1.0, 0.92)}, 
}

const BASE_OUTFITS: = ["o_base", "r_base", "h_base", "y_base", "n_base"]


func equipped(h: String) -> String:
	var id: String = S.outfit.get(h, "")
	if id == "" or id in BASE_OUTFITS or not owns(id) or not ITEM.has(id):
		return ""
	return id

func skin_source(id: String) -> String:
	for lv in LEVELS:
		if lv.reward.get("item", "") == id:
			return "награда за партию %s" % lv.code
	return "в Желаниях"

func skin_look() -> Dictionary:
	return SKIN_LOOK.get(S.get("skin", "s_sakura"), SKIN_LOOK.s_sakura)

const SHARDS_NEED: = 5


const PERKS: = {
	"mc": "+1 бесплатная подсказка", 
	"rin": "+1 бесплатная отмена", 
	"hana": "Окно комбо +1 секунда", 
	"yue": "Золотые фишки ×8 вместо ×5", 
	"nova": "+1 перемешивание и +10% кристаллов", 
}

const SKILLS: = {
	"mc": {"name": "Подсказка сердца", "desc": "сама убирает одну пару"}, 
	"rin": {"name": "Чайная пауза", "desc": "возвращает весь лоток на стол"}, 
	"hana": {"name": "Рывок", "desc": "убирает две пары подряд"}, 
	"yue": {"name": "Лунный свет", "desc": "переворачивает все закрытые фишки и показывает пару"}, 
	"nova": {"name": "Взлом", "desc": "снимает самую глубоко спрятанную пару"}, 
}


const FORTUNES: = [
	{"id": "great", "rank": "Великая удача", "name": "Щедрый вечер", "desc": "Кристаллы за эту партию +50%.", "w": 2}, 
	{"id": "tray", "rank": "Великая удача", "name": "Ладонь кицунэ", "desc": "Если лоток переполнится, он один раз спасётся сам.", "w": 2}, 
	{"id": "pairs", "rank": "Удача", "name": "Счастливое начало", "desc": "Первые три пары приносят втрое больше кристаллов.", "w": 3}, 
	{"id": "wind", "rank": "Удача", "name": "Ветер перемен", "desc": "Ещё одно бесплатное смешивание.", "w": 3}, 
	{"id": "reveal", "rank": "Удача", "name": "Лунный взгляд", "desc": "Тайные фишки открыты с самого начала.", "w": 2}, 
	{"id": "gold", "rank": "Удача", "name": "Золотой дождь", "desc": "На столе появятся ещё четыре золотые фишки.", "w": 3, "gold": 4}, 
	{"id": "tea", "rank": "Малая удача", "name": "Тёплый чай", "desc": "Комбо держится на полторы секунды дольше.", "w": 3}, 
	{"id": "small", "rank": "Малая удача", "name": "Шёпот ветра", "desc": "Одна подсказка сверху.", "w": 3}, 
	{"id": "later", "rank": "Будущая удача", "name": "Терпение", "desc": "Сегодня без подарка. Зато следующее гадание точно будет великой удачей.", "w": 2}, 
]

func draw_fortune(lv: = {}) -> Dictionary:
	var pool: = FORTUNES.filter( func(f): return f.id != "reveal" or lv.get("hidden", false))
	if S.get("next_great", false):
		S.next_great = false
		var gs: = FORTUNES.filter( func(f): return f.rank == "Великая удача")
		return gs[randi() % gs.size()]
	var total: = 0
	for f in pool:
		total += int(f.w)
	var r: = randi() % total
	for f in pool:
		r -= int(f.w)
		if r < 0:
			if f.id == "later":
				S.next_great = true
			return f
	return FORTUNES[0]

const PULL_COST: = 150
const NEWBIE_COST: = 1200
const EXCHANGE_COST: = 120

const BANNERS: = [
	{"id": "newbie", "name": "Первый гость", "sub": "20 желаний со скидкой 20%, SSR среди них", "hero": "mc", "item": "o_dragon", "img": "mc_dragon", "color": Color("ff8fb8"), "newbie": true}, 
	{"id": "moon", "name": "Лунная ночь", "sub": "Шанс SSR повышен", "hero": "yue", "item": "y_queen", "img": "yue_queen", "color": Color("8f7cff")}, 
	{"id": "neon", "name": "Неоновый форсаж", "sub": "Только на время события", "hero": "nova", "item": "n_ssr", "img": "nova_ssr", "color": Color("38d9ff")}, 
]

var S: = {}
var demo: = false
var demo_force_ssr: = false
var current_level: = 0
var rng: = RandomNumberGenerator.new()
var time: = 0.0
var offer_shown: = false

func _process(dt: float) -> void :
	time += dt

func _ready() -> void :
	for it in ITEMS:
		ITEM[it.id] = it
	_build_levels()
	demo = "--demo" in OS.get_cmdline_user_args()
	rng.randomize()
	load_game()

func default_state() -> Dictionary:
	var owned: = {}
	for it in ITEMS:
		if it.get("start", false):
			owned[it.id] = true
	return {
		"gems": 1500, "coins": 2400, "player_lv": 7, "xp": 340, "unlocked": 1, "stars": {}, 
		"owned": owned, "partner": "mc", "outfit": {"mc": "o_base"}, "skin": "s_sakura", 
		"pity": 0, "aff": {"mc": 120, "rin": 40, "hana": 30, "yue": 0, "nova": 0}, 
		"daily_day": "", "streak": 0, "sound": true, "music": true, "pulls": 0, 
		"level_partner": "mc", "tut_done": false, "free10": false, "newbie_left": 20, "newbie_ssr": false, 
		"guar": false, "sr_pity": 0, "ex": 0, 
		"pet": {"day": "", "n": 0}, 
		"tasks": {"day": "", "pairs": 0, "levels": 0, "combo5": 0, "claimed": [false, false, false]}, 
		"login": {"n": 0, "last": ""}, 
		"dailymap": {"month": "", "done": []}, 
		"pass": {"owned": false, "xp": 0, "claimed": 0}, 
		"month_card": {"until": "", "last": ""}, 
		"modest": false, "cutins": true, "voice": true, "first_buy": {}, "shards": {}, "side": "f", 
		"rp": 0, "ver": 5, "yaku_seen": {}, "blitz_best": 0, "next_great": false, "intro_done": false, 
	}

func load_game() -> void :
	S = default_state()
	if demo:

		S.unlocked = 3
		S.stars = {"0": 3, "1": 3}
		S.rp = 50
		S.owned["s_mint"] = true
		S.owned["b_tea"] = true
		S.tut_done = true
		S.level_partner = "mc"
		return
	if FileAccess.file_exists(SAVE_PATH):
		var f: = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:
				S[k] = d[k]
			if int(d.get("ver", 0)) < 4:

				var old_unl: = int(S.unlocked)
				var ns: = {}
				for k in S.stars:
					ns[str(int(k) * 4)] = S.stars[k]
				S.stars = ns
				S.unlocked = mini(1 + (old_unl - 1) * 4, LEVELS.size())
				S.ver = 4

			if int(S.get("ver", 0)) < 5:
				var ns5: = {}
				for k in S.stars:
					ns5[str(V6Worlds.migrate_index(int(k)))] = S.stars[k]
				S.stars = ns5
				S.unlocked = mini(V6Worlds.migrate_index(maxi(0, int(S.unlocked) - 1)) + 1, LEVELS.size())
				S["v6_map"] = {"chests": {}, "seen": int(S.unlocked)}
				S.ver = 5


func save() -> void :
	if demo:
		return
	var f: = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(S))

func level_stars(i: int) -> int:
	return int(S.stars.get(str(i), 0))

func owns(id: String) -> bool:
	return S.owned.has(id)

func give(id: String) -> bool:

	if owns(id):
		S.gems += 25
		return false
	S.owned[id] = true
	return true

func add_aff(hero: String, n: int) -> void :
	S.aff[hero] = int(S.aff.get(hero, 0)) + n

func aff_level(hero: String) -> int:
	return 1 + int(S.aff.get(hero, 0)) / 100

func item_tex(it: Dictionary) -> Texture2D:
	if it.has("img"):
		return load("res://assets/outfits/%s.webp" % it.img)
	if it.has("tile"):
		return tile_tex(it.tile)
	if it.has("bg"):
		return load("res://assets/bg/%s.webp" % it.bg)
	return null

func tile_tex(i: int) -> Texture2D:
	return load("res://assets/tiles/%02d_%s.png" % [i, TILE_NAMES[i]])

func icon(name: String) -> Texture2D:

	if ResourceLoader.exists("res://assets/v06/hud/icons/%s.png" % name):
		return load("res://assets/v06/hud/icons/%s.png" % name)
	return load("res://assets/icons/%s.png" % name)

func fx(name: String) -> Texture2D:
	return load("res://assets/fx/%s.png" % name)

func rar_color(r: String) -> Color:
	match r:
		"SSR": return Color("ffc93c")
		"SR": return Color("c08bff")
	return Color("7cc6ff")


func art_tex(it: Dictionary) -> Texture2D:

	if S.get("modest", false) and it.get("bold", false) and it.has("alt"):
		return load("res://assets/outfits/%s.webp" % it.alt)
	return item_tex(it)

func today() -> String:
	return Time.get_date_string_from_system()

func days_between(a: String, b: String) -> int:
	if a == "" or b == "":
		return 9999
	return int((Time.get_unix_time_from_datetime_string(b) - Time.get_unix_time_from_datetime_string(a)) / 86400)

func hero_unlocked(h: String) -> bool:
	if h == "mc" or int(S.shards.get(h, 0)) >= SHARDS_NEED:
		return true
	for it in ITEMS:
		if it.get("hero", "") == h and owns(it.id):
			return true
	return false

func summon_open() -> bool:
	return int(S.unlocked) >= 4

func tasks() -> Dictionary:
	if S.tasks.get("day", "") != today():
		S.tasks = {"day": today(), "pairs": 0, "levels": 0, "combo5": 0, "claimed": [false, false, false]}
	return S.tasks

const TASKS: = [
	{"key": "pairs", "name": "Собери 40 пар", "goal": 40, "gems": 60}, 
	{"key": "levels", "name": "Сыграй 2 партии", "goal": 2, "gems": 60}, 
	{"key": "combo5", "name": "Собери серию ×5", "goal": 1, "gems": 80}, 
]

func task_add(key: String, n: = 1) -> void :
	var t: = tasks()
	t[key] = int(t.get(key, 0)) + n

func tasks_ready() -> int:
	var t: = tasks()
	var n: = 0
	for i in TASKS.size():
		if int(t[TASKS[i].key]) >= TASKS[i].goal and not t.claimed[i]:
			n += 1
	return n

func pet_left() -> int:
	if S.pet.get("day", "") != today():
		S.pet = {"day": today(), "n": 0}
	return 3 - int(S.pet.n)

const LOGIN_REWARDS: = [
	{"gems": 50}, {"gems": 50}, {"coins": 500}, {"gems": 100}, {"gems": 50}, {"coins": 1000}, {"gems": 300}, 
]

func login_ready() -> bool:
	return S.login.get("last", "") != today()

func dailymap() -> Dictionary:
	var m: = today().substr(0, 7)
	if S.dailymap.get("month", "") != m:
		S.dailymap = {"month": m, "done": []}
	return S.dailymap

func daily_done_today() -> bool:
	return int(today().substr(8, 2)) in dailymap().done.map( func(x): return int(x))

func pass_tier() -> int:
	return mini(30, int(S.pass.xp) / 100)

func add_pass_xp(n: int) -> void :
	S.pass.xp = int(S.pass.xp) + n

func month_card_days() -> int:
	var u: String = S.month_card.get("until", "")
	if u == "":
		return 0
	return maxi(0, days_between(today(), u))




func roll() -> String:
	S.pity = int(S.pity) + 1
	S.sr_pity = int(S.sr_pity) + 1
	var rate: = 0.03
	if S.pity >= 60:
		rate = 1.0
	elif S.pity > 45:
		rate = 0.03 + (S.pity - 45) * 0.06
	var r: = rng.randf()
	if r < rate:
		S.pity = 0
		S.sr_pity = 0
		return "SSR"
	if S.sr_pity >= 10 or r < rate + 0.15:
		S.sr_pity = 0
		return "SR"
	return "R"

func pull(n: int, banner: Dictionary) -> Array:
	var res: = []
	var newbie: bool = banner.get("newbie", false)
	for i in n:
		var rar: = roll()
		if demo_force_ssr and n == 10 and i == 6:
			rar = "SSR"
			S.pity = 0
		if newbie:
			S.newbie_left = int(S.newbie_left) - 1
			if rar == "SSR":
				S.newbie_ssr = true
			elif int(S.newbie_left) <= 0 and not S.newbie_ssr:
				rar = "SSR"
				S.pity = 0
				S.newbie_ssr = true
		var pool: = ITEMS.filter( func(x): return x.rar == rar and not x.get("start", false) and not x.get("nogacha", false))
		var it: Dictionary = pool[rng.randi() % pool.size()]
		if rar == "SSR":
			if newbie:
				pool = pool.filter( func(x): return x.cat == "outfit")
				it = pool[rng.randi() % pool.size()]
			elif S.guar or rng.randf() < 0.5 or (demo_force_ssr and i == 6):
				it = ITEM[banner.item]
				S.guar = false
			else:
				var off: = pool.filter( func(x): return x.id != banner.item)
				it = off[rng.randi() % off.size()]
				S.guar = true
		var is_new: = give(it.id)
		var r: = it.duplicate()
		r["new"] = is_new
		res.append(r)
	S.pulls = int(S.pulls) + n
	S.ex = int(S.ex) + n
	add_pass_xp(10 * n)
	save()
	return res
