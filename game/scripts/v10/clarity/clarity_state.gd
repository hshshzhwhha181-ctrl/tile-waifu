class_name V10ClarityState
extends RefCounted

# Saved clarity settings and «first time seen» marks, in G.S["v10_clarity"] (created lazily like G.S["v6_special"],
# so no SAVE_VER bump is needed; an old save simply has no key and gets the defaults).
#   marks   "auto" | "on" | "off"   suit marks on tiles. auto = ON for the first 10 tables of the Path, then the
#                                   player is asked once («Оставить метки мастей?») and the answer becomes on / off
#   big     bool                    «Крупные символы и контрастные масти»: bigger marks with the number, bolder badges,
#                                   blocked tiles darkened more. Defaults to the tutorial lane's large-text option
#                                   (V10TutState.large) when that lane is merged, else off.
#   asked   bool                    the one-time question after table 10 was shown
#   seen    {glossary id: count}    bonuses already met on a victory screen (the NEW highlight shows only once)
#   tips    {id: true}              one-time tooltips (long-press hint, legend hint)

const KEY: = "v10_clarity"
const AUTO_LEVELS: = 10

static func st() -> Dictionary:
	if not G.S.has(KEY) or not (G.S[KEY] is Dictionary):
		G.S[KEY] = {"marks": "auto", "big": _tut_large(), "asked": false, "seen": {}, "tips": {}}
	var d: Dictionary = G.S[KEY]
	for k in ["seen", "tips"]:
		if not d.has(k) or not (d[k] is Dictionary):
			d[k] = {}
	if not d.has("marks"):
		d["marks"] = "auto"
	if not d.has("big"):
		d["big"] = false
	return d

static func save() -> void:
	G.save()

static func marks_mode() -> String:
	return String(st().marks)

static func set_marks(m: String) -> void:
	st().marks = m
	save()

static func marks_on() -> bool:
	return marks_mode() != "off"

static func big() -> bool:
	return bool(st().big)

static func set_big(v: bool) -> void:
	st().big = v
	save()

# the one-time question is due: auto mode, not asked yet, the player is past the first AUTO_LEVELS tables
static func ask_due(level_index: int) -> bool:
	var d: = st()
	return String(d.marks) == "auto" and not bool(d.get("asked", false)) and level_index >= AUTO_LEVELS

static func answer(keep: bool) -> void:
	var d: = st()
	d.asked = true
	d.marks = "on" if keep else "off"
	save()

static func seen_count(id: String) -> int:
	return int(st().seen.get(id, 0))

# returns true the FIRST time an id is met (and counts it)
static func mark_seen(id: String) -> bool:
	var d: Dictionary = st().seen
	var first: = int(d.get(id, 0)) == 0
	d[id] = int(d.get(id, 0)) + 1
	return first

static func tip_done(id: String) -> bool:
	return bool(st().tips.get(id, false))

static func mark_tip(id: String) -> void:
	st().tips[id] = true

# soft link to the tutorial lane (v10-tutorial): its «large text» option, if that class exists in this build
static func _tut_large() -> bool:
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == "V10TutState":
			var s = load(String(c.path))
			if s is Script and (s as Script).get_script_method_list().any(func(m): return String(m.name) == "large"):
				return bool(s.call("large"))
	return false
