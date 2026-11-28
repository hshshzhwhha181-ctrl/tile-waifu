class_name V10Energy
extends RefCounted

# V10Energy — «Чай», energy for farm domains and events ONLY (CEO_PLAN №6/№8, «Решения владельцу» 3: no lives on the
# Path, no continue for coins; affection and story never depend on tea).
#
#   cap 160, +1 every 6 min (real clock through V10Clock: rollbacks freeze, in-session jumps are ignored)
#   «Термос» (thermos): regen that would overflow a full bar is stored 1:1 up to 1200; take it out any time
#   refill: fixed 60 crystals → +60 tea, at most 2 a day (never escalates), plus 1 a day for a rewarded ad
#     (month-card owners get the ad refill without watching — V10Shop.ad_free())
#   grants (rewards, packs) may overfill the cap up to TEA_HARD_MAX; regen stops while at/over the cap
#
# Saved state: {"v": tea, "t": regen anchor unix, "th": thermos, "day": day index, "ref": refills today, "ad": ad today}

signal changed

var st: Dictionary
var clock: V10Clock


func _init(state: Dictionary = {}, clk: V10Clock = null) -> void:
	st = state
	clock = clk
	ensure()


func ensure() -> void:
	var fresh: = not st.has("v")
	st["v"] = clampi(int(st.get("v", V10Catalog.TEA_CAP)), 0, V10Catalog.TEA_HARD_MAX)
	st["t"] = int(st.get("t", 0))
	st["th"] = clampi(int(st.get("th", 0)), 0, V10Catalog.THERMOS_CAP)
	st["day"] = int(st.get("day", 0))
	st["ref"] = maxi(0, int(st.get("ref", 0)))
	st["ad"] = maxi(0, int(st.get("ad", 0)))
	if fresh and clock != null:
		st.t = clock.now()


func _day() -> void:
	var d: = clock.today()
	if d != int(st.day):
		# only forward: a rolled-back clock cannot reset the daily refill counters (clock.now never goes back)
		if d > int(st.day):
			st.ref = 0
			st.ad = 0
		st.day = maxi(d, int(st.day))


# regen up to now; returns tea gained
func tick() -> int:
	var now: = clock.now()
	if int(st.t) <= 0:
		st.t = now
	if now <= int(st.t):
		return 0
	var R: = V10Catalog.TEA_REGEN_SEC
	var n: = (now - int(st.t)) / R
	if n <= 0:
		return 0
	st.t = int(st.t) + n * R
	var room: = maxi(0, V10Catalog.TEA_CAP - int(st.v))
	var add: = mini(n, room)
	st.v = int(st.v) + add
	var over: = n - add
	if over > 0:
		st.th = mini(V10Catalog.THERMOS_CAP, int(st.th) + over)
	if add > 0 or over > 0:
		changed.emit()
	return add


func value() -> int:
	tick()
	return int(st.v)


func thermos() -> int:
	tick()
	return int(st.th)


# seconds to the next +1 (0 when at/over the cap)
func next_in() -> int:
	tick()
	if int(st.v) >= V10Catalog.TEA_CAP:
		return 0
	return maxi(0, int(st.t) + V10Catalog.TEA_REGEN_SEC - clock.now())


func full_in() -> int:
	tick()
	var miss: = V10Catalog.TEA_CAP - int(st.v)
	if miss <= 0:
		return 0
	return next_in() + (miss - 1) * V10Catalog.TEA_REGEN_SEC


func can_spend(n: int) -> bool:
	return n >= 0 and value() >= n


func spend(n: int) -> bool:
	tick()
	if n < 0 or int(st.v) < n:
		return false
	var was_full: = int(st.v) >= V10Catalog.TEA_CAP
	st.v = int(st.v) - n
	if was_full and int(st.v) < V10Catalog.TEA_CAP:
		# the bar was full, so no regen was running: the 6-minute timer starts now
		st.t = clock.now()
	changed.emit()
	return true


func add(n: int) -> int:
	tick()
	if n <= 0:
		return 0
	var was_below: = int(st.v) < V10Catalog.TEA_CAP
	var nv: = mini(V10Catalog.TEA_HARD_MAX, int(st.v) + n)
	var got: = nv - int(st.v)
	st.v = nv
	if was_below and nv >= V10Catalog.TEA_CAP:
		st.t = clock.now()
	changed.emit()
	return got


func take_thermos(n: int = -1) -> int:
	tick()
	var k: = int(st.th) if n < 0 else mini(n, int(st.th))
	k = mini(k, V10Catalog.TEA_HARD_MAX - int(st.v))
	if k <= 0:
		return 0
	st.th = int(st.th) - k
	add(k)
	return k


func refills_left() -> int:
	_day()
	return maxi(0, V10Catalog.TEA_REFILLS_DAY - int(st.ref))


func ad_refills_left() -> int:
	_day()
	return maxi(0, V10Catalog.TEA_AD_REFILLS_DAY - int(st.ad))


# pay a fixed 60 crystals (crystals then moonstone) for +60 tea
func refill(wallet: V10Wallet) -> Dictionary:
	if refills_left() <= 0:
		return {"ok": false, "reason": "daily_limit"}
	tick()
	if int(st.v) + V10Catalog.TEA_REFILL > V10Catalog.TEA_HARD_MAX:
		return {"ok": false, "reason": "full"}
	if wallet.premium() < V10Catalog.TEA_REFILL_COST:
		return {"ok": false, "reason": "no_crystals"}
	var paid: = wallet.spend_premium(V10Catalog.TEA_REFILL_COST, "tea_refill")
	st.ref = int(st.ref) + 1
	var got: = add(V10Catalog.TEA_REFILL)
	return {"ok": true, "tea": got, "paid": paid}


# call after a completed rewarded ad (or directly for month-card owners)
func ad_refill() -> Dictionary:
	if ad_refills_left() <= 0:
		return {"ok": false, "reason": "daily_limit"}
	tick()
	if int(st.v) + V10Catalog.TEA_REFILL > V10Catalog.TEA_HARD_MAX:
		return {"ok": false, "reason": "full"}
	st.ad = int(st.ad) + 1
	return {"ok": true, "tea": add(V10Catalog.TEA_REFILL)}


func audit() -> Array:
	var bad: = []
	if int(st.v) < 0 or int(st.v) > V10Catalog.TEA_HARD_MAX:
		bad.append("tea out of range %d" % int(st.v))
	if int(st.th) < 0 or int(st.th) > V10Catalog.THERMOS_CAP:
		bad.append("thermos out of range %d" % int(st.th))
	if int(st.ref) > V10Catalog.TEA_REFILLS_DAY or int(st.ad) > V10Catalog.TEA_AD_REFILLS_DAY:
		bad.append("tea refills over the daily limit")
	return bad
