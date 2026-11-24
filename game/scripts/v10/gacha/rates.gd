class_name V10Rates
extends RefCounted

# V10Rates — the ONLY place with gacha odds numbers (spec §2.2, Г1). Same on every banner.
#
# v2 (rates_ver 2):  SSR 1.6 % without the guarantee; from wish #46 since the last SSR +6 % per wish; wish #60 is
#                    always SSR → consolidated ≈ 2.90 %. S 13 %, at least one S-or-better in every 10 wishes
#                    (consolidated ≈ 16.4 %). A — the rest (≈ 80.7 %).
# v1 (rates_ver 1):  the 0.8/0.9 curve (SSR 3 %, S 15 %). A save from 0.9 keeps it until its first SSR after the
#                    update (the announcement letter explains this), then switches to v2 for good.
# Phase banner: an SSR is the featured one with probability 1/2; a miss makes the next SSR the featured one for
#               sure → the worst case for the featured SSR is 120 wishes. The 3 «S of the banner» get half of S drops.
#
#   V10Rates.ssr_rate(p, ver) -> float      chance of SSR on the p-th wish since the last SSR
#   V10Rates.consolidated(ver) -> {SSR,S,A} exact long-run shares (Markov chain over (p, s)), cached
#   V10Rates.mean_ssr_wishes(ver) -> float  expected wishes per SSR
#   V10Rates.item_odds(banner, pool) -> Array[{id, rar, base, total, featured}]   per item, in %, both columns sum 100
#   V10Rates.ref_rub_per_pull() -> float    reference rubles per wish (spec §2.2: 1190 ₽ = 1090 moon, 150 per wish)
#   V10Rates.worst_lines() -> Array[String] the two «худший случай» lines of the rules tab
#   V10Rates.rub_text(rub) -> String        «≈ 19 700 ₽» (rounded to hundreds)

const VER_NOW: = 2
const HARD: = 60
const SOFT_FROM: = 46
const SOFT_STEP: = 0.06
const S_HARD: = 10
const SSR_BASE: = {1: 0.03, 2: 0.016}
const S_BASE: = {1: 0.15, 2: 0.13}
const FEATURED_SHARE: = 0.5
const S_UP_SHARE: = 0.5
const WORST_FEATURED: = 2 * HARD            # 120
const SPARK: = 200                          # the Candle of wishes

# reference price (spec §2.2) — the integrator swaps these for V10Sku.ref_rub_per_pull() when the shop lands
const REF_PACK_RUB: = 1190.0
const REF_PACK_MOON: = 1090.0
const PULL_COST: = 150
const NEWBIE_COST: = 120

static var _cons: = {}


static func ssr_rate(p: int, ver: int = VER_NOW) -> float:
	if p >= HARD:
		return 1.0
	var base: float = SSR_BASE.get(ver, SSR_BASE[VER_NOW])
	if p >= SOFT_FROM:
		return minf(1.0, base + float(p - SOFT_FROM + 1) * SOFT_STEP)
	return base


static func s_rate(ver: int = VER_NOW) -> float:
	return S_BASE.get(ver, S_BASE[VER_NOW])


# one rarity roll; c = {"p": wishes since SSR, "s": wishes since S-or-better}. Mutates c.
static func roll(c: Dictionary, ver: int, r: float, hard: int = HARD) -> String:
	c.p = int(c.p) + 1
	c.s = int(c.s) + 1
	var rate: = 1.0 if int(c.p) >= hard else ssr_rate(int(c.p), ver)
	if r < rate:
		c.p = 0
		c.s = 0
		return "SSR"
	if int(c.s) >= S_HARD or r < rate + s_rate(ver):
		c.s = 0
		return "S"
	return "A"


static func consolidated(ver: int = VER_NOW) -> Dictionary:
	if _cons.has(ver):
		return _cons[ver]
	# stationary distribution over (p, s) by power iteration; small chain (60 × 10)
	var st: = {Vector2i(0, 0): 1.0}
	var acc: = {"SSR": 0.0, "S": 0.0, "A": 0.0}
	for it in 1400:
		var nst: = {}
		for k in st:
			var pr: float = st[k]
			var kv: Vector2i = k
			var p1: int = kv.x + 1
			var s1: int = kv.y + 1
			var r: = ssr_rate(p1, ver)
			var ps: = (1.0 - r) if s1 >= S_HARD else minf(s_rate(ver), 1.0 - r)
			var pa: = maxf(0.0, 1.0 - r - ps)
			nst[Vector2i(0, 0)] = float(nst.get(Vector2i(0, 0), 0.0)) + pr * r
			nst[Vector2i(p1, 0)] = float(nst.get(Vector2i(p1, 0), 0.0)) + pr * ps
			if pa > 0.0:
				nst[Vector2i(p1, s1)] = float(nst.get(Vector2i(p1, s1), 0.0)) + pr * pa
			if it >= 1000:
				acc.SSR += pr * r
				acc.S += pr * ps
				acc.A += pr * pa
		st = nst
	var t: float = acc.SSR + acc.S + acc.A
	var out: = {"SSR": acc.SSR / t, "S": acc.S / t, "A": acc.A / t}
	_cons[ver] = out
	return out


static func mean_ssr_wishes(ver: int = VER_NOW) -> float:
	var surv: = 1.0
	var e: = 0.0
	for p in range(1, HARD + 1):
		var r: = ssr_rate(p, ver)
		e += surv * float(p) * r
		surv *= 1.0 - r
	return e


static func base_rates(ver: int = VER_NOW) -> Dictionary:
	var ssr: float = SSR_BASE[ver]
	var s: float = S_BASE[ver]
	return {"SSR": ssr, "S": s, "A": 1.0 - ssr - s}


# odds per item of a banner. banner: V10Banners dict {kind, ssr:[ids], s_up:[ids]}; pool: {rar: [items]}.
# For a phase banner the featured SSR column «итог» counts the carried promise: 2/3 of all SSRs are featured.
static func item_odds(banner: Dictionary, pool: Dictionary, ver: int = VER_NOW) -> Array:
	var base: = base_rates(ver)
	var tot: = consolidated(ver)
	var out: = []
	var kind: = String(banner.get("kind", "std"))
	var feat: Array = banner.get("ssr", []) if kind == "phase" else []
	var target: = String(banner.get("target", feat[0] if not feat.is_empty() else ""))
	var s_up: Array = banner.get("s_up", []) if kind == "phase" else []
	for rar in ["SSR", "S", "A"]:
		var items: Array = pool.get(rar, [])
		var b: float = base[rar]
		var t: float = tot[rar]
		if rar == "SSR" and kind == "phase" and target != "":
			var others: = items.filter(func(x): return String(x.id) != target)
			out.append({"id": target, "rar": rar, "base": b * FEATURED_SHARE * 100.0, "total": t * (2.0 / 3.0) * 100.0, "featured": true})
			for it in others:
				out.append({"id": String(it.id), "rar": rar, "base": b * (1.0 - FEATURED_SHARE) / others.size() * 100.0,
					"total": t * (1.0 / 3.0) / others.size() * 100.0, "featured": false})
			continue
		if rar == "S" and not s_up.is_empty():
			var rest: = items.filter(func(x): return not (String(x.id) in s_up))
			for id in s_up:
				out.append({"id": String(id), "rar": rar, "base": b * S_UP_SHARE / s_up.size() * 100.0,
					"total": t * S_UP_SHARE / s_up.size() * 100.0, "featured": true})
			for it in rest:
				out.append({"id": String(it.id), "rar": rar, "base": b * (1.0 - S_UP_SHARE) / rest.size() * 100.0,
					"total": t * (1.0 - S_UP_SHARE) / rest.size() * 100.0, "featured": false})
			continue
		for it in items:
			out.append({"id": String(it.id), "rar": rar, "base": b / items.size() * 100.0, "total": t / items.size() * 100.0, "featured": false})
	return out


static func ref_rub_per_pull() -> float:
	return REF_PACK_RUB / REF_PACK_MOON * float(PULL_COST)


static func rub_text(rub: float) -> String:
	var r: = int(round(rub / 100.0)) * 100
	return "≈\u00a0%s\u00a0₽" % group(r)


static func group(n: int) -> String:
	var s: = str(absi(n))
	var out: = ""
	while s.length() > 3:
		out = "\u00a0" + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func pct(x: float) -> String:
	return ("%.2f %%" % x).replace(".", ",")


static func worst_lines() -> Array:
	var r: = ref_rub_per_pull()
	return [
		"SSR героини баннера — не позже %d-го желания %s" % [WORST_FEATURED, rub_text(r * WORST_FEATURED)],
		"Любая SSR из постоянных — через Свечу за %d желаний %s" % [SPARK, rub_text(r * SPARK)],
	]


static func summary_lines(ver: int = VER_NOW) -> Array:
	var b: = base_rates(ver)
	var t: = consolidated(ver)
	return [
		{"rar": "SSR", "base": b.SSR * 100.0, "total": t.SSR * 100.0},
		{"rar": "S", "base": b.S * 100.0, "total": t.S * 100.0},
		{"rar": "A", "base": b.A * 100.0, "total": t.A * 100.0},
	]
