class_name V10Reveal
extends RefCounted
# Staged reveal, UX_RULES §3.5 (+ MODES §6.4 for the «Столы» shelves). The single table of «what opens when».
# «после партии N» = levels_done() >= N, levels_done = G.S.unlocked - 1 (play.gd sets unlocked = lvl + 2 on a win).
# Unknown ids are open: the table never blocks a system it does not know.

const GATES: = {
	"tab.teahouse": {},
	"tab.tables": {"lvl": 1},
	"lantern.salon": {"lvl": 2},
	"tab.wishes": {"lvl": 3},
	"tab.heroines": {"lvl": 3, "flag": "first_pick", "or_lvl": 4},
	"phone": {"lvl": 5},
	"lantern.today": {"lvl": 6},
	"tab.shop": {"lvl": 8},
	"match.help": {"lvl": 3},
	"lantern.streak": {"day": 2},
	"phone.chats": {"day": 2},
	"morning_tray": {"day": 2},
	"phone.feed": {"day": 3},
	"path.boosters": {"lvl": 10},
	"mode.blitz": {"lvl": 12},
	"afisha.mode_day": {"lvl": 12},
	"victory.challenge": {"lvl": 15},
	"tables.tourney": {"lvl": 16},
	"season": {"lvl": 20, "or_day": 4},
	"mode.classic": {"lvl": 9},
	"mode.triples": {"lvl": 14},
	"mode.connect": {"lvl": 18},
	"mode.daily_task": {"lvl": 22},
	"mode.hand": {"lvl": 26},
	"mode.palm": {"lvl": 30},
	"mode.riichi": {"lvl": 34},
	"mode.cube": {"lvl": 40},
	"mode.koikoi": {"lvl": 45},
	"path.arcs": {"lvl": 49},
	"mode.dragon": {"lvl": 50},
	"path.peaks": {"lvl": 58},
	"path.legend": {"lvl": 100},
	# rank gates (G.rank_index: tier * 3 + sub; Нефрит I = 3, Нефрит III = 5, Жемчуг I = 6, Золото I = 9)
	"mode.garden": {"rank": 3},
	"mode.journey": {"rank": 3},
	"mode.duels": {"rank": 5},
	"mode.etudes": {"rank": 5},
	"mode.shift": {"rank": 6},
	"mode.pagoda": {"rank": 9},
}


static func levels_done() -> int:
	return _levels_done(V10TutState._root())


static func _levels_done(S: Dictionary) -> int:
	return maxi(0, int(S.get("unlocked", 1)) - 1)


static func _day(d: Dictionary) -> int:
	return maxi(1, V10TutState._today_index() - int(d.get("first_day", 0)) + 1) if int(d.get("first_day", 0)) > 0 else 1


static func _rank(S: Dictionary) -> int:
	if G != null and G.has_method("rank_index"):
		return int(G.rank_index(int(S.get("rp", 0))))
	return 0


static func is_open(id: String) -> bool:
	var S: = V10TutState._root()
	return is_open_in(S, V10TutState.st(), id)


# Pure form (used by the save migration before the block is complete).
static func is_open_in(S: Dictionary, d: Dictionary, id: String) -> bool:
	if not GATES.has(id):
		return true
	if d.get("forced", {}) is Dictionary and bool(d.get("forced", {}).get(id, false)):
		return true
	var g: Dictionary = GATES[id]
	if g.is_empty():
		return true
	var lv: = _levels_done(S)
	if g.has("rank"):
		return _rank(S) >= int(g.rank)
	if g.has("flag"):
		# tab.heroines: right after the first SSR pick (one fullscreen flow after L3), at the latest after L4
		if lv >= int(g.get("lvl", 0)) and String(S.get(g.flag, "")) != "":
			return true
		return lv >= int(g.get("or_lvl", 9999))
	if g.has("day") and not g.has("lvl"):
		return _day(d) >= int(g.day)
	if lv >= int(g.get("lvl", 0)):
		return true
	if g.has("or_day") and _day(d) >= int(g.or_day):
		return true
	return false


static func force_open(id: String) -> void:
	V10TutState.st().forced[id] = true
	V10TutState.save()


static func locked_text(id: String) -> String:
	if is_open(id) or not GATES.has(id):
		return ""
	var g: Dictionary = GATES[id]
	if g.has("rank"):
		return V10TutLines.ui("locked_rank", {"r": String(V10TutLines.RANK_GATES.get(id, ""))})
	if g.has("day") and not g.has("lvl"):
		return V10TutLines.ui("locked_day", {"n": int(g.day)})
	if g.has("flag"):
		return V10TutLines.ui("locked_level", {"n": int(g.lvl)})
	return V10TutLines.ui("locked_level", {"n": int(g.get("lvl", 0))})


# Intros whose gate is open, not yet seen, allowed on this screen — sorted by prio.
static func due_intros(screen_id: String) -> Array:
	var d: = V10TutState.st()
	var S: = V10TutState._root()
	var out: = []
	for id in V10TutLines.INTROS:
		var e: Dictionary = V10TutLines.INTROS[id]
		if bool(d.seen.get(id, false)):
			continue
		var sc: = String(e.get("screen", "home"))
		if sc != "*" and sc != screen_id:
			continue
		if id == "v10_welcome":
			if not bool(d.get("legacy", false)):
				continue
		elif not is_open_in(S, d, String(e.get("gate", ""))):
			continue
		out.append(id)
	out.sort_custom(func(a, b): return int(V10TutLines.INTROS[a].prio) < int(V10TutLines.INTROS[b].prio))
	return out


static func open_ids() -> Array:
	var out: = []
	for id in GATES:
		if is_open(id):
			out.append(id)
	return out
