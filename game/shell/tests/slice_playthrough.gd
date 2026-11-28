class_name TWSlice
extends RefCounted

# P37 / WP10d: QA of the vertical slice. The slice = Home -> Match -> Result -> Collection -> Wish -> Shop, driven through the SAME
# doors a finger uses: LegacyHost.open(id) for the v10 screens, TWScreens.go("match") + TWMatchScreen.tap_tile() for the v11 ones, the
# victory modal's own buttons for the way on.
#
#   godot --path game res://shell/main_v11.tscn -- --slice=play  [--slice_games=100]       100 bot games through the screen API
#   godot --path game res://shell/main_v11.tscn -- --slice=goldens --slice_dir=<dir> [--slice_update=1]   6 screens -> PNG / compare
#   godot --path game res://shell/main_v11.tscn -- --slice=perf                            60-tile frame cost (see slice_perf.gd)
#
# `play` prints "SLICE_SELFTEST ok/total" (suite `slice`). A game is a failure when a stage does not finish, a SCRIPT ERROR / engine
# ERROR (other than the two known teardown noises of legacy screens) shows up, or a stage takes more than HANG_S seconds without an event
# (a watchdog node quits the process with the stage name, so a hang is a red line and not a timeout of the whole suite).
#
# Policies of the bot (per game, by index): solver (certificate / twin of a tray tile), hint (TWBoard.hint), random free tile, mixed
# (random + deny taps on covered tiles + undo + shuffle + hint). The bot only calls TWMatchScreen.tap_tile / undo / shuffle / hint and
# TWMatchScreen.view.tile_tapped (the finger's signal); it never touches the board's rules.

const HANG_S: = 10.0
const GAMES_DEFAULT: = 100
const TEARDOWN_NOISE: = ["Lambda capture at index", "Playback can only happen when a node is inside the scene tree"]
const SAVE: = "user://slice_qa_save.json"
const LEGACY_LOOP: = ["home", "collection", "summon", "shop"]   # Home, Collection (wardrobe), Wish (summon), Shop

var h: LegacyHost
var ok: = 0
var total: = 0
var fails: Array = []
var log_: Variant = null
var stage: = ""
var last_beat_ms: = 0
var dog: _Dog = null
var stats: = {"games": 0, "cleared": 0, "failed": 0, "taps": 0, "denied": 0, "modals": 0, "chain": 0, "fast": 0, "next": 0, "map": 0,
	"legacy_opens": 0, "max_stage_ms": 0, "undo": 0, "shuffle": 0, "hint": 0}


class _Dog extends Node:
	var t: TWSlice = null

	func _process(_d: float) -> void:
		if t != null:
			t._watch()


static func run(host: LegacyHost) -> void:
	var mode: = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--slice="):
			mode = a.substr(8)
	var s: = TWSlice.new()
	s.h = host
	match mode:
		"play":
			await s._play()
		"goldens", "tour":
			await TWSliceGoldens.run(s)
		"perf":
			await TWSlicePerf.run(s)
		_:
			printerr("SLICE: unknown mode '%s' (play | goldens | perf)" % mode)
			host.get_tree().quit(2)


static func arg(key: String, default: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.substr(key.length() + 3)
	return default


# ---- plumbing shared by the three modes ------------------------------------------------------------------------------------------

func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		print("SLICE FAIL: ", what)


func beat(what: String) -> void:
	var now: = Time.get_ticks_msec()
	if stage != "":
		stats.max_stage_ms = maxi(int(stats.max_stage_ms), now - last_beat_ms)
	stage = what
	last_beat_ms = now


func _watch() -> void:
	if stage != "" and float(Time.get_ticks_msec() - last_beat_ms) / 1000.0 > HANG_S:
		print("SLICE FAIL: HANG - no event for %.0f s at stage '%s'" % [HANG_S, stage])
		print("SLICE_SELFTEST %d/%d" % [ok, total + 1])
		h.get_tree().quit(1)


func start_dog() -> void:
	log_ = V8Playtest.ErrLog.new()
	OS.add_logger(log_)
	dog = _Dog.new()
	dog.t = self
	dog.name = "SliceWatchdog"
	h.add_child(dog)
	last_beat_ms = Time.get_ticks_msec()


func frames(n: int) -> void:
	for i in n:
		await h.get_tree().process_frame
		last_beat_ms = Time.get_ticks_msec()   # a frame that was drawn is an event (a 1536x2048 software frame can take 0.3 s)


# real script errors since the last call (teardown noise of legacy screens is not counted, like the legacy_host suite)
func errors_since(mark: Array) -> Array:
	var out: = []
	if log_ == null:
		return out
	var se: Array = log_.script_errors
	for i in range(int(mark[0]), se.size()):
		out.append(String(se[i]))
	var er: Array = log_.errors
	for i in range(int(mark[1]), er.size()):
		var noise: = false
		for k in TEARDOWN_NOISE:
			if k in String(er[i]):
				noise = true
		if not noise:
			out.append(String(er[i]))
	return out


func err_mark() -> Array:
	if log_ == null:
		return [0, 0]
	return [log_.script_errors.size(), log_.errors.size()]


# a finished profile (no title card / intro / tutorial in the way), rich enough to open every screen, never the player's save
func prepare_save(frozen_unix: int = 0) -> void:
	G.save_path = SAVE
	G.S.profile_done = true
	G.S.intro_done = true
	G.S.tut_done = true
	G.S.unlocked = mini(40, G.LEVELS.size())
	V10Money.set_balance("gems", 12450)
	V10Money.set_balance("coins", 38200)
	G.S.free10 = true
	h._v6_opt("v6_story.on", false)
	if frozen_unix > 0:
		V10Meta.set_now(frozen_unix)


func match_ctx() -> Dictionary:
	return {"screens": h.tw_screens, "ctx": h.ctx}


# ---- legacy side: Home / Collection / Wish / Shop through the host ----------------------------------------------------------------

func open_legacy(id: String, dwell: int = 4) -> bool:
	beat("open " + id)
	var good: bool = await h.open(id, {})
	await frames(dwell)
	stats.legacy_opens += 1
	return good and h.screen_id == id and h.screen != null and is_instance_valid(h.screen)


# the v11 match screen sits above the legacy chrome; hide what is underneath while it is up (and give it back after)
func hide_legacy(hide: bool) -> void:
	if h.screen_root != null:
		h.screen_root.visible = not hide
	if h.navbar != null:
		h.navbar.visible = not hide and h.screen_id in ["home", "collection", "summon", "shop"]


func go_match(params: Dictionary) -> TWMatchScreen:
	beat("go match")
	hide_legacy(true)
	var res: Variant = await h.tw_screens.go("match", params)
	var m: = h.tw_screens.current as TWMatchScreen
	if m == null or h.tw_screens.current_id != "match":
		return null
	m.view.manual = bool(params.get("manual", true))
	return m


func leave_match() -> void:
	beat("leave match")
	h.tw_screens.reset()
	hide_legacy(false)
	await frames(2)


static func cfg_of(i: int) -> Dictionary:
	# varied but always playable: size of the field, number of faces, specials by game number
	var sizes: = [[6, 8, 3, 0.7], [6, 8, 3, 0.5], [5, 7, 3, 0.62], [6, 9, 3, 0.55], [4, 6, 2, 0.8]]
	var s: Array = sizes[i % sizes.size()]
	var plan: = {}
	if i % 3 == 0:
		plan = {"lock": 1, "lock_n": 1, "chain": 1, "joker": 1, "bomb": 1, "gift": 1}
	return {"cols": s[0], "rows": s[1], "layers": s[2], "fill": s[3], "faces": 8 + (i % 5) * 2, "seed": 1000 + i * 7, "shape": "rect",
		"gold": 3, "ice": i % 3, "hidden": i % 2 == 0, "shard": "rin" if i % 2 == 0 else "", "plan": plan}


static func policy_of(i: int) -> String:
	var k: = i % 10
	if k <= 5:
		return "solver"
	if k <= 7:
		return "hint"
	if k == 8:
		return "random"
	return "mixed"


# one tap of the bot; returns false when it has nothing left to do
func bot_step(m: TWMatchScreen, policy: String, rng: RandomNumberGenerator, step_no: int) -> bool:
	var b: = m.board
	var id: = -1
	match policy:
		"solver":
			id = b.solver_move()
		"hint":
			var hh: Array = m.hint()
			stats.hint += 1
			id = int(hh[0]) if not hh.is_empty() else b.solver_move()
		"random":
			var fr: = b.free_tiles()
			id = int(fr[rng.randi() % fr.size()]) if fr.size() > 0 else -1
		_:
			var r: = rng.randf()
			if r < 0.06 and step_no > 5:
				stats.undo += 1
				m.undo()
				return true
			if r < 0.09:
				stats.shuffle += 1
				m.shuffle()
				return true
			if r < 0.2:
				# a covered tile: the board denies, nothing changes
				var fr2: = b.free_tiles()
				var cand: = -1
				for t in b.n:
					if b.present[t] == 1 and not fr2.has(t):
						cand = t
						break
				if cand >= 0:
					stats.denied += 1
					var before: = b.state_hash()
					m.tap_tile(cand)
					check(b.state_hash() == before or b.failed or b.cleared, "a tap on a covered tile changes nothing (game step %d)" % step_no)
					return true
			if r < 0.55:
				id = b.solver_move()
			else:
				var fr3: = b.free_tiles()
				id = int(fr3[rng.randi() % fr3.size()]) if fr3.size() > 0 else -1
	if id < 0:
		return false
	stats.taps += 1
	if step_no % 5 == 0:
		# the finger's own door: the view's tile_tapped signal -> screen -> board
		m.view.tile_tapped.emit(id)
	else:
		m.tap_tile(id)
	return true


func play_game(i: int, wins: int, realtime: bool) -> Dictionary:
	var policy: = policy_of(i)
	var rng: = RandomNumberGenerator.new()
	rng.seed = 7000 + i
	var facts: = {"wins_before": wins, "partner": "rin", "chapter_has_3star": true}
	var m: = await go_match({"cfg": cfg_of(i), "tile_size": ["S", "M", "L", "XL"][i % 4], "result_facts": facts,
		"round_state": {"partner": "rin"}, "manual": not realtime})
	var out: = {"ok": false, "cleared": false, "failed": false, "kind": "", "taps": 0}
	check(m != null, "game %d: the match screen mounts through TWScreens.go" % i)
	if m == null:
		return out
	var acts: Array = []
	m.result_action.connect(func(a: String, info: Dictionary) -> void: acts.append([a, info]))
	var step_no: = 0
	var stuck: = 0
	while not m.ended and step_no < 500 and stuck < 12:
		beat("game %d bot step %d" % [i, step_no])
		step_no += 1
		var hash0: = m.board.state_hash()
		if not bot_step(m, policy, rng, step_no):
			break
		stuck = stuck + 1 if m.board.state_hash() == hash0 else 0
		if realtime:
			await frames(2)
		else:
			m.view.advance(0.05)
		if step_no % 40 == 0:
			await frames(1)
	m.view.finish()
	await frames(1)
	out.taps = step_no
	out.cleared = m.board.cleared
	out.failed = m.board.failed
	var ended_clean: bool = m.board.cleared or m.board.failed or stuck >= 12 or step_no >= 500
	check(ended_clean, "game %d (%s): the bot reaches an end" % [i, policy])
	if m.board.cleared:
		stats.cleared += 1
		check(m.round_result != null and m.round_result.win, "game %d: TWRound.resolve gave a win" % i)
		check(m.result_modal != null and h.modals.depth() == 1, "game %d: the victory modal is open on the ModalStack, once" % i)
		if m.result_modal != null:
			stats.modals += 1
			var kind: String = String(m.result_modal.plan.kind)
			out.kind = kind
			stats[("chain" if kind == TWResultChain.KIND_CHAIN else "fast")] += 1
			beat("game %d result" % i)
			if kind == TWResultChain.KIND_CHAIN:
				m.result_modal.skip()
			m.result_modal.advance(1.6 if kind != TWResultChain.KIND_CHAIN else 0.1)
			check(m.result_modal.cta_ready() or m.result_modal.cta.visible, "game %d: the button of the result is reachable" % i)
			if i % 2 == 0:
				m.result_modal.cta.pressed.emit()
			else:
				m.result_modal.sec_map.pressed.emit()
			await frames(2)
			check(acts.size() == 1 and h.modals.depth() == 0, "game %d: one result_action and the modal layer is empty (%d actions, depth %d)" % [i, acts.size(), h.modals.depth()])
			if acts.size() == 1:
				stats[String(acts[0][0])] = int(stats.get(String(acts[0][0]), 0)) + 1
	elif m.board.failed:
		stats.failed += 1
		check(m.result_modal == null and h.modals.depth() == 0, "game %d: a lost round opens no victory modal" % i)
	out.ok = true
	await leave_match()
	return out


func _play() -> void:
	var n_games: = int(arg("slice_games", str(GAMES_DEFAULT)))
	var tree: = h.get_tree()
	await tree.process_frame
	prepare_save()
	start_dog()
	check(tree.current_scene == h and h.ctx != null and h.tw_screens != null and h.tw_screens.has_screen("match"), "the v11 host is up with the match screen registered")
	check(h.screen_id == "home", "the host boots into Home")
	var t0: = Time.get_ticks_msec()
	var wins: = 0
	var done: = 0
	var from: = int(arg("slice_from", "0"))
	var verbose: = arg("slice_verbose", "0") == "1"
	for i in range(from, from + n_games):
		if verbose:
			print("SLICE game %d policy %s" % [i, policy_of(i)])
		var mark: = err_mark()
		beat("game %d home" % i)
		var g0: int = total
		var f0: int = fails.size()
		# 1. Home
		check(await open_legacy("home"), "game %d: Home opens through the host" % i)
		# 2. play -> result (a real-time game now and then: the timeline runs on frames, not on advance())
		var res: = await play_game(i, wins, i % 25 == 3)
		if res.cleared:
			wins += 1
		# 3. the way on: Collection, Wish, Shop (a rotation of the three each game, all three every 4th game)
		for id in ["collection", "summon", "shop"]:
			var idx: int = ["collection", "summon", "shop"].find(id)
			if i % 4 == 0 or i % 3 == idx:
				check(await open_legacy(id), "game %d: %s opens through the host" % [i, id])
		var errs: = errors_since(mark)
		check(errs.is_empty(), "game %d: 0 SCRIPT ERROR / engine ERROR (%s)" % [i, str(errs.slice(0, 2))])
		check(h.modals.depth() == 0, "game %d: no modal leaked" % i)
		done += 1
		stats.games += 1
		if done % 10 == 0:
			print("SLICE progress: %d/%d games, %d wins, %d fails so far, %.0f s" % [done, n_games, wins, fails.size(), float(Time.get_ticks_msec() - t0) / 1000.0])
	beat("final")
	check(done == n_games, "%d/%d games played to the end of the loop" % [done, n_games])
	check(stats.cleared >= n_games * 4 / 10, "the bot wins a good share (%d cleared of %d)" % [stats.cleared, n_games])
	check(stats.failed >= 1 or n_games < 20, "the bot also loses some rounds (%d failed)" % stats.failed)
	check(stats.modals == stats.cleared, "every win opened exactly one victory modal (%d modals, %d wins)" % [stats.modals, stats.cleared])
	check(stats.fast >= 1 and (stats.chain >= 1 or n_games < 20), "both victory shapes were met (%d fast, %d chain)" % [stats.fast, stats.chain])
	check(int(stats.max_stage_ms) <= int(HANG_S * 1000.0), "no stage waited more than %.0f s (max %.2f s)" % [HANG_S, float(stats.max_stage_ms) / 1000.0])
	print("SLICE stats: ", JSON.stringify(stats))
	print("SLICE wall: %.1f s for %d games" % [float(Time.get_ticks_msec() - t0) / 1000.0, n_games])
	V10Meta.clear_now()
	print("SLICE_SELFTEST %d/%d" % [ok, total])
	tree.quit(0 if ok == total else 1)
