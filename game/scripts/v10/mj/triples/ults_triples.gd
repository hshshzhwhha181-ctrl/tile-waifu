class_name V10MjTriplesUlts
extends RefCounted

# Приёмы героинь в Тройках (docs/MODES.md §5.5): адаптер читает ядро V9Ults по героине и переводит его на лоток 7.
#   mc   «Снять пару»     → 1 тройка (сначала та, что разгрузит лоток)
#   rin  «Вернуть лоток»  → 3 фишки из лотка на стол (если лоток пуст — 1 тройка)
#   hana «Рывок»          → 2 тройки
#   yue  «Лунный свет»    → открывает тайные фишки и снимает тройку
#   nova «Взлом»          → самая глубокая тройка
# Модификатор наряда (V9Ults.MODS: П/О/Л/В/Ц/С) добавляет малый эффект поверх ядра (mod_effect).
# Заряд: +1 за тройку (тройки самого Приёма заряд не дают), нужно need(aff) троек.

const EFFECT: = {
	"mc": {"triples": 1, "prefer": "tray"},
	"rin": {"return": 3, "empty_triples": 1},
	"hana": {"triples": 2, "prefer": "tray"},
	"yue": {"triples": 1, "reveal_all": true, "prefer": "tray"},
	"nova": {"triples": 1, "prefer": "deep"},
}
const DESC: = {
	"mc": "снимает 1 тройку",
	"rin": "возвращает 3 фишки из лотка на стол",
	"hana": "снимает 2 тройки подряд",
	"yue": "открывает тайные фишки и снимает тройку",
	"nova": "снимает самую глубокую тройку",
}


static func core(hero: String) -> Dictionary:
	var c: Dictionary = V9Ults.core(hero if EFFECT.has(hero) else "mc", false)
	var e: Dictionary = EFFECT.get(hero, EFFECT.mc).duplicate()
	e["name"] = String(c.get("name", "Приём"))
	e["desc"] = DESC.get(hero, DESC.mc)
	e["hero"] = hero if EFFECT.has(hero) else "mc"
	return e


# имя Приёма по наряду (V9Ults.ULTS[outfit].name), иначе имя ядра
static func ult_name(hero: String) -> String:
	var id: = V9Ults.for_hero(hero)
	var u: = V9Ults.get_ult(id)
	return String(u.get("name", core(hero).name))


static func need(aff_level: int) -> int:
	return maxi(4, V9Ults.need(aff_level, false) - 2)


static func start_charge(hero: String) -> int:
	return V9Ults.start_charge_for(V9Ults.for_hero(hero), false)


# план Приёма на текущем столе (ничего не меняет): {return: n, triples: [[ids]], reveal_all, mod, mod_ids}
static func plan(hero: String, r: V10MjTriplesRules) -> Dictionary:
	var e: = core(hero)
	var out: = {"hero": e.hero, "name": e.name, "return": 0, "triples": [], "reveal_all": bool(e.get("reveal_all", false)),
		"mod": V9Ults.mod(V9Ults.for_hero(hero), false), "mod_ids": []}
	var sim: = r.clone()
	if int(e.get("return", 0)) > 0:
		if sim.tray.size() > 0:
			out["return"] = mini(int(e["return"]), sim.tray.size())
			return out
		e["triples"] = int(e.get("empty_triples", 1))
	for k in int(e.get("triples", 0)):
		var tri: = sim.ult_triple(String(e.get("prefer", "tray")) == "deep")
		if tri.size() < 3:
			break
		(out.triples as Array).append(tri)
		sim.remove(tri)
	# модификатор наряда: малый бонус поверх ядра
	match String(out.mod):
		"П", "Ц":
			var t2: = sim.ult_triple(false)
			out.mod_ids = t2
		"В":
			pass
		"С":
			if sim.tray.size() > 0:
				var f: = sim.face[sim.history[0]] if sim.history.size() > 0 else -1
				for i in sim.frees:
					if sim.face[i] == f:
						out.mod_ids = [i]
						break
	return out


# применить план к правилам (доска повторяет то же визуально). Возвращает индексы, ушедшие со стола/из лотка.
static func apply(p: Dictionary, r: V10MjTriplesRules) -> Dictionary:
	var gone: Array = []
	var back: Array[int] = []
	if int(p.get("return", 0)) > 0:
		back = r.return_last(int(p["return"]))
	for tri in p.get("triples", []):
		r.remove(tri)
		r.triples += 1
		gone.append_array(tri)
	if String(p.get("mod", "")) == "В" and r.tray.size() > 0:
		back.append_array(r.return_last(1))
	return {"gone": gone, "back": back}
