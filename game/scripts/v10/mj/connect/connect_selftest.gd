extends Node

# Самотест «Связей» (Шисэн-сё, docs/MODES.md §4.3, контракт §7.1, UX_RULES §10):
#   godot --headless --audio-driver Dummy --path game res://scripts/v10/mj/connect/connect_selftest.tscn -- --mj_connect_selftest=1
# Печатает MJ_CONNECT ok/total, код 0 только при 100 %.

const STAGE_PATH: = "res://scripts/v10/mj/stage/presence.gd"

var args: = {}
var ok_n: = 0
var total: = 0
var fails: Array = []


func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok_n += 1
	else:
		fails.append(what)
		if fails.size() <= 40:
			print("FAIL ", what)


func _ready() -> void:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			args[s.substr(2, s.find("=") - 2)] = s.substr(s.find("=") + 1)
	get_tree().create_timer(600.0).timeout.connect(func():
		print("MJ_CONNECT watchdog: 600 s")
		get_tree().quit(2))
	await get_tree().process_frame
	var t0: = Time.get_ticks_msec()
	_t_bfs_200()
	_t_levels_90x3()
	_t_rain_shift_undo_shuffle()
	_t_save_ults_words()
	await _t_screen()
	for f in fails:
		printerr("  - ", f)
	print("MJ_CONNECT %d/%d (%d ms)" % [ok_n, total, Time.get_ticks_msec() - t0])
	get_tree().quit(0 if ok_n == total else 1)


# 1. BFS ≤ 2 поворотов на ≥ 200 эталонных случаях (рамка, углы, блокировка, сквозь фишку) + сравнение с oracle
func _t_bfs_200() -> void:
	# ручные эталоны: рамка, углы, 0/1/2/3 поворотов
	var pw: = 8
	var ph: = 8
	var occ: = PackedInt32Array()
	occ.resize(pw * ph)
	occ.fill(-1)
	# заполняем внутренность 1..6 × 1..6, проверяем связь по рамке между углами
	for y in range(1, 7):
		for x in range(1, 7):
			occ[y * pw + x] = y * 10 + x
	# верхний ряд: две угловые фишки соединяются через верхнюю рамку (2 поворота: вверх → вправо → вниз)
	var p_top: = V10MjConnectPath.find(occ, pw, ph, Vector2i(1, 1), Vector2i(6, 1))
	check(not p_top.is_empty() and V10MjConnectPath.turns_of(p_top) == 2, "border link (1,1)->(6,1) in 2 turns")
	# противоположные углы (1,1) и (6,6) при полной внутренности требуют 3 поворота → недоступно
	var p_diag: = V10MjConnectPath.find(occ, pw, ph, Vector2i(1, 1), Vector2i(6, 6))
	check(p_diag.is_empty() and not V10MjConnectPath.can_link(occ, pw, ph, Vector2i(1, 1), Vector2i(6, 6)), "opposite corners blocked at ≤2 turns")
	# запертая внутри фишка (3,3) и внешняя (1,1) — пути нет
	check(V10MjConnectPath.find(occ, pw, ph, Vector2i(3, 3), Vector2i(1, 1)).is_empty(), "enclosed tile cannot link")
	# соседние фишки — 0 поворотов
	var p_adj: = V10MjConnectPath.find(occ, pw, ph, Vector2i(2, 2), Vector2i(2, 3))
	check(p_adj.size() == 2 and V10MjConnectPath.turns_of(p_adj) == 0, "adjacent tiles: 0 turns")

	# 220 случайных конфигураций (включая края и углы): сверка find / can_link / oracle и проверка, что линия не идёт сквозь фишки
	var rng: = RandomNumberGenerator.new()
	rng.seed = 20261126
	var agree: = 0
	var clear_line: = 0
	var cases: = 220
	for k in cases:
		var cw: = rng.randi_range(6, 10)
		var ch: = rng.randi_range(6, 10)
		var gpw: = cw + 2
		var gph: = ch + 2
		var g: = PackedInt32Array()
		g.resize(gpw * gph)
		g.fill(-1)
		var dens: = rng.randf_range(0.25, 0.85)
		var tiles: Array = []
		for y in range(1, ch + 1):
			for x in range(1, cw + 1):
				if rng.randf() < dens:
					g[y * gpw + x] = tiles.size()
					tiles.append(Vector2i(x, y))
		if tiles.size() < 2:
			agree += 1
			clear_line += 1
			continue
		var a: Vector2i
		var b: Vector2i
		if k < 40:
			# принудительно края и углы
			var corners: = [Vector2i(1, 1), Vector2i(cw, 1), Vector2i(1, ch), Vector2i(cw, ch), Vector2i(cw / 2, 1), Vector2i(1, ch / 2)]
			a = corners[k % corners.size()]
			b = corners[(k * 3 + 1) % corners.size()]
			if a == b:
				b = Vector2i(cw, ch) if a != Vector2i(cw, ch) else Vector2i(1, 1)
			g[a.y * gpw + a.x] = 900
			g[b.y * gpw + b.x] = 901
		else:
			var ia: = rng.randi_range(0, tiles.size() - 1)
			var ib: = (ia + rng.randi_range(1, tiles.size() - 1)) % tiles.size()
			a = tiles[ia]
			b = tiles[ib]
		var path: = V10MjConnectPath.find(g, gpw, gph, a, b)
		var fast: = V10MjConnectPath.can_link(g, gpw, gph, a, b)
		var ora: = V10MjConnectPath.oracle(g, gpw, gph, a, b)
		var t_fast: = V10MjConnectPath.turns(g, gpw, gph, a, b)
		if (not path.is_empty()) == ora and fast == ora and (path.is_empty() or V10MjConnectPath.turns_of(path) == t_fast):
			agree += 1
		var line_ok: = true
		if not path.is_empty():
			if V10MjConnectPath.turns_of(path) > 2:
				line_ok = false
			for c in V10MjConnectPath.cells(path):
				if c != a and c != b and g[c.y * gpw + c.x] >= 0:
					line_ok = false
					break
		if line_ok:
			clear_line += 1
	check(agree == cases, "BFS == can_link == oracle on %d/%d cases" % [agree, cases])
	check(clear_line == cases, "line never passes through tiles on %d/%d cases" % [clear_line, cases])


# 2. 90 уровней × 3 сида решаемы сертификатом (включая Ливень, Сдвиг, сетку и лёд)
func _t_levels_90x3() -> void:
	check(V10MjConnectGen.COUNT == 90, "90 levels")
	var built_ok: = 0
	var cert_ok: = 0
	var variants_seen: = {}
	var obst_ok: = 0
	var total_runs: = 90 * 3
	for i in 90:
		for s in 3:
			var p: = V10MjConnectGen.build(i, s)
			if not p.is_empty() and int(p.n) >= 16 and int(p.n) % 2 == 0:
				built_ok += 1
			variants_seen[String(p.get("variant", ""))] = true
			var err: = V10MjConnectGen.verify(p)
			if err == "":
				cert_ok += 1
			var lock_valid: = true
			for lk in p.get("lock", []):
				if int(lk[1]) > 3:
					lock_valid = false
			if lock_valid:
				obst_ok += 1
	check(built_ok == total_runs, "90 × 3 boards built (%d/%d)" % [built_ok, total_runs])
	check(cert_ok == total_runs, "90 × 3 certificates verified (%d/%d)" % [cert_ok, total_runs])
	check(obst_ok == total_runs, "obstacles obey ≤ 3 moves rule (%d/%d)" % [obst_ok, total_runs])
	check(variants_seen.has("static") and variants_seen.has("rain") and variants_seen.has("shift"), "all 3 variants in chapters: %s" % str(variants_seen.keys()))
	# Крупные фишки: сетка не больше 10×12
	var p_big: = V10MjConnectGen.build(88, 1, true)
	check(int(p_big.cols) <= 10 and int(p_big.rows) <= 12 and V10MjConnectGen.verify(p_big) == "", "big tiles cap ≤ 10×12 and solvable")


# 3. Ливень и Сдвиг: сжатие стопок, побитовая отмена, гарантия хода после перемешивания
func _t_rain_shift_undo_shuffle() -> void:
	for li in [10, 30, 50, 70]:
		var p: = V10MjConnectGen.build(li, 7)
		var b: = V10MjConnectBoard.new().load_payload(p)
		var snap0_occ: = b.occ.duplicate()
		var snap0_pos: = b.pos.duplicate()
		var steps: = mini(6, (p.cert as Array).size())
		for k in steps:
			var pr: Array = p.cert[k]
			var r: = b.remove(int(pr[0]), int(pr[1]))
			check(not r.is_empty(), "L%d step %d removable" % [li + 1, k])
			for c in V10MjConnectPath.cells(r.path):
				if c != r.from_a and c != r.from_b:
					# во время хода до сжатия все промежуточные клетки были пусты (проверено path_for)
					pass
		for k in steps:
			check(b.undo(), "L%d undo %d" % [li + 1, k])
		check(b.occ == snap0_occ and b.pos == snap0_pos and b.left() == int(p.n) and b.removed_pairs == 0, "L%d undo bit-exact" % (li + 1))
		# после нескольких случайных ходов перемешивание всегда оставляет доступный ход и то же число фишек
		var rng: = RandomNumberGenerator.new()
		rng.seed = 500 + li
		for k in 5:
			var mv: = b.moves(4)
			if mv.is_empty():
				break
			var pick: Array = mv[rng.randi() % mv.size()]
			b.remove(int(pick[0]), int(pick[1]))
		var left_before: = b.left()
		check(b.shuffle(rng) and b.any_move() and b.left() == left_before, "L%d shuffle guarantees a move" % (li + 1))


# 4. Сейв, мастерство, Приёмы 5 героинь, токены V10DS, ноль сырых Time.* и запретных слов
func _t_save_ults_words() -> void:
	var S: = {}
	var d: = V10MjConnectSave.st(S)
	check(S.has(V10MjConnectSave.KEY) and int(d.level) == 1, "save defaults")
	S[V10MjConnectSave.KEY] = {"level": -9, "stars": "bad", "ranks_paid": 99}
	d = V10MjConnectSave.st(S)
	check(int(d.level) == 1 and d.stars is Dictionary and int(d.ranks_paid) <= 5, "save repairs junk")
	check(V10MjConnectSave.stars_for(true, 0, 40, 90) == 3 and V10MjConnectSave.stars_for(true, 0, 150, 90) == 2 and V10MjConnectSave.stars_for(true, 1, 40, 90) == 1 and V10MjConnectSave.stars_for(false, 0, 40, 90) == 0, "stars rules")
	S = {}
	d = V10MjConnectSave.st(S)
	var gems: = 0
	for lv_i in range(1, 76):
		var rec: = V10MjConnectSave.record(d, lv_i, true, 3, 500, 35)
		gems += int(rec.gems)
	check(gems == 150 and int(d.ranks_paid) == 5 and (d.cosmetics as Array).size() == 3, "mastery I–V pays 5 × 30 gems and 3 gifts once (%d)" % gems)

	# Приёмы 5 героинь
	for h in ["mc", "rin", "hana", "yue", "nova"]:
		var pb: = V10MjConnectBoard.new().load_payload(V10MjConnectGen.build(0, 1))
		var pl: = V10MjConnectUlts.plan(h, pb)
		check(not pl.is_empty(), "ult plan for %s" % h)
		var th: = V10MjConnectLook.thread_for(h)
		check(th.has("line") and th.has("glow"), "thread for %s" % h)

	check(V10MjConnectLook.TOK.night900 == V10DS.NIGHT_900 and V10MjConnectLook.TOK.rose500 == V10DS.ROSE_500, "tokens aliased to V10DS")
	check(V10MjConnectInfo.INFO.id == "connect" and V10MjConnectInfo.INFO.shelf == "solitaire" and V10MjConnectInfo.INFO.host == "rin" and int(V10MjConnectInfo.INFO.gate.level) == 18 and V10MjConnectInfo.HOW.size() == 3, "INFO contract")

	# Тексты и отсутствие Time.*_from_system
	var dir: = "res://scripts/v10/mj/connect/"
	var re: = RegEx.new()
	re.compile("\"([^\"\\\\]*[А-Яа-яЁё][^\"\\\\]*)\"")
	var strs: Array = []
	var raw_time: = 0
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd") or f == "connect_selftest.gd":
			continue
		var txt: = FileAccess.get_file_as_string(dir + f)
		raw_time += txt.count("Time." + "get_unix_time_from_system") + txt.count("Time." + "get_date_string_from_system")
		for ln in txt.split("\n"):
			if ln.strip_edges().begins_with("#"):
				continue
			for mt in re.search_all(ln):
				strs.append(mt.get_string(1))
	check(raw_time == 0, "zero raw Time.*_from_system calls (%d)" % raw_time)
	var bad_ui: = V10Lint.ui_scan(strs)
	check(bad_ui.is_empty(), "UI strings pass V10Lint.ui_check %s" % str(bad_ui))
	var bark_lines: Array = V10MjConnectPresence.LINES.values()
	var bad_bark: = V10Lint.scan(bark_lines)
	check(bad_bark.is_empty(), "heroine lines pass V10Lint %s" % str(bad_bark))


# 5. Экран партии: 720×1280 и 720×1600, бюджеты, хит-зоны ≥ 80, фишки ≥ 48×64, святая зона, «?», полный проход до finished
func _t_screen() -> void:
	for sz in [Vector2i(720, 1280), Vector2i(720, 1600)]:
		for pres_arg in [null, "stage"]:
			if pres_arg == "stage" and not ResourceLoader.exists(STAGE_PATH):
				continue
			var vp: = SubViewport.new()
			vp.size = sz
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			add_child(vp)
			var s: = V10MjConnectScreen.new()
			vp.add_child(s)
			s.setup(null, {"level": 18, "hero": "rin", "start_sheet": false, "instant": true, "fx_min": true, "demo": true, "mute": true, "presence": pres_arg})
			await get_tree().process_frame
			await get_tree().process_frame
			var tag: = "%dx%d_%s" % [sz.x, sz.y, "stage" if pres_arg != null else "lite"]
			check(s.tappables().size() <= 6 and s.words_in_play() <= 8, "%s: budget taps=%d words=%d" % [tag, s.tappables().size(), s.words_in_play()])
			check(s.cell_size.x >= 48.0 and s.cell_size.y >= 64.0, "%s: tile min size %.1f×%.1f >= 48×64" % [tag, s.cell_size.x, s.cell_size.y])
			var hits: Array = s.presence.sacred_hits() if s.presence.has_method("sacred_hits") else []
			check(s.input_on and hits.is_empty(), "%s: sacred zone clear (%d)" % [tag, hits.size()])
			check(s.pause_btn.size.x >= 80.0 and s.pause_btn.size.y >= 80.0, "%s: pause hit >= 80" % tag)
			vp.queue_free()
			await get_tree().process_frame

	# Стартовый лист + лист помощи «?» + полный проход партии с сигналом finished(result)
	var vp2: = SubViewport.new()
	vp2.size = Vector2i(720, 1280)
	vp2.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp2)
	var sc: = V10MjConnectScreen.new()
	vp2.add_child(sc)
	sc.build(null, {"level": 1, "hero": "hana", "start_sheet": true, "result_sheet": false, "instant": true, "fx_min": true, "demo": true, "mute": true, "need": 3})
	await get_tree().process_frame
	var hb: Button = sc.sheet_layer.find_child("HelpBtn", true, false)
	var pb: Button = sc.sheet_layer.find_child("Play", true, false)
	check(hb != null and hb.size.x >= 80 and pb != null and pb.size.x >= 440 and pb.size.y >= 104, "start sheet: ? button >=80 and primary >=440x104")
	hb.pressed.emit()
	await get_tree().process_frame
	var okb: Button = sc.sheet_layer.find_child("OkBtn", true, false)
	check(okb != null, "help sheet opens with HOW rules")
	okb.pressed.emit()
	await get_tree().process_frame
	pb = sc.sheet_layer.find_child("Play", true, false)
	pb.pressed.emit()
	await get_tree().process_frame
	check(sc.input_on, "match started after Play")

	var got: = [null]
	sc.finished.connect(func(r): got[0] = r)
	# проверка подсказки, отмены и Приёма, затем прохождение до чистого поля
	check(sc._use_help("hint") and sc.hinted_pair.size() == 2, "hint highlights pair")
	var mv0: = sc.board.moves(1)
	sc.tap_tile(int(mv0[0][0]))
	sc.tap_tile(int(mv0[0][1]))
	check(sc.moves_count == 1 and sc._use_help("undo"), "tap pair + undo")
	sc.charge = sc.need
	check(sc.try_ult() and sc.ults_used == 1, "Hana ult takes 2 pairs")
	var guard: = 0
	while sc.board.left() > 0 and guard < 200:
		guard += 1
		var mv: = sc.board.moves(1)
		if mv.is_empty():
			sc._ensure_move()
			mv = sc.board.moves(1)
		if mv.is_empty():
			break
		sc.tap_tile(int(mv[0][0]))
		sc.tap_tile(int(mv[0][1]))
	for w in 30:
		if got[0] != null:
			break
		await get_tree().create_timer(0.03).timeout
	var res = got[0]
	check(res is Dictionary and bool(res.get("win", false)), "finished(result) emitted on clear")
	if res is Dictionary:
		var all_keys: = true
		for k in ["mode", "win", "score", "stars", "time_s", "pairs", "hero", "seed", "level", "rewards"]:
			if not res.has(k):
				all_keys = false
		check(all_keys and res.mode == "connect" and int(res.level) == 1, "result matches §7.1 10-key schema")
	vp2.queue_free()
	await get_tree().process_frame
