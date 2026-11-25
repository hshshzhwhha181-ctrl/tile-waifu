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
	app_resumed.connect(func() -> void: V10Money.on_resumed())
	app_paused.connect(func() -> void:
		var g = get_node_or_null("/root/G")
		if g and g.has_method("save"):
			g.save())
	game_ended.connect(func(r: Dictionary) -> void: V10Afisha.on_game_ended(r))
	# meta: at most one full-screen entry scene per launch, offered by the modules, run when the tea house is up
	home_built.connect(func(_h: Node) -> void: V10EntryQueue.run())
	# the W1 shell: Afisha providers (Неделя = турнир недели, партия дня from the 0.9 calendar)
	V10Nav.install()
