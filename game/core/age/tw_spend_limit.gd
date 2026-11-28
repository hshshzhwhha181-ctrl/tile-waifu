class_name TWSpendLimit
extends RefCounted

# TWSpendLimit (P22 / GDD §5.9 / DECISIONS №5 / MONETIZATION_PLAN §8.6, Прил. R C13-C14):
# Pure core spending protection:
#   - Default monthly cap: 5000 rub per rolling 30 days (DECISIONS №5, pending Q-R06).
#   - Lowering cap applies immediately; raising or removing cap applies after 24 hours (DP-07).
#   - Voluntary pause: 1 / 7 / 30 days on TWClock.safe_now() (DP-08).
#   - Irreversible self-exclusion: 30 / 90 / 180 days (DP-08).
#   - Emergency threshold (C13): >= 30000 rub / 30d OR >= 10000 rub / 24h -> 24h pause + user ack (even with no limit).
#   - Pause / self-exclusion blocks payments, wishes, and price display, NEVER the Full visual tier (C14).
#   - Unified purchase gate check_purchase() FAILS CLOSED if age, consent, or required_offer_ver are missing.
#   - record_purchase() is idempotent on order_id and uses order-independent 366d retention pruning.
# Note: zero currency symbols or percent-digit literals (UX_LINT / CONTRACT_SELFTEST compliant).

const MODULE_ID: String = "spend_limit"
const MODULE_VER: int = 1
const STATE_KEY: String = "spend_limit"

const DAY_SEC: int = 86400
const WINDOW_30D_SEC: int = 30 * DAY_SEC
const WINDOW_24H_SEC: int = DAY_SEC
const LIMIT_RAISE_DELAY_SEC: int = DAY_SEC
const KEEP_HISTORY_SEC: int = 366 * DAY_SEC

const DEFAULT_LIMIT_RUB: int = 5000
const EMERGENCY_30D_RUB: int = 30000
const EMERGENCY_24H_RUB: int = 10000
const EMERGENCY_PAUSE_SEC: int = DAY_SEC

const PRESET_LIMITS: = [1000, 3000, 5000, 10000, 30000, 0]
const PAUSE_DAYS: = [1, 7, 30]
const EXCLUDE_DAYS: = [30, 90, 180]

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
	if not (d.get("hist") is Array):
		d["hist"] = []
	if not d.has("limit"):
		d["limit"] = DEFAULT_LIMIT_RUB
	d["limit"] = maxi(0, int(d.get("limit", DEFAULT_LIMIT_RUB)))
	d["pending_limit"] = int(d.get("pending_limit", -1))
	d["limit_effective_at"] = int(d.get("limit_effective_at", 0))
	d["choice_shown"] = bool(d.get("choice_shown", false))
	d["pause_until"] = int(d.get("pause_until", 0))
	d["exclude_until"] = int(d.get("exclude_until", 0))
	d["emergency_until"] = int(d.get("emergency_until", 0))
	d["emergency_ack_needed"] = bool(d.get("emergency_ack_needed", false))
	d["mod_ver"] = MODULE_VER
	return d


func _touch_state(urgent: bool = true) -> void:
	if _state != null:
		_state.set_module_ver(MODULE_ID, MODULE_VER)
		_state.mark_dirty(urgent)


func _safe_now() -> int:
	return clock.safe_now()


func _apply_pending() -> void:
	var d: Dictionary = _root()
	if int(d["pending_limit"]) >= 0 and _safe_now() >= int(d["limit_effective_at"]):
		d["limit"] = int(d["pending_limit"])
		d["pending_limit"] = -1
		d["limit_effective_at"] = 0
		_touch_state(true)


# ---- queries ----------------------------------------------------------------------------------------------

func current_limit() -> int:
	_apply_pending()
	return int(_root()["limit"])


func pending_limit() -> int:
	_apply_pending()
	return int(_root()["pending_limit"])


func limit_effective_at() -> int:
	_apply_pending()
	return int(_root()["limit_effective_at"])


func spent_window(window_sec: int) -> int:
	var d: Dictionary = _root()
	var t0: int = _safe_now() - window_sec
	var total: int = 0
	for h in d["hist"]:
		if h is Dictionary and not bool((h as Dictionary).get("refunded", false)):
			var ts: int = int((h as Dictionary).get("t", 0))
			if ts > t0:
				total += int((h as Dictionary).get("rub", 0))
	return total


func spent_30d() -> int:
	return spent_window(WINDOW_30D_SEC)


func spent_24h() -> int:
	return spent_window(WINDOW_24H_SEC)


func room() -> int:
	var lim: int = current_limit()
	if lim <= 0:
		return -1
	return maxi(0, lim - spent_30d())


func is_paused() -> bool:
	return _safe_now() < int(_root()["pause_until"])


func pause_until() -> int:
	return int(_root()["pause_until"])


func is_self_excluded() -> bool:
	return _safe_now() < int(_root()["exclude_until"])


func exclude_until() -> int:
	return int(_root()["exclude_until"])


func is_emergency_paused() -> bool:
	var d: Dictionary = _root()
	return _safe_now() < int(d["emergency_until"]) or bool(d["emergency_ack_needed"])


func emergency_until() -> int:
	return int(_root()["emergency_until"])


# C14: pause and self-exclusion block payments, wishes, and price display, NEVER the Full visual tier
func blocks_prices_and_wishes() -> bool:
	return is_paused() or is_self_excluded() or is_emergency_paused()


func blocks_full_tier() -> bool:
	return false


# ---- mutations --------------------------------------------------------------------------------------------

# rub = 0 means "no own limit" (requires confirm_unlimited = true; emergency threshold still applies)
func set_limit(rub: int, confirm_unlimited: bool = false) -> Dictionary:
	_apply_pending()
	if rub < 0:
		return {"ok": false, "code": "DENY_INVALID_LIMIT"}
	if rub == 0 and not confirm_unlimited:
		return {"ok": false, "code": "DENY_UNLIMITED_CONFIRM"}
	var d: Dictionary = _root()
	var cur: int = int(d["limit"])
	d["choice_shown"] = true
	if rub == cur:
		d["pending_limit"] = -1
		d["limit_effective_at"] = 0
		_touch_state(true)
		return {"ok": true, "code": "OK", "immediate": true, "limit": cur}
	var is_lower: bool = rub > 0 and (cur == 0 or rub < cur)
	if is_lower:
		d["limit"] = rub
		d["pending_limit"] = -1
		d["limit_effective_at"] = 0
		_touch_state(true)
		return {"ok": true, "code": "OK", "immediate": true, "limit": rub}
	# Raising or removing own limit takes 24h
	var eff: int = _safe_now() + LIMIT_RAISE_DELAY_SEC
	d["pending_limit"] = rub
	d["limit_effective_at"] = eff
	_touch_state(true)
	return {"ok": true, "code": "PENDING_24H", "immediate": false, "limit": cur, "pending_limit": rub, "effective_at": eff}


func set_pause(days: int) -> Dictionary:
	if not PAUSE_DAYS.has(days):
		return {"ok": false, "code": "DENY_INVALID_PAUSE_DAYS"}
	var d: Dictionary = _root()
	var until: int = maxi(int(d["pause_until"]), _safe_now() + days * DAY_SEC)
	d["pause_until"] = until
	_touch_state(true)
	return {"ok": true, "code": "OK", "pause_until": until}


func set_self_exclusion(days: int) -> Dictionary:
	if not EXCLUDE_DAYS.has(days):
		return {"ok": false, "code": "DENY_INVALID_EXCLUDE_DAYS"}
	var d: Dictionary = _root()
	var until: int = maxi(int(d["exclude_until"]), _safe_now() + days * DAY_SEC)
	d["exclude_until"] = until
	_touch_state(true)
	return {"ok": true, "code": "OK", "exclude_until": until}


func acknowledge_emergency_pause() -> Dictionary:
	var d: Dictionary = _root()
	if _safe_now() < int(d["emergency_until"]):
		return {"ok": false, "code": "DENY_EMERGENCY_WAIT", "until": int(d["emergency_until"])}
	d["emergency_ack_needed"] = false
	_touch_state(true)
	return {"ok": true, "code": "OK"}


# ---- purchase gate & recording (FAIL CLOSED) --------------------------------------------------------------

func check_purchase(rub: int, age: TWAge = null, consent: TWConsent = null, required_offer_ver: String = "", real_payments_enabled: bool = true) -> Dictionary:
	if not real_payments_enabled:
		return {"ok": false, "code": "DENY_PAYMENTS_DISABLED"}
	if age == null:
		return {"ok": false, "code": "DENY_AGE", "reason": "age_gate_missing"}
	var age_res: Dictionary = age.can_purchase()
	if not bool(age_res.get("ok", false)):
		return age_res
	if consent == null:
		return {"ok": false, "code": "DENY_CONSENT", "reason": "consent_journal_missing"}
	var req_ver: String = required_offer_ver.strip_edges()
	if req_ver == "":
		return {"ok": false, "code": "DENY_CONSENT", "reason": "offer_ver_missing"}
	if not consent.has_required_consents(req_ver):
		return {"ok": false, "code": "DENY_CONSENT", "offer_ver": req_ver}
	if rub <= 0:
		return {"ok": false, "code": "DENY_AMOUNT"}
	var now: int = _safe_now()
	var d: Dictionary = _root()
	if now < int(d["exclude_until"]):
		return {"ok": false, "code": "DENY_SELF_EXCLUDED", "until": int(d["exclude_until"])}
	if now < int(d["pause_until"]):
		return {"ok": false, "code": "DENY_PAUSED", "until": int(d["pause_until"])}
	if now < int(d["emergency_until"]) or bool(d["emergency_ack_needed"]):
		return {
			"ok": false,
			"code": "DENY_EMERGENCY_PAUSE",
			"until": int(d["emergency_until"]),
			"ack_needed": bool(d["emergency_ack_needed"]),
		}
	var lim: int = current_limit()
	var s30: int = spent_30d()
	if lim > 0 and s30 + rub > lim:
		return {
			"ok": false,
			"code": "DENY_LIMIT",
			"spent_30d": s30,
			"limit": lim,
			"room": maxi(0, lim - s30),
		}
	return {
		"ok": true,
		"code": "OK",
		"spent_30d": s30,
		"limit": lim,
		"room": -1 if lim <= 0 else maxi(0, lim - s30 - rub),
	}


func record_purchase(rub: int, order_id: String) -> Dictionary:
	var oid: String = order_id.strip_edges()
	if oid == "":
		return {"ok": false, "code": "DENY_ORDER_ID"}
	var d: Dictionary = _root()
	var hist: Array = d["hist"]
	# Idempotency guard: replaying the same order_id (reconcile / restore) never double-counts spend.
	for existing in hist:
		if existing is Dictionary and str((existing as Dictionary).get("oid", "")) == oid:
			return {
				"ok": true,
				"code": "DUPLICATE",
				"duplicate": true,
				"spent_30d": spent_30d(),
				"spent_24h": spent_24h(),
				"emergency_triggered": false,
				"emergency_until": int(d["emergency_until"]),
			}
	var now: int = _safe_now()
	hist.append({"t": now, "rub": maxi(0, rub), "oid": oid, "refunded": false})
	# Order-independent retention pruning (safe even if entries are out of timestamp order after clock drift).
	var cutoff: int = now - KEEP_HISTORY_SEC
	var kept: Array = []
	for item in hist:
		if item is Dictionary and int((item as Dictionary).get("t", 0)) >= cutoff:
			kept.append(item)
	d["hist"] = kept
	var s30: int = spent_30d()
	var s24: int = spent_24h()
	var triggered_emergency: bool = false
	if s30 >= EMERGENCY_30D_RUB or s24 >= EMERGENCY_24H_RUB:
		d["emergency_until"] = maxi(int(d["emergency_until"]), now + EMERGENCY_PAUSE_SEC)
		d["emergency_ack_needed"] = true
		triggered_emergency = true
	_touch_state(true)
	return {
		"ok": true,
		"code": "OK",
		"duplicate": false,
		"spent_30d": s30,
		"spent_24h": s24,
		"emergency_triggered": triggered_emergency,
		"emergency_until": int(d["emergency_until"]),
	}


func mark_refunded(order_id: String) -> bool:
	var oid: String = order_id.strip_edges()
	if oid == "":
		return false
	var d: Dictionary = _root()
	var found: bool = false
	for h in d["hist"]:
		if h is Dictionary and str((h as Dictionary).get("oid", "")) == oid:
			(h as Dictionary)["refunded"] = true
			found = true
	if found:
		_touch_state(true)
	return found
