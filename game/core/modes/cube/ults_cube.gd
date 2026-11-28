class_name V10MjCubeUlts
extends RefCounted

# Приёмы героинь в Кубе (docs/MODES.md §5.5, колонка «Куб»): адаптер к ядрам V9Ults.
#   mc   «Снять пару»     → 1 пара (та, после которой фигура остаётся проходимой)
#   rin  «Вернуть лоток»  → показать пару и повернуть к ней камеру (без траты подсказки)
#   hana «Рывок»          → 2 пары подряд
#   yue  «Лунный свет»    → подсвечивает все свободные пары, и фигура делает оборот — видно скрытые грани
#   nova «Взлом»          → пара из сердцевины (ближайшая к реликвии)
# Заряд: +1 за пару, +1 за её фишку-подпись; нужно need(aff) пар. Пары Приёма заряд не дают.

const EFFECT: = {
	"mc": {"pairs": 1},
	"rin": {"show": true},
	"hana": {"pairs": 2},
	"yue": {"glow_all": true},
	"nova": {"pairs": 1, "deep": true},
}
const DESC: = {
	"mc": "снимает 1 пару",
	"rin": "показывает пару и поворачивает к ней куб",
	"hana": "снимает 2 пары подряд",
	"yue": "подсвечивает все свободные пары и поворачивает куб",
	"nova": "снимает пару из сердцевины",
}


static func core(hero: String) -> Dictionary:
	var h: = hero if EFFECT.has(hero) else "mc"
	var c: Dictionary = V9Ults.core(h, false)
	var e: Dictionary = EFFECT[h].duplicate()
	e.name = String(c.get("name", "Приём"))
	e.desc = DESC[h]
	e.hero = h
	return e


static func ult_name(hero: String) -> String:
	var u: = V9Ults.get_ult(V9Ults.for_hero(hero))
	return String(u.get("name", core(hero).name))


static func need(aff_level: int) -> int:
	return maxi(4, V9Ults.need(aff_level, false) - 2)


static func start_charge(hero: String) -> int:
	return V9Ults.start_charge_for(V9Ults.for_hero(hero), false)


# the plan on the current figure (changes nothing): {hero, name, pairs: [[a, b]…], show: [a, b], glow: [tiles]}
static func plan(hero: String, r: V10MjCubeRules, center: Vector3) -> Dictionary:
	var e: = core(hero)
	var out: = {"hero": e.hero, "name": e.name, "pairs": [], "show": [], "glow": []}
	var sim: = r.clone()
	if e.has("pairs"):
		for k in int(e.pairs):
			var p: Array = sim.deepest_pair(center) if e.get("deep", false) else sim.hint_pair()
			if p.is_empty():
				break
			(out.pairs as Array).append(p)
			sim.take(p[0], p[1], false)
	if e.get("show", false):
		out.show = r.hint_pair()
	if e.get("glow_all", false):
		var seen: = {}
		for p in r.free_pairs(true):
			seen[p[0]] = true
			seen[p[1]] = true
		out.glow = seen.keys()
	return out


static func empty(p: Dictionary) -> bool:
	return (p.pairs as Array).is_empty() and (p.show as Array).is_empty() and (p.glow as Array).is_empty()
