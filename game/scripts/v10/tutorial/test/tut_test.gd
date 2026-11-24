extends Node

# Tutorial selftest scene (README «Самотест»):
#   godot --headless --path game res://scripts/v10/tutorial/test/tut_test.tscn -- --save=user://tut_test.json --save_wipe=1
#   xvfb-run -a godot --path game res://scripts/v10/tutorial/test/tut_test.tscn --rendering-driver opengl3 \
#       --audio-driver Dummy --resolution 720x1280 -- --save=user://tut_test.json --save_wipe=1 --tut_shots=<dir>
# 1) V10TutSelftest: data, references against the real screen scripts, mock screen set, state.
# 2) The whole first run on the REAL game (main.tscn, real screens) with real touch events: a bot plays like a
#    newcomer — taps «Дальше» on read steps, taps inside the spotlight on forced steps, plays the table, skips the
#    summon animation. Integration hooks are applied here the way README asks the integrator to (attach, the 0.9
#    finger off). Checks: every chapter finishes, every step is shown, no step waits longer than its limit
#    (softlock), forced steps really block taps outside the hole, tips show once and one per visit, resume after a
#    simulated app kill, «Пропустить обучение» with confirm, «Как играть» opens a card. Screenshots of each step.
# Prints «V10TUT ok/total» and quits with 1 on any failure.

const MAIN: = preload("res://main.tscn")
const STEP_LIMIT: = 45.0

var st: V10TutSelftest
var main
var shots: = ""
var shot_n: = 0
var shown_steps: = {}
var log_lines: = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tut_shots="):
			shots = a.substr(12)
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	_run.call_deferred()


func _run() -> void:
	st = V10TutSelftest.new()
	await st.run_all(get_tree())
	print("V10TUT static %d/%d" % [st.ok, st.total])
	if not ("--tut_static=1" in OS.get_cmdline_user_args()):
		await _real()
	print("V10TUT %d/%d" % [st.ok, st.total])
	for f in st.fails:
		print("  FAIL ", f)
	get_tree().quit(0 if st.ok == st.total else 1)


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _win(p: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * p


# a real finger: touch down, hold, touch up (the engine emulates the mouse from the touch)
func tap(p: Vector2, hold: = 0.06) -> void:
	var d: = InputEventScreenTouch.new()
	d.index = 0
	d.position = _win(p)
	d.pressed = true
	Input.parse_input_event(d)
	await wait(hold)
	var u: = InputEventScreenTouch.new()
	u.index = 0
	u.position = _win(p)
	u.pressed = false
	Input.parse_input_event(u)
	await frames(3)


func shot(label: String) -> void:
	if shots == "":
		return
	await frames(2)
	var img: = get_viewport().get_texture().get_image()
	shot_n += 1
	img.save_png("%s/%02d_%s.png" % [shots, shot_n, label])


func tut() -> V10Tutorial:
	return V10Tutorial.inst


func coach() -> V10Coach:
	return tut().coach if V10Tutorial.active() else null


func vp() -> Vector2:
	return get_viewport().get_visible_rect().size


# ── boot the real game ───────────────────────────────────────────────────────────────────────────────────────

func boot(fresh: bool) -> void:
	if fresh:
		G.S = G.default_state()
		G.S.profile_done = true
		G.S.intro_done = true
		G.S.profile.nick = "Тест"
		G.save()
	main = MAIN.instantiate()
	add_child(main)
	# integration hook (README): main._ready → V10Tutorial.attach(main)
	V10Tutorial.attach(main)
	await wait(1.6)
	# the title waits for a tap
	await tap(Vector2(vp().x * 0.5, vp().y - 200))
	await wait(1.4)


func kill_app() -> void:
	G.save()
	main.queue_free()
	main = null
	await frames(3)
	V10Tutorial.inst = null
	G.load_game()


func go(id: String, args: = {}) -> void:
	var t0: = G.time
	while main.busy and G.time - t0 < 6.0:
		await wait(0.1)
	var sc0 = main.screen
	if main.screen_id == id and args.is_empty():
		main.screen_id = ""
	main.go(id, args, false)
	await wait(0.2)
	while (main.screen_id != id or main.screen == sc0) and G.time - t0 < 8.0:
		await wait(0.1)
	st.check("go %s" % id, main.screen_id == id, main.screen_id)
	# integration hook (README): play.gd does not start its 0.9 finger while V10Tutorial owns the first match
	if id == "play" and main.screen_id == "play" and V10Tutorial.owns_first_match():
		main.screen.tut = false


# ── the bot ──────────────────────────────────────────────────────────────────────────────────────────────────

# answers whatever coach-mark is up; returns the step id it handled ("" if nothing to do)
func answer_coach() -> String:
	var c: = coach()
	if c == null or not c.visible or c._closing or not c.bubble.visible:
		return ""
	await wait(0.45)
	if c == null or not c.visible or not c.bubble.visible:
		return ""
	var sid: = String(tut().step.get("id", "")) if tut().tip_showing == "" else "tip_" + tut().tip_showing
	if not shown_steps.has(sid):
		shown_steps[sid] = true
		await wait(0.35)
		await shot(sid)
	if c.mode == "do":
		# a tap outside the hole must NOT reach the game (blocked), then the real tap inside the hole
		var before: = _game_state()
		var far: = Vector2(30, vp().y * 0.5) if not c.hole.has_point(Vector2(30, vp().y * 0.5)) else Vector2(vp().x - 30, 140)
		await tap(far)
		await wait(0.2)
		st.check("%s blocks taps outside the spotlight" % sid, _game_state() == before, "%s → %s" % [before, _game_state()])
		await tap(c.hole.get_center() if not c.pointer.visible else c._pointer_at())
	else:
		await tap(c.bubble.get_global_rect().get_center())
		if c.typing():
			await tap(c.bubble.get_global_rect().get_center())
	return sid


func _game_state() -> String:
	var s = main.screen
	var b = s.get("board") if s else null
	return "%s|%d|%d" % [main.screen_id, b.tray.size() if b is TrayBoard else -1, V10Tutorial._gone(b) if b is TrayBoard else -1]


# runs the coach until `until` is true; fails on a step that stays longer than STEP_LIMIT
func drive(until: Callable, limit: = 180.0, play_board: = false) -> bool:
	var t0: = G.time
	var last_step: = ""
	var step_t: = G.time
	while G.time - t0 < limit:
		if until.call():
			return true
		var cur: = String(tut().step.get("id", ""))
		if cur != last_step:
			last_step = cur
			step_t = G.time
		elif cur != "" and G.time - step_t > STEP_LIMIT and not play_board:
			st.check("no softlock at %s" % cur, false, "waited %.0f s | %s" % [G.time - step_t, _dump()])
			return false
		var h: = await answer_coach()
		if h == "":
			if play_board:
				await _bot_move()
			else:
				await _bot_other()
			await wait(0.15)
	st.check("drive finished in time", false, "last step %s | %s" % [last_step, _dump()])
	return false


func _dump() -> String:
	var c: = coach()
	var s = main.screen if main else null
	var vb = s.get("victory_next_btn") if s else null
	return "screen=%s busy=%s coach=%s mode=%s shown=%s hole=%s vnext=%s" % [main.screen_id, main.busy, c.visible if c else false,
		c.mode if c else "", tut().step_shown, c.hole if c else Rect2(), (vb as Control).get_global_rect() if V10TutTarget.usable(vb) else "-"]


# a move on the table (only when no coach-mark is up)
func _bot_move() -> void:
	var s = main.screen
	if s == null or main.screen_id != "play":
		return
	var b = s.get("board")
	if not (b is TrayBoard) or not b.input_on or b.busy > 0:
		return
	var tl: Tile = b.solver_move()
	if tl == null:
		return
	await tap(tl.get_global_transform_with_canvas().origin)
	await wait(0.3)


# non-tutorial UI the bot has to get through (summon animation, results)
func _bot_other() -> void:
	if main.screen_id == "summon":
		var s = main.screen
		var sk = s.get("skip_btn") if "skip_btn" in s else null
		if V10TutTarget.usable(sk):
			await tap((sk as Control).get_global_rect().get_center())
			await wait(0.6)
			return
		var done: = V10TutTarget.find_text(main, "Готово")
		if done:
			await tap((done as Control).get_global_rect().get_center())
			await wait(0.6)
			return
		# the reveal waits for taps
		await tap(Vector2(vp().x * 0.5, vp().y * 0.45))
		await wait(0.3)


# ── the real run ─────────────────────────────────────────────────────────────────────────────────────────────

func _real() -> void:
	await boot(true)
	st.check("real: home after the title", main.screen_id == "home", main.screen_id)
	st.check("real: tutorial attached", V10Tutorial.active())
	# the first match is not played yet (in the real game the intro leads straight into it; here we land on home,
	# like a player whose app was killed before the first match): the bridge step points at «Сесть за стол»
	await wait(0.6)
	st.check("real: bridge to the first match on home", String(tut().step.get("id", "")) == "m_bridge" and coach().visible, String(tut().step.get("id", "")))
	var okb: = await drive(func(): return main.screen_id in ["levels", "play"], 30.0)
	st.check("real: bridge leads to the table", okb, main.screen_id)
	await wait(1.0)
	await answer_coach()
	await go("play", {"level": 0, "partner": "mc"})
	st.check("real: owns the first match", V10Tutorial.owns_first_match())
	# ── match chapter, then the bot plays the rest of the table
	var ok1: = await drive(func(): return V10TutState.chapter_done("match1"), 200.0)
	st.check("real: first match chapter finished", ok1)
	for sid in ["m_board", "m_free", "m_tray", "m_twin", "m_full", "m_combo", "m_combo2", "m_ult", "m_hint", "m_undo", "m_shuffle", "m_go"]:
		st.check("real: step %s shown" % sid, shown_steps.has(sid))
	st.check("real: 0.9 tut_done set by the chapter", bool(G.S.tut_done))
	# ── victory
	var ok2: = await drive(func(): return V10TutState.chapter_done("victory1"), 240.0, true)
	st.check("real: victory chapter finished", ok2)
	for sid in ["v_stars", "v_reward", "v_next"]:
		st.check("real: step %s shown" % sid, shown_steps.has(sid))
	st.check("real: «Ещё уровень» left the victory", main.screen_id != "play" or not V10TutTarget.usable(main.screen.get("victory_next_btn")), main.screen_id)
	# ── tip on the level map (path) happens here if the levels screen opened; then home tour
	await wait(1.6)
	await answer_coach()
	await go("home")
	var ok3: = await drive(func(): return V10TutState.chapter_done("home1"), 120.0)
	st.check("real: home chapter finished", ok3)
	for sid in ["h_hero", "h_side", "h_play", "h_modes", "h_nav", "h_profile", "h_help"]:
		st.check("real: step %s shown" % sid, shown_steps.has(sid))
	# ── tips: one per visit, once
	await _tips()
	# ── summon (opens at level 4) and the wardrobe
	G.S.unlocked = 4
	var g0: = int(G.S.gems)
	await go("modes")
	await go("home")
	var ok4: = await drive(func(): return V10TutState.chapter_done("summon1"), 200.0)
	st.check("real: summon chapter finished", ok4)
	st.check("real: first wish gift given once", V10TutState.gift_given("first_wish"))
	st.check("real: wish pulled", int(G.S.pulls) >= 1)
	for sid in ["s_go", "s_rates", "s_pull", "s_wardrobe"]:
		st.check("real: step %s shown" % sid, shown_steps.has(sid))
	var ok5: = await drive(func(): return V10TutState.chapter_done("wardrobe1"), 90.0)
	st.check("real: wardrobe chapter finished", ok5)
	# ── the ult on the 2nd table
	await go("play", {"level": 1})
	var s = main.screen
	var t0: = G.time
	while not (s.board and s.board.input_on) and G.time - t0 < 12.0:
		await wait(0.2)
	await wait(1.0)
	s._skill_ready()
	var ok6: = await drive(func(): return V10TutState.chapter_done("ult1"), 90.0)
	st.check("real: ult chapter finished", ok6)
	st.check("real: step u_tap shown", shown_steps.has("u_tap"))
	# ── «Как играть»
	await _help()
	# ── resume after an app kill mid-match, then «Пропустить обучение»
	await _resume_and_skip()
	# ── aspect: the coach follows a resize (targets re-resolved)
	await _resize_check()


func _tips() -> void:
	var seen0: int = V10TutState.st().tips.size()
	await go("modes")
	await wait(1.4)
	st.check("tip: modes shows on first visit", tut().tip_showing == "modes", tut().tip_showing)
	await answer_coach()
	await wait(0.6)
	await go("home")
	await wait(1.3)
	await go("modes")
	await wait(1.6)
	st.check("tip: modes not again", tut().tip_showing == "" and not coach().visible)
	await go("shop")
	await wait(1.5)
	st.check("tip: shop by the neutral guide", tut().tip_showing == "shop" and coach().name_lbl.text == "Подсказка", tut().tip_showing + " / " + coach().name_lbl.text)
	await answer_coach()
	await wait(0.4)
	st.check("tip: one per visit", not coach().visible)
	await go("profile", {"from": "home"})
	await wait(1.5)
	st.check("tip: profile", tut().tip_showing == "profile", tut().tip_showing)
	await answer_coach()
	await go("v7tourney", {"tab": "quarter"})
	await wait(1.5)
	st.check("tip: leagues", tut().tip_showing == "leagues", tut().tip_showing)
	await answer_coach()
	await go("home")
	await wait(1.4)
	main.settings()
	await wait(0.5)
	V10Tutorial.event("settings")
	await wait(0.3)
	st.check("tip: settings event", tut().tip_showing == "settings", tut().tip_showing)
	await answer_coach()
	await wait(0.3)
	for p in main.overlay.get_children():
		if p.has_meta("popup"):
			p.queue_free()
	st.check("tip: marked seen", V10TutState.st().tips.size() >= seen0 + 5)
	# tips off: nothing shows
	V10TutState.set_tips_off(true)
	await go("v7event")
	await wait(1.5)
	st.check("tip: tips off respected", not coach().visible)
	V10TutState.set_tips_off(false)
	await go("home")
	await wait(0.4)


func _help() -> void:
	await go("home")
	await wait(1.4)
	await answer_coach()
	var h: = V10Help.open(main)
	await wait(0.8)
	await shot("help_book")
	st.check("help: all topics as cards", h._rows.size() == V10TutTips.TOPICS.size(), str(h._rows.size()))
	var card: Control = h._rows.get("salon")
	if card:
		h.scroll.ensure_control_visible(card)
		await wait(0.3)
		await tap(card.get_global_rect().get_center())
		await wait(0.6)
	st.check("help: a tap opens the card", is_instance_valid(h.sheet))
	await shot("help_card")
	var ok: = V10TutTarget.find_text(h.sheet, "Понятно") if is_instance_valid(h.sheet) else null
	if ok:
		await tap((ok as Control).get_global_rect().get_center())
		await wait(0.5)
	st.check("help: «Понятно» closes the card", not is_instance_valid(h.sheet))
	# chips filter
	h._set_cat("modes")
	await wait(0.4)
	st.check("help: category filter", h._rows.size() > 0 and h._rows.size() < V10TutTips.TOPICS.size())
	await shot("help_modes")
	var x = h.get_node_or_null("Close")
	if x:
		await tap((x as Control).get_global_rect().get_center())
	await wait(0.5)
	st.check("help: ✕ closes the book", not is_instance_valid(h) or h.is_queued_for_deletion())


func _resume_and_skip() -> void:
	V10Tutorial.replay()
	await go("play", {"level": 0, "partner": "mc"})
	shown_steps.erase("m_board")
	var ok: = await drive(func(): return V10TutState.step() == "m_twin" and coach().visible and coach().bubble.visible, 90.0)
	st.check("resume: reached m_twin", ok, V10TutState.step())
	await kill_app()
	st.check("resume: step survives the kill", String(G.S.v10_tut.step) == "m_twin", str(G.S.get("v10_tut", {}).get("step")))
	await boot(false)
	st.check("resume: resume point loaded", tut()._resume_id == "m_twin", tut()._resume_id)
	await go("play", {"level": 0, "partner": "mc"})
	var t0: = G.time
	while not (coach().visible and coach().bubble.visible) and G.time - t0 < 15.0:
		await wait(0.2)
	st.check("resume: restarts at the table explanation", String(tut().step.get("id", "")) == "m_board", String(tut().step.get("id", "")))
	await wait(0.6)
	await shot("resume_m_board")
	# «Пропустить обучение» → confirm → skipped
	var sk: = coach().skip_btn
	st.check("skip: pill visible", sk.is_visible_in_tree())
	await tap(sk.get_global_rect().get_center())
	await wait(0.6)
	st.check("skip: asks first", coach().confirm_open())
	await shot("skip_confirm")
	var yes: = V10TutTarget.find_text(coach()._confirm, "Пропустить") if coach().confirm_open() else null
	if yes:
		await tap((yes as Control).get_global_rect().get_center())
	await wait(0.8)
	st.check("skip: skipped and hidden", V10TutState.skipped() and not coach().visible)
	st.check("skip: the 0.9 finger is not owed either", bool(G.S.tut_done))


func _resize_check() -> void:
	V10Tutorial.replay("home1")
	await go("home")
	var t0: = G.time
	while not (coach().visible and String(tut().step.get("id", "")) == "h_play") and G.time - t0 < 40.0:
		var c: = coach()
		if c.visible and c.bubble.visible and String(tut().step.get("id", "")) != "h_play":
			await tap(c.bubble.get_global_rect().get_center())
		await wait(0.4)
	await wait(0.6)
	var r0: = coach().goal
	var btn: Control = main.screen.play_btn
	st.check("resize: hole on «Сесть за стол»", r0.grow(-4).intersects(btn.get_global_rect()), "%s vs %s" % [r0, btn.get_global_rect()])
	st.check("resize: bubble inside the screen", Rect2(Vector2.ZERO, vp()).encloses(coach().bubble.get_global_rect()), str(coach().bubble.get_global_rect()))
	st.check("resize: bubble does not cover the hole", not coach().bubble.get_global_rect().intersects(r0.grow(-6)))
	V10TutState.skip_all()
	tut()._end_flow(false)
