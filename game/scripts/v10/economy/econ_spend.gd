class_name V10Spend
extends RefCounted

# V10Spend — spending protection (CEO_PLAN №16 «обязательно в 1.0», §5; IDEAS 5.13). Checked before every purchase.
#
#   • Until 18+ is verified (VK ID / Яндекс ID birth date, set_age_verified) at most 3000 ₽ per rolling 30 days.
#   • Optional own limit per rolling 30 days. Lowering applies at once, raising (or removing) after 24 h.
#   • Voluntary pause of all purchases until a date («добровольная пауза трат»).
#   • Optional «остыть 24 часа» after a purchase of 1490 ₽ or more.
#   • spent_30d() for the «потрачено за 30 дней» screen; only the player sees it, never shared.
#   Refunded purchases stop counting.
#
# Saved state: {"hist": [{t, rub, oid, ref}], "age_ok", "limit", "limit_next", "limit_at", "pause_until",
#   "cool_on", "cool_until"}

var st: Dictionary
var clock: V10Clock


func _init(state: Dictionary = {}, clk: V10Clock = null) -> void:
	st = state
	clock = clk
	ensure()


func ensure() -> void:
	if not (st.get("hist") is Array):
		st["hist"] = []
	for h in st.hist:
		h["t"] = int(h.get("t", 0))
		h["rub"] = int(h.get("rub", 0))
		h["ref"] = bool(h.get("ref", false))
	st["age_ok"] = bool(st.get("age_ok", false))
	st["limit"] = maxi(0, int(st.get("limit", 0)))
	st["limit_next"] = int(st.get("limit_next", -1))
	st["limit_at"] = int(st.get("limit_at", 0))
	st["pause_until"] = int(st.get("pause_until", 0))
	st["cool_on"] = bool(st.get("cool_on", false))
	st["cool_until"] = int(st.get("cool_until", 0))


func _apply_pending() -> void:
	if int(st.limit_next) >= 0 and clock.now() >= int(st.limit_at):
		st.limit = int(st.limit_next)
		st.limit_next = -1


func spent_30d() -> int:
	var t0: = clock.now() - 30 * V10Catalog.DAY
	var s: = 0
	for h in st.hist:
		if int(h.t) > t0 and not bool(h.ref):
			s += int(h.rub)
	return s


func limit() -> int:
	_apply_pending()
	return int(st.limit)


# 0 = no own limit
func set_limit(rub: int) -> void:
	_apply_pending()
	rub = maxi(0, rub)
	var cur: = int(st.limit)
	var lower: = rub > 0 and (cur == 0 or rub < cur)
	if lower:
		st.limit = rub
		st.limit_next = -1
	elif rub != cur:
		st.limit_next = rub
		st.limit_at = clock.now() + V10Catalog.LIMIT_RAISE_DELAY


func set_age_verified(ok: bool) -> void:
	st.age_ok = ok


func pause(days: int) -> void:
	st.pause_until = maxi(int(st.pause_until), clock.now() + days * V10Catalog.DAY)


func set_cooldown(on: bool) -> void:
	st.cool_on = on


# how many rubles may still be spent now (-1 = no cap)
func room() -> int:
	var caps: = []
	if not bool(st.age_ok):
		caps.append(V10Catalog.AGE_LIMIT_RUB_30D)
	if limit() > 0:
		caps.append(limit())
	if caps.is_empty():
		return -1
	return maxi(0, int(caps.min()) - spent_30d())


func check(rub: int) -> Dictionary:
	var now: = clock.now()
	if now < int(st.pause_until):
		return {"ok": false, "reason": "paused", "until": int(st.pause_until)}
	if now < int(st.cool_until):
		return {"ok": false, "reason": "cooldown", "until": int(st.cool_until)}
	var spent: = spent_30d()
	if not bool(st.age_ok) and spent + rub > V10Catalog.AGE_LIMIT_RUB_30D:
		return {"ok": false, "reason": "age_limit", "room": maxi(0, V10Catalog.AGE_LIMIT_RUB_30D - spent)}
	if limit() > 0 and spent + rub > limit():
		return {"ok": false, "reason": "own_limit", "room": maxi(0, limit() - spent)}
	return {"ok": true}


func record(rub: int, oid: String) -> void:
	st.hist.append({"t": clock.now(), "rub": rub, "oid": oid, "ref": false})
	if bool(st.cool_on) and rub >= V10Catalog.BIG_PURCHASE_RUB:
		st.cool_until = clock.now() + V10Catalog.COOL_SEC
	# keep a year for the monthly summary
	var t0: = clock.now() - 366 * V10Catalog.DAY
	while not st.hist.is_empty() and int(st.hist[0].t) < t0:
		st.hist.pop_front()


func mark_refunded(oid: String) -> void:
	for h in st.hist:
		if h.oid == oid:
			h.ref = true
