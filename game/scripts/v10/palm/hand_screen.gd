class_name V10PalmScreen
extends Control

# V10PalmScreen — экран «Чтение руки» и «Разбор ожиданий» (docs/MODES.md §7.1, docs/0.10-spec.md R4, UX_RULES).
# Контракт экрана: setup(main, args) и build(main, args), сигнал finished(result), шторка «?» (3 правила),
# палитра V10DS «Тишина и лак», ровно одна главная кнопка ≥ 440×104 в нижней трети, ≤ 2 второстепенных, глубина ≤ 2.

signal finished(result: Dictionary)

const U: = preload("res://core/modes/palm/hand_util.gd")
const GEN: = preload("res://core/modes/palm/hand_gen.gd")
const ST: = preload("res://core/modes/palm/hand_state.gd")
const T: = preload("res://core/modes/palm/hand_text.gd")
const H: = preload("res://core/modes/palm/hand.gd")
const L: = preload("res://core/modes/palm/hand_lessons.gd")
const BOARD: = preload("res://scripts/v10/palm/hand_board.gd")

const COL_W: = 720.0
const M: = 32.0

const BTN_TO_DAILY: = "К руке дня"
const BTN_START_LESSON: = "Начать разбор %d"
const BTN_TO_LIST: = "К списку"
const BTN_GOT_IT: = "Понятно"
const COPIED_TEXT: = "Скопировано"
const NEW_FRAME_TEXT: = "Новая рамка: Читающая руки"

static var test_clip: = ""
static var use_test_clip: = false

var main = null
var args: Dictionary = {}
var session: V10Hand = null
var view: = "daily"
var header: V10Header = null
var page: Control = null
var board: V10HandBoard = null
var hand_view: Control = null
var strip_view: Control = null
var meta_lbl: Label = null
var btn_primary: V10Button = null
var btn_second: V10Button = null
var btn_second_b: V10Button = null
var active_sheet: V10BottomSheet = null
var shutter_grid: Control = null

var vs: = Vector2(720, 1280)
var cx: = 0.0
var safe_b: = 0.0
var _t0_ms: = 0
var _emitted: = false
var _local_host: Control = null
var _lesson_n: = 1
var _lesson_i: = 0
var _picked: Array = []


func build(m, a: Dictionary = {}) -> void:
	setup(m, a)


func setup(m, a: Dictionary = {}) -> void:
	main = m
	args = a.duplicate(true)
	_t0_ms = U.tick_ms()
	_emitted = false
	ST.register_save()
	ST.register_cos()
	if main and main.has_method("show_chrome"):
		main.call("show_chrome", false, false)
	if size.x <= 0.0 or size.y <= 0.0:
		var vr: = get_viewport_rect().size if is_inside_tree() else Vector2(720, 1280)
		size = vr if vr.x > 0.0 else Vector2(720, 1280)
	_metrics()
	for c in get_children():
		c.queue_free()
	var bg: = _PalmBg.new()
	bg.name = "Bg"
	bg.size = vs
	add_child(bg)
	header = V10Header.make(self, T.MODE, _on_back, open_help)
	if header.back_btn:
		header.back_btn.set_meta("ux_role", "tertiary")
	if header.help_btn:
		header.help_btn.set_meta("ux_role", "tertiary")
	_ensure_local_host()
	if args.get("session") is V10Hand:
		session = args.session
	elif args.get("entry") is Dictionary:
		session = H.for_entry(args.entry, String(args.get("hero", "yue")), bool(args.get("school", false)))
	elif String(args.get("day", "")) != "":
		session = H.for_key(String(args.day), bool(args.get("persist", true)))
	else:
		session = H.today()
	if String(args.get("view", "daily")) == "lessons":
		show_lessons()
	else:
		show_daily()


func _metrics() -> void:
	vs = get_viewport_rect().size if is_inside_tree() else size
	if vs.x <= 0.0 or vs.y <= 0.0:
		vs = Vector2(720, 1280)
	size = vs
	cx = floorf(maxf(0.0, (vs.x - COL_W) * 0.5))
	safe_b = float(main.safe_bottom) if (main and "safe_bottom" in main) else float(V10Hud2Util.safe_insets(vs).bottom)


func _ensure_local_host() -> void:
	if main and main.get("overlay") is Control:
		return
	_local_host = _LocalSheetHost.new()
	_local_host.name = "LocalSheetHost"
	_local_host.size = vs
	_local_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_local_host)


func _sheet_host():
	if main and main.get("overlay") is Control:
		return main
	return _local_host


func _y0() -> float:
	return V10Header.content_y(vs)


func _clear_page() -> void:
	board = null
	hand_view = null
	strip_view = null
	meta_lbl = null
	btn_primary = null
	btn_second = null
	btn_second_b = null
	if page and is_instance_valid(page):
		page.free()
	page = Control.new()
	page.name = "Page"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.position = Vector2(cx, 0)
	page.size = Vector2(COL_W, vs.y)
	add_child(page)
	move_child(page, header.get_index())


func _make_btn(kind: String, text: String, sz: Vector2, cb: Callable, role: String) -> V10Button:
	var b: = V10Button.make(kind, text, sz)
	b.set_meta("ux_role", role)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


func _make_lbl(txt: String, role: String, px: int, col: Color, w: float, max_l: int = 1) -> Label:
	var l: = V10Type.label(txt, role, px, col)
	if max_l > 1:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = max_l
	else:
		l.clip_text = true
	l.size = Vector2(w, float(px) * 1.42 * float(max_l))
	return l


func _place_actions(p_txt: String, on_p: Callable, s1_txt: String = "", on_s1: Callable = Callable(), s2_txt: String = "", on_s2: Callable = Callable()) -> float:
	var yb: = vs.y - safe_b - 20.0
	if s1_txt != "" and s2_txt != "":
		btn_second = _make_btn("secondary", s1_txt, Vector2(272, 80), on_s1, "secondary")
		btn_second.position = Vector2((COL_W - 560.0) * 0.5, yb - 80.0)
		page.add_child(btn_second)
		btn_second_b = _make_btn("secondary", s2_txt, Vector2(272, 80), on_s2, "secondary")
		btn_second_b.position = Vector2((COL_W - 560.0) * 0.5 + 288.0, yb - 80.0)
		page.add_child(btn_second_b)
		yb -= 88.0
	elif s1_txt != "":
		btn_second = _make_btn("secondary", s1_txt, Vector2(560, 80), on_s1, "secondary")
		btn_second.position = Vector2((COL_W - 560.0) * 0.5, yb - 80.0)
		page.add_child(btn_second)
		yb -= 88.0
	btn_primary = _make_btn("play", p_txt, Vector2(560, 104), on_p, "primary")
	btn_primary.position = Vector2((COL_W - 560.0) * 0.5, yb - 104.0)
	page.add_child(btn_primary)
	return btn_primary.position.y

# ================================================================== daily & verdict

func show_daily() -> void:
	view = "daily"
	header.set_title(T.MODE)
	_clear_page()
	var stt: = session.status()
	if String(stt.get("state", "open")) == "locked" and session.persist:
		var py: = _place_actions(T.BTN_DONE, _finish_and_leave, T.BTN_LESSONS, show_lessons)
		var lock_box: = _Plate.new()
		lock_box.position = Vector2(M, _y0() + 80.0)
		lock_box.size = Vector2(COL_W - 2.0 * M, 180.0)
		page.add_child(lock_box)
		var lt: = _make_lbl(String(stt.get("text", ST.lock_text())), "ui", 22, V10DS.PAPER_100, lock_box.size.x - 48.0, 2)
		lt.position = Vector2(24, 36)
		lock_box.add_child(lt)
		var ls: = _make_lbl(T.MODE_LINE, "ui", 18, V10DS.PAPER_500, lock_box.size.x - 48.0, 2)
		ls.position = Vector2(24, 104)
		lock_box.add_child(ls)
		if py < 0.0:
			pass
		return
	if not session.can_guess():
		_build_verdict()
		return
	var top_y: = _y0()
	var top_box: = _Plate.new()
	top_box.name = "HandPlate"
	top_box.position = Vector2(M, top_y)
	top_box.size = Vector2(COL_W - 2.0 * M, 162.0)
	page.add_child(top_box)
	meta_lbl = _make_lbl(_meta_line(), "ui", 18, V10DS.GOLD_300 if session.mult() >= 2 else V10DS.PAPER_300, top_box.size.x - 32.0, 1)
	meta_lbl.name = "MetaLine"
	meta_lbl.position = Vector2(16, 10)
	top_box.add_child(meta_lbl)
	var sf_pos: Array = session.school_form().positions if session.school else []
	hand_view = _HandView.new()
	hand_view.name = "HandRow"
	hand_view.position = Vector2(16, 40)
	hand_view.size = Vector2(top_box.size.x - 32.0, 68.0)
	hand_view.configure(session.hand, session.flipped, session.sleeve, [], sf_pos, false, session.closed)
	top_box.add_child(hand_view)
	strip_view = _StripView.new()
	strip_view.name = "StripRow"
	strip_view.position = Vector2(16, 118)
	strip_view.size = Vector2(top_box.size.x - 32.0, 34.0)
	strip_view.configure(session.strip, _strip_fallback())
	top_box.add_child(strip_view)

	var act_y: = _place_actions(T.BTN_GUESS, open_shutter, T.BTN_LESSONS, show_lessons)
	btn_primary.name = "BtnGuess"
	if btn_second:
		btn_second.name = "BtnLessons"

	var zone_top: = top_y + top_box.size.y + 12.0
	var zone_bot: = act_y - 12.0
	if session.closed:
		var cbox: = _Plate.new()
		cbox.name = "ClosedPlate"
		cbox.position = Vector2(M, zone_top + maxf(16.0, (zone_bot - zone_top - 160.0) * 0.5))
		cbox.size = Vector2(COL_W - 2.0 * M, 152.0)
		page.add_child(cbox)
		var ct: = _make_lbl(T.TABLE_CLOSED, "display", 32, V10DS.PAPER_100, cbox.size.x - 48.0, 1)
		ct.position = Vector2(24, 28)
		cbox.add_child(ct)
		var cs: = _make_lbl(T.TABLE_CLOSED_SUB, "ui", 22, V10DS.PAPER_300, cbox.size.x - 48.0, 2)
		cs.position = Vector2(24, 82)
		cbox.add_child(cs)
		return

	var tray_h: = 88.0
	var tray_y: = zone_bot - tray_h
	var tray_bar: = _TrayBar.new()
	tray_bar.name = "TrayBar"
	tray_bar.position = Vector2(M, tray_y)
	tray_bar.size = Vector2(COL_W - 2.0 * M, tray_h)
	page.add_child(tray_bar)

	var brect: = Rect2(16.0, zone_top, COL_W - 32.0, maxf(240.0, tray_y - zone_top - 8.0))
	board = BOARD.new()
	board.name = "HandBoard"
	board.slots = BOARD.SLOTS_HAND
	page.add_child(board)
	board.setup(session.board_cfg())
	_sync_board_taken()
	board.fit_into(brect)
	var gslots: Array[Vector2] = []
	for r in tray_bar.slot_rects():
		var lp: Vector2 = tray_bar.position + r.get_center()
		gslots.append(page.get_global_transform() * lp)
	board.slot_pos = gslots
	board.slot_size = 76.0
	board.kind_taken.connect(_on_kind_taken)
	board.failed.connect(_on_board_failed)
	board.cleared.connect(_on_board_cleared)


func _sync_board_taken() -> void:
	if board == null or session.taken.is_empty():
		return
	var order: = board.tiles.duplicate()
	order.sort_custom(func(a, b): return a.step < b.step)
	var rem: = session.taken.duplicate()
	var i: = 0
	while i + 1 < order.size() and not rem.is_empty():
		var a: Tile = order[i]
		var b: Tile = order[i + 1]
		var idx: = rem.find(a.face)
		if idx >= 0:
			rem.remove_at(idx)
			a.alive = false
			b.alive = false
			a.visible = false
			b.visible = false
		i += 2


func _meta_line() -> String:
	return "%s · %s · %s" % [T.HERO_OF_DAY % session.hero_name(), T.CLOSED_N % session.hidden_count(), T.BOLD % session.mult()]


func _strip_fallback() -> String:
	if session.school:
		return T.SCHOOL_FORM % String(session.school_form().title).to_lower()
	return T.MODE_SUB


func _on_kind_taken(kind: int) -> void:
	var r: = session.reveal(kind)
	if meta_lbl:
		meta_lbl.text = _meta_line()
		meta_lbl.label_settings = V10Type.settings("ui", 18, V10DS.GOLD_300 if session.mult() >= 2 else V10DS.PAPER_300)
	if hand_view:
		var sf_pos: Array = session.school_form().positions if session.school else []
		hand_view.configure(session.hand, session.flipped, session.sleeve, [], sf_pos, false, session.closed)
		if not (r.get("positions", []) as Array).is_empty() and V9Feel.can_fx():
			hand_view.pivot_offset = hand_view.size * 0.5
			hand_view.scale = Vector2(1.02, 1.04)
			hand_view.create_tween().tween_property(hand_view, "scale", Vector2.ONE, 0.16)
	if strip_view:
		strip_view.configure(session.strip, _strip_fallback())
	_save_if_needed()


func _on_board_cleared() -> void:
	if hand_view:
		var sf_pos: Array = session.school_form().positions if session.school else []
		hand_view.configure(session.hand, session.flipped, session.sleeve, [], sf_pos, false, true)


func _on_board_failed() -> void:
	session.close_table()
	_save_if_needed()
	show_daily()


func _build_verdict() -> void:
	var res: Dictionary = session.result
	var right: = bool(res.get("correct", false))
	var y: = _y0()
	var card: = _Plate.new()
	card.name = "VerdictPlate"
	card.accent = V10DS.GOLD_500 if right else V10DS.ROSE_300
	card.position = Vector2(M, y)
	card.size = Vector2(COL_W - 2.0 * M, 436.0)
	page.add_child(card)

	var h_line: = _make_lbl(T.HERO_OF_DAY % session.hero_name(), "ui", 18, V10DS.PAPER_500, card.size.x - 48.0, 1)
	h_line.position = Vector2(24, 18)
	card.add_child(h_line)

	var stamp_txt: = T.STAMP if right else T.WRONG
	var stamp_lbl: = _make_lbl(stamp_txt, "display", 32, V10DS.GOLD_300 if right else V10DS.ROSE_300, card.size.x - 48.0, 1)
	stamp_lbl.name = "VerdictTitle"
	stamp_lbl.position = Vector2(24, 48)
	card.add_child(stamp_lbl)

	var say_lbl: = _make_lbl(String(res.get("say", T.say(session.hero, right))), "ui", 22, V10DS.PAPER_100, card.size.x - 48.0, 2)
	say_lbl.position = Vector2(24, 96)
	card.add_child(say_lbl)

	hand_view = _HandView.new()
	hand_view.name = "RevealedHand"
	hand_view.position = Vector2(16, 166)
	hand_view.size = Vector2(card.size.x - 32.0, 68.0)
	hand_view.configure(session.hand, session.flipped, session.sleeve, res.get("waits", session.waits), [], true, true)
	card.add_child(hand_view)

	var exp_lbl: = _make_lbl(String(res.get("explanation", session.explain())), "ui", 22, V10DS.PAPER_100, card.size.x - 48.0, 3)
	exp_lbl.name = "Explanation"
	exp_lbl.position = Vector2(24, 248)
	card.add_child(exp_lbl)

	var gems_n: = int(res.get("gems", ST.gems_for(right, int(res.get("mult", 1)))))
	var bond_n: = int(res.get("bond", int(U.econ("hand.bond"))))
	var rew_txt: = "%s · %s" % [U.gems_text(gems_n), T.REWARD_BOND % bond_n]
	var rew_lbl: = _make_lbl(rew_txt, "ui", 22, V10DS.GOLD_300, card.size.x - 48.0, 1)
	rew_lbl.name = "RewardLine"
	rew_lbl.position = Vector2(24, 344)
	card.add_child(rew_lbl)

	var tail: = T.NEXT_HAND
	var cos_new: Array = res.get("cos_new", [])
	if not cos_new.is_empty():
		tail = NEW_FRAME_TEXT
	elif right and int(res.get("streak", 0)) >= 2:
		tail = "%s · %s" % [T.STREAK % int(res.streak), T.NEXT_HAND]
	meta_lbl = _make_lbl(tail, "ui", 18, V10DS.JADE_300 if not cos_new.is_empty() else V10DS.PAPER_500, card.size.x - 48.0, 1)
	meta_lbl.name = "SubLine"
	meta_lbl.position = Vector2(24, 386)
	card.add_child(meta_lbl)

	_place_actions(T.BTN_DONE, _finish_and_leave, T.BTN_SHARE, copy_share, T.BTN_LESSONS, show_lessons)
	btn_primary.name = "BtnDone"
	if btn_second:
		btn_second.name = "BtnShare"
	if btn_second_b:
		btn_second_b.name = "BtnLessons"


func copy_share() -> void:
	var txt: = session.share_text()
	if txt == "":
		return
	_clip_set(txt)
	if meta_lbl:
		meta_lbl.text = COPIED_TEXT
		meta_lbl.label_settings = V10Type.settings("ui", 18, V10DS.JADE_300)

# ================================================================== shutter & confirm (depth == 1)

func open_shutter() -> V10BottomSheet:
	if not session.can_guess():
		return null
	active_sheet = V10BottomSheet.open(_sheet_host(), T.SHUTTER_TITLE)
	active_sheet.name = "PalmShutterSheet"
	_fill_shutter_grid(active_sheet)
	return active_sheet


func _fill_shutter_grid(sh: V10BottomSheet) -> void:
	for c in sh.body.get_children():
		c.queue_free()
	sh.title_l.text = T.SHUTTER_TITLE
	var sub_txt: = "%s · %s" % [T.BOLD % session.mult(), T.BOLD_SUB]
	var sub_lbl: = _make_lbl(sub_txt, "ui", 18, V10DS.GOLD_300 if session.mult() >= 2 else V10DS.PAPER_300, 656.0, 2)
	sub_lbl.name = "ShutterSub"
	sh.add_body(sub_lbl, 0.0)
	var rows: = session.shutter()
	shutter_grid = _TileShutterGrid.new()
	shutter_grid.name = "ShutterGrid"
	shutter_grid.size = Vector2(656.0, 368.0)
	shutter_grid.setup_shutter(rows, [], false)
	shutter_grid.tile_tapped.connect(func(k: int, dimmed: bool):
		if dimmed:
			sub_lbl.text = T.SHUTTER_DIM
			sub_lbl.label_settings = V10Type.settings("ui", 18, V10DS.ROSE_300)
			return
		_fill_confirm_sheet(sh, k))
	sh.add_body(shutter_grid, 48.0)
	sh.finish(424.0)


func pick_shutter_kind(kind: int) -> void:
	if active_sheet == null or not is_instance_valid(active_sheet):
		open_shutter()
	if session.impossible(kind):
		return
	_fill_confirm_sheet(active_sheet, kind)


func _fill_confirm_sheet(sh: V10BottomSheet, kind: int) -> void:
	shutter_grid = null
	for c in sh.body.get_children():
		c.queue_free()
	sh.title_l.text = T.ASK % GEN.name(kind)
	var prev: = _SingleCardView.new(kind)
	prev.name = "ConfirmTile"
	prev.size = Vector2(96.0, 132.0)
	sh.add_body(prev, 8.0, true)
	var b_lbl: = _make_lbl("%s · %s" % [T.CLOSED_N % session.hidden_count(), T.BOLD % session.mult()], "ui", 22, V10DS.GOLD_300, 656.0, 1)
	b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sh.add_body(b_lbl, 152.0)
	var yes_btn: = _make_btn("play", T.BTN_YES, Vector2(560, 104), func():
		sh.close()
		active_sheet = null
		submit_guess(kind), "primary")
	yes_btn.name = "BtnConfirmYes"
	sh.add_body(yes_btn, 204.0, true)
	var no_btn: = _make_btn("secondary", T.BTN_NO, Vector2(560, 80), func():
		_fill_shutter_grid(sh), "secondary")
	no_btn.name = "BtnConfirmNo"
	sh.add_body(no_btn, 316.0, true)
	sh.finish(404.0)


func submit_guess(kind: int) -> Dictionary:
	var res: = session.guess(kind)
	if not bool(res.get("ok", false)):
		return res
	var af: = U.cls("V10Afisha")
	if af and U.has_fn(af, "on_game_ended"):
		af.call("on_game_ended", {"mode": "hand", "win": bool(res.get("correct", false))})
	_save_if_needed()
	show_daily()
	return res


# ================================================================== lessons («Разбор ожиданий»)

func show_lessons() -> void:
	view = "lessons"
	header.set_title(T.LESSONS_TITLE)
	_clear_page()
	var y: = _y0()
	var sub: = _make_lbl(T.LESSONS_SUB, "ui", 22, V10DS.PAPER_300, COL_W - 2.0 * M, 1)
	sub.position = Vector2(M, y)
	page.add_child(sub)
	y += 44.0

	# UX_RULES В-8: все открытые разборы + не более одного серого замка подряд (дальше скрыто)
	var vis: Array = []
	var lock_added: = false
	var first_unfinished: = 1
	var found_unfinished: = false
	for entry in L.LESSONS:
		var n: = int(entry.n)
		if L.is_open(n):
			vis.append(entry)
			if not L.done(n) and not found_unfinished:
				first_unfinished = n
				found_unfinished = true
		elif not lock_added:
			vis.append(entry)
			lock_added = true
	if not found_unfinished:
		first_unfinished = clampi(_lesson_n, 1, L.LESSONS.size())
	_lesson_n = first_unfinished
	while vis.size() > 5:
		if int(vis[0].n) < _lesson_n - 1:
			vis.pop_front()
		else:
			vis.pop_back()

	var act_y: = _place_actions(BTN_START_LESSON % _lesson_n, func(): show_lesson_task(_lesson_n, 0), BTN_TO_DAILY, show_daily)
	btn_primary.name = "BtnStartLesson"
	if btn_second:
		btn_second.name = "BtnBackDaily"

	var row_h: = 88.0
	for entry in vis:
		if y + row_h > act_y - 12.0:
			break
		var n: = int(entry.n)
		var open_l: = L.is_open(n)
		var done_l: = L.done(n)
		var row: = _LessonRow.new()
		row.name = "Lesson_%d" % n
		row.position = Vector2(M, y)
		row.size = Vector2(COL_W - 2.0 * M, row_h)
		row.accent = V10DS.JADE_500 if done_l else (V10DS.GOLD_500 if n == _lesson_n and open_l else Color(0, 0, 0, 0))
		var t_str: = "%s · %s" % [T.LESSON_N % n, String(entry.title)]
		var r_lbl: = _make_lbl(t_str, "ui", 22, V10DS.PAPER_100 if open_l else V10DS.PAPER_500, row.size.x - 40.0, 1)
		r_lbl.position = Vector2(20, 12)
		row.add_child(r_lbl)
		var st_str: = T.LESSON_DONE if done_l else (String(entry.line) if open_l else L.lock_text(n))
		var s_lbl: = _make_lbl(st_str, "ui", 18, V10DS.JADE_300 if done_l else V10DS.PAPER_500, row.size.x - 40.0, 1)
		s_lbl.position = Vector2(20, 48)
		row.add_child(s_lbl)
		if open_l:
			row.enable_tap(func():
				_lesson_n = n
				show_lesson_task(n, 0))
		page.add_child(row)
		y += row_h + 8.0


func show_lesson_task(n: int, i: int) -> void:
	view = "lesson_task"
	_lesson_n = clampi(n, 1, L.LESSONS.size())
	_lesson_i = clampi(i, 0, L.TASKS - 1)
	_picked = []
	var les: = L.lesson(_lesson_n)
	var tsk: = L.task(_lesson_n, _lesson_i)
	header.set_title(T.LESSON_N % _lesson_n)
	_clear_page()
	var y: = _y0()

	var box: = _Plate.new()
	box.name = "LessonHandPlate"
	box.position = Vector2(M, y)
	box.size = Vector2(COL_W - 2.0 * M, 186.0)
	page.add_child(box)

	var head_l: = _make_lbl("%s · %d из %d" % [String(les.title), _lesson_i + 1, L.TASKS], "ui", 22, V10DS.GOLD_300, box.size.x - 32.0, 1)
	head_l.position = Vector2(16, 10)
	box.add_child(head_l)
	var rule_l: = _make_lbl(String(les.line), "ui", 18, V10DS.PAPER_300, box.size.x - 32.0, 2)
	rule_l.position = Vector2(16, 42)
	box.add_child(rule_l)

	var open_map: = {}
	var sl: Array = tsk.get("sleeve", [])
	for idx in 13:
		if not (idx in sl):
			open_map[idx] = true
	hand_view = _HandView.new()
	hand_view.name = "LessonHandRow"
	hand_view.position = Vector2(16, 102)
	hand_view.size = Vector2(box.size.x - 32.0, 68.0)
	hand_view.configure(tsk.get("hand", []), open_map, sl, [], [], false, true)
	box.add_child(hand_view)
	y += box.size.y + 10.0

	var notin: Array = tsk.get("notin", [])
	if not notin.is_empty():
		strip_view = _StripView.new()
		strip_view.position = Vector2(M, y)
		strip_view.size = Vector2(COL_W - 2.0 * M, 34.0)
		strip_view.configure(notin, T.STRIP)
		page.add_child(strip_view)
		y += 40.0

	meta_lbl = _make_lbl(T.LESSON_ASK, "ui", 18, V10DS.PAPER_300, COL_W - 2.0 * M, 2)
	meta_lbl.name = "LessonFeedback"
	meta_lbl.position = Vector2(M, y)
	page.add_child(meta_lbl)
	y += 48.0

	var rows34: = []
	for k in 34:
		rows34.append({"kind": k, "name": GEN.name(k), "dim": false, "notin": k in notin, "mine": 0, "cand": false})
	shutter_grid = _TileShutterGrid.new()
	shutter_grid.name = "LessonPicker"
	shutter_grid.position = Vector2(M, y)
	shutter_grid.size = Vector2(COL_W - 2.0 * M, 348.0)
	shutter_grid.setup_shutter(rows34, _picked, true)
	shutter_grid.tile_tapped.connect(func(k: int, _dim: bool):
		toggle_lesson_pick(k))
	page.add_child(shutter_grid)

	_place_actions(T.BTN_LESSON_CHECK, check_lesson_task, BTN_TO_LIST, show_lessons)
	btn_primary.name = "BtnLessonCheck"
	if btn_second:
		btn_second.name = "BtnLessonBack"


func toggle_lesson_pick(kind: int) -> void:
	if kind in _picked:
		_picked.erase(kind)
	else:
		_picked.append(kind)
		_picked.sort()
	if shutter_grid and shutter_grid.has_method("set_picked"):
		shutter_grid.call("set_picked", _picked)


func check_lesson_task() -> Dictionary:
	var res: = L.check(_lesson_n, _lesson_i, _picked)
	if bool(res.get("ok", false)):
		L.mark(_lesson_n, _lesson_i, true)
		_save_if_needed()
		if meta_lbl:
			meta_lbl.text = String(res.get("explanation", T.LESSON_RIGHT))
			meta_lbl.label_settings = V10Type.settings("ui", 18, V10DS.JADE_300)
		if btn_primary:
			btn_primary.text = T.BTN_LESSON_NEXT
			for c in btn_primary.pressed.get_connections():
				btn_primary.pressed.disconnect(c.callable)
			btn_primary.pressed.connect(_next_lesson_step)
	else:
		if meta_lbl:
			meta_lbl.text = String(res.get("text", ""))
			meta_lbl.label_settings = V10Type.settings("ui", 18, V10DS.ROSE_300)
	return res


func _next_lesson_step() -> void:
	if _lesson_i + 1 < L.TASKS:
		show_lesson_task(_lesson_n, _lesson_i + 1)
	else:
		show_lessons()


# ================================================================== help, nav, result

func open_help() -> V10BottomSheet:
	var sh: = V10BottomSheet.open(_sheet_host(), T.MODE)
	sh.name = "PalmHelpSheet"
	var y: = 0.0
	for r in T.RULES:
		var rl: = _make_lbl(String(r), "ui", 22, V10DS.PAPER_100, 656.0, 2)
		sh.add_body(rl, y)
		y += 68.0
	var fair_l: = _make_lbl(T.FAIR, "ui", 18, V10DS.PAPER_500, 656.0, 1)
	sh.add_body(fair_l, y + 4.0)
	y += 48.0
	var ok_b: = _make_btn("play", BTN_GOT_IT, Vector2(560, 104), sh.close, "primary")
	ok_b.name = "BtnHelpOk"
	sh.add_body(ok_b, y, true)
	sh.finish(y + 112.0)
	active_sheet = sh
	return sh


func _result_payload() -> Dictionary:
	var res: Dictionary = session.result
	var right: = bool(res.get("correct", false))
	var mult_n: = int(res.get("mult", session.mult()))
	var secs: = maxf(0.1, float(U.tick_ms() - _t0_ms) / 1000.0)
	return {
		"mode": "hand",
		"win": right,
		"score": int(res.get("gems", 0)),
		"stars": clampi(mult_n, 1, 3) if right else 0,
		"time_s": secs,
		"pairs": session.taken.size(),
		"hero": session.hero,
		"seed": int(session.entry.get("deal_seed", 0)),
		"level": session.day_idx,
		"rewards": (res.get("rewards", {}) as Dictionary).duplicate(true),
	}


func _finish_and_leave() -> void:
	if not _emitted:
		_emitted = true
		finished.emit(_result_payload())
	_navigate_back()


func _on_back() -> void:
	if view == "lesson_task":
		show_lessons()
		return
	if view == "lessons" and String(args.get("view", "daily")) != "lessons":
		show_daily()
		return
	if not _emitted and not session.result.is_empty():
		_emitted = true
		finished.emit(_result_payload())
	_navigate_back()


func _navigate_back() -> void:
	if main and main.has_method("back"):
		main.call("back")
	elif main and main.has_method("go"):
		main.call("go", String(args.get("back", "home")))


func _save_if_needed() -> void:
	if session and session.persist and U.g_ok() and G.has_method("save"):
		G.save()


static func _clip_set(txt: String) -> void:
	test_clip = txt
	if not use_test_clip and DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(txt)


static func set_test_clip_mode(on: bool) -> void:
	use_test_clip = on
	test_clip = ""


static func last_test_clip() -> String:
	return test_clip

# ================================================================== painted inner controls (V10DS only)

class _LocalSheetHost:
	extends Control
	var overlay: Control
	var safe_bottom: = 0.0

	func _init() -> void:
		overlay = Control.new()
		overlay.name = "LocalOverlay"
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(overlay)


class _PalmBg:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var a: = V10DS.NIGHT_800
		var b: = V10DS.NIGHT_900
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([a, a, b, b])
		)
		for i in 7:
			draw_circle(Vector2(size.x * 0.5, size.y * 0.52), 180.0 + float(i) * 56.0, Color(V10DS.FELT_HI, 0.045))


class _Plate:
	extends Control
	var accent: = Color(0, 0, 0, 0)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		V10Plate.draw_surface(self, Rect2(Vector2.ZERO, size), false, false, false, false, false, -1.0, Color(V10DS.NIGHT_800, V10DS.ON_ART_A))
		if accent.a > 0.0:
			draw_rect(Rect2(0, 14, 4, size.y - 28), accent)


class _HandView:
	extends Control
	var cards: Array = []
	var open_pos: Dictionary = {}
	var sleeve_pos: Array = []
	var wait_kinds: Array = []
	var school_pos: Array = []
	var reveal_all: = false
	var show_sleeve_mark: = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func configure(h: Array, op: Dictionary, sl: Array, waits: Array, sf: Array, rev_all: bool, sl_mark: bool) -> void:
		cards = h.duplicate()
		open_pos = op.duplicate()
		sleeve_pos = sl.duplicate()
		wait_kinds = waits.duplicate()
		school_pos = sf.duplicate()
		reveal_all = rev_all
		show_sleeve_mark = sl_mark
		queue_redraw()

	func _draw() -> void:
		var n: = cards.size()
		if n <= 0:
			return
		var gap: = 3.0
		var cw: = floorf((size.x - gap * float(n - 1)) / float(n))
		var ch: = minf(size.y - 6.0, cw * 1.36)
		var x0: = floorf((size.x - (cw * float(n) + gap * float(n - 1))) * 0.5)
		var y0: = floorf((size.y - ch) * 0.5)
		for i in n:
			var r: = Rect2(x0 + float(i) * (cw + gap), y0, cw, ch)
			var k: = int(cards[i])
			var is_open: = reveal_all or open_pos.has(i)
			var in_sleeve: = i in sleeve_pos
			if is_open:
				draw_rect(r, V10DS.PAPER_100)
				draw_rect(r.grow(-1.5), Color(V10DS.PAPER_300, 0.35), false, 1.0)
				var tx: = V10HandBoard.face_tex(k)
				if tx:
					draw_texture_rect(tx, r.grow(-3.0), false)
				if reveal_all and in_sleeve:
					draw_rect(Rect2(r.position.x + 3.0, r.position.y, r.size.x - 6.0, 3.0), V10DS.GOLD_500)
				if reveal_all and (k in wait_kinds):
					draw_rect(Rect2(r.position.x + 2.0, r.end.y - 3.0, r.size.x - 4.0, 3.0), V10DS.JADE_500)
			else:
				draw_rect(r, V10DS.NIGHT_700)
				draw_rect(r.grow(-3.0), Color(V10DS.GOLD_500, 0.38 if (show_sleeve_mark and in_sleeve) else 0.18), false, 1.0)
				if show_sleeve_mark and in_sleeve:
					draw_circle(r.get_center(), 4.0, V10DS.GOLD_500)
			if not reveal_all and (i in school_pos):
				draw_rect(Rect2(r.position.x + 2.0, r.end.y + 2.0, r.size.x - 4.0, 3.0), V10DS.GOLD_500)


class _StripView:
	extends Control
	var kinds: Array = []
	var cap_lbl: Label = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap_lbl = V10Type.label("", "ui", 18, V10DS.PAPER_500)
		add_child(cap_lbl)

	func configure(ks: Array, fallback_txt: String) -> void:
		kinds = ks.duplicate()
		if kinds.is_empty():
			cap_lbl.text = fallback_txt
			cap_lbl.position = Vector2.ZERO
			cap_lbl.size = Vector2(size.x, 30.0)
		else:
			cap_lbl.text = V10HandText.STRIP + ":"
			cap_lbl.position = Vector2.ZERO
			cap_lbl.size = Vector2(116.0, 30.0)
		queue_redraw()

	func _draw() -> void:
		if kinds.is_empty():
			return
		var x: = 104.0
		var tw: = 24.0
		var th: = 32.0
		for k in kinds:
			if x + tw > size.x:
				break
			var r: = Rect2(x, 1.0, tw, th)
			draw_rect(r, Color(V10DS.PAPER_100, 0.88))
			var tx: = V10HandBoard.face_tex(int(k))
			if tx:
				draw_texture_rect(tx, r.grow(-1.5), false)
			x += tw + 4.0


class _TrayBar:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func slot_rects() -> Array:
		var n: = V10HandBoard.SLOTS_HAND
		var sw: = 82.0
		var sh: = 76.0
		var gap: = 10.0
		var tot: = float(n) * sw + float(n - 1) * gap
		var x0: = floorf((size.x - tot) * 0.5)
		var y0: = floorf((size.y - sh) * 0.5)
		var out: = []
		for i in n:
			out.append(Rect2(x0 + float(i) * (sw + gap), y0, sw, sh))
		return out

	func _draw() -> void:
		V10Plate.draw_surface(self, Rect2(Vector2.ZERO, size), false, false, false, false, false, -1.0, Color(V10DS.NIGHT_800, 0.9))
		for r in slot_rects():
			var rr: Rect2 = r
			draw_rect(rr, Color(V10DS.NIGHT_900, 0.72))
			draw_rect(rr.grow(-1.0), V10DS.hair(), false, 1.0)


class _SingleCardView:
	extends Control
	var kind: = 0

	func _init(k: int = 0) -> void:
		kind = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		draw_rect(r, V10DS.PAPER_100)
		draw_rect(r.grow(-3.0), Color(V10DS.GOLD_500, 0.55), false, 2.0)
		var tx: = V10HandBoard.face_tex(kind)
		if tx:
			draw_texture_rect(tx, r.grow(-8.0), false)


class _TileShutterGrid:
	extends Control
	signal tile_tapped(kind: int, dimmed: bool)

	var rows_data: Array = []
	var picked: Array = []
	var multi: = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_meta("ux_tap", true)

	func setup_shutter(rows: Array, sel: Array, is_multi: bool) -> void:
		rows_data = rows.duplicate(true)
		picked = sel.duplicate()
		multi = is_multi
		queue_redraw()

	func set_picked(sel: Array) -> void:
		picked = sel.duplicate()
		queue_redraw()

	func _cell_rect(kind: int) -> Rect2:
		var row_i: = 3 if kind >= 27 else (kind / 9)
		var col_i: = (kind - 27) if kind >= 27 else (kind % 9)
		var cols_in_row: = 7 if row_i == 3 else 9
		var gap_x: = 6.0
		var gap_y: = 8.0
		var cw: = floorf((size.x - gap_x * 8.0) / 9.0)
		var ch: = floorf((size.y - gap_y * 3.0) / 4.0)
		var row_w: = cw * float(cols_in_row) + gap_x * float(cols_in_row - 1)
		var x0: = floorf((size.x - row_w) * 0.5)
		return Rect2(x0 + float(col_i) * (cw + gap_x), float(row_i) * (ch + gap_y), cw, ch)

	func kind_at(pos: Vector2) -> int:
		for k in 34:
			if _cell_rect(k).grow(2.0).has_point(pos):
				return k
		return -1

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			var k: = kind_at(e.position)
			if k >= 0 and k < rows_data.size():
				var d: Dictionary = rows_data[k]
				var is_dim: = bool(d.get("dim", false))
				V9Feel.press(self, "deny" if is_dim else "tick", "deny" if is_dim else "tap")
				tile_tapped.emit(k, is_dim)
				accept_event()

	func _draw() -> void:
		for k in mini(34, rows_data.size()):
			var d: Dictionary = rows_data[k]
			var r: = _cell_rect(k)
			var is_dim: = bool(d.get("dim", false))
			var is_sel: = k in picked
			var is_cand: = bool(d.get("cand", false))
			var is_notin: = bool(d.get("notin", false))
			var alpha: = 0.28 if is_dim else 1.0
			draw_rect(r, Color(V10DS.PAPER_100, alpha * (0.98 if is_sel else 0.90)))
			if is_sel:
				draw_rect(r.grow(1.5), V10DS.JADE_500, false, 3.0)
			elif is_cand and not is_dim:
				draw_rect(Rect2(r.position.x + 4.0, r.end.y - 4.0, r.size.x - 8.0, 3.0), V10DS.GOLD_500)
			var tx: = V10HandBoard.face_tex(k)
			if tx:
				draw_texture_rect(tx, r.grow(-4.0), false, Color(1, 1, 1, alpha))
			if is_notin and not is_dim:
				draw_circle(Vector2(r.end.x - 7.0, r.position.y + 7.0), 4.0, V10DS.ROSE_500)


class _LessonRow:
	extends Control
	var accent: = Color(0, 0, 0, 0)
	var _cb: = Callable()
	var _down: = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func enable_tap(cb: Callable) -> void:
		_cb = cb
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_meta("ux_tap", true)

	func _gui_input(e: InputEvent) -> void:
		if not _cb.is_valid():
			return
		if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
			if e.pressed:
				_down = true
				queue_redraw()
			elif _down:
				_down = false
				queue_redraw()
				if Rect2(Vector2.ZERO, size).has_point(e.position):
					V9Feel.press(self, "tick", "tap")
					_cb.call()
					accept_event()

	func _draw() -> void:
		var fill: = Color(V10DS.NIGHT_700, 0.92) if _down else Color(V10DS.NIGHT_800, V10DS.ON_ART_A)
		V10Plate.draw_surface(self, Rect2(Vector2.ZERO, size), false, false, false, false, false, -1.0, fill)
		if accent.a > 0.0:
			draw_rect(Rect2(0, 14, 4, size.y - 28), accent)