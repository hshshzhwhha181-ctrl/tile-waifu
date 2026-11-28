class_name TWAge
extends RefCounted

# TWAge (P22 / GDD §5.9, §11.3 / MONETIZATION_PLAN §8.6, Прил. R C14-C15):
# Pure core age gate, 18+ declaration, 30-day minor lockout, Full-tier toggle guard, and verified account-link gate.
# Deterministic: uses injected TWClock and stores state in a plain Dictionary (or TWState.data["age_gate"]).
# Privacy (C15): full DOB (month/day) is NEVER persisted — only birth_year and age_declared_ok.

const MODULE_ID: String = "age_gate"
const MODULE_VER: int = 1
const STATE_KEY: String = "age_gate"

const MIN_AGE: int = 18
const MAX_AGE: int = 120
const MIN_YEAR: int = 1900
const MSK_OFFSET_SEC: int = TWClock.MSK_BIAS_MIN * 60
const TZ_BIAS_MIN_BOUND: int = -720
const TZ_BIAS_MAX_BOUND: int = 840
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
var _support_verifier: Callable = Callable()
var _link_verifier: Callable = Callable()


func _init(p_clock: TWClock = null, p_state: TWState = null, store_override: Dictionary = {}) -> void:
	_state = p_state
	clock = p_clock if p_clock != null else (p_state.clock if p_state != null else TWClock.new())
	if _state != null:
		_ensure_in(_state.data)
	else:
		_store = store_override
		_ensure_in(_store)


func set_support_verifier(verifier: Callable) -> void:
	_support_verifier = verifier


func set_link_verifier(verifier: Callable) -> void:
	_link_verifier = verifier


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
	d["linked_verified"] = bool(d.get("linked_verified", false))
	d["linked_at"] = int(d.get("linked_at", 0))
	d["support_ticket"] = str(d.get("support_ticket", ""))
	d["support_cleared_at"] = int(d.get("support_cleared_at", 0))
	d["mod_ver"] = MODULE_VER
	return d


func _touch_state(urgent: bool = true) -> void:
	if _state != null:
		_state.set_module_ver(MODULE_ID, MODULE_VER)
		_state.mark_dirty(urgent)


func _safe_now() -> int:
	return clock.safe_now()


# ---- pure calendar helpers (timezone-aware, default Moscow Time UTC+3) ------------------------------------

static func is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)


static func days_in_month(year: int, month: int) -> int:
	if month < 1 or month > 12:
		return 0
	if month == 2 and is_leap_year(year):
		return 29
	return int(DAYS_IN_MONTH[month])


static func date_of_tz(unix_ts: int, tz_bias_min: int) -> Dictionary:
	var bias: int = clampi(tz_bias_min, TZ_BIAS_MIN_BOUND, TZ_BIAS_MAX_BOUND)
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix_ts + bias * 60)
	return {
		"year": int(dt.get("year", 1970)),
		"month": int(dt.get("month", 1)),
		"day": int(dt.get("day", 1)),
		"hour": int(dt.get("hour", 0)),
		"minute": int(dt.get("minute", 0)),
		"second": int(dt.get("second", 0)),
	}


static func msk_date_of(unix_ts: int) -> Dictionary:
	return date_of_tz(unix_ts, TWClock.MSK_BIAS_MIN)


static func validate_dob(year: int, month: int, day: int, now_unix: int, tz_bias_min: int = TWClock.MSK_BIAS_MIN) -> Dictionary:
	var today: Dictionary = date_of_tz(now_unix, tz_bias_min)
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
	if age > MAX_AGE:
		return {"ok": false, "code": "DENY_DOB_RANGE", "age": -1}
	return {"ok": true, "code": "OK", "age": age, "today": today}


static func compute_age_tz(year: int, month: int, day: int, now_unix: int, tz_bias_min: int) -> int:
	var v: Dictionary = validate_dob(year, month, day, now_unix, tz_bias_min)
	if not bool(v.get("ok", false)):
		return -1
	return int(v.get("age", -1))


static func compute_age_msk(year: int, month: int, day: int, now_unix: int) -> int:
	return compute_age_tz(year, month, day, now_unix, TWClock.MSK_BIAS_MIN)


# ---- state machine ----------------------------------------------------------------------------------------

func current_state() -> String:
	var d: Dictionary = _root()
	return str(d["state"])


func is_minor_blocked() -> bool:
	var d: Dictionary = _root()
	var bu: int = int(d["blocked_until"])
	return bu > 0 and _safe_now() < bu


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
	var now: int = _safe_now()
	var bu: int = int(d["blocked_until"])
	if (str(d["state"]) == STATE_BLOCKED_MINOR or bu > 0) and now < bu:
		d["state"] = STATE_BLOCKED_MINOR
		d["age_declared_ok"] = false
		d["full_tier_enabled"] = false
		return {
			"ok": false,
			"code": "DENY_MINOR_LOCKED",
			"state": STATE_BLOCKED_MINOR,
			"blocked_until": bu,
		}
	var tz_bias: int = clampi(clock.tz_bias_min(), TZ_BIAS_MIN_BOUND, TZ_BIAS_MAX_BOUND)
	var v: Dictionary = validate_dob(year, month, day, now, tz_bias)
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


# Support-only unlock: fails closed unless a support_verifier callable is configured and approves (ticket_id, token).
func clear_minor_block_by_support(ticket_id: String = "", support_token: String = "") -> Dictionary:
	var d: Dictionary = _root()
	if not _support_verifier.is_valid():
		return {
			"ok": false,
			"code": "DENY_SUPPORT_UNCONFIGURED",
			"state": str(d["state"]),
		}
	var tid: String = ticket_id.strip_edges()
	var tok: String = support_token.strip_edges()
	if tid == "" or tok == "" or not bool(_support_verifier.call(tid, tok)):
		return {
			"ok": false,
			"code": "DENY_SUPPORT_AUTH",
			"state": str(d["state"]),
		}
	if str(d["state"]) == STATE_BLOCKED_MINOR or int(d["blocked_until"]) > 0:
		d["state"] = STATE_UNSET
		d["blocked_until"] = 0
		d["age_declared_ok"] = false
		d["full_tier_enabled"] = false
		d["support_ticket"] = tid
		d["support_cleared_at"] = _safe_now()
		_touch_state(true)
	return {"ok": true, "code": "OK", "state": str(d["state"]), "ticket_id": tid}


# Revoking adult declaration MUST NEVER bypass an active 30-day BLOCKED_MINOR lock.
func revoke_age() -> Dictionary:
	var d: Dictionary = _root()
	if is_minor_blocked():
		d["state"] = STATE_BLOCKED_MINOR
		d["age_declared_ok"] = false
		d["full_tier_enabled"] = false
		return {
			"ok": false,
			"code": "DENY_MINOR_LOCKED",
			"state": STATE_BLOCKED_MINOR,
			"blocked_until": int(d["blocked_until"]),
		}
	d["state"] = STATE_UNSET
	d["age_declared_ok"] = false
	d["full_tier_enabled"] = false
	d["declared_at"] = 0
	_touch_state(true)
	return {"ok": true, "code": "OK", "state": STATE_UNSET}


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
			"code": "DENY_MINOR" if (str(d["state"]) == STATE_BLOCKED_MINOR or is_minor_blocked()) else "DENY_AGE",
		}
	d["full_tier_enabled"] = enabled
	_touch_state(true)
	return {"ok": true, "code": "OK", "full_tier_enabled": enabled}


# ---- Account linking before first purchase (DECISIONS §5, P22 acceptance: DENY_LINK) ----------------------

static func _valid_uid_format(provider: String, uid_clean: String) -> bool:
	if uid_clean.length() < 3 or uid_clean.contains(" ") or uid_clean.contains("\t") or uid_clean.contains("\n"):
		return false
	if provider == "email":
		var at_idx: int = uid_clean.find("@")
		if at_idx <= 0 or at_idx != uid_clean.rfind("@"):
			return false
		var dom: String = uid_clean.substr(at_idx + 1)
		if dom.length() < 3 or not dom.contains(".") or dom.begins_with(".") or dom.ends_with("."):
			return false
	return true


func is_linked() -> bool:
	var d: Dictionary = _root()
	return str(d["linked_provider"]) != "" and str(d["linked_hash"]) != "" and bool(d["linked_verified"])


func linked_provider() -> String:
	return str(_root()["linked_provider"]) if is_linked() else ""


# Fails closed unless a link_verifier callable is configured and approves (provider, uid, verification_token).
func link_account(provider: String, account_uid: String, verification_token: String = "") -> Dictionary:
	var p: String = provider.strip_edges().to_lower()
	if not LINK_PROVIDERS.has(p):
		return {"ok": false, "code": "DENY_PROVIDER"}
	var uid_clean: String = account_uid.strip_edges()
	if not _valid_uid_format(p, uid_clean):
		return {"ok": false, "code": "DENY_UID"}
	if not _link_verifier.is_valid():
		return {"ok": false, "code": "DENY_LINK_UNCONFIGURED"}
	var tok_clean: String = verification_token.strip_edges()
	if tok_clean == "" or not bool(_link_verifier.call(p, uid_clean, tok_clean)):
		return {"ok": false, "code": "DENY_LINK_UNVERIFIED"}
	var d: Dictionary = _root()
	d["linked_provider"] = p
	d["linked_hash"] = (p + ":" + uid_clean).sha256_text()
	d["linked_verified"] = true
	d["linked_at"] = _safe_now()
	_touch_state(true)
	return {"ok": true, "code": "OK", "provider": p}


func unlink_account() -> void:
	var d: Dictionary = _root()
	d["linked_provider"] = ""
	d["linked_hash"] = ""
	d["linked_verified"] = false
	d["linked_at"] = 0
	_touch_state(true)


func can_purchase() -> Dictionary:
	var d: Dictionary = _root()
	if is_minor_blocked() or str(d["state"]) == STATE_BLOCKED_MINOR:
		return {"ok": false, "code": "DENY_MINOR", "blocked_until": int(d["blocked_until"])}
	if not is_adult():
		return {"ok": false, "code": "DENY_AGE"}
	if not is_linked():
		return {"ok": false, "code": "DENY_LINK"}
	return {"ok": true, "code": "OK"}
