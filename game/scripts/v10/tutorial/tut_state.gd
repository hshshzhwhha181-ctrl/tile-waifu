class_name V10TutState
extends RefCounted
# Save block of the tutorial: G.S.v10_tut (v2). Keys are only added; SAVE_VER is untouched.
# Re-read G.S on every call: a load / recovery import replaces G.S as a whole.

const KEY: = "v10_tut"
const VER: = 2
const DEFAULTS: = {
	"v": VER, "seen": {}, "first_match": false, "skipped": false, "hints": true,
	"first_day": 0, "t0": 0, "funnel": {}, "large": false, "legacy": false, "entries": 0, "forced": {},
}

static var test_store = null  # Dictionary: used instead of G.S when not null (selftest)


static func _root() -> Dictionary:
	if test_store is Dictionary:
		return test_store
	if G == null or not (G.S is Dictionary):
		test_store = {}
		return test_store
	return G.S


static func st() -> Dictionary:
	var S: = _root()
	return ensure(S)


# Idempotent. Migrates the old v1 block (old module) and 0.9 players.
static func ensure(S: Dictionary) -> Dictionary:
	var d = S.get(KEY, null)
	var fresh: = not (d is Dictionary)
	if fresh:
		d = {}
		S[KEY] = d
	var old_v: = int(d.get("v", 0))
	if old_v == 1:
		_from_v1(d)
	for k in DEFAULTS:
		if not d.has(k):
			d[k] = DEFAULTS[k].duplicate(true) if DEFAULTS[k] is Dictionary else DEFAULTS[k]
	# types (JSON brings ints back as floats; corrupted values become defaults)
	for k in ["seen", "funnel", "forced"]:
		if not (d[k] is Dictionary):
			d[k] = {}
	for k in ["first_match", "skipped", "hints", "large", "legacy"]:
		d[k] = bool(d[k])
	for k in ["first_day", "t0", "entries"]:
		d[k] = int(d[k])
	d.v = VER
	if int(d.t0) <= 0:
		d.t0 = V10Meta.now_unix()
	if int(d.first_day) <= 0:
		d.first_day = _today_index()
	if fresh or old_v < 2:
		_legacy_check(S, d)
	return d


static func _from_v1(d: Dictionary) -> void:
	var ch = d.get("chapters", {})
	if ch is Dictionary and bool(ch.get("match1", false)):
		d["first_match"] = true
	if bool(d.get("tips_off", false)):
		d["hints"] = false
	if bool(d.get("skipped", false)):
		d["skipped"] = true
		d["first_match"] = true
	for k in ["step", "chapters", "tips", "tips_off", "gifts"]:
		d.erase(k)


# A 0.9 player (finished the old tutorial or has progress): the first match is done, everything already open is
# «seen» (one welcome line about the new tabs is kept for them).
static func _legacy_check(S: Dictionary, d: Dictionary) -> void:
	var played: = int(S.get("unlocked", 1)) > 1 or bool(S.get("tut_done", false))
	if not played:
		return
	d["first_match"] = true
	d["legacy"] = true
	var seen: Dictionary = d.seen
	for id in V10TutLines.INTROS:
		if id == "v10_welcome":
			continue
		var gate: = String(V10TutLines.INTROS[id].get("gate", ""))
		if gate == "" or V10Reveal.is_open_in(S, d, gate):
			seen[id] = true
	for id in V10TutLines.MATCH:
		if String(id).begins_with("m_") or String(id).begins_with("v_"):
			seen[id] = true


static func _today_index() -> int:
	return V10Meta.day_index(V10Meta.day_key())


static func seen(id: String) -> bool:
	return bool(st().seen.get(id, false))


static func mark(id: String) -> void:
	st().seen[id] = true


static func unmark(id: String) -> void:
	st().seen.erase(id)


static func hints_on() -> bool:
	return bool(st().hints)


static func set_hints(on: bool) -> void:
	st().hints = on
	save()


static func first_match_done() -> bool:
	return bool(st().first_match)


static func set_first_match_done() -> void:
	st().first_match = true
	var S: = _root()
	S["tut_done"] = true
	save()


static func skipped() -> bool:
	return bool(st().skipped)


static func skip() -> void:
	var d: = st()
	d.skipped = true
	d.hints = false
	set_first_match_done()


# 1 on the first play day (04:00 day boundary of V10Meta), 2 on the next, …
static func day_number() -> int:
	return maxi(1, _today_index() - int(st().first_day) + 1)


static func funnel_mark(ev: String) -> void:
	var d: = st()
	if d.funnel.has(ev):
		return
	d.funnel[ev] = V10Meta.now_unix() - int(d.t0)


static func replay() -> void:
	var d: = st()
	d.skipped = false
	d.hints = true
	if d.get("tries", null) is Dictionary:
		(d.tries as Dictionary).clear()
	for k in V10TutLines.MATCH:
		if String(k).begins_with("m_") or String(k).begins_with("v_"):
			d.seen.erase(String(k))
	save()


static func funnel(ev: String) -> int:
	return int(st().funnel.get(ev, -1))


# compatibility: clarity_state.gd asks for the old «Крупный текст» flag (now the global text scale owns it)
static func large() -> bool:
	return bool(st().get("large", false))


static func save() -> void:
	if test_store is Dictionary:
		return
	if G != null and G.has_method("save"):
		G.save()
