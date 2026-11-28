class_name TWAnalyticsBuffer
extends RefCounted

# P106: Pure deterministic analytics event builder and bounded in-memory queue.
# Zero Node/network/time/random/G. dependencies: timestamps are injected explicitly
# (or pulled from an injected TWClock instance).
# Enforces 152-FZ consent toggle: when analytics_consent == false, no telemetry is buffered.

const DEFAULT_MAX_QUEUE: = 500

var uid: String = ""
var sess: String = ""
var app_ver: String = "0.12.0"
var build: String = "rustore"
var lang: String = "ru"
var tier: String = "standard"
var age_ok: bool = false
var conn: String = "wifi"
var analytics_consent: bool = false
var max_queue: int = DEFAULT_MAX_QUEUE

var accepted_count: int = 0
var rejected_count: int = 0
var dropped_no_consent: int = 0
var dropped_overflow: int = 0
var last_errors: Array = []

var _queue: Array = []
var _seq: int = 0


func configure_session(p_uid: String, p_sess: String, opts: Dictionary = {}) -> void:
	uid = p_uid
	sess = p_sess
	if opts.has("app_ver"):
		app_ver = str(opts.app_ver)
	if opts.has("build"):
		build = str(opts.build)
	if opts.has("lang"):
		lang = str(opts.lang)
	if opts.has("tier"):
		tier = str(opts.tier)
	if opts.has("age_ok"):
		age_ok = bool(opts.age_ok)
	if opts.has("conn"):
		conn = str(opts.conn)
	if opts.has("analytics_consent"):
		analytics_consent = bool(opts.analytics_consent)
	if opts.has("max_queue"):
		max_queue = maxi(1, int(opts.max_queue))


# 152-FZ S02 consent toggle: revoking consent clears buffered events immediately.
func set_consent(granted: bool) -> void:
	analytics_consent = granted
	if not analytics_consent:
		_queue.clear()


func build_event(event_name: String, params: Dictionary, ts_ms: int, event_id: String = "") -> Dictionary:
	var eid: String = event_id
	if eid.is_empty():
		_seq += 1
		eid = "%s_%d_%d" % [sess, ts_ms, _seq]
	return {
		"event_id": eid,
		"event": event_name,
		"ts": ts_ms,
		"uid": uid,
		"sess": sess,
		"app_ver": app_ver,
		"build": build,
		"lang": lang,
		"tier": tier,
		"age_ok": age_ok,
		"conn": conn,
		"ev_ver": TWAnalyticsSchema.EV_VER,
		"params": params.duplicate(true),
	}


# Validates and enqueues an event. Returns {ok, status, errors, event}.
func record(event_name: String, params: Dictionary, ts_ms: int) -> Dictionary:
	last_errors = []
	if not analytics_consent:
		dropped_no_consent += 1
		return {"ok": false, "status": "no_consent", "errors": ["CONSENT_NOT_GRANTED"], "event": {}}

	var ev: Dictionary = build_event(event_name, params, ts_ms)
	var check: Dictionary = TWAnalyticsSchema.validate_event(ev)
	if not bool(check.ok):
		rejected_count += 1
		last_errors = check.errors
		return {"ok": false, "status": "rejected", "errors": check.errors, "event": ev}

	if _queue.size() >= max_queue:
		_queue.pop_front()
		dropped_overflow += 1

	_queue.append(ev)
	accepted_count += 1
	return {"ok": true, "status": "queued", "errors": [], "event": ev}


# Convenience helper for econ_snapshot using MP §7.4 bucketed balances (no exact raw balances).
func record_econ_snapshot(gems: int, tickets: int, moon: int, petals: int, coins: int, ts_ms: int) -> Dictionary:
	return record("econ_snapshot", {
		"gems": TWAnalyticsSchema.bucket_econ_value(gems),
		"tickets": TWAnalyticsSchema.bucket_econ_value(tickets),
		"moon": TWAnalyticsSchema.bucket_econ_value(moon),
		"petals": TWAnalyticsSchema.bucket_econ_value(petals),
		"coins": TWAnalyticsSchema.bucket_econ_value(coins),
	}, ts_ms)


func pending_count() -> int:
	return _queue.size()


func peek_batch(limit: int = 50) -> Array:
	var n: int = mini(maxi(0, limit), _queue.size())
	var out: Array = []
	for i in n:
		out.append((_queue[i] as Dictionary).duplicate(true))
	return out


func ack_batch(count: int) -> int:
	var n: int = mini(maxi(0, count), _queue.size())
	for _i in n:
		_queue.pop_front()
	return n


func drain_batch(limit: int = 50) -> Array:
	var batch: Array = peek_batch(limit)
	ack_batch(batch.size())
	return batch


func clear() -> void:
	_queue.clear()


func snapshot_stats() -> Dictionary:
	return {
		"pending": _queue.size(),
		"accepted": accepted_count,
		"rejected": rejected_count,
		"dropped_no_consent": dropped_no_consent,
		"dropped_overflow": dropped_overflow,
		"consent": analytics_consent,
	}
