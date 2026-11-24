class_name V10Clock
extends RefCounted

# V10Clock — the one time source of the economy, with anti-cheat basics until the server clock arrives (CEO_PLAN §4:
# server time in 1.0). now() never goes backwards and never trusts a wall-clock jump inside a session.
#
#   • Server time  sync_server(unix) → from then on now() = server time advanced by the monotonic clock.
#   • In a session the monotonic clock (Time.get_ticks_msec) is the truth: a wall clock that drifts more than
#     JUMP_TOL from it (player moved the clock while the game runs) is ignored and counted in st.jumps.
#   • Across sessions only the wall clock exists. now() is clamped to the high-water mark st.hw (latest time ever
#     seen): rolling the clock back freezes time until real time passes the mark (st.rollbacks counts it). So a
#     forward-jump-then-back trick pays back every second it borrowed; the most one can gain is what a regen cap
#     already bounds (one full energy bar).
#   • day_key()/day_index() use Moscow time for everyone (calendar resets are the same for all players).
#
# Saved state (dict, JSON-safe): {"hw": int, "rollbacks": int, "jumps": int, "in_rb": bool}
# Tests: set_manual(wall_unix, mono_msec) replaces both clocks.

const JUMP_TOL: = 120          # s of wall/monotonic disagreement tolerated inside one session
const RB_TOL: = 5              # s of backwards wall clock ignored silently (NTP corrections)

var st: Dictionary
var _manual: = false
var _m_wall: = 0
var _m_mono: = 0
var _srv: = false
var _srv_base: = 0.0           # server unix at _srv_mono
var _srv_mono: = 0
var _anchored: = false
var _a_wall: = 0
var _a_mono: = 0
var _skew: = 0


func _init(state: Dictionary = {}) -> void:
	st = state
	ensure()


func ensure() -> void:
	st["hw"] = int(st.get("hw", 0))
	st["rollbacks"] = int(st.get("rollbacks", 0))
	st["jumps"] = int(st.get("jumps", 0))
	st["in_rb"] = bool(st.get("in_rb", false))


func set_manual(wall_unix: int, mono_msec: int = -1) -> void:
	_manual = true
	_m_wall = wall_unix
	_m_mono = mono_msec if mono_msec >= 0 else _m_mono


# test helper: a new app session (monotonic clock restarts, anchors drop)
func new_session(wall_unix: int) -> void:
	_anchored = false
	_skew = 0
	_srv = false
	set_manual(wall_unix, 0)


func wall() -> int:
	return _m_wall if _manual else int(Time.get_unix_time_from_system())


func mono_ms() -> int:
	return _m_mono if _manual else Time.get_ticks_msec()


func trusted() -> bool:
	return _srv


func sync_server(server_unix: int) -> void:
	_srv = true
	_srv_base = float(server_unix)
	_srv_mono = mono_ms()


func now() -> int:
	var t: int
	if _srv:
		t = int(_srv_base + float(mono_ms() - _srv_mono) / 1000.0)
		# the server is the truth, even below the mark (a cheated clock may have pushed the mark forward)
		st.hw = t
		st.in_rb = false
		return t
	var w: = wall()
	var m: = mono_ms()
	if not _anchored:
		_anchored = true
		_a_wall = w
		_a_mono = m
	# _skew: how far the wall clock was moved away from the monotonic clock in this session; ignored for good.
	# A jump is counted once, when the skew changes by more than JUMP_TOL.
	var expect: = _a_wall + (m - _a_mono) / 1000
	var d: = w - expect
	if absi(d - _skew) > JUMP_TOL:
		st.jumps = int(st.jumps) + 1
		_skew = d
	w -= _skew
	if w < int(st.hw) - RB_TOL:
		if not bool(st.in_rb):
			st.rollbacks = int(st.rollbacks) + 1
			st.in_rb = true
		return int(st.hw)
	st.in_rb = false
	st.hw = maxi(int(st.hw), w)
	return int(st.hw)


static func day_index(t: int) -> int:
	return int(floor(float(t + V10Catalog.TZ_OFFSET) / float(V10Catalog.DAY)))


static func day_key(t: int) -> String:
	return Time.get_date_string_from_unix_time(t + V10Catalog.TZ_OFFSET)


static func day_start(t: int) -> int:
	return day_index(t) * V10Catalog.DAY - V10Catalog.TZ_OFFSET


func today() -> int:
	return day_index(now())
