extends Control

# Demo runner of the Pagoda hub (part A of the tower UI track), without main.gd.
#   godot --path game res://scripts/v10/tower/ui/demo_pagoda.tscn [--resolution 720x1280] -- [flags]
#     --shots=<abs dir>   snapshots of every state into <dir>/<W>x<H>_<state>.png, then quit
#     --selftest=1        UX budget + behaviour checks at 720×1280 and 720×1600 (SubViewports), prints
#                         «PAGODA_UI_SELFTEST ok/total», exit code 0 only when every check passed
#     --state=<name>      just show one state (interactive look), --fx=full|mid|min
# A stub main records go / back / toast; the save is a fake: V10Pagoda._test_S + a few G.S keys (G.demo = true,
# so nothing is written to disk). The clock is fixed (V10TowerUtil.fake_now) so the week tables are stable.

const SCREEN: = "res://scripts/v10/tower/pagoda_screen.gd"
const FAKE_NOW: = 1795629600  # Wed 25 Nov 2026, 18:00 UTC
const SIZES: = [Vector2i(720, 1280), Vector2i(720, 1600)]

# visible-text bans: UX_RULES §4.3 jargon + the «было» column of §4.2 (case-insensitive, whole words where short)
const BANNED_RE: = ["(?i)гарант", "(?i)\\bпити\\b", "(?i)\\bpity\\b", "50/50", "\\bSR\\+?\\b", "\\bSSR\\+", "(?i)\\bгача",
	"(?i)\\bролл", "(?i)крутк", "(?i)фивер", "(?i)ивент", "(?i)квартал", "(?i)\\bперк", "(?i)ульт", "(?i)риичи",
	"(?i)\\bяку\\b", "(?i)банер", "(?i)донат", "\\bХИТ\\b", "ВЫГОДНО", "\\bBEST\\b", "\\bNEW\\b", "(?i)успей",
	"(?i)последний шанс", "(?i)топ-100", "(?i)богин", "(?i)лихорадк", "₽", "%", "(?i)лунная лестница",
	"(?i)гардероб", "(?i)поручени", "(?i)рядом с тобой", "(?i)лунн(ый|ого) кам"]

const STATES: = ["fresh", "rec_h0", "rec_h8", "rec_h16", "heat12", "heat18", "run7", "locked", "scroll", "scroll_grey",
	"records_week", "records_heroines", "result", "partner", "rules", "end_confirm"]

var args: = {}
var stub: StubMain
var screen: Control
var host: Node
var _ok: = 0
var _total: = 0
var _fails: = []
var _bans: = []


class StubMain extends RefCounted:
	var calls: = []

	func go(id: String, a: = {}, _anim: = true, _rem: = true) -> void:
		calls.append(["go", id, a])

	func back() -> void:
		calls.append(["back"])

	func toast(text: String, icon: = "") -> void:
		calls.append(["toast", text, icon])

	func last(kind: String) -> Array:
		for i in range(calls.size() - 1, -1, -1):
			if calls[i][0] == kind:
				return calls[i]
		return []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	G.demo = true
	V10TowerUtil.fake_now = FAKE_NOW
	V10TowerBoard._test_profile_id = "demo-player"
	if args.has("fx"):
		V10Hud2Util.fx_override = str(args.fx)
	for r in BANNED_RE:
		var re: = RegEx.new()
		re.compile(r)
		_bans.append(re)
	get_tree().create_timer(float(args.get("watchdog", "300"))).timeout.connect(func() -> void:
		print("PAGODA_UI_SELFTEST watchdog: no result (runtime error above?)")
		get_tree().quit(4))
	if args.has("selftest"):
		await _selftest()
		return
	var vs: = get_viewport_rect().size
	V10Hud2Util.sim_insets = {"top": 48.0, "bottom": 24.0} if vs.y / vs.x >= 2.0 else {"top": 0.0, "bottom": 0.0}
	if args.has("shots"):
		await _shots(str(args.shots))
		get_tree().quit(0)
		return
	await _show(self, str(args.get("state", "rec_h0")))


# ---------------------------------------------------------------- fake saves per state

func _base_save(open: = true) -> Dictionary:
	return {"rp": 1000 if open else 0, "v6_modes": {}, "v10_pagoda": {"best": {}, "best_score": 0, "migrated": true,
		"week": {"id": -1, "floors": 0, "score": 0, "offered": 0, "heat": 0}, "miles": [], "runs": 0, "cos": [], "run": {}}}


const C8: = {"shroud": 1, "hourglass": 1, "fog": 1, "guards": 1}  # Жар 8
const C12: = {"shroud": 2, "hourglass": 2, "narrow": 1, "no_undo": 1}  # Жар 12
const C16: = {"shroud": 2, "hourglass": 2, "narrow": 1, "no_undo": 1, "guards": 2}  # Жар 16
const C18: = {"shroud": 2, "hourglass": 3, "narrow": 1, "no_undo": 1, "guards": 2}  # Жар 18


func _setup(state: String) -> Dictionary:
	var S: = _base_save(state != "locked")
	var d: Dictionary = S.v10_pagoda
	var rec: = {"0": 14, "8": 9, "12": 7, "16": 5, "18": 3}
	var a: = {}
	G.S["rp"] = 1000 if state != "locked" else 0
	G.S["level_partner"] = "rin"
	var sh: Dictionary = G.S.get("shards", {})
	for h in ["rin", "hana", "yue"]:
		sh[h] = maxi(int(sh.get(h, 0)), G.SHARDS_NEED)
	G.S["shards"] = sh
	match state:
		"fresh", "locked":
			pass
		"rec_h0", "records_week", "records_heroines", "partner", "rules":
			d.best = rec.duplicate()
		"rec_h8":
			d.best = rec.duplicate()
			d["scroll"] = C8.duplicate()
		"rec_h16":
			d.best = rec.duplicate()
			d["scroll"] = C16.duplicate()
		"heat12", "scroll":
			d.best = rec.duplicate()
			d["scroll"] = C12.duplicate()
		"scroll_grey":
			d.best = rec.duplicate()
			d["scroll"] = {"fog": 2, "shroud": 1}
		"heat18":
			d.best = rec.duplicate()
			d["scroll"] = C18.duplicate()
		"run7", "end_confirm":
			d.best = rec.duplicate()
			d["scroll"] = C12.duplicate()
			d.run = {"mode": "pagoda", "floor": 7, "lives": 2, "partner": "rin", "seed": 4242, "curses": C12.duplicate(),
				"forced": {}, "bless": {"tips": 1}, "offer": [], "chests": 1, "petals_done": true, "cleared": 6,
				"week": V10TowerUtil.cur_week()}
		"result":
			d.best = rec.duplicate()
			d.best["12"] = 12
			d["scroll"] = C12.duplicate()
			a = {"result": {"floors": 12, "heat": 12, "mult": 2.2, "score": 2640, "record_heat": true, "record_score": false,
				"cos": [], "week_score": 2640}, "new_cos": []}
	if state in ["records_week", "records_heroines", "rec_h0"]:
		# this week's own best so the «Неделя» table has the player's row
		d.week = {"id": V10TowerUtil.cur_week(), "floors": 11, "score": 1980, "offered": 40, "heat": 8}
	V10Pagoda._test_S = S
	return a


func _show(parent: Node, state: String) -> Control:
	if is_instance_valid(screen):
		screen.queue_free()
		screen = null
		await get_tree().process_frame
	var a: = _setup(state)
	stub = StubMain.new()
	var s: = Control.new()
	s.name = "PagodaScreen"
	s.set_script(load(SCREEN))
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size = (parent as Viewport).size if parent is Viewport else get_viewport_rect().size
	parent.add_child(s)
	s.call("build", stub, a)
	screen = s
	await _wait(0.05)
	match state:
		"scroll", "scroll_grey":
			await _wait(0.4)
			s.call("_open_scroll")
			if state == "scroll_grey":
				var sc: V10CurseScroll = s.sheet
				sc.set_level("narrow", 1)  # denied: Туман II is on → the grey card «Слишком жестоко…»
		"records_week":
			s.call("_open_records", "week")
		"records_heroines":
			s.call("_open_records", "heroines")
		"partner":
			s.call("_open_partner")
		"rules":
			s.call("_open_rules")
		"end_confirm":
			s.call("_open_end_confirm")
	return s


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


# ---------------------------------------------------------------- shots

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var vs: = get_viewport_rect().size
	for st in STATES:
		await _show(self, st)
		await _wait(1.5 if not st.begins_with("scroll") else 1.6)
		await RenderingServer.frame_post_draw
		var img: = get_viewport().get_texture().get_image()
		var path: = "%s/%dx%d_%s.png" % [dir, int(vs.x), int(vs.y), st]
		img.save_png(path)
		print("shot ", path)


# ---------------------------------------------------------------- selftest

func ok(cond: bool, what: String) -> void:
	_total += 1
	if cond:
		_ok += 1
	else:
		_fails.append(what)
		print("  FAIL ", what)


func _selftest() -> void:
	var scr = load(SCREEN)
	if scr == null or not (scr as GDScript).can_instantiate():
		print("PAGODA_UI_SELFTEST parse error")
		get_tree().quit(3)
		return
	V10Hud2Util.fx_override = "min"
	for sz in SIZES:
		var svp: = SubViewport.new()
		svp.size = sz
		svp.disable_3d = true
		svp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(svp)
		host = svp
		V10Hud2Util.sim_insets = {"top": 48.0, "bottom": 24.0} if sz.y >= 1600 else {"top": 0.0, "bottom": 0.0}
		for st in STATES:
			await _show(svp, st)
			await _wait(0.3)
			_audit(st, Vector2(sz))
		await _behaviour(svp, Vector2(sz))
		if is_instance_valid(screen):
			screen.queue_free()
		svp.queue_free()
		await get_tree().process_frame
	print("PAGODA_UI_SELFTEST %d/%d" % [_ok, _total])
	for f in _fails:
		print("  failed: ", f)
	get_tree().quit(0 if _ok == _total else 1)


func _open_sheets(root: Node) -> Array:
	var out: = []
	_collect(root, func(n: Node) -> bool: return (n.has_meta("tw_sheet") or n.has_meta("tower_sheet")) and not n.is_queued_for_deletion(), out)
	return out


func _collect(n: Node, pred: Callable, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if pred.call(n):
		out.append(n)
	for c in n.get_children():
		_collect(c, pred, out)


func _is_tap(n: Node) -> bool:
	if not (n is Control) or n.has_meta("tw_surface"):
		return false
	if n is V10Button:
		return true
	if n is V10Plate:
		return (n as V10Plate).interactive
	return n.has_meta("tw_tap")


# the part of a control that is on screen: its rect clipped by every clipping ancestor (scroll lists)
func _vis_rect(c: Control) -> Rect2:
	var r: = c.get_global_rect()
	var p: = c.get_parent()
	while p != null and p is Control:
		var pc: = p as Control
		if pc.clip_contents or pc is ScrollContainer:
			r = r.intersection(pc.get_global_rect())
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				return Rect2()
		p = p.get_parent()
	return r


func _audit(st: String, vs: Vector2) -> void:
	var tag: = "%s@%dx%d" % [st, int(vs.x), int(vs.y)]
	var sheets: = _open_sheets(screen)
	var root: Node = screen
	ok(sheets.size() <= 1, tag + ": at most one sheet (%d)" % sheets.size())
	if not sheets.is_empty():
		root = sheets[0]
	# 1. roles: exactly 1 primary, ≤ 2 secondary, ≤ 2 tertiary (the open sheet is the screen while it is up)
	var roles: = V10TowerUI.roles_of(root)
	ok(int(roles.primary) == 1, tag + ": exactly 1 primary (%d)" % int(roles.primary))
	ok(int(roles.secondary) <= 2, tag + ": ≤ 2 secondary (%d)" % int(roles.secondary))
	ok(int(roles.tertiary) <= 2, tag + ": ≤ 2 tertiary (%d)" % int(roles.tertiary))
	# 2. visible labels: no banned words, sizes ≥ 18 (Overline 15 only), ≤ 4 sizes + overline, words budget
	var labels: = []
	_collect(screen, func(n: Node) -> bool: return n is Label and (n as Label).text.strip_edges() != "", labels)
	var sizes: = {}
	var words: = 0
	for l in labels:
		var lb: = l as Label
		var txt: = lb.text
		var bad: = ""
		for re in _bans:
			if (re as RegEx).search(txt):
				bad = (re as RegEx).get_pattern()
		ok(bad == "", tag + ": no banned word in «%s» (%s)" % [txt, bad])
		var ls: = lb.label_settings
		ok(ls != null, tag + ": label has V10Type settings «%s»" % txt)
		if ls == null:
			continue
		var overline: = ls.font == V10Type.font("overline")
		ok(ls.font_size >= 18 or (overline and ls.font_size == 15), tag + ": size %d ≥ 18 «%s»" % [ls.font_size, txt])
		ok(ls.outline_size == 0, tag + ": no outline «%s»" % txt)
		var inside_sheet: = sheets.is_empty() or (sheets[0] as Node).is_ancestor_of(lb)
		if inside_sheet and not overline:
			sizes[ls.font_size] = true
		if sheets.is_empty() and not lb.get_parent() is ScrollContainer:
			words += txt.split(" ", false).size()
	# part C's result sheet keeps its own type budget (its demo checks it); ours: ≤ 4 sizes + overline
	if sheets.is_empty() or not (sheets[0] as Node).has_meta("tower_sheet"):
		ok(sizes.size() <= 4, tag + ": ≤ 4 type sizes + overline (%s)" % str(sizes.keys()))
	if sheets.is_empty():
		ok(words <= 60, tag + ": ≤ 60 words (%d)" % words)
	# 3. tappables: ≥ 80 px, inside the screen, no two overlap
	var taps: = []
	_collect(root, _is_tap, taps)
	ok(taps.size() >= 1, tag + ": something to tap")
	var screen_r: = Rect2(Vector2.ZERO, vs).grow(0.5)
	var rects: = []
	for t in taps:
		var c: = t as Control
		var full: = c.get_global_rect()
		var vr: = _vis_rect(c)
		if vr.size.x <= 0.0 or vr.size.y <= 0.0:
			continue
		var nm: = _name_of(c)
		ok(full.size.x >= 79.5 and full.size.y >= 79.5, tag + ": hit zone ≥ 80 «%s» %s" % [nm, str(full.size)])
		ok(screen_r.encloses(vr), tag + ": inside the screen «%s» %s" % [nm, str(vr)])
		rects.append([nm, vr])
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var a: Rect2 = rects[i][1]
			var b: Rect2 = rects[j][1]
			var x: = a.intersection(b)
			ok(x.size.x * x.size.y < 1.0, tag + ": «%s» and «%s» do not overlap" % [rects[i][0], rects[j][0]])
	# 4. the hub: the primary is in the bottom third; markers on the art never sit under a button or plate
	if sheets.is_empty():
		var play: Control = screen.get("play")
		ok(play.get_global_rect().position.y >= vs.y * 2.0 / 3.0, tag + ": main button in the bottom third")
		ok(play.get_global_rect().size.x >= 440.0 and play.get_global_rect().size.y >= 104.0, tag + ": main button ≥ 440×104")
		var view: V10PagodaView = screen.get("view")
		for mr in view.marker_rects():
			for r in rects:
				ok(not (mr as Rect2).intersects(r[1]), tag + ": marker clear of «%s»" % r[0])
			ok((mr as Rect2).end.x <= vs.x and (mr as Rect2).position.y >= view.scene_top, tag + ": marker inside the scene")


func _name_of(c: Control) -> String:
	if c is V10Button:
		return (c as V10Button).text if (c as V10Button).text != "" else String(c.name)
	if c is V10Plate:
		return (c as V10Plate).title
	for ch in c.get_children():
		if ch is Label:
			return (ch as Label).text
	return String(c.name)


func _find_button(root: Node, text: String) -> V10Button:
	var out: = []
	_collect(root, func(n: Node) -> bool: return n is V10Button and (n as V10Button).text == text, out)
	return out[0] if not out.is_empty() else null


# ---------------------------------------------------------------- behaviour

func _behaviour(svp: Node, vs: Vector2) -> void:
	var tag: = "@%dx%d" % [int(vs.x), int(vs.y)]
	# «Подняться» starts a valid run and goes to tower_play
	var s: = await _show(svp, "rec_h0")
	(s.get("play") as V10Button).pressed.emit()
	var g: = stub.last("go")
	ok(not g.is_empty() and g[1] == "tower_play", "Подняться → go(tower_play)" + tag)
	if not g.is_empty():
		var a: Dictionary = g[2]
		var run: Dictionary = a.get("run", {})
		ok(String(a.get("mode", "")) == "pagoda", "go args mode = pagoda" + tag)
		ok(String(run.get("mode", "")) == "pagoda" and int(run.get("floor", 0)) == 1 and int(run.get("lives", 0)) == 3 and not run.has("error"),
			"go args run is a fresh pagoda run (floor 1, 3 lanterns)" + tag)
		ok(String(run.get("partner", "")) == "rin", "run partner = level_partner" + tag)
		ok(V10Pagoda.has_run() and V10Pagoda.current_run() == run, "the run is stored in the save" + tag)
	# the curse scroll: forbidden pair denied, «Готово» applies the heat to the hub
	s = await _show(svp, "rec_h0")
	(s.get("chip") as V10Plate).pressed.emit()
	await _wait(0.2)
	var sc: = s.get("sheet") as V10CurseScroll
	ok(sc != null, "chip → curse scroll" + tag)
	if sc:
		ok(sc.set_level("fog", 2), "Туман II can be set" + tag)
		ok(not sc.set_level("narrow", 1), "Тесный лоток is denied with Туман II" + tag)
		ok(sc.blocked("narrow"), "Тесный лоток is a grey card" + tag)
		ok(sc.denied == "narrow" and sc.touched == "narrow", "the denied row shows «%s»" % V10ModsData.SAFE_TEXT + tag)
		ok(sc.set_level("hourglass", 3), "Песочные часы III" + tag)
		ok(sc.heat() == 10, "heat 4 + 6 = 10 (%d)" % sc.heat() + tag)
		var cell: = sc.cell("narrow", 1)
		ok(cell != null and cell.size.x >= 80.0 and cell.size.y >= 80.0, "segment cell ≥ 80" + tag)
		sc.close(true)
		await _wait(0.3)
		ok(int(s.get("curses").get("hourglass", 0)) == 3 and int(s.get("curses").get("fog", 0)) == 2, "the hub keeps the scroll" + tag)
		ok((s.get("chip") as V10Plate).title == V10Pagoda.heat_text(10), "chip shows «%s»" % V10Pagoda.heat_text(10) + tag)
		ok((s.get("play") as V10Button).overline == "Этаж 1 · Жар 10", "overline ЭТАЖ 1 · ЖАР 10" + tag)
		var v: V10PagodaView = s.get("view")
		ok(v.lit_to == V10Pagoda.best_for_heat(10), "lanterns lit to the record of Жар 10" + tag)
		ok(V10Pagoda.st().get("scroll", {}).get("hourglass", 0) == 3, "the scroll is saved for the next visit" + tag)
	# a run: «Продолжить · этаж 7» goes with the stored run; the chip is frozen
	s = await _show(svp, "run7")
	var pl: = s.get("play") as V10Button
	ok(pl.text == "Продолжить · этаж 7", "run: «Продолжить · этаж 7»" + tag)
	ok(not (s.get("chip") as V10Plate).interactive, "run: the chip does not open the scroll" + tag)
	ok((s.get("chip") as V10Plate).subtitle == "Жар выбран на старте", "run: «Жар выбран на старте»" + tag)
	pl.pressed.emit()
	g = stub.last("go")
	ok(not g.is_empty() and g[1] == "tower_play" and (g[2] as Dictionary).get("run") == V10Pagoda.current_run(), "Продолжить → the same run" + tag)
	# «Завершить восхождение» → confirm → end_run → the result sheet
	s = await _show(svp, "run7")
	(s.get("end_btn") as V10Button).pressed.emit()
	await _wait(0.2)
	var conf: = _find_button(s, "Завершить")
	ok(conf != null, "end → confirm sheet with «Завершить»" + tag)
	if conf:
		conf.pressed.emit()
		await _wait(0.3)
		ok(not V10Pagoda.has_run(), "the run is over" + tag)
		ok(int(V10Pagoda.best_for_heat(12)) >= 7, "the record holds" + tag)
		ok(_open_sheets(s).size() == 1, "the result sheet is up (one sheet)" + tag)
		var again: = _find_button(s, "Новое восхождение")
		if again == null:
			ok(true, "result sheet comes from part C" + tag)
		else:
			again.pressed.emit()
			g = stub.last("go")
			ok(not g.is_empty() and g[1] == "tower_play" and int((g[2] as Dictionary).run.floor) == 1, "again → a new run" + tag)
	# locked: the main action goes back to the tables
	s = await _show(svp, "locked")
	ok((s.get("play") as V10Button).text == "К столам", "locked: «К столам»" + tag)
	ok(not (s.get("chip") as Control).visible, "locked: no chip" + tag)
	(s.get("play") as V10Button).pressed.emit()
	ok(not stub.last("back").is_empty(), "locked: К столам → back()" + tag)
	# partner: a tap makes her the partner and saves it
	s = await _show(svp, "partner")
	var plates: = []
	_collect(s.get("sheet"), func(n: Node) -> bool: return n is V10Plate and (n as V10Plate).interactive, plates)
	ok(plates.size() == V10TowerUtil.owned().size(), "partner sheet lists the owned heroines" + tag)
	for p in plates:
		if (p as V10Plate).title == V10TowerUtil.hero_name("hana"):
			(p as V10Plate).pressed.emit()
	ok(String(G.S.level_partner) == "hana", "partner saved to level_partner" + tag)
	ok((s.get("partner_plate") as V10Plate).title == V10TowerUtil.hero_name("hana"), "partner plate updated" + tag)
	# records: the segment switches the table, the heroines tab carries «соперницы-героини (ИИ)»
	s = await _show(svp, "records_week")
	var sh: Node = s.get("sheet")
	var seg = sh.get_meta("seg")
	seg.press("heroines")
	await _wait(0.1)
	var found: = []
	_collect(sh, func(n: Node) -> bool: return n is Label and (n as Label).text == V10TowerBoard.HEROINE_LABEL, found)
	ok(found.size() == 1, "heroines tab: «%s»" % V10TowerBoard.HEROINE_LABEL + tag)
	# one heroine owned only: no picker
	G.S["shards"] = {}
	s = await _show_one_owned(svp)
	var one: = V10TowerUtil.owned().size() <= 1
	ok((s.get("partner_plate") as V10Plate).interactive != one, "partner picker only with a choice (owned %d)" % V10TowerUtil.owned().size() + tag)


func _show_one_owned(svp: Node) -> Control:
	if is_instance_valid(screen):
		screen.queue_free()
		await get_tree().process_frame
	V10Pagoda._test_S = _base_save(true)
	G.S["shards"] = {}
	stub = StubMain.new()
	var s: = Control.new()
	s.set_script(load(SCREEN))
	s.size = Vector2((svp as SubViewport).size)
	svp.add_child(s)
	s.call("build", stub, {})
	screen = s
	await _wait(0.2)
	return s
