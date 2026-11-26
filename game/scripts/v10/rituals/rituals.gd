class_name V10Rituals
extends RefCounted

# V10Rituals — the one entry point the integrator wires (README «Hooks»). Keeps the hot files to one-liners.
#
#   V10Rituals.install()                        once at start: save defaults (V10Save.register when present), tray
#                                               providers, V10Hooks signals when the autoload exists
#   V10Rituals.day_start(key = today) -> Dictionary   BEFORE the home is built (entry queue): comeback check, streak
#                                               check (leaf / cooled / reset), birthdays; returns
#                                               {scene: {tier…}|{}, player_bday: bool, streak_events:[…], letters:[…]}
#   V10Rituals.on_game_ended(r) -> Dictionary   r = {won, mode, ranked, pairs, best_combo, secs, hard, stars, hints,
#                                               undos, fever, ults, new_level, duel}; returns {streak: on_win result,
#                                               ask_bday: bool} for the win stack (tick icon «серия»)
#   V10Rituals.deal_overlay(cfg) -> Dictionary  V10Bday.sig_overlay for game_started (unranked only)
#   V10Rituals.on_pair(face, overlay)           bday goal counting (pair_taken)
#   V10Rituals.mastery_pairs(pairs, ranked)     Отдых ×2: pairs doubled for outfit mastery
#   V10Rituals.entries(key) -> Array            entry-queue items [{id, prio, kind}] (≤1 full-screen scene per launch)

static var _installed: = false


static func install() -> void:
	if _installed:
		return
	_installed = true
	var sv: = V10RitBridge.klass("V10Save")
	if sv:
		var df: = V10RitSave.defaults()
		for k in df:
			sv.call("register", k, df[k])
	V10Tray.install_builtins()
	var tree: = Engine.get_main_loop() as SceneTree
	var hooks = tree.root.get_node_or_null("V10Hooks") if tree else null
	if hooks:
		if hooks.has_signal("game_ended"):
			hooks.game_ended.connect(func(r): on_game_ended(r))
		if hooks.has_signal("app_resumed"):
			hooks.app_resumed.connect(func(): V10Streak.check())


static func day_start(key: = "") -> Dictionary:
	key = key if key != "" else V10RitClock.day_key()
	var cb: = V10Comeback.check(key)
	var ev: = V10Streak.check(key)
	var letters: = []
	var bh: = V10Bday.today_hero(key)
	var b: Dictionary = V10RitSave.st("v10_bday")
	if bh != "" and str(b.seen_key) != key:
		b.seen_key = key
		letters.append(V10Bday.letter(bh))
	if int(cb.get("letters", 0)) > 0:
		letters.append_array(V10Comeback.while_away(int(cb.gap)))
	var wl: = V10WeekLetter.due(key)
	if not wl.is_empty():
		letters.append(wl)
	V10RitSave.save()
	return {"scene": V10Comeback.take_scene() if cb.tier != "" else {}, "comeback": cb,
		"player_bday": V10PlayerBday.gift_due(key), "streak_events": ev, "letters": letters, "bday_hero": bh}


static func on_game_ended(r: Dictionary) -> Dictionary:
	var key: = V10RitClock.day_key()
	var rn: = r.duplicate()
	if not rn.has("won") and rn.has("win"):
		rn["won"] = bool(rn.win)
	V10Tele.note_game(rn, key)
	var out: = {"streak": {}, "ask_bday": false}
	if bool(rn.get("won", false)):
		out.streak = V10Streak.on_win(key)
		var first: = str(V10Tele.st().first_key)
		if V10PlayerBday.ask_due(key, first, true):
			V10PlayerBday.mark_asked()
			out.ask_bday = true
			if not V10RitSave._bound:
				var lt: = V10RitBridge.klass("V9Letters")
				if lt != null and lt.has_method("queue"):
					lt.call("queue", "ask_bday")
	V10RitSave.save()
	return out


static func deal_overlay(cfg: Dictionary) -> Dictionary:
	return V10Bday.sig_overlay(cfg)


static func on_pair(face: int, overlay: Dictionary) -> Dictionary:
	return V10Bday.on_pair(face, overlay)


static func mastery_pairs(pairs: int, ranked: bool) -> int:
	return V10Comeback.consume_rested(pairs, ranked)


static func entries(key: = "") -> Array:
	key = key if key != "" else V10RitClock.day_key()
	var out: = []
	var cs: = str(V10Comeback.st().scene)
	if cs != "":
		out.append({"id": "comeback", "prio": 100, "kind": "scene", "tier": cs})
	if V10PlayerBday.gift_due(key):
		out.append({"id": "player_bday", "prio": 90, "kind": "scene"})
	if V10Tray.should_show(key):
		out.append({"id": "tray", "prio": 50, "kind": "overlay"})
	return out
