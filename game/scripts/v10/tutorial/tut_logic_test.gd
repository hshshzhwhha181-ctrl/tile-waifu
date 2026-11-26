extends RefCounted
# Logic checks of the orchestrator (V10Tutorial) and the first-match driver (V10TutMatch). Run from tut_selftest:
#   -- --tut_logic=1                      fake main: gates, one system intro per hub entry, legacy, hints, entry queue
#   -- --tut_l1=1 --story_off=1 --autotap=1 --save=user://tut_l1.json --save_wipe=1
#                                         real main.tscn: plays L1 by tapping the coach window / solver tiles
#                                         (+ --tut_l1_shots=/abs/dir under xvfb: one PNG per step)
# Prints «TUT LOGIC ok n/n» / «TUT L1 ok …», exit code = failures.

class FakeMain extends Control:
	var screen_id: = ""
	var screen: Control
	var busy: = false
	var screen_root: Control
	var overlay: Control

	func _init() -> void:
		size = Vector2(720, 1280)
		screen_root = Control.new()
		add_child(screen_root)
		overlay = Control.new()
		add_child(overlay)

	func show_screen(id: String, tags: Array) -> void:
		if screen != null:
			screen.queue_free()
		screen_id = id
		screen = Control.new()
		screen.size = size
		var y: = 100.0
		for tg in tags:
			var c: = Control.new()
			c.position = Vector2(100, y)
			c.size = Vector2(120, 96)
			c.set_meta("tut_id", tg)
			screen.add_child(c)
			y += 110.0
		screen_root.add_child(screen)


const HOME_TAGS: = ["home.play", "home.phone", "lantern.today", "lantern.salon", "lantern.streak", "nav.teahouse",
	"nav.heroines", "nav.tables", "nav.wishes", "nav.shop"]
const LEVEL_TAGS: = ["tables.play", "nav.tables", "nav.heroines"]

var host: Node
var n: = 0
var bad: = 0


func ok(cond: bool, what: String) -> void:
	n += 1
	if not cond:
		bad += 1
		printerr("TUT LOGIC FAIL ", what)


func frame() -> void:
	await host.get_tree().process_frame


func pump(t: V10Tutorial) -> void:
	await frame()
	t._next_try = 0.0
	t._tick()


func enter(t: V10Tutorial, m: FakeMain, id: String, tags: Array) -> void:
	m.show_screen(id, tags)
	await frame()
	await pump(t)


func close(t: V10Tutorial) -> String:
	var s: = t.step
	if t.coach != null and t.coach.is_showing():
		t.coach.complete("tap")
	return s


func fresh(unlocked: int) -> void:
	V10TutState.test_store = {"unlocked": 1}
	V10TutState.st()
	V10TutState.test_store["unlocked"] = unlocked


# ------------------------------------------------------------------ fake main -----------------------------------------

func run_logic(h: Node) -> int:
	host = h
	var m: = FakeMain.new()
	h.add_child(m)
	fresh(1)
	var t: = V10Tutorial.attach(m)
	t.settle = 0.0
	await frame()
	ok(V10Tutorial.attach(m) == t, "attach is idempotent")
	ok(V10Tutorial.main_node() == m and V10Tutorial.owns_first_match(), "main_node / owns_first_match")

	# fresh player before L1: nothing on home
	await enter(t, m, "home", HOME_TAGS)
	ok(t.step == "", "fresh: no intro before L1 (got %s)" % t.step)
	ok(int(V10TutState.st().entries) == 1, "entries counted")
	ok(V10Reveal.locked_text("tab.shop") == "Откроется после партии 8", "locked text")
	V10Tutorial.locked_tap("tab.shop", Rect2(0, 0, 10, 10))

	# after L1: tables_first on «Столы» ("tables" and "levels"), home_first on the Чайная (one each)
	V10TutState.test_store["unlocked"] = 2
	await enter(t, m, "tables", LEVEL_TAGS)
	ok(close(t) == "tables_first", "after L1: tables_first on tables hub")
	await enter(t, m, "home", HOME_TAGS)
	ok(close(t) == "home_first", "after L1: home_first on home")
	await pump(t)
	ok(t.step == "", "one intro per arrival")
	await enter(t, m, "home", HOME_TAGS)
	ok(t.step == "", "nothing new on the next entry after L1 (got %s)" % t.step)

	# after L2: the salon lantern; after L3: wishes; heroines after L4; phone after L5
	V10TutState.test_store["unlocked"] = 3
	await enter(t, m, "home", HOME_TAGS)
	ok(close(t) == "lantern_salon", "after L2: lantern_salon")
	V10TutState.test_store["unlocked"] = 4
	await enter(t, m, "levels", LEVEL_TAGS)
	ok(t.step == "", "levels after L3: nothing")
	await enter(t, m, "home", HOME_TAGS)
	ok(close(t) == "wishes_first", "after L3: wishes_first")
	V10TutState.test_store["unlocked"] = 5
	ok(not V10Reveal.due_intros("home").has("phone_first"), "phone not due after L4")
	await enter(t, m, "home", HOME_TAGS)
	ok(close(t) == "heroines_first", "after L4: heroines_first (*)")
	V10TutState.test_store["unlocked"] = 6
	await enter(t, m, "home", HOME_TAGS)
	ok(close(t) == "phone_first", "after L5: phone_first")

	# a backlog: at most ONE system intro per hub entry, in prio order
	fresh(7)
	var order: = []
	for i in 8:
		await enter(t, m, "home", HOME_TAGS)
		var sys_n: = 0
		for k in 3:
			var s: = close(t)
			if s != "":
				order.append(s)
				if bool(V10TutLines.INTROS[s].system):
					sys_n += 1
			await pump(t)
		ok(sys_n <= 1, "entry %d: ≤ 1 system intro" % i)
		await enter(t, m, "levels", LEVEL_TAGS)
		var s2: = close(t)
		if s2 != "":
			order.append(s2)
	ok(order.slice(0, 2) == ["home_first", "tables_first"], "backlog order starts home_first, tables_first: %s" % [order])
	for id in ["home_first", "tables_first", "lantern_salon", "wishes_first", "heroines_first", "phone_first", "lantern_today"]:
		ok(order.has(id), "backlog shows %s" % id)
	ok(order.size() == 7, "backlog: 7 intros, no repeats (%d)" % order.size())

	# legacy 0.9 save: only the welcome line
	V10TutState.test_store = {"unlocked": 10, "tut_done": true}
	ok(V10TutState.first_match_done() and bool(V10TutState.st().legacy), "legacy: first match done")
	ok(V10Reveal.due_intros("home") == ["v10_welcome"], "legacy: only v10_welcome due (%s)" % [V10Reveal.due_intros("home")])
	await enter(t, m, "home", HOME_TAGS)
	ok(close(t) == "v10_welcome", "legacy: v10_welcome shown")
	for i in 2:
		await enter(t, m, "levels", LEVEL_TAGS)
		ok(close(t) == "", "legacy: nothing on levels")
		await enter(t, m, "home", HOME_TAGS)
		ok(close(t) == "", "legacy: nothing more on home")

	# hints off: no intros, gates still apply
	fresh(2)
	V10TutState.set_hints(false)
	await enter(t, m, "home", HOME_TAGS)
	ok(t.step == "", "hints off: no intro")
	ok(V10Reveal.is_open("tab.tables") and not V10Reveal.is_open("tab.wishes"), "hints off: gates still apply")

	# target never found: retried on 3 entries, then dropped
	fresh(3)
	V10TutState.mark("home_first")
	for i in 3:
		await enter(t, m, "home", ["home.play"])
		ok(t.step == "", "missing lantern: no intro (try %d)" % (i + 1))
		await pump(t)
	ok(V10TutState.seen("lantern_salon"), "missing target: dropped after 3 entries")

	# the entry queue showed a full-screen scene on this launch: the intro waits for the next entry
	fresh(2)
	V10EntryQueue.new_launch()
	V10EntryQueue.offer("comeback", "tut_test", func(): pass)
	V10EntryQueue.run()
	t._eq_seen = false
	await enter(t, m, "home", HOME_TAGS)
	ok(t.step == "", "entry queue scene: intro postponed")
	await enter(t, m, "home", HOME_TAGS)
	ok(close(t) == "home_first", "entry queue: intro on the next entry")
	V10EntryQueue.new_launch()

	# main.busy / a popup hold the intro back
	fresh(2)
	m.busy = true
	await enter(t, m, "home", HOME_TAGS)
	ok(t.step == "", "busy: no intro")
	m.busy = false
	var pop: = Control.new()
	pop.set_meta("popup", true)
	m.overlay.add_child(pop)
	await pump(t)
	ok(t.step == "", "popup: no intro")
	pop.free()
	await pump(t)
	ok(close(t) == "home_first", "intro after busy / popup")

	# replay: «Показать в игре» shows it again right here
	V10Tutorial.replay("home_first")
	await pump(t)
	ok(close(t) == "home_first", "replay shows on the current screen")

	# watchdog: a coach that never finishes is closed
	V10Tutorial.say("Тестовая реплика.", "home.play")
	await pump(t)
	ok(t.step == "say" and V10Tutorial.busy(), "say() shows a line")
	t._deadline = 0.001
	await pump(t)
	ok(t.step == "" and not V10Tutorial.busy(), "watchdog closes a stuck step")

	# events
	V10Tutorial.event("salon_done")
	ok(V10TutState.seen("lantern_salon"), "salon_done marks lantern_salon")
	V10TutState.mark("m_a")
	V10Tutorial.event("replay_first_match", {"go": false})
	ok(V10TutMatch.replay_l1 and not V10TutState.seen("m_a"), "replay_first_match: flag + guided steps unmarked")
	V10TutMatch.replay_l1 = false

	# chapters_enabled = false pauses auto intros while keeping owns_first_match false
	fresh(2)
	V10Tutorial.chapters_enabled = false
	ok(not V10Tutorial.owns_first_match(), "chapters_enabled=false -> owns_first_match false")
	await enter(t, m, "home", HOME_TAGS)
	ok(t.step == "", "chapters_enabled=false: no auto intro")
	V10Tutorial.chapters_enabled = true
	ok(V10Tutorial.owns_first_match(), "chapters_enabled=true -> owns_first_match true")
	await pump(t)
	ok(close(t) == "home_first", "chapters_enabled=true: intro resumes")

	# skip
	V10Tutorial.skip_all()
	ok(V10TutState.skipped() and not V10TutState.hints_on() and V10TutState.first_match_done(), "skip_all")

	print("TUT LOGIC %s %d/%d" % ["ok" if bad == 0 else "fail", n - bad, n])
	V10TutState.test_store = null
	m.queue_free()
	return bad


# ------------------------------------------------------------------ real main, L1 -------------------------------------

func _win(p: Vector2) -> Vector2:
	return host.get_tree().root.get_final_transform() * p


func tap(p: Vector2) -> void:
	var d: = InputEventScreenTouch.new()
	d.index = 0
	d.position = _win(p)
	d.pressed = true
	Input.parse_input_event(d)
	await host.get_tree().create_timer(0.07).timeout
	var u: = InputEventScreenTouch.new()
	u.index = 0
	u.position = _win(p)
	u.pressed = false
	Input.parse_input_event(u)
	await frame()
	await frame()


func wait(s: float) -> void:
	await host.get_tree().create_timer(s).timeout


func rect_of_step(t: V10Tutorial) -> Rect2:
	var r: = t.coach.current_rect()
	if r.size.x < 2.0:
		var tg: = String(t.coach.spec.get("target", ""))
		if tg != "":
			r = V10TutTarget.find(t.main, tg).rect
	return r


func _advance_story(h: Node, m: Node, t: V10Tutorial) -> bool:
	for holder in [h, m, h.get_tree().current_scene]:
		if holder == null or not is_instance_valid(holder):
			continue
		for ch in holder.get_children():
			if ch is V6StoryScene and (ch as CanvasItem).visible and not ch.is_queued_for_deletion():
				ok(t._hard_blocked(), "story scene blocks tutorial overlay")
				(ch as V6StoryScene).skipping = true
				(ch as V6StoryScene).tapped = true
				return true
	return false


func run_l1(h: Node) -> int:
	host = h
	V10TutState.test_store = null
	V10Tutorial.shown.clear()
	V10TutMatch.trace.clear()
	V10TutMatch.victory_pending = false
	V10Tutorial.chapters_enabled = true
	G.S = G.default_state().duplicate(true)
	G.S.intro_done = true
	G.S.profile_done = true
	V10TutState.st()
	G.S.tut_done = true   # play.gd's 0.9 finger stays off (the integrator gates it with owns_first_match())
	G.demo = false
	var m: Node = load("res://main.tscn").instantiate()
	h.get_tree().root.add_child.call_deferred(m)
	await frame()
	await frame()
	var keep_nodes: = [m.get("screen_root"), m.get("topbar"), m.get("navbar"), m.get("overlay"), m.get("trans"), m.get("finger")]
	for ch in m.get_children():
		if not (ch in keep_nodes):
			ch.queue_free()
	await frame()
	var t: = V10Tutorial.attach(m)
	ok(V6Story.seen("intro"), "attach synced story intro_done -> V6Story.seen('intro')")
	await wait(0.4)
	m.call("go", "play", {"level": 0, "partner": "mc"}, false)
	var t0: = Time.get_ticks_msec()
	var seen_steps: = []
	var stuck: = 0.0
	var last_step: = ""
	var shots: = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tut_l1_shots="):
			shots = a.substr(15)
			DirAccess.make_dir_recursive_absolute(shots)
	while Time.get_ticks_msec() - t0 < 90000:
		await wait(0.2)
		if _advance_story(h, m, t):
			await wait(0.4)
			continue
		var sid: = String(m.get("screen_id"))
		if t.step != "" and not seen_steps.has(t.step):
			seen_steps.append(t.step)
			if t.coach != null and t.coach.has_method("debug_state"):
				var ds: Dictionary = t.coach.call("debug_state")
				if String(ds.get("line", "")) != "":
					ok(int(ds.get("lines", 0)) <= 2, "live %s ≤ 2 lines (got %d)" % [t.step, int(ds.get("lines", 0))])
			if shots != "":
				await wait(0.5)
				var img: = host.get_viewport().get_texture().get_image()
				img.save_png("%s/l1_%02d_%s.png" % [shots, seen_steps.size(), t.step])
		if sid == "home" and V10TutState.first_match_done():
			if t.step == "home_first":
				var ds_h: Dictionary = t.coach.debug_state()
				for av in t._face_avoid():
					ok(not (ds_h.text_rect as Rect2).intersects(av), "home_first clears face_rect+48")
				close(t)
				break
			continue
		var scr = m.get("screen")
		if t.step in ["m_a", "m_b", "m_ult", "v_home", "ring"]:
			if t.step == last_step:
				stuck += 0.2
			last_step = t.step
			var r: = rect_of_step(t)
			if r.size.x > 2.0:
				await tap(r.get_center())
				await wait(0.25)
			if stuck > 5.0 and t.coach.is_showing():
				t.coach.complete("tap")
				stuck = 0.0
			continue
		stuck = 0.0
		last_step = t.step
		if t.step in ["m_left", "m_tray", "m_free", "m_danger", "v_stars", "m_fail", "say"] or t.step.begins_with("match_"):
			await wait(0.45)
			if t.coach.is_showing():
				await tap(Vector2(64, 64))
				if t.coach.is_showing():
					t.coach.complete("tap")
			continue
		if sid != "play" or scr == null:
			continue
		var d: = V10TutMatch.inst
		if d != null and is_instance_valid(d) and d.l1 and (d.phase == "start" or not d._queue.is_empty() \
				or V10TutMatch._now() < d._gap_until + 0.25):
			continue
		var b = scr.get("board")
		if b == null or not bool(b.input_on):
			if scr.get("fail_retry_btn") != null and is_instance_valid(scr.get("fail_retry_btn")) and (scr.get("fail_retry_btn") as Control).is_visible_in_tree():
				await tap((scr.get("fail_retry_btn") as Control).get_global_rect().get_center())
			continue
		if bool(scr.get("skill_ready")) and not V10TutState.seen("m_ult"):
			continue
		var mv = b.solver_move()
		if mv != null:
			await tap((mv as Node2D).get_global_transform_with_canvas().origin)
	for k in ["m_a", "m_b", "m_left", "m_free", "m_tray", "v_stars", "v_home", "home_first"]:
		ok(V10Tutorial.shown.has(k), "L1 showed %s" % k)
	for k in ["l1_start", "first_pair", "l1_win"]:
		ok(V10TutState.funnel(k) >= 0, "funnel %s" % k)
	ok(V10TutState.first_match_done(), "first match done")

	# Live navigation & staged reveals on real W1 5-tab main.gd
	t.settle = 0.0
	m.call("go", "tables", {}, false)
	await wait(0.15)
	await pump(t)
	ok(close(t) == "tables_first", "live tables_hub: tables_first resolves PlayPath")

	G.S.unlocked = 4
	G.S.first_pick = "rin"
	m.call("go", "collection", {}, false)
	await wait(0.15)
	await pump(t)
	ok(t.step in ["heroines_first", "heroines_partner"], "live collection: heroines coach (%s)" % t.step)
	close(t)

	# Settings «Как играть» closes Settings popup first (П-6: never window-over-window)
	m.call("go", "home", {}, false)
	await wait(0.15)
	close(t)
	m.call("settings")
	await frame()
	var pop_panel: Control = null
	for ch in (m.get("overlay") as Node).get_children():
		for sub in ch.get_children():
			if sub is Control and sub.has_meta("root"):
				pop_panel = sub as Control
				break
	ok(pop_panel != null, "live settings popup opened")
	if pop_panel != null:
		var hbtn: Control = V10Help.settings_hook(m, pop_panel)
		ok(hbtn != null, "settings_hook added HowToPlay")
		if hbtn != null:
			hbtn.emit_signal("pressed")
			await frame()
			ok(V10TutHelp.current() != null, "HowToPlay opened V10TutSheet")
			ok(not t._popup_open(), "П-6: Settings popup closed before sheet (no window-over-window)")
			V10Help.close_all(m)
			await wait(0.25)

	print("TUT L1 %s %d/%d" % ["ok" if bad == 0 else "fail", n - bad, n])
	m.queue_free()
	await frame()
	return bad
