class_name V10Shop
extends RefCounted

# V10Shop — catalog availability, the real-money purchase flow, receipts, refunds, month card (CEO_PLAN №11, №13–16,
# §2, §4, §6). Grants go through V10Econ (grant_fn / revoke_fn), money through a V10PaymentProvider.
#
# Purchase flow (state machine per order):
#   buy(sku) ── checks: listed, once/window, server wallet for consumables, provider, spending protection, no open
#   │           order for the same SKU ──► order "created" ──► provider.purchase(product, order_id)
#   ├─ "pending"   ► order "pending" (bank / SBP confirmation); a later result finishes it
#   ├─ "cancelled" / "failed" ► order closed, nothing granted, nothing counted
#   └─ "paid"      ► verify ► deliver ONCE per purchase_id (receipt "delivered") ► provider.confirm ► "confirmed"
#   reconcile() at start: paid-but-unconfirmed purchases are delivered (if not yet) and confirmed; restorable
#     entitlements (month card days, pass, outfits) come back on a fresh install without re-granting currency
#   refund(purchase_id): receipt "refunded", currency clawed back (debt if spent), entitlements revoked, the order
#     stops counting toward spending limits. Hook: provider.refund_notice → refund().
#
# No fake timers: the only limited offers are beginner sets listed 14 days from install, shown with their end DATE
# (offer.until), no countdown popup; seasons and banners are calendar dates for everyone.
#
# Saved state: {"orders": {oid: {oid, sku, rub, t, st}}, "receipts": [..], "bought": {sku: n}, "install": unix,
#   "seq": n, "month": {"end": day, "last": day}}
# Receipt: {oid, pid, sku, rub, t, prov, st: delivered|confirmed|refunded|restored, grant, first, token}

signal delivered(receipt: Dictionary)
signal failed(order: Dictionary, reason: String)
signal pending(order: Dictionary)
signal refunded(receipt: Dictionary)

var st: Dictionary
var clock: V10Clock
var provider: V10PaymentProvider
var spend: V10Spend
var pass_: V10Pass
var caps: = {"server_wallet": false}
var grant_fn: Callable           # (grant: Dictionary, src: String) -> void
var revoke_fn: Callable          # (grant: Dictionary, src: String) -> void
var extra_skus: Array = []       # outfit SKUs added by the integrator (V10Catalog.outfit_sku)


func _init(state: Dictionary, clk: V10Clock, sp: V10Spend, ps: V10Pass) -> void:
	st = state
	clock = clk
	spend = sp
	pass_ = ps
	ensure()


func ensure() -> void:
	for k in ["orders", "bought"]:
		if not (st.get(k) is Dictionary):
			st[k] = {}
	if not (st.get("receipts") is Array):
		st["receipts"] = []
	for r in st.receipts:
		r["t"] = int(r.get("t", 0))
		r["rub"] = int(r.get("rub", 0))
	for k in st.bought.keys():
		st.bought[k] = int(st.bought[k])
	st["install"] = int(st.get("install", 0))
	if int(st.install) <= 0 and clock != null:
		st.install = clock.now()
	st["seq"] = int(st.get("seq", 0))
	var m = st.get("month", {})
	if not (m is Dictionary):
		m = {}
	st["month"] = {"end": int(m.get("end", -1)), "last": int(m.get("last", -1))}


func set_provider(p: V10PaymentProvider) -> void:
	if provider != null:
		if provider.purchase_result.is_connected(_on_result):
			provider.purchase_result.disconnect(_on_result)
		if provider.refund_notice.is_connected(refund):
			provider.refund_notice.disconnect(refund)
	provider = p
	if p != null:
		p.purchase_result.connect(_on_result)
		p.refund_notice.connect(refund)


func sku(id: String) -> Dictionary:
	var s: = V10Catalog.sku(id)
	if not s.is_empty():
		return s
	for e in extra_skus:
		if e.id == id:
			return e
	return {}


func all_skus() -> Array:
	var a: Array = V10Catalog.SKUS.duplicate()
	a.append_array(extra_skus)
	return a


# ---------------------------------------------------------------- availability
func is_first(s: Dictionary) -> bool:
	return s.get("kind", "") == "currency" and int(st.bought.get(s.id, 0)) == 0


func available(id: String) -> Dictionary:
	var s: = sku(id)
	if s.is_empty():
		return {"ok": false, "reason": "unknown"}
	if bool(s.get("once", false)) and int(st.bought.get(id, 0)) > 0:
		return {"ok": false, "reason": "owned"}
	var win: = int(s.get("window_days", 0))
	if win > 0 and clock.now() >= int(st.install) + win * V10Catalog.DAY:
		return {"ok": false, "reason": "expired"}
	if bool(s.get("requires_server", false)) and not bool(caps.get("server_wallet", false)):
		return {"ok": false, "reason": "server"}
	match String(s.kind):
		"month":
			if month_days_left() + V10Catalog.MONTH_DAYS > V10Catalog.MONTH_STACK_MAX:
				return {"ok": false, "reason": "month_max"}
		"pass":
			if pass_ == null or not pass_.active():
				return {"ok": false, "reason": "no_season"}
			if bool(pass_.st.prem):
				return {"ok": false, "reason": "owned"}
	return {"ok": true}


func can_buy(id: String) -> Dictionary:
	var a: = available(id)
	if not a.ok:
		return a
	if provider == null or not provider.is_available():
		return {"ok": false, "reason": "no_provider"}
	for oid in st.orders:
		var o: Dictionary = st.orders[oid]
		# an order the store never answered (app killed mid-purchase, abandoned SBP) must not lock the SKU forever;
		# a late "paid" for it is still delivered by _on_result / reconcile
		if o.sku == id and String(o.st) in ["created", "pending"] \
				and clock.now() - int(o.get("t", 0)) < V10Catalog.ORDER_STALE_SEC:
			return {"ok": false, "reason": "in_progress"}
	var c: = spend.check(int(sku(id).rub))
	if not c.ok:
		return c
	return {"ok": true}


# what the shop screen shows: every SKU with price, «≈ N ₽ за крутку», first bonus, end date, availability
func offers() -> Array:
	var out: = []
	for s in all_skus():
		var a: = available(s.id)
		if not a.ok and String(a.reason) in ["owned", "expired", "unknown"] and s.kind != "pass":
			continue
		var first: = is_first(s)
		var o: Dictionary = s.duplicate(true)
		o["available"] = a.ok
		o["reason"] = String(a.get("reason", ""))
		o["price"] = V10Catalog.fmt_rub(float(s.rub))
		o["first"] = first
		o["grant_now"] = V10Catalog.sku_grant(s, first)
		var pv: = V10Catalog.pull_value(s, first)
		o["pulls"] = pv
		o["per_pull"] = V10Sku.per_wish(float(s.rub) / pv) if pv > 0.0 else ""
		var win: = int(s.get("window_days", 0))
		o["until"] = int(st.install) + win * V10Catalog.DAY if win > 0 else 0
		out.append(o)
	return out


# ---------------------------------------------------------------- purchase
func buy(id: String) -> Dictionary:
	var c: = can_buy(id)
	if not c.ok:
		return c
	var s: = sku(id)
	st.seq = int(st.seq) + 1
	var oid: = "o%x-%d" % [int(st.install), int(st.seq)]
	var o: = {"oid": oid, "sku": id, "rub": int(s.rub), "t": clock.now(), "st": "created"}
	st.orders[oid] = o
	provider.purchase(id, oid)
	return {"ok": true, "oid": oid, "st": String(st.orders[oid].st)}


func receipt(pid: String) -> Dictionary:
	for r in st.receipts:
		if r.pid == pid:
			return r
	return {}


func _on_result(res: Dictionary) -> void:
	var oid: = String(res.get("order_id", ""))
	var o: Dictionary = st.orders.get(oid, {})
	var status: = String(res.get("status", "failed"))
	match status:
		"paid":
			if not provider.verify(res):
				if not o.is_empty():
					o.st = "failed"
					failed.emit(o, "verify")
				return
			if o.is_empty():
				# a paid result for an order this save never created (reinstall, second device): deliver anyway
				o = {"oid": oid if oid != "" else "ext-" + String(res.purchase_id), "sku": String(res.product_id),
					"rub": int(sku(String(res.product_id)).get("rub", 0)), "t": int(res.get("t", clock.now())), "st": "created"}
				st.orders[o.oid] = o
			_deliver(o, res)
		"pending":
			if not o.is_empty() and o.st == "created":
				o.st = "pending"
				pending.emit(o)
		_:
			if not o.is_empty() and String(o.st) in ["created", "pending"]:
				o.st = status
				failed.emit(o, String(res.get("error", status)))


func _deliver(o: Dictionary, res: Dictionary) -> void:
	var pid: = String(res.purchase_id)
	var have: = receipt(pid)
	if not have.is_empty():
		# duplicate callback: never deliver twice, just make sure the store knows we have it
		o.st = "delivered"
		if have.st == "delivered" and provider.confirm(pid):
			have.st = "confirmed"
		return
	var s: = sku(String(o.sku))
	if s.is_empty():
		o.st = "failed"
		failed.emit(o, "unknown_sku")
		return
	var first: = is_first(s)
	var g: = V10Catalog.sku_grant(s, first)
	match String(s.kind):
		"month":
			_month_extend()
		"pass":
			pass_.unlock(bool(s.get("deluxe", false)), String(o.oid))
	if not g.is_empty():
		grant_fn.call(g, "buy:" + String(s.id))
	st.bought[s.id] = int(st.bought.get(s.id, 0)) + 1
	spend.record(int(s.rub), String(o.oid))
	var r: = {"oid": o.oid, "pid": pid, "sku": s.id, "rub": int(s.rub), "t": clock.now(), "prov": provider.id(),
		"st": "delivered", "grant": g, "first": first, "token": String(res.get("token", ""))}
	st.receipts.append(r)
	o.st = "delivered"
	if provider.confirm(pid):
		r.st = "confirmed"
	delivered.emit(r)


# call on start (and after the provider reconnects)
func reconcile() -> Array:
	var done: = []
	if provider == null or not provider.is_available():
		return done
	for p in provider.get_purchases():
		var pid: = String(p.get("purchase_id", ""))
		var have: = receipt(pid)
		var s: = sku(String(p.get("product_id", "")))
		if String(p.status) == "paid":
			if have.is_empty():
				var poid: = String(p.get("order_id", ""))
				var o: Dictionary = st.orders.get(poid, {}) if poid != "" else {}
				if o.is_empty():
					o = {"oid": poid if poid != "" else "ext-" + pid, "sku": String(p.product_id), "rub": int(s.get("rub", 0)),
						"t": int(p.get("t", 0)), "st": "created"}
					st.orders[o.oid] = o
				_deliver(o, {"purchase_id": pid, "product_id": p.product_id, "order_id": o.oid, "status": "paid"})
				done.append(pid)
			elif have.st == "delivered" and provider.confirm(pid):
				have.st = "confirmed"
				done.append(pid)
		elif String(p.status) == "confirmed" and have.is_empty() and bool(s.get("restorable", false)):
			if _restore(s, p):
				done.append(pid)
	return done


# entitlements only: a restored month card gets its remaining days, a pass its premium track (if the season is the
# same), an outfit the outfit. Currency inside these SKUs is not granted again.
func _restore(s: Dictionary, p: Dictionary) -> bool:
	var t: = int(p.get("t", 0))
	var ok: = false
	match String(s.kind):
		"month":
			var end: = V10Clock.day_index(t) + V10Catalog.MONTH_DAYS - 1
			if end >= clock.today():
				st.month.end = maxi(int(st.month.end), end)
				ok = true
		"pass":
			if pass_ != null and pass_.active() and t >= int(pass_.st.start):
				pass_.unlock(bool(s.get("deluxe", false)), String(p.get("order_id", "")))
				ok = true
		"outfit":
			var items: Array = s.get("grant", {}).get("items", [])
			if not items.is_empty():
				grant_fn.call({"items": items}, "restore:" + String(s.id))
				ok = true
	if ok:
		st.receipts.append({"oid": String(p.get("order_id", "")), "pid": String(p.purchase_id), "sku": s.id, "rub": int(s.rub),
			"t": t, "prov": provider.id(), "st": "restored", "grant": {}, "first": false, "token": ""})
		st.bought[s.id] = maxi(1, int(st.bought.get(s.id, 0)))
	return ok


# ---------------------------------------------------------------- refunds
func refund(pid: String) -> bool:
	var r: = receipt(pid)
	if r.is_empty() or r.st == "refunded":
		return false
	var s: = sku(String(r.sku))
	var back: Dictionary = (r.grant as Dictionary).duplicate(true)
	match String(s.get("kind", "")):
		"month":
			st.month.end = int(st.month.end) - V10Catalog.MONTH_DAYS
			if int(st.month.end) < clock.today():
				st.month.end = mini(int(st.month.end), clock.today() - 1)
		"pass":
			if pass_ != null and String(pass_.st.oid) == String(r.oid):
				for g in pass_.revoke():
					V10Catalog._add_into(back, g)
	back.erase("tea")      # tea is not clawed back
	if not back.is_empty():
		revoke_fn.call(back, "refund:" + String(r.sku))
	r.st = "refunded"
	spend.mark_refunded(String(r.oid))
	if st.orders.has(r.oid):
		st.orders[r.oid].st = "refunded"
	refunded.emit(r)
	return true


# ---------------------------------------------------------------- month card «Лунный абонемент»
func month_days_left() -> int:
	return maxi(0, int(st.month.end) - clock.today() + 1)


func _month_extend() -> void:
	var start: = maxi(clock.today(), int(st.month.end) + 1)
	st.month.end = start + V10Catalog.MONTH_DAYS - 1


func month_can_claim() -> bool:
	return month_days_left() > 0 and int(st.month.last) < clock.today()


# today's 90 crystals ({} if nothing to claim). Unclaimed days are not paid later (shown on the card).
func month_claim() -> Dictionary:
	if not month_can_claim():
		return {}
	st.month.last = clock.today()
	var g: Dictionary = V10Catalog.MONTH_DAILY.duplicate()
	grant_fn.call(g, "month_daily")
	return g


# month-card owners get rewarded-ad rewards without watching the ad
func ad_free() -> bool:
	return month_days_left() > 0


func spent_rub_total() -> int:
	var s: = 0
	for r in st.receipts:
		if r.st != "refunded" and r.st != "restored":
			s += int(r.rub)
	return s


func audit() -> Array:
	var bad: = []
	var seen: = {}
	for r in st.receipts:
		if seen.has(r.pid):
			bad.append("receipt %s delivered twice" % r.pid)
		seen[r.pid] = true
	for s in all_skus():
		if bool(s.get("once", false)) and int(st.bought.get(s.id, 0)) > 1:
			bad.append("once-only %s bought %d times" % [s.id, int(st.bought[s.id])])
	if month_days_left() > V10Catalog.MONTH_STACK_MAX:
		bad.append("month card over %d days" % V10Catalog.MONTH_STACK_MAX)
	return bad
