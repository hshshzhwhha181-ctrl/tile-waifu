class_name V10MjBridgeTiles
extends RefCounted

# Фишки риичи для моста (docs/MODES.md §4.5): виды 0…33 как в движке V8Mj (kind = tile >> 2):
#   0–8 ман · 9–17 пин · 18–26 со · 27–30 ветры (Восток, Юг, Запад, Север) · 31–33 драконы (белый, зелёный, красный).
# Картинки — assets/v08/table/t00–t33 (V8Mj.face(kind*4) == kind для всех видов: красные пятёрки мост не использует).
# Здесь только данные и счёт; движок V8Mj вызывается, но не меняется.

const DIR: = "res://assets/v08/table/"
const KINDS: = 34
const SUIT_SQ: = ["🟥", "🟦", "🟩", "⬜"]          # шаринг: квадраты мастей (ман, пин, со, знаки)
const SUIT_COL: = [Color("d9686f"), Color("6f9fd9"), Color("5b9580"), Color("ddd2c4")]

# имя в родительном падеже («Без 9 ман», «Без Севера») и в винительном («сбросить Север»)
const HONOR_GEN: = ["Востока", "Юга", "Запада", "Севера", "белого дракона", "зелёного дракона", "красного дракона"]
const HONOR_ACC: = ["Восток", "Юг", "Запад", "Север", "белого дракона", "зелёного дракона", "красного дракона"]

static var _tex: = {}


static func tex(k: int) -> Texture2D:
	var key: = "t%02d" % k if k >= 0 else "back"
	if _tex.has(key):
		return _tex[key]
	var p: = DIR + key + ".png"
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_tex[key] = t
	return t


static func suit(k: int) -> int:
	return mini(k / 9, 3)


static func num(k: int) -> int:
	return k % 9 + 1


static func is_honor(k: int) -> bool:
	return k >= 27


static func is_simple(k: int) -> bool:
	return k < 27 and k % 9 != 0 and k % 9 != 8


static func is_term(k: int) -> bool:
	return k < 27 and (k % 9 == 0 or k % 9 == 8)


static func name_ru(k: int) -> String:
	return V8Mj.name_ru(k)


static func name_gen(k: int) -> String:
	if k >= 27:
		return HONOR_GEN[k - 27]
	return V8Mj.name_ru(k)


static func name_acc(k: int) -> String:
	if k >= 27:
		return HONOR_ACC[k - 27]
	return V8Mj.name_ru(k)


static func zero() -> Array:
	var c: = []
	c.resize(KINDS)
	c.fill(0)
	return c


static func counts(kinds: Array) -> Array:
	var c: = zero()
	for k in kinds:
		c[int(k)] += 1
	return c


static func total(c: Array) -> int:
	var n: = 0
	for v in c:
		n += int(v)
	return n


static func to_kinds(c: Array) -> Array:
	var out: = []
	for k in KINDS:
		for i in int(c[k]):
			out.append(k)
	return out


static func sorted(kinds: Array) -> Array:
	var a: = kinds.duplicate()
	a.sort()
	return a


# виды → номера фишек 0…135 для V8Mj.evaluate (без красных пятёрок: копии 1–3 у пятёрок)
static func to_ids(kinds: Array) -> Array:
	var used: = {}
	var out: = []
	for k in kinds:
		var n: int = int(used.get(k, 0))
		used[k] = n + 1
		var id: int = int(k) * 4 + n
		if V8Mj.is_aka(id):
			id = int(k) * 4 + 3 - (n % 3)
		out.append(id)
	return out


# регулярный шантен (4 набора и пара; без семи пар и сирот) — как в правилах моста
static func shanten_reg(c: Array, melds: = 0) -> int:
	return V8Mj.shanten_regular(c, melds)


static func is_complete(kinds: Array) -> bool:
	return kinds.size() == 14 and V8Mj.shanten_regular(counts(kinds), 0) == -1


# квадраты мастей руки (шаринг без названий фишек)
static func squares(kinds: Array) -> String:
	var s: = ""
	for k in sorted(kinds):
		s += SUIT_SQ[suit(int(k))]
	return s
