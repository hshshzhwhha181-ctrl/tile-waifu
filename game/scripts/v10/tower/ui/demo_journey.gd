extends Control

# Demo runner of the Journey hub (part B) without main.gd: a stub main records go / back / toast, the save is a
# test dict (V10Journey._test_S) and the clock is V10TowerUtil.fake_now, like tower_selftest.gd.
#
#   godot --path game res://scripts/v10/tower/ui/demo_journey.tscn -- [flags]
#     --state=new|run|spent|last48|locked|result   interactive: one state (default new)
#     --shots=<abs dir>                            snapshots of every state into <dir> (suffix = viewport size)
#     --selftest=1                                 UX budget audit at 720×1280 and 720×1600 → JOURNEY_UI_SELFTEST ok/total
#     --fx=full|mid|min                            fx level override
# Exit code 0 only when every check passes.

const J: = preload("res://core/modes/tower/journey.gd")
const U: = preload("res://core/modes/tower/tower_util.gd")
const TB: = preload("res://core/modes/tower/tower_board.gd")
const SCREEN: = preload("res://scripts/v10/tower/journey_screen.gd")

# UX_RULES §4.3 jargon and §4.2 «было» (token prefixes, lower case) + symbols
const BANNED_PREFIX: = ["гарант", "пити", "pity", "гача", "ролл", "крутк", "фивер", "ивент", "квартал", "перк", "ульт",
	"риичи", "яку", "банер", "донат", "богин", "лихорадк", "гардероб", "поручени", "визит", "режим"]
const BANNED_TOKEN: = ["sr", "ssr+", "sr+", "r", "хит", "выгодно", "best", "new", "id", "успей", "штук", "топ"]
const BANNED_SUB: = ["₽", "%", "50/50", "последний шанс", "рядом с тобой", "лунная лестница", "только сегодня", "сесть за стол"]

class StubMain:
	extends Node
	var calls: Array = []
	func go(id: String, a: = {}) -> void:
		calls.append(["go", id, a])
	func back() -> void:
		calls.append(["back"])
	func toast(t: String, icon: = "") -> void:
		calls.append(["toast", t, icon])
	func show_chrome(top: bool, nav: bool) -> void:
		calls.append(["chrome", top, nav])
	func last(kind: String) -> Array:
		for i in range(calls.size() - 1, -1, -1):
			if String(calls[i][0]) == kind:
				return calls[i]
		return []

var args: = {}
var ok: = 0
var total: = 0
var fails: = []
var notes: = []
var strict: = true
var W0: = 0
var embedded: = false
var _wall_s: = 0.0


func _process(delta: float) -> void:
	_wall_s += delta / maxf(0.001, Engine.time_scale)


func _ready() -> void:
	if embedded:
		G.demo = true
		TB._test_profile_id = "demo"
		W0 = U.week_id(1795521600)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv: = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	G.demo = true  # never write the player's real save from the demo
	TB._test_profile_id = "demo"
	if args.has("fx"):
		V10Hud2Util.fx_override = String(args.fx)
	W0 = U.week_id(1795521600)  # Tue 24 Nov 2026, 12:00 UTC
	if String(args.get("selftest", "0")) == "1":
		var code: int = await _selftest()
		get_tree().quit(code)
	elif args.has("shots"):
		await _shots(String(args.shots))
		get_tree().quit(0)
	else:
		var st: = String(args.get("state", "new"))
		var a: = setup(st)
		var scr = Control.new()
		scr.set_script(SCREEN)
		add_child(scr)
		scr.call("build", StubMain.new(), a)


# ---------------------------------------------------------------- states

# a week of the given theme index (0..7) and boss index (0..4 of the released heroines), near W0
func week_for(theme_i: int, boss_i: int) -> int:
	var n: = U.released().size()
	for d in range(0, 200):
		for w in [W0 + d, W0 - d]:
			if posmod(w, J.THEMES.size()) == theme_i and posmod(w, n) == boss_i:
				return w
	return W0


func _base(w: int, hours: float, rp: = 400, partner: = "mc") -> void:
	U.fake_now = U.week_start(w) + int(hours * 3600.0)
	J._test_S = {"rp": rp, "level_partner": partner}
	J.st()


func _play_boards(run: Dictionary, n: int, pick: = true) -> void:
	for k in n:
		var res: = J.board_clear(run, {"secs": 92.0 + 7.0 * k, "max_combo": 8 + k})
		if not res.done and pick and not (run.offer as Array).is_empty():
			J.pick_blessing(run, String(run.offer[0]))


func _lose_hearts(run: Dictionary, n: int) -> void:
	for k in n:
		J.on_overflow(run, {})


# sets the save and the clock for a state; returns the args for build()
func setup(st: String) -> Dictionary:
	match st:
		"run":
			_base(week_for(5, 1), 40.0, 400, "rin")
			var r: = J.start("rin")
			_play_boards(r, 2)
			_lose_hearts(r, 1)
		"spent":
			_base(week_for(2, 2), 70.0, 400, "hana")
			var r1: = J.start("hana")
			_play_boards(r1, 3)
			_lose_hearts(r1, 3)
			J.finish(r1)
			var r2: = J.start("hana")
			_play_boards(r2, 4)
			_lose_hearts(r2, 3)
			J.finish(r2)
		"last48":
			var w: = week_for(3, 0)
			_base(w, 0.0, 400, "mc")
			U.fake_now = U.week_end(w) - 31 * 3600 + 60
			var r3: = J.start("mc")
			_play_boards(r3, 2)
			_lose_hearts(r3, 3)
			J.finish(r3)
		"locked":
			_base(W0, 30.0, 0, "mc")
		"result":
			_base(week_for(7, 4), 50.0, 400, "nova")
			var r4: = J.start("nova")
			_play_boards(r4, 5)
			var fin: = J.finish(r4)
			return {"result": fin}
		_:
			_base(W0, 30.0, 400, "yue")
	return {}


# ---------------------------------------------------------------- shots

func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var vsz: = get_viewport_rect().size
	var path: = "%s/journey_%s_%dx%d.png" % [dir, name, int(vsz.x), int(vsz.y)]
	get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path)


# contrast data: every visible label's rect and colour + the same frame without text (tools/contrast check)
func _contrast_dump(dir: String, name: String, scr: Node) -> void:
	var ls: = []
	_labels(scr, ls)
	var rows: = []
	for l in ls:
		var lb: Label = l
		var r: = lb.get_global_rect()
		var fs: = int(lb.label_settings.font_size)
		var tw: = lb.label_settings.font.get_string_size(lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x0: = r.position.x
		if lb.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
			x0 = r.position.x + (r.size.x - minf(tw, r.size.x)) * 0.5
		var lh: = float(V10Type.line_h(fs))
		var lines: = maxi(1, lb.get_line_count()) if lb.autowrap_mode != TextServer.AUTOWRAP_OFF else 1
		var h: = lh * lines
		var y0: = r.position.y + (r.size.y - h) * 0.5 if lb.vertical_alignment == VERTICAL_ALIGNMENT_CENTER else r.position.y
		var c: Color = lb.label_settings.font_color
		var m: = lb.get_global_transform_with_canvas()
		rows.append({"text": lb.text, "x": x0, "y": y0, "w": minf(tw, r.size.x), "h": h, "r": c.r, "g": c.g, "b": c.b, "a": c.a * lb.modulate.a,
			"shadow": lb.label_settings.shadow_size > 0, "size": fs})
	var vsz: = get_viewport_rect().size
	var f: = FileAccess.open("%s/contrast_%s_%dx%d.json" % [dir, name, int(vsz.x), int(vsz.y)], FileAccess.WRITE)
	f.store_string(JSON.stringify(rows))
	f.close()
	for l in ls:
		(l as Label).visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/bg_%s_%dx%d.png" % [dir, name, int(vsz.x), int(vsz.y)])
	for l in ls:
		(l as Label).visible = true


func _mount_root(a: Dictionary):
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var scr = Control.new()
	scr.set_script(SCREEN)
	add_child(scr)
	scr.call("build", StubMain.new(), a)
	return scr


func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var vsz: = get_viewport_rect().size
	V10Hud2Util.sim_insets = {"top": 48, "bottom": 24} if vsz.y >= 1500.0 else {}
	await get_tree().process_frame
	# the signature motion: the scroll mid-unroll
	var scr = _mount_root(setup("new"))
	await get_tree().create_timer(0.3).timeout
	await _shot(dir, "unroll_mid")
	for st in ["new", "run", "spent", "last48", "locked"]:
		scr = _mount_root(setup(st))
		await get_tree().create_timer(1.3).timeout
		await _shot(dir, st)
		await _contrast_dump(dir, st, scr)
	scr = _mount_root(setup("spent"))
	scr.skip_intro()
	scr.call("_open_table")
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "table")
	scr = _mount_root(setup("new"))
	scr.skip_intro()
	scr.call("_open_table")
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "table_unranked")
	scr = _mount_root(setup("new"))
	scr.skip_intro()
	scr.call("_open_rules")
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "rules")
	scr = _mount_root(setup("result"))
	await get_tree().create_timer(1.3).timeout
	await _shot(dir, "result")
	U.fake_now = 0


# ---------------------------------------------------------------- selftest

func check(cond: bool, what: String) -> void:
	if not strict:
		# a window of another part (C): report, never count
		if not cond:
			notes.append(what)
		return
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		print("  FAIL ", what)


func _mount(sz: Vector2i, a: Dictionary) -> Dictionary:
	V10Hud2Util.sim_insets = {"top": 48, "bottom": 24} if sz.y >= 1500 else {}
	var sv: = SubViewport.new()
	sv.size = sz
	sv.disable_3d = true
	add_child(sv)
	var stub: = StubMain.new()
	sv.add_child(stub)
	var scr = Control.new()
	scr.set_script(SCREEN)
	sv.add_child(scr)
	scr.call("build", stub, a)
	await get_tree().process_frame
	scr.skip_intro()
	await get_tree().process_frame
	return {"sv": sv, "scr": scr, "stub": stub}


func _unmount(m: Dictionary) -> void:
	var sv: SubViewport = m.sv
	remove_child(sv)
	sv.queue_free()


func _words(t: String) -> int:
	var n: = 0
	var rx: = RegEx.new()
	rx.compile("[A-Za-zА-Яа-яЁё]+")
	n = rx.search_all(t).size()
	return n


func _banned(t: String) -> String:
	var low: = t.to_lower()
	for s in BANNED_SUB:
		if s in low:
			return s
	var rx: = RegEx.new()
	rx.compile("[a-zа-яё0-9+/]+")
	for m in rx.search_all(low):
		var tok: = m.get_string()
		if tok in BANNED_TOKEN:
			return tok
		for p in BANNED_PREFIX:
			if tok.begins_with(p):
				return tok
	return ""


func _labels(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Label and (n as Label).text.strip_edges() != "":
		out.append(n)
	for c in n.get_children():
		_labels(c, out)


func _taps(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n.has_meta("ux_role") and n is Control:
		out.append(n)
	for c in n.get_children():
		_taps(c, out)


# the UX audit of one screen or sheet (UX_RULES §3.4, §3.7, §4, §6.1; HUD v2 §3)
func audit(tag: String, root: Node, vsz: Vector2) -> Dictionary:
	var roles: = V10TowerUI.roles_of(root)
	check(int(roles.primary) == 1, "%s: exactly 1 primary (%d)" % [tag, int(roles.primary)])
	check(int(roles.secondary) <= 2, "%s: <= 2 secondary (%d)" % [tag, int(roles.secondary)])
	check(int(roles.tertiary) <= 2, "%s: <= 2 tertiary (%d)" % [tag, int(roles.tertiary)])
	var ls: = []
	_labels(root, ls)
	var words: = 0
	var sizes: = {}
	var bad_size: = []
	var bad_word: = []
	var clipped: = []
	var outside: = []
	var screen: = Rect2(Vector2.ZERO, vsz)
	for l in ls:
		var lb: Label = l
		var fs: = int(lb.label_settings.font_size) if lb.label_settings else 16
		var is_over: = String(lb.get_meta("v10_role", "")) == "overline"
		if fs < 18 and not (is_over and fs == 15):
			bad_size.append("%s(%d)" % [lb.text, fs])
		if not is_over:
			sizes[fs] = true
		words += _words(lb.text)
		var bw: = _banned(lb.text)
		if bw != "":
			bad_word.append("%s [%s]" % [lb.text, bw])
		var f: Font = lb.label_settings.font if lb.label_settings else lb.get_theme_font("font")
		var r: = lb.get_global_rect()
		if lb.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var tw: = f.get_string_size(lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if tw > lb.size.x + 1.0:
				clipped.append("%s (%d > %d)" % [lb.text, int(tw), int(lb.size.x)])
			var x0: = r.position.x
			if lb.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
				x0 = r.position.x + (r.size.x - tw) * 0.5
			elif lb.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
				x0 = r.end.x - tw
			if x0 < -0.5 or x0 + minf(tw, r.size.x) > vsz.x + 0.5:
				outside.append(lb.text)
		else:
			if lb.max_lines_visible > 0 and lb.get_line_count() > lb.max_lines_visible:
				clipped.append("%s (%d lines)" % [lb.text, lb.get_line_count()])
			if not screen.grow(0.5).encloses(r):
				outside.append(lb.text)
		if r.end.y > vsz.y + 0.5 or r.position.y < -0.5:
			outside.append(lb.text)
	check(bad_size.is_empty(), "%s: text >= 18 px (overline 15) %s" % [tag, str(bad_size)])
	check(bad_word.is_empty(), "%s: no banned words %s" % [tag, str(bad_word)])
	check(clipped.is_empty(), "%s: no clipped text %s" % [tag, str(clipped)])
	check(outside.is_empty(), "%s: text inside the screen %s" % [tag, str(outside)])
	check(words <= 60, "%s: <= 60 words (%d)" % [tag, words])
	check(sizes.size() <= 4, "%s: <= 4 type sizes %s" % [tag, str(sizes.keys())])
	var taps: = []
	_taps(root, taps)
	var small: = []
	var out_t: = []
	var overl: = []
	var rects: = []
	for t in taps:
		var r2: Rect2 = (t as Control).get_global_rect()
		if r2.size.x < 79.5 or r2.size.y < 79.5:
			small.append("%s %s" % [t.name, str(r2.size)])
		if not screen.grow(0.5).encloses(r2):
			out_t.append("%s %s" % [t.name, str(r2)])
		for q in rects:
			if (q[1] as Rect2).grow(-0.5).intersects(r2.grow(-0.5)):
				overl.append("%s × %s" % [q[0], t.name])
		rects.append([t.name, r2])
	check(small.is_empty(), "%s: hit zones >= 80 px %s" % [tag, str(small)])
	check(out_t.is_empty(), "%s: taps inside the screen %s" % [tag, str(out_t)])
	check(overl.is_empty(), "%s: taps do not overlap %s" % [tag, str(overl)])
	check(taps.size() <= 10, "%s: <= 10 taps (%d)" % [tag, taps.size()])
	var texts: = []
	for l in ls:
		texts.append((l as Label).text)
	return {"roles": roles, "texts": texts, "words": words}


func _has_text(texts: Array, sub: String) -> bool:
	for t in texts:
		if sub in String(t):
			return true
	return false


func _selftest() -> int:
	var t0: = _wall_s
	var themes: = {}
	var bosses: = {}
	for sz in [Vector2i(720, 1280), Vector2i(720, 1600)]:
		var tag0: = "%dx%d" % [sz.x, sz.y]
		var vsz: = Vector2(sz)
		# --- new week: 2 of 2
		var a: = setup("new")
		var m: = await _mount(sz, a)
		var scr = m.scr
		var info: = J.week_info()
		themes[String(info.theme.id)] = true
		bosses[String(info.boss)] = true
		var au: = audit(tag0 + " new", scr, vsz)
		check(scr.state == "new" and scr.primary.text == "Начать забег", tag0 + " new: primary «Начать забег»")
		check(scr.buttons.has("practice") and scr.buttons.has("table"), tag0 + " new: secondaries Тренировка + Таблица")
		check(_has_text(au.texts, "Попытки: 2 из 2"), tag0 + " new: attempts 2 of 2")
		var rf: String = scr.labels.refresh.text
		check("МСК" in rf and rf.begins_with("Обновится в пн, 30 ноября, 04:00 МСК"), tag0 + " new: date with МСК: " + rf)
		check(not ("ещё" in rf) and not bool(info.countdown), tag0 + " new: no countdown before the last 48 h")
		check(_has_text(au.texts, "Честный зачёт: наряды не дают силы"), tag0 + " new: honest plate")
		check(_has_text(au.texts, String(info.theme.name)) and _has_text(au.texts, String(info.trick.name)), tag0 + " new: theme and trick on the scroll")
		check(scr.scroll.node_states() == ["current", "future", "future", "future", "future"], tag0 + " new: path states")
		var p: V10Button = scr.primary
		check(p.get_global_rect().position.y >= vsz.y * 2.0 / 3.0 - 1.0 and p.size.x >= 440 and p.size.y >= 104, tag0 + " new: primary in the bottom third, >= 440×104")
		var hb: Rect2 = scr.header.get_global_rect()
		check(scr.scroll.get_global_rect().position.y >= hb.end.y - 1.0, tag0 + " new: scroll below the header")
		# press «Начать забег»: the attempt is spent and tower_play gets a valid run
		var before: = J.attempts_left()
		p.pressed.emit()
		var call: Array = (m.stub as StubMain).last("go")
		var ok_go: = call.size() == 3 and String(call[1]) == "tower_play" and String((call[2] as Dictionary).get("mode", "")) == "journey"
		check(ok_go, tag0 + " start: go(tower_play, journey) " + str(call))
		if ok_go:
			var run: Dictionary = call[2].run
			check(int(run.week) == int(info.week) and int(run.board) == 0 and int(run.hearts) == J.HEARTS and not bool(run.practice) and String(run.mode) == "journey",
				tag0 + " start: valid run")
			check(J.current_run() == run, tag0 + " start: the run is saved")
		check(J.attempts_left() == before - 1, tag0 + " start: the attempt is spent at the start")
		p.pressed.emit()
		check(J.attempts_left() == before - 1 and (m.stub as StubMain).calls.filter(func(c): return String(c[0]) == "go").size() == 1, tag0 + " start: a double tap spends nothing more")
		_unmount(m)
		# --- run on table 3, 2 hearts, 2 blessings
		a = setup("run")
		m = await _mount(sz, a)
		scr = m.scr
		info = J.week_info()
		themes[String(info.theme.id)] = true
		bosses[String(info.boss)] = true
		au = audit(tag0 + " run", scr, vsz)
		var cur: = J.current_run()
		check(int(cur.board) == 2 and int(cur.hearts) == 2 and (cur.bless as Dictionary).size() >= 1, tag0 + " run: state is table 3, 2 hearts")
		check(scr.primary.text == "Продолжить · стол 3 из 5", tag0 + " run: primary «Продолжить · стол 3 из 5» (%s)" % scr.primary.text)
		check(scr.scroll.node_states() == ["done", "done", "current", "future", "future"], tag0 + " run: path states " + str(scr.scroll.node_states()))
		check(_has_text(au.texts, "очков") and _has_text(au.texts, "благословени"), tag0 + " run: score and blessings on the scroll")
		before = J.attempts_left()
		scr.primary.pressed.emit()
		call = (m.stub as StubMain).last("go")
		check(call.size() == 3 and String(call[1]) == "tower_play" and (call[2] as Dictionary).get("run") == J.current_run() and J.attempts_left() == before,
			tag0 + " run: «Продолжить» opens the saved run without a new attempt")
		_unmount(m)
		# --- no attempts left: practice is the primary
		a = setup("spent")
		m = await _mount(sz, a)
		scr = m.scr
		info = J.week_info()
		themes[String(info.theme.id)] = true
		bosses[String(info.boss)] = true
		au = audit(tag0 + " spent", scr, vsz)
		check(scr.state == "spent" and scr.primary.text == "Тренировка" and not scr.buttons.has("practice") and scr.buttons.has("table"), tag0 + " spent: primary Тренировка, secondary Таблица")
		check(_has_text(au.texts, "Попытки этой недели закончились") and _has_text(au.texts, "Лучшее за неделю"), tag0 + " spent: attempts over + best of the week")
		# the table sheet (ranked)
		scr.call("_open_table")
		await get_tree().create_timer(0.3).timeout
		var sh = scr.sheet
		check(sh != null and scr.sheet_kind == "table", tag0 + " table: sheet open")
		if sh:
			var at: = audit(tag0 + " table", sh, vsz)
			var nh: = 0
			for t in at.texts:
				if "соперницы-героини (ИИ)" in String(t):
					nh += 1
			var others: = 0
			for pl in sh.find_children("*", "V10Plate", true, false):
				if not (pl as V10Plate).selected:
					others += 1
			check(nh >= 1 and nh == others, tag0 + " table: every heroine row is labelled (%d of %d)" % [nh, others])
			var sel: = 0
			for pl in sh.find_children("*", "V10Plate", true, false):
				if (pl as V10Plate).selected:
					sel += 1
			check(sel == 1, tag0 + " table: own row highlighted")
			check(not _has_text(at.texts, "Не в рейтинге"), tag0 + " table: ranked after an attempt")
		scr.close_sheet(true)
		check(scr.sheet == null, tag0 + " table: closes")
		scr.primary.pressed.emit()
		call = (m.stub as StubMain).last("go")
		check(call.size() == 3 and String(call[2].get("mode", "")) == "practice" and bool(call[2].run.practice) and J.attempts_left() == 0 and J.current_run().is_empty(),
			tag0 + " spent: practice run, nothing spent, nothing saved")
		_unmount(m)
		# --- the last 48 h: countdown
		a = setup("last48")
		m = await _mount(sz, a)
		scr = m.scr
		info = J.week_info()
		themes[String(info.theme.id)] = true
		bosses[String(info.boss)] = true
		au = audit(tag0 + " last48", scr, vsz)
		rf = scr.labels.refresh.text
		check(bool(info.countdown) and rf.ends_with("· ещё 31 ч") and "МСК" in rf, tag0 + " last48: date + «ещё 31 ч»: " + rf)
		_unmount(m)
		# --- locked
		a = setup("locked")
		m = await _mount(sz, a)
		scr = m.scr
		au = audit(tag0 + " locked", scr, vsz)
		check(scr.state == "locked" and scr.scroll.locked and scr.primary.text == "К столам", tag0 + " locked: rolled scroll, «К столам»")
		check(_has_text(au.texts, "Откроется: на ранге Нефрит I"), tag0 + " locked: «Откроется: на ранге Нефрит I»")
		check(not scr.buttons.has("practice") and not scr.buttons.has("table"), tag0 + " locked: no secondaries")
		scr.primary.pressed.emit()
		check((m.stub as StubMain).last("back").size() == 1, tag0 + " locked: «К столам» goes back")
		_unmount(m)
		# --- rules and an unranked table on a fresh week
		a = setup("new")
		m = await _mount(sz, a)
		scr = m.scr
		scr.call("_open_rules")
		await get_tree().create_timer(0.3).timeout
		sh = scr.sheet
		check(sh != null and scr.sheet_kind == "rules", tag0 + " rules: sheet open")
		if sh:
			var ar: = audit(tag0 + " rules", sh, vsz)
			var all: = " ".join(ar.texts)
			check("4 000" in all and "7 000" in all and "10 000" in all and "Бронза" in all and "Золото" in all, tag0 + " rules: tiers from econ")
			check("30 · 60 · 100" in all and "билет желания" in all and "сердца" in all and "списывается при старте" in all, tag0 + " rules: boards, ticket, hearts, attempt")
		scr.call("_open_table")
		await get_tree().create_timer(0.3).timeout
		check(scr.get_children().filter(func(c): return c.name.begins_with("Sheet") and not c.is_queued_for_deletion()).size() == 1, tag0 + " sheets: never a sheet over a sheet")
		sh = scr.sheet
		if sh:
			var au2: = audit(tag0 + " table_unranked", sh, vsz)
			check(_has_text(au2.texts, "Не в рейтинге — пройди 1 стол") and not _has_text(au2.texts, "#"), tag0 + " table: «Не в рейтинге — пройди 1 стол» before the first attempt")
		scr.call("_on_back")
		check(scr.sheet == null, tag0 + " back closes the sheet first")
		_unmount(m)
		# --- the result of a run: shown once, reward granted once
		a = setup("result")
		info = J.week_info()
		themes[String(info.theme.id)] = true
		bosses[String(info.boss)] = true
		var fin: Dictionary = a.result
		var gems0: = V10Money.bal("gems")
		m = await _mount(sz, a)
		scr = m.scr
		await get_tree().create_timer(0.3).timeout
		check(scr.sheet != null and scr.sheet_kind == "result", tag0 + " result: the window is shown over the hub")
		check(V10Money.bal("gems") - gems0 == int(fin.reward.get("gems", 0)) and bool(fin.get("granted", false)), tag0 + " result: reward granted")
		var c_win: = ResourceLoader.exists("res://scripts/v10/tower/ui/tower_sheets.gd") and scr.call("_sheets_script") != null
		if scr.sheet:
			strict = true
			audit(tag0 + " result" + (" (part C window)" if c_win else ""), scr.sheet, vsz)
		if c_win:
			check(not scr.layer.visible, tag0 + " result: the hub hides under the full result window")
		# our own fallback window, audited strictly whatever part C ships
		scr.close_sheet(true)
		scr.call("_result_fallback", fin)
		await get_tree().create_timer(0.3).timeout
		check(scr.sheet != null and scr.sheet_kind == "result", tag0 + " result fallback: shown")
		if scr.sheet:
			var af: = audit(tag0 + " result fallback", scr.sheet, vsz)
			check(_has_text(af.texts, "Странствие пройдено") and _has_text(af.texts, "билет желания"), tag0 + " result fallback: title and ticket")
		_unmount(m)
		var m2: = await _mount(sz, a)
		check(V10Money.bal("gems") - gems0 == int(fin.reward.get("gems", 0)), tag0 + " result: a second build never grants again")
		_unmount(m2)
	check(themes.size() >= 3, "at least 3 week themes covered (%d)" % themes.size())
	check(bosses.size() >= 2, "at least 2 bosses covered (%d)" % bosses.size())
	# fx = min: the scroll appears in 120 ms with the same information
	V10Hud2Util.fx_override = "min"
	var a3: = setup("new")
	V10Hud2Util.sim_insets = {}
	var sv: = SubViewport.new()
	sv.size = Vector2i(720, 1280)
	add_child(sv)
	var stub3: = StubMain.new()
	sv.add_child(stub3)
	var s3 = Control.new()
	s3.set_script(SCREEN)
	sv.add_child(s3)
	s3.call("build", stub3, a3)
	check(s3.scroll.reveal >= 0.999, "fx=min: the scroll is open at once (fade only)")
	await get_tree().create_timer(0.2).timeout
	check(s3.scroll.modulate.a >= 0.999, "fx=min: faded in within 120 ms")
	remove_child(sv)
	sv.queue_free()
	V10Hud2Util.fx_override = String(args.get("fx", ""))
	V10Hud2Util.sim_insets = {}
	U.fake_now = 0
	# colours only from V10DS / V10TowerUI in the part-B files
	for f in ["res://scripts/v10/tower/journey_screen.gd", "res://scripts/v10/tower/ui/journey_scroll.gd"]:
		var src: = FileAccess.get_file_as_string(f)
		check(not ("Color(\"#" in src or "Color(0." in src or "Color(1" in src), "no colour literals in " + f.get_file())
	print("JOURNEY_UI_SELFTEST %d/%d (%d ms)" % [ok, total, int((_wall_s - t0) * 1000.0)])
	for f2 in fails:
		print("  - ", f2)
	for n2 in notes:
		print("  note (part C window, not counted): ", n2)
	return 0 if ok == total else 1


func run_embedded() -> Dictionary:
	await _selftest()
	J._test_S = null
	U.fake_now = 0
	V10Hud2Util.fx_override = ""
	V10Hud2Util.sim_insets = {}
	return {"ok": ok, "total": total, "fails": fails.duplicate()}
