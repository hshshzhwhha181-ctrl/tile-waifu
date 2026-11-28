class_name TWClock
extends RefCounted

# TWClock (P12 / WP4): the ONE clock of the new core, injectable and safe against the phone clock being moved back.
# It replaces the `G.time` + wall-clock combination and is the time source of TWState (debounce) and of the day roll.
# Same state keys and same day rules as V10Meta (S.v10_meta {max_unix, srv_offset, last_key, days_seen}), so the shell can
# bind it to S.v10_meta later without a save change; nothing here touches G, the scene tree or the system clock directly
# unless no source was injected.
#
#   TWClock.new()                         system sources (wall clock + monotonic ticks)
#   TWClock.fake(unix) -> TWClock         tests: a clock you drive by hand (advance / set_wall / set_tz)
#   bind(dict)                            point it at the persisted state dict (fills / repairs the 4 keys)
#   raw_now() -> int                      wall clock as the phone says it            (never trust for rewards)
#   now() -> int                          raw_now + srv_offset (1.0: the server sets the offset)
#   safe_now() -> int                     max(now, high-water mark): NEVER goes backwards, even if the clock was set back
#   clock_ok() -> bool                    false while now < max_unix - CLOCK_TOL (the clock was moved back)
#   skew() -> int                         seconds the clock is behind the high-water mark (0 when ok)
#   tick() -> bool                        raise the high-water mark (only while the clock is ok); call every ~30 s and on
#                                         resume; returns clock_ok()
#   day_key() -> String                   "YYYY-MM-DD" of the player's day: starts 04:00 phone time, NEVER below last_key
#   cal_key(u = now) -> String            shared calendar day (04:00 Moscow), key_of(u) the phone day of a unix time
#   secs_to_rollover() -> int, day_index(key) -> int
#   mono_msec() -> int                    monotonic milliseconds (debounce and cool-downs; immune to wall-clock changes)

const DAY_START_H: = 4
const MSK_BIAS_MIN: = 180
const CLOCK_TOL: = 3600

var st: Dictionary = {}
var _wall: Callable
var _ticks: Callable
var _tz: int = -100000
var _fake: Fake = null


# a hand-driven source: advance() moves wall and monotonic time together, set_wall() moves only the wall clock
class Fake extends RefCounted:
	var unix_ms: int = 0
	var msec: int = 0
	var tz_bias_min: int = 0

	func wall() -> int:
		return unix_ms / 1000

	func ticks() -> int:
		return msec

	func advance_ms(ms: int) -> void:
		msec += ms
		unix_ms += ms

	func set_unix(u: int) -> void:
		unix_ms = u * 1000


func _init(wall: Callable = Callable(), ticks: Callable = Callable()) -> void:
	_wall = wall
	_ticks = ticks
	_ensure(st)


static func fake(unix: int = 1_800_000_000, tz_bias_min: int = 0) -> TWClock:
	var f: = Fake.new()
	f.set_unix(unix)
	f.tz_bias_min = tz_bias_min
	var c: = TWClock.new(f.wall, f.ticks)
	c._fake = f
	c._tz = tz_bias_min
	return c


func source() -> Fake:
	return _fake


func advance(secs: float) -> void:
	if _fake:
		_fake.advance_ms(int(round(secs * 1000.0)))


func advance_ms(ms: int) -> void:
	if _fake:
		_fake.advance_ms(ms)


func set_wall(unix: int) -> void:
	if _fake:
		_fake.set_unix(unix)


func set_tz(bias_min: int) -> void:
	_tz = bias_min


# ── state ──────────────────────────────────────────────────────────────────────────────────────────────────────

static func defaults() -> Dictionary:
	return {"max_unix": 0, "srv_offset": 0, "last_key": "", "days_seen": 0}


# fills missing / wrong-typed keys of d IN PLACE and returns it (a save from outside is never trusted)
static func _ensure(d: Dictionary) -> Dictionary:
	var df: = defaults()
	for k in df:
		var v = d.get(k)
		if k == "last_key":
			if not (v is String) or not _valid_key(v):
				d[k] = ""
		else:
			if v is float and is_finite(v) and absf(v) < 4.0e18:
				d[k] = int(v)
			elif not (v is int):
				d[k] = 0
	d.max_unix = maxi(0, int(d.max_unix))
	d.days_seen = maxi(0, int(d.days_seen))
	return d


static func _valid_key(k: String) -> bool:
	if k == "":
		return true
	if k.length() != 10 or k[4] != "-" or k[7] != "-":
		return false
	for i in [0, 1, 2, 3, 5, 6, 8, 9]:
		if not (k[i] >= "0" and k[i] <= "9"):
			return false
	return true


func bind(d: Dictionary) -> void:
	st = _ensure(d)


# ── time ───────────────────────────────────────────────────────────────────────────────────────────────────────

func raw_now() -> int:
	if _wall.is_valid():
		return int(_wall.call())
	return int(Time.get_unix_time_from_system())


func now() -> int:
	return raw_now() + int(st.get("srv_offset", 0))


func safe_now() -> int:
	return maxi(now(), int(st.get("max_unix", 0)))


func mono_msec() -> int:
	if _ticks.is_valid():
		return int(_ticks.call())
	return Time.get_ticks_msec()


func clock_ok() -> bool:
	return now() >= int(st.get("max_unix", 0)) - CLOCK_TOL


func skew() -> int:
	return maxi(0, int(st.get("max_unix", 0)) - now())


func tick() -> bool:
	var n: = now()
	var ok: = n >= int(st.get("max_unix", 0)) - CLOCK_TOL
	if ok and n > int(st.get("max_unix", 0)):
		st["max_unix"] = n
	return ok


# ── days ───────────────────────────────────────────────────────────────────────────────────────────────────────

func tz_bias_min() -> int:
	if _tz > -100000:
		return _tz
	return int(Time.get_time_zone_from_system().get("bias", 0))


func local_unix(u: int) -> int:
	return u + tz_bias_min() * 60


func key_of(u: int) -> String:
	return Time.get_date_string_from_unix_time(local_unix(u) - DAY_START_H * 3600)


# monotonic: a later raw key is recorded at once; an earlier one (clock moved back, update installed at 01:30) is
# clamped to last_key, so tasks / letters / login are never handed out twice by turning the clock back
func day_key() -> String:
	var k: = key_of(now())
	var last: = str(st.get("last_key", ""))
	if last >= k:
		return last
	st["last_key"] = k
	st["days_seen"] = int(st.get("days_seen", 0)) + 1
	return k


func cal_key(u: int = -1) -> String:
	if u < 0:
		u = now()
	return Time.get_date_string_from_unix_time(u + MSK_BIAS_MIN * 60 - DAY_START_H * 3600)


static func day_index(key: String) -> int:
	if key == "":
		return 0
	return int(floor(Time.get_unix_time_from_datetime_string(key) / 86400.0))


func secs_to_rollover() -> int:
	var lu: = local_unix(now()) - DAY_START_H * 3600
	return 86400 - posmod(lu, 86400)
