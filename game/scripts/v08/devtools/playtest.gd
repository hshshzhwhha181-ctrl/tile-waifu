class_name V8Playtest
extends Node

# 0.8 playtest runner: plays the game like a person, with touch input at node centres, and screenshots
# every step.
#   godot --path . -- --pt=fresh --shots=/abs/dir [--save=user://pt_save.json]
# The save is always a separate file (user://pt_save.json unless --save= is given) and is wiped first,
# so a run never touches the real save. See G._ready.
# Scenario "fresh": title → player card (type a nick, pick an avatar, «Играть офлайн») → intro → level 1-1
# played to a win with real taps → victory → home, then every screen: profile (+ recovery code), modes,
# daily calendar, levels (plays 1-2 and 1-3, which opens Желания), summon (one free pull), wardrobe, shop,
# tasks, visits, letters, tournament (quarter, a player card, week), league card, event, room, plus the
# Android «назад» key on a popup and on a screen.
# 0.9 adds: an ult cast in a Path level (shots during the cut-in), the 3-stage summon (lantern, lit, caption, deal,
# showcase), taps on the live heroine's zones at home (head / hand / outfit / room), the letters screen, and
# «Эффекты» switched to «Минимум» and back to «Полные» from the settings.
# Ends with "PT OK <n steps>" (exit 0) or "PT FAIL <step> <reason>" (exit 1). Any SCRIPT ERROR fails the run.

const NOISE: = ["custom_samplers", "Error calling deferred method", "ObjectDB instances", "resources still in use",
	"Pages in use", "leaked at exit"]
const NICK: = "Чайный Гость"
const TIMEOUT: = 900.0


class ErrLog extends Logger:
	var mutex: = Mutex.new()
	var script_errors: Array = []
	var errors: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var msg: = "%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function]
		for n in V8Playtest.NOISE:
			if n in msg:
				return
		mutex.lock()
		if error_type == ERROR_TYPE_SCRIPT:
			script_errors.append(msg)
		elif error_type == ERROR_TYPE_ERROR:
			errors.append(msg)
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var main
var dir: = ""
var scenario: = "fresh"
var n: = 0
var step: = "start"
var elog: ErrLog
var t_start: = 0.0
var touch_miss: = 0
var notes: Array = []
var _done: = false
var ult_casts: = 0


static func start(m, args: Dictionary) -> V8Playtest:
	var pt: = V8Playtest.new()
	pt.main = m
	pt.dir = String(args.get("shots", ""))
	pt.scenario = String(args.get("pt", "fresh"))
	pt.name = "V8Playtest"
	m.add_child(pt)
	return pt


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	elog = ErrLog.new()
	OS.add_logger(elog)
	t_start = Time.get_ticks_msec() / 1000.0
	print("PT start scenario=%s save=%s shots=%s" % [scenario, G.save_path, dir])
	_run.call_deferred()


func _process(_dt: float) -> void:
	if not _done and Time.get_ticks_msec() / 1000.0 - t_start > TIMEOUT:
		_finish(false, "global timeout %ds" % int(TIMEOUT))


func _run() -> void:
	var err: = ""
	match scenario:
		"fresh":
			err = await _fresh()
		_:
			err = "unknown scenario '%s'" % scenario
	if _done:
		return
	_finish(err == "", err)


func _finish(ok: bool, reason: String) -> void:
	if _done:
		return
	_done = true
	elog.mutex.lock()
	var se: = elog.script_errors.duplicate()
	var ee: = elog.errors.duplicate()
	elog.mutex.unlock()
	for e in ee:
		print("PT error: %s" % e)
	for e in se:
		print("PT script error: %s" % e)
	for s in notes:
		print("PT note: %s" % s)
	if ok and not se.is_empty():
		ok = false
		reason = "%d SCRIPT ERROR(s), first: %s" % [se.size(), se[0]]
	if ok:
		print("PT OK %d steps (%.0f s, touch misses %d)" % [n, Time.get_ticks_msec() / 1000.0 - t_start, touch_miss])
	else:
		print("PT FAIL %s %s" % [step, reason])
		await shot("FAIL")
	OS.remove_logger(elog)
	get_tree().quit(0 if ok else 1)


# ------------------------------------------------------------------------------------- primitives

func wait(s: float) -> void:
	await get_tree().create_timer(s, true).timeout

func frames(k: = 2) -> void:
	for i in k:
		await get_tree().process_frame

func until(cond: Callable, timeout: float) -> bool:
	var t0: = Time.get_ticks_msec() / 1000.0
	while not _done:
		if cond.call():
			return true
		if Time.get_ticks_msec() / 1000.0 - t0 > timeout:
			return false
		await get_tree().process_frame
	return false

func shot(label: String) -> void:
	n += 1
	print("PT STEP %02d %s  [%s]" % [n, label, step])
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%02d_%s.png" % [dir, n, label])

func _win(p: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * p

# a finger tap: touch down, short hold, touch up (the engine emulates the mouse from touch)
func tap(p: Vector2, hold: = 0.07) -> void:
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

func pos_of(c: CanvasItem) -> Vector2:
	if c is Control:
		return (c as Control).get_global_rect().get_center()
	return (c as Node2D).get_global_transform_with_canvas().origin

func on_screen(c: CanvasItem) -> bool:
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return false
	var vr: = Rect2(Vector2.ZERO, Vector2(main.W, main.H))
	return vr.has_point(pos_of(c))

func tap_node(c: CanvasItem, what: String) -> String:
	if not on_screen(c):
		return "%s is not on screen" % what
	await tap(pos_of(c))
	return ""

func swipe(from: Vector2, to: Vector2, dur: = 0.35) -> void:
	var d: = InputEventScreenTouch.new()
	d.index = 0
	d.position = _win(from)
	d.pressed = true
	Input.parse_input_event(d)
	var k: = 12
	var prev: = from
	for i in k:
		await wait(dur / k)
		var p: = from.lerp(to, float(i + 1) / k)
		var m: = InputEventScreenDrag.new()
		m.index = 0
		m.position = _win(p)
		m.relative = p - prev
		m.velocity = (p - prev) / (dur / k)
		Input.parse_input_event(m)
		prev = p
	var u: = InputEventScreenTouch.new()
	u.index = 0
	u.position = _win(to)
	u.pressed = false
	Input.parse_input_event(u)
	await frames(3)

# mouse wheel over a ScrollContainer (no touch-drag scrolling on desktop builds)
func wheel(p: Vector2, clicks: int) -> void:
	for i in absi(clicks):
		for pressed in [true, false]:
			var e: = InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_WHEEL_DOWN if clicks > 0 else MOUSE_BUTTON_WHEEL_UP
			e.pressed = pressed
			e.factor = 1.0
			e.position = _win(p)
			e.global_position = _win(p)
			Input.parse_input_event(e)
		await frames(1)
	await wait(0.25)

func type_text(s: String) -> void:
	for ch in s:
		for pressed in [true, false]:
			var k: = InputEventKey.new()
			k.pressed = pressed
			k.unicode = ch.unicode_at(0)
			k.keycode = KEY_SPACE if ch == " " else KEY_NONE
			Input.parse_input_event(k)
		await wait(0.05)

func key(code: Key) -> void:
	for pressed in [true, false]:
		var k: = InputEventKey.new()
		k.pressed = pressed
		k.keycode = code
		k.physical_keycode = code
		Input.parse_input_event(k)
		await frames(1)
	await frames(2)

func find(root: Node, pred: Callable) -> Node:
	if root == null:
		return null
	for c in root.get_children():
		if pred.call(c):
			return c
		var r: = find(c, pred)
		if r:
			return r
	return null

func find_label(root: Node, text: String) -> Label:
	return find(root, func(c): return c is Label and text in (c as Label).text and on_screen(c)) as Label

func find_button(root: Node, text: String) -> JButton:
	return find(root, func(c): return c is JButton and (c as JButton).lbl != null and text in (c as JButton).lbl.text and on_screen(c)) as JButton

func tap_text(root: Node, text: String) -> String:
	var l: = find_label(root, text)
	if l == null:
		return "no visible «%s»" % text
	await tap(pos_of(l))
	return ""

func tap_button(root: Node, text: String) -> String:
	var b: = find_button(root, text)
	if b == null:
		return "no button «%s»" % text
	await tap(pos_of(b))
	return ""

func popup() -> RBox:
	return main._top_popup()

# × of the top Common.popup
func close_popup() -> String:
	var p: = popup()
	if p == null:
		return "no popup to close"
	var x: JButton = null
	for c in p.get_children():
		if c is JButton and (c as JButton).lbl == null and c.size == Vector2(64, 64):
			x = c
	if x == null:
		return "popup has no ×"
	await tap(pos_of(x))
	await until(func(): return popup() != p, 2.0)
	await wait(0.3)
	return ""

func header() -> V8Header:
	return find(main.screen, func(c): return c is V8Header) as V8Header

func header_back() -> String:
	var h: = header()
	if h == null or h.back_btn == null:
		return "screen %s has no V8Header back" % main.screen_id
	var sid: String = main.screen_id
	await tap(pos_of(h.back_btn))
	if not await until(func(): return main.screen_id != sid and not main.busy, 6.0):
		return "header back did not leave %s" % sid
	await wait(0.9)
	return ""

# wait for a screen; story scenes that play on the way (V6Story.before_go) are tapped through
func on(id: String, timeout: = 8.0) -> String:
	var t0: = Time.get_ticks_msec() / 1000.0
	while not _done:
		if story_scene() != null:
			await story()
			t0 = Time.get_ticks_msec() / 1000.0
		if main.screen_id == id and not main.busy and main.screen != null:
			break
		if Time.get_ticks_msec() / 1000.0 - t0 > timeout:
			return "expected screen %s, got %s" % [id, main.screen_id]
		await get_tree().process_frame
	await wait(0.3)
	await story()
	await wait(0.7)
	return ""

# poll pred() -> Node until it returns one
func wait_find(pred: Callable, timeout: float) -> Node:
	var t0: = Time.get_ticks_msec() / 1000.0
	while not _done:
		var r = pred.call()
		if r != null:
			return r
		if Time.get_ticks_msec() / 1000.0 - t0 > timeout:
			return null
		await get_tree().process_frame
	return null

# full-screen views added straight to main (title, story) — not the game screen or the HUD
func _top_views() -> Array:
	var out: = []
	for c in main.get_children():
		if c in [main.screen_root, main.topbar, main.navbar, main.overlay, main.trans, main.finger, self]:
			continue
		out.append(c)
	return out

func story_scene() -> Control:
	var root: = get_tree().current_scene
	for c in root.get_children():
		if c is V6StoryScene and not c.is_queued_for_deletion():
			return c
	return null

# tap through a story scene if one is showing (screenshots of the first lines)
func story(label: = "story", max_shots: = 2, pause: = 0.9) -> int:
	var k: = 0
	var guard: = 0
	await frames(2)
	while story_scene() != null and guard < 80:
		guard += 1
		await wait(pause)
		if story_scene() == null:
			break
		if k < max_shots:
			await shot("%s_%d" % [label, k + 1])
		k += 1
		await tap(Vector2(main.W * 0.5, main.H * 0.55))
	return k

func go_tab(id: String) -> String:
	var e: = await tap_node(main.tab_nodes[id], "tab " + id)
	if e != "":
		return e
	return await on(id)


# ------------------------------------------------------------------------------------- scenario

func _fresh() -> String:
	var e: = ""
	# ---- title
	step = "title"
	if G.S.get("profile_done", false) or G.S.get("intro_done", false):
		return "save is not fresh (%s)" % G.save_path
	var tap_text_s: = V6Txt.s("title.tap")
	var splash: Label = await wait_find(func():
		for v in _top_views():
			var l: = find(v, func(c): return c is Label and (c as Label).text == tap_text_s and on_screen(c))
			if l:
				return l
		return null, 6.0)
	if splash == null:
		return "title has no «%s»" % tap_text_s
	await wait(1.4)
	await shot("title")
	await tap(pos_of(splash))
	# ---- player card
	step = "card"
	var card: V8ProfileCard = await wait_find(func(): return find(main, func(c): return c is V8ProfileCard), 6.0)
	if card == null:
		return "player card did not open"
	await wait(1.0)
	await shot("card")
	await tap(pos_of(card.nick_le))
	if not card.nick_le.has_focus():
		return "nick field did not take focus on tap"
	await type_text(NICK)
	await wait(0.2)
	if card.nick_le.text != NICK:
		return "typed nick reads «%s»" % card.nick_le.text
	var slot: float = card.avatars.size.x / G.HERO_ORDER.size()
	var ri: = G.HERO_ORDER.find("rin")
	await tap(card.avatars.get_global_rect().position + Vector2(slot * (ri + 0.5), 60))
	await wait(0.4)
	if card.avatar != "rin":
		return "avatar tap did not select Rin (avatar=%s)" % card.avatar
	await shot("card_filled")
	await tap(pos_of(card.play_btn))
	if not await until(func(): return bool(G.S.get("profile_done", false)), 3.0):
		return "«Играть офлайн» did not save the profile"
	if G.nick() != NICK or str(G.profile().avatar) != "rin":
		return "profile saved as %s/%s" % [G.nick(), G.profile().avatar]
	# ---- intro
	step = "intro"
	if not await until(func(): return story_scene() != null, 5.0):
		return "intro did not start"
	var lines: = await story("intro", 4, 2.6)
	if lines != 3:
		notes.append("intro took %d taps (spec: 3 lines)" % lines)
	# ---- level 1-1
	step = "level1"
	e = await play_level("lv1", true)
	if e != "":
		return e
	var play = main.screen
	if play.victory_summon_btn == null:
		return "victory has no home button"
	await tap(pos_of(play.victory_summon_btn))
	# ---- home
	step = "home"
	e = await on("home", 10.0)
	if e != "":
		return e
	await wait(1.5)
	await dismiss_popups("home")
	await shot("home")
	# ---- profile from the top bar
	step = "profile"
	await tap(Vector2(190, 62))
	e = await on("profile")
	if e != "":
		return e
	await shot("profile")
	var sc: ScrollContainer = main.screen.scroll
	await wheel(sc.get_global_rect().get_center(), 6)
	await shot("profile_scroll")
	await wheel(sc.get_global_rect().get_center(), 30)
	await shot("profile_bottom")
	e = await tap_button(main.screen, "Показать код")
	if e != "":
		return e
	await wait(0.8)
	if popup() == null:
		return "recovery code popup did not open"
	await shot("profile_code")
	e = await close_popup()
	if e != "":
		return e
	e = await tap_button(main.screen, "Настройки")
	if e != "":
		return e
	await wait(0.8)
	if popup() == null:
		return "settings did not open from the profile"
	await shot("settings")
	# Android «назад» closes the popup
	step = "android_back_popup"
	await key(KEY_ESCAPE)
	if not await until(func(): return popup() == null, 2.0):
		return "Android back did not close the settings popup"
	await wait(0.3)
	step = "profile_back"
	e = await header_back()
	if e != "":
		return e
	if main.screen_id != "home":
		return "profile back went to %s" % main.screen_id
	# ---- 0.10: «Столы» (tab) → the Path scroll → the map → the level card → partner → 1-2
	step = "tables"
	e = await go_tab("tables")
	if e != "":
		return e
	await wait(0.8)
	await shot("tables")
	var hub = main.screen
	if hub.play_btn == null or not on_screen(hub.play_btn):
		return "«Столы» has no «Играть»"
	step = "levels"
	e = await tap_node(hub.scroll_plate, "«Столы» Path scroll")
	if e != "":
		return e
	e = await on("levels")
	if e != "":
		return e
	await wait(1.5)
	await shot("levels")
	e = await tap_node(main.screen.play_btn, "levels play")
	if e != "":
		return e
	await wait(0.9)
	if popup() == null:
		return "level card did not open"
	await shot("level_card")
	e = await tap_button(popup(), "Сесть за стол")
	if e != "":
		return e
	e = await partner_go("lv2")
	if e != "":
		return e
	step = "level2"
	e = await play_level("lv2", true)
	if e != "":
		return e
	# 0.10 (meta V10WinPanel): «Ещё уровень · 3» goes straight to the next table
	step = "more_level"
	if main.screen.victory_next_btn == null or str(main.screen.victory_next_btn.name) != "MoreLevel":
		return "the Path win has no «Ещё уровень» (MoreLevel)"
	await shot("lv2_more_level")
	var lv2_screen = main.screen
	await tap(pos_of(main.screen.victory_next_btn))
	if not await until(func(): return main.screen != lv2_screen and main.screen_id == "play", 10.0):
		return "«Ещё уровень» did not start the next table (on %s)" % main.screen_id
	step = "level3"
	e = await play_level("lv3", false)
	if e != "":
		return e
	# ---- summon unlock → Желания
	step = "summon"
	play = main.screen
	if not await until(func(): return play.unlock_go_btn != null and on_screen(play.unlock_go_btn), 12.0):
		return "summon unlock window did not appear after 1-3"
	await wait(1.0)
	await shot("summon_unlocked")
	await tap(pos_of(play.unlock_go_btn))
	e = await on("summon", 10.0)
	if e != "":
		return e
	await wait(0.8)
	await shot("summon")
	var sm = main.screen
	if sm.pull10_btn and on_screen(sm.pull10_btn):
		await tap(pos_of(sm.pull10_btn))
		# 0.9 §E stage 1: the lantern drops in dark; a tap on it lights it
		step = "summon_lantern"
		if not await until(func(): return sm.stage == "lantern" and sm.lantern != null and is_instance_valid(sm.lantern), 8.0):
			return "the summon lantern never dropped in (stage «%s»)" % sm.stage
		await wait(1.2)
		await shot("summon_lantern")
		await tap(sm.seq.get_global_rect().position + sm.lantern.centre())
		if not await until(func(): return sm.stage != "lantern", 3.0):
			return "a tap on the lantern did not light it"
		# stage 2: the colour climbs to the best rarity, then its caption
		step = "summon_climb"
		await wait(0.6)
		await shot("summon_lit")
		if not await until(func(): return sm.stage != "climb" or (sm.lantern_cap != null and is_instance_valid(sm.lantern_cap)), 12.0):
			return "the lantern never reached its colour"
		await wait(0.7)
		await shot("summon_caption")
		# stage 3: the cards come out of the light and flip (an SSR rises into the showcase)
		step = "summon_cards"
		if not await until(func(): return sm.stage in ["deal", "results"], 10.0):
			return "the cards were never dealt (stage «%s»)" % sm.stage
		await wait(1.0)
		await shot("summon_deal")
		var t0: = Time.get_ticks_msec()
		var sc_shots: = 0
		var flip_shot: = false
		while Time.get_ticks_msec() - t0 < 45000 and not (sm.results_shown and not sm.flipping):
			if sm.showcase != null and is_instance_valid(sm.showcase) and sm.showcase.is_inside_tree() and not sm.showcase.is_queued_for_deletion():
				await wait(1.3)
				if sc_shots < 2:
					sc_shots += 1
					await shot("summon_showcase%d" % sc_shots)
				await tap(Vector2(main.W * 0.5, main.H * 0.55))
				await until(func(): return sm.showcase == null or not is_instance_valid(sm.showcase) or sm.showcase.is_queued_for_deletion(), 3.0)
				continue
			await wait(0.5)
			if not flip_shot and Time.get_ticks_msec() - t0 > 2200:
				flip_shot = true
				await shot("summon_flip")
			if Time.get_ticks_msec() - t0 > 6000:
				await tap(Vector2(main.W * 0.5, main.H * 0.55))
		step = "summon"
		if not sm.results_shown:
			return "10-pull results never showed"
		await wait(1.0)
		await shot("summon_results")
		step = "android_back_summon"
		await key(KEY_ESCAPE)
		await wait(1.2)
		if sm.seq and is_instance_valid(sm.seq) and sm.results_shown:
			return "Android back did not close the pull results"
	else:
		notes.append("summon: no free 10-pull button")
	# ---- Героини, Лавка (closed until L8: the tab denies and says when; the screen itself still renders)
	step = "collection"
	e = await go_tab("collection")
	if e != "":
		return e
	await shot("collection")
	step = "shop_locked"
	if V10Nav.tab_open("shop"):
		notes.append("Лавка is open at unlocked=%d" % int(G.S.unlocked))
	else:
		e = await tap_node(main.tab_nodes["shop"], "tab shop (closed)")
		if e != "":
			return e
		await wait(0.5)
		if main.screen_id == "shop":
			return "the closed Лавка tab opened the shop before L8"
		await shot("shop_locked")
	step = "shop"
	main.go("shop")
	e = await on("shop")
	if e != "":
		return e
	await wait(0.8)
	await shot("shop")
	await swipe(Vector2(360, 1000), Vector2(360, 500), 0.4)
	await wait(0.8)
	await shot("shop_scroll")
	# ---- home again (0.10: no offer before L8, UX §3.5 / О-3)
	step = "home2"
	e = await go_tab("home")
	if e != "":
		return e
	if await until(func(): return popup() != null, 3.0):
		await shot("home_offer")
		return "an offer popped up on the tea house before L8"
	await shot("home2")
	step = "home_touch"
	e = await home_touch()
	if e != "":
		return e
	await dismiss_popups("home_touch")
	var home = main.screen
	# ---- «Сегодня» sheet (the lantern opens after L6; the sheet itself is checked here): «Забрать всё»
	step = "today"
	var sh: = V10Nav.today_sheet(main)
	await wait(0.8)
	await shot("today_sheet")
	var claim = sh.find_child("ClaimAll", true, false)
	if claim != null:
		var gems0: = V10Money.bal("gems")
		e = await tap_node(claim, "«Забрать всё»")
		if e != "":
			return e
		await wait(0.8)
		if V10Money.bal("gems") <= gems0 and G.login_ready():
			return "«Забрать всё» gave nothing"
	elif G.login_ready() or G.tasks_ready() > 0:
		return "«Сегодня» has something to claim but no «Забрать всё»"
	if is_instance_valid(sh) and sh.is_inside_tree():
		sh.close()
		await wait(0.4)
	step = "mail"
	home = main.screen
	e = await tap_node(home.home2.phone_b, "«Телефон»")
	if e != "":
		return e
	# 0.9: «Письма» is the letters screen (scripts/v09/letters): open the newest letter, answer it, back home
	e = await on("letters")
	if e != "":
		return e
	await shot("mail")
	var lcard: Control = null
	for c in main.screen.list.get_children():
		if str(c.name).begins_with("Letter"):
			lcard = c
			break
	if lcard != null:
		e = await tap_node(lcard, "letter card")
		if e != "":
			return e
		await wait(0.7)
		await shot("letter")
		var lrb = popup().get_node_or_null("Reply0") if popup() != null else null
		if lrb != null:
			e = await tap_node(lrb, "letter reply")
			if e != "":
				return e
			await wait(0.9)
			await shot("letter_reply")
		if popup() != null:
			e = await close_popup()
			if e != "":
				return e
	e = await go_tab("home")
	if e != "":
		return e
	await wait(1.0)
	# ---- tournament (0.10: a shelf of «Столы» and the «Неделя» row from L16; opened directly here)
	step = "rating"
	main.go("v7tourney", {"tab": "quarter"})
	e = await on("v7tourney")
	if e != "":
		return e
	await shot("tourney_quarter")
	var ts = main.screen
	if ts.tab != "quarter":
		return "the tournament opened tab %s, not the quarter" % ts.tab
	var row: Control = null
	if ts.list:
		for c in ts.list.get_children():
			if c is Control and c.get_signal_connection_list("gui_input").size() > 0 and on_screen(c):
				row = c
				break
	if row == null:
		return "quarter table has no tappable row"
	step = "player_card"
	await tap(pos_of(row))
	await wait(0.9)
	if popup() == null:
		return "tapping a quarter row opened no player card"
	await shot("player_card")
	e = await close_popup()
	if e != "":
		return e
	step = "tourney_week"
	e = await tap_node(ts.tab_nodes["week"], "tab «Неделя»")
	if e != "":
		return e
	await wait(0.8)
	await shot("tourney_week")
	await wheel(ts.scroll.get_global_rect().get_center() if ts.scroll else Vector2(360, 900), 8)
	await shot("tourney_week_group")
	e = await tap_node(header().help_btn, "tourney «?»")
	if e != "":
		return e
	await wait(0.8)
	await shot("tourney_rules")
	e = await close_popup()
	if e != "":
		return e
	# Android «назад» on a screen goes back
	step = "android_back_screen"
	await key(KEY_ESCAPE)
	e = await on("home")
	if e != "":
		return "Android back from the tournament: " + e
	# ---- event (a row of «Сегодня» while it runs)
	step = "event"
	if V7Event.is_open():
		var esh: = V10Nav.today_sheet(main)
		await wait(0.6)
		var er = esh.find_child("Row_event", true, false)
		if er == null:
			return "the event is open but «Сегодня» has no «Событие» row"
		e = await tap_node(er, "«Событие»")
		if e != "":
			return e
		e = await on("v7event")
		if e != "":
			return e
		await dismiss_popups("event")
		await shot("event")
		e = await header_back()
		if e != "":
			return e
	else:
		notes.append("event is closed at unlocked=%d" % int(G.S.unlocked))
	# ---- the partner plate → her card in «Героини»; the 0.9 room (W2: a salon zone scene) directly
	step = "partner"
	home = main.screen
	e = await tap_node(home.home2.partner, "partner plate")
	if e != "":
		return e
	e = await on("collection")
	if e != "":
		return e
	await shot("partner_card")
	e = await go_tab("home")
	if e != "":
		return e
	step = "room"
	main.go("room", {"hero": G.S.partner})
	e = await on("room")
	if e != "":
		return e
	await dismiss_popups("room")
	await shot("room")
	e = await header_back()
	if e != "":
		return e
	if main.screen_id != "home":
		e = await go_tab("home")
		if e != "":
			return e
	step = "fx_level"
	e = await fx_toggle()
	if e != "":
		return e
	if ult_casts == 0:
		return "no ult was cast in levels 1-1…1-3"
	step = "end"
	if main.screen_id != "home":
		return "ended on %s" % main.screen_id
	await wait(0.5)
	await shot("home_end")
	return ""


func dismiss_popups(label: String) -> void:
	var k: = 0
	while popup() != null and k < 4:
		k += 1
		await wait(0.6)
		await shot("%s_popup%d" % [label, k])
		var p: = popup()
		if await close_popup() != "":
			# no ×: tap outside the panel
			await tap(Vector2(main.W * 0.5, 60))
			await wait(0.4)
			if popup() == p:
				notes.append("%s: popup could not be closed" % label)
				return


func partner_go(label: String) -> String:
	var lv = main.screen
	if not await until(func(): return lv.partner_go_btn != null and is_instance_valid(lv.partner_go_btn) and on_screen(lv.partner_go_btn), 6.0):
		return "partner picker did not open"
	await wait(0.6)
	await shot(label + "_partner")
	await tap(pos_of(lv.partner_go_btn))
	return ""


# play the current Path level to a win with touch taps on the solver's tiles
func play_level(label: String, need_next: bool) -> String:
	var e: = await on("play", 12.0)
	if e != "":
		return e
	var play = main.screen
	if not await until(func(): return play.board != null and play.board.input_on, 12.0):
		return "board never became playable"
	await shot(label + "_start")
	var moves: = 0
	var t0: = Time.get_ticks_msec()
	var stuck: = 0
	var mid_done: = false
	while is_instance_valid(play) and play.is_inside_tree() and play.victory_next_btn == null:
		if Time.get_ticks_msec() - t0 > 240000:
			return "level not finished in 240 s (%d moves)" % moves
		if play.fail_retry_btn and is_instance_valid(play.fail_retry_btn) and on_screen(play.fail_retry_btn):
			notes.append("%s: tray overflowed, tapped «%s»" % [label, play.fail_retry_btn.lbl.text])
			await shot(label + "_fail")
			await tap(pos_of(play.fail_retry_btn))
			await wait(1.0)
			continue
		# 0.9: an ult (auto-cast when charged outside ranked, or a real tap on the glowing portrait)
		if play.ult != null and play.ult.busy:
			await ult_cast(label, play)
			continue
		if play.skill_ready and play.stage != null and on_screen(play.stage) and not play.ult.busy:
			await wait(0.3)
			if play.skill_ready and not play.ult.busy:
				await tap(pos_of(play.stage))
				await wait(0.2)
			continue
		var b = play.board
		if b == null or not is_instance_valid(b) or b.board_count() == 0:
			await wait(0.2)
			continue
		if popup() != null:
			await shot(label + "_popup")
			if await close_popup() != "":
				return "a popup without × blocks the table"
			continue
		var t: Tile = b.solver_move()
		if t == null or not b.input_on or b.busy > 0:
			await wait(0.1)
			continue
		var before: int = b.history.size() + b.tiles.filter(func(x): return not x.alive).size()
		var ice: int = t.ice
		await tap(pos_of(t), 0.05)
		await wait(0.08)
		var after: int = b.history.size() + b.tiles.filter(func(x): return not x.alive).size()
		if after == before and t.ice == ice and t.alive and b.on_board(t):
			touch_miss += 1
			stuck += 1
			if stuck >= 6:
				return "touch taps do not reach the tile at %s" % str(pos_of(t))
		else:
			stuck = 0
			moves += 1
		if moves == 8 and not mid_done:
			mid_done = true
			await shot(label + "_mid")
	if not await until(func(): return play.victory_next_btn != null and on_screen(play.victory_next_btn), 15.0):
		return "victory buttons did not appear"
	await wait(2.6)
	await shot(label + "_victory")
	return ""


# one ult cast: screenshots of the cut-in (the strip coming in, the strong beat) and of the board after it.
# Shots only for the first two casts of the run; later casts are just waited out.
func ult_cast(label: String, play) -> void:
	ult_casts += 1
	var k: = ult_casts
	var t0: = Time.get_ticks_msec()
	if k <= 2:
		var cut: Node = await wait_find(func(): return find(play, func(c): return c is V9Cutin), 3.2)
		if cut != null:
			await wait(0.3)
			await shot("%s_ult%d_cutin" % [label, k])
			await wait(0.4)
			if is_instance_valid(cut):
				await shot("%s_ult%d_strong" % [label, k])
		else:
			await shot("%s_ult%d_nocutin" % [label, k])
			notes.append("%s: ult %d had no cut-in (ult_cutin=%s)" % [label, k, G.ult_cutin()])
	await until(func(): return not is_instance_valid(play) or play.ult == null or not play.ult.busy, 8.0)
	if is_instance_valid(play) and play.ult != null and play.ult.busy:
		notes.append("%s: ult %d still busy after 8 s" % [label, k])
	if k <= 2:
		await wait(0.5)
		await shot("%s_ult%d_after" % [label, k])
	print("PT ult %d cast in %s (%.1f s)" % [k, label, (Time.get_ticks_msec() - t0) / 1000.0])


# 0.9 live heroine at home: real taps on her zones; every zone must answer (a line, or affection on her)
func home_touch() -> String:
	var home = main.screen
	var live: V9HomeLive = home.live if "live" in home else null
	if live == null or not is_instance_valid(live):
		return "home has no live heroine layer"
	var pet0: = G.pet_left()
	for z in ["head", "hand", "outfit", "bg"]:
		var p: Vector2 = live.zone_point(z)
		var got: = live.zone_at(p)
		if got != z:
			notes.append("home_touch: %s point %s reads as «%s»" % [z, str(p), got])
			continue
		var l0: = live.touch.last_line_t
		var pl0: = G.pet_left()
		await tap(p)
		await wait(0.8)
		await shot("home_touch_" + z)
		var answered: bool = live.touch.last_line_t != l0 or G.pet_left() != pl0
		if not answered:
			if z == "hand" or z == "outfit":
				# a card or icon above her can take this tap first (Hana's tile on a stick)
				notes.append("home_touch: a tap on her %s at %s got no answer (covered?)" % [z, str(p)])
			else:
				return "a tap on her %s at %s got no answer" % [z, str(p)]
		# her next line needs V9Touch.TALK_CD (the room: ×1.5)
		await wait(3.3)
	if G.pet_left() >= pet0 and pet0 > 0:
		return "touching her gave no affection (pet_left %d)" % G.pet_left()
	return ""


# 0.9 «Эффекты»: switch to «Минимум» in the settings (from the profile), look at home, tap her, then back to «Полные»
func fx_toggle() -> String:
	for lv in [["min", "Минимум"], ["full", "Полные"]]:
		await tap(Vector2(190, 62))
		var e: = await on("profile")
		if e != "":
			return e
		# «Настройки» sits at the bottom of the profile
		var psc: ScrollContainer = main.screen.scroll
		await wheel(psc.get_global_rect().get_center(), 36)
		e = await tap_button(main.screen, "Настройки")
		if e != "":
			return e
		await wait(0.8)
		if popup() == null:
			return "settings did not open from the profile"
		e = await tap_button(popup(), lv[1])
		if e != "":
			return e
		await wait(0.4)
		if G.fx_level() != lv[0]:
			return "«%s» set effects to %s" % [lv[1], G.fx_level()]
		await shot("settings_fx_" + lv[0])
		await key(KEY_ESCAPE)
		if not await until(func(): return popup() == null, 2.0):
			return "Android back did not close the settings popup"
		e = await header_back()
		if e != "":
			return e
		if main.screen_id != "home":
			return "profile back went to %s" % main.screen_id
		await wait(0.6)
		var live = main.screen.live if "live" in main.screen else null
		if live != null and is_instance_valid(live):
			await tap(live.zone_point("head"))
			await wait(0.5)
		await shot("home_fx_" + lv[0])
		await wait(2.0)
	return ""
