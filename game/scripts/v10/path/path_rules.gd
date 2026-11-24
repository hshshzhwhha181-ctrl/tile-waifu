class_name V10PathRules
extends RefCounted

# 0.10 · Путь (M2 П1–П3): constants, names, colours and the default reward numbers of the Path map.
# Reward numbers are DEFAULTS: when V10Econ (economy.json, 0.10-spec §2.2) is in the build, `num()` reads it.

const ARCS_RELEASED: = 2            # 0.10: arcs 1–2 (1–200); arcs 3+ show a silhouette «Арка выходит с обновлением»
const DAILY_FULL: = 15              # full Path reward for 15 wins a day (0.10-spec §2.3)
const DAILY_FULL_SHOW: = 10         # «полная награда 9/15» is hidden until the 10th win of the day
const ASSIST_AFTER: = 2             # fails in a row before the hostess offers an easier deal
const LEGEND_BYPASS_AFTER: = 5      # «Обходная тропа» after 5 fails on a Legendary
const STAR_CHEST_NEED: = 25         # chapter star chest: 25★ of 30
const SUMMIT_STEP: = 10             # every 10 summits = one step of the «Восходящая» frame (I–X)
const BOOST_PRICE: = 60             # a booster bought for crystals when the stock is empty (with confirm)
const BOOST_MAX: = 3                # max boosters per level
const ARC_TITLES: = ["Пробуждение чайной", "Чайная во льду", "Фестиваль фонарей", "Лунный дворец", "Драконье святилище",
	"Неоновая ночь", "Храм Тысячи врат", "Жемчужный дворец", "Алая ночь", "Царство Жар-птицы"]

# reward defaults (economy.json keys in comments)
const R: = {
	"chapter_chest": {"gems": 20, "coins": 100},        # path.chapter_chest
	"star_chest": {"gems": 40, "petals": 10},           # path.star_chest
	"arc_end": {"tickets": 1},                          # path.arc_end (+ laurel only after a real Legendary win)
	"peak_first": {"gems": 30},                         # path.peak_first
	"legend_first": {"gems": 150},                      # path.legend_first (+ laurel)
}

# tier → node look. mint · cream · lilac + 1 flame · crimson + 2 flames + pulse · gold crown (0.10-spec П1)
const TIER_LOOK: = {
	"tutorial": {"top": Color("c9f0dd"), "bot": Color("5fae8c"), "rim": Color("e8fff4"), "flames": 0, "name": "Обучение"},
	"easy": {"top": Color("c9f0dd"), "bot": Color("4f9f7e"), "rim": Color("e8fff4"), "flames": 0, "name": "Передышка"},
	"normal": {"top": Color("fff3dc"), "bot": Color("d6b98a"), "rim": Color("fffaf0"), "flames": 0, "name": "Обычный"},
	"hard": {"top": Color("e3d2ff"), "bot": Color("8a63c9"), "rim": Color("f3ecff"), "flames": 1, "name": "Сложный"},
	"very_hard": {"top": Color("ffb3c0"), "bot": Color("b3223f"), "rim": Color("ffe1e6"), "flames": 2, "name": "Очень сложный"},
	"legendary": {"top": Color("ffe9a8"), "bot": Color("c48a1c"), "rim": Color("fff6d6"), "flames": 3, "name": "Легендарный"},
}

const MECH_NAMES: = {"gold": "Золотые фишки", "ice": "Перевёртыши", "gift": "Шкатулка", "hidden": "Тайные фишки",
	"lock": "Замок и ключ", "chain": "Цепь", "joker": "Джокер", "bomb": "Хлопушка", "lock2": "Замки двух цветов",
	"chain_long": "Длинные цепи", "ice_heavy": "Стол перевёртышей", "starset": "Звёздный набор",
	"fog": "Туман", "lantern_timer": "Фонарь-срок"}

# modes where only honest play is allowed (0.10-spec П3): boosters grey «Здесь только честная игра»
const HONEST_MODES: = ["peak", "legend", "pagoda", "wander", "ranked", "palm", "duel_ranked", "challenge"]
const HONEST_TIERS: = ["very_hard", "legendary"]
const BOOSTERS: = ["lantern", "wind", "scroll"]
const BOOSTER_NAMES: = {"lantern": "Фонарик", "wind": "Попутный ветер", "scroll": "Свиток"}
const BOOSTER_HELP: = {"lantern": "На старте раскрыты тайные фишки и перевёртыши.",
	"wind": "Две пары улетают со стола на старте (в комбо не идут).",
	"scroll": "+3 подсказки на эту партию."}

const HOST_NAMES: = {"mc": "Маджонг-тян", "rin": "Рин", "hana": "Хана", "yue": "Юэ", "nova": "Нова"}
const ROMAN: = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

const ART_DIR: = "res://assets/v10/path/"
const OLD_MAP_DIR: = "res://assets/v06/map/"

static var _econ = null
static var _econ_checked: = false


# a global script class by name (V10Econ, V10Wallet, V10Meta, V10ProfileCos …) or null when that lane is not merged
static func cls(name: String):
	for c in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == name:
			return load(str(c.path))
	return null


# reward bundle by key; economy.json wins when V10Econ is present
static func reward(key: String) -> Dictionary:
	if not _econ_checked:
		_econ_checked = true
		_econ = cls("V10Econ")
	if _econ != null and _econ.has_method("get_value"):
		var v = _econ.get_value("path." + key, null)
		if v is Dictionary:
			return v
	return (R.get(key, {}) as Dictionary).duplicate()


static func tier_look(tier: String) -> Dictionary:
	return TIER_LOOK.get(tier, TIER_LOOK.normal)


static func host_name(h: String) -> String:
	return HOST_NAMES.get(h, h.capitalize())


static func roman(n: int) -> String:
	return ROMAN[clampi(n, 0, 10)]


static func cover(w: int) -> Texture2D:
	var p: = ART_DIR + "cover_w%d.webp" % (w + 1)
	if ResourceLoader.exists(p):
		return load(p)
	return null


static func map_bg(w: int) -> Texture2D:
	var p: = OLD_MAP_DIR + "w%d.webp" % (w % 6 + 1)
	if ResourceLoader.exists(p):
		return load(p)
	return null


static func icon(name: String) -> Texture2D:
	var p: = ART_DIR + "ic_%s.png" % name
	if ResourceLoader.exists(p):
		return load(p)
	return null


static func plural(n: int, one: String, few: String, many: String) -> String:
	var m10: = n % 10
	var m100: = n % 100
	if m10 == 1 and m100 != 11:
		return one
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return few
	return many
