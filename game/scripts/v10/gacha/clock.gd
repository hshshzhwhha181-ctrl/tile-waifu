class_name V10GClock
extends RefCounted

# V10GClock — the one place the gacha lane reads time from (spec §2.5).
# The integrator points `now_fn` at V10Meta.now_unix (M1) and `clock_ok_fn` at V10Meta.clock_ok; until then the
# system clock is used. Tests set `fixed` to a unix time.
#   V10GClock.now() -> int                 unix seconds
#   V10GClock.msk_day(t) -> int            index of the calendar day that starts at 04:00 MSK (banner phases, shared)
#   V10GClock.day_key(t) -> String         "YYYY-MM-DD" of the day that starts at 04:00 phone time (daily things)
#   V10GClock.until_text(end_t, now) -> String   «до пн, 22 марта, 04:00 МСК», or «ещё 13 ч 42 мин» in the last 48 h
#   V10GClock.msk_date(t) -> Dictionary    {year, month, day, weekday} in Moscow time

const MSK: = 3 * 3600
const RESET_H: = 4
const DAY: = 86400
const COUNTDOWN_MAX: = 48 * 3600
const WD: = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"]
const MON: = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]

static var now_fn: Callable = Callable()
static var fixed: = 0
static var tz_bias: = -1        # phone UTC offset in seconds; -1 = ask the OS


static func now() -> int:
	if fixed > 0:
		return fixed
	if now_fn.is_valid():
		return int(now_fn.call())
	return V10Meta.now_unix()


static func msk_day(t: int) -> int:
	return int(floor(float(t + MSK - RESET_H * 3600) / DAY))


# unix time of 04:00 MSK on the given Moscow calendar date
static func msk_at(y: int, m: int, d: int) -> int:
	var u: = Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": RESET_H, "minute": 0, "second": 0})
	return int(u) - MSK


static func msk_date(t: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(t + MSK)


static func local_bias() -> int:
	if tz_bias >= 0 or tz_bias < -1:
		return tz_bias
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


static func day_key(t: int = -1) -> String:
	if t < 0:
		t = now()
	var d: = Time.get_datetime_dict_from_unix_time(t + local_bias() - RESET_H * 3600)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


static func until_text(end_t: int, t: int = -1) -> String:
	if t < 0:
		t = now()
	var left: = end_t - t
	if left <= 0:
		return "завершено"
	if left <= COUNTDOWN_MAX:
		var h: = left / 3600
		var m: = (left % 3600) / 60
		return "ещё %d ч %02d мин" % [h, m] if h > 0 else "ещё %d мин" % maxi(1, m)
	var d: = msk_date(end_t)
	return "до %s, %d %s, %02d:%02d МСК" % [WD[int(d.weekday)], int(d.day), MON[int(d.month) - 1], int(d.hour), int(d.minute)]


static func date_text(t: int) -> String:
	var d: = msk_date(t)
	return "%s, %d %s" % [WD[int(d.weekday)], int(d.day), MON[int(d.month) - 1]]
