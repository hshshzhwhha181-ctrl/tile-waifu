class_name V10Salon
extends RefCounted

# Салон Пяти ветров — logic (docs/0.10-spec.md §Р1–Р2). Static, no autoload. Everything the screen, the hub card,
# the win bar and the selftest need goes through here; nothing else writes S.v10_salon.
#
# Save: S.v10_salon = {spent, zones:{zid:{t:{tid:variant}, jp:{tid:true}, done, done_day, scene_seen, chest}},
#                      lobby_bg, intro, inv:{}, photos:[], last_line:{hero:i}}
#   The star bank is NOT stored: bank() = stars_total() − spent (stars_total = Σ best ★ of every Path level).
#   variant: "lacquer" (comes with the restore) | "jade" (+ceil(cost/2) ★ once; jp remembers it was paid, so
#   switching finishes afterwards is free) | "season" (season pass only, M4 flag).
#
# Zone states: "locked" (previous zone not finished / arc not released) → "ruined" (0 tasks) → "restoring"
#   → "restored" (all tasks, lacquer) → "jade" (every task in jade: the finished «Нефрит» state).
#
# Integration hooks (static Callables; the integrator sets them in M2, defaults work standalone and in tests):
#   grant_cb(rewards: Dictionary, src: String)   chest payout → V10Wallet / boosters. Default: gems → S.gems,
#                                                 the rest into S.v10_salon.inv (for the integrator to route)
#   bond_cb(hero, n, src)                         affinity: V10Bond.gain when that class exists, else queued
#   letter_cb(hero, kind)                         V9Letters.queue("salon_scene") — default no-op
#   day_cb() -> String                            V10Meta.day_key() when it exists, else ""
#   season_cb() -> bool                           season pass owned (M4). Default false
#   level_cb() -> int                             the next Path level number for «Играть · уровень N»

const KEY: = "v10_salon"
const SCENE_BOND: = 20

static var grant_cb: Callable
static var bond_cb: Callable
static var letter_cb: Callable
static var day_cb: Callable
static var season_cb: Callable
static var level_cb: Callable

# tests and the standalone runner point this at their own fixture; null → G.S
static var state_override = null
static var _total_cache: = -1
static var _classes: = {}


# ── state ─────────────────────────────────────────────────────────────────────────────────────────────────────

static func save_root() -> Dictionary:
	if state_override is Dictionary:
		return state_override
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree else null
	if g != null and g.get("S") is Dictionary:
		return g.S
	if state_override == null:
		state_override = {}
	return state_override


static func defaults() -> Dictionary:
	return {"spent": 0, "zones": {}, "lobby_bg": "", "intro": false, "inv": {}, "photos": [], "last_line": {}}


# idempotent: adds missing keys, never overwrites (V10Save.register(KEY, defaults()) does the same in M1)
static func ensure(S: Dictionary = {}) -> Dictionary:
	var root: = S if not S.is_empty() else save_root()
	if not (root.get(KEY) is Dictionary):
		root[KEY] = defaults()
	var s: Dictionary = root[KEY]
	var d: = defaults()
	for k in d:
		if not s.has(k):
			s[k] = d[k]
	for zid in V10SalonData.zone_ids():
		zone_rec(zid, s)
	return s


static func st() -> Dictionary:
	return ensure()


static func zone_rec(zid: String, s: Dictionary = {}) -> Dictionary:
	var ss: = s if not s.is_empty() else st()
	var zs: Dictionary = ss.zones
	if not (zs.get(zid) is Dictionary):
		zs[zid] = {}
	var z: Dictionary = zs[zid]
	for k in {"t": {}, "jp": {}, "done": false, "done_day": "", "scene_seen": false, "chest": false}.keys():
		if not z.has(k):
			z[k] = {} if k in ["t", "jp"] else ("" if k == "done_day" else false)
	return z


# ── stars ─────────────────────────────────────────────────────────────────────────────────────────────────────

static func stars_total() -> int:
	if _total_cache >= 0:
		return _total_cache
	var n: = 0
	var stars = save_root().get("stars", {})
	if stars is Dictionary:
		for k in stars:
			n += clampi(int(stars[k]), 0, 3)
	_total_cache = n
	return n


# call when a Path result improved a level's best (delta = new best − old best; only growth counts)
static func notify_stars(delta: int = 0) -> void:
	_total_cache = -1
	if delta > 0:
		repair()


static func bank() -> int:
	return maxi(0, stars_total() - int(st().spent))


# spent > total can only come from an edited/rolled-back save: clamp and say so once in the log
static func repair() -> bool:
	var s: = st()
	var total: = stars_total()
	if int(s.spent) > total:
		push_warning("V10Salon: spent %d > stars %d — repaired" % [int(s.spent), total])
		s.spent = total
		return true
	return false


# ── zones and tasks ──────────────────────────────────────────────────────────────────────────────────────────

static func zone_open(zid: String) -> bool:
	var ids: = V10SalonData.zone_ids()
	var i: = ids.find(zid)
	if i < 0:
		return false
	if i == 0:
		return true
	return bool(zone_rec(ids[i - 1]).done)


static func task_variant(zid: String, tid: String) -> String:
	return str(zone_rec(zid).t.get(tid, ""))


static func restored(zid: String, tid: String) -> bool:
	return task_variant(zid, tid) != ""


static func progress(zid: String) -> Vector2i:
	var z: = V10SalonData.zone(zid)
	var n: = 0
	for t in z.get("tasks", []):
		if restored(zid, t.id):
			n += 1
	return Vector2i(n, z.get("tasks", []).size())


static func zone_state(zid: String) -> String:
	if not zone_open(zid):
		return "locked"
	var p: = progress(zid)
	if p.x == 0:
		return "ruined"
	if p.x < p.y:
		return "restoring"
	for t in V10SalonData.zone(zid).tasks:
		if task_variant(zid, t.id) != "jade":
			return "restored"
	return "jade"


static func can_restore(zid: String, tid: String) -> bool:
	var t: = V10SalonData.task(zid, tid)
	return not t.is_empty() and zone_open(zid) and not restored(zid, tid) and bank() >= int(t.cost)


# → {ok, reason: ""|"locked"|"done"|"stars"|"unknown", need, zone_done}
static func restore(zid: String, tid: String) -> Dictionary:
	var t: = V10SalonData.task(zid, tid)
	if t.is_empty():
		return {"ok": false, "reason": "unknown"}
	if not zone_open(zid):
		return {"ok": false, "reason": "locked"}
	if restored(zid, tid):
		return {"ok": false, "reason": "done"}
	var b: = bank()
	if b < int(t.cost):
		return {"ok": false, "reason": "stars", "need": int(t.cost) - b}
	var s: = st()
	s.spent = int(s.spent) + int(t.cost)
	var z: = zone_rec(zid)
	z.t[tid] = "lacquer"
	var done: = progress(zid).x == progress(zid).y
	if done and not z.done:
		z.done = true
		z.done_day = _day()
	_save()
	return {"ok": true, "reason": "", "zone_done": done}


# → {ok, reason: ""|"not_restored"|"stars"|"season"|"unknown", paid}
static func set_finish(zid: String, tid: String, variant: String) -> Dictionary:
	var t: = V10SalonData.task(zid, tid)
	if t.is_empty() or not variant in V10SalonData.FINISHES:
		return {"ok": false, "reason": "unknown"}
	if not restored(zid, tid):
		return {"ok": false, "reason": "not_restored"}
	var z: = zone_rec(zid)
	var paid: = 0
	if variant == "season" and not season_open():
		return {"ok": false, "reason": "season"}
	if variant == "jade" and not z.jp.get(tid, false):
		var c: = V10SalonData.jade_cost(int(t.cost))
		if bank() < c:
			return {"ok": false, "reason": "stars", "need": c - bank()}
		st().spent = int(st().spent) + c
		z.jp[tid] = true
		paid = c
	z.t[tid] = variant
	_save()
	return {"ok": true, "reason": "", "paid": paid}


static func jade_paid(zid: String, tid: String) -> bool:
	return bool(zone_rec(zid).jp.get(tid, false))


static func season_open() -> bool:
	return season_cb.is_valid() and bool(season_cb.call())


# the zone the player works on now: the first open zone that is not finished (or the last one)
static func current_zone() -> String:
	var ids: = V10SalonData.zone_ids()
	for zid in ids:
		if zone_open(zid) and not bool(zone_rec(zid).done):
			return zid
	return ids[ids.size() - 1]


static func all_released_done() -> bool:
	for zid in V10SalonData.zone_ids():
		if not bool(zone_rec(zid).done):
			return false
	return true


# the next thing to save stars for: cheapest unrestored task of the current zone → {zid, tid, name, cost, need}
static func next_goal() -> Dictionary:
	var zid: = current_zone()
	if bool(zone_rec(zid).done):
		return {}
	for t in V10SalonData.tasks_by_cost(zid):
		if not restored(zid, t.id):
			return {"zid": zid, "tid": t.id, "name": t.name, "cost": int(t.cost), "need": maxi(0, int(t.cost) - bank())}
	return {}


# anything restorable right now (gold dot on the hub card, «В салон» on the win screen)
static func can_restore_any() -> bool:
	var g: = next_goal()
	return not g.is_empty() and int(g.need) == 0


# hub card / Afisha line: {zid, name, n, total, frac, dot, label}
static func hub_info() -> Dictionary:
	var zid: = current_zone()
	var p: = progress(zid)
	var z: = V10SalonData.zone(zid)
	var label: = "%s · %d/%d" % [zid, p.x, p.y]
	if all_released_done():
		label = "Салон восстановлен"
	return {"zid": zid, "name": z.name, "n": p.x, "total": p.y, "frac": float(p.x) / maxf(1.0, p.y),
		"dot": can_restore_any(), "label": label, "bank": bank()}


# ── chest, scene, lobby ──────────────────────────────────────────────────────────────────────────────────────

static func chest_ready(zid: String) -> bool:
	var z: = zone_rec(zid)
	return bool(z.done) and not bool(z.chest)


# once per zone; → the rewards dict ({} when already claimed or the zone is not done)
static func claim_chest(zid: String) -> Dictionary:
	if not chest_ready(zid):
		return {}
	var r: Dictionary = V10SalonData.CHESTS.get(V10SalonData.zone(zid).chest, {}).duplicate()
	zone_rec(zid).chest = true
	if grant_cb.is_valid():
		grant_cb.call(r, "salon_" + zid)
	else:
		var root: = save_root()
		var inv: Dictionary = st().inv
		for k in r:
			if k == "gems":
				root["gems"] = int(root.get("gems", 0)) + int(r[k])
			else:
				inv[k] = int(inv.get(k, 0)) + int(r[k])
	_save()
	return r


# first view of a zone scene: +20 affinity (hard source, §2.4) and a letter next morning; → true the first time
static func mark_scene_seen(zid: String) -> bool:
	var z: = zone_rec(zid)
	if not bool(z.done) or bool(z.scene_seen):
		return false
	z.scene_seen = true
	var hero: String = V10SalonData.zone(zid).hero
	_bond(hero, SCENE_BOND, "salon_scene")
	if letter_cb.is_valid():
		letter_cb.call(hero, "salon_scene")
	_save()
	return true


static func set_lobby(zid: String) -> bool:
	if not bool(zone_rec(zid).done):
		return false
	st().lobby_bg = zid
	_save()
	return true


# texture path for the home screen's background slot ("" = the default lobby)
static func lobby_texture() -> String:
	var zid: String = str(st().lobby_bg)
	if zid == "" or not bool(zone_rec(zid).done):
		return ""
	return V10SalonData.ART + str(V10SalonData.zone(zid).lobby)


# ── heroine lines ────────────────────────────────────────────────────────────────────────────────────────────

static func aff_tier(hero: String) -> int:
	var aff: Dictionary = save_root().get("aff", {})
	var lv: = 1 + int(aff.get(hero, 0)) / 100
	if lv >= 9:
		return 3
	if lv >= 6:
		return 2
	if lv >= 3:
		return 1
	return 0


# a line for her current affinity tier, never the same as the previous one
static func next_line(hero: String, rng: RandomNumberGenerator = null) -> String:
	var tiers: Array = V10SalonData.LINES.get(hero, [])
	if tiers.is_empty():
		return ""
	var pool: Array = tiers[mini(aff_tier(hero), tiers.size() - 1)]
	var last: Dictionary = st().last_line
	var prev: = str(last.get(hero, ""))
	var cand: = []
	for l in pool:
		if l != prev:
			cand.append(l)
	var r: = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var line: String = cand[r.randi() % cand.size()]
	last[hero] = line
	return line


# ── intro (first visit, spec §Р1 п.1 and migration) ──────────────────────────────────────────────────────────

static func intro_text() -> String:
	return V10SalonData.INTRO_OLD % bank() if bank() > 6 else V10SalonData.INTRO_NEW


static func intro_needed() -> bool:
	return not bool(st().intro)


static func intro_done() -> void:
	st().intro = true
	_save()


# ── helpers ──────────────────────────────────────────────────────────────────────────────────────────────────

static func global_class(cls: String) -> Script:
	if _classes.has(cls):
		return _classes[cls]
	var sc: Script = null
	for c in ProjectSettings.get_global_class_list():
		if str(c["class"]) == cls:
			sc = load(str(c.path))
			break
	_classes[cls] = sc
	return sc


static func _day() -> String:
	if day_cb.is_valid():
		return str(day_cb.call())
	var meta: = global_class("V10Meta")
	if meta != null and meta.has_method("day_key"):
		return str(meta.call("day_key"))
	return ""


static func _bond(hero: String, n: int, src: String) -> void:
	if bond_cb.is_valid():
		bond_cb.call(hero, n, src)
		return
	var bond: = global_class("V10Bond")
	if bond != null and bond.has_method("gain"):
		bond.call("gain", hero, n, src)
		return
	var s: = st()
	if not (s.get("bond_pending") is Array):
		s["bond_pending"] = []
	s.bond_pending.append([hero, n, src])


static func next_level() -> int:
	if level_cb.is_valid():
		return int(level_cb.call())
	return maxi(1, int(save_root().get("unlocked", 1)))


static func _save() -> void:
	if state_override is Dictionary:
		return
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree else null
	if g != null and g.has_method("save"):
		g.save()


static func reset_cache() -> void:
	_total_cache = -1
