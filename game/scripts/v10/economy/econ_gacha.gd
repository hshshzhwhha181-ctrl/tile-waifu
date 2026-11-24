class_name V10Gacha
extends RefCounted

# V10Gacha — summon rules (ROSTER_20 §1.4, CEO_PLAN №10, IDEAS №2/№3). Decides; V10Econ pays and grants.
#
# Rarity per pull (same numbers as the 0.8 g.gd roll(), so the disclosed odds do not change):
#   SSR 3 %; from pull #46 since the last SSR +6 % per pull; pull #60 is always SSR (#50 on the beginner banner).
#   S 15 %; the 10th pull without S-or-better is at least S. A — the rest.
#   Pity lives in counters: every limited banner shares "limited", the standard banner has "std", beginner "newbie".
# Limited banners: an SSR is the featured one with featured_share (50 %); a lost 50/50 guarantees the next SSR.
#   A «3+3» rerun has two featured SSRs: the player picks the target a won 50/50 gives (set_target).
# «Свеча желаний»: each pull on a limited banner lights a candle; 200 candles → any featured SSR of that banner
#   (spark). When the banner ends its unspent candles turn into «Воск» (close), never to nothing.
# First SSR of choice: three SSR outfits, free, once, final (choose_first).
# Beginner banner: 50 pulls at -20 %, no timer, SSR guaranteed within the 50.
# Pools: a heroine always drops; an outfit only when its heroine is owned (owns callable). Items of one rarity are
#   equally likely (with replacement), which is exactly what the odds screen discloses.
# History: every pull is logged for 90 days (odds screen «история»).
#
# Saved state: {"ctr": {id: {"p","s","g","rules","n"}}, "candles": {bid}, "bpulls": {bid}, "sparks": {bid},
#   "closed": {bid: true}, "target": {bid: id}, "first": "", "newbie": {"n", "ssr"}, "hist": [{t,b,r,i}], "total": n}

var st: Dictionary
var clock: V10Clock
var rng: = RandomNumberGenerator.new()
var pool: Array = []
var owns: Callable = func(_id: String) -> bool: return false
var rules_current: String = V10Catalog.RULES_CURRENT
var rules_announced: int = V10Catalog.RULES_ANNOUNCED
var banners: Array = V10Catalog.BANNERS


func _init(state: Dictionary = {}, clk: V10Clock = null, items: Array = []) -> void:
	st = state
	clock = clk
	rng.randomize()
	pool = V10Catalog.POOL_HEROES.duplicate(true)
	pool.append_array(items)
	ensure()


func ensure() -> void:
	for k in ["ctr", "candles", "bpulls", "sparks", "closed", "target"]:
		if not (st.get(k) is Dictionary):
			st[k] = {}
	for cid in st.ctr.keys():
		var c: Dictionary = st.ctr[cid]
		c["p"] = clampi(int(c.get("p", 0)), 0, V10Catalog.SSR_HARD - 1)
		c["s"] = clampi(int(c.get("s", 0)), 0, V10Catalog.S_HARD - 1)
		c["g"] = bool(c.get("g", false))
		c["rules"] = String(c.get("rules", rules_current))
		c["n"] = int(c.get("n", 0))
	for k in ["candles", "bpulls", "sparks"]:
		for b in st[k].keys():
			st[k][b] = maxi(0, int(st[k][b]))
	st["first"] = String(st.get("first", ""))
	var nb = st.get("newbie", {})
	if not (nb is Dictionary):
		nb = {}
	st["newbie"] = {"n": clampi(int(nb.get("n", 0)), 0, V10Catalog.NEWBIE_PULLS), "ssr": bool(nb.get("ssr", false))}
	if not (st.get("hist") is Array):
		st["hist"] = []
	for h in st.hist:
		h["t"] = int(h.get("t", 0))
	st["total"] = int(st.get("total", 0))


func banner(id: String) -> Dictionary:
	for b in banners:
		if b.id == id:
			return b
	return {}


func counter(cid: String) -> Dictionary:
	if not st.ctr.has(cid):
		st.ctr[cid] = {"p": 0, "s": 0, "g": false, "rules": rules_current, "n": 0}
	return st.ctr[cid]


func _now() -> int:
	return clock.now() if clock != null else 0


func is_open(b: Dictionary) -> bool:
	if b.is_empty():
		return false
	if b.kind == "newbie":
		return newbie_left() > 0
	if bool(st.closed.get(b.id, false)):
		return false
	var t: = _now()
	if int(b.get("start", 0)) > 0 and t < int(b.start):
		return false
	if int(b.get("end", 0)) > 0 and t >= int(b.end):
		return false
	return true


func newbie_left() -> int:
	return V10Catalog.NEWBIE_PULLS - int(st.newbie.n)


func hard_of(b: Dictionary) -> int:
	return int(b.get("hard", V10Catalog.SSR_HARD))


# pulls to the hard SSR guarantee on this banner (for «до гаранта: N»)
func pity_left(bid: String) -> int:
	var b: = banner(bid)
	var c: = counter(String(b.get("counter", "std")))
	var left: = hard_of(b) - int(c.p)
	if b.kind == "newbie" and not bool(st.newbie.ssr):
		left = mini(left, V10Catalog.NEWBIE_HARD - int(st.newbie.n))
	return left


static func rate_at(p: int, hard: int) -> float:
	return 1.0 if p >= hard else V10Catalog.ssr_rate(p)


# one rarity roll on a counter (mirrors g.gd roll())
func roll_rar(c: Dictionary, hard: int = V10Catalog.SSR_HARD) -> String:
	c.p = int(c.p) + 1
	c.s = int(c.s) + 1
	c.n = int(c.n) + 1
	var rate: = rate_at(int(c.p), hard)
	var r: = rng.randf()
	if r < rate:
		c.p = 0
		c.s = 0
		_maybe_new_rules(c)
		return "SSR"
	if int(c.s) >= V10Catalog.S_HARD or r < rate + V10Catalog.S_BASE:
		c.s = 0
		return "S"
	return "A"


# a counter that just reset adopts the current rules once their notice period is over
func _maybe_new_rules(c: Dictionary) -> void:
	if String(c.rules) == rules_current:
		return
	if _now() >= rules_announced + V10Catalog.RULE_NOTICE_DAYS * V10Catalog.DAY:
		c.rules = rules_current


func eligible(rar: String, exclude: Array = []) -> Array:
	var out: = []
	for it in pool:
		if it.rar != rar or it.id in exclude:
			continue
		if String(it.get("kind", "hero")) == "outfit" and not owns.call(String(it.get("hero", ""))):
			continue
		out.append(it)
	return out


func _pick(items: Array) -> Dictionary:
	if items.is_empty():
		return {}
	return items[rng.randi() % items.size()]


func _item(id: String) -> Dictionary:
	for it in pool:
		if it.id == id:
			return it
	return {"id": id, "rar": "SSR", "kind": "hero"}


func set_target(bid: String, id: String) -> bool:
	var b: = banner(bid)
	if b.is_empty() or not (id in b.featured):
		return false
	st.target[bid] = id
	return true


func target(bid: String) -> String:
	var b: = banner(bid)
	if b.is_empty() or b.featured.is_empty():
		return ""
	var t: = String(st.target.get(bid, ""))
	return t if t in b.featured else String(b.featured[0])


# n pulls, decided only (no payment, no grant). Returns [] when the banner is closed or n is over the beginner limit.
func pull(bid: String, n: int) -> Array:
	var b: = banner(bid)
	if not is_open(b) or n <= 0:
		return []
	if b.kind == "newbie" and n > newbie_left():
		return []
	var c: = counter(String(b.counter))
	var hard: = hard_of(b)
	var res: = []
	for i in n:
		var p_before: = int(c.p)
		var rar: = roll_rar(c, hard)
		var r: = {"rar": rar, "pity": p_before + 1, "banner": bid, "featured": false}
		if b.kind == "newbie":
			st.newbie.n = int(st.newbie.n) + 1
			if rar == "SSR":
				st.newbie.ssr = true
		var it: Dictionary
		if rar == "SSR" and b.kind == "limited":
			var rs: = V10Catalog.ruleset(String(c.rules))
			var win: = bool(c.g) or rng.randf() < float(rs.featured_share)
			r["won"] = win and not bool(c.g)
			r["guaranteed"] = bool(c.g)
			if win:
				it = _item(target(bid))
				r.featured = true
				c.g = false
			else:
				it = _pick(eligible("SSR", b.featured))
				c.g = bool(rs.carry_guarantee)
		else:
			it = _pick(eligible(rar))
		r["id"] = String(it.get("id", ""))
		r["kind"] = String(it.get("kind", "hero"))
		if b.kind == "limited":
			st.candles[bid] = int(st.candles.get(bid, 0)) + 1
		st.bpulls[bid] = int(st.bpulls.get(bid, 0)) + 1
		st.total = int(st.total) + 1
		_hist(bid, rar, r.id)
		res.append(r)
	return res


func candles(bid: String) -> int:
	return int(st.candles.get(bid, 0))


func can_spark(bid: String) -> bool:
	var b: = banner(bid)
	return b.get("kind", "") == "limited" and is_open(b) and candles(bid) >= V10Catalog.SPARK


# exchange 200 candles for a featured SSR of the banner; the pity counter is not touched
func spark(bid: String, pick: String) -> Dictionary:
	var b: = banner(bid)
	if not can_spark(bid) or not (pick in b.featured):
		return {}
	st.candles[bid] = candles(bid) - V10Catalog.SPARK
	st.sparks[bid] = int(st.sparks.get(bid, 0)) + 1
	_hist(bid, "SSR", pick, true)
	var it: = _item(pick)
	return {"rar": "SSR", "id": pick, "kind": String(it.get("kind", "hero")), "banner": bid, "featured": true, "spark": true}


# banner over: candles → wax. Idempotent. Returns the wax to credit.
func close(bid: String) -> int:
	if bool(st.closed.get(bid, false)):
		return 0
	st.closed[bid] = true
	var c: = candles(bid)
	st.candles[bid] = 0
	return c * V10Catalog.WAX_PER_CANDLE


# limited banners whose end time passed and that are not closed yet
func ended() -> Array:
	var t: = _now()
	var out: = []
	for b in banners:
		if b.kind == "limited" and int(b.get("end", 0)) > 0 and t >= int(b.end) and not bool(st.closed.get(b.id, false)):
			out.append(b.id)
	return out


func first_options() -> Array:
	if String(st.first) != "":
		return []
	return V10Catalog.FIRST_SSR_CHOICES.filter(func(id): return not owns.call(id))


func choose_first(id: String) -> bool:
	if String(st.first) != "" or not (id in V10Catalog.FIRST_SSR_CHOICES) or not (id in first_options()):
		return false
	st.first = id
	_hist("first", "SSR", id, true)
	return true


func _hist(bid: String, rar: String, id: String, special: bool = false) -> void:
	var t: = _now()
	var e: = {"t": t, "b": bid, "r": rar, "i": id}
	if special:
		e["x"] = true
	st.hist.append(e)
	prune_history()


func prune_history() -> void:
	var t: = _now()
	var lim: = t - V10Catalog.HISTORY_DAYS * V10Catalog.DAY
	var k: = 0
	while k < st.hist.size() and (int(st.hist[k].t) < lim or st.hist.size() - k > V10Catalog.HISTORY_MAX):
		k += 1
	if k > 0:
		st.hist = st.hist.slice(k)


func history(bid: String = "") -> Array:
	prune_history()
	if bid == "":
		return st.hist.duplicate()
	return st.hist.filter(func(e): return e.b == bid)


func audit() -> Array:
	var bad: = []
	for bid in st.candles:
		var maxc: = int(st.bpulls.get(bid, 0)) - V10Catalog.SPARK * int(st.sparks.get(bid, 0))
		if candles(bid) > maxc:
			bad.append("candles on %s (%d) exceed pulls %d - sparks" % [bid, candles(bid), int(st.bpulls.get(bid, 0))])
	for cid in st.ctr:
		var c: Dictionary = st.ctr[cid]
		if int(c.p) >= V10Catalog.SSR_HARD or int(c.s) >= V10Catalog.S_HARD or int(c.p) < 0 or int(c.s) < 0:
			bad.append("counter %s out of range" % cid)
		if not V10Catalog.RULESETS.has(String(c.rules)):
			bad.append("counter %s has unknown rules %s" % [cid, c.rules])
	if int(st.newbie.n) > V10Catalog.NEWBIE_PULLS:
		bad.append("beginner banner over its limit")
	var sum: = 0
	for bid in st.bpulls:
		sum += int(st.bpulls[bid])
	if sum > int(st.total):
		bad.append("banner pulls %d exceed total %d" % [sum, int(st.total)])
	return bad
