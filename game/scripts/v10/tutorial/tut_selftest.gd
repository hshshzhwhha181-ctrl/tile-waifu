class_name V10TutSelftest
extends Node
# Full tutorial selftest (README §5).
#   -- --tut_selftest=1          all suites: code/hygiene, lint/lines, state/gates, HUD v2 geometry, «?»/«Как играть»
#                                sheets, orchestrator logic, AND live main.tscn L1 -> Victory -> Чайная -> Столы ->
#                                Героини -> Settings «Как играть» (unless --tut_static=1 is passed)
#   -- --tut_static=1            fast headless static + HUD v2 host geometry + sheets + orchestrator logic
#   -- --tut_shots=<abs_dir>     capture PNGs of coach modes & sheets (under OpenGL)
#   -- --tut_compile=1 | --tut_logic=1 | --tut_l1=1 | --tut_bot=1

const DIR: = "res://scripts/v10/tutorial/"
const BANNED_09: = [
	"левая колонка", "сесть за стол", "гардероб", "ульта", "умение", "лихорадка",
	"полнолуние", "ва-банк", "богиня", "поручения", "визиты", "ивент", "перк",
]
const REQUIRED_IDS: = [
	"nav.teahouse", "nav.heroines", "nav.tables", "nav.wishes", "nav.shop",
	"home.hero", "home.play", "home.phone", "home.partner",
	"lantern.today", "lantern.salon", "lantern.streak",
	"tables.play", "tables.tourney", "tables.mode.triples", "tables.mode.riichi",
	"tables.mode.koikoi", "tables.mode.duels", "tables.mode.journey", "tables.mode.pagoda",
	"match.tray", "match.hero", "match.board", "match.hint", "match.pause",
	"match.status", "match.stake", "match.combo", "match.tile_a", "match.tile_b",
	"win.stars", "win.rewards", "win.next", "win.home",
]

var checks: = 0
var fails: = 0
var mods: = {}
var _mod: = "init"
var _shot_dir: = ""


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not mods.has(_mod):
		mods[_mod] = [0, 0]
	mods[_mod][1] += 1
	if cond:
		mods[_mod][0] += 1
	else:
		fails += 1
		printerr("TUT_FAIL [%s] %s" % [_mod, what])


func _apply_resolution_arg() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tut_res="):
			var parts: PackedStringArray = a.substr(10).split("x")
			if parts.size() >= 2:
				var w: = int(parts[0])
				var h: = int(parts[1])
				if w > 0 and h > 0:
					get_tree().root.size = Vector2i(w, h)
					DisplayServer.window_set_size(Vector2i(w, h))


func _ready() -> void:
	_apply_resolution_arg()
	await get_tree().process_frame
	var args: = OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--tut_shots="):
			_shot_dir = a.substr(12)
			DirAccess.make_dir_recursive_absolute(_shot_dir)
		elif a.begins_with("--insets="):
			var p: PackedStringArray = a.substr(9).split(",")
			if p.size() >= 2:
				V10Hud2Util.sim_insets = {"top": float(p[0]), "bottom": float(p[1])}
	if "--tut_compile=1" in args:
		_suite_code_hygiene()
		await _clean_quit(1 if fails > 0 else 0)
		return
	if "--tut_logic=1" in args:
		var lt0: RefCounted = load(DIR + "tut_logic_test.gd").new()
		var f0: int = await lt0.run_logic(self)
		await _clean_quit(1 if f0 > 0 else 0)
		return
	if "--tut_l1=1" in args or "--tut_bot=1" in args:
		var lt1: RefCounted = load(DIR + "tut_logic_test.gd").new()
		var f1: int = await lt1.run_l1(self)
		await _clean_quit(1 if f1 > 0 else 0)
		return
	var static_only: = "--tut_static=1" in args
	await _run_all(static_only)
	await _clean_quit(1 if fails > 0 else 0)


func _run_all(static_only: bool) -> void:
	_suite_code_hygiene()
	_suite_lines_and_lint()
	_suite_state_and_gates()
	await _suite_coach_and_geometry()
	await _suite_help_and_sheets()
	_mod = "logic"
	var lt: RefCounted = load(DIR + "tut_logic_test.gd").new()
	var lf: int = await lt.run_logic(self)
	checks += int(lt.n)
	fails += lf
	mods["logic"] = [int(lt.n) - lf, int(lt.n)]
	if not static_only:
		_mod = "live"
		var lt2: RefCounted = load(DIR + "tut_logic_test.gd").new()
		var lf2: int = await lt2.run_l1(self)
		checks += int(lt2.n)
		fails += lf2
		mods["live"] = [int(lt2.n) - lf2, int(lt2.n)]
	var parts: = []
	for k in mods:
		parts.append("%s %d/%d" % [k, mods[k][0], mods[k][1]])
	var passed: = checks - fails
	print("V10TUT %d/%d (%s)" % [passed, checks, ", ".join(parts)])
	print("TUT_SELFTEST %d/%d %s" % [passed, checks, "OK" if fails == 0 else "FAIL"])


func _suite_code_hygiene() -> void:
	_mod = "code"
	var files: = []
	_collect_gd(DIR, files)
	_collect_gd("res://core/tutorial/", files)  # WP3: tut_state/tut_lines/tut_reveal moved to core
	ok(files.size() >= 11, "tutorial scripts count >= 11 (%d)" % files.size())
	var hex_re: = RegEx.create_from_string("Color\\s*\\(\\s*\"#?[0-9a-fA-F]{6,8}\"")
	var flt_re: = RegEx.create_from_string("Color\\s*\\(\\s*0\\.[0-9]")
	for p in files:
		var s = load(p)
		ok(s is GDScript and (s as GDScript).can_instantiate(), "compile %s" % p.get_file())
		var txt: = FileAccess.get_file_as_string(p)
		ok(hex_re.search(txt) == null and flt_re.search(txt) == null, "В-1 no color literals in %s" % p.get_file())
		var ts_fn: = "Time.get_unix_time" + "_from_system"
		var td_fn: = "Time.get_date_string" + "_from_system"
		var aff_fn: = "G.add" + "_aff("
		var rub_ch: = char(0x20BD)
		ok(txt.count(ts_fn) == 0 and txt.count(td_fn) == 0, "no raw system clock in %s" % p.get_file())
		ok(txt.count(aff_fn) == 0, "no G.add_aff in %s" % p.get_file())
		ok(txt.find(rub_ch) < 0, "С-2/С-9 no ruble sign in %s" % p.get_file())


func _collect_gd(dir_path: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in DirAccess.get_directories_at(dir_path):
		if not d.begins_with("."):
			_collect_gd(dir_path.path_join(d), out)


func _suite_lines_and_lint() -> void:
	_mod = "lint"
	var hlines: = V10TutLines.all_heroine_lines()
	var uistrs: = V10TutLines.all_ui_strings()
	ok(hlines.size() >= 38, "heroine lines >= 38 (%d)" % hlines.size())
	ok(V10Lint.scan(hlines).is_empty(), "С-9 heroine lines pass V10Lint.check: %s" % str(V10Lint.scan(hlines)))
	ok(V10Lint.ui_scan(hlines).is_empty(), "С-1 heroine lines pass V10Lint.ui_check: %s" % str(V10Lint.ui_scan(hlines)))
	ok(V10Lint.ui_scan(uistrs).is_empty(), "С-1 UI strings pass V10Lint.ui_check: %s" % str(V10Lint.ui_scan(uistrs)))
	for s in hlines + uistrs:
		var low: = String(s).to_lower()
		for bw in BANNED_09:
			if bw == "режимы":
				ok(String(s).strip_edges() != "Режимы", "no 0.9 tab Режимы in «%s»" % s)
			else:
				ok(low.find(bw) < 0, "no 0.9 word «%s» in «%s»" % [bw, s])
	for k in V10TutLines.INTROS:
		var ln: = V10TutLines.intro_line(String(k))
		ok(V10Type.lines_needed(ln, "hand", 30, 488.0) <= 2, "intro %s <= 2 Caveat lines at 488 px" % k)
	for k in V10TutLines.MATCH:
		var mln: = V10TutLines.match_line(String(k), {"n": 7})
		ok(V10Type.lines_needed(mln, "hand", 30, 456.0) <= 2, "match %s <= 2 Caveat lines at 456 px" % k)
	for bk in ["understood", "more", "show_in_game", "replay_first", "skip", "skip_sure", "glossary", "how_to"]:
		var bt: = V10TutLines.ui(bk)
		ok(bt.length() <= 18, "button «%s» <= 18 chars (%d)" % [bt, bt.length()])
	var all_joined: = " ".join(hlines + uistrs)
	for req in ["Чайная", "Героини", "Столы", "Желания", "Лавка", "Приём", "Азарт", "Ставка ×2", "Дар", "Играть"]:
		ok(all_joined.find(req) >= 0, "canonical 0.10 term «%s» present" % req)
	V10Type.overflow.clear()
	for tk in V10TutLines.HELP:
		var rows: Array = V10TutLines.HELP[tk].rows
		ok(rows.size() >= 1 and rows.size() <= 3, "HELP[%s] has 1..3 rows (%d)" % [tk, rows.size()])
		for r in rows:
			var lbl: = Label.new()
			V10Type.fit(lbl, String(r[1]), "text_l", 544.0, 2, V10DS.PAPER_100)
			lbl.free()
	ok(V10Type.overflow.is_empty(), "HELP rows fit <= 2 lines without ellipsis (%s)" % str(V10Type.overflow))


func _suite_state_and_gates() -> void:
	_mod = "gates"
	# 1. v1 migration -> v2
	var sv1: = {"unlocked": 1, "v10_tut": {"v": 1, "chapters": {"match1": true}, "tips_off": true, "large": true, "step": "old"}}
	var d1: = V10TutState.ensure(sv1)
	ok(int(d1.v) == 2 and bool(d1.first_match) and not bool(d1.hints) and bool(d1.large) and not d1.has("chapters"), "v1 -> v2 migration")
	# 2. 0.9 tut_done migration + JSON round-trip idempotency
	var s09: = {"unlocked": 5, "tut_done": true}
	V10TutState.ensure(s09)
	var snap_tut: = JSON.stringify(s09.v10_tut)
	var back: Dictionary = JSON.parse_string(JSON.stringify(s09))
	V10TutState.ensure(back)
	ok(JSON.stringify(back.v10_tut) == snap_tut and bool(back.v10_tut.legacy) and bool(back.v10_tut.first_match), "0.9 migration + JSON idempotency")
	ok(not bool(back.v10_tut.seen.get("v10_welcome", false)) and bool(back.v10_tut.seen.get("lantern_salon", false)), "0.9 welcome kept, open gates marked seen")
	# 3. UX §3.5 staged gates + day rollover + rank gates
	V10Meta.bind({})
	var base_u: = 1795687200
	V10Meta.set_now(base_u)
	V10TutState.test_store = {"unlocked": 1, "rp": 0}
	V10TutState.st()
	ok(V10Reveal.is_open("tab.teahouse") and not V10Reveal.is_open("tab.tables"), "L0: only teahouse open")
	var expected_lvls: = [
		[2, "tab.tables"], [3, "lantern.salon"], [4, "tab.wishes"], [4, "match.help"],
		[6, "phone"], [7, "lantern.today"], [9, "tab.shop"], [11, "path.boosters"], [11, "path.ogonyok"],
		[15, "mode.triples"], [17, "tables.tourney"], [35, "mode.riichi"], [46, "mode.koikoi"],
	]
	for pair in expected_lvls:
		V10TutState.test_store["unlocked"] = int(pair[0]) - 1
		ok(not V10Reveal.is_open(String(pair[1])), "%s closed before unlocked=%d" % [pair[1], pair[0]])
		V10TutState.test_store["unlocked"] = int(pair[0])
		ok(V10Reveal.is_open(String(pair[1])), "%s open at unlocked=%d" % [pair[1], pair[0]])
	# Heroines right after first SSR pick on L3
	V10TutState.test_store = {"unlocked": 4, "first_pick": ""}
	V10TutState.st()
	ok(not V10Reveal.is_open("tab.heroines"), "heroines waits at L3 before first_pick")
	V10TutState.test_store["first_pick"] = "rin"
	ok(V10Reveal.is_open("tab.heroines"), "heroines opens at L3 right after first_pick")
	# Shop opens quietly at L8: zero shop intro
	V10TutState.test_store = {"unlocked": 9}
	V10TutState.st()
	ok(V10Reveal.is_open("tab.shop") and not V10Reveal.due_intros("shop").has("shop_first"), "shop opens quietly at L8")
	# Day 2 & Day 3 via V10Meta clock
	V10Meta.set_now(base_u + 86400)
	ok(V10TutState.day_number() == 2 and V10Reveal.is_open("lantern.streak") and not V10Reveal.is_open("phone.feed"), "Day 2 opens streak")
	V10Meta.set_now(base_u + 2 * 86400)
	ok(V10TutState.day_number() == 3 and V10Reveal.is_open("phone.feed"), "Day 3 opens feed")
	# Rank gates (Нефрит I = 3, Нефрит III = 5, Золото I = 9) + force_open
	V10TutState.test_store["rank_index"] = 3
	ok(V10Reveal.is_open("mode.journey") and V10Reveal.is_open("mode.garden") and not V10Reveal.is_open("mode.duels"), "Нефрит I opens journey & garden")
	V10TutState.test_store["rank_index"] = 5
	ok(V10Reveal.is_open("mode.duels") and not V10Reveal.is_open("mode.pagoda"), "Нефрит III opens duels")
	V10Reveal.force_open("mode.pagoda")
	ok(V10Reveal.is_open("mode.pagoda"), "force_open opens pagoda")
	ok(V10Reveal.screen_matches("tables", "tables") and V10Reveal.screen_matches("tables", "levels") and V10Reveal.screen_matches("tables", "v10path"), "tables screen group")
	V10Meta.clear_now()
	V10Meta.unbind()
	V10TutState.test_store = null


func _suite_coach_and_geometry() -> void:
	_mod = "geom"
	V10TutState.test_store = {"unlocked": 7, "partner": "mc"}
	V10TutState.st()
	var holder: = Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(holder)
	var coach: = V10Coach.new()
	V10Coach.layer(self).add_child(coach)
	await get_tree().process_frame

	# Verify EVERY required tut_id resolves via meta "tut_id" on HUD v2 demo hosts
	var h_home: = V10TutDemo.make_home(holder)
	await get_tree().process_frame
	for tid in ["nav.teahouse", "nav.heroines", "nav.tables", "nav.wishes", "nav.shop", "home.hero", "home.play",
			"home.phone", "home.partner", "lantern.today", "lantern.salon", "lantern.streak"]:
		ok(V10TutTarget.find(h_home, tid).ok, "tut_id %s resolves on V10HudHome" % tid)
	# Tea House coach checks (lantern.salon do + home.play tap) across normal & notched insets
	for ins in [{"top": 0.0, "bottom": 0.0}, {"top": 48.0, "bottom": 24.0}]:
		V10Hud2Util.sim_insets = ins
		h_home.layout_now()
		var face_h: Rect2 = (h_home.L.hero_face as Rect2).grow(48.0)
		for pair in [["lantern_salon", "lantern.salon", "do"], ["home_first", "home.play", "tap"], ["wishes_first", "nav.wishes", "do"]]:
			coach.show_step({"line": V10TutLines.intro_line(pair[0]), "speaker": "mc", "target": pair[1],
				"mode": pair[2], "dim": 0.72, "avoid": [face_h], "root": h_home, "timeout": 0, "instant": true})
			await get_tree().process_frame
			var ds: = coach.debug_state()
			ok(bool(ds.revealed) and (ds.hole as Rect2).has_area(), "home %s revealed" % pair[0])
			ok(int(ds.lines) <= 2, "home %s <= 2 lines (%d)" % [pair[0], int(ds.lines)])
			ok(not (ds.text_rect as Rect2).intersects(face_h), "Г-1 home %s clears face_rect+48" % pair[0])
			ok(int(ds.animated) <= 1, "В-7 home %s <= 1 animation" % pair[0])
		if _shot_dir != "" and float(ins.top) == 0.0:
			await get_tree().create_timer(0.55).timeout
			await _save_shot("01_home_coach")
	coach.complete("tap")
	h_home.queue_free()
	V10TutTarget.clear_cache()
	await get_tree().process_frame

	# Tables demo host
	V10Hud2Util.sim_insets = {}
	var h_tab: = V10TutDemo.make_tables(holder)
	await get_tree().process_frame
	for tid2 in ["tables.play", "tables.tourney", "tables.mode.triples", "tables.mode.riichi", "tables.mode.koikoi",
			"tables.mode.duels", "tables.mode.journey", "tables.mode.pagoda"]:
		ok(V10TutTarget.find(h_tab, tid2).ok, "tut_id %s resolves on Tables" % tid2)
	coach.show_step({"line": V10TutLines.intro_line("tables_first"), "speaker": "mc", "portrait": true,
		"target": "tables.play", "mode": "tap", "dim": 0.72, "root": h_tab, "timeout": 0})
	await get_tree().process_frame
	ok(int(coach.debug_state().lines) <= 2, "tables_first <= 2 lines with portrait")
	coach.complete("tap")
	h_tab.queue_free()
	V10TutTarget.clear_cache()
	await get_tree().process_frame

	# Match HUD v2 host (L1 without help discs + L4+ with help discs) + two-tap skip + fx_level=min
	for show_h in [false, true]:
		var h_m: = V10TutDemo.make_match(holder, {"show_help": show_h, "stake_offer": true})
		h_m.combo_l.visible = true
		await get_tree().process_frame
		for tid3 in ["match.tray", "match.hero", "match.board", "match.hint", "match.pause", "match.status",
				"match.stake", "match.combo", "match.tile_a", "match.tile_b"]:
			if tid3 == "match.hint" and not show_h:
				continue
			ok(V10TutTarget.find(h_m, tid3).ok, "tut_id %s resolves on V10HudMatch (help=%s)" % [tid3, show_h])
		var face_m: = h_m.hero_face_global().grow(48.0)
		var board_r: = h_m.board_rect()
		var tr_r: Rect2 = h_m.L.get("tray", Rect2(16, 792, 688, 104))
		var vs_m: = get_viewport().get_visible_rect().size
		var x0: = tr_r.position.x + (148.0 if show_h and not bool(h_m.L.get("wide", false)) else 8.0)
		var anc: = Rect2(x0, tr_r.end.y + 8.0, maxf(240.0, tr_r.end.x - 8.0 - x0), maxf(112.0, vs_m.y - tr_r.end.y - 24.0))
		var avoid_m: = [face_m, board_r]
		if show_h:
			for dk in h_m.discs:
				avoid_m.append(Rect2((h_m.discs[dk] as Control).get_global_rect().position, Vector2(128, 80)))
		for mk in ["m_a", "m_tray", "m_ult", "match_help", "match_stake"]:
			if mk == "match_help" and not show_h:
				continue
			var m_e: Dictionary = V10TutLines.MATCH[mk]
			var tg_m: = "match.hint" if mk == "match_help" else String(m_e.target)
			coach.show_step({"line": V10TutLines.match_line(mk, {"n": 7}), "speaker": "mc", "target": tg_m,
				"mode": String(m_e.mode), "dim": 0.45 if mk == "m_a" else 0.0, "place": "hero", "ctx": "match",
				"anchor": anc, "avoid": avoid_m, "skippable": mk == "m_a", "root": h_m, "timeout": 0, "instant": true})
			await get_tree().process_frame
			var dsm: = coach.debug_state()
			ok(int(dsm.lines) <= 2, "match %s <= 2 lines (help=%s, got %d)" % [mk, show_h, int(dsm.lines)])
			ok(not (dsm.text_rect as Rect2).intersects(face_m), "Г-1 match %s clears face_rect+48" % mk)
			ok(not (dsm.text_rect as Rect2).intersects(board_r), "match %s clears sacred board_rect (help=%s tr=%s br=%s anc=%s)" % [mk, show_h, dsm.text_rect, board_r, anc])
			if mk == "m_a":
				var skr: Rect2 = dsm.skip_rect
				ok(bool(dsm.skippable) and skr.size.x >= 80.0 and skr.size.y >= 80.0, "В-6 skip hit >= 80 (%s)" % str(skr.size))
				if _shot_dir != "" and not show_h:
					await get_tree().create_timer(0.55).timeout
					await _save_shot("02_match_l1")
		V10Hud2Util.fx_override = "min"
		coach.show_step({"line": V10TutLines.match_line("m_a"), "speaker": "mc", "target": "match.tile_a",
			"mode": "do", "dim": 0.45, "place": "hero", "anchor": anc, "avoid": avoid_m, "root": h_m, "timeout": 0, "instant": true})
		await get_tree().process_frame
		ok(int(coach.debug_state().animated) == 0, "В-7 fx_level=min -> 0 animated rings")
		V10Hud2Util.fx_override = ""
		coach.complete("tap")
		h_m.queue_free()
		V10TutTarget.clear_cache()
		await get_tree().process_frame

	# Victory HUD v2 host (wait for «Вдох» 0.3s + 0.16s stagger so modulate.a > 0.05)
	var h_vic: = V10TutDemo.make_victory(holder)
	await get_tree().create_timer(0.55).timeout
	for tid4 in ["win.stars", "win.rewards", "win.next", "win.home"]:
		ok(V10TutTarget.find(h_vic, tid4).ok, "tut_id %s resolves on V10HudVictory" % tid4)
	coach.show_step({"line": V10TutLines.match_line("v_home"), "speaker": "mc", "target": "win.home",
		"mode": "do", "dim": 0.72, "ctx": "work", "root": h_vic, "timeout": 0, "instant": true})
	await get_tree().process_frame
	ok(int(coach.debug_state().lines) <= 2, "victory v_home <= 2 lines")
	if _shot_dir != "":
		await get_tree().create_timer(0.55).timeout
		await _save_shot("03_victory_coach")
	coach.complete("tap")
	h_vic.queue_free()
	coach.queue_free()
	holder.queue_free()
	V10TutTarget.clear_cache()
	V10TutState.test_store = null
	await get_tree().process_frame


func _suite_help_and_sheets() -> void:
	_mod = "help"
	V10TutState.test_store = {"unlocked": 4, "partner": "mc"}
	V10TutState.st()
	V10TutState.mark("home_first")
	var stage: = Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	var hb: = V10Help.help_button(stage, Rect2(632, 4, 80, 80), stage, "teahouse")
	ok(hb.size == Vector2(80, 80) and String(hb.get_meta("ux_role", "")) == "tertiary", "help_button 80x80 tertiary")

	# Check every contextual «?» topic sheet (UX §4.1.9: ≤3 rows, «Понятно» primary, «Подробнее» secondary, hit >= 80)
	for tp in V10TutLines.HELP:
		var sh: = V10Help.open(stage, String(tp))
		await get_tree().process_frame
		ok(sh != null and V10TutHelp.current() == sh, "open help topic %s" % tp)
		if sh != null:
			var page: Control = sh.get("page")
			var rl: = V10MetaUI.roles(page)
			ok(int(rl.primary) == 1 and int(rl.secondary) <= 2 and int(rl.tertiary) <= 2,
				"П-1 help %s roles %s" % [tp, str(rl)])
			ok(V10MetaUI.small_hits(page).is_empty(), "В-6 help %s hits >= 80: %s" % [tp, str(V10MetaUI.small_hits(page))])
			ok(V10TutTarget.find(page, "help.more").ok, "UX §4.1.9 help %s has «Подробнее»" % tp)
	if _shot_dir != "":
		V10Help.open(stage, "teahouse")
		await get_tree().create_timer(0.3).timeout
		await _save_shot("04_help_teahouse")

	# Tapping «Подробнее» swaps the SAME sheet to «Как играть» (П-6: never two sheets)
	var sh0: = V10Help.open(stage, "tables")
	await get_tree().process_frame
	var more_b: = V10TutTarget.find(sh0, "help.more").node as V10Button
	ok(more_b != null, "tables sheet has help.more button")
	if more_b != null:
		more_b.pressed.emit()
		await get_tree().process_frame
		ok(V10TutHelp.current() == sh0 and String(sh0.get("page_kind")) == "list", "Подробнее swaps same sheet to list")
		var list_ctrl: Control = sh0.get("_list")
		var teasers: = 0
		if list_ctrl != null:
			for ch in list_ctrl.get_children():
				if ch.has_meta("tut_id") and String(ch.get_meta("tut_id")) == "help.teaser":
					teasers += 1
		ok(teasers == 1, "В-8 how_to shows exactly 1 closed teaser (%d)" % teasers)
		if _shot_dir != "":
			await get_tree().create_timer(0.3).timeout
			await _save_shot("05_how_to")
	V10Help.locked_toast(stage, Rect2(576, 1144, 144, 136), V10Reveal.locked_text("tab.shop"))
	await get_tree().process_frame
	var sl: = V10TutHelp.layer(stage)
	ok(sl != null and sl.get_node_or_null("V10TutToast") != null, "locked_toast spawns S plate")
	V10Help.close_all(stage)
	stage.queue_free()
	V10TutTarget.clear_cache()
	V10TutState.test_store = null
	await get_tree().create_timer(0.25).timeout


func _save_shot(name_s: String) -> void:
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	var vs: = get_viewport().get_visible_rect().size
	img.save_png("%s/%s_%dx%d.png" % [_shot_dir, name_s, int(vs.x), int(vs.y)])


# Drop static Callable / FontVariation caches before SceneTree quits so Godot 4.5.1 exits cleanly with code 0.
func _clean_quit(code: int) -> void:
	V10Help.close_all(self)
	if V10Tutorial.inst != null and is_instance_valid(V10Tutorial.inst):
		V10Tutorial.inst.queue_free()
		V10Tutorial.inst = null
	for lname in ["V10TutLayer", "V10TutSheetLayer"]:
		var l: = get_tree().root.get_node_or_null(lname)
		if l != null:
			l.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	V10TutTarget.clear_all()
	V10Type._fonts.clear()
	V10Type._ls.clear()
	V10Fonts._cache.clear()
	V10Fonts._files.clear()
	V10Lint._re_cache.clear()
	V10Hud2Util._classes.clear()
	V10Registry._mods.clear()
	V10Save._migrators.clear()
	V10GClock.now_fn = Callable()
	V10Bond.sink = Callable()
	V10EntryQueue.new_launch()
	get_tree().quit(code)
