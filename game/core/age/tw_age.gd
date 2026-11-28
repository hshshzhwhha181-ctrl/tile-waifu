class_name TWAge
extends RefCounted

# TWAge (P22 / GDD §5.9, §11.3 / MONETIZATION_PLAN §8.6, Прил. R C14-C15):
# Pure core age gate, 18+ declaration, 30-day minor lockout, Full-tier toggle guard, and account-link gate.
# Deterministic: uses injected TWClock and stores state in a plain Dictionary (or TWState.data["age_gate"]).
# Privacy (C15): full DOB (month/day) is NEVER persisted — only birth_year and age_declared_ok.

const MODULE_ID: String = "age_gate"
const MODULE_VER: int = 1
const STATE_KEY: String = "age_gate"

const MIN_AGE: int = 18
const MIN_YEAR: int = 1900
const MSK_OFFSET_SEC: int = TWClock.MSK_BIAS_MIN * 60
const MINOR_BLOCK_DAYS: int = 30
const MINOR_BLOCK_SEC: int = MINOR_BLOCK_DAYS * 86400

const STATE_UNSET: String = "UNSET"
const STATE_BLOCKED_MINOR: String = "BLOCKED_MINOR"
const STATE_AGE_DECLARED: String = "AGE_DECLARED"

const LINK_PROVIDERS: = ["vk", "yandex", "email"]
const DAYS_IN_MONTH: = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

var _state: TWState = null
var _store: Dictionary = {}
var clock: TWClock = null


func _init(p_clock: TWClock = null, p_state: TWState = null, store_override: Dictionary = {}) -> void:
	_state = p_state
	clock = p_clock if p_clock != null else (p_state.clock if p_state != null else TWClock.new())
	if _state != null:
		_ensure_in(_state.data)
	else:
		_store = store_override
		_ensure_in(_store)


func _root() -> Dictionary:
	var target: Dictionary = _state.data if _state != null else _store
	return _ensure_in(target)


static func _ensure_in(data: Dictionary) -> Dictionary:
	if not (data.get(STATE_KEY) is Dictionary):
		data[STATE_KEY] = {}
	var d: Dictionary = data[STATE_KEY]
	if not (d.get("state") is String) or str(d.get("state", "")) == "":
		d["state"] = STATE_UNSET
	d["age_declared_ok"] = bool(d.get("age_declared_ok", false))
	d["birth_year"] = int(d.get("birth_year", 0))
	d["declared_at"] = int(d.get("declared_at", 0))
	d["blocked_until"] = int(d.get("blocked_until", 0))
	d["full_tier_enabled"] = bool(d.get("full_tier_enabled", false))
	d["linked_provider"] = str(d.get("linked_provider", ""))
	d["linked_hash"] = str(d.get("linked_hash", ""))
	d["linked_at"] = int(d.get("linked_at", 0))
	d["mod_ver"] = MODULE_VER
	return d


func _touch_state(urgent: bool = true) -> void:
	if _state != null:
		_state.set_module_ver(MODULE_ID, MODULE_VER)
		_state.mark_dirty(urgent)


# ---- pure calendar helpers (Moscow Time, UTC+3) -----------------------------------------------------------

static func is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)


static func days_in_month(year: int, month: int) -> int:
	if month < 1 or month > 12:
		return 0
	if month == 2 and is_leap_year(year):
		return 29
	return int(DAYS_IN_MONTH[month])


static func msk_date_of(unix_ts: int) -> Dictionary:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix_ts + MSK_OFFSET_SEC)
	return {
		"year": int(dt.get("year", 1970)),
		"month": int(dt.get("month", 1)),
		"day": int(dt.get("day", 1)),
		"hour": int(dt.get("hour", 0)),
		"minute": int(dt.get("minute", 0)),
		"second": int(dt.get("second", 0)),
	}


static func validate_dob(year: int, month: int, day: int, now_unix: int) -> Dictionary:
	var today: Dictionary = msk_date_of(now_unix)
	var ty: int = int(today["year"])
	var tm: int = int(today["month"])
	var td: int = int(today["day"])
	if year < MIN_YEAR:
		return {"ok": false, "code": "DENY_DOB_RANGE", "age": -1}
	if month < 1 or month > 12:
		return {"ok": false, "code": "DENY_DOB_INVALID", "age": -1}
	var dim: int = days_in_month(year, month)
	if day < 1 or day > dim:
		return {"ok": false, "code": "DENY_DOB_INVALID", "age": -1}
	if year > ty or (year == ty and (month > tm or (month == tm and day > td))):
		return {"ok": false, "code": "DENY_DOB_FUTURE", "age": -1}
	var age: int = ty - year
	if tm < month or (tm == month and td < day):
		age -= 1
	return {"ok": true, "code": "OK", "age": age, "today": today}


static func compute_age_msk(year: int, month: int, day: int, now_unix: int) -> int:
	var v: Dictionary = validate_dob(year, month, day, now_unix)
	if not bool(v.get("ok", false)):
		return -1
	return int(v.get("age", -1))


# ---- state machine ----------------------------------------------------------------------------------------

func current_state() -> String:
	var d: Dictionary = _root()
	return str(d["state"])


func is_minor_blocked() -> bool:
	var d: Dictionary = _root()
	return str(d["state"]) == STATE_BLOCKED_MINOR and clock.now() < int(d["blocked_until"])


func blocked_until() -> int:
	return int(_root()["blocked_until"])


func is_adult() -> bool:
	var d: Dictionary = _root()
	return str(d["state"]) == STATE_AGE_DECLARED and bool(d["age_declared_ok"]) and not is_minor_blocked()


func needs_gate() -> bool:
	return not is_adult()


func birth_year() -> int:
	return int(_root()["birth_year"])


func submit_dob(year: int, month: int, day: int) -> Dictionary:
	var d: Dictionary = _root()
	var now: int = clock.now()
	if str(d["state"]) == STATE_BLOCKED_MINOR and now < int(d["blocked_until"]):
		return {
			"ok": false,
			"code": "DENY_MINOR_LOCKED",
			"state": STATE_BLOCKED_MINOR,
			"blocked_until": int(d["blocked_until"]),
		}
	var v: Dictionary = validate_dob(year, month, day, now)
	if not bool(v.get("ok", false)):
		return {
			"ok": false,
			"code": str(v["code"]),
			"state": str(d["state"]),
			"age": -1,
		}
	var age: int = int(v["age"])
	if age < MIN_AGE:
		d["state"] = STATE_BLOCKED_MINOR
		d["age_declared_ok"] = false
		d["birth_year"] = year
		d["declared_at"] = now
		d["blocked_until"] = now + MINOR_BLOCK_SEC
		d["full_tier_enabled"] = false
		_touch_state(true)
		return {
			"ok": false,
			"code": "DENY_MINOR",
			"state": STATE_BLOCKED_MINOR,
			"age": age,
			"blocked_until": int(d["blocked_until"]),
		}
	d["state"] = STATE_AGE_DECLARED
	d["age_declared_ok"] = true
	d["birth_year"] = year
	d["declared_at"] = now
	d["blocked_until"] = 0
	# Full tier stays OFF by default until the player explicitly toggles it on
	d["full_tier_enabled"] = false
	_touch_state(true)
	return {
		"ok": true,
		"code": "OK",
		"state": STATE_AGE_DECLARED,
		"age": age,
	}


func clear_minor_block_by_support() -> void:
	var d: Dictionary = _root()
	if str(d["state"]) == STATE_BLOCKED_MINOR:
		d["state"] = STATE_UNSET
		d["blocked_until"] = 0
		d["age_declared_ok"] = false
		d["full_tier_enabled"] = false
		_touch_state(true)


func revoke_age() -> void:
	var d: Dictionary = _root()
	d["state"] = STATE_UNSET
	d["age_declared_ok"] = false
	d["full_tier_enabled"] = false
	d["declared_at"] = 0
	_touch_state(true)


# ---- Full visual tier toggle (C14: blocked ONLY in BLOCKED_MINOR / unset / revoked age) -------------------

func is_full_tier_enabled() -> bool:
	return is_adult() and bool(_root()["full_tier_enabled"])


func can_toggle_full_tier() -> bool:
	return is_adult()


func set_full_tier(enabled: bool) -> Dictionary:
	var d: Dictionary = _root()
	if enabled and not is_adult():
		d["full_tier_enabled"] = false
		return {
			"ok": false,
			"code": "DENY_MINOR" if str(d["state"]) == STATE_BLOCKED_MINOR else "DENY_AGE",
		}
	d["full_tier_enabled"] = enabled
	_touch_state(true)
	return {"ok": true, "code": "OK", "full_tier_enabled": enabled}


# ---- Account linking before first purchase (DECISIONS §5, P22 acceptance: DENY_LINK) ----------------------

func is_linked() -> bool:
	var d: Dictionary = _root()
	return str(d["linked_provider"]) != "" and str(d["linked_hash"]) != ""


func linked_provider() -> String:
	return str(_root()["linked_provider"])


func link_account(provider: String, account_uid: String) -> Dictionary:
	var p: String = provider.strip_edges().to_lower()
	if not LINK_PROVIDERS.has(p):
		return {"ok": false, "code": "DENY_PROVIDER"}
	var uid_clean: String = account_uid.strip_edges()
	if uid_clean == "":
		return {"ok": false, "code": "DENY_UID"}
	var d: Dictionary = _root()
	d["linked_provider"] = p
	d["linked_hash"] = (p + ":" + uid_clean).sha256_text()
	d["linked_at"] = clock.now()
	_touch_state(true)
	return {"ok": true, "code": "OK", "provider": p}


func unlink_account() -> void:
	var d: Dictionary = _root()
	d["linked_provider"] = ""
	d["linked_hash"] = ""
	d["linked_at"] = 0
	_touch_state(true)


func can_purchase() -> Dictionary:
	var d: Dictionary = _root()
	if str(d["state"]) == STATE_BLOCKED_MINOR:
		return {"ok": false, "code": "DENY_MINOR", "blocked_until": int(d["blocked_until"])}
	if not is_adult():
		return {"ok": false, "code": "DENY_AGE"}
	if not is_linked():
		return {"ok": false, "code": "DENY_LINK"}
	return {"ok": true, "code": "OK"}
