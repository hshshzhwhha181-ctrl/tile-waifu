class_name V10Notify
extends RefCounted

# V10Notify — the notification PLAN (docs/0.10-spec.md Ф1). In 0.10 nothing is posted to the phone: requests are
# planned, logged to user://v10_logs/notify.json and shown in the dev overlay. 1.0 adds the TWNotify Gradle plugin
# (POST_NOTIFICATIONS asked only after «Разрешить», WorkManager on Android 14) and posts exactly this plan.
#
#   V10Notify.request(cat, earliest_unix, hero = "", text_id = "") -> Dictionary   the planned entry or {} (skipped)
#       · consent first: nothing is planned without «Разрешить»; a switched-off category is skipped
#         (Возвращение / comeback is OFF by default, its own switch)
#       · budget: ONE notification per 72 h (from the last one sent); one slot in the queue — a higher priority
#         request displaces the queued one (bday 3 > comeback 2 > salon 1 > feed 0), a lower/equal one is dropped
#       · quiet hours 22:00–10:00 phone time: moved to 10:00 + 0–40 min (jitter from the day's seed)
#       · the text passes V10Lint (no prices, no guilt), else the request is dropped and logged
#   V10Notify.advance(now) -> Dictionary   the queued entry whose time has come is marked sent (last_unix) and returned
#   V10Notify.next_allowed(now) -> int, next_text(now) -> «Следующее уведомление не раньше: чт 18:30»
#   V10Notify.set_consent(allow), can_ask(now) (re-ask after a refusal not sooner than 30 days), set_cat(cat, on)
#   V10Notify.log_entries() -> Array       the dev log (≤200 entries)
#
# State: S.v10_meta.notify {cats, last_unix, queued} and S.v10_meta.consent {push, push_asked, asked_unix, bday}.

const BUDGET_SECS: = 72 * 3600
const QUIET_FROM_H: = 22
const QUIET_TO_H: = 10
const JITTER_MIN: = 40
const REASK_SECS: = 30 * 86400
const LOG_MAX: = 200
const PRIO: = {"bday": 3, "comeback": 2, "salon": 1, "feed": 0}
const CATS: = ["bday", "salon", "feed", "comeback"]
const CAT_NAMES: = {"bday": "Дни рождения", "salon": "Салон", "feed": "Лента", "comeback": "Возвращение"}

static var log_path: = "user://v10_logs/notify.json"
static var _log: Array = []
static var _log_loaded: = false


static func _n() -> Dictionary:
	return V10Meta.st().notify


static func _c() -> Dictionary:
	return V10Meta.st().consent


static func request(cat: String, earliest: int, hero: = "", text_id: = "") -> Dictionary:
	if not PRIO.has(cat):
		_write_log("skip", {"cat": cat, "why": "unknown"})
		return {}
	if not bool(_c().push):
		_write_log("skip", {"cat": cat, "why": "no_consent"})
		return {}
	var s: = _n()
	if not bool((s.cats as Dictionary).get(cat, false)):
		_write_log("skip", {"cat": cat, "why": "cat_off"})
		return {}
	if text_id == "":
		text_id = V10NotifyText.pick(cat, V10Meta.day_seed(V10Meta.day_key(), cat))
	var txt: = V10NotifyText.text(text_id, hero)
	if txt == "" or not V10Lint.ok(txt):
		_write_log("skip", {"cat": cat, "why": "lint", "text_id": text_id})
		return {}
	var now: = V10Meta.now_unix()
	var at: = maxi(earliest, now)
	if int(s.last_unix) > 0:
		at = maxi(at, int(s.last_unix) + BUDGET_SECS)
	at = quiet_shift(at)
	var q: Dictionary = s.queued
	if not q.is_empty():
		if int(PRIO[cat]) > int(PRIO.get(str(q.get("cat", "")), -1)):
			_write_log("displaced", {"cat": q.get("cat", ""), "by": cat})
		else:
			_write_log("skip", {"cat": cat, "why": "budget", "queued": q.get("cat", "")})
			return {}
	var plan: = {"cat": cat, "at": at, "hero": hero, "text_id": text_id, "text": txt,
		"title": V10NotifyText.TITLES.get(cat, "")}
	s.queued = plan
	_write_log("plan", {"cat": cat, "at": at, "hero": hero, "text_id": text_id})
	return plan


static func advance(now: int) -> Dictionary:
	var s: = _n()
	var q: Dictionary = s.queued
	if q.is_empty() or int(q.get("at", 0)) > now:
		return {}
	s.last_unix = int(q.at)
	s.queued = {}
	_write_log("sent", {"cat": q.get("cat", ""), "at": int(q.at)})
	return q


static func in_quiet(u: int) -> bool:
	var h: = int(V10Meta.local_dt(u).hour)
	return h >= QUIET_FROM_H or h < QUIET_TO_H


static func quiet_shift(u: int) -> int:
	if not in_quiet(u):
		return u
	var lu: = V10Meta.local_unix(u)
	var day0: = lu - posmod(lu, 86400)
	var h: = int(V10Meta.local_dt(u).hour)
	var target: = day0 + QUIET_TO_H * 3600 + (86400 if h >= QUIET_FROM_H else 0)
	var key: = Time.get_date_string_from_unix_time(target)
	var jitter: = posmod(V10Meta.day_seed(key, "notify"), JITTER_MIN + 1) * 60
	return target - V10Meta.tz_bias_min() * 60 + jitter


static func next_allowed(now: int) -> int:
	var s: = _n()
	var q: Dictionary = s.queued
	if not q.is_empty():
		return int(q.at)
	var t: = now
	if int(s.last_unix) > 0:
		t = maxi(t, int(s.last_unix) + BUDGET_SECS)
	return quiet_shift(t)


static func next_text(now: int) -> String:
	return "Следующее уведомление не раньше: %s" % V10Meta.fmt_when(next_allowed(now))


static func set_consent(allow: bool) -> void:
	var c: = _c()
	c.push_asked = true
	c.asked_unix = V10Meta.now_unix()
	c.push = allow
	c.bday = allow
	if allow:
		var cats: Dictionary = _n().cats
		for k in ["bday", "salon", "feed"]:
			cats[k] = true
	_write_log("consent", {"allow": allow})


static func can_ask(now: int) -> bool:
	var c: = _c()
	if bool(c.push):
		return false
	return not bool(c.push_asked) or now - int(c.asked_unix) >= REASK_SECS


static func set_cat(cat: String, on: bool) -> void:
	if PRIO.has(cat):
		(_n().cats as Dictionary)[cat] = on
		_write_log("cat", {"cat": cat, "on": on})


static func cat_on(cat: String) -> bool:
	return bool((_n().cats as Dictionary).get(cat, false))


# ── dev log (user://v10_logs/notify.json, not in the save) ─────────────────────────────────────────────────────

static func log_entries() -> Array:
	_load_log()
	return _log


static func clear_log() -> void:
	_log = []
	_log_loaded = true
	_flush_log()


static func _load_log() -> void:
	if _log_loaded:
		return
	_log_loaded = true
	_log = []
	if FileAccess.file_exists(log_path):
		var f: = FileAccess.open(log_path, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			f.close()
			if d is Array:
				_log = d


static func _write_log(ev: String, data: Dictionary) -> void:
	_load_log()
	var e: = data.duplicate()
	e["ev"] = ev
	e["t"] = V10Meta.now_unix()
	_log.append(e)
	while _log.size() > LOG_MAX:
		_log.pop_front()
	_flush_log()


static func _flush_log() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(log_path.get_base_dir()))
	var f: = FileAccess.open(log_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_log))
		f.close()
