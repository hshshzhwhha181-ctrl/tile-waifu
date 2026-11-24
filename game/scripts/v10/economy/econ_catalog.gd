class_name V10Catalog
extends RefCounted

# V10Catalog — every number of the 0.10 economy in one place (docs/CEO_PLAN.md §2, №8, №10–16; docs/IDEAS.md №2, №3,
# №5.7; docs/ROSTER_20.md §1.4). Pure data + validators, no state. Everything the shop, gacha and energy read comes
# from here, so a balance change is one edit and the selftest re-checks the store rules (3× ladder, kit-pack cap,
# disclosed odds) on every run.
#
# Currencies (wallet ids):
#   crystal  «Кристаллы»       free premium currency (rewards, month card daily). Pays for pulls.
#   moon     «Лунный камень»   PAID premium currency, only from real-money SKUs. Kept apart for refunds/accounting;
#                              pays for pulls 1:1 like crystals (free crystals are spent first).
#   coin     «Монеты»          soft currency.
#   wish     «Желание»         one pull ticket (any banner except the beginner one).
#   wax      «Воск»            unspent candles of an ended banner; spent in the outfit shop.
#   petal    «Лепестки»        duplicates; fixed-price path to Constellation stars (CEO_PLAN №12).
# Energy «Чай» is not a wallet currency (it regenerates) — see V10Energy.

const CURRENCIES: = ["crystal", "moon", "coin", "wish", "wax", "petal"]
const CUR_NAME: = {"crystal": "Кристаллы", "moon": "Лунный камень", "coin": "Монеты", "wish": "Желание",
	"wax": "Воск", "petal": "Лепестки", "tea": "Чай"}
const PREMIUM: = ["crystal", "moon"]          # spend order: free crystals first, then paid moonstone

# ---------------------------------------------------------------- clock / calendar
const TZ_OFFSET: = 3 * 3600                   # all daily resets on Moscow time, the same for every player
const DAY: = 86400

# ---------------------------------------------------------------- energy «Чай» (CEO_PLAN №8, §2)
const TEA_CAP: = 160
const TEA_REGEN_SEC: = 360                    # 1 tea / 6 min → empty to full in 16 h
const TEA_HARD_MAX: = 2000                    # grants/refills may overfill the cap, never past this
const THERMOS_CAP: = 1200                     # «Термос»: regen overflow while full is stored here 1:1
const TEA_REFILL: = 60                        # one refill gives 60 tea …
const TEA_REFILL_COST: = 60                   # … for a fixed 60 crystals (never escalates)
const TEA_REFILLS_DAY: = 2
const TEA_AD_REFILLS_DAY: = 1

# ---------------------------------------------------------------- gacha (ROSTER_20 §1.4, g.gd roll())
const RARS: = ["A", "S", "SSR"]
const PULL_COST: = 150                        # crystals/moonstone per pull
const SSR_BASE: = 0.03
const S_BASE: = 0.15
const SOFT_FROM: = 46                         # pull #46 since the last SSR is the first with a raised rate
const SOFT_STEP: = 0.06                       # +6 % per pull from #46: 9 %, 15 %, 21 % …
const SSR_HARD: = 60                          # pull #60 is always SSR
const S_HARD: = 10                            # every 10th pull without S-or-better is at least S
const NEWBIE_PULLS: = 50                      # beginner banner: 50 pulls total, no timer
const NEWBIE_HARD: = 50                       # SSR guaranteed within those 50
const NEWBIE_COST: = 120                      # -20 %
const SPARK: = 200                            # «Свеча желаний»: 200 candles → any featured SSR of the banner
const WAX_PER_CANDLE: = 1                     # unspent candles become wax when the banner ends
const HISTORY_DAYS: = 90
const HISTORY_MAX: = 4000
const CONST_MAX: = 5                          # «Созвездие» 0–5★ from duplicate heroines
const DUP_PETALS: = {"A": 5, "S": 20, "SSR": 60}   # duplicate outfit / heroine past ★5 → petals
const PETALS_PER_STAR: = 60                   # guaranteed path: 1 star = 60 petals

# Gacha rule sets. A counter keeps the rules it was started under until it resets on an SSR; a new rule set only
# applies to counters that start ≥ RULE_NOTICE_DAYS after it was announced (CEO_PLAN №10: 50/50 only for new counters,
# announced 14 days ahead).
const RULE_NOTICE_DAYS: = 14
const RULESETS: = {
	# 0.8/0.9 client rules (g.gd pull()): 50/50 with the guarantee carried to the next SSR
	"r0": {"featured_share": 0.5, "carry_guarantee": true},
	# 1.0 rules, identical numbers; kept separate so a future change has a clean announce/effective path
	"r1": {"featured_share": 0.5, "carry_guarantee": true},
}
const RULES_CURRENT: = "r1"
const RULES_ANNOUNCED: = 0                    # unix; 0 = in force for every new counter

# First SSR of choice (IDEAS №2): three SSR outfits, free, final, once.
const FIRST_SSR_CHOICES: = ["o_dragon", "y_queen", "n_ssr"]

# Standard pool from ROSTER_20 (founders come from Path shards, never from the gacha). Outfits are added by the
# integrator from g.gd ITEMS; an outfit only drops when its heroine is owned (ROSTER_20 §1.4 «Пулы»).
const POOL_HEROES: = [
	{"id": "tsubame", "rar": "A", "kind": "hero"}, {"id": "miel", "rar": "A", "kind": "hero"},
	{"id": "lian", "rar": "A", "kind": "hero"}, {"id": "tsuru", "rar": "A", "kind": "hero"},
	{"id": "jess", "rar": "A", "kind": "hero"},
	{"id": "kohaku", "rar": "S", "kind": "hero"}, {"id": "shirin", "rar": "S", "kind": "hero"},
	{"id": "mari", "rar": "S", "kind": "hero"}, {"id": "hibana", "rar": "S", "kind": "hero"},
	{"id": "nemi", "rar": "S", "kind": "hero"},
	{"id": "zlata", "rar": "SSR", "kind": "hero"}, {"id": "minamo", "rar": "SSR", "kind": "hero"},
	{"id": "kira", "rar": "SSR", "kind": "hero"}, {"id": "vesper", "rar": "SSR", "kind": "hero"},
	{"id": "sigrid", "rar": "SSR", "kind": "hero"},
]

# Banners. kind: standard | newbie | limited. counter: pity is shared by every banner with the same counter id
# (all limited banners share one, like the 0.8 S.pity). start/end: unix, 0 = open. A limited banner with two featured
# SSRs is the «3+3» rerun: the player picks which one a won 50/50 gives (target) and the spark can take either.
const BANNERS: = [
	{"id": "std", "kind": "standard", "name": "Чайный круг", "counter": "std", "cost": PULL_COST, "featured": []},
	{"id": "newbie", "kind": "newbie", "name": "Первый гость", "counter": "newbie", "cost": NEWBIE_COST,
		"featured": [], "limit": NEWBIE_PULLS, "hard": NEWBIE_HARD},
	{"id": "lim_zlata", "kind": "limited", "name": "Жар-птица", "counter": "limited", "cost": PULL_COST,
		"featured": ["zlata"], "start": 0, "end": 0},
	{"id": "rerun_night", "kind": "limited", "name": "Алая ночь и сияние", "counter": "limited", "cost": PULL_COST,
		"featured": ["vesper", "sigrid"], "start": 0, "end": 0},
]

# ---------------------------------------------------------------- shop (CEO_PLAN №11, №13–16, §2)
# Price ladder rule: no offer may be more than LADDER_MAX× better than the base pack in rubles per pull.
# Base pack = BASE_SKU without bonus. Month card ≈ 3×, pass ≈ 2×, first-purchase double ≤ 2×.
const LADDER_MAX: = 3.0
const KIT_MAX_RUB: = 4990                     # no SKU above 4990 ₽
const BASE_SKU: = "moon_180"
const NEWBIE_WINDOW_DAYS: = 14                # beginner sets stay in the shop 14 days from install, no countdown popup
const MONTH_DAYS: = 30
const MONTH_STACK_MAX: = 180
const MONTH_NOW: = {"moon": 300}
const MONTH_DAILY: = {"crystal": 90}

# kind: currency | starter | month | pass | outfit
#   base/bonus — currency packs: bonus normally, first purchase gives base again instead (double)
#   grant      — fixed contents; «value» for the ladder counts crystal/moon/150 + wish
#   once       — buyable once per account; window_days — days from install it is listed
#   requires_server — consumables are sold only with the server wallet (CEO_PLAN §4)
#   restorable — comes back through getPurchases on a new install
const SKUS: = [
	{"id": "moon_180", "kind": "currency", "rub": 79, "base": {"moon": 180}, "bonus": {}, "requires_server": true},
	{"id": "moon_900", "kind": "currency", "rub": 379, "base": {"moon": 860}, "bonus": {"moon": 40}, "requires_server": true},
	{"id": "moon_3000", "kind": "currency", "rub": 1190, "base": {"moon": 2710}, "bonus": {"moon": 290}, "requires_server": true},
	{"id": "moon_6000", "kind": "currency", "rub": 2290, "base": {"moon": 5220}, "bonus": {"moon": 780}, "requires_server": true},
	{"id": "moon_10200", "kind": "currency", "rub": 3790, "base": {"moon": 8640}, "bonus": {"moon": 1560}, "requires_server": true},
	{"id": "moon_14000", "kind": "currency", "rub": 4990, "base": {"moon": 11370}, "bonus": {"moon": 2630}, "requires_server": true},
	{"id": "first_79", "kind": "starter", "name": "Первая покупка", "rub": 79, "grant": {"moon": 450, "coin": 2000},
		"once": true, "requires_server": true},
	{"id": "guest_149", "kind": "starter", "name": "Набор первого гостя", "rub": 149,
		"grant": {"moon": 600, "wish": 2, "tea": 120}, "once": true, "window_days": NEWBIE_WINDOW_DAYS, "requires_server": true},
	{"id": "newbie_499", "kind": "starter", "name": "Набор новичка", "rub": 499,
		"grant": {"moon": 1800, "wish": 8}, "once": true, "window_days": NEWBIE_WINDOW_DAYS, "requires_server": true},
	{"id": "growth_1490", "kind": "starter", "name": "Набор роста", "rub": 1490,
		"grant": {"moon": 3600, "wish": 20, "coin": 20000}, "once": true, "requires_server": true},
	{"id": "month_449", "kind": "month", "name": "Лунный абонемент", "rub": 449, "restorable": true},
	{"id": "pass_899", "kind": "pass", "name": "Пропуск сезона", "rub": 899, "restorable": true},
	{"id": "pass_1490", "kind": "pass", "name": "Пропуск сезона+", "rub": 1490, "deluxe": true,
		"grant": {"moon": 1500}, "skip_tiers": 10, "restorable": true},
]

# Outfits sold directly for rubles (restorable, no randomness). Integrator adds SKUs with outfit_sku().
const OUTFIT_RUB: = {"A": 199, "S": 399, "SSR": 899}

# ---------------------------------------------------------------- battle pass (CEO_PLAN №15, IDEAS §3.3)
const PASS_TIERS: = 30
const PASS_XP_TIER: = 100
const PASS_LATE_DAYS: = 10                    # XP ×2 in the last 10 days of the season
const PASS_SKIP_XP_MAX: = 3000
# 30 tiers; free track modest, premium track sums to 2700 crystals + 9 wishes (+ exclusive SSR outfit on 30)
static func pass_free(tier: int) -> Dictionary:     # tier 1..30
	if tier % 10 == 0:
		return {"crystal": 100, "coin": 3000}
	if tier % 5 == 0:
		return {"tea": 60}
	return {"coin": 800} if tier % 2 == 1 else {"crystal": 20}


static func pass_prem(tier: int) -> Dictionary:
	if tier == PASS_TIERS:
		return {"crystal": 300, "wish": 3, "items": ["@season_outfit"]}
	if tier % 5 == 0:
		return {"wish": 1, "crystal": 60}       # tiers 5,10,15,20,25 → 5 wishes (+3 on 30, +1 on 3 below = 9)
	if tier == 3:
		return {"wish": 1, "crystal": 60}
	return {"crystal": 100}


static func pass_track_total(prem: bool) -> Dictionary:
	var t: = {}
	for i in range(1, PASS_TIERS + 1):
		var r: Dictionary = pass_prem(i) if prem else pass_free(i)
		for k in r:
			if k == "items":
				continue
			t[k] = int(t.get(k, 0)) + int(r[k])
	return t


# ---------------------------------------------------------------- spending protection (CEO_PLAN №16, §5; IDEAS 5.13)
const AGE_LIMIT_RUB_30D: = 3000               # hard limit until 18+ is verified
const BIG_PURCHASE_RUB: = 1490                # optional «остыть 24 часа» after a purchase this big
const COOL_SEC: = DAY
const LIMIT_RAISE_DELAY: = DAY                # raising your own limit applies after 24 h, lowering at once


# ================================================================= lookups
static func banner(id: String) -> Dictionary:
	for b in BANNERS:
		if b.id == id:
			return b
	return {}


static func sku(id: String) -> Dictionary:
	for s in SKUS:
		if s.id == id:
			return s
	return {}


static func outfit_sku(item_id: String, rar: String) -> Dictionary:
	return {"id": "outfit_" + item_id, "kind": "outfit", "name": item_id, "rub": int(OUTFIT_RUB.get(rar, 399)),
		"grant": {"items": [item_id]}, "once": true, "restorable": true}


static func ssr_rate(p: int) -> float:
	# p = number of this pull since the last SSR (1-based)
	if p >= SSR_HARD:
		return 1.0
	if p >= SOFT_FROM:
		return minf(1.0, SSR_BASE + float(p - SOFT_FROM + 1) * SOFT_STEP)
	return SSR_BASE


static func ruleset(id: String) -> Dictionary:
	return RULESETS.get(id, RULESETS[RULES_CURRENT])


# What a SKU grants on delivery (first: first purchase of a currency pack → base doubled instead of the bonus)
static func sku_grant(s: Dictionary, first: bool) -> Dictionary:
	var g: = {}
	match String(s.get("kind", "")):
		"currency":
			_add_into(g, s.base)
			_add_into(g, s.base if first else s.get("bonus", {}))
		"month":
			_add_into(g, MONTH_NOW)
		_:
			_add_into(g, s.get("grant", {}))
	return g


static func _add_into(into: Dictionary, g: Dictionary) -> void:
	for k in g:
		if k == "items":
			var a: Array = into.get("items", [])
			a.append_array(g[k])
			into["items"] = a
		else:
			into[k] = int(into.get(k, 0)) + int(g[k])


# pulls a SKU is worth (premium currency / PULL_COST + wishes), for the ladder rule and «≈ N ₽ за крутку»
static func pull_value(s: Dictionary, first: bool = false) -> float:
	var g: = sku_grant(s, first)
	var kind: = String(s.get("kind", ""))
	if kind == "month":
		_add_into(g, {"crystal": int(MONTH_DAILY.crystal) * MONTH_DAYS})
	elif kind == "pass":
		# tier skips only move you along the same track: no extra value
		_add_into(g, pass_track_total(true))
	var v: = float(int(g.get("crystal", 0)) + int(g.get("moon", 0))) / float(PULL_COST)
	return v + float(int(g.get("wish", 0)))


static func rub_per_pull(s: Dictionary, first: bool = false) -> float:
	var v: = pull_value(s, first)
	return INF if v <= 0.0 else float(s.rub) / v


static func base_rub_per_pull() -> float:
	return rub_per_pull(sku(BASE_SKU), false)


static func best_rub_per_pull() -> float:
	# the best repeatable currency pack (no first bonus, no one-off offers)
	var best: = INF
	for s in SKUS:
		if s.kind == "currency":
			best = minf(best, rub_per_pull(s, false))
	return best


static func ladder_ratio(s: Dictionary, first: bool = false) -> float:
	var r: = rub_per_pull(s, first)
	return 0.0 if r == INF else base_rub_per_pull() / r


static func fmt_rub(n: float) -> String:
	var i: = int(round(n))
	var t: = str(i)
	if i >= 1000:
		t = "%d %03d" % [i / 1000, i % 1000]
	return t + " ₽"


# Store rules over the whole catalog; returns a list of problems (empty = compliant).
static func validate() -> Array:
	var bad: = []
	var ids: = {}
	for s in SKUS:
		if ids.has(s.id):
			bad.append("duplicate sku %s" % s.id)
		ids[s.id] = true
		if int(s.get("rub", 0)) <= 0:
			bad.append("%s has no ruble price" % s.id)
		if int(s.rub) > KIT_MAX_RUB:
			bad.append("%s costs %d ₽ > kit cap %d ₽" % [s.id, s.rub, KIT_MAX_RUB])
		for first in [false, true]:
			if first and s.kind != "currency":
				continue
			var r: = ladder_ratio(s, first)
			if r > LADDER_MAX + 0.0001:
				bad.append("%s%s is %.2f× the base pack (max %.1f×)" % [s.id, " (first)" if first else "", r, LADDER_MAX])
		if s.kind == "currency" and not bool(s.get("requires_server", false)):
			bad.append("%s is a consumable without the server flag" % s.id)
	for b in BANNERS:
		if not (b.kind in ["standard", "newbie", "limited"]):
			bad.append("banner %s has unknown kind" % b.id)
		if b.kind == "limited" and b.featured.is_empty():
			bad.append("limited banner %s has no featured SSR" % b.id)
	return bad
