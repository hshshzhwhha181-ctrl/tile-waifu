class_name V10LayoutShots
extends Node

# 0.10 M0 «responsive»: visits every screen (and the first-run views, the main popups, a cut-in and a victory)
# at the window's resolution and screenshots each one into <dir>/<W>x<H>/NN_name.png. A layout lint runs on every
# view: an interactive control (JButton / tap-stop Control, outside scroll lists) whose rect leaves the viewport or
# whose centre sits under a simulated cut-out is a LAYOUT WARN line. Ends with
#   LAYOUT OK <shots> shots, <warnings> warnings, <errors> script errors   (exit 0)
#
#   godot --path game --resolution 1080x2400 -- --layout_shots=/abs/dir --save=user://layout_save.json \
#         --save_wipe=1 --story_off=1 [--safe=120,48 --notch=1] [--layout_only=home,shop]
#   bash game/scripts/v10/responsive/layout_shots.sh /abs/dir [WxH ...]      (all resolutions, contact sheets)
#
# --layout_selftest=1 (same runner) checks V10Layout's math at every listed resolution and quits:
#   LAYOUT_SELFTEST ok/total.

const RES_LIST: = ["720x1280", "1080x1920", "1080x2340", "1080x2400", "1216x2688", "1440x3200", "1536x2048", "1600x2560"]

var main
var dir: = ""
var out: = ""
var only: = []
var n: = 0
var warns: Array = []
var core: Array = []
var elog
var notch: Control


static func start(m, a: Dictionary) -> V10LayoutShots:
	var d: = V10LayoutShots.new()
	d.main = m
	d.dir = String(a.get("layout_shots", ""))
	if a.has("layout_only"):
		d.only = Array(String(a.layout_only).split(",", false))
	d.name = "V10LayoutShots"
	m.add_child(d)
	return d


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	elog = V8Playtest.ErrLog.new()
	OS.add_logger(elog)
	_run.call_deferred()


# ------------------------------------------------------------------ helpers

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func want(name: String) -> bool:
	return only.is_empty() or name in only


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	n += 1
	_lint(name)
	if "--layout_dump=1" in OS.get_cmdline_user_args():
		_dump_column_edges(name)
	if out == "":
		return
	var img: = get_viewport().get_texture().get_image()
	img.save_png(out.path_join("%02d_%s.png" % [n, name]))
	print("LAYOUT SHOT %02d %s" % [n, name])


func _transients() -> Array:
	var res: = []
	for c in main.get_children():
		if not c in core:
			res.append(c)
	return res


# free everything a step added straight to main (title, player card, story scenes, cut-ins) and close popups
func cleanup() -> void:
	for c in _transients():
		c.queue_free()
	for c in main.overlay.get_children():
		c.queue_free()
	main.busy = false
	await get_tree().process_frame


func go(id: String, args: = {}) -> void:
	await cleanup()
	main.busy = false
	main.screen_id = ""
	main.go(id, args, false)
	while main.busy:
		await get_tree().process_frame


func _prep_save() -> void:
	# never write the player's real save from here
	if G.save_path == G.SAVE_PATH:
		G.save_path = "user://layout_shots_save.json"
	G.S.profile_done = true
	G.S.intro_done = true
	G.S.tut_done = true
	G.S.unlocked = mini(14, G.LEVELS.size())
	var st: = {}
	for i in 13:
		st[str(i)] = 3 if i % 3 != 2 else 2
	G.S.stars = st
	G.S.gems = 12450
	G.S.coins = 38200
	G.S.rp = 180
	G.S.free10 = true
	G.S.profile.nick = "Чайный Гость"
	G.S.profile.avatar = "rin"
	for id in V6Scenes.SCENES:
		V6Story.mark(id)
	main._refresh_profile_chip()
	main.refresh_currency()
	main.refresh_nav()


# ------------------------------------------------------------------ lint

func _lint(view: String) -> void:
	var vs: Vector2 = main.get_viewport_rect().size
	var ins: = V10Layout.safe_insets(vs)
	var vr: = Rect2(Vector2.ZERO, vs)
	var bad: = 0
	var stack: Array = [main]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is CanvasItem and not (nd as CanvasItem).is_visible_in_tree():
			continue
		if nd is ScrollContainer or nd == notch:
			continue
		# a hand-scrolled map (levels: one Control many screens tall) is scroll content too
		if nd is Control and nd != main and (nd as Control).size.y > vs.y * 2.0:
			continue
		for c in nd.get_children():
			stack.append(c)
		if not (nd is Control):
			continue
		var c: Control = nd
		var tap: = c is JButton or (c.mouse_filter == Control.MOUSE_FILTER_STOP and c.gui_input.get_connections().size() > 0)
		if not tap or c.size.x < 8.0 or c.size.y < 8.0 or c.modulate.a < 0.05:
			continue
		# full-screen tap catchers (dims, backgrounds, live layers) are not buttons
		if c.size.x >= vs.x * 0.9 and c.size.y >= vs.y * 0.5:
			continue
		var gr: = c.get_global_rect()
		var why: = ""
		# wholly above / below the viewport = scrolled map or list content (levels), not a layout fault
		var scrolled_away: = gr.end.y < 0.0 or gr.position.y > vs.y
		if not vr.grow(2.0).encloses(gr) and not scrolled_away:
			why = "leaves the viewport %s" % str(gr)
		elif ins.top > 0.0 and gr.get_center().y < float(ins.top):
			why = "centre under the cut-out (top %.0f) %s" % [ins.top, str(gr)]
		elif ins.bottom > 0.0 and gr.get_center().y > vs.y - float(ins.bottom):
			why = "centre in the bottom inset %s" % str(gr)
		if why != "":
			bad += 1
			if bad <= 6:
				var w: = "LAYOUT WARN %s: %s %s" % [view, _path(c), why]
				warns.append(w)
				print(w)


# dev: canvas items that start exactly at the column's left edge and are tall (seams on tablets)
func _dump_column_edges(view: String) -> void:
	var x0: float = main.CR.position.x
	if x0 < 1.0:
		return
	var stack: Array = [main.screen]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
		if nd is Control and (nd as Control).is_visible_in_tree():
			var gr: = (nd as Control).get_global_rect()
			if absf(gr.position.x - x0) < 2.0 and gr.size.y > 300.0:
				print("LAYOUT EDGE %s: %s %s %s" % [view, _path(nd), nd.get_class(), str(gr)])


func _path(c: Node) -> String:
	var p: = []
	var x: Node = c
	while x and x != main and p.size() < 4:
		p.push_front(x.name if not x.name.begins_with("@") else x.get_class())
		x = x.get_parent()
	return "/".join(p)


# a fake camera pill where --safe= says the cut-out is (screenshots only)
func _draw_notch() -> void:
	var vs: Vector2 = main.get_viewport_rect().size
	var ins: = V10Layout.safe_insets(vs)
	if float(ins.top) <= 0.0:
		return
	notch = Control.new()
	notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notch.z_index = 1000
	notch.name = "V10Notch"
	var band: = ColorRect.new()
	band.color = Color(1, 0, 0.4, 0.10)
	band.size = Vector2(vs.x, float(ins.top))
	notch.add_child(band)
	var pill: = UI.rbox("graphite", Rect2(vs.x * 0.5 - 22, float(ins.top) * 0.5 - 22, 44, 44), 22, 0, 4)
	pill.colors(Color.BLACK, Color.BLACK)
	notch.add_child(pill)
	main.add_child(notch)
	core.append(notch)


# ------------------------------------------------------------------ run

func _run() -> void:
	await get_tree().process_frame
	var vs: Vector2 = main.get_viewport_rect().size
	var win: = DisplayServer.window_get_size()
	if "--layout_selftest=1" in OS.get_cmdline_user_args():
		_selftest()
		return
	out = dir.path_join("%dx%d" % [win.x, win.y]) if dir != "" else ""
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	print("LAYOUT start " + V10Layout.dump(vs))
	core = [main.screen_root, main.topbar, main.navbar, main.overlay, main.trans, main.finger, self]
	if "--notch=1" in OS.get_cmdline_user_args():
		_draw_notch()
	_prep_save()
	await wait(0.4)
	await _first_run()
	await _screens()
	elog.mutex.lock()
	var se: Array = elog.script_errors.duplicate()
	elog.mutex.unlock()
	for e in se.slice(0, 12):
		print("LAYOUT script error: %s" % e)
	print("LAYOUT %s %d shots, %d warnings, %d script errors" % ["OK" if se.is_empty() else "FAIL", n, warns.size(), se.size()])
	OS.remove_logger(elog)
	get_tree().quit(0 if se.is_empty() else 1)


func _tap_center(c: Control) -> void:
	var ev: = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = c.size * 0.5
	c.gui_input.emit(ev)


func _first_run() -> void:
	# fresh install: title, then the player card on top of it
	if want("title_fresh") or want("card"):
		await cleanup()
		main.screen_id = ""
		main.go("home", {}, false)
		G.S.profile_done = false
		G.S.intro_done = false
		main._splash()
		await wait(2.2)
		await shot("title_fresh")
		var tr: = _transients()
		if not tr.is_empty() and tr[-1] is Control:
			_tap_center(tr[-1])
			await wait(1.8)
			await shot("card")
		G.S.profile_done = true
		G.S.intro_done = true
	if want("title"):
		await cleanup()
		main._splash()
		await wait(2.2)
		await shot("title")
	if want("intro"):
		await cleanup()
		V6Story.play("intro")
		await wait(2.4)
		await shot("intro")
	await cleanup()


func _screens() -> void:
	var steps: Array = [
		["home", "home", {}],
		["home_outfit", "home", {"outfit": "o_dragon"}],
		["profile", "profile", {"from": "home"}],
		["levels", "levels", {"select": 4}],
		["tables", "tables", {}],
		["tutorial", "play", {"level": 0, "partner": "mc"}],
		["play", "play", {"level": 6, "partner": "mc"}],
		["summon", "summon", {}],
		["collection", "collection", {}],
		["shop", "shop", {}],
		["shop_gems", "shop", {"tab": 2}],
		["modes", "modes", {}],
		["climb", "arena", {"mode": "climb", "partner": "mc"}],
		["etude", "arena", {"mode": "etude", "etude": 0, "partner": "mc"}],
		["blitz", "play", {"mode": "blitz", "partner": "mc"}],
		["duel", "play", {"mode": "duel", "rival": "rin", "partner": "mc"}],
		["room", "room", {"hero": "mc"}],
		["event", "v7event", {}],
		["tourney", "v7tourney", {"tab": "quarter"}],
		["tourney_week", "v7tourney", {"tab": "week"}],
		["tourney_play", "v7play", {"mode": "v7tourney", "table": 0, "partner": "mc"}],
		["letters", "letters", {}],
	]
	for st in steps:
		var name: String = st[0]
		if not want(name) and not (name == "home" and (want("settings") or want("tasks") or want("visits") or want("calendar") or want("album") or want("today"))) \
				and not (name == "play" and (want("cutin") or want("victory"))) and not (name == "summon" and want("pull")):
			continue
		if name == "home_outfit":
			# her SSR outfit painting instead of the lobby video (home «art» mode)
			G.S.owned["o_dragon"] = true
			G.S.outfit["mc"] = "o_dragon"
		elif G.S.outfit.get("mc", "") == "o_dragon":
			G.S.outfit["mc"] = "o_base"
		await go(st[1], st[2])
		await wait(2.6 if st[1] in ["play", "arena"] else 1.8)
		if want(name):
			await shot(name)
		match name:
			"home":
				await _popup_shot("settings", func(): main.settings())
				await _popup_shot("tasks", func(): Daily.tasks(main, main.screen))
				await _popup_shot("visits", func(): Daily.login(main, main.screen))
				await _popup_shot("calendar", func(): Daily.calendar(main))
				await _popup_shot("album", func(): V7AlbumView.open(main))
				await _popup_shot("today", func(): V10Nav.today_sheet(main))  # 0.10 W1: the «Сегодня» sheet
			"play":
				if want("cutin"):
					await _cutin()
				if want("victory"):
					await _victory()
			"summon":
				if want("pull") and main.screen.pull10_btn:
					main.screen.pull10_btn.pressed.emit()
					await wait(2.2)
					await shot("pull_lantern")
					await wait(3.6)
					await shot("pull_reveal")


func _popup_shot(name: String, open: Callable) -> void:
	if not want(name):
		return
	for c in main.overlay.get_children():
		c.queue_free()
	await get_tree().process_frame
	open.call()
	await wait(0.9)
	await shot(name)
	for c in main.overlay.get_children():
		c.queue_free()
	await get_tree().process_frame


func _cutin() -> void:
	var p: Control = main.screen
	var oid: = "o_dragon" if G.ITEM.has("o_dragon") else "mc_base"
	G.S.owned[oid] = true
	V9Cutin.run(p, oid, {"mode": "full"})
	await wait(1.0)
	await shot("cutin")
	await wait(2.5)


func _victory() -> void:
	var p = main.screen
	if p == null or not ("board" in p) or p.board == null:
		return
	var t0: = Time.get_ticks_msec()
	while is_instance_valid(p) and not p.board.input_on and Time.get_ticks_msec() - t0 < 6000:
		await get_tree().process_frame
	if not is_instance_valid(p):
		return
	for t in p.board.tiles:
		t.alive = false
		t.hide()
	p._on_clear()
	await wait(4.0)
	await shot("victory")


# ------------------------------------------------------------------ selftest

func _selftest() -> void:
	# lambdas capture locals by value: count in an array
	var cnt: = [0, 0]
	var fails: Array = []
	var check: = func(cond: bool, what: String):
		cnt[1] += 1
		if cond:
			cnt[0] += 1
		else:
			fails.append(what)
	for r in RES_LIST:
		var px: = Vector2(float(r.split("x")[0]), float(r.split("x")[1]))
		# canvas_items + expand on a 720×1280 base
		var k: = minf(px.x / 720.0, px.y / 1280.0)
		var vs: = (px / k).round()
		check.call(absf(vs.x - 720.0) < 1.0 or absf(vs.y - 1280.0) < 1.0, "%s: expand keeps one base side (%s)" % [r, vs])
		var none: = {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
		var cr: = V10Layout.content_rect(vs, none)
		check.call(cr.size.x <= V10Layout.COL_MAX + 0.5, "%s: column ≤ 720 (%s)" % [r, cr])
		check.call(absf(cr.get_center().x - vs.x * 0.5) <= 1.0, "%s: column centred (%s)" % [r, cr])
		check.call(cr.size.y >= vs.y - 0.5, "%s: column takes the full height without insets (%s)" % [r, cr])
		# a punch-hole phone: 70 px cut-out, 30 px gesture bar
		var cut: = {"top": 70.0, "bottom": 30.0, "left": 0.0, "right": 0.0}
		var cc: = V10Layout.content_rect(vs, cut)
		check.call(cc.position.y == 70.0 and absf(cc.end.y - (vs.y - 30.0)) < 0.5, "%s: column between the insets (%s)" % [r, cc])
		for tex in [Vector2(720, 1280), Vector2(1600, 893), Vector2(859, 1280), Vector2(2048, 2048)]:
			var c: = V10Layout.cover_rect(tex, Rect2(Vector2.ZERO, vs), Vector2(0.5, 0.4))
			check.call(c.encloses(Rect2(Vector2.ZERO, vs).grow(-0.5)), "%s: cover %s fills (%s)" % [r, tex, c])
			check.call(absf(c.size.x / c.size.y - tex.x / tex.y) < 0.002, "%s: cover %s keeps aspect" % [r, tex])
			var cn: = V10Layout.contain_rect(tex, Rect2(Vector2.ZERO, vs))
			check.call(Rect2(Vector2.ZERO, vs).grow(0.5).encloses(cn), "%s: contain %s inside" % [r, tex])
			check.call(absf(cn.size.x / cn.size.y - tex.x / tex.y) < 0.002, "%s: contain %s keeps aspect" % [r, tex])
	# the live viewport: main's content rect = V10Layout's, screen placed in it, chrome on the edges
	var lvs: Vector2 = main.get_viewport_rect().size
	check.call(main.CR == V10Layout.content_rect(lvs), "main.CR matches V10Layout")
	check.call(main.screen != null and main.screen.position == main.CR.position and main.screen.size == main.CR.size, "screen sits in the column")
	check.call(absf(main.navbar.position.y - (lvs.y - 132.0 - main.safe_bottom)) < 0.5, "navbar on the bottom edge")
	check.call(absf(main.topbar.position.y - main.safe_top) < 0.5, "top bar below the cut-out")
	for f in fails:
		print("LAYOUT_SELFTEST FAIL %s" % f)
	print("LAYOUT_SELFTEST %d/%d" % [cnt[0], cnt[1]])
	OS.remove_logger(elog)
	get_tree().quit(0 if cnt[0] == cnt[1] else 1)
