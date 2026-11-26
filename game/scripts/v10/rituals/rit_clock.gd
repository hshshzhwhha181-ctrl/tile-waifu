class_name V10RitClock
extends RefCounted

# V10RitClock — time for the rituals lane (docs/0.10-spec.md §2.5). The ONE source of time in 0.10 is V10Meta;
# this class forwards to it when the class exists in the project (after the v10-meta merge) and otherwise
# reproduces the same rules, so the rituals work and test before integration:
#   * the player's day starts at 04:00 PHONE time: day_key() at 01:30 is still yesterday;
#   * clock_ok() is false while the phone clock is more than 1 h behind the latest time seen this run.
# Tests pin the time with set_now(unix) and the zone with set_tz(minutes) and never touch the system clock.
#
#   V10RitClock.now_unix() -> int          V10RitClock.day_key(u = -1) -> "YYYY-MM-DD"
#   V10RitClock.day_index(key) -> int      V10RitClock.key_of_index(i) -> String     add_days(key, n)
#   V10RitClock.days_between(a, b) -> int  (b − a in days, keys)        weekday(key) -> 0 = Mon … 6 = Sun
#   V10RitClock.week_key(key) -> Monday key of that week                 md(key) -> [month, day]   year(key)
#   V10RitClock.local_hour(u = -1) -> int  V10RitClock.unix_of(key, hour, minute) -> unix (local time)
#   V10RitClock.clock_ok() -> bool         V10RitClock.fmt_until(key, hour) -> "чт, 2 дек, 04:00"

const DAY_START_H: = 4
const WD_SHORT: = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]
const MONTHS_GEN: = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября",
	"октября", "ноября", "декабря"]
const MONTHS_SHORT: = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
const MONTHS_NOM: = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь",
	"Ноябрь", "Декабрь"]

static var _fixed: = -1
static var _tz: = -100000
static var _max_seen: = 0
static var force_clock: = -1          # tests: 0 = clock moved back, 1 = ok, -1 = real guard
static var use_meta: = true           # tests turn the V10Meta forward off to pin time
static var _meta_script: Script = null
static var _meta_looked: = false


static func set_now(u: int) -> void:
	_fixed = u
	_max_seen = maxi(_max_seen, u)


static func clear() -> void:
	_fixed = -1
	_tz = -100000
	_max_seen = 0
	force_clock = -1


static func set_tz(minutes: int) -> void:
	_tz = minutes


static func _meta() -> Script:
	if not use_meta:
		return null
	if not _meta_looked:
		_meta_looked = true
		for c in ProjectSettings.get_global_class_list():
			if str(c.get("class", "")) == "V10Meta":
				_meta_script = load(str(c.path))
	return _meta_script


static func now_unix() -> int:
	if _fixed >= 0:
		return _fixed
	var m: = _meta()
	if m:
		return int(m.call("now_unix"))
	var u: = int(Time.get_unix_time_from_system()) + _arg_shift()
	_max_seen = maxi(_max_seen, u)
	return u


static var _shift: = -999999

static func _arg_shift() -> int:
	if _shift == -999999:
		_shift = 0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--v10_dayshift="):
				_shift = int(a.substr(15)) * 86400
	return _shift


static func tz_bias_sec() -> int:
	if _tz != -100000:
		return _tz * 60
	# one zone for the whole game: V10Meta's (it can be pinned there) when the class exists
	var m: = _meta()
	if m:
		return int(m.call("tz_bias_min")) * 60
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


static func _local(u: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(u + tz_bias_sec())


static func day_key(u: = -1) -> String:
	if u < 0:
		if _fixed < 0 and _meta():
			return str(_meta().call("day_key"))
		u = now_unix()
	var d: = Time.get_datetime_dict_from_unix_time(u + tz_bias_sec() - DAY_START_H * 3600)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


static func day_index(key: String) -> int:
	if key.length() < 10:
		return -1
	return int(Time.get_unix_time_from_datetime_string(key.substr(0, 10) + "T00:00:00") / 86400)


static func key_of_index(i: int) -> String:
	var d: = Time.get_datetime_dict_from_unix_time(i * 86400)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


static func add_days(key: String, n: int) -> String:
	return key_of_index(day_index(key) + n)


static func days_between(a: String, b: String) -> int:
	if a == "" or b == "":
		return 99999
	return day_index(b) - day_index(a)


# 0 = Monday … 6 = Sunday (1970-01-01 was a Thursday)
static func weekday(key: String) -> int:
	return (day_index(key) + 3) % 7


static func week_key(key: String) -> String:
	return add_days(key, -weekday(key))


static func md(key: String) -> Array:
	return [int(key.substr(5, 2)), int(key.substr(8, 2))]


static func year(key: String) -> int:
	return int(key.substr(0, 4))


static func local_hour(u: = -1) -> int:
	if u < 0:
		u = now_unix()
	return int(_local(u).hour)


# unix of <key> at hh:mm phone time (hours below DAY_START_H belong to the next calendar date of that day)
static func unix_of(key: String, hour: int, minute: = 0) -> int:
	var base: = day_index(key) * 86400
	if hour < DAY_START_H:
		base += 86400
	return base + hour * 3600 + minute * 60 - tz_bias_sec()


static func clock_ok() -> bool:
	if force_clock >= 0:
		return force_clock == 1
	if _fixed < 0 and _meta():
		return bool(_meta().call("clock_ok"))
	return now_unix() >= _max_seen - 3600


# «чт, 2 дек, 04:00»: the moment a day-key deadline ends (deadline keys mean «until the start of that day»).
# UX_RULES §4.1.7: time is shown as a date (weekday, day, month, hour), never as a bare weekday or a countdown.
static func fmt_until(key: String, hour: = DAY_START_H) -> String:
	var m: = md(key)
	return "%s, %d %s, %02d:00" % [WD_SHORT[weekday(key)], int(m[1]), MONTHS_SHORT[clampi(int(m[0]) - 1, 0, 11)], hour]


static func fmt_date(m: int, d: int) -> String:
	return "%d %s" % [d, MONTHS_GEN[clampi(m - 1, 0, 11)]]


static func fmt_date_short(m: int, d: int) -> String:
	return "%d %s" % [d, MONTHS_SHORT[clampi(m - 1, 0, 11)]]
