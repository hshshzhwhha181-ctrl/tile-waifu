class_name V10AffCurve
extends RefCounted

# V10AffCurve — heavy exponential affection progression (Levels 1–20), 16+ BD2-style milestones,
# and purchasable / boss-dropped Affection Gifts. Routes all XP grants through V10Bond.gain(..., "gift")
# and wallet spends through V10Money.

const SAVE_KEY: = "v10_gifts"
const MAX_LEVEL: = 20

const CURVE: = [
	120, 260, 480, 800, 1300,
	2000, 3000, 4400, 6200, 8500,
	11400, 15000, 19400, 24800, 31400,
	39400, 49000, 60500, 74000, 90000,
]

const MILESTONES: = {
	2: {
		"level": 2,
		"title": "После закрытия чайной",
		"desc": "16+ Сцена «После закрытия чайной» + бонус атаки в Приключении",
		"tag_16": true,
		"scene": "after_hours",
		"atk_bonus": 0.08,
	},
	4: {
		"level": 4,
		"title": "Шёпот за ширмой",
		"desc": "Особые интерактивные реплики в Чайной + ускорение ульты",
		"tag_16": false,
		"voice_lines": true,
		"ult_haste": 0.10,
	},
	6: {
		"level": 6,
		"title": "Полуночный шёлк",
		"desc": "16+ Сцена «Полуночный шёлк» + усиление критов",
		"tag_16": true,
		"scene": "midnight_silk",
		"crit_bonus": 0.12,
	},
	8: {
		"level": 8,
		"title": "Приватный ракурс",
		"desc": "Особая поза и кадрирование лобби + золотая рамка",
		"tag_16": false,
		"lobby_pose": true,
		"frame": true,
	},
	10: {
		"level": 10,
		"title": "Клятва хозяйки",
		"desc": "«Клятва хозяйки» (16+ будуарный CG-арт + максимальный бонус)",
		"tag_16": true,
		"scene": "mistress_vow",
		"cg_16": true,
		"atk_bonus": 0.20,
	},
}

const GIFTS: = [
	{
		"id": "gift_tea_set",
		"name": "Чайный набор",
		"aff": 40,
		"cur": "coins",
		"price": 800,
		"rar": "A",
		"art": "item_tea",
		"desc": "Тёплый улун и фарфор",
	},
	{
		"id": "gift_silk_fan",
		"name": "Шёлковый веер",
		"aff": 120,
		"cur": "gems",
		"price": 90,
		"rar": "S",
		"art": "item_petal",
		"desc": "Шёлк ручной росписи",
	},
	{
		"id": "gift_jade_pin",
		"name": "Нефритовая заколка",
		"aff": 300,
		"cur": "gems",
		"price": 200,
		"rar": "SSR",
		"art": "item_gift",
		"desc": "Нефрит для хозяйки",
	},
]

static var _bound_root: Variant = null


static func bind_root(s_root: Dictionary) -> void:
	_bound_root = s_root
	ensure(s_root)


static func unbind_root() -> void:
	_bound_root = null


static func _root() -> Dictionary:
	if _bound_root is Dictionary:
		return _bound_root as Dictionary
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree else null
	if g != null and g.get("S") is Dictionary:
		return g.S
	return {}


static func defaults() -> Dictionary:
	return {
		"gift_tea_set": 0,
		"gift_silk_fan": 0,
		"gift_jade_pin": 0,
	}


static func ensure(s_root: Variant = null) -> Dictionary:
	var r: Dictionary = s_root if s_root is Dictionary else _root()
	if not (r.get(SAVE_KEY) is Dictionary):
		r[SAVE_KEY] = defaults()
	var inv: Dictionary = r[SAVE_KEY]
	var df: = defaults()
	for k in df:
		inv[k] = maxi(0, int(inv.get(k, df[k])))
	return inv


static func need_for_level(lv: int) -> int:
	var idx: = clampi(lv - 1, 0, CURVE.size() - 1)
	return int(CURVE[idx])


static func total_xp_for_level(lv: int) -> int:
	var target: = clampi(lv, 1, MAX_LEVEL)
	var sum: = 0
	for k in range(1, target):
		sum += need_for_level(k)
	return sum


static func level_for_xp(xp: int) -> int:
	var left: = maxi(0, xp)
	for lv in range(1, MAX_LEVEL):
		var need: = need_for_level(lv)
		if left < need:
			return lv
		left -= need
	return MAX_LEVEL


static func progress(xp: int) -> Dictionary:
	var clean_xp: = maxi(0, xp)
	var left: = clean_xp
	for lv in range(1, MAX_LEVEL):
		var need: = need_for_level(lv)
		if left < need:
			return {
				"level": lv,
				"into": left,
				"need": need,
				"ratio": clampf(float(left) / float(maxi(1, need)), 0.0, 1.0),
				"total_xp": clean_xp,
				"is_max": false,
				"next_milestone": next_milestone(lv),
			}
		left -= need
	var cap_need: = need_for_level(MAX_LEVEL)
	return {
		"level": MAX_LEVEL,
		"into": cap_need,
		"need": cap_need,
		"ratio": 1.0,
		"total_xp": clean_xp,
		"is_max": true,
		"next_milestone": {},
	}


static func hero_xp(hero: String) -> int:
	var r: = _root()
	var aff: Dictionary = r.get("aff", {}) if r.get("aff") is Dictionary else {}
	return maxi(0, int(aff.get(hero, 0)))


static func hero_level(hero: String) -> int:
	return level_for_xp(hero_xp(hero))


static func hero_progress(hero: String) -> Dictionary:
	return progress(hero_xp(hero))


static func milestone_at(lv: int) -> Dictionary:
	return MILESTONES.get(lv, {}).duplicate(true) if MILESTONES.has(lv) else {}


static func unlocked_milestones(lv: int) -> Array:
	var out: = []
	var keys: = MILESTONES.keys()
	keys.sort()
	for k in keys:
		if int(k) <= lv:
			out.append((MILESTONES[k] as Dictionary).duplicate(true))
	return out


static func next_milestone(lv: int) -> Dictionary:
	var keys: = MILESTONES.keys()
	keys.sort()
	for k in keys:
		if int(k) > lv:
			return (MILESTONES[k] as Dictionary).duplicate(true)
	return {}


static func bonuses_for_level(lv: int) -> Dictionary:
	var atk: = 0.0
	var crit: = 0.0
	var haste: = 0.0
	for m in unlocked_milestones(lv):
		atk += float(m.get("atk_bonus", 0.0))
		crit += float(m.get("crit_bonus", 0.0))
		haste += float(m.get("ult_haste", 0.0))
	return {"atk_bonus": atk, "crit_bonus": crit, "ult_haste": haste}


static func gift_def(gift_id: String) -> Dictionary:
	for g in GIFTS:
		if String(g.id) == gift_id:
			return g
	return {}


static func gift_count(gift_id: String) -> int:
	var inv: = ensure()
	return maxi(0, int(inv.get(gift_id, 0)))


static func grant_gift(gift_id: String, count: int = 1) -> int:
	if count <= 0 or gift_def(gift_id).is_empty():
		return gift_count(gift_id)
	var inv: = ensure()
	inv[gift_id] = int(inv.get(gift_id, 0)) + count
	return int(inv[gift_id])


static func _apply_gift_xp(hero: String, aff: int) -> int:
	if hero == "" or aff <= 0:
		return 0
	if _bound_root is Dictionary:
		var r: = _bound_root as Dictionary
		if not (r.get("aff") is Dictionary):
			r["aff"] = {}
		r.aff[hero] = int(r.aff.get(hero, 0)) + aff
		return aff
	return V10Bond.gain(hero, aff, "gift")


static func use_gift(gift_id: String, hero: String) -> Dictionary:
	var gd: = gift_def(gift_id)
	if gd.is_empty() or hero == "":
		return {"ok": false, "reason": "unknown"}
	var inv: = ensure()
	if int(inv.get(gift_id, 0)) <= 0:
		return {"ok": false, "reason": "empty"}
	var old_lv: = hero_level(hero)
	inv[gift_id] = int(inv[gift_id]) - 1
	var gained: = _apply_gift_xp(hero, int(gd.aff))
	var new_lv: = hero_level(hero)
	var unlocked: = {}
	for k in range(old_lv + 1, new_lv + 1):
		if MILESTONES.has(k):
			unlocked = MILESTONES[k].duplicate(true)
	return {
		"ok": true,
		"source": "inventory",
		"aff": gained,
		"old_level": old_lv,
		"new_level": new_lv,
		"milestone": unlocked,
	}


static func buy_and_give_gift(gift_id: String, hero: String) -> Dictionary:
	var gd: = gift_def(gift_id)
	if gd.is_empty() or hero == "":
		return {"ok": false, "reason": "unknown"}
	if gift_count(gift_id) > 0:
		return use_gift(gift_id, hero)
	var cur: = String(gd.cur)
	var price: = int(gd.price)
	if _bound_root is Dictionary:
		var r: = _bound_root as Dictionary
		var have: = int(r.get(cur, 0))
		if have < price:
			return {"ok": false, "reason": "short", "cur": cur, "short": price - have}
		r[cur] = have - price
	else:
		if cur == "coins":
			if not V10Money.spend({"coins": price}, "aff_gift:" + gift_id):
				return {"ok": false, "reason": "short", "cur": cur, "short": maxi(1, price - V10Money.bal("coins"))}
		else:
			if V10Money.can({"gems": price}):
				V10Money.spend({"gems": price}, "aff_gift:" + gift_id)
			else:
				var e: = V10Money.econ()
				var total_prem: = e.wallet.premium() if e != null else V10Money.bal("gems")
				if e == null or total_prem < price:
					return {"ok": false, "reason": "short", "cur": "gems", "short": maxi(1, price - total_prem)}
				e.wallet.spend_premium(price, "aff_gift:" + gift_id)
				V10Money.sync(_root())
	var old_lv: = hero_level(hero)
	var gained: = _apply_gift_xp(hero, int(gd.aff))
	var new_lv: = hero_level(hero)
	var unlocked: = {}
	for k in range(old_lv + 1, new_lv + 1):
		if MILESTONES.has(k):
			unlocked = MILESTONES[k].duplicate(true)
	return {
		"ok": true,
		"source": "shop",
		"aff": gained,
		"old_level": old_lv,
		"new_level": new_lv,
		"milestone": unlocked,
	}


static func award_boss_gift(tier: int = 1) -> String:
	var pick: = "gift_tea_set"
	if tier >= 3:
		pick = "gift_jade_pin"
	elif tier == 2:
		pick = "gift_silk_fan"
	grant_gift(pick, 1)
	return pick
