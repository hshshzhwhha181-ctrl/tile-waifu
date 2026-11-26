extends Node

# Самотест и утилиты «Моста к столу» (docs/MODES.md §4.5, §7.1; UX_RULES §6.6):
#   --mj_bridge_selftest=1   печатает MJ_BRIDGE ok/total и завершает с кодом 0/1
#   --bridge_gen=365 / --bridge_bake=1 / --bridge_probe=1   CLI-утилиты разработки

const DIR_PATH: = "res://scripts/v10/mj/bridge"

var args: = {}
var ok_n: = 0
var tot_n: = 0
var fails: Array = []


func check(cond: bool, msg: String) -> void:
	tot_n += 1
	if cond:
		ok_n += 1
	else:
		fails.append(msg)
		push_error("MJ_BRIDGE FAIL: " + msg)


func _ready() -> void:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			args[s.substr(2, s.find("=") - 2)] = s.substr(s.find("=") + 1)
	await get_tree().process_frame
	if args.has("bridge_gen"):
		var t0: = Time.get_ticks_msec()
		var n: = int(args.bridge_gen)
		var d: = V10MjBridgeDaily.generate(n, func(it, tries): print("gen %d %s tries=%d sh=%d uke=%d best=%s" % [it.n, it.kind, tries, it.sh, it.uke, str(it.best)]))
		print("gen ms=", Time.get_ticks_msec() - t0, " tries=", d.tries)
		if n == 365:
			V10MjBridgeDaily.write(V10MjBridgeDaily.DATA_PATH, d)
		get_tree().quit(0)
		return
	if args.has("bridge_bake"):
		var t0: = Time.get_ticks_msec()
		V10MjBridgeLevels.bake(V10MjBridgeLevels.BAKE_PATH, func(e): print(JSON.stringify(e)))
		print("bake ms=", Time.get_ticks_msec() - t0)
		get_tree().quit(0)
		return
	if args.has("bridge_compile"):
		for f in ["bridge_tiles", "bridge_daily", "bridge_hand", "bridge_levels", "bridge_save", "bridge_info", "bridge_look", "bridge_icon", "bridge_tile", "bridge_presence", "bridge_daily_screen", "bridge_hand_screen", "bridge_screen"]:
			var sc: = load("res://scripts/v10/mj/bridge/%s.gd" % f)
			print("compile ", f, " ", sc != null and sc.can_instantiate())
		get_tree().quit(0)
		return
	if args.has("bridge_probe"):
		var from: = int(args.get("from", "1"))
		var to: = int(args.get("to", "60"))
		for i in range(from, to + 1):
			var lv: = V10MjBridgeLevels.build(i)
			var sv: = V10MjBridgeLevels.solve(lv, int(args.get("budget", "6000")))
			print("L%d n=%d req=%d digs=%d solve=%s nodes=%d" % [i, lv.n, lv.req, lv.digs, sv.ok, sv.nodes])
		get_tree().quit(0)
		return

	var t_all: = Time.get_ticks_msec()
	_t_daily_365()
	_t_auto_meld_non_greedy()
	_t_levels_60()
	_t_save_words_glossary()
	await _t_screens()
	print("MJ_BRIDGE %d/%d (%d ms)" % [ok_n, tot_n, Time.get_ticks_msec() - t_all])
	get_tree().quit(0 if ok_n == tot_n else 1)


func _t_daily_365() -> void:
	var items: Array = V10MjBridgeDaily.items()
	check(items.size() == 365, "daily_discard_2027.json has 365 items (%d)" % items.size())
	var valid_hands: = 0
	var exact_best: = 0
	var explain_ok: = 0
	for it in items:
		var h: Array = it.hand
		var cnt: = {}
		var ok_h: = h.size() == 14
		for k in h:
			var kv: = int(k)
			cnt[kv] = int(cnt.get(kv, 0)) + 1
			if kv < 0 or kv >= 34 or int(cnt[kv]) > 4:
				ok_h = false
		if ok_h:
			valid_hands += 1
		var an: = V10MjBridgeDaily.analyze(h, int(it.dora))
		var b_ref: Array = an.best.duplicate()
		var b_it: Array = it.best.duplicate()
		b_ref.sort()
		b_it.sort()
		if b_ref == b_it and not b_ref.is_empty():
			exact_best += 1
		var ex: = V10MjBridgeDaily.explain(it, int(b_ref[0]), true)
		if ex.length() > 4:
			explain_ok += 1
	check(valid_hands == 365, "all 365 daily hands valid 14 tiles <=4 copies (%d/365)" % valid_hands)
	check(exact_best == 365, "all 365 daily best discards match shanten+ukeire oracle (%d/365)" % exact_best)
	check(explain_ok == 365, "all 365 daily explanations non-empty (%d/365)" % explain_ok)
	var sh_txt: = V10MjBridgeDaily.share(items[0], 1, false)
	var spoiler: = false
	for w in ["бамбук", "точек", "символ", "ветер", "дракон", "восток", "юг", "запад", "север"]:
		if sh_txt.to_lower().find(w) >= 0:
			spoiler = true
	check(not spoiler and sh_txt.find("Задача") >= 0, "share text is spoiler-free")


func _t_auto_meld_non_greedy() -> void:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 202705
	var lost_wins: = 0
	var greedy_fails: = 0
	for _t in 2000:
		# собираем заведомо победную руку 14 фишек (4 набора + пара) и подаём в случайном порядке
		var cnt: = V10MjBridgeTiles.zero()
		var tiles14: Array = []
		var sets_made: = 0
		var guard: = 0
		while sets_made < 4 and guard < 100:
			guard += 1
			if rng.randf() < 0.65:
				var st: = rng.randi_range(0, 2) * 9 + rng.randi_range(0, 6)
				if cnt[st] < 4 and cnt[st + 1] < 4 and cnt[st + 2] < 4:
					for x in [st, st + 1, st + 2]:
						cnt[x] += 1
						tiles14.append(x)
					sets_made += 1
			else:
				var k: = rng.randi_range(0, 33)
				if cnt[k] <= 1:
					for _j in 3:
						cnt[k] += 1
						tiles14.append(k)
					sets_made += 1
		var pk: = rng.randi_range(0, 33)
		while cnt[pk] > 2:
			pk = (pk + 1) % 34
		tiles14.append(pk)
		tiles14.append(pk)
		for i in range(13, 0, -1):
			var j: = rng.randi_range(0, i)
			var tmp = tiles14[i]
			tiles14[i] = tiles14[j]
			tiles14[j] = tmp
		var pos14: Array = []
		for i in 14:
			pos14.append(Vector3(i, 0, 0))
		var r: = V10MjBridgeHand.make({"pos": pos14, "kinds": tiles14, "req": 1})
		for i in 14:
			r.take(i)
		if not r.won:
			lost_wins += 1
		# сравнение с наивной жадной сборкой без оглядки на остаток
		var g_loose: Array = []
		var g_sets: = 0
		for kv in tiles14:
			g_loose.append(int(kv))
			while g_sets < 4:
				var gp: = V10MjBridgeHand.greedy_pick(V10MjBridgeTiles.counts(g_loose))
				if gp.is_empty():
					break
				for x in gp.k:
					g_loose.erase(int(x))
				g_sets += 1
		if not (g_sets == 4 and g_loose.size() == 2 and g_loose[0] == g_loose[1]):
			greedy_fails += 1
	check(lost_wins == 0 and greedy_fails > 0, "non-greedy auto-meld wins 2000/2000 (lost=%d, naive_greedy_lost=%d)" % [lost_wins, greedy_fails])


func _t_levels_60() -> void:
	var built: = 0
	var certs: = 0
	var solved: = 0
	var req_ok: = 0
	for i in range(1, V10MjBridgeLevels.COUNT + 1):
		var lv: = V10MjBridgeLevels.build(i)
		if not lv.is_empty():
			built += 1
		if V10MjBridgeLevels.certificate_ok(lv):
			certs += 1
		var sv: = V10MjBridgeLevels.solve(lv, 6000)
		if bool(sv.ok):
			solved += 1
		if (i < 20 and int(lv.req) == 1) or (i >= 20 and int(lv.req) >= 2):
			req_ok += 1
	check(built == 60 and certs == 60, "all 60 hand levels built & certificate_ok (%d/60, %d/60)" % [built, certs])
	check(solved == 60 and req_ok == 60, "all 60 hand levels solved by bot & L20+ require >=x2 (%d/60)" % solved)


func _t_save_words_glossary() -> void:
	var S: = {}
	var d: = V10MjBridgeSave.ensure(S)
	check(not bool(d.riichi_open) and int(d.hand_level) == 1, "save defaults")
	V10MjBridgeSave.record_daily(d, "2027-01-01", 1, true, 1, false, 0)
	V10MjBridgeSave.record_daily(d, "2027-01-02", 2, true, 1, false, 0)
	var r3: = V10MjBridgeSave.record_daily(d, "2027-01-03", 3, true, 1, false, 0)
	check(bool(d.riichi_open) and bool(r3.riichi_opened) and int(d.streak) == 3, "3 solved dailies open 4p Riichi table + streak 3")
	check(V10MjBridgeLook.TOK.night900 == V10DS.NIGHT_900 and V10MjBridgeLook.ACCENT.hana[0] == V10DS.HEROES.hana.accent, "tokens aliased to V10DS")
	var inf: = V10MjBridgeInfo.INFO
	var inf_h: = V10MjBridgeInfo.INFO_HAND
	check(String(inf.shelf) in ["solitaire", "table", "trials"] and String(inf_h.shelf) == "table" and (inf.HOW as Array).size() == 3 and (inf_h.HOW as Array).size() == 3, "INFO & INFO_HAND §7.1 contract")
	var gl_ok: = true
	for gk in ["tanyao", "sanankou", "ittsu", "chinitsu", "bridge.daily", "bridge.hand"]:
		var e: = V10MjBridgeInfo.glossary(gk)
		if String(e.get("name", "")).length() == 0 or String(e.get("why", "")).length() > 74:
			gl_ok = false
	check(gl_ok, "glossary entries valid")
	var ui_texts: Array = [inf.name, inf.line, inf_h.name, inf_h.line]
	for h in V10MjBridgeInfo.HOW_DAILY + V10MjBridgeInfo.HOW_HAND:
		ui_texts.append(h[1])
	for s in V10MjBridgeInfo.STARS_HOW:
		ui_texts.append(s)
	var bad_w: = 0
	for t in ui_texts:
		bad_w += V10Lint.ui_check(String(t)).size()
	for ln in V10MjBridgeHandScreen.LINES.values():
		bad_w += V10Lint.check(String(ln)).size() + V10Lint.ui_check(String(ln)).size()
	check(bad_w == 0, "zero banned words in bridge texts (%d)" % bad_w)
	var raw_time: = 0
	var da: = DirAccess.open(DIR_PATH)
	if da:
		da.list_dir_begin()
		var fn: = da.get_next()
		while fn != "":
			if fn.ends_with(".gd") and fn != "bridge_selftest.gd":
				var src: = FileAccess.get_file_as_string(DIR_PATH + "/" + fn)
				for pat in ["Time." + "get_unix_time_from_system", "Time." + "get_date_string_from_system", "Time." + "get_date_dict_from_system"]:
					if src.find(pat) >= 0:
						raw_time += 1
			fn = da.get_next()
	check(raw_time == 0, "zero raw Time.*_from_system in bridge/*.gd")


func _t_screens() -> void:
	var req_keys: = ["mode", "win", "score", "stars", "time_s", "pairs", "hero", "seed", "level", "rewards"]
	# 1. Экран Задачи дня (через маршрутизатор V10MjBridgeScreen)
	var vp1: = SubViewport.new()
	vp1.size = Vector2i(720, 1280)
	vp1.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp1)
	var rt1: = V10MjBridgeScreen.new()
	vp1.add_child(rt1)
	var got1: = [null]
	rt1.finished.connect(func(r): got1[0] = r)
	rt1.build(null, {"variant": "daily", "day": "2027-01-12", "instant": true, "demo": true})
	await get_tree().process_frame
	var ds: V10MjBridgeDailyScreen = rt1.child_screen as V10MjBridgeDailyScreen
	check(ds != null and ds.lite.sacred_hits() == 0, "daily screen: sacred zone clear")
	var hb1: Button = ds.find_child("HelpBtn", true, false)
	check(hb1 != null and hb1.size.x >= 80, "daily screen: ? HelpBtn >= 80")
	hb1.pressed.emit()
	await get_tree().process_frame
	var okb1: Button = ds.sheet_layer.find_child("OkBtn", true, false)
	check(okb1 != null and okb1.size.x >= 440, "daily screen: help sheet opens")
	okb1.pressed.emit()
	await get_tree().process_frame
	var best_k: int = int(V10MjBridgeDaily.analysis_of(ds.item).best[0])
	ds.select_kind(best_k)
	ds.drop()
	for _w in 8:
		if ds.sheet_layer.find_child("Primary", true, false) != null:
			break
		await get_tree().create_timer(0.06).timeout
	var done_b: Button = ds.sheet_layer.find_child("Primary", true, false)
	if done_b:
		done_b.pressed.emit()
	await get_tree().process_frame
	var res1: Dictionary = got1[0] if got1[0] is Dictionary else {}
	var has1: = true
	for k in req_keys:
		if not res1.has(k):
			has1 = false
	check(has1 and String(res1.get("mode", "")) == "bridge_daily" and bool(res1.get("win", false)), "daily screen: finished(result) 10-key schema")
	vp1.queue_free()
	await get_tree().process_frame

	# 2. Экран Собери руку
	var vp2: = SubViewport.new()
	vp2.size = Vector2i(720, 1280)
	vp2.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp2)
	var hs: = V10MjBridgeHandScreen.new()
	vp2.add_child(hs)
	var got2: = [null]
	hs.finished.connect(func(r): got2[0] = r)
	hs.build(null, {"level": 1, "hero": "hana", "start_sheet": true, "result_sheet": false, "instant": true, "demo": true})
	await get_tree().process_frame
	var hb2: Button = hs.sheet_layer.find_child("HelpBtn", true, false)
	var pb2: Button = hs.sheet_layer.find_child("Play", true, false)
	check(hb2 != null and hb2.size.x >= 80 and pb2 != null and pb2.size.x >= 440 and pb2.size.y >= 104, "hand start sheet: ? >=80, Play >=440x104")
	hb2.pressed.emit()
	await get_tree().process_frame
	var okb2: Button = hs.sheet_layer.find_child("OkBtn", true, false)
	check(okb2 != null, "hand help sheet opens")
	okb2.pressed.emit()
	await get_tree().process_frame
	pb2 = hs.sheet_layer.find_child("Play", true, false)
	pb2.pressed.emit()
	await get_tree().process_frame
	check(hs.input_on and hs.lite.sacred_hits() == 0, "hand screen: sacred zone clear")
	for t_idx in hs.lv.order:
		hs.tap(int(t_idx))
	for _w2 in 12:
		if got2[0] != null:
			break
		if hs.lite.finale_active():
			hs.lite._finale.queue_free()
			hs.lite._finale = null
			hs.lite.finale_done.emit()
		await get_tree().create_timer(0.05).timeout
	var res2: Dictionary = got2[0] if got2[0] is Dictionary else {}
	var has2: = true
	for k in req_keys:
		if not res2.has(k):
			has2 = false
	check(has2 and String(res2.get("mode", "")) == "bridge_hand" and bool(res2.get("win", false)), "hand screen: finished(result) 10-key schema")
	vp2.queue_free()
	await get_tree().process_frame
