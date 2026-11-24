class_name V10EntryQueue
extends RefCounted

# V10EntryQueue — at most ONE full-screen scene per launch (docs/0.10-spec.md §1.2, Ф1). Modules offer their
# full-screen moment while the home screen is being built; the home screen asks take() once and shows only the
# winner. Everything else waits for a later launch: its module simply offers again next time (its condition still
# holds), until it calls done(kind, key). Trays, toasts and badges are not full-screen and never go through here.
#
# Priority: comeback > player birthday > heroine birthday > new banner phase > «Новый стиль стола» > rules note.
#
#   V10EntryQueue.offer(kind, key, show: Callable) -> bool   false when this kind+key was already seen or the
#                                                            launch's scene is already taken
#   V10EntryQueue.take() -> Dictionary   {kind, key, show} of the highest offer, once per launch; {} afterwards
#   V10EntryQueue.run() -> bool          take() and call its show(); true when something was shown
#   V10EntryQueue.done(kind, key)        the scene was seen: never offer this kind+key again (S.v10_meta.scenes_seen)
#   V10EntryQueue.new_launch()           tests / dev only: forget this launch's state

const PRIO: = {"comeback": 6, "player_bday": 5, "hero_bday": 4, "banner_phase": 3, "table_style": 2, "rules_note": 1}

static var _offers: Array = []
static var _taken: = false
static var _shown: Dictionary = {}


static func seen(kind: String, key: String) -> bool:
	var ss: Dictionary = V10Meta.st().scenes_seen
	return str(ss.get(kind, "")) == key and key != ""


static func offer(kind: String, key: String, show: Callable = Callable()) -> bool:
	if not PRIO.has(kind):
		push_warning("V10EntryQueue.offer: unknown kind '%s'" % kind)
		return false
	if _taken or seen(kind, key):
		return false
	for o in _offers:
		if o.kind == kind:
			o.key = key
			o.show = show
			return true
	_offers.append({"kind": kind, "key": key, "show": show})
	return true


static func pending() -> Array:
	var out: = _offers.duplicate()
	out.sort_custom(func(a, b): return int(PRIO[a.kind]) > int(PRIO[b.kind]))
	return out


static func take() -> Dictionary:
	if _taken:
		return {}
	_taken = true
	var p: = pending()
	_offers.clear()
	if p.is_empty():
		return {}
	_shown = p[0]
	return _shown


static func run() -> bool:
	var t: = take()
	if t.is_empty():
		return false
	var cb: Callable = t.get("show", Callable())
	if cb.is_valid():
		cb.call()
	return true


static func done(kind: String, key: String) -> void:
	(V10Meta.st().scenes_seen as Dictionary)[kind] = key


static func shown_this_launch() -> Dictionary:
	return _shown


static func new_launch() -> void:
	_offers.clear()
	_taken = false
	_shown = {}
