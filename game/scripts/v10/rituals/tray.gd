class_name V10Tray
extends RefCounted

# V10Tray — «Утренний поднос» (docs/0.10-spec.md Р4). On the first home visit of the day a lacquer tray rises in
# the lower third with cards of what is waiting; ONE button «Забрать всё». No tray when nothing waits.
#
#   V10Tray.register(id, provider: Callable(day_key) -> Dictionary | Array, prio = 50)
#       a provider returns {} / [] (nothing today) or a card / cards:
#       {icon: path | Texture2D, title: "Чайный лист", text: "+1 · серия под защитой", rewards: {…} (optional),
#        claim: Callable() (optional; called exactly once on «Забрать всё»)}
#       Higher prio first. Р3 (leaf) registers here; Г4 «Семь встреч» and Л4 абонемент register from their lanes.
#   V10Tray.collect(key = today) -> Array      cards for today ([] when already claimed today)
#   V10Tray.should_show(key = today) -> bool
#   V10Tray.claim_all(key = today) -> Array    calls every claim once, grants rewards, marks the day; returns rows
#                                              [{card, rows:[reward rows]}] for the cascade. A second call is a no-op.
# State S.v10_tray = {day, claimed:{id: day}}.

static var _providers: = {}
static var _builtins: = false


static func st() -> Dictionary:
	return V10RitSave.st("v10_tray")


static func register(id: String, provider: Callable, prio: = 50) -> void:
	_providers[id] = {"fn": provider, "prio": prio}


static func unregister(id: String) -> void:
	_providers.erase(id)


static func clear() -> void:
	_providers.clear()
	_builtins = false


static func ids() -> Array:
	return _providers.keys()


static func install_builtins() -> void:
	if _builtins:
		return
	_builtins = true
	register("streak_leaf", _leaf_card, 80)


# Р3: the Monday leaf (granted by V10Streak.weekly_leaf on the day roll) is shown here, so the player SEES it arrive
static func _leaf_card(key: String) -> Dictionary:
	var s: = V10Streak.st()
	if str(s.get("leaf_new_key", "")) != key:
		return {}
	return {"icon": "res://assets/v10/rituals/leaf.webp", "title": "Чайный лист",
		"text": "Листьев: %d из %d" % [int(s.leaves), V10Streak.LEAF_MAX], "rewards": {},
		"claim": func(): s.leaf_new_key = ""}


static func _today(key: String) -> String:
	return key if key != "" else V10RitClock.day_key()


static func collect(key: = "") -> Array:
	key = _today(key)
	install_builtins()
	if str(st().day) == key:
		return []
	var ids_sorted: = _providers.keys()
	ids_sorted.sort_custom(func(a, b): return int(_providers[a].prio) > int(_providers[b].prio))
	var out: = []
	for id in ids_sorted:
		var fn: Callable = _providers[id].fn
		if not fn.is_valid():
			continue
		var r = fn.call(key)
		var cards: = []
		if r is Dictionary and not r.is_empty():
			cards.append(r)
		elif r is Array:
			for c in r:
				if c is Dictionary and not c.is_empty():
					cards.append(c)
		for c in cards:
			var card: Dictionary = c.duplicate()
			card["id"] = id
			out.append(card)
	return out


static func should_show(key: = "") -> bool:
	return not collect(key).is_empty()


static func claim_all(key: = "") -> Array:
	key = _today(key)
	var cards: = collect(key)
	if cards.is_empty():
		return []
	var s: = st()
	s.day = key
	var out: = []
	for c in cards:
		var cl = c.get("claim")
		if cl is Callable and (cl as Callable).is_valid():
			(cl as Callable).call()
		var rw: Dictionary = c.get("rewards", {})
		var rows: = V10RitBridge.grant(rw, "tray_" + str(c.id)) if not rw.is_empty() else []
		s.claimed[str(c.id)] = key
		out.append({"card": c, "rows": rows})
	V10RitSave.save()
	return out
