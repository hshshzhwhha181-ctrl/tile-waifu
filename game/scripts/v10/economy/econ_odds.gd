class_name V10Odds
extends RefCounted

# V10Odds — exact odds for the single odds screen (IDEAS 5.7, CEO_PLAN №10/№11; RuStore / Google Play loot-box
# disclosure). Everything is computed from V10Catalog with Markov chains, not hand-typed, so the screen can never
# drift from the rules; the selftest checks these numbers against a Monte-Carlo run of V10Gacha.
#
#   first_ssr_dist(hard) -> Array   P(first SSR exactly at pull k), k = 1..hard (index k-1)
#   expected_to_ssr(hard) -> float  mean pulls per SSR
#   consolidated(hard) -> {"SSR","S","A"}  long-run share of each rarity with pity (stationary chain over (p, s))
#   featured_expected(hard) / featured_worst(hard)   pulls per featured SSR on a limited banner (50/50 + guarantee)
#   disclosure(banner_id, gacha=null) -> Dictionary  everything the odds screen shows, numbers + RU lines
#   rub_label(pulls) -> String      «≈ 1 317–1 975 ₽» from the best and the base pack

static var _cache: = {}


static func first_ssr_dist(hard: int = V10Catalog.SSR_HARD) -> Array:
	var out: = []
	var alive: = 1.0
	for k in range(1, hard + 1):
		var r: = V10Gacha.rate_at(k, hard)
		out.append(alive * r)
		alive *= 1.0 - r
	return out


static func expected_to_ssr(hard: int = V10Catalog.SSR_HARD) -> float:
	var d: = first_ssr_dist(hard)
	var e: = 0.0
	for i in d.size():
		e += float(i + 1) * float(d[i])
	return e


# stationary distribution of the (pulls since SSR, pulls since S+) chain → long-run rarity shares
static func consolidated(hard: int = V10Catalog.SSR_HARD) -> Dictionary:
	var key: = "cons%d" % hard
	if _cache.has(key):
		return _cache[key]
	var SH: = V10Catalog.S_HARD
	var n: = hard * SH
	var pi: = PackedFloat64Array()
	pi.resize(n)
	pi.fill(0.0)
	pi[0] = 1.0
	var ssr: = 0.0
	var s: = 0.0
	for it in 4000:
		var nx: = PackedFloat64Array()
		nx.resize(n)
		nx.fill(0.0)
		ssr = 0.0
		s = 0.0
		for p in hard:
			for q in SH:
				var w: = pi[p * SH + q]
				if w == 0.0:
					continue
				var p2: = p + 1
				var q2: = q + 1
				var r: = V10Gacha.rate_at(p2, hard)
				var rs: = (1.0 - r) if q2 >= SH else minf(V10Catalog.S_BASE, 1.0 - r)
				ssr += w * r
				s += w * rs
				nx[0] += w * r
				if p2 < hard:
					nx[p2 * SH + 0] += w * rs
					if q2 < SH:
						nx[p2 * SH + q2] += w * (1.0 - r - rs)
		var diff: = 0.0
		for i in n:
			diff += absf(nx[i] - pi[i])
		pi = nx
		if diff < 1e-13:
			break
	var out: = {"SSR": ssr, "S": s, "A": 1.0 - ssr - s}
	_cache[key] = out
	return out


static func featured_expected(hard: int = V10Catalog.SSR_HARD, share: float = 0.5) -> float:
	# from a fresh counter: SSRs needed for one featured = share·1 + (1-share)·2
	return expected_to_ssr(hard) * (2.0 - share)


static func featured_worst(hard: int = V10Catalog.SSR_HARD, carry: bool = true) -> int:
	var w: = 2 * hard if carry else V10Catalog.SPARK
	return mini(w, V10Catalog.SPARK)


static func rub_range(pulls: float) -> Array:
	return [pulls * V10Catalog.best_rub_per_pull(), pulls * V10Catalog.base_rub_per_pull()]


static func rub_label(pulls: float) -> String:
	var r: = rub_range(pulls)
	var lo: = V10Catalog.fmt_rub(r[0])
	var hi: = V10Catalog.fmt_rub(r[1])
	return "≈ %s" % lo if lo == hi else "≈ %s–%s" % [lo.trim_suffix(" ₽"), hi]


static func pct(x: float, digits: int = 2) -> String:
	var s: = String.num(x * 100.0, digits)
	return s.replace(".", ",") + " %"


# Everything the odds screen needs for one banner. gacha (optional) adds the player's live counters and history.
static func disclosure(bid: String, gacha: V10Gacha = null) -> Dictionary:
	var b: = V10Catalog.banner(bid) if gacha == null else gacha.banner(bid)
	if b.is_empty():
		return {}
	var hard: = int(b.get("hard", V10Catalog.SSR_HARD))
	var cons: = consolidated(V10Catalog.SSR_HARD)
	var cost: = int(b.cost)
	var ppull: = float(cost) / float(V10Catalog.PULL_COST)       # beginner pulls cost 0.8 of a pull
	var d: = {
		"banner": bid, "name": b.name, "kind": b.kind, "cost": cost,
		"rub_per_pull": [V10Catalog.best_rub_per_pull() * ppull, V10Catalog.base_rub_per_pull() * ppull],
		"base": {"SSR": V10Catalog.SSR_BASE, "S": V10Catalog.S_BASE, "A": 1.0 - V10Catalog.SSR_BASE - V10Catalog.S_BASE},
		"consolidated": cons,
		"soft_from": V10Catalog.SOFT_FROM, "soft_step": V10Catalog.SOFT_STEP, "hard": hard, "s_hard": V10Catalog.S_HARD,
		"expected_ssr": expected_to_ssr(V10Catalog.SSR_HARD),
		"soft": [],
		"items": [],
	}
	for p in range(V10Catalog.SOFT_FROM, hard + 1):
		d.soft.append({"pull": p, "rate": V10Gacha.rate_at(p, hard)})
	var pool: Array = V10Catalog.POOL_HEROES if gacha == null else gacha.pool
	var feat: Array = b.get("featured", [])
	var rs: = V10Catalog.ruleset(V10Catalog.RULES_CURRENT)
	var share: = float(rs.featured_share)
	var feat_frac: = 1.0 / (2.0 - share) if bool(rs.carry_guarantee) else share     # long-run featured share of SSRs
	for rar in ["SSR", "S", "A"]:          # highest rarity first, featured SSR on top
		var items: Array = pool.filter(func(it): return it.rar == rar and String(it.get("kind", "hero")) == "hero")
		if gacha != null:
			items = gacha.eligible(rar)
		if b.kind == "limited" and rar == "SSR":
			var off: Array = items.filter(func(it): return not (it.id in feat))
			var tgt: String = String(feat[0]) if gacha == null else gacha.target(bid)
			d.items.append({"id": tgt, "rar": "SSR", "featured": true, "base": V10Catalog.SSR_BASE * share,
				"rate": float(cons.SSR) * feat_frac})
			for it in off:
				d.items.append({"id": it.id, "rar": "SSR", "featured": false,
					"base": V10Catalog.SSR_BASE * (1.0 - share) / float(off.size()),
					"rate": float(cons.SSR) * (1.0 - feat_frac) / float(off.size())})
			continue
		for it in items:
			d.items.append({"id": it.id, "rar": rar, "featured": false,
				"base": float(d.base[rar]) / float(items.size()), "rate": float(cons[rar]) / float(items.size())})
	var worst: int
	match String(b.kind):
		"limited":
			d["featured"] = feat
			d["featured_share"] = share
			d["expected_featured"] = featured_expected(V10Catalog.SSR_HARD, share)
			worst = featured_worst(V10Catalog.SSR_HARD, bool(rs.carry_guarantee))
			d["spark"] = V10Catalog.SPARK
			d["wax_per_candle"] = V10Catalog.WAX_PER_CANDLE
		"newbie":
			d["limit"] = int(b.get("limit", V10Catalog.NEWBIE_PULLS))
			worst = V10Catalog.NEWBIE_HARD
		_:
			worst = V10Catalog.SSR_HARD
	d["worst"] = worst
	d["worst_rub"] = rub_range(float(worst) * ppull)
	if gacha != null:
		var c: = gacha.counter(String(b.counter))
		d["live"] = {"pity_left": gacha.pity_left(bid), "s_left": V10Catalog.S_HARD - int(c.s),
			"guaranteed": bool(c.g), "candles": gacha.candles(bid), "history": gacha.history(bid)}
	d["lines"] = lines(d)
	return d


static func lines(d: Dictionary) -> Array:
	var L: = []
	var rp: Array = d.rub_per_pull
	L.append("Цена крутки: %d кристаллов (≈ %s–%s)" % [d.cost, V10Catalog.fmt_rub(rp[0]).trim_suffix(" ₽"), V10Catalog.fmt_rub(rp[1])])
	L.append("Базовые шансы: SSR %s · S %s · A %s" % [pct(d.base.SSR, 1), pct(d.base.S, 1), pct(d.base.A, 1)])
	L.append("С учётом гаранта: SSR %s · S %s · A %s" % [pct(d.consolidated.SSR), pct(d.consolidated.S), pct(d.consolidated.A)])
	L.append("С %d-й крутки без SSR шанс растёт на %s за крутку; %d-я крутка — SSR всегда" % [d.soft_from, pct(d.soft_step, 0), d.hard])
	L.append("Каждая %d-я крутка без S или SSR — не ниже S" % d.s_hard)
	match String(d.kind):
		"limited":
			L.append("SSR: %s — героиня баннера, иначе следующая SSR — она гарантированно" % pct(d.featured_share, 0))
			L.append("Свеча желаний: %d свечей — любая SSR баннера на выбор. После баннера свечи становятся Воском" % d.spark)
			L.append("В среднем героиня баннера за %d круток, самое большее — за %d (%s)" % [int(round(d.expected_featured)), d.worst,
				rub_label(float(d.worst) * float(d.cost) / float(V10Catalog.PULL_COST))])
		"newbie":
			L.append("%d круток со скидкой 20 %%, SSR гарантированно среди них. Без таймера" % d.limit)
		_:
			L.append("SSR самое большее за %d круток (%s)" % [d.worst, rub_label(float(d.worst))])
	return L
