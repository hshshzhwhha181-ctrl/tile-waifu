class_name V10W1Gacha
extends RefCounted

# V10W1Gacha — the five wave-1 goddesses in the Wishes and the Лавка (docs/ROSTER_20.md §1.4 mapped onto the 0.10
# gacha v2 rules, docs/0.10-spec.md Г1–Г8, Л6). Pure data + static helpers, NOT gated itself: every consumer calls it
# only behind V10Wave1.released() (hooks in the wave-1 README).
#
# How each goddess comes (V10Gacha2 pools are outfits; owning any outfit of a goddess = owning her, G.hero_unlocked):
#   A   Цубамэ, Миэль   base outfit (tb_base, me_base) in the standard A pool of every banner; the fixed petals path is
#                       Лавка · Наряды «за лепестки» (V10ShopData.PETAL_PRICE.A); «Семь писем Цубамэ» / «Семь угощений
#                       Миэль»: 7 visits inside a 21-day window → her base outfit in the morning tray (one A a quarter).
#   S   Кохаку, Ширин   base outfit (ko_base, sh_base) in the standard S pool + S rate-up (s_up) of most wave-1 phases;
#                       «Испечь вместе» (Миэль, event lane) ends its track with an S outfit (me_parlor) — data only.
#   SSR Злата           banner-only until std_entry (zl_base, zl_ember → limited_now), then «Пять ветров». Never sold,
#                       never a pass reward, never in «Первый гость» before std_entry.
# Pool rule (ROSTER «Пулы»): a non-base outfit of a wave-1 goddess drops only for a player who owns her, so an A/S item
# never unlocks a goddess of a higher rank (ko_matsuri A → Кохаку S, sh_oasis A → Ширин S, zl_fair S → Злата SSR).
# Featured SSRs and s_up never name such an item (selfcheck). ko_vow / zl_vow are Симпатия 10 «Обет» rewards:
# never in a pool, never in the shop.
#
# Calendar (data/w1_banners.json, the schema of v10/gacha/data/banners.json). The 3+3 rhythm (Г6) is the only model of
# limited banners: 21-day phases from the same anchor, even index = A «Новая луна», odd = B «Полнолуние». Wave 1 takes
# the calendar over from 2027-02-15 (index 4); both plans keep that parity, so any splice point keeps A/B alternating.
# «Масленица» (8–29 March 2027; Масленичная неделя 8–14 March; Злата's birthday 18 March) lands on an odd index, so it
# is a B phase whose default «Цель желания» is Злата «Жар-птица» — for her exactly an A rate-up (half of all SSRs, a
# miss promises the next, ≤ 120 wishes); the second card is Маджонг-тян «Императрица дракона». Злата's rerun is the B
# phase of 4–25 October 2027 (7 months later), after it both her SSR outfits join «Пять ветров» (Афиша notice 14 days
# ahead, std_notice). Dates only, never a countdown longer than 48 h (V10GClock.until_text does the rest).
#
# Лавка: the crystal-shop outfits are the core agent's (V10W1Core.ITEMS `shop` + nogacha: ko_matsuri, sh_oasis 480 —
# «повседневный, магазин», ROSTER §1.2); SHOP mirrors them for the checks. The petals tab lists A/S outfits by rank
# automatically. shop_ok() keeps both tabs to A goddesses' base outfits and to outfits of goddesses the player already
# owns (buying ko_matsuri must never unlock Кохаку).
#
#   V10W1Gacha.data() -> Dictionary                      parsed w1_banners.json (cached)
#   V10W1Gacha.merge(base, keep_t = 0) -> Dictionary     base banners.json + wave-1 phases from index 4 (keep_t: unix of
#                                                        the save's release; base phases started before it stay)
#   V10W1Gacha.phases() -> Array                         wave-1 phases with idx/start/end (unix, 04:00 MSK)
#   V10W1Gacha.maslenitsa() -> Dictionary                the «Масленица» phase
#   V10W1Gacha.droppable(id, owns, t) -> bool            may this wave-1 outfit sit in the pool now (owns: Callable(id))
#   V10W1Gacha.limited_now(t) -> Array                   banner-only wave-1 ids at t
#   V10W1Gacha.shop_ok(id, owns) -> bool                 may the Лавка list this wave-1 outfit
#   V10W1Gacha.std_notice(t) -> Array                    Афиша rows «… — в постоянных желаниях» (14 days ahead)
#   V10W1Gacha.login7_card(S, day, t, give) -> Dict      V10Tray provider body for «Семь писем/угощений»
#   V10W1Gacha.econ_banners(base) -> Array               V10Catalog.BANNERS with lim_zlata/rerun_zlata dated
#   V10W1Gacha.hero_rank(h) / outfit_rank(o) / rar(o)    ranks (V10Rank shape) and the 0.9 `rar` (R/SR/SSR)
#   V10W1Gacha.selfcheck(items = [], base = {}) -> Array [{ok, name}] for --wave1_selftest

const PATH: = "res://scripts/v10/wave1/data/w1_banners.json"
const BASE_PATH: = "res://scripts/v10/gacha/data/banners.json"
const DAY: = 86400

const HEROES: = ["tsubame", "miel", "kohaku", "shirin", "zlata"]
const HERO_NAME: = {"tsubame": "Цубамэ", "miel": "Миэль", "kohaku": "Кохаку", "shirin": "Ширин", "zlata": "Злата"}
const HERO_RANK: = {"tsubame": "A", "miel": "A", "kohaku": "S", "shirin": "S", "zlata": "SSR"}
const BASE_OF: = {"tsubame": "tb_base", "miel": "me_base", "kohaku": "ko_base", "shirin": "sh_base", "zlata": "zl_base"}
# birthdays (spec Р6, ROSTER §2), MM-DD
const BDAY: = {"tsubame": "05-20", "miel": "02-27", "kohaku": "04-27", "shirin": "08-27", "zlata": "03-18"}

# the 18 outfits (ROSTER §3.2–3.4); rank A/S/SSR, `rar` in ITEMS is RAR09[rank]
const OUTFITS: = {
	"tb_base": {"hero": "tsubame", "rank": "A", "name": "Ночная ласточка"},
	"tb_post": {"hero": "tsubame", "rank": "S", "name": "Почта сквозь миры"},
	"tb_crimson": {"hero": "tsubame", "rank": "SSR", "name": "Алая луна клана"},
	"me_base": {"hero": "miel", "rank": "A", "name": "Утренняя выпечка"},
	"me_parlor": {"hero": "miel", "rank": "S", "name": "Салон «Мёд»"},
	"me_gala": {"hero": "miel", "rank": "SSR", "name": "Сахарный бал"},
	"ko_base": {"hero": "kohaku", "rank": "S", "name": "Жрица тысячи врат"},
	"ko_matsuri": {"hero": "kohaku", "rank": "A", "name": "Ночной мацури"},
	"ko_kyubi": {"hero": "kohaku", "rank": "SSR", "name": "Девятихвостая"},
	"ko_vow": {"hero": "kohaku", "rank": "SSR", "name": "Обет лисьей свадьбы", "vow": true},
	"sh_base": {"hero": "shirin", "rank": "S", "name": "Танец семи колодцев"},
	"sh_oasis": {"hero": "shirin", "rank": "A", "name": "Оазис"},
	"sh_sun": {"hero": "shirin", "rank": "SSR", "name": "Дочь полуденного солнца"},
	"sh_night": {"hero": "shirin", "rank": "SSR", "name": "Тысяча и одна партия"},
	"zl_base": {"hero": "zlata", "rank": "SSR", "name": "Жар-птица"},
	"zl_fair": {"hero": "zlata", "rank": "S", "name": "Масленичная ярмарка"},
	"zl_ember": {"hero": "zlata", "rank": "SSR", "name": "Царица-пламя"},
	"zl_vow": {"hero": "zlata", "rank": "SSR", "name": "Обет Жар-птицы", "vow": true},
}
const VOWS: = ["ko_vow", "zl_vow"]
# founder items the wave-1 calendar names (checked against G.ITEMS when the selftest passes them)
const FOUNDER_RANK: = {"o_dragon": "SSR", "h_gym": "SSR", "y_duel": "SSR", "o_cafe": "S", "r_after": "S", "r_maid": "S",
	"n_base": "S", "h_street": "S", "y_base": "S"}
const RANKS: = ["A", "S", "SSR"]
const RAR09: = {"A": "R", "S": "SR", "SSR": "SSR"}

# crystal-shop outfits of wave 1 — mirror of V10W1Core.ITEMS `shop` (the core agent owns the price); owners only (shop_ok)
const SHOP: = {"ko_matsuri": 480, "sh_oasis": 480}

# heroine/UI text checks (spec §2.7 V10Lint.BANNED, UX_RULES §4.3)
const BANNED: = ["скуча", "одна", "обещал", "пропал", "забыл", "почему ты", "бросил", "вернись", "\u20bd", "скидк", "успей",
	"последн", "только сегодня", "купи", "баннер", "акци", "цена", "бесплатн"]
const UI_BANNED: = ["гарант", "пити", "pity", "гача", "ролл", "крутка", "фивер", "ивент", "ульта", "донат", "шаффл", "риичи",
	"квартал", "50/50"]

static var _data: = {}


# ---------------------------------------------------------------- data
static func data() -> Dictionary:
	if _data.is_empty():
		_data = _read(PATH)
	return _data


static func _read(path: String) -> Dictionary:
	var f: = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


# unix time of 04:00 MSK on "YYYY-MM-DD" (0 for a bad string)
static func msk(date: String) -> int:
	var p: = date.split("-")
	if p.size() != 3:
		return 0
	return V10GClock.msk_at(int(p[0]), int(p[1]), int(p[2]))


static func phase_len(d: Dictionary = {}) -> int:
	return int((d if not d.is_empty() else data()).get("phase_days", 21)) * DAY


static func anchor_t(d: Dictionary = {}) -> int:
	return msk(String((d if not d.is_empty() else data()).get("anchor", "2026-11-23")))


static func idx_at(t: int, anchor: int, plen: int) -> int:
	return maxi(0, int(floor(float(t - anchor) / plen)))


static func from_idx() -> int:
	return idx_at(msk(String(data().get("from", ""))), anchor_t(), phase_len())


# ---------------------------------------------------------------- items and ranks
static func is_w1(id: String) -> bool:
	return OUTFITS.has(id)


static func is_w1_hero(hero: String) -> bool:
	return hero in HEROES


static func hero_of(id: String) -> String:
	return String(OUTFITS.get(id, {}).get("hero", ""))


static func is_base(id: String) -> bool:
	return id != "" and BASE_OF.values().has(id)


static func is_vow(id: String) -> bool:
	return id in VOWS


static func hero_rank(hero: String) -> String:
	return String(HERO_RANK.get(hero, ""))


# A / S / SSR of a wave-1 outfit (founder ids the calendar names too); "" when unknown
static func outfit_rank(id: String) -> String:
	if OUTFITS.has(id):
		return String(OUTFITS[id].rank)
	return String(FOUNDER_RANK.get(id, ""))


static func rar(id: String) -> String:
	return String(RAR09.get(outfit_rank(id), ""))


static func outfit_name(id: String) -> String:
	return String(OUTFITS.get(id, {}).get("name", id))


static func outfits_of(hero: String) -> Array:
	var out: = []
	for id in OUTFITS:
		if String(OUTFITS[id].hero) == hero:
			out.append(id)
	return out


static func _rank_i(r: String) -> int:
	return RANKS.find(r)


# ---------------------------------------------------------------- calendar
static func merge(base: Dictionary, keep_t: int = 0) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	var mine: Array = data().get("phases", [])
	if mine.is_empty() or anchor_t(base) != anchor_t() or phase_len(base) != phase_len():
		return out
	var list: Array = out.get("phases", [])
	var k0: = from_idx()
	if list.size() < k0:
		return out
	var k: = k0
	if keep_t > 0:
		k = mini(maxi(k, idx_at(keep_t, anchor_t(), phase_len()) + 1), maxi(k0, list.size()))
	var merged: = list.slice(0, k)
	for j in range(k - k0, mine.size()):
		merged.append((mine[j] as Dictionary).duplicate(true))
	out["phases"] = merged
	out["w1"] = {"from_idx": k0, "splice": k}
	return out


static func phases() -> Array:
	var out: = []
	var k0: = from_idx()
	var a: = anchor_t()
	var L: = phase_len()
	var list: Array = data().get("phases", [])
	for j in list.size():
		var p: Dictionary = (list[j] as Dictionary).duplicate(true)
		p["idx"] = k0 + j
		p["start"] = a + (k0 + j) * L
		p["end"] = a + (k0 + j + 1) * L
		out.append(p)
	return out


static func phase(id: String) -> Dictionary:
	for p in phases():
		if String(p.id) == id:
			return p
	return {}


static func maslenitsa() -> Dictionary:
	return phase("fm_maslenitsa")


# the wave-1 phase running at t ({} outside the wave-1 plan)
static func phase_at(t: int) -> Dictionary:
	for p in phases():
		if t >= int(p.start) and t < int(p.end):
			return p
	return {}


# ---------------------------------------------------------------- pools
static func std_from(id: String) -> int:
	var d: String = String(data().get("std_entry", {}).get(id, ""))
	return msk(d) if d != "" else 0


static func limited_now(t: int) -> Array:
	var out: = []
	for id in data().get("std_entry", {}):
		if std_from(String(id)) > t:
			out.append(String(id))
	return out


static func hero_owned(hero: String, owns: Callable) -> bool:
	if not owns.is_valid():
		return false
	for id in outfits_of(hero):
		if bool(owns.call(id)):
			return true
	return false


static func droppable(id: String, owns: Callable, t: int) -> bool:
	if not OUTFITS.has(id) or is_vow(id):
		return false
	if std_from(id) > t:
		return false
	if is_base(id):
		return true
	return hero_owned(hero_of(id), owns)


static func shop_ok(id: String, owns: Callable) -> bool:
	if not OUTFITS.has(id) or is_vow(id):
		return false
	var h: = hero_of(id)
	if is_base(id):
		return hero_rank(h) == "A"
	return hero_owned(h, owns)


# Афиша: «С 25 октября Злата — в постоянных желаниях: «Жар-птица» и «Царица-пламя»», shown notice_days before
static func std_notice(t: int) -> Array:
	var groups: = {}
	for id in data().get("std_entry", {}):
		var at: = std_from(String(id))
		var key: = "%s@%d" % [hero_of(String(id)), at]
		if not groups.has(key):
			groups[key] = {"hero": hero_of(String(id)), "t": at, "ids": []}
		groups[key].ids.append(String(id))
	var out: = []
	var lead: = int(data().get("notice_days", 14)) * DAY
	for key in groups:
		var g: Dictionary = groups[key]
		if t < int(g.t) - lead or t >= int(g.t):
			continue
		var d: = V10GClock.msk_date(int(g.t))
		var names: = (g.ids as Array).map(func(i): return "«%s»" % outfit_name(String(i)))
		out.append({"hero": g.hero, "ids": g.ids, "t": g.t,
			"text": "С %d %s %s — в постоянных желаниях: %s" % [int(d.day), V10GClock.MON[int(d.month) - 1],
				HERO_NAME.get(g.hero, g.hero), " и ".join(names)]})
	return out


# ---------------------------------------------------------------- «Семь писем Цубамэ» / «Семь угощений Миэль»
# S.v10_w1.login7 = {id: {days: ["YYYY-MM-DD"…], done: bool}}; a day counts once (V10GClock.day_key, 04:00 phone time)
static func login7_list() -> Array:
	return data().get("login7", [])


static func login7_at(t: int) -> Dictionary:
	for w in login7_list():
		var a: = msk(String(w.from))
		if t >= a and t < a + int(w.days) * DAY:
			return w
	return {}


static func login7_st(S: Dictionary, id: String) -> Dictionary:
	if not (S.get("v10_w1") is Dictionary):
		S["v10_w1"] = {}
	var w: Dictionary = S.v10_w1
	if not (w.get("login7") is Dictionary):
		w["login7"] = {}
	var s = w.login7.get(id)
	if not (s is Dictionary):
		s = {}
	if not (s.get("days") is Array):
		s["days"] = []
	s["done"] = bool(s.get("done", false))
	w.login7[id] = s
	return s


static func login7_visit(S: Dictionary, day: String, t: int) -> bool:
	var w: = login7_at(t)
	if w.is_empty():
		return false
	var s: = login7_st(S, String(w.id))
	if bool(s.done) or s.days.size() >= int(w.need) or day in s.days:
		return false
	s.days.append(day)
	return true


static func login7_progress(S: Dictionary, t: int) -> Dictionary:
	var w: = login7_at(t)
	if w.is_empty():
		return {}
	var s: = login7_st(S, String(w.id))
	var n: = mini(s.days.size(), int(w.need))
	return {"id": w.id, "hero": w.hero, "item": w.item, "name": w.name, "days": n, "need": int(w.need),
		"done": bool(s.done), "claimable": n >= int(w.need) and not bool(s.done),
		"until": msk(String(w.from)) + int(w.days) * DAY, "text": "%s %d из %d" % [w.unit, n, int(w.need)]}


# the morning-tray card: counts today's visit, returns {} until the 7th visit; claim → give({kind: "item", id})
static func login7_card(S: Dictionary, day: String, t: int, give: Callable) -> Dictionary:
	login7_visit(S, day, t)
	var p: = login7_progress(S, t)
	if p.is_empty() or not bool(p.claimable):
		return {}
	var w: = login7_at(t)
	var s: = login7_st(S, String(w.id))
	var item: = String(w.item)
	return {"id": String(w.id), "icon": String(w.get("icon", "")), "title": String(w.name), "text": login7_text(w),
		"rewards": {}, "claim": func(): _login7_claim(s, item, give)}


static func login7_text(w: Dictionary) -> String:
	return "%d из %d · %s в наряде «%s» — за твоим столом" % [int(w.need), int(w.need), HERO_NAME.get(String(w.hero), ""),
		outfit_name(String(w.item))]


static func _login7_claim(s: Dictionary, item: String, give: Callable) -> void:
	if bool(s.done):
		return
	s.done = true
	if give.is_valid():
		give.call({"kind": "item", "id": item})


static func events() -> Array:
	return data().get("events", [])


# ---------------------------------------------------------------- economy lane (V10Catalog.BANNERS shape)
static func econ_banners(base: Array) -> Array:
	var out: = []
	for b in base:
		out.append((b as Dictionary).duplicate(true))
	for e in data().get("econ", []):
		var b: = {"id": String(e.id), "kind": String(e.kind), "name": String(e.name), "counter": String(e.counter),
			"cost": int(e.cost), "featured": (e.featured as Array).duplicate(), "start": msk(String(e.from)), "end": msk(String(e.to))}
		var at: = -1
		for i in out.size():
			if String(out[i].id) == b.id:
				at = i
		if at >= 0:
			out[at] = b
		else:
			out.append(b)
	return out


# ---------------------------------------------------------------- texts (every visible string this file makes)
static func texts() -> Array:
	var out: = []
	for p in data().get("phases", []):
		out.append(String(p.name))
		out.append(String(p.sub))
		if p.has("fest"):
			out.append(String(p.fest.name))
	for w in login7_list():
		out.append(String(w.name))
		out.append(String(w.unit))
		out.append(login7_text(w))
	for e in events():
		out.append(String(e.name))
	for e in data().get("econ", []):
		out.append(String(e.name))
	var last: = 0
	for id in data().get("std_entry", {}):
		last = maxi(last, std_from(String(id)))
	for r in std_notice(last - DAY):
		out.append(String(r.text))
	return out


static func lint(s: String) -> Array:
	var bad: = []
	var low: = s.to_lower()
	for w in BANNED + UI_BANNED:
		if low.contains(String(w)):
			bad.append(String(w))
	return bad


# ---------------------------------------------------------------- selfcheck (→ --wave1_selftest)
# items: G.ITEMS with the wave-1 entries (optional), base: the raw v10/gacha banners.json (read from disk when empty)
static func selfcheck(items: Array = [], base: Dictionary = {}) -> Array:
	var out: = []
	var ck: = func(ok: bool, name: String): out.append({"ok": ok, "name": name})
	if base.is_empty():
		base = _read(BASE_PATH)
	var d: = data()
	var list: Array = d.get("phases", [])
	ck.call(int(d.get("ver", 0)) == 1 and list.size() == 12, "w1_banners.json parses: ver 1, 12 phases")
	ck.call(anchor_t(base) == anchor_t() and phase_len(base) == phase_len(), "same anchor and 21-day phases as banners.json")
	var k0: = from_idx()
	var base_list: Array = base.get("phases", [])
	ck.call(k0 == 4 and base_list.size() >= k0, "wave 1 takes over from phase 4 (2027-02-15), base has phases 0–3")
	var aligned: = (msk(String(d.get("from", ""))) - anchor_t()) % phase_len() == 0
	var ids: = {}
	var dates_ok: = true
	var parity_ok: = true
	var shape_ok: = true
	var rank_ok: = true
	var gate_ok: = true
	for j in list.size():
		var p: Dictionary = list[j]
		var i: = k0 + j
		if msk(String(p.get("from", ""))) != anchor_t() + i * phase_len():
			dates_ok = false
		if String(p.half) != ("A" if i % 2 == 0 else "B"):
			parity_ok = false
		var ssr: Array = p.get("ssr", [])
		var sup: Array = p.get("s_up", [])
		if String(p.get("kind", "")) != "phase" or ssr.size() != (1 if String(p.half) == "A" else 2) or sup.size() != 3 \
				or ids.has(String(p.id)) or String(p.get("color", "")).length() != 6 or String(p.get("hero", "")) == "":
			shape_ok = false
		ids[String(p.id)] = true
		var seen: = {}
		for id in ssr + sup:
			if seen.has(id):
				shape_ok = false
			seen[id] = true
		for id in ssr:
			if outfit_rank(String(id)) != "SSR":
				rank_ok = false
		for id in sup:
			if outfit_rank(String(id)) != "S":
				rank_ok = false
		# a featured item is never a vow and never unlocks a goddess of a higher rank than its own
		for id in ssr + sup:
			var sid: = String(id)
			if is_vow(sid):
				gate_ok = false
			if is_w1(sid) and _rank_i(outfit_rank(sid)) < _rank_i(hero_rank(hero_of(sid))):
				gate_ok = false
	ck.call(aligned and dates_ok, "every wave-1 phase starts on the 21-day grid at 04:00 MSK")
	ck.call(parity_ok, "even index = A «Новая луна», odd = B «Полнолуние» (alternation kept at any splice)")
	ck.call(shape_ok, "phase shape: A 1 SSR, B 2 SSR, 3 s_up (S-повышения), unique ids, colour, hero")
	ck.call(rank_ok, "featured SSRs are SSR, s_up (S-повышения) are S")
	ck.call(gate_ok, "no vow and no item that would unlock a higher-rank goddess is featured")
	# coverage
	var featured: = {}
	var sups: = {}
	for p in list:
		for id in p.ssr:
			featured[String(id)] = true
		for id in p.s_up:
			sups[String(id)] = int(sups.get(String(id), 0)) + 1
	var cover_ok: = true
	for id in OUTFITS:
		if String(OUTFITS[id].rank) == "SSR" and not is_vow(id) and not featured.has(id):
			cover_ok = false
	ck.call(cover_ok, "every wave-1 SSR outfit (vows aside) is featured in a phase")
	ck.call(int(sups.get("ko_base", 0)) >= 3 and int(sups.get("sh_base", 0)) >= 3, "Кохаку and Ширин are s_up (S-повышения) in ≥ 3 phases each")
	ck.call(not sups.has("zl_fair") and not sups.has("ko_matsuri") and not sups.has("sh_oasis"), "zl_fair / ko_matsuri / sh_oasis never featured")
	# «Масленица»
	var m: = maslenitsa()
	var bz: = msk("2027-03-18") + 8 * 3600
	ck.call(not m.is_empty() and int(m.start) == msk("2027-03-08") and int(m.end) == msk("2027-03-29") and String(m.ssr[0]) == "zl_base"
		and String(m.hero) == "zlata" and String(m.font) == "zlata", "«Масленица» = 8–29 March 2027, Злата «Жар-птица» is the default target")
	ck.call(not m.is_empty() and msk(String(m.fest.from)) >= int(m.start) and msk(String(m.fest.to)) <= int(m.end) and bz >= int(m.start) and bz < int(m.end),
		"Масленичная неделя 8–14 March and Злата's birthday inside «Масленица»")
	# birthdays 2027 inside a phase of the goddess
	var bd_ok: = true
	for h in HEROES:
		var bt: = msk("2027-" + String(BDAY[h])) + 8 * 3600
		var p: = phase_at(bt)
		if p.is_empty() or String(p.hero) != h:
			bd_ok = false
	ck.call(bd_ok, "each 2027 birthday falls inside a phase of that goddess")
	# rerun and the standard pool
	var zl: = phases().filter(func(p): return String(p.hero) == "zlata" and "zl_base" in p.ssr)
	var last_end: = 0
	for p in phases():
		if String(p.hero) == "zlata":
			last_end = maxi(last_end, int(p.end))
	ck.call(zl.size() == 2 and int(zl[1].start) - int(zl[0].start) >= 180 * DAY and bool(zl[1].get("rerun", false)), "Злата's rerun ≥ 6 months after the debut")
	ck.call(std_from("zl_base") == last_end and std_from("zl_ember") == last_end, "Злата's SSR outfits join «Пять ветров» when her last phase ends")
	# merge
	var mg: = merge(base)
	var ml: Array = mg.get("phases", [])
	var same: = true
	for i in mini(k0, base_list.size()):
		if JSON.stringify(ml[i]) != JSON.stringify(base_list[i]):
			same = false
	ck.call(same and ml.size() == k0 + list.size() and String(ml[k0].id) == String(list[0].id), "merge keeps base phases 0–3 untouched, then wave 1")
	var alt: = true
	for i in range(1, ml.size()):
		if String(ml[i - 1].half) == String(ml[i].half):
			alt = false
	ck.call(alt, "merged calendar alternates A/B")
	var mk: = merge(base, msk("2027-02-20"))
	ck.call((mk.phases as Array).size() > 5 and JSON.stringify(mk.phases[4]) == JSON.stringify(base_list[4]) and String(mk.phases[5].id) == "fm_maslenitsa",
		"merge never rewrites a base phase already running for the save (keep_t)")
	# pools
	var none: = func(_id): return false
	var has_zl: = func(id): return String(id) == "zl_base"
	var has_ko: = func(id): return String(id) == "ko_base"
	var t0: = msk("2027-03-10")
	var t1: = msk("2027-11-01")
	ck.call(droppable("tb_base", none, t0) and droppable("me_base", none, t0) and droppable("ko_base", none, t0) and droppable("sh_base", none, t0),
		"base outfits of A and S goddesses are in the standard pool")
	ck.call(not droppable("zl_base", none, t0) and not droppable("zl_ember", none, t0) and droppable("zl_base", none, t1) and droppable("zl_ember", has_zl, t1),
		"Злата SSR outfits are banner-only until std_entry")
	ck.call(limited_now(t0) == ["zl_base", "zl_ember"] or limited_now(t0) == ["zl_ember", "zl_base"], "limited_now before std_entry = zl_base, zl_ember")
	ck.call(limited_now(t1).is_empty(), "limited_now after std_entry is empty")
	ck.call(not droppable("zl_fair", none, t0) and droppable("zl_fair", has_zl, t0) and not droppable("ko_matsuri", none, t0) and droppable("ko_matsuri", has_ko, t0)
		and not droppable("tb_post", none, t0), "non-base outfits drop only for owners of the goddess")
	ck.call(not droppable("ko_vow", has_ko, t1) and not droppable("zl_vow", has_zl, t1), "vows never drop")
	ck.call(shop_ok("tb_base", none) and shop_ok("me_base", none) and not shop_ok("ko_base", none) and not shop_ok("sh_base", none)
		and not shop_ok("zl_base", has_zl) and not shop_ok("zl_fair", none) and shop_ok("zl_fair", has_zl) and not shop_ok("ko_vow", has_ko)
		and not shop_ok("ko_matsuri", none) and shop_ok("ko_matsuri", has_ko) and not shop_ok("sh_oasis", has_ko),
		"Лавка: A base outfits for petals, the rest only for owners, vows never")
	# login7 and events
	var l7_ok: = true
	var prev_end: = 0
	for w in login7_list():
		var a: = msk(String(w.from))
		if outfit_rank(String(w.item)) != "A" or not is_base(String(w.item)) or int(w.days) < int(w.need) or a < prev_end or a == 0:
			l7_ok = false
		prev_end = a + int(w.days) * DAY
	ck.call(l7_ok and login7_list().size() == 2, "«Семь писем/угощений»: A base outfits, windows apart, need ≤ days")
	var S: = {}
	var w0: Dictionary = login7_list()[0]
	var wa: = msk(String(w0.from)) + 3600
	var got: = []
	var give: = func(r): got.append(r)
	var c: = {}
	for i in 7:
		c = login7_card(S, "d%d" % i, wa + i * DAY, give)
		if i < 6 and not c.is_empty():
			l7_ok = false
	login7_card(S, "d1", wa + DAY, give)
	var counted: = (S.v10_w1.login7[w0.id].days as Array).size()
	if not c.is_empty():
		c.claim.call()
		c.claim.call()
	ck.call(counted == 7 and got.size() == 1 and String(got[0].id) == String(w0.item) and login7_card(S, "d8", wa + 8 * DAY, give).is_empty(),
		"login7: one visit a day, card on the 7th, one grant")
	var ev_ok: = true
	for e in events():
		if outfit_rank(String(e.track_reward)) != "S" or String(e.hero) != hero_of(String(e.track_reward)):
			ev_ok = false
	ck.call(ev_ok and not events().is_empty(), "«Испечь вместе» ends its track with an S outfit of Миэль")
	var eb: = econ_banners([{"id": "lim_zlata", "kind": "limited", "name": "Жар-птица", "counter": "limited", "cost": 150, "featured": ["zlata"], "start": 0, "end": 0}])
	ck.call(eb.size() == 2 and int(eb[0].start) == int(m.start) and int(eb[0].end) == int(m.end), "economy lim_zlata dated as «Масленица»")
	# texts
	var lint_ok: = true
	for s in texts():
		if not lint(String(s)).is_empty():
			lint_ok = false
	ck.call(lint_ok and texts().size() > 20, "no V10Lint.BANNED / UX §4.3 word in any visible string")
	ck.call(not std_notice(std_from("zl_base") - 3 * DAY).is_empty() and std_notice(std_from("zl_base") - 20 * DAY).is_empty(),
		"Афиша notice only in the 14 days before std_entry")
	# items (when the core entries are present)
	if not items.is_empty():
		var by: = {}
		for it in items:
			by[String(it.get("id", ""))] = it
		var it_ok: = true
		for id in OUTFITS:
			var it: Dictionary = by.get(id, {})
			if it.is_empty() or String(it.get("rar", "")) != rar(id) or String(it.get("hero", "")) != hero_of(id) or bool(it.get("limited", false)):
				it_ok = false
			if is_vow(id) and not bool(it.get("nogacha", false)):
				it_ok = false
			if int(it.get("shop", 0)) != int(SHOP.get(id, 0)) or (SHOP.has(id) and not bool(it.get("nogacha", false))):
				it_ok = false
		ck.call(it_ok, "ITEMS: 18 wave-1 outfits, rar/hero as here, vows nogacha, shop = SHOP (+ nogacha), no static `limited`")
		var f_ok: = true
		for id in FOUNDER_RANK:
			if String(by.get(id, {}).get("rar", "")) != String(RAR09[FOUNDER_RANK[id]]):
				f_ok = false
		ck.call(f_ok, "founder items named by the calendar exist with their rank")
	return out
