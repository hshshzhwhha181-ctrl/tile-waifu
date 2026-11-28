class_name V10Stars
extends RefCounted

# V10Stars — «Созвездие ✦» of outfits and «Лепестки» from duplicates (spec Г7, glossary §2.1).
# UI writes Созвездие with ✦ (lavender); ★ (gold) stays for Path stars only (UX_RULES §4.2).
# A new outfit is ✦1. A duplicate outfit → +✦ up to ✦5; past ✦5: A 10, S 20, SSR 60 petals.
# A duplicate of a non-outfit (tile theme, backdrop): A 25 crystals + 2 petals, S 25 + 6, SSR 20 petals.
# «Добавить звезду» for 60 petals is the guaranteed path. Unlocks are cosmetic only (ranked_safe).
#
#   V10Stars.level(S, id) -> int                       0 if not owned
#   V10Stars.on_new(S, id)                             ✦1 for an outfit (called by V10Gacha2 on a new item)
#   V10Stars.on_dup(S, item) -> {star, up, petals, gems}   applies the duplicate, returns what it turned into
#   V10Stars.can_add(S, id) / add_star(S, id) -> bool  60 petals → +✦ (never past ✦5)
#   V10Stars.unlocks(item, lv) -> Array[{lv, text, ranked_safe}]
#   V10Stars.migrate(S)                                ✦1 for every owned outfit (idempotent)

const MAX: = 5
const STAR_PETALS: = 60
const OVER_PETALS: = {"A": 10, "S": 20, "SSR": 60}
const NONOUT: = {"A": {"gems": 25, "petals": 2}, "S": {"gems": 25, "petals": 6}, "SSR": {"gems": 0, "petals": 20}}
const UNLOCK_TEXT: = {
	2: "+6 реплик героини в этом наряде",
	3: "Живая поза в Салоне",
	4: "SSR: видео-вставка Приёма · A/S: цветной вариант наряда",
	5: "Золотая окантовка и титул «Звезда %s»",
}


static func rar10(it: Dictionary) -> String:
	var r: = String(it.get("rar", "A"))
	return {"R": "A", "SR": "S"}.get(r, r)


static func ostars(S: Dictionary) -> Dictionary:
	if not (S.get("ostars") is Dictionary):
		S["ostars"] = {}
	return S.ostars


static func level(S: Dictionary, id: String) -> int:
	return int(ostars(S).get(id, 0))


static func is_outfit(it: Dictionary) -> bool:
	return String(it.get("cat", "outfit")) == "outfit"


static func on_new(S: Dictionary, id: String) -> void:
	ostars(S)[id] = maxi(1, level(S, id))


static func on_dup(S: Dictionary, it: Dictionary) -> Dictionary:
	var id: = String(it.get("id", ""))
	var r: = rar10(it)
	var out: = {"star": 0, "up": false, "petals": 0, "gems": 0}
	if is_outfit(it):
		var lv: = maxi(1, level(S, id))
		if lv < MAX:
			lv += 1
			ostars(S)[id] = lv
			out.star = lv
			out.up = true
		else:
			ostars(S)[id] = MAX
			out.star = MAX
			out.petals = int(OVER_PETALS.get(r, 10))
	else:
		var g: Dictionary = NONOUT.get(r, NONOUT.A)
		out.gems = int(g.gems)
		out.petals = int(g.petals)
	return out


static func can_add(S: Dictionary, id: String, petals: int) -> bool:
	var lv: = level(S, id)
	return lv >= 1 and lv < MAX and petals >= STAR_PETALS


static func unlocks(it: Dictionary, lv: int = MAX) -> Array:
	var out: = []
	var hero_name: = String(it.get("hero_name", it.get("name", "")))
	for k in range(2, lv + 1):
		var t: String = UNLOCK_TEXT[k]
		if k == 5:
			t = t % hero_name
		out.append({"lv": k, "text": t, "ranked_safe": true})
	return out


static func migrate(S: Dictionary, outfit_ids: Array) -> int:
	var n: = 0
	for id in outfit_ids:
		if S.get("owned", {}).has(id) and level(S, id) == 0:
			ostars(S)[id] = 1
			n += 1
	return n


static func text(lv: int) -> String:
	return "✦%d" % lv
