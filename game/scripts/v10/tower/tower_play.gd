extends "res://scripts/screens/play.gd"

# tower_play — the match of Пагода Луны and Странствие (spec 0.10 R1–R3). A child of the 0.9 play screen, like
# v06/modes/mode_play.gd, so play.gd stays untouched: every point of the README §3 table is an override here and
# goes through the adapter V10TowerRules (tower_rules.gd).
#
#   main.go("tower_play", {"mode": "pagoda", "run": run})      a floor of the Pagoda (run = V10Pagoda.current_run())
#   main.go("tower_play", {"mode": "journey", "run": run})     a board of the week (run = V10Journey.current_run())
#   main.go("tower_play", {"mode": "practice", "run": run})    practice: the run lives in args only, never saved
#
# What the match does (README §3):
#   _v6_setup     run + V10TowerRules.for_run(run) + cfg = tr.hook_cfg() (seed locked)
#   _slot_count   tr.slot_count(V7Passives.slots(partner, 4))   (Journey: the run's own number, no outfit passives)
#   _make_board   seed(cfg.seed) before the deal, a V6SpecialBoard WITHOUT specials (no gift boxes, no «Счастливая
#                 серия» — they pay crystals and random helps), the mode line V10TowerHud above the table
#   _apply_perk   helps from the run (V10Pagoda.helps / V10Journey.helps); no Азарт (it only doubles crystals)
#   deal done     tr.hook_start(self): helps, combo, ult, clock, fog, shroud, lasso, warm-up, first hint
#   _on_match     crystals never tick (restored after the 0.9 code ran), then tr.hook_pair(self): the boss tricks
#                 come back; each is shown with V10BossCutin first, then tr.apply_op (input and clock frozen)
#   _refresh      tr.on_tray_changed(self) (a veil leaves with its tile)
#   _on_fail      tr.hook_overflow(self): Pagoda — a lantern goes out (exhale + «lantern_out»), the tray comes back,
#                 the floor goes on; Journey — a heart breaks («heart_break») and the same table starts over (same
#                 seed, same deal); the shield (forgiven) — the tray comes back with a soft line. Saved at once.
#   _process      tr.tick(dt) -> on_timeout (the hourglass curse), the clock in the mode line
#   helps         tr.help_ok(kind); a curse greys the help with tr.help_off_text(kind); NO paid help: an empty help
#                 is a deny + «Здесь только честная игра», _v8_pay never asks for crystals here
#   _on_clear     tr.hook_clear({secs, max_combo, pairs}) -> grant -> save -> the window of part C
#                 (V10TowerSheets.floor_clear / board_clear; a plain fallback sheet while C is missing)
#   leaving       the house button / Android back: Pagoda — the run is kept, the floor restarts on the same seed;
#                 Journey — the attempt is already spent, the run goes on from the same board; practice — nothing kept
#
# Rank points and tasks (like climb in mode_play): every cleared floor / board is a won game,
# V8PlayRules.award("other", rp, true) + G.task_add("levels") + G.add_aff(partner, 4); a run lost on its last
# lantern / heart counts one lost game. Pagoda rp = V8PlayRules.climb_rp(floor); Journey rp = 6 + 2 × board index.
# Practice gives nothing (no rank, no tasks, no rewards, no save).

signal tower_event(kind: String, data: Dictionary)

const TR: = preload("res://scripts/v10/tower/tower_rules.gd")
const P: = preload("res://scripts/v10/tower/pagoda.gd")
const J: = preload("res://scripts/v10/tower/journey.gd")
const M: = preload("res://scripts/v10/tower/mods.gd")
const UIT: = preload("res://scripts/v10/tower/ui/tower_ui.gd")
const THUD: = preload("res://scripts/v10/tower/ui/tower_hud.gd")
const CUT: = preload("res://scripts/v10/tower/ui/boss_cutin.gd")
const SHEETS_PATH: = "res://scripts/v10/tower/ui/tower_sheets.gd"
const TOWER_MODES: = ["pagoda", "journey", "practice"]
const FAIR_TEXT: = "Здесь только честная игра"
const NORMAL_TEXT: = "Честный зачёт: наряды не дают силы"
const STRIP_GAP: = 8.0

var tmode: = ""
var run: Dictionary = {}
var tr = null
var thud = null          # V10TowerHud (untyped: its API is called directly)
var started: = false
var frozen: = false
var done: = false
var failing: = false
var deal_sig: = ""
var pay_calls: = 0
var events: Array = []
var last_res: Dictionary = {}
var last_award: Dictionary = {}
var sheet: Control = null
var sheet_cb: = Callable()
var _sheet_closed: = false
var _trick_q: Array = []
var _trick_running: = false
var _tower_caps: = {}


func is_tower() -> bool:
	return tmode != ""


func _emit(kind: String, data: = {}) -> void:
	events.append([kind, data])
	tower_event.emit(kind, data)


# ------------------------------------------------------------------ setup

func _v6_setup(args: Dictionary) -> bool:
	var m: = String(args.get("mode", ""))
	if not m in TOWER_MODES:
		return super._v6_setup(args)
	tmode = m
	mode = m
	run = args.get("run", {})
	match m:
		"pagoda":
			# the saved run is the one that must change (lanterns, floor): prefer it when it is the same climb
			var stored: Dictionary = P.current_run()
			if run.is_empty():
				run = stored
			elif not stored.is_empty() and not is_same(stored, run) and int(stored.get("seed", -1)) == int(run.get("seed", -2)):
				run = stored
			if run.is_empty():
				run = P.new_run(partner, {})
		"journey":
			var sj: Dictionary = J.current_run()
			if run.is_empty():
				run = sj
			elif not sj.is_empty() and not is_same(sj, run) and int(sj.get("week", -1)) == int(run.get("week", -2)) \
					and int(sj.get("attempt", -1)) == int(run.get("attempt", -2)):
				run = sj
			if run.is_empty():
				# nothing to continue (the week rolled over): a practice table, never a free attempt
				tmode = "practice"
				mode = "practice"
				run = J.start(partner, true)
		"practice":
			if run.is_empty():
				run = J.start(partner, true)
	partner = String(run.get("partner", partner))
	tr = TR.for_run(run)
	cfg = tr.hook_cfg()
	# the 0.9 goal plate shows cfg.name: the place, never the floor / board again (that is the mode line's job)
	if tmode == "pagoda":
		cfg.name = "Пагода Луны"
	elif not cfg.has("boss"):
		cfg.name = "Странствие"
	return true


func build(m, args: Dictionary) -> void:
	super.build(m, args)
	if not is_tower():
		return
	UIT.music("pagoda" if tmode == "pagoda" else "journey")
	_emit("build", {"mode": tmode})


func _slot_count() -> int:
	if not is_tower() or tr == null:
		return super._slot_count()
	return tr.slot_count(V7Passives.slots(partner, 4))


func _build_hud() -> void:
	super._build_hud()
	if not is_tower():
		return
	# no currencies in a match (UX §3.7): the crystal counter of the 0.9 HUD goes
	if gems_lbl and gems_lbl.get_parent() is Control:
		(gems_lbl.get_parent() as Control).visible = false
	# the house button: a tower match is left through _ask_leave (the run is kept), never main.leave_match
	for c in get_children():
		if c is JButton and (c as JButton).position.is_equal_approx(Vector2(12, 22)):
			for con in (c as JButton).pressed.get_connections():
				(c as JButton).pressed.disconnect(con.callable)
			(c as JButton).pressed.connect(_ask_leave)
			break
	# Странствие: Приём at base strength (cfg.normalized) — the ranked ult: start 0, base need, no outfit modifier
	if bool(cfg.get("normalized", false)) and ult:
		ult.ranked = true
		ult.core = V9Ults.core(ult.hero, true)
		ult.mod = ""
		SKILL_NEED = ult.need()
		skill_charge = ult.start_charge()
		if stage:
			stage.set_ult_badge("", V10DS.PAPER_100)
	if tr and not tr.help_ok("ult"):
		skill_charge = 0
		if stage:
			stage.set_ult_badge("", V10DS.PAPER_100)
	if stage:
		stage.pressed.connect(_on_stage_tap)


func _make_board() -> void:
	if not is_tower():
		super._make_board()
		return
	if thud == null:
		thud = THUD.new()
		thud.name = "TowerHud"
		thud.z_index = 5
		add_child(thud)
		thud.place(Rect2(board_rect.position.x, board_rect.position.y, board_rect.size.x, THUD.PLATE_H))
		thud.configure(tmode, run)
		var top: = board_rect.position.y + THUD.PLATE_H + STRIP_GAP
		board_rect = Rect2(board_rect.position.x, top, board_rect.size.x, board_rect.end.y - top)
	if board:
		board.queue_free()
	# a special board without specials: the tower's own rules are the only twists (no gift box, no streak gems)
	board = V6SpecialBoard.new()
	board.look = G.skin_look()
	board.slots = _slot_count()
	add_child(board)
	if fx_layer:
		move_child(board, fx_layer.get_index())
	# the deal comes from the seed of the floor / board: a retry gives the same table (README §3, like the études)
	seed(int(cfg.seed))
	board.setup(cfg)
	randomize()
	deal_sig = deal_signature(board)
	gold_total = board.tiles.filter(func(t): return t.gold).size() / 2
	board.fit_into(board_rect)
	board.slot_pos.clear()
	for r in slot_rects:
		board.slot_pos.append((r as Rect2).get_center())
	board.slot_size = (slot_rects[0] as Rect2).size.x * 0.92
	board.matched.connect(_on_match)
	board.denied.connect(_on_deny)
	board.cleared.connect(_on_clear)
	board.failed.connect(_on_fail)
	board.tray_changed.connect(_refresh)


static func deal_signature(b: TrayBoard) -> String:
	var parts: = PackedStringArray()
	for t in b.tiles:
		parts.append("%d:%d:%d:%d:%d:%d:%d" % [t.gx, t.gy, t.gz, t.face, t.step, int(t.gold), t.ice])
	return ",".join(parts)


func _apply_perk() -> void:
	super._apply_perk()
	if not is_tower():
		return
	# the helps of this floor / board come from the run (V10Pagoda.helps / V10Journey.helps); hook_start sets the
	# same numbers again once the table is dealt
	var h: Dictionary = P.helps(run) if tmode == "pagoda" else J.helps(run)
	hint_n = int(h.hint)
	undo_n = int(h.undo)
	shuffle_n = int(h.shuffle)
	# crystals do not tick in a tower match: no Азарт (it only doubles crystals), no gain, no first-pairs bonus
	fever_pending = true
	gem_bonus = -1.0
	first_pairs_bonus = 0
	free_rescue_left = 0


func _intro() -> void:
	if not is_tower():
		await super._intro()
		return
	_watch_deal()
	await super._intro()


# the adapter's start ops (warm-up pairs, lasso, fog, peek, first hint, ult charge) and the clock start when the
# deal has landed (or a tap skipped it): before that the tiles are still in flight
func _watch_deal() -> void:
	while is_inside_tree() and not done:
		if board and board.visible and board.input_on:
			break
		await get_tree().process_frame
	if not is_inside_tree() or done:
		return
	_on_dealt()


func _on_dealt() -> void:
	tr.hook_start(self)
	started = true
	if not tr.help_ok("ult"):
		skill_charge = 0
		skill_ready = false
	if tmode != "pagoda":
		_band_plate(NORMAL_TEXT, 2.4)
	elif int(run.get("floor", 1)) % 10 == 0 and not (run.get("forced", {}) as Dictionary).is_empty() and thud:
		thud.flash_heat()
	_refresh()
	_emit("start", {"helps": {"hint": hint_n, "undo": undo_n, "shuffle": shuffle_n}, "clock": tr.clock_full,
		"slots": board.slots, "tiles": board.tiles.size()})


# ------------------------------------------------------------------ the running table

func _popup_open() -> bool:
	if main == null or main.overlay == null:
		return false
	for c in main.overlay.get_children():
		if c.has_meta("popup") and not c.has_meta("closing") and c is CanvasItem and (c as CanvasItem).visible:
			return true
	return false


func _process(dt: float) -> void:
	super._process(dt)
	if not is_tower() or tr == null:
		return
	# the hourglass runs only while the table is playable: frozen under a cut-in, a window, the ult, a fail beat
	if started and not done and not frozen and not failing and board and board.input_on and not _v8_modal \
			and not (ult and ult.busy) and not _popup_open():
		if tr.tick(dt) == "timeout":
			_on_timeout()
	if thud and float(tr.clock_full) > 0.0:
		thud.call("set_clock", tr.clock_text(), float(tr.clock) <= 10.0)
	_fix_stage_text()


func _on_match(mid: Vector2, combo: int, gold: bool, shard: String) -> void:
	if not is_tower():
		super._on_match(mid, combo, gold, shard)
		return
	var g0: = int(G.S.gems)
	var gained0: = gained
	var before: = {}
	if fx_layer:
		for c in fx_layer.get_children():
			before[c] = true
	super._on_match(mid, combo, gold, shard)
	# crystals never tick in a tower match (pairs, gold, sets, combo milestones): the window's rewards are the
	# only income. The «+N» floats of the 0.9 code go with them.
	G.S.gems = g0
	gained = gained0
	if fx_layer:
		for c in fx_layer.get_children():
			if not before.has(c) and c is Label and String((c as Label).text).begins_with("+"):
				c.queue_free()
	_fix_combo_pill()
	if tr and not tr.help_ok("ult"):
		skill_charge = 0
		skill_ready = false
	if done or tr == null:
		return
	var tricks: Array = tr.hook_pair(self)
	for op in tricks:
		_trick_q.append(op)
	if not _trick_q.is_empty() and not _trick_running:
		_run_tricks()


# the 0.9 combo pill speaks of crystals (×N, milestone «+5 кристаллов»): here it only keeps the beat
func _fix_combo_pill() -> void:
	if v7combo == null or not is_instance_valid(v7combo):
		return
	var sub = v7combo.get("pill_sub")
	if sub is Label and "кристалл" in (sub as Label).text:
		(sub as Label).text = "держи темп"


# the boss of the week plays her trick: the cut-in first (input and clock frozen), then the op on the table
func _run_tricks() -> void:
	_trick_running = true
	while not _trick_q.is_empty() and is_inside_tree() and not done:
		while ult and ult.busy and is_inside_tree():
			await get_tree().process_frame
		if not is_inside_tree() or done:
			break
		var op: Dictionary = _trick_q.pop_front()
		frozen = true
		board.input_on = false
		var boss: = String(cfg.get("boss", J.boss(int(run.get("week", 0)))))
		var trick: Dictionary = cfg.get("boss_trick", J.BOSS.get(boss, J.BOSS.mc))
		var t0: = now()
		_emit("trick_cutin", {"boss": boss, "name": String(trick.get("name", ""))})
		await CUT.play(self, boss, trick)
		if not is_inside_tree():
			return
		# the combo keeps its window across the clip (the clock was frozen too)
		board.last_match += now() - t0
		if done:
			break
		tr.apply_op(self, op)
		_emit("trick_op", op)
		var line: = UIT.ui_text(String(trick.get("line", "")))
		if line != "":
			_band_plate(line, 1.6)
		if not failing:
			board.input_on = board.tray.size() < board.slots and board.board_count() > 0
		frozen = false
	frozen = false
	_trick_running = false


func _refresh() -> void:
	super._refresh()
	if not is_tower() or tr == null:
		return
	tr.on_tray_changed(self)
	if not tr.help_ok("ult") and stage:
		stage.set_charge(0, SKILL_NEED)
	_fix_stage_text()
	_settle_veils()


# a veil (fog, smoke, the boss's «вуаль») belongs to its tile's place in the stack: V10TowerRules._veil gives it
# z_index 3, which draws a veiled lower tile over the free tiles above it (a lavender blob over the pyramid).
# Kept at z 0 here it is drawn right after its own tile and under every tile that covers it.
func _settle_veils() -> void:
	if tr == null:
		return
	for v in (tr.veils as Dictionary).values():
		if is_instance_valid(v) and (v as CanvasItem).z_index != 0:
			(v as CanvasItem).z_index = 0


# the 0.9 portrait meter says «ульта N/M» / «УЛЬТА!» (V6HeroStage.set_charge): in the towers it is the Приём
func _fix_stage_text() -> void:
	if stage == null:
		return
	var gl = stage.get("gauge_lbl")
	if gl is Label and is_instance_valid(gl):
		var t0: String = (gl as Label).text
		var t1: = UIT.ui_text(t0).replace("УЛЬТА", "ПРИЁМ")
		if tr and not tr.help_ok("ult"):
			t1 = "без приёма"
		if t1 != t0:
			(gl as Label).text = t1


func _check_riichi() -> void:
	# no «Ставка ×2» in the towers (like climb in mode_play)
	if is_tower():
		return
	super._check_riichi()


func _skill_ready() -> void:
	if not is_tower():
		super._skill_ready()
		return
	if tr and not tr.help_ok("ult"):
		skill_charge = 0
		skill_ready = false
		if stage:
			stage.set_charge(0, SKILL_NEED)
		return
	skill_ready = true
	skill_charge = SKILL_NEED
	stage.set_charge(SKILL_NEED, SKILL_NEED)
	var nm: = ult.ult_name() if ult else String(G.SKILLS[partner].name)
	_bubble("Приём «%s» готов! Коснись меня." % UIT.ui_text(nm))
	Sfx.play("reveal_sr", 1.3, -4)
	V9Feel.haptic("match")


# the intro card of play.gd heads its text with the heroine's 0.9 perk («Перк Маджонг-тян: +1 бесплатная
# подсказка»): in the towers the helps come from the run only, so the card is headed with her name alone
func _tip(text: String) -> void:
	if not is_tower():
		super._tip(text)
		return
	super._tip(UIT.ui_text(text))
	for tc in get_tree().get_nodes_in_group("v6_tip"):
		if not is_ancestor_of(tc):
			continue
		for c in tc.get_children():
			if c is Label and (c as Label).text.begins_with("Перк"):
				(c as Label).text = String(G.HEROES[partner].name)


func _on_stage_tap() -> void:
	if is_tower() and tr and not tr.help_ok("ult"):
		main.toast(_off_text("ult"), "lock")


# ------------------------------------------------------------------ helps: by the run's rules, never paid

func _help_n(kind: String) -> int:
	match kind:
		"hint":
			return hint_n
		"undo":
			return undo_n
		"shuffle":
			return shuffle_n
	return 1


func _off_text(kind: String) -> String:
	return UIT.ui_text(String(tr.help_off_text(kind))) if tr else ""


func _help_ok(kind: String) -> bool:
	if is_tower() and tr:
		if not tr.help_ok(kind) or _help_n(kind) <= 0:
			return false
	return super._help_ok(kind)


# true when the tap is answered here: a curse turned the help off, or the help ran out (no paid help: deny + why)
func _tower_help_denied(kind: String, btn: Control) -> bool:
	if not is_tower() or tr == null:
		return false
	if not tr.help_ok(kind):
		V9Feel.deny(btn)
		main.toast(_off_text(kind), "lock")
		_emit("help_denied", {"kind": kind, "why": "curse"})
		return true
	if _help_n(kind) <= 0:
		V9Feel.deny(btn)
		main.toast(FAIR_TEXT, kind)
		_emit("help_denied", {"kind": kind, "why": "empty"})
		return true
	return false


func _hint() -> void:
	if _tower_help_denied("hint", btn_hint):
		return
	super._hint()


func _undo() -> void:
	if _tower_help_denied("undo", btn_undo):
		return
	super._undo()


func _shuffle() -> void:
	if _tower_help_denied("shuffle", btn_shuffle):
		return
	super._shuffle()


func _v8_pay(kind: String, title: String, text: String, price: int, on_yes: Callable) -> void:
	if not is_tower():
		super._v8_pay(kind, title, text, price, on_yes)
		return
	# never reached through the helps above; a last guard: nothing is ever sold in a tower match
	pay_calls += 1
	main.toast(FAIR_TEXT, "lock")


func _set_badge(b: JButton, n: int) -> void:
	if not is_tower() or tr == null:
		super._set_badge(b, n)
		return
	var kind: = "hint" if b == btn_hint else ("undo" if b == btn_undo else "shuffle")
	var cap: Label = b.get_node("Cap")
	var tc: Label = _tower_caps.get(kind)
	if tc == null:
		tc = V10Type.label("", "ui", 18, V10DS.PAPER_300)
		tc.name = "TowerCap"
		tc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tc.max_lines_visible = 2
		tc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		tc.position = Vector2(-34, 108)
		tc.size = Vector2(180, 56)
		b.add_child(tc)
		_tower_caps[kind] = tc
	var off: bool = not tr.help_ok(kind)
	var dim: = Color(V10DS.PAPER_500, 0.5)
	if off:
		# a curse turned it off: grey, and the caption says which curse («Проклятие «Без подсказок»»)
		cap.visible = false
		tc.visible = true
		tc.text = _off_text(kind)
		b.box.modulate = dim
		var ic: = b.get_node_or_null("Icon")
		if ic:
			(ic as CanvasItem).modulate = dim
	else:
		cap.visible = true
		tc.visible = false
		cap.text = "%s · %d" % [cap.get_meta("base"), n]
		b.box.modulate = Color.WHITE if n > 0 else dim
		var ic2: = b.get_node_or_null("Icon")
		if ic2:
			(ic2 as CanvasItem).modulate = Color.WHITE if n > 0 else dim


# ------------------------------------------------------------------ overflow, hourglass

func _on_fail() -> void:
	if not is_tower():
		super._on_fail()
		return
	if done or failing:
		return
	failing = true
	while _trick_running and is_inside_tree() and frozen:
		await get_tree().process_frame
	if not is_inside_tree():
		return
	_v6_clear_tips()
	if stage:
		stage.flash_emotion("sad")
	var r: Dictionary = tr.hook_overflow(self)
	_emit("overflow", r)
	await _life_event(r, "overflow")
	failing = false


func _on_timeout() -> void:
	if done or failing:
		return
	failing = true
	var r: Dictionary = tr.on_timeout()
	r["return_n"] = 0
	_emit("timeout", r)
	await _life_event(r, "timeout")
	failing = false


func _life_event(r: Dictionary, why: String) -> void:
	var pag: = tmode == "pagoda"
	if bool(r.get("forgiven", false)):
		# the shield (Дымовая завеса) forgave it: the tray comes back, nothing is lost
		Sfx.play("whoosh", 1.2, -4)
		_band_plate("Переполнение прощено: лоток вернулся", 1.6)
		_save()
		await get_tree().create_timer(0.2).timeout
		if is_inside_tree() and not done:
			board.return_tray(int(r.get("return_n", 3)))
			_refresh()
		return
	var left: = int(r.get("lives", r.get("hearts", 0)))
	if thud:
		thud.call("lose_life", left)
	UIT.sfx("lantern_out" if pag else "heart_break", "deny")
	if tray_box:
		Fx.shake(tray_box, 8, 0.35)
	# README §8: the lantern / heart is gone for good the moment it goes out
	_save()
	_emit("life_lost", {"left": left, "why": why})
	if bool(r.get("run_over", false)):
		done = true
		board.input_on = false
		Sfx.say(partner, "lose")
		if tmode != "practice":
			V8PlayRules.award("other", 0, false)
		await get_tree().create_timer(0.8).timeout
		if not is_inside_tree():
			return
		if pag:
			_pagoda_over()
		else:
			_journey_finish()
		return
	if pag:
		_band_plate("Фонарь погас · осталось %d" % left, 1.4)
		if why == "overflow":
			await get_tree().create_timer(0.25).timeout
			if is_inside_tree() and not done:
				board.return_tray(int(r.get("return_n", 3)))
				_refresh()
		return
	# Journey: the same table from the start (same seed, same deal)
	done = true
	board.input_on = false
	_band_plate("Сердце разбито · этот стол заново", 1.4)
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree():
		_emit("restart", {"board": int(run.get("board", 0))})
		_go("tower_play", {"mode": tmode, "run": run})


func _pagoda_over() -> void:
	var end_res: Dictionary = P.end_run(run)
	_save()
	_emit("end", end_res)
	_go("pagoda", {"result": end_res, "new_cos": (run.get("new_cos", []) as Array).duplicate()})


func _journey_finish() -> void:
	var fin: Dictionary = J.finish(run)
	if tmode != "practice":
		UIT.grant(fin.get("reward", {}), "journey")
		_save()
	# the reward is credited here (practice has none): the Journey hub credits it only when this flag is missing
	fin["granted"] = true
	_emit("finish", fin)
	_go("journey", {"result": fin})


func _save() -> void:
	# practice never writes anything (its run is not in the save; README §8)
	if tmode != "practice":
		UIT.save_now()


func _go(id: String, args: Dictionary) -> void:
	var guard: = 0
	while main.busy and guard < 240 and is_inside_tree():
		guard += 1
		await get_tree().process_frame
	main.go(id, args)


# ------------------------------------------------------------------ the table is cleared

func _on_clear() -> void:
	if not is_tower():
		super._on_clear()
		return
	if done:
		return
	done = true
	board.input_on = false
	_v6_clear_tips()
	get_tree().call_group("v6_chip", "queue_free")
	var secs: = now() - start_t
	var res: Dictionary = tr.hook_clear({"secs": secs, "max_combo": max_combo, "pairs": int(tr.pairs)})
	last_res = res
	if tmode == "pagoda":
		var cos: Array = res.get("cosmetics", [])
		if not cos.is_empty():
			run["new_cos"] = (run.get("new_cos", []) as Array) + cos
		UIT.grant(res.get("reward", {}), "pagoda")
		_award_win(V8PlayRules.climb_rp(int(res.get("floor", 1))))
	elif tmode == "journey":
		_award_win(clampi(6 + 2 * (int(run.get("board", 1)) - 1), 5, 15))
	_save()
	_v8_saved = true
	_emit("clear", res)
	Sfx.play("win", 1.1)
	Sfx.say(partner, "win")
	_v8_end_overlays()
	await get_tree().create_timer(0.35).timeout
	if is_inside_tree():
		_open_sheet(res)


func _award_win(rp: int) -> void:
	if tmode == "practice":
		return
	G.add_aff(partner, 4)
	G.task_add("levels")
	last_award = V8PlayRules.award("other", rp, true)


static func sheets_script() -> Script:
	if not ResourceLoader.exists(SHEETS_PATH):
		return null
	var s: Script = load(SHEETS_PATH)
	if s == null:
		return null
	var names: = {}
	for mth in s.get_script_method_list():
		names[String(mth.get("name", ""))] = true
	return s if names.has("floor_clear") and names.has("board_clear") else null


func _open_sheet(res: Dictionary) -> void:
	var holder: = Control.new()
	holder.name = "TowerSheet"
	holder.size = size
	# above the tiles of the tray (z 200+), under main.overlay
	holder.z_index = 300
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	sheet = holder
	sheet_cb = _on_sheet_done
	var S: = sheets_script()
	var node = null
	if S:
		if tmode == "pagoda":
			node = S.call("floor_clear", holder, run, res, sheet_cb)
		else:
			node = S.call("board_clear", holder, run, res, sheet_cb)
	if node == null:
		_fallback_sheet(holder, res)
	_emit("sheet", {"fallback": S == null})


func _on_sheet_done(d: Dictionary) -> void:
	if _sheet_closed:
		return
	_sheet_closed = true
	var action: = String(d.get("action", "next"))
	# a blessing (and in the Journey a curse) was picked into the run
	_save()
	_emit("sheet_done", d)
	match action:
		"next":
			_go("tower_play", {"mode": tmode, "run": run})
		"finish":
			_journey_finish()
		_:
			_go("pagoda" if tmode == "pagoda" else "journey", {})


# ------------------------------------------------------------------ leaving the match

func handle_back() -> bool:
	if not is_tower():
		return false
	_ask_leave()
	return true


func _ask_leave() -> void:
	if sheet and not _sheet_closed:
		# the window of a cleared floor is up: back = leave to the hub, the run is saved
		_on_sheet_done({"action": "leave"})
		return
	if done:
		return
	var title: = "Выйти в Пагоду?"
	var text: = "Забег сохранён. Этаж начнётся заново."
	if tmode == "journey":
		title = "Выйти в Странствие?"
		text = "Попытка уже засчитана. Забег продолжится с этого стола."
	elif tmode == "practice":
		title = "Закончить тренировку?"
		text = "Тренировка не сохраняется."
	Common.confirm(main, title, text, "", 0, _leave, {"yes_text": "Выйти", "no_text": "Играть"})


func _leave() -> void:
	if done:
		return
	done = true
	if board:
		board.input_on = false
	_save()
	_emit("leave", {})
	_go("pagoda" if tmode == "pagoda" else "journey", {})


# ------------------------------------------------------------------ small views

# a one-line plate in the band between the table and the help buttons (play.v8_band slot, never over a tile)
func _band_plate(text: String, hold: float) -> void:
	var w: = minf(W - 48.0, V10Type.text_w(text, "ui", 22) + 48.0)
	var painter: = func(ci: CanvasItem, sz: Vector2) -> void:
		V10Plate.draw_surface(ci, Rect2(Vector2.ZERO, sz), true, false, false, false, false, -1.0, V10DS.NIGHT_700)
	var p: Control = UIT.glyph(painter, Vector2(w, 48))
	p.name = "TowerBand"
	var l: = V10Type.label("", "ui", 22, V10DS.PAPER_100)
	V10Type.fit(l, text, "title_sm", w - 32.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(16, 0)
	l.size = Vector2(w - 32.0, 48)
	p.add_child(l)
	v8_band(p, hold, true, 2)


# the window of part C is missing: one plain sheet with the same choices (title, rewards, blessings 1 of 3,
# Journey curse 1 of 2, «Выше» / «В Пагоду»). It calls the same logic and the same on_done.
func _fallback_sheet(holder: Control, res: Dictionary) -> Control:
	var pag: = tmode == "pagoda"
	var root: = Control.new()
	root.name = "FallbackSheet"
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(root)
	var dimr: = ColorRect.new()
	dimr.size = size
	dimr.color = Color(V10DS.NIGHT_900, 0.72)
	dimr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dimr)
	var offer: Array = res.get("offer", [])
	var curses: Array = res.get("curse_offer", [])
	var done_run: = bool(res.get("done", false))
	var sh_h: = 24.0 + 60.0 + 40.0 + 16.0
	if not offer.is_empty():
		sh_h += 32.0 + offer.size() * 88.0
	if not curses.is_empty():
		sh_h += 32.0 + (curses.size() + 1) * 88.0
	sh_h += 16.0 + 104.0 + 12.0 + 80.0 + 32.0
	var top: = H - sh_h
	var painter: = func(ci: CanvasItem, sz: Vector2) -> void:
		V10Plate.draw_surface(ci, Rect2(Vector2.ZERO, sz + Vector2(0, 8)), false, false, false, false, false, -1.0, V10DS.NIGHT_700)
	var panel: Control = UIT.glyph(painter, Vector2(W, sh_h))
	panel.position = Vector2(0, top)
	root.add_child(panel)
	var y: = top + 24.0
	var title: = ("Этаж %d пройден" % int(res.get("floor", 1))) if pag else ("Стол %d пройден" % int(res.get("boards", 1)))
	var tl: = V10Type.label(title, "display", 44, V10DS.PAPER_100)
	tl.position = Vector2(24, y)
	tl.size = Vector2(W - 48, 56)
	root.add_child(tl)
	y += 60.0
	var parts: = []
	if pag:
		for tok in UIT.reward_tokens(res.get("reward", {})):
			parts.append("+%d %s" % [int(tok[1]), String(tok[2])])
		if bool(res.get("chest", false)):
			parts.append("сундук Стража")
		if not (res.get("forced", []) as Array).is_empty():
			parts.append("Пагода разгорается")
	else:
		parts.append("стол %d очков" % int(res.get("score", 0)))
		parts.append("всего %d" % int(res.get("total", 0)))
	var rl: = V10Type.label("", "ui", 22, V10DS.GOLD_300)
	V10Type.fit(rl, " · ".join(parts) if not parts.is_empty() else "Без награды", "title_sm", W - 48.0)
	rl.position = Vector2(24, y)
	rl.size = Vector2(W - 48, 32)
	root.add_child(rl)
	y += 56.0
	var picked: = {"bless": "", "curse": ""}
	var bless_plates: = []
	if not offer.is_empty():
		var ov: = V10Type.label("БЛАГОСЛОВЕНИЕ · ОДНО ИЗ ТРЁХ", "overline", 15, V10DS.GOLD_500)
		ov.position = Vector2(24, y)
		ov.size = Vector2(W - 48, 24)
		root.add_child(ov)
		y += 32.0
		for id in offer:
			var card: = M.bless_card(String(id), run)
			var pl: = V10Plate.make("M", 672, UIT.ui_text(String(card.title)), UIT.ui_text("%s · %s" % [String(card.hero_name), String(card.line)]))
			pl.position = Vector2(24, y)
			pl.interactive = true
			pl.set_meta("id", String(id))
			root.add_child(pl)
			bless_plates.append(pl)
			y += 88.0
		for pl2 in bless_plates:
			var me: V10Plate = pl2
			me.pressed.connect(func() -> void:
				if picked.bless != "":
					return
				var bid: = String(me.get_meta("id"))
				var ok: bool = P.pick_blessing(run, bid) if pag else J.pick_blessing(run, bid)
				if ok:
					picked.bless = bid
					UIT.tap(me)
					for o in bless_plates:
						(o as V10Plate).selected = o == me
						(o as V10Plate).disabled = o != me
					_save())
	var curse_plates: = []
	if not curses.is_empty():
		var ov2: = V10Type.label("ПРОКЛЯТИЕ ПО ЖЕЛАНИЮ · ОЧКИ ×1,15", "overline", 15, V10DS.GOLD_500)
		ov2.position = Vector2(24, y)
		ov2.size = Vector2(W - 48, 24)
		root.add_child(ov2)
		y += 32.0
		var ids: Array = curses.duplicate()
		ids.append("")
		for cid in ids:
			var pl3: V10Plate
			if String(cid) == "":
				pl3 = V10Plate.make("M", 672, "Без проклятия", "Счёт без множителя")
				pl3.selected = true
			else:
				var cc: = M.curse_card(String(cid), 1, "journey")
				pl3 = V10Plate.make("M", 672, UIT.ui_text(String(cc.title)), UIT.ui_text(String(cc.line)))
			pl3.position = Vector2(24, y)
			pl3.interactive = true
			pl3.set_meta("id", String(cid))
			root.add_child(pl3)
			curse_plates.append(pl3)
			y += 88.0
		for pc in curse_plates:
			var mc: V10Plate = pc
			mc.pressed.connect(func() -> void:
				if picked.curse != "":
					return
				var cid2: = String(mc.get_meta("id"))
				if cid2 != "" and not J.take_curse(run, cid2):
					return
				if cid2 == "":
					run.curse_offer = []
				picked.curse = cid2 if cid2 != "" else "-"
				UIT.tap(mc)
				for o2 in curse_plates:
					(o2 as V10Plate).selected = o2 == mc
					(o2 as V10Plate).disabled = o2 != mc
				_save())
	y += 16.0
	var main_text: = ""
	if pag:
		main_text = "Выше · этаж %d" % int(run.get("floor", 2))
	elif done_run:
		main_text = "Итог забега"
	else:
		main_text = "Дальше · стол %d" % (int(run.get("board", 1)) + 1)
	var pb: = V10Button.make("play", main_text, Vector2(560, 104))
	pb.position = Vector2((W - 560.0) * 0.5, y)
	UIT.role(pb, "primary")
	root.add_child(pb)
	y += 116.0
	var sb: = V10Button.make("secondary", "В Пагоду" if pag else "В Странствие", Vector2(440, 80))
	sb.position = Vector2((W - 440.0) * 0.5, y)
	UIT.role(sb, "secondary")
	root.add_child(sb)
	pb.pressed.connect(func() -> void:
		UIT.tap(pb, "pop")
		if picked.bless == "" and not offer.is_empty():
			if pag:
				P.skip_blessing(run)
			else:
				run.offer = []
		_on_sheet_done({"action": "finish" if (done_run and not pag) else "next"}))
	sb.pressed.connect(func() -> void:
		UIT.tap(sb, "pop")
		_on_sheet_done({"action": "finish" if (done_run and not pag) else "leave"}))
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.12 if UIT.calm() else 0.24)
	return root
