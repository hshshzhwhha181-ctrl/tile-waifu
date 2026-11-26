class_name V10DuelRank
extends RefCounted

# V10DuelRank — the numbers of the ranked duel (spec R6): Elo, «шанс по рейтингу», the 6 season tiers, 28-day
# seasons on the МСК week grid, the soft reset, the season-end reward by PEAK tier, the offers within ±150, gates.
#
#   K_for(games) -> 40 for the first 20 ranked games, then 24
#   expected(a, b) -> float            Elo expectation of a against b
#   delta(dr, opp, score, games) -> int   score 1 / 0.5 / 0; a win is never below +1, a loss never above −1
#   chance(dr, opp) -> int 1…99; chance_text(dr, opp) -> «46 из 100» (never «%», UX §4)
#   tier_of(dr) -> 0…5; tier_name(i); tier_caption(i) «ступень 2 из 6»; rating_text(dr) «Рейтинг 1 040» (never «ДР»)
#   TIER_PAL[i] = {metal, lacquer, glow}: palettes of the tier frames for the frame shader (UI lane)
#   soft_reset(dr) -> 1000 + (dr − 1000) / 2
#   season_reward(tier) -> {gems, frame?, title?}; cos_defs() -> entries for V10ProfileCos.register
#   rating(h, f) -> int                from data/duel_ratings.json (offline calibration, monotone in the form)
#   bounds() -> Vector2i(lo, hi)       ratings where 3 offers within ±150 always exist; the player's rating is kept in it
#   offers(dr, day, used, roll) -> Array[3]   deterministic: same day + rating + roll + used = same offers
#   menu_open(S), ranked_open(S, casual_wins), lock texts

const U: = preload("res://scripts/v10/duels/duel_util.gd")
const F: = preload("res://scripts/v10/duels/duel_forms.gd")
const C: = preload("res://scripts/v10/duels/duel_cfg.gd")

const START: = 1000
const K_NEW: = 40
const K_SETTLED: = 24
const NEW_GAMES: = 20
const WINDOW: = 150
const OFFERS: = 3
const RATINGS_PATH: = "res://scripts/v10/duels/data/duel_ratings.json"

const TIERS: = [
	{"id": "bronze", "name": "Бронзовый веер", "min": -100000},
	{"id": "silver", "name": "Серебряный веер", "min": 1000},
	{"id": "lacquer", "name": "Лаковый веер", "min": 1200},
	{"id": "cinnabar", "name": "Киноварный веер", "min": 1400},
	{"id": "pearl", "name": "Перламутровый веер", "min": 1600},
	{"id": "sky", "name": "Небесный веер", "min": 1800},
]
# frame-shader palettes of the six tiers (cosmetic data, read by the UI lane and by cos_defs)
const TIER_PAL: = [
	{"metal": "b07a4a", "lacquer": "3a2418", "glow": "d29a62"},
	{"metal": "cfd3da", "lacquer": "2a2c33", "glow": "e8ecf2"},
	{"metal": "e8c47e", "lacquer": "1b171c", "glow": "f1d9a0"},
	{"metal": "e8c47e", "lacquer": "c8463c", "glow": "e07a5a"},
	{"metal": "f3eee6", "lacquer": "d9cfe6", "glow": "e6e0ff"},
	{"metal": "f1d9a0", "lacquer": "4f6fc8", "glow": "a9c8ff"},
]
# season end, by the PEAK tier of the season (economy budget §2.3: outside the daily cap)
const SEASON_REWARDS: = [
	{"gems": 50},
	{"gems": 100},
	{"gems": 150},
	{"gems": 250, "frame": "fr_duel_cinnabar"},
	{"gems": 350, "frame": "fr_duel_pearl", "title": "t_duel_pearl"},
	{"gems": 500, "frame": "fr_duel_sky"},
]

const T_MENU_LOCK: = "Откроется на ранге Нефрит III"
const T_RANKED_LOCK: = "Откроется на ранге Нефрит III или после 10 побед в дружеских дуэлях"
const CASUAL_FOR_RANKED: = 10


# ---------------------------------------------------------------- Elo

static func k_for(games: int) -> int:
	return K_NEW if games < NEW_GAMES else K_SETTLED


static func expected(a: float, b: float) -> float:
	return 1.0 / (1.0 + pow(10.0, (b - a) / 400.0))


static func delta(dr: int, opp: int, score: float, games: int) -> int:
	var d: = int(round(float(k_for(games)) * (score - expected(dr, opp))))
	if score >= 1.0:
		d = maxi(1, d)
	elif score <= 0.0:
		d = mini(-1, d)
	return d


static func chance(dr: int, opp: int) -> int:
	return clampi(int(round(100.0 * expected(dr, opp))), 1, 99)


static func chance_text(dr: int, opp: int) -> String:
	return "%d из 100" % chance(dr, opp)


# ---------------------------------------------------------------- tiers

static func tier_of(dr: int) -> int:
	var t: = 0
	for i in TIERS.size():
		if dr >= int(TIERS[i].min):
			t = i
	return t


static func tier_name(i: int) -> String:
	return String(TIERS[clampi(i, 0, TIERS.size() - 1)].name)


static func tier_caption(i: int) -> String:
	return "ступень %d из %d" % [clampi(i, 0, TIERS.size() - 1) + 1, TIERS.size()]


static func rating_text(dr: int) -> String:
	return "Рейтинг %s" % U.fmt_int(dr)


static func next_tier_text(dr: int) -> String:
	var t: = tier_of(dr)
	if t >= TIERS.size() - 1:
		return "Высшая ступень"
	var need: = int(TIERS[t + 1].min) - dr
	return "До ступени «%s» ещё %s %s рейтинга" % [tier_name(t + 1), U.fmt_int(need), U.plural(need, "очко", "очка", "очков")]


# ---------------------------------------------------------------- seasons

static func soft_reset(dr: int) -> int:
	return START + int(round(float(dr - START) * 0.5))


static func season_reward(tier: int) -> Dictionary:
	return SEASON_REWARDS[clampi(tier, 0, SEASON_REWARDS.size() - 1)].duplicate()


static func season_text(sid: int) -> String:
	return "Сезон %d · %s" % [U.season_num(sid), U.until_text(U.season_end(sid))]


# frames and the title of the season end (V10ProfileCos.register; never sold: source «grant»)
static func cos_defs() -> Array:
	var p3: Dictionary = TIER_PAL[3]
	var p4: Dictionary = TIER_PAL[4]
	var p5: Dictionary = TIER_PAL[5]
	var hint: = "Дойди до ступени «%s» в сезоне дуэлей"
	return [
		{"id": "fr_duel_cinnabar", "kind": "frame", "name": "Киноварный веер", "tier": "S",
			"src": {"type": "grant", "event": "duel_season", "hint": hint % tier_name(3)},
			"look": {"base": "ring", "metal": p3.metal, "violet": p3.lacquer, "deco": "gems", "deco_col": p3.lacquer, "glow": p3.glow}},
		{"id": "fr_duel_pearl", "kind": "frame", "name": "Перламутровый веер", "tier": "SSR",
			"src": {"type": "grant", "event": "duel_season", "hint": hint % tier_name(4)},
			"look": {"base": "wing", "metal": p4.metal, "violet": p4.lacquer, "deco": "pearls", "deco_col": p4.metal, "glow": p4.glow}},
		{"id": "t_duel_pearl", "kind": "title", "name": "Перламутровый веер", "tier": "SSR",
			"src": {"type": "grant", "event": "duel_season", "hint": hint % tier_name(4)}},
		{"id": "fr_duel_sky", "kind": "frame", "name": "Небесный веер", "tier": "SSR",
			"src": {"type": "grant", "event": "duel_season", "hint": hint % tier_name(5)},
			"look": {"base": "wing", "metal": p5.metal, "violet": p5.lacquer, "deco": "stars", "deco_col": p5.glow, "glow": p5.glow, "anim": true}},
	]


# registers the season cosmetics once (call at boot / from registry_list); returns the errors
static func register_cos() -> Array:
	var cos: = U.klass("V10ProfileCos")
	if cos == null:
		cos = load("res://scripts/v10/profile/cosmetics.gd")
	var errs: = []
	if cos == null:
		return ["V10ProfileCos missing"]
	for e in cos_defs():
		if bool(cos.call("has", String(e.id), "")):
			continue
		var err: = String(cos.call("register", e))
		if err != "":
			errs.append(err)
	return errs


# ---------------------------------------------------------------- calibrated ratings

static var _ratings: = {}
static var _loaded: = false
static var test_ratings = null   # selftests: a {hero: [5 ratings]} dict

static func ratings() -> Dictionary:
	if test_ratings != null:
		return test_ratings
	if not _loaded:
		_loaded = true
		var f: = FileAccess.open(RATINGS_PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary and d.get("ratings") is Dictionary:
				_ratings = d.ratings
	return _ratings


static func reload() -> void:
	_loaded = false
	_ratings = {}
	_bounds_key = ""


static func rating(h: String, f: int) -> int:
	var r = ratings().get(h)
	if r is Array and r.size() >= F.FORMS:
		return int(r[clampi(f, 1, F.FORMS) - 1])
	# no data (should not happen in a build; the selftest requires the file): a rough guess from her pace
	var fm: = F.form(h, f)
	return int(round(2300.0 - 300.0 * float(fm.pace)))


static var _bounds: = Vector2i(START, START)
static var _bounds_key: = ""

static func _pool_ratings() -> Array:
	var out: = []
	for h in F.heroes():
		for f in range(1, F.FORMS + 1):
			out.append(rating(h, f))
	return out


static func _covered(x: int, rs: Array) -> bool:
	var n: = 0
	for r in rs:
		if absi(int(r) - x) <= WINDOW:
			n += 1
	return n >= OFFERS


# the contiguous band around START where 3 offers within ±150 always exist; the rating is kept inside it
static func bounds() -> Vector2i:
	var key: = ",".join(F.heroes()) + "|" + str(ratings().size()) + "|" + str(test_ratings != null)
	if key == _bounds_key:
		return _bounds
	var rs: = _pool_ratings()
	var lo: = START
	var hi: = START
	if _covered(START, rs):
		while lo > 0 and _covered(lo - 1, rs):
			lo -= 1
		while hi < 4000 and _covered(hi + 1, rs):
			hi += 1
	_bounds = Vector2i(lo, hi)
	_bounds_key = key
	return _bounds


static func clamp_dr(dr: int) -> int:
	var b: = bounds()
	return clampi(dr, b.x, b.y)


# ---------------------------------------------------------------- offers

static func offer_key(day: String, h: String, f: int) -> String:
	return "%s|%s|%d" % [day, h, f]


# used: {"h|f": round} of today's played offers. Every offer is a fixed (her, form, rating, trick, seed): the same
# (day, rival, form) is one deal; an offer that was played is never offered again that day (round + 1 only when
# every combination within ±150 is used up).
static func offers(dr: int, day: String, used: Dictionary, roll: int = 0) -> Array:
	var x: = clamp_dr(dr)
	var pool: = []
	for h in F.heroes():
		for f in range(1, F.FORMS + 1):
			var r: = rating(h, f)
			if absi(r - x) <= WINDOW:
				pool.append({"h": h, "f": f, "r": r, "o": U.hseed(["offer", day, roll, h, f]), "round": int(used.get("%s|%d" % [h, f], -1)) + 1})
	pool.sort_custom(func(a, b): return int(a.o) < int(b.o))
	var fresh: = pool.filter(func(p): return int(p.round) == 0)
	var picked: = []
	var heroes_in: = {}
	var take: = func(p: Dictionary) -> void:
		picked.append(p)
		heroes_in[p.h] = true
	# one at or below the player, one above, then the most varied rest (distinct heroines first)
	for want in ["low", "high", "any"]:
		for p in fresh:
			if picked.size() >= OFFERS or picked.has(p) or heroes_in.has(p.h):
				continue
			if want == "low" and int(p.r) > x:
				continue
			if want == "high" and int(p.r) <= x:
				continue
			take.call(p)
			break
	for p in fresh:
		if picked.size() < OFFERS and not picked.has(p) and not heroes_in.has(p.h):
			take.call(p)
	for p in fresh:
		if picked.size() < OFFERS and not picked.has(p):
			take.call(p)
	var replay: = pool.filter(func(p): return int(p.round) > 0)
	for p in replay:
		if picked.size() < OFFERS and not picked.has(p):
			take.call(p)
	picked.sort_custom(func(a, b): return int(a.r) < int(b.r) or (int(a.r) == int(b.r) and String(a.h) < String(b.h)))
	var out: = []
	for p in picked:
		out.append(make_offer("ranked", String(p.h), int(p.f), day, dr, int(p.round)))
	return out


static func make_offer(kind: String, h: String, f: int, day: String, dr: int, round_n: int = 0) -> Dictionary:
	var fm: = F.form(h, f)
	var opp: = rating(h, f)
	var o: = {
		"id": "%s|%s|%s|%d|%d" % [kind, day, h, f, round_n],
		"kind": kind, "rival": h, "form": f, "roman": F.roman(f), "day": day, "round": round_n,
		"name": U.hero_name(h), "badge": "ИИ · героиня",
		"dr_opp": opp, "dr_opp_text": rating_text(opp),
		"chance": chance(dr, opp), "chance_text": chance_text(dr, opp),
		"trick": fm.trick, "trick_name": fm.trick_name, "trick_n": int(fm.trick_n),
		"trick_text": F.trick_text(h, f),
		"seed": C.deal_seed(kind, day, h, f, round_n),
		"price": 0,
	}
	return o


# ---------------------------------------------------------------- gates

static func jade3_index() -> int:
	if U.has_g():
		for t in G.RANKS.size():
			if String(G.RANKS[t].name) == "Нефрит":
				return t * 3 + 2
	return 5


static func rank_index(S: Dictionary) -> int:
	if not U.has_g():
		return 0
	return int(G.rank_index(int(S.get("rp", 0))))


static func menu_open(S: Dictionary) -> bool:
	return rank_index(S) >= jade3_index()


static func ranked_open(S: Dictionary, casual_wins: int) -> bool:
	return rank_index(S) >= jade3_index() or casual_wins >= CASUAL_FOR_RANKED


static func all_texts() -> Array:
	var out: = [T_MENU_LOCK, T_RANKED_LOCK, rating_text(1040), chance_text(1000, 1040), next_tier_text(1150), next_tier_text(1900)]
	for i in TIERS.size():
		out.append(tier_name(i))
		out.append(tier_caption(i))
	for e in cos_defs():
		out.append(String(e.name))
		out.append(String(e.src.hint))
	return out
