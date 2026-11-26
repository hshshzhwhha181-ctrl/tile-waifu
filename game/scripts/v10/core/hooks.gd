extends Node

# V10Hooks — autoload (project.godot [autoload] V10Hooks="*res://scripts/v10/core/hooks.gd", after V7Event).
# The integration bus of 0.10 (docs/0.10-spec.md §2.8, docs/INTEGRATION_0.10.md §3.8): the hot files (play.gd,
# home.gd, summon.gd, main.gd, mode_play.gd, event_play.gd, daily.gd) emit here ONCE; modules connect to the
# signals instead of editing those files.
#
#   game_ended(result) — MODES §7.1 schema: {mode, win, score, stars, time_s, pairs, hero, seed, level, rewards}
#   pair_taken(info)   — {mid, combo, gold, shard, face, mode, partner}
#   screen_shown(id, screen) — main.go() after the screen's build() (music, tutorial, transitions)
#
# No class_name: the autoload name IS the global (a class_name of the same name would clash).

signal pair_taken(info: Dictionary)
signal game_started(cfg: Dictionary)
signal game_ended(result: Dictionary)
signal win_screen(ctx: Dictionary)
signal home_built(home: Node)
signal summon_built(sc: Node)
signal app_resumed
signal app_paused
signal screen_shown(id: String, screen: Node)

# counters (selftests and the playtest read them; never saved)
var counts: = {}
var last: = {}


func _bump(sig: String, payload = null) -> void:
	counts[sig] = int(counts.get(sig, 0)) + 1
	last[sig] = payload


func emit_pair_taken(info: Dictionary) -> void:
	_bump("pair_taken", info)
	pair_taken.emit(info)


func emit_game_started(cfg: Dictionary) -> void:
	_bump("game_started", cfg)
	game_started.emit(cfg)


# result keys missing from a caller are filled with neutral values, so a module can read any of them
func emit_game_ended(result: Dictionary) -> void:
	var r: = {"mode": "path", "win": false, "score": 0, "stars": 0, "time_s": 0.0, "pairs": 0, "hero": "", "seed": 0,
		"level": -1, "rewards": {}}
	r.merge(result, true)
	_bump("game_ended", r)
	game_ended.emit(r)


func emit_win_screen(ctx: Dictionary) -> void:
	_bump("win_screen", ctx)
	win_screen.emit(ctx)


func emit_home_built(home: Node) -> void:
	_bump("home_built")
	home_built.emit(home)


func emit_summon_built(sc: Node) -> void:
	_bump("summon_built")
	summon_built.emit(sc)


func emit_app_resumed() -> void:
	_bump("app_resumed")
	app_resumed.emit()


func emit_app_paused() -> void:
	_bump("app_paused")
	app_paused.emit()


func emit_screen_shown(id: String, screen: Node) -> void:
	_bump("screen_shown", id)
	screen_shown.emit(id, screen)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# economy: the clock skips the sleep, then the day's grants and store receipts are caught up; pause = save now
	app_resumed.connect(func() -> void:
		V10Money.on_resumed()
		if V10Registry.wired("phone"):
			V10Phone.tick())
	app_paused.connect(func() -> void:
		var g = get_node_or_null("/root/G")
		if g and g.has_method("save"):
			g.save())
	game_ended.connect(func(r: Dictionary) -> void:
		V10Afisha.on_game_ended(r)
		if V10Registry.wired("salon") and int(r.get("stars_delta", 0)) > 0:
			V10Salon.notify_stars(int(r.stars_delta))
		if V10Registry.wired("phone") and bool(r.get("win", false)):
			if bool(r.get("first_win_day", false)):
				V10Phone.event({"kind": "first_win"})
			if bool(r.get("combo_rec", false)):
				V10Phone.event({"kind": "combo_record", "combo": int(r.get("max_combo", 0))})
			if bool(r.get("rank_up", false)):
				V10Phone.event({"kind": "rank_up", "rank": str(r.get("rank_title", ""))})
	)
	V10Meta.bus().day_rolled.connect(func(_old: String, _new: String) -> void:
		if V10Registry.wired("phone"):
			V10Phone.tick())
	# meta: at most one full-screen entry scene per launch, offered by the modules, run when the tea house is up
	home_built.connect(func(_h: Node) -> void: V10EntryQueue.run())
	# the W1+W2 shell: Afisha providers, MoreLevel codes, WinStack salon bar + streak/flame/daily ticks
	V10Nav.install()
	if V10Registry.wired("salon"):
		V10WinStack.add_bar("salon", V10WinStack.PRIO_SALON, V10SalonWinBar.build, {
			"modes": ["path"],
			"when": func(_c: Dictionary) -> bool: return V10Nav.salon_open() and not V10Salon.next_goal().is_empty(),
		})
	if V10Registry.wired("rituals"):
		V10WinStack.add_tick("streak", func(_c: Dictionary) -> Dictionary:
			var n: = int(V10Streak.st().get("n", 0))
			return {"icon": "visits", "text": "Серия · %d" % n} if n > 0 else {}, {"order": 0})
	if V10Registry.wired("path"):
		V10WinStack.add_tick("flame", func(_c: Dictionary) -> Dictionary:
			var fl: = V10PathBoosters.flame()
			return {"icon": "star", "text": "Огонёк · %d" % fl} if fl > 0 and int(G.S.get("unlocked", 1)) >= V10PathRules.BOOST_FROM else {},
			{"order": 1, "modes": ["path"]})
		V10WinStack.add_tick("path15", func(_c: Dictionary) -> Dictionary:
			var d: = V10PathState.daily()
			return {"icon": "gem", "text": "Награда · %d/%d" % [int(d.n), V10PathRules.DAILY_FULL]} if bool(d.show) else {},
			{"order": 2, "modes": ["path"]})
