class_name V10Save
extends RefCounted

# V10Save — the ONE save bump of 0.10: SAVE_VER 7 → 8 (docs/0.10-spec.md §2.6). Later milestones add keys through
# register() without another bump; ensure() fills them idempotently on every load.
#
#   V10Save.register(key, defaults)              a module's top-level save key and its defaults (dict or value)
#   V10Save.register_migrator(id, fn)            fn.call(S: Dictionary, now: int) — a module's one-time 7→8 step
#                                                (economy: S.econ = V10Econ.from_legacy(S, now), see README)
#   V10Save.migrate(S, now = -1) -> Dictionary   g.gd _migrate() calls it for ver < 8; returns a report
#                                                {from, to, added:[keys], migrators:[ids]}; never removes a key
#   V10Save.ensure(S) -> Array                   keys/sub-keys added (empty on the 2nd call = idempotent)
#
# Core plan of the bump (what this lane owns):
#   S.v10_meta    = V10Meta.defaults() with max_unix = now, days_seen = S.login.n, and last_key = the latest of the
#                   0.9 dates already counted (legacy midnight date, S.daily_day, S.tasks.day, S.login.last, S.pet.day):
#                   an update installed between 00:00 and 04:00 never rolls the day back (Ф1)
#   S.v10_afisha  = {day:"", played:{}}
# Logs (notify, ledger, pull_log …) live in user://v10_logs/*.json and are NOT in S.

const VER: = 8

static var _defaults: = {}
static var _migrators: Array = []


static func register(key: String, defaults) -> void:
	_defaults[key] = defaults


static func register_migrator(id: String, fn: Callable) -> void:
	for m in _migrators:
		if m.id == id:
			m.fn = fn
			return
	_migrators.append({"id": id, "fn": fn})


static func all_defaults() -> Dictionary:
	var d: = {"v10_meta": V10Meta.defaults(), "v10_afisha": V10Afisha.defaults()}
	for k in _defaults:
		d[k] = _defaults[k]
	return d


static func _fill(dst: Dictionary, src: Dictionary, path: String, added: Array) -> void:
	for k in src:
		if not dst.has(k):
			dst[k] = src[k].duplicate(true) if (src[k] is Dictionary or src[k] is Array) else src[k]
			added.append(path + str(k))
		elif src[k] is Dictionary and dst[k] is Dictionary and not (src[k] as Dictionary).is_empty():
			_fill(dst[k], src[k], path + str(k) + ".", added)


static func ensure(S: Dictionary) -> Array:
	var added: = []
	_fill(S, all_defaults(), "", added)
	return added


static func _latest_key(S: Dictionary, now: int = -1) -> String:
	var best: String = Time.get_date_string_from_unix_time(V10Meta.local_unix(now)) if now >= 0 else V10Meta.legacy_today()
	var max_idx: int = V10Meta.day_index(best) + 1
	var cands: = [str(S.get("daily_day", ""))]
	for k in ["tasks", "pet"]:
		var d = S.get(k)
		if d is Dictionary:
			cands.append(str(d.get("day", "")))
	var lg = S.get("login")
	if lg is Dictionary:
		cands.append(str(lg.get("last", "")))
	for c in cands:
		# only well-formed calendar ISO dates, and never ahead of tomorrow (a damaged date must not freeze the day)
		if c != "" and TWClock._valid_key(c) and c > best and V10Meta.day_index(c) <= max_idx:
			best = c
	return best


static func migrate(S: Dictionary, now: int = -1) -> Dictionary:
	var from: = int(S.get("ver", 0))
	var rep: = {"from": from, "to": maxi(from, VER), "added": [], "migrators": []}
	if now < 0:
		now = V10Meta.now_unix()
	if from < VER:
		if not (S.get("v10_meta") is Dictionary):
			var m: = V10Meta.defaults()
			m.max_unix = now
			var lg = S.get("login")
			m.days_seen = int(lg.get("n", 0)) if lg is Dictionary else 0
			m.last_key = _latest_key(S, now)
			S["v10_meta"] = m
			rep.added.append("v10_meta")
		if not (S.get("v10_afisha") is Dictionary):
			S["v10_afisha"] = V10Afisha.defaults()
			rep.added.append("v10_afisha")
		for mg in _migrators:
			(mg.fn as Callable).call(S, now)
			rep.migrators.append(mg.id)
		S["ver"] = VER
	rep.added.append_array(ensure(S))
	return rep
