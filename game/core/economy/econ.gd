class_name V10Econ
extends RefCounted

# V10Econ — the economy core in one object: clock, wallet, energy, gacha, pass, spending protection, shop.
# Pure logic, no nodes, no UI, no disk: the owner (G) keeps econ.st inside its save and calls save_dict()/load.
#
#   var e := V10Econ.new(state_dict_or_empty, provider_or_null, extra_pool_items)
#   e.summon(banner_id, n)        pay (wishes → crystals → moonstone) + pull + grant; {ok, res | reason}
#   e.spark(banner_id, pick)      200 candles → featured SSR
#   e.choose_first(id)            first SSR of choice (free, once)
#   e.tick()                      close ended banners (candles → wax); call on start/resume and on the shop screen
#   e.grant(g, src) / e.revoke(g, src)   apply a reward/refund dict {currency: n, "tea": n, "items": [ids]}
#   e.audit() -> Array            plausibility problems (wallet invariant, candles vs pulls, ranges, receipts, seal)
#   e.save_dict(key) / V10Econ.verify(d, key)      HMAC-SHA256 seal over the canonical JSON of the state
#   V10Econ.from_legacy(G.S, now)  econ state from a 0.8/0.9 save (save v7), see README «Миграция»
#
# Signals for the integrator: item_granted(id, src) → G.give(id); item_revoked(id, src) → refund policy;
#   changed → refresh HUD.
# owns: Callable(id) -> bool  (set to G.owns for the real game; default: this state's own inventory)

signal changed
signal item_granted(id: String, src: String)
signal item_revoked(id: String, src: String)

const VER: = 1
const LOCAL_KEY: = "tw-econ-v1:5e1f0c2a9b"    # deterrent only; the server issues the real key (IDEAS 5.9)

var st: Dictionary
var clock: V10Clock
var wallet: V10Wallet
var energy: V10Energy
var gacha: V10Gacha
var pass_: V10Pass
var spend: V10Spend
var shop: V10Shop
var owns: Callable
var season_outfit: = ""         # what pass tier 30 «@season_outfit» resolves to this season
var pass_xp_per_pull: = 0


# t0 > 0: a manual clock starting at t0 (selftests, replays); 0 = real clock
func _init(state: Dictionary = {}, provider: V10PaymentProvider = null, items: Array = [], t0: int = 0) -> void:
	st = state
	st["ver"] = int(st.get("ver", VER))
	for k in ["clock", "wallet", "energy", "gacha", "pass", "spend", "shop", "inv", "const", "flags"]:
		if not (st.get(k) is Dictionary):
			st[k] = {}
	owns = _owns_local
	clock = V10Clock.new(st.clock)
	if t0 > 0:
		clock.set_manual(t0, 0)
	wallet = V10Wallet.new(st.wallet, clock)
	energy = V10Energy.new(st.energy, clock)
	gacha = V10Gacha.new(st.gacha, clock, items)
	gacha.owns = _owns_proxy
	pass_ = V10Pass.new(st.pass, clock)
	spend = V10Spend.new(st.spend, clock)
	shop = V10Shop.new(st.shop, clock, spend, pass_)
	shop.grant_fn = grant
	shop.revoke_fn = revoke
	shop.set_provider(provider)
	for k in st.const.keys():
		st.const[k] = clampi(int(st.const[k]), 0, V10Catalog.CONST_MAX)
	wallet.changed.connect(_on_wallet)


# method callables (not lambdas) so the economy holds no reference cycle to itself
func _owns_local(id: String) -> bool:
	return st.inv.has(id)


func _owns_proxy(id: String) -> bool:
	return owns.call(id)


func _on_wallet(_c: String) -> void:
	changed.emit()


# ---------------------------------------------------------------- grants
func grant(g: Dictionary, src: String = "") -> void:
	for k in g:
		if k == "items":
			for id in g[k]:
				var iid: = String(id)
				if iid == "@season_outfit":
					iid = season_outfit
				if iid == "":
					continue
				st.inv[iid] = true
				item_granted.emit(iid, src)
		elif k == "tea":
			energy.add(int(g[k]))
		else:
			wallet.add(String(k), int(g[k]), src)
	changed.emit()


func revoke(g: Dictionary, src: String = "refund") -> void:
	for k in g:
		if k == "items":
			for id in g[k]:
				var iid: = season_outfit if String(id) == "@season_outfit" else String(id)
				if iid != "":
					item_revoked.emit(iid, src)
		elif k != "tea":
			wallet.revoke(String(k), int(g[k]), src)
	changed.emit()


# ---------------------------------------------------------------- summons
func pull_cost(bid: String, n: int) -> Dictionary:
	var b: = gacha.banner(bid)
	if b.is_empty():
		return {}
	var wishes: = 0 if b.kind == "newbie" else mini(wallet.balance("wish"), n)
	return {"wish": wishes, "premium": (n - wishes) * int(b.cost)}


func can_summon(bid: String, n: int) -> Dictionary:
	var b: = gacha.banner(bid)
	if b.is_empty():
		return {"ok": false, "reason": "unknown"}
	if n <= 0:
		return {"ok": false, "reason": "bad_count"}
	if not gacha.is_open(b):
		return {"ok": false, "reason": "closed"}
	if b.kind == "newbie" and n > gacha.newbie_left():
		return {"ok": false, "reason": "newbie_limit", "left": gacha.newbie_left()}
	var c: = pull_cost(bid, n)
	if wallet.premium() < int(c.premium):
		return {"ok": false, "reason": "no_crystals", "need": int(c.premium) - wallet.premium()}
	return {"ok": true, "cost": c}


func summon(bid: String, n: int) -> Dictionary:
	var ok: = can_summon(bid, n)
	if not ok.ok:
		return ok
	var c: Dictionary = ok.cost
	if int(c.wish) > 0:
		wallet.spend("wish", int(c.wish), "pull:" + bid)
	var paid: = wallet.spend_premium(int(c.premium), "pull:" + bid)
	var res: = gacha.pull(bid, n)
	for r in res:
		_apply(r, "pull:" + bid)
	pass_.add_xp(pass_xp_per_pull * n)
	changed.emit()
	return {"ok": true, "res": res, "paid": paid, "wish": int(c.wish)}


# gifted pulls (login calendar, return ladder): no payment, same rules
func summon_free(bid: String, n: int) -> Dictionary:
	if gacha.banner(bid).get("kind", "") == "newbie":
		return {"ok": false, "reason": "closed"}     # gifted pulls never eat the 50 discounted beginner pulls
	var res: = gacha.pull(bid, n)
	if res.is_empty():
		return {"ok": false, "reason": "closed"}
	for r in res:
		_apply(r, "gift:" + bid)
	changed.emit()
	return {"ok": true, "res": res}


func _apply(r: Dictionary, src: String) -> void:
	var id: = String(r.get("id", ""))
	if id == "":
		r["new"] = false
		return
	if not owns.call(id):
		r["new"] = true
		grant({"items": [id]}, src)
		return
	r["new"] = false
	var rar: = String(r.rar)
	if String(r.get("kind", "hero")) == "hero" and int(st.const.get(id, 0)) < V10Catalog.CONST_MAX:
		st.const[id] = int(st.const.get(id, 0)) + 1
		r["star"] = int(st.const[id])
	else:
		var pet: = int(V10Catalog.DUP_PETALS.get(rar, 5))
		wallet.add("petal", pet, src)
		r["petals"] = pet


func spark(bid: String, pick: String) -> Dictionary:
	var r: = gacha.spark(bid, pick)
	if r.is_empty():
		return {"ok": false, "reason": "no_spark"}
	_apply(r, "spark:" + bid)
	changed.emit()
	return {"ok": true, "res": [r]}


func choose_first(id: String) -> bool:
	if not gacha.choose_first(id):
		return false
	grant({"items": [id]}, "first_ssr")
	return true


# a Constellation star bought with petals (guaranteed path, CEO_PLAN №12)
func buy_star(hero: String) -> bool:
	if not owns.call(hero) or int(st.const.get(hero, 0)) >= V10Catalog.CONST_MAX:
		return false
	if not wallet.spend("petal", V10Catalog.PETALS_PER_STAR, "star:" + hero):
		return false
	st.const[hero] = int(st.const.get(hero, 0)) + 1
	changed.emit()
	return true


func tick() -> Dictionary:
	var wax: = 0
	for bid in gacha.ended():
		var w: = gacha.close(bid)
		if w > 0:
			wallet.add("wax", w, "candles:" + bid)
			wax += w
	energy.tick()
	return {"wax": wax}


# ---------------------------------------------------------------- integrity
func audit() -> Array:
	var bad: = []
	bad.append_array(wallet.audit())
	bad.append_array(energy.audit())
	bad.append_array(gacha.audit())
	bad.append_array(shop.audit())
	if bool(st.flags.get("tampered", false)):
		bad.append("seal mismatch on load")
	if int(st.clock.get("rollbacks", 0)) > 0:
		bad.append("clock rolled back %d time(s)" % int(st.clock.rollbacks))
	return bad


static func canon(v: Variant) -> Variant:
	# JSON turns ints into floats; the seal must not care
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			return int(f) if f == floorf(f) and absf(f) < 9.0e15 else f
		TYPE_DICTIONARY:
			var d: = {}
			for k in v:
				if String(k) != "seal":
					d[String(k)] = canon(v[k])
			return d
		TYPE_ARRAY:
			var a: = []
			for x in v:
				a.append(canon(x))
			return a
	return v


static func seal_of(d: Dictionary, key: String = LOCAL_KEY) -> String:
	var txt: = JSON.stringify(canon(d), "", true)
	var h: = HMACContext.new()
	h.start(HashingContext.HASH_SHA256, key.to_utf8_buffer())
	h.update(txt.to_utf8_buffer())
	return h.finish().hex_encode()


func save_dict(key: String = LOCAL_KEY) -> Dictionary:
	st.seal = seal_of(st, key)
	return st


static func verify(d: Dictionary, key: String = LOCAL_KEY) -> bool:
	return d.has("seal") and String(d.seal) == seal_of(d, key)


# load from a parsed save: checks the seal, flags (never wipes) a tampered state
static func load_dict(d: Dictionary, provider: V10PaymentProvider = null, items: Array = [], key: String = LOCAL_KEY,
		t0: int = 0) -> V10Econ:
	var ok: = verify(d, key) if d.has("seal") else true
	var e: = V10Econ.new(d, provider, items, t0)
	if not ok:
		e.st.flags["tampered"] = true
	return e


# ---------------------------------------------------------------- migration from the 0.8/0.9 save (G.S, ver 7)
static func from_legacy(S: Dictionary, now: int) -> Dictionary:
	var e: = {"ver": VER, "clock": {"hw": now}, "flags": {"migrated_from": int(S.get("ver", 0))}}
	# gems from the fake 0.8 shop and from rewards stay FREE crystals; paid moonstone starts at 0 for everyone
	var gems: = maxi(0, int(S.get("gems", 0)))
	var coins: = maxi(0, int(S.get("coins", 0)))
	e.wallet = {"bal": {"crystal": gems, "coin": coins}, "earned": {"crystal": gems, "coin": coins}}
	e.energy = {"v": V10Catalog.TEA_CAP, "t": now}
	# the legacy single pity counter carried the event banners → the shared limited counter keeps it (and its rules)
	var pity: = clampi(int(S.get("pity", 0)), 0, V10Catalog.SSR_HARD - 1)
	var spity: = clampi(int(S.get("sr_pity", 0)), 0, V10Catalog.S_HARD - 1)
	var used: = 20 - clampi(int(S.get("newbie_left", 20)), 0, 20)
	e.gacha = {
		"ctr": {"limited": {"p": pity, "s": spity, "g": bool(S.get("guar", false)), "rules": "r0", "n": int(S.get("pulls", 0))}},
		"newbie": {"n": used, "ssr": bool(S.get("newbie_ssr", false))},
		"total": int(S.get("pulls", 0)),
	}
	# pass: progress and premium flag carry over into a legacy season that ends with the first 1.0 season
	var lp = S.get("pass", {})
	if lp is Dictionary:
		var cl: = clampi(int(lp.get("claimed", 0)), 0, V10Catalog.PASS_TIERS)
		var mask: = (1 << cl) - 1
		e.pass = {"season": "legacy", "start": 0, "end": 0, "xp": int(lp.get("xp", 0)), "prem": bool(lp.get("owned", false)),
			"cf": mask, "cp": mask if bool(lp.get("owned", false)) else 0}
	# month card «until» date (YYYY-MM-DD) → last day index
	var mc = S.get("month_card", {})
	var mend: = -1
	if mc is Dictionary and String(mc.get("until", "")) != "":
		mend = V10Clock.day_index(int(Time.get_unix_time_from_datetime_string(String(mc.until) + "T12:00:00")) - V10Catalog.TZ_OFFSET)
	e.shop = {"install": int(S.get("profile", {}).get("created", now)) if S.get("profile") is Dictionary else now,
		"month": {"end": mend, "last": -1}}
	# owned outfits/heroines: the integrator keeps G.S.owned as the truth (owns = G.owns); nothing copied here
	return e
