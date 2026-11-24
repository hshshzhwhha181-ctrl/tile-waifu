class_name V10Age
extends RefCounted

# V10Age — neutral age screen data + the 16–17 spend layer (spec 0.10 Л2, UX Г-2, HANDOFF §1).
#
#   Neutral: the player picks a birth YEAR on a wheel. Nothing is pre-selected and there is no «Вам есть 18? Да».
#   The confirm button reads «Мне есть 18 · войти» only after an adult year is picked, otherwise «Продолжить».
#   band(): "adult" (18+), "teen" (16–17), "child" (<16). min_age: 18 in the RuStore build (HANDOFF §1: 18+),
#   16 in a 16+ flavour. Below min_age → «Эта версия игры для 18+» and no entry.
#   Teen caps: ≤ 1500 ₽ per rolling 30 days and ≤ 499 ₽ per purchase (V10Spend keeps the 3000 ₽ cap of unverified
#   18+ and the own limits; this layer only adds the teen caps, checked BEFORE econ.shop.buy).
#   bold_ok(): the 18+ coquettish rig/legwear delta (LEGWEAR.md, rig v2 gestures) — adult band AND 18+ build only.
#
# State (in S.v10_shop.age): {"year": 0 (unset) | 1900.., "set_t": unix, "band": ""}

const YEAR_MIN: = 1940


static func ensure(st: Dictionary) -> Dictionary:
	if not (st.get("age") is Dictionary):
		st["age"] = {}
	var a: Dictionary = st.age
	a["year"] = int(a.get("year", 0))
	a["set_t"] = int(a.get("set_t", 0))
	a["band"] = String(a.get("band", ""))
	return a


static func min_age() -> int:
	if OS.has_feature("tw_16plus"):
		return V10ShopData.MIN_AGE_GP
	return V10ShopData.MIN_AGE_STORE


static func year_now(now_unix: int) -> int:
	return int(Time.get_datetime_dict_from_unix_time(now_unix + 3 * 3600).year)


# conservative: the birthday may still be ahead this year, so age = year_now - year - 1 … year_now - year;
# we use the LOWER bound only for the child/teen edge (never lets a 17-year-old through as 18)
static func age_of(year: int, now_unix: int) -> int:
	if year <= 0:
		return -1
	return year_now(now_unix) - year - 1


static func band_of(year: int, now_unix: int) -> String:
	var a: = age_of(year, now_unix)
	if a < 0:
		return ""
	if a >= 18:
		return "adult"
	if a >= 16:
		return "teen"
	return "child"


static func allowed(year: int, now_unix: int) -> bool:
	var a: = age_of(year, now_unix)
	return a >= min_age()


static func set_year(st: Dictionary, year: int, now_unix: int) -> String:
	var a: = ensure(st)
	a.year = year
	a.set_t = now_unix
	a.band = band_of(year, now_unix)
	return String(a.band)


static func is_set(st: Dictionary) -> bool:
	return int(ensure(st).year) > 0


static func band(st: Dictionary) -> String:
	return String(ensure(st).band)


static func bold_ok(st: Dictionary) -> bool:
	return band(st) == "adult" and min_age() >= 18


static func confirm_text(year: int, now_unix: int) -> String:
	if year <= 0:
		return "Выбери год рождения"
	return "Мне есть 18 · войти" if band_of(year, now_unix) == "adult" else "Продолжить"


# extra teen caps; spent30 = V10Spend.spent_30d()
static func check(st: Dictionary, rub: int, spent30: int) -> Dictionary:
	var b: = band(st)
	if b == "child" or b == "":
		return {"ok": false, "reason": "age_unset" if b == "" else "age_child"}
	if b == "teen":
		if rub > V10ShopData.TEEN_ONE_RUB:
			return {"ok": false, "reason": "teen_one", "room": V10ShopData.TEEN_ONE_RUB}
		if spent30 + rub > V10ShopData.TEEN_MONTH_RUB:
			return {"ok": false, "reason": "teen_month", "room": maxi(0, V10ShopData.TEEN_MONTH_RUB - spent30)}
	return {"ok": true}


# the cap the confirm sheet shows («Потрачено за 30 дней: 528 ₽ из 3 000»); -1 = no cap
static func cap_30d(st: Dictionary, spend: V10Spend) -> int:
	var caps: = []
	if band(st) == "teen":
		caps.append(V10ShopData.TEEN_MONTH_RUB)
	if spend != null:
		if not bool(spend.st.age_ok):
			caps.append(V10Catalog.AGE_LIMIT_RUB_30D)
		if spend.limit() > 0:
			caps.append(spend.limit())
	return -1 if caps.is_empty() else int(caps.min())


static func years(now_unix: int) -> Array:
	var out: = []
	for y in range(year_now(now_unix), YEAR_MIN - 1, -1):
		out.append(y)
	return out
