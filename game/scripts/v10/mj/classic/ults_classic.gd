class_name V10MjClassicUlts
extends RefCounted

# Приёмы героинь в Классике и Памяти (docs/MODES.md §5.5). Адаптер читает ядро V9Ults по героине и переводит его на
# объёмный стол без лотка:
#   mc   «Снять пару»     → 1 пара живого сертификата (самый безопасный ход стола)
#   rin  «Вернуть лоток»  → лотка нет: показывает пару, которую ещё нельзя взять, и фишки, что её держат (3 с)
#   hana «Рывок»          → 2 пары подряд
#   yue  «Лунный свет»    → тайных фишек в Классике нет: светит все свободные пары 3 с; в Памяти — все карты на 1 с
#   nova «Взлом»          → самая глубокая пара (даже накрытая), если стол остаётся решаемым без неё
# Заряд: +1 за пару (пары самого Приёма заряд не дают, V9Ults.gain), пара её фишки-подписи — +25 % кольца.
# Звёзды Приём не снимает: «Чистая игра» — это без подсказок и перемешиваний.

const EFFECT: = {
	"mc": {"kind": "take", "n": 1},
	"rin": {"kind": "path", "t": 3.0},
	"hana": {"kind": "take", "n": 2},
	"yue": {"kind": "pairs", "t": 3.0},
	"nova": {"kind": "deep"},
}
# Память: те же ядра на плоской сетке рубашкой вверх
const MEMORY: = {
	"mc": {"kind": "find", "n": 1},
	"rin": {"kind": "peek_pair", "t": 1.0},
	"hana": {"kind": "find", "n": 2},
	"yue": {"kind": "peek_all", "t": 1.0},
	"nova": {"kind": "find", "n": 1},
}
const DESC: = {
	"mc": "снимает 1 пару",
	"rin": "показывает пару и что её держит",
	"hana": "снимает 2 пары подряд",
	"yue": "светит все свободные пары",
	"nova": "снимает самую глубокую пару",
}


static func hero_key(hero: String) -> String:
	return hero if EFFECT.has(hero) else "mc"


# the name of her Приём: the equipped outfit's (V9Ults.ULTS[outfit].name), else the core's
static func ult_name(hero: String) -> String:
	var h: = hero_key(hero)
	var u: = V9Ults.get_ult(V9Ults.for_hero(h))
	var nm: = String(u.get("name", ""))
	if nm == "":
		nm = String(V9Ults.core(h).get("name", "Приём"))
	return nm


static func desc(hero: String) -> String:
	return String(DESC[hero_key(hero)])


# cast on the Classic table -> {kind, pairs: [[a, b]…] (taken), shown: …}
static func cast(hero: String, board: V10MjClassicBoard) -> Dictionary:
	var e: Dictionary = EFFECT[hero_key(hero)]
	match String(e.kind):
		"take":
			return {"kind": "take", "pairs": board.ult_take(int(e.n))}
		"deep":
			return {"kind": "deep", "pairs": board.ult_deep()}
		"path":
			return {"kind": "path", "pairs": [], "shown": board.show_path(float(e.t))}
		"pairs":
			return {"kind": "pairs", "pairs": [], "shown": board.show_pairs(float(e.t))}
	return {"kind": "none", "pairs": []}


static func memory_effect(hero: String) -> Dictionary:
	return MEMORY[hero_key(hero)]
