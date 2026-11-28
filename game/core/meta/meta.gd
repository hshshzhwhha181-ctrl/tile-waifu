class_name V10Meta
extends RefCounted

# V10Meta — the meta core of 0.10 (docs/0.10-spec.md §2.5, M1 Ф1): the ONE source of time and of the day.
# Static (no autoload needed, callable from anywhere); the 30-second poll and the app-resume hook live in the tiny
# node V10MetaTick (meta_tick.gd), which the integrator adds once (autoload or child of main).
#
# TIME
#   V10Meta.now_unix() -> int        system time + srv_offset (1.0: the server sets it) [+ dev/test overrides]
#   V10Meta.day_key() -> String      "YYYY-MM-DD" of the player's day. The day starts at 04:00 PHONE time and the key
#                                    NEVER goes below st.last_key: an update installed between 00:00 and 04:00 (0.9
#                                    already counted the new date at midnight) does not roll the day back, so tasks,
#                                    letters and login are not handed out twice.
#   V10Meta.cal_key(u = now) -> String   calendar day shared by everyone: 04:00 Moscow time (banner phases, pass
#                                    season, Странствие week, duel of the week). Show it with fmt_msk().
#   V10Meta.day_index(key) -> int    days since 1970-01-01 of a key (deterministic rotations: Афиша, seeds)
#   V10Meta.secs_to_rollover() -> int   seconds to the next 04:00 phone time («обновится в 04:00»)
#   V10Meta.legacy_today() -> String    0.9 G.today() (midnight date) — only for the SAVE_VER 8 migration
#   V10Meta.fmt_when(u) -> "чт 18:30"   V10Meta.fmt_msk(u) -> "пн, 22 марта, 04:00 МСК"
# CLOCK GUARD (one for the whole game: no module keeps its own clock_max)
#   V10Meta.clock_ok() -> bool       false while now < max_unix − 1 h (the phone clock was moved back)
#   V10Meta.grant_dated(kind, data) -> bool    a date-bound grant (tea streak, Отдых, daily rewards …). With the clock
#                                    ok it is applied at once through the handler registered by on(kind, cb); with
#                                    the clock moved back it is NOT lost — it waits in st.pending and is applied by
#                                    tick() as soon as the clock is back. Returns true when applied now.
#   V10Meta.on(kind, cb: Callable(data: Dictionary))   handler for grant_dated / pending (modules register at load)
# DAY ROLL
#   V10Meta.tick() -> String         call every 30 s and on resume (V10MetaTick does): raises max_unix, flushes
#                                    pending, and when the day changed since the previous tick of this run emits
#                                    bus().day_rolled(old, new) (the first tick of a launch only sets the baseline).
#                                    Returns the new key or "". The home screen only refreshes badges on day_rolled.
#   V10Meta.bus().day_rolled / clock_changed(ok)
# STATE  S.v10_meta (save_v8.gd registers the defaults):
#   {max_unix, srv_offset, last_key, days_seen, bond:{key, h:{}}, consent:{push, push_asked, asked_unix, bday},
#    notify:{cats:{bday, comeback, salon, feed}, last_unix, queued:{}}, pending:[], scenes_seen:{}}
#   bind(dict) points the module at a state dict (selftests); unbound it uses G.S.v10_meta when the save has it,
#   otherwise a private in-memory dict (pre-integration, nothing is written to the save).
# DEV FLAGS  --v10_now=<unix> (clock starts there and runs), --v10_dayshift=<n> (±n days)

const DAY_START_H: = 4
const MSK_BIAS_MIN: = 180
const CLOCK_TOL: = 3600
const POLL_SECS: = 30.0

const WD_SHORT: = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"]
const MONTHS_GEN: = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября",
	"ноября", "декабря"]


class Bus extends RefCounted:
	signal day_rolled(old_key: String, new_key: String)
	signal clock_changed(ok: bool)


static var _bus: Bus
static var _st: Dictionary = {}
static var _bound: = false
static var _handlers: = {}
static var _fixed_now: = -1
static var _tz_override: = -100000
static var _args_read: = false
static var _arg_base: = -1
static var _arg_t0: = 0
static var _arg_shift: = 0
static var _last_ok: = true
static var _tick_key: = ""


static func bus() -> Bus:
	if _bus == null:
		_bus = Bus.new()
	return _bus


# ── state ──────────────────────────────────────────────────────────────────────────────────────────────────────

static func defaults() -> Dictionary:
	return {
		"max_unix": 0, "srv_offset": 0, "last_key": "", "days_seen": 0,
		"bond": {"key": "", "h": {}},
		"consent": {"push": false, "push_asked": false, "asked_unix": 0, "bday": false},
		"notify": {"cats": {"bday": true, "comeback": false, "salon": true, "feed": true}, "last_unix": 0, "queued": {}},
		"pending": [],
		"scenes_seen": {},
	}


# fills missing keys (nested one level for dict defaults); never overwrites a value the save has
static func ensure(d: Dictionary) -> Dictionary:
	var df: = defaults()
	for k in df:
		if not d.has(k) or typeof(d[k]) != typeof(df[k]):
			if d.has(k) and (typeof(d[k]) == TYPE_FLOAT and typeof(df[k]) == TYPE_INT):
				d[k] = int(d[k])
				continue
			d[k] = df[k]
		elif df[k] is Dictionary:
			for k2 in df[k]:
				if not (d[k] as Dictionary).has(k2):
					d[k][k2] = df[k][k2]
	for k in ["max_unix", "srv_offset", "days_seen"]:
		d[k] = int(d[k])
	d.notify.last_unix = int(d.notify.last_unix)
	d.consent.asked_unix = int(d.consent.asked_unix)
	return d


static func bind(d: Dictionary) -> void:
	_st = ensure(d)
	_bound = true
	_tick_key = ""


static func unbind() -> void:
	_st = {}
	_bound = false
	_tick_key = ""


static func st() -> Dictionary:
	if _bound:
		return _st
	var tree: = Engine.get_main_loop() as SceneTree
	if tree and tree.root.get_node_or_null("G") != null:
		var s = G.S
		if s is Dictionary and s.get("v10_meta") is Dictionary:
			return ensure(s.v10_meta)
	if _st.is_empty():
		_st = ensure({})
	return _st


# ── time ───────────────────────────────────────────────────────────────────────────────────────────────────────

static func _read_args() -> void:
	if _args_read:
		return
	_args_read = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--v10_now="):
			_arg_base = int(a.substr(10))
			_arg_t0 = Time.get_ticks_msec()
		elif a.begins_with("--v10_dayshift="):
			_arg_shift = int(a.substr(15)) * 86400


static func now_unix() -> int:
	_read_args()
	if _fixed_now >= 0:
		return _fixed_now
	var base: int
	if _arg_base >= 0:
		base = _arg_base + int((Time.get_ticks_msec() - _arg_t0) / 1000)
	else:
		base = int(Time.get_unix_time_from_system())
	return base + int(st().get("srv_offset", 0)) + _arg_shift


# tests: freeze the clock at `unix` (no flow); clear_now() returns to the system clock
static func set_now(unix: int) -> void:
	_fixed_now = unix


static func clear_now() -> void:
	_fixed_now = -1


static func set_tz(bias_min: int) -> void:
	_tz_override = bias_min


static func clear_tz() -> void:
	_tz_override = -100000


static func tz_bias_min() -> int:
	if _tz_override > -100000:
		return _tz_override
	return int(Time.get_time_zone_from_system().get("bias", 0))


static func local_unix(u: int) -> int:
	return u + tz_bias_min() * 60


static func key_of(u: int) -> String:
	return Time.get_date_string_from_unix_time(local_unix(u) - DAY_START_H * 3600)


# monotonic: a later raw key is recorded at once (last_key, days_seen), so every reader agrees on the day even
# between two polls; an earlier raw key (clock moved back, update installed at 01:30) is clamped to last_key
static func day_key() -> String:
	var s: = st()
	var k: = key_of(now_unix())
	var last: = str(s.get("last_key", ""))
	if last >= k:
		return last
	s.last_key = k
	s.days_seen = int(s.get("days_seen", 0)) + 1
	return k


static func cal_key(u: int = -1) -> String:
	if u < 0:
		u = now_unix()
	return Time.get_date_string_from_unix_time(u + MSK_BIAS_MIN * 60 - DAY_START_H * 3600)


static func day_index(key: String) -> int:
	if key == "":
		return 0
	return int(floor(Time.get_unix_time_from_datetime_string(key) / 86400.0))


static func secs_to_rollover() -> int:
	var lu: = local_unix(now_unix()) - DAY_START_H * 3600
	return 86400 - posmod(lu, 86400)


static func legacy_today() -> String:
	if _fixed_now >= 0:
		return Time.get_date_string_from_unix_time(local_unix(_fixed_now))
	return Time.get_date_string_from_system()


# local wall-clock dict of a unix time (weekday 0 = Sunday)
static func local_dt(u: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(local_unix(u))


static func fmt_when(u: int) -> String:
	var d: = local_dt(u)
	return "%s %02d:%02d" % [WD_SHORT[int(d.weekday)], int(d.hour), int(d.minute)]


static func fmt_msk(u: int) -> String:
	var d: = Time.get_datetime_dict_from_unix_time(u + MSK_BIAS_MIN * 60)
	return "%s, %d %s, %02d:%02d МСК" % [WD_SHORT[int(d.weekday)], int(d.day), MONTHS_GEN[int(d.month) - 1],
		int(d.hour), int(d.minute)]


# ── clock guard and pending grants ─────────────────────────────────────────────────────────────────────────────

static func clock_ok() -> bool:
	return now_unix() >= int(st().get("max_unix", 0)) - CLOCK_TOL


static func on(kind: String, cb: Callable) -> void:
	_handlers[kind] = cb


static func off(kind: String) -> void:
	_handlers.erase(kind)


static func grant_dated(kind: String, data: Dictionary = {}) -> bool:
	var s: = st()
	if clock_ok() and _handlers.has(kind):
		(_handlers[kind] as Callable).call(data)
		return true
	(s.pending as Array).append({"kind": kind, "data": data, "at": now_unix(), "day": day_key()})
	return false


static func pending_count() -> int:
	return (st().pending as Array).size()


static func flush_pending() -> int:
	if not clock_ok():
		return 0
	var s: = st()
	var keep: = []
	var n: = 0
	for p in s.pending:
		var kind: = str(p.get("kind", ""))
		if _handlers.has(kind):
			var data: Dictionary = p.get("data", {})
			data = data.duplicate()
			data["_day"] = str(p.get("day", ""))
			(_handlers[kind] as Callable).call(data)
			n += 1
		else:
			keep.append(p)
	s.pending = keep
	return n


# ── the poll ───────────────────────────────────────────────────────────────────────────────────────────────────

static func tick() -> String:
	var s: = st()
	var now: = now_unix()
	var ok: = clock_ok()
	if ok != _last_ok:
		_last_ok = ok
		bus().clock_changed.emit(ok)
	if not ok:
		return ""
	if now > int(s.max_unix):
		s.max_unix = now
	flush_pending()
	var k: = day_key()
	var old: = _tick_key
	_tick_key = k
	if old != "" and k != old:
		bus().day_rolled.emit(old, k)
		return k
	return ""


# app resumed from background (main.gd NOTIFICATION_APPLICATION_RESUMED via V10Hooks.app_resumed)
static func on_resumed() -> void:
	tick()


# a small deterministic number for a day (0 … n−1): notification jitter, Афиша rotation
static func day_seed(key: String, salt: = "") -> int:
	return absi(hash(key + "|" + salt))
