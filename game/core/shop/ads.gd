class_name V10Ads
extends RefCounted

# V10Ads — rewarded ads only (spec 0.10 Л8). No interstitials, no «▶ ролик» on the loss screen.
#   Slots: «gift» (Подарок дня ×2), «chest» (coins of the win chest ×2, ≤ 3/day), «event» (reserve).
#   ≤ 6 per day in total. Month-card owners get the reward WITHOUT a video (the provider is never called).
#   0.10: only the stub — a 2 s overlay «ТЕСТ · реклама» in test builds. The store build has no provider (slots say
#   unavailable). Yandex Mobile Ads + ads/PD consent before SDK init + age category — 1.0 (ads_yandex: not here).
#
# State (S.v10_shop.ads): {"day": -1, "n": 0, "slots": {slot: n}}
# Provider contract: show(slot: String, done: Callable(ok: bool)) ; available() -> bool

signal shown(slot: String, via: String)     # via: "video" | "month"

var st: Dictionary
var provider: Object = null                 # V10AdsStub in test builds, null in store builds
var month_free: Callable                    # () -> bool, V10Shop.ad_free
var day_fn: Callable                        # () -> int, the economy day index (Moscow 04:00 rule is V10Meta's job)
var calls: = 0                              # provider calls (selftest)


func _init(state: Dictionary, today: Callable, month: Callable = Callable()) -> void:
	st = state
	day_fn = today
	month_free = month
	ensure()


func ensure() -> void:
	if not (st.get("ads") is Dictionary):
		st["ads"] = {}
	var a: Dictionary = st.ads
	a["day"] = int(a.get("day", -1))
	a["n"] = int(a.get("n", 0))
	if not (a.get("slots") is Dictionary):
		a["slots"] = {}


func _roll() -> Dictionary:
	var a: Dictionary = st.ads
	var d: = int(day_fn.call())
	if int(a.day) != d:
		a.day = d
		a.n = 0
		a.slots = {}
	return a


func left_today() -> int:
	return maxi(0, V10ShopData.ADS_DAY_MAX - int(_roll().n))


func slot_left(slot: String) -> int:
	var a: = _roll()
	var cap: = int(V10ShopData.AD_SLOTS.get(slot, 0))
	return maxi(0, mini(cap - int(a.slots.get(slot, 0)), left_today()))


func month_skip() -> bool:
	return month_free.is_valid() and bool(month_free.call())


func can(slot: String) -> Dictionary:
	if not V10ShopData.AD_SLOTS.has(slot):
		return {"ok": false, "reason": "slot"}
	if slot_left(slot) <= 0:
		return {"ok": false, "reason": "limit"}
	if month_skip():
		return {"ok": true, "via": "month"}
	if provider == null or not provider.call("available"):
		return {"ok": false, "reason": "no_provider"}
	return {"ok": true, "via": "video"}


# done(ok: bool) is called once
func show(slot: String, done: Callable) -> void:
	var c: = can(slot)
	if not c.ok:
		done.call(false)
		return
	var via: = String(c.via)
	if via == "month":
		_count(slot)
		shown.emit(slot, via)
		done.call(true)
		return
	calls += 1
	provider.call("show", slot, func(ok: bool):
		if ok:
			_count(slot)
			shown.emit(slot, via)
		done.call(ok))


func _count(slot: String) -> void:
	var a: = _roll()
	a.n = int(a.n) + 1
	a.slots[slot] = int(a.slots.get(slot, 0)) + 1
