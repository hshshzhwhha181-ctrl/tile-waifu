class_name V10Bday
extends RefCounted

# V10Bday — heroine birthdays (docs/0.10-spec.md Р6).
#   * Morning letter from the birthday heroine (letter() payload, hook H5), a dot on her salon card.
#   * If she is the partner: the lobby cake scene (V10BdayCake), tap blows the candles.
#   * Goal «Праздник Рин: 0/24 пары её фишкой», valid on ANY of the 7 days around the date (−3…+3).
#     In unranked deals a VISUAL swap draws her signature emblem over 2 face kinds; face ids never change
#     (determinism, bot measurements and challenge codes stay intact). No swap in ranked.
#   * Reward once a year: frame «Праздник <Имя> · YYYY», 100 кр, +30 симпатии, 1 чайный лист.
#
#   V10Bday.today_hero(key) -> h|""         V10Bday.window_hero(key) -> {h, year, delta}|{}
#   V10Bday.sig_overlay(cfg) -> {h, faces:[a, b], icon}|{}      cfg {ranked, faces:[face ids in the deal], seed}
#   V10Bday.on_pair(face, overlay, key) -> {n, goal, done}       count a pair of an overlaid face
#   V10Bday.goal_view(key) -> {h, name, n, goal, claimable, claimed, icon}|{}
#   V10Bday.claim(key) -> rows                                    once per heroine per year
#   V10Bday.letter(h) -> {h, ev:"bday", subj, body}               V10Bday.LETTER_PRIORITY: bday before comeback
#   V10Bday.notify_at(key) -> unix (10:30 of her day; V10Notify.request("bday", …))
# heroes are limited to V10RitBridge.heroes() (= G.HEROES): unknown heroines never celebrate.

const LETTER_PRIORITY: = ["bday", "comeback", "rank", "combo", "first_win"]
const NOTIFY_H: = 10
const NOTIFY_M: = 30

static var heroes_override: = []   # selftests


static func st() -> Dictionary:
	return V10RitSave.st("v10_bday")


static func _heroes() -> Array:
	return heroes_override if not heroes_override.is_empty() else V10RitBridge.heroes()


static func _key(key: String) -> String:
	return key if key != "" else V10RitClock.day_key()


static func today_hero(key: = "") -> String:
	key = _key(key)
	var md: = key.substr(5, 5)
	for h in _heroes():
		if V10BdayData.date_of(h) == md:
			return h
	return ""


static func window_hero(key: = "") -> Dictionary:
	key = _key(key)
	var y: = V10RitClock.year(key)
	var ki: = V10RitClock.day_index(key)
	for h in _heroes():
		var md: = V10BdayData.date_of(h)
		if md == "":
			continue
		for yy in [y - 1, y, y + 1]:
			var bi: = V10RitClock.day_index("%04d-%s" % [yy, md])
			var delta: = ki - bi
			if absi(delta) <= V10BdayData.WINDOW:
				return {"h": h, "year": yy, "delta": delta, "date": "%04d-%s" % [yy, md]}
	return {}


static func sig_icon(h: String) -> String:
	return str(V10BdayData.SIG.get(h, ""))


# visual swap: never touches cfg (the deal hash stays the same), never in ranked
static func sig_overlay(cfg: Dictionary, key: = "") -> Dictionary:
	if bool(cfg.get("ranked", false)):
		return {}
	var w: = window_hero(_key(key))
	if w.is_empty() or sig_icon(w.h) == "":
		return {}
	var uniq: = {}
	for f in cfg.get("faces", []):
		uniq[int(f)] = true
	var faces: = uniq.keys()
	faces.sort()
	if faces.size() < 2:
		return {}
	var seed: = int(cfg.get("seed", 0))
	# kind A wears her emblem, kind B her birthday cake. A face that already shows the emblem's motif (or a cake) is
	# the one that gets swapped, so no two kinds on the board look alike; otherwise the seed picks (deterministic)
	var motif: = V10RitBridge.face_of(str(V10BdayData.SIG_MOTIF.get(w.h, "")))
	var cake: = V10RitBridge.face_of(V10BdayData.CAKE_MOTIF)
	var pool: = faces.filter(func(f): return f != cake)
	if pool.is_empty():
		pool = faces
	var a: int = motif if motif in faces else pool[posmod(seed, pool.size())]
	var rest: = faces.filter(func(f): return f != a)
	var b: int = cake if cake in rest else rest[posmod(seed * 7 + 3, rest.size())]
	return {"h": w.h, "faces": [a, b], "icon": sig_icon(w.h), "icons": [sig_icon(w.h), cake_icon(w.h)]}


static func cake_icon(h: String) -> String:
	return "res://assets/v10/rituals/%s.webp" % str(V10BdayData.CAKE.get(h, "cake_tier"))


static func _prog(key: String) -> Dictionary:
	var s: = st()
	var w: = window_hero(key)
	if w.is_empty():
		return {}
	var pk: = "%s:%d" % [w.h, int(w.year)]
	if str(s.prog.key) != pk:
		s.prog = {"key": pk, "h": w.h, "n": 0}
	return s.prog


static func on_pair(face: int, overlay: Dictionary, key: = "") -> Dictionary:
	key = _key(key)
	if overlay.is_empty() or not (face in overlay.get("faces", [])):
		return {}
	var p: = _prog(key)
	if p.is_empty() or str(p.h) != str(overlay.h):
		return {}
	p.n = mini(V10BdayData.GOAL_PAIRS, int(p.n) + 1)
	return {"n": int(p.n), "goal": V10BdayData.GOAL_PAIRS, "done": int(p.n) >= V10BdayData.GOAL_PAIRS}


static func goal_view(key: = "") -> Dictionary:
	key = _key(key)
	var w: = window_hero(key)
	if w.is_empty():
		return {}
	var p: = _prog(key)
	var claimed: bool = int(st().year_done.get(str(w.h), 0)) == int(w.year)
	return {"h": w.h, "name": V10RitBridge.hero_name(w.h), "short": V10RitBridge.short_name(w.h), "n": int(p.n),
		"goal": V10BdayData.GOAL_PAIRS, "claimable": int(p.n) >= V10BdayData.GOAL_PAIRS and not claimed,
		"claimed": claimed, "icon": sig_icon(w.h), "today": int(w.delta) == 0, "year": int(w.year),
		"gen": V10RitBridge.gen_name(w.h),
		"text": "Праздник %s: %d/%d пары её фишкой" % [V10RitBridge.gen_name(w.h), int(p.n), V10BdayData.GOAL_PAIRS]}


# V10ProfileCos ids (v10-profile builds fr_bday_rin_2027 / fr_bday_nova_2027 itself; other years are registered here)
static func frame_id(h: String, year: int) -> String:
	return "fr_bday_%s_%d" % [h, year]


static func claim(key: = "") -> Array:
	var v: = goal_view(_key(key))
	if v.is_empty() or not v.claimable:
		return []
	st().year_done[str(v.h)] = int(v.year)
	var fid: = frame_id(v.h, v.year)
	V10RitBridge.register_frame(fid, "Праздник %s · %d" % [v.gen, v.year], {"type": "bday", "hero": str(v.h), "year": int(v.year)})
	var r: Dictionary = V10BdayData.REWARD.duplicate(true)
	r["frame"] = fid
	r["aff"] = {str(v.h): V10BdayData.REWARD_AFF}
	var leaves: = int(r.get("leaves", 0))
	r.erase("leaves")
	var rows: = V10RitBridge.grant(r, "bday")
	if leaves > 0:
		V10Streak.grant_leaf(leaves)
		rows.append({"kind": "leaves", "n": leaves, "icon": V10RitBridge.ICONS.leaves, "text": "Чайный лист ×%d" % leaves})
	V10RitSave.save()
	return rows


static func letter(h: String) -> Dictionary:
	return {"h": h, "ev": "bday", "subj": "У меня сегодня праздник", "body": V10RitLines.pick("bday_letter", h, 0)}


static func notify_at(key: String) -> int:
	return V10RitClock.unix_of(key, NOTIFY_H, NOTIFY_M)


# picks the strongest letter of the morning: a birthday beats a comeback
static func letter_order(evs: Array) -> Array:
	var a: = evs.duplicate()
	a.sort_custom(func(x, y): return LETTER_PRIORITY.find(str(x)) < LETTER_PRIORITY.find(str(y)))
	return a
