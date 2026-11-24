class_name V10TutState
extends RefCounted

# V10TutState — what the player has already been shown (docs: scripts/v10/tutorial/README.md).
# Lives in the save as S.v10_tut (one dictionary, added by ensure(); V10Save.register can call ensure too).
#   step       id of the flow step in progress ("" = none started / between chapters)
#   chapters   {chapter_id: true} finished chapters of the guided first run
#   skipped    true after «Пропустить обучение» (flow off; contextual tips stay on unless tips_off)
#   tips       {tip_id: day_key} contextual first-time tips already shown
#   tips_off   true: no contextual tips at all (from Справка)
#   large      bigger bubble text (accessibility; S.text_large from the look lane wins when present)
#   gifts      {gift_id: true} one-time tutorial gifts (first free wish) — never granted twice
#   v          format version of this block

const KEY: = "v10_tut"
const VER: = 1
const DEFAULTS: = {"v": VER, "step": "", "chapters": {}, "skipped": false, "tips": {}, "tips_off": false,
	"large": false, "gifts": {}}

# test hook: a dictionary that stands in for G.S (selftests run without touching the real save)
static var override_s = null


static func S() -> Dictionary:
	if override_s is Dictionary:
		return override_s
	return G.S


# idempotent: adds the block and any missing key, repairs wrong types, never resets progress
static func ensure(s = null) -> Dictionary:
	var root: Dictionary = s if s is Dictionary else S()
	var d = root.get(KEY)
	var fresh: = not (d is Dictionary)
	if fresh:
		d = {}
		root[KEY] = d
	for k in DEFAULTS:
		var dv = DEFAULTS[k]
		if not d.has(k) or typeof(d[k]) != typeof(dv):
			d[k] = dv.duplicate(true) if dv is Dictionary else dv
	# migration, once: a player who finished the 0.9 first match (S.tut_done) does not get the match chapter
	# (a later «Обучение заново» may bring it back, so this runs only when the block is created)
	if fresh and bool(root.get("tut_done", false)):
		d.chapters["match1"] = true
	return d


static func st() -> Dictionary:
	return ensure()


static func save() -> void:
	if override_s is Dictionary:
		return
	var tree: = Engine.get_main_loop() as SceneTree
	if tree and tree.root.get_node_or_null("G"):
		G.save()


static func chapter_done(id: String) -> bool:
	return bool(st().chapters.get(id, false))


static func finish_chapter(id: String) -> void:
	var d: = st()
	d.chapters[id] = true
	d.step = ""
	if id == "match1":
		S()["tut_done"] = true
	save()


static func set_step(id: String) -> void:
	var d: = st()
	if d.step == id:
		return
	d.step = id
	save()


static func step() -> String:
	return String(st().step)


static func skipped() -> bool:
	return bool(st().skipped)


static func skip_all() -> void:
	var d: = st()
	d.skipped = true
	d.step = ""
	S()["tut_done"] = true
	save()


# «Пройти обучение заново» from Справка: the guided chapters come back (gifts stay given)
static func replay() -> void:
	var d: = st()
	d.skipped = false
	d.step = ""
	d.chapters = {}
	save()


static func tip_seen(id: String) -> bool:
	return st().tips.has(id)


static func mark_tip(id: String) -> void:
	st().tips[id] = _day()
	save()


static func reset_tips() -> void:
	var d: = st()
	d.tips = {}
	d.tips_off = false
	save()


static func tips_off() -> bool:
	return bool(st().tips_off)


static func set_tips_off(v: bool) -> void:
	st().tips_off = v
	save()


static func gift_given(id: String) -> bool:
	return bool(st().gifts.get(id, false))


static func mark_gift(id: String) -> void:
	st().gifts[id] = true
	save()


static func large() -> bool:
	var s: = S()
	if s.has("text_large"):
		return bool(s.text_large) or bool(st().large)
	return bool(st().large)


static func set_large(v: bool) -> void:
	st().large = v
	save()


# text scale for every tutorial caption: 1.0, or 1.22 with «Крупный текст»
static func text_scale() -> float:
	var s: = S()
	if s.has("text_scale"):
		return clampf(float(s.text_scale), 1.0, 1.5) if not bool(st().large) else maxf(1.22, float(s.text_scale))
	return 1.22 if large() else 1.0


static func _day() -> String:
	# only a marker that the tip was seen (its value is informational); G.today() is the game's day source.
	# No direct Time.* call here: spec §2.5 keeps those in v10/meta/meta.gd only.
	var tree: = Engine.get_main_loop() as SceneTree
	if tree and tree.root.get_node_or_null("G"):
		return str(G.today())
	return "-"
