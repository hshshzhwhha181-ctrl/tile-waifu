extends Node

# Самотест Куба (docs/MODES.md §4.4, §7.1; UX_RULES §6.6):
#   --mj_cube_selftest=1  печатает MJ_CUBE ok/total и завершает с кодом 0/1

const DIR_PATH: = "res://scripts/v10/mj/cube"
const STAGE_PATH: = "res://scripts/v10/mj/stage/presence.gd"

var ok_n: = 0
var tot_n: = 0
var fails: Array = []


func check(cond: bool, msg: String) -> void:
	tot_n += 1
	if cond:
		ok_n += 1
	else:
		fails.append(msg)
		push_error("MJ_CUBE FAIL: " + msg)


func _ready() -> void:
	var run_st: = "--mj_cube_selftest=1" in OS.get_cmdline_user_args() or "--mj_cube_selftest=1" in OS.get_cmdline_args()
	if not run_st and OS.get_cmdline_user_args().is_empty():
		run_st = true
	if not run_st:
		return
	var t0: = Time.get_ticks_msec()
	_t_freedom_and_rules()
	_t_figures_40x5()
	_t_picking_and_view()
	_t_save_sound_words()
	await _t_screen()
	print("MJ_CUBE %d/%d (%d ms)" % [ok_n, tot_n, Time.get_ticks_msec() - t0])
	get_tree().quit(0 if ok_n == tot_n else 1)


func _t_freedom_and_rules() -> void:
	# эталонный куб 3×3×3: вершина (3 оси) и ребро (2 оси) свободны, центр грани (1 ось) и ядро (0) — нет
	var cells: Array = []
	var faces: Array = []
	for z in 3:
		for y in 3:
			for x in 3:
				cells.append(Vector3i(x, y, z))
				faces.append(0)
	var r: = V10MjCubeRules.make(cells, faces)
	check(r.is_free(r.at(Vector3i(0, 0, 0))) and r.is_exposed(r.at(Vector3i(0, 0, 0))), "corner is free & exposed")
	check(r.is_free(r.at(Vector3i(1, 0, 0))) and r.is_exposed(r.at(Vector3i(1, 0, 0))), "edge is free & exposed")
	check(not r.is_free(r.at(Vector3i(1, 1, 0))) and r.is_exposed(r.at(Vector3i(1, 1, 0))), "face centre is NOT free")
	check(not r.is_free(r.at(Vector3i(1, 1, 1))) and not r.is_exposed(r.at(Vector3i(1, 1, 1))), "core is NOT free/exposed")
	# сквозной туннель по оси Z: открыты +Z и −Z (одна ось) — центральная клетка НЕ свободна
	var tc: Array = []
	var tf: Array = []
	for z in 3:
		for y in 3:
			for x in 3:
				if x == 1 and y == 1 and (z == 0 or z == 2):
					continue
				tc.append(Vector3i(x, y, z))
				tf.append(0)
	var rt: = V10MjCubeRules.make(tc, tf)
	check(not rt.is_free(rt.at(Vector3i(1, 1, 1))), "axis tunnel (+z/-z only) is NOT free")
	var eq_ok: = true
	for i in r.cells.size():
		var any_dir: = false
		for d in V10MjCubeRules.DIRS:
			if r.free_from(i, d):
				any_dir = true
				break
		if any_dir != r.is_free(i):
			eq_ok = false
	check(eq_ok, "is_free equivalent to free_from for some axis")
	# отмена, подсказка, перемешивание, Мотив и Приёмы 5 героинь
	var lv: = V10MjCubeGen.build(1, 0)
	var rm: = V10MjCubeRules.make(lv.cells, lv.faces)
	var p0: Array = lv.order[0]
	var t1: = rm.take(int(p0[0]), int(p0[1]))
	check(bool(t1.ok) and rm.left() == int(lv.n) - 2, "take removes pair")
	var un: = rm.undo()
	check(un.size() == 2 and rm.left() == int(lv.n), "undo restores pair")
	check(rm.hint_pair().size() == 2, "hint_pair returns tappable pair")
	var rng: = RandomNumberGenerator.new()
	rng.seed = 42
	check( not rm.shuffle(rng).is_empty(), "shuffle keeps figure solvable")
	var ults_ok: = true
	for h in ["mc", "rin", "hana", "yue", "nova"]:
		var pl: = V10MjCubeUlts.plan(h, rm, Vector3(lv.relic_at))
		if V10MjCubeUlts.empty(pl):
			ults_ok = false
	check(ults_ok, "all 5 heroine Priyomy produce non-empty plan")


func _t_figures_40x5() -> void:
	var built: = 0
	var certs: = 0
	var sigs: = 0
	for i in range(1, V10MjCubeShapes.COUNT + 1):
		for sk in 5:
			var lv: = V10MjCubeGen.build(i, sk)
			if bool(lv.get("ok", false)) and int(lv.n) % 2 == 0 and int(lv.n) <= V10MjCubeShapes.MAX_TILES:
				built += 1
			if V10MjCubeGen.certificate_ok(lv):
				certs += 1
			var lvs: = V10MjCubeGen.with_signature(lv, 24)
			if V10MjCubeGen.certificate_ok(lvs) and (lvs.faces as Array).has(24):
				sigs += 1
	check(built == 200, "40 × 5 figures valid even <= 125 (%d/200)" % built)
	check(certs == 200, "40 × 5 certificates replay cleanly (%d/200)" % certs)
	check(sigs == 200, "40 × 5 with_signature preserves certificate (%d/200)" % sigs)


func _t_picking_and_view() -> void:
	var lv: = V10MjCubeGen.build(25, 0) # 5×5×5 полый куб
	var r: = V10MjCubeRules.make(lv.cells, lv.faces)
	var v: = V10MjCubeView.new()
	add_child(v)
	v.setup(lv, r, {"hero": "nova", "fx_min": true, "px": 720})
	var angles: = [V10MjCubeView.HOME, Vector2(0.95, 0.35), Vector2(-1.45, -0.35), Vector2(2.55, 0.72), Vector2(0.0, 1.15), Vector2(3.14, -1.05)]
	var pick_ok: = true
	for ang in angles:
		v.set_view(ang.x, ang.y)
		var vis_n: = 0
		for i in r.cells.size():
			if v.visible_tile(i):
				vis_n += 1
				if v.pick(v.face_point(i)) != i:
					pick_ok = false
		if vis_n == 0:
			pick_ok = false
	check(pick_ok, "ray picking hits visible tiles across 6 camera rotations")
	check(v.mm.instance_count == r.cells.size() and v.lamp.shadow_enabled == false, "single MultiMesh, shadows off")
	v.queue_free()


func _t_save_sound_words() -> void:
	var S: = {}
	var d: = V10MjCubeSave.ensure(S)
	check(int(d.level) == 1 and (d.relics as Array).is_empty(), "save defaults")
	var rec: = V10MjCubeSave.record(d, 8, true, 3, 420, 30)
	check(bool(rec.first_clear) and bool(rec.relic_new) and String(rec.relic) == "mc", "boss figure 8 awards mc relic")
	var sc_arr: = V10MjCubeSave.showcase(d)
	check(sc_arr.size() == 5 and bool(sc_arr[0].have), "showcase tracks 5 relics")
	check(V10MjCubeSound.peak_of(V10MjCubeSound.toktok_wav(0)) <= 0.505, "toktok peak <= -6 dBFS")
	check(V10MjCubeSound.peak_of(V10MjCubeSound.rustle_wav(0)) <= 0.505, "rustle peak <= -6 dBFS")
	check(V10MjCubeStyle.TOK.night900 == V10DS.NIGHT_900 and V10MjCubeStyle.ACCENT.nova[0] == V10DS.HEROES.nova.accent, "tokens aliased to V10DS")
	var info: = V10MjCubeInfo.INFO
	check(String(info.id) == "cube" and String(info.title) == "Куб" and String(info.shelf) == "solitaire" and String(info.host) == "nova" and (info.HOW as Array).size() == 3, "INFO §7.1 contract")
	var ui_texts: Array = [info.name, info.line, V10MjCubeInfo.RULE]
	for r in V10MjCubeInfo.HOW:
		ui_texts.append(r[1])
	for s in V10MjCubeInfo.STARS_HOW:
		ui_texts.append(s)
	for n in V10MjCubeRelic.NAMES.values():
		ui_texts.append(n)
	var bad_w: = 0
	for t in ui_texts:
		bad_w += V10Lint.ui_check(String(t)).size()
	for ev in V10MjCubePresence.LINES.values():
		for ln in (ev as Dictionary).values():
			bad_w += V10Lint.check(String(ln)).size() + V10Lint.ui_check(String(ln)).size()
	check(bad_w == 0, "zero banned words in cube texts (%d)" % bad_w)
	var raw_time: = 0
	var da: = DirAccess.open(DIR_PATH)
	if da:
		da.list_dir_begin()
		var fn: = da.get_next()
		while fn != "":
			if fn.ends_with(".gd") and fn != "cube_selftest.gd":
				var src: = FileAccess.get_file_as_string(DIR_PATH + "/" + fn)
				for pat in ["Time.get_unix_time_from_system", "Time.get_date_string_from_system", "Time.get_date_dict_from_system"]:
					if src.find(pat) >= 0:
						raw_time += 1
			fn = da.get_next()
	check(raw_time == 0, "zero raw Time.*_from_system in cube/*.gd")


func _t_screen() -> void:
	for sz in [Vector2i(720, 1280), Vector2i(720, 1600)]:
		var vp: = SubViewport.new()
		vp.size = sz
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(vp)
		var s: = V10MjCubeScreen.new()
		vp.add_child(s)
		s.setup(null, {"level": 1, "hero": "nova", "start_sheet": false, "instant": true, "fx_min": true, "demo": true, "music": false})
		await get_tree().process_frame
		await get_tree().process_frame
		check(s.tappables().size() <= 6 and s.words_in_play() <= 8, "%dx%d: budget taps=%d words=%d" % [sz.x, sz.y, s.tappables().size(), s.words_in_play()])
		check(s.lite.sacred_hits() == 0 and s.lite.mote_over_s() <= 0.45, "%dx%d: sacred zone clear" % [sz.x, sz.y])
		# отделение свайпа от тапа по фишке
		var free_i: int = int(s.lv.order[0][0])
		var gp: Vector2 = s.view_rect.position + s.view.face_point(free_i)
		var lp: Vector2 = gp - s.catcher.position
		var y0: = s.view.yaw
		var dn: = InputEventMouseButton.new()
		dn.button_index = MOUSE_BUTTON_LEFT
		dn.pressed = true
		dn.position = lp
		s._on_field_input(dn)
		var mv: = InputEventMouseMotion.new()
		mv.position = lp + Vector2(36, 0)
		s._on_field_input(mv)
		var mv2: = InputEventMouseMotion.new()
		mv2.position = lp + Vector2(96, 0)
		s._on_field_input(mv2)
		var up: = InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = lp + Vector2(96, 0)
		s._on_field_input(up)
		check(s.selected == -1 and absf(s.view.yaw - y0) > 0.01, "%dx%d: swipe rotates and never selects tile" % [sz.x, sz.y])
		vp.queue_free()
		await get_tree().process_frame

	# стартовый лист, кнопка «?», полный проход фигуры-главы (level 8) до finished(result)
	var vp2: = SubViewport.new()
	vp2.size = Vector2i(720, 1280)
	vp2.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp2)
	var sc: = V10MjCubeScreen.new()
	vp2.add_child(sc)
	sc.build(null, {"level": 8, "hero": "mc", "start_sheet": true, "result_sheet": false, "instant": true, "fx_min": true, "demo": true, "music": false})
	await get_tree().process_frame
	var hb: Button = sc.sheet_layer.find_child("HelpBtn", true, false)
	var pb: Button = sc.sheet_layer.find_child("Primary", true, false)
	check(hb != null and hb.size.x >= 80 and pb != null and pb.size.x >= 440 and pb.size.y >= 104, "start sheet: ? >=80 and Primary >=440x104")
	hb.pressed.emit()
	await get_tree().process_frame
	var okb: Button = sc.sheet_layer.find_child("OkBtn", true, false)
	check(okb != null, "help sheet opens")
	okb.pressed.emit()
	await get_tree().process_frame
	pb = sc.sheet_layer.find_child("Primary", true, false)
	pb.pressed.emit()
	await get_tree().process_frame
	var got: = [null]
	sc.finished.connect(func(res): got[0] = res)
	for pr in sc.lv.order:
		sc.tap_tile(int(pr[0]))
		sc.tap_tile(int(pr[1]))
	for _w in 8:
		if got[0] != null:
			break
		await get_tree().create_timer(0.05).timeout
	if got[0] == null and sc.lite._finale:
		sc.lite._finish()
		await get_tree().process_frame
	var res: Dictionary = got[0] if got[0] is Dictionary else {}
	var req: = ["mode", "win", "score", "stars", "time_s", "pairs", "hero", "seed", "level", "rewards"]
	var has_all: = true
	for k in req:
		if not res.has(k):
			has_all = false
	check(has_all and String(res.get("mode", "")) == "cube" and bool(res.get("win", false)) and int(res.get("level", 0)) == 8, "finished(result) 10-key schema on clear")
	vp2.queue_free()
	await get_tree().process_frame
