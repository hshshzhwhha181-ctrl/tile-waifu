extends Node

# 0.10 Path selftest (П1–П3): --path_selftest=1 → «PATH SELFTEST ok/total» (+ FAIL lines).
# The model runs on a private dictionary (V10PathState.root_override), never on the player's save.

const Gen = preload("res://scripts/v10/levels/level_gen.gd")
const Sim = preload("res://scripts/v10/levels/level_sim.gd")
const State = preload("res://scripts/v10/path/path_state.gd")
const Rules = preload("res://scripts/v10/path/path_rules.gd")
const Boost = preload("res://scripts/v10/path/path_boosters.gd")
const Jam = preload("res://scripts/v10/path/path_jam.gd")
const PathMap = preload("res://scripts/v10/path/path_map.gd")
const Card = preload("res://scripts/v10/path/path_card.gd")
const Dlg = preload("res://scripts/v10/path/path_dialogs.gd")

var ok: = 0
var total: = 0
var by: = {}
var _sec: = ""


class StubMain extends Control:
	var overlay: Control
	var toasts: = []
	func _init(sz: Vector2) -> void:
		size = sz
		overlay = Control.new()
		overlay.size = sz
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(overlay)
	func toast(t: String, _i: = "") -> void:
		toasts.append(t)
	func show_chrome(_a, _b) -> void:
		pass


func check(cond: bool, what: String) -> void:
	total += 1
	if not by.has(_sec):
		by[_sec] = [0, 0]
	by[_sec][1] += 1
	if cond:
		ok += 1
		by[_sec][0] += 1
	else:
		print("PATH FAIL [%s] %s" % [_sec, what])


func fresh() -> Dictionary:
	var d: = {"unlocked": 1, "stars": {}, "gems": 0, "coins": 0}
	State.root_override = d
	State.day_override = "d1"
	State._lv_cache = {}
	State.st()
	Boost.st()
	return d


func run() -> Array:
	var t0: = Time.get_ticks_msec()
	_model()
	_peaks()
	_legend()
	_boosters()
	_wind()
	_jam()
	await _ui()
	State.root_override = null
	State.day_override = ""
	var parts: = []
	for k in by:
		parts.append("%s %d/%d" % [k, by[k][0], by[k][1]])
	print("PATH SELFTEST %d/%d (%s) %.1f s" % [ok, total, ", ".join(parts), (Time.get_ticks_msec() - t0) / 1000.0])
	return [ok, total]


# ------------------------------------------------------------------ progress, rewards, daily, assist, chests

func _model() -> void:
	_sec = "levels"
	var S: = fresh()
	check(State.state_of(0) == "current", "fresh: level 1 is current")
	check(State.state_of(1) == "locked", "fresh: level 2 locked")
	check(State.state_of(100) == "arc_locked" or not State.arc_released(1) or State.state_of(100) == "locked", "arc 2 not open at start")
	check(State.state_of(250) == "arc_locked", "arc 3 is a silhouette (not released)")
	# first clear pays 2 + 2×★ once; a replay pays only new stars
	var r1: = State.on_win(0, 2)
	var rw: Dictionary = State.level(0).reward
	check(int(r1.gems) == int(rw.gems) + 2 * int(rw.per_star), "first clear 2+2×★ (%d)" % int(r1.gems))
	var r2: = State.on_win(0, 2)
	check(int(r2.gems) == 0, "replay with the same stars pays 0")
	var r3: = State.on_win(0, 3)
	check(int(r3.gems) == int(rw.per_star), "a new star pays per_star")
	check(int(S.gems) == int(r1.gems) + int(r3.gems), "wallet fallback got exactly the Path gems")
	check(not r1.grants.has("shards") and not S.has("shards"), "no shards from the Path")
	# linear unlock over the main path, Peaks skipped
	var prev_u: = State.unlocked()
	var good: = true
	for i in range(1, 199):
		if Gen.is_peak(i):
			continue
		if State.state_of(i) == "locked":
			good = false
			print("  locked before its turn: ", Gen.code(i))
			break
		State.on_win(i, 1 + i % 3)
		if State.unlocked() != mini(State.next_main(i) + 1, State.released_total()):
			good = false
			print("  unlock after %s = %d" % [Gen.code(i), State.unlocked()])
			break
	check(good, "main path opens one by one, Peaks are not on the way")
	check(State.unlocked() <= State.released_total(), "never past the released arcs (%d)" % State.unlocked())
	check(prev_u < State.unlocked(), "progress moved")
	# daily full reward: label from the 10th win, nothing after the 15th
	fresh()
	State.day_override = "d2"
	var shows: = []
	var paid: = []
	for i in 20:
		var ii: = i if not Gen.is_peak(i) else i + 1
		if Gen.is_peak(i):
			continue
		shows.append(bool(State.daily().show))
		var r: = State.on_win(i, 3)
		paid.append(int(r.gems))
	check(shows[0] == false and shows.count(true) > 0, "«полная награда» hidden before the 10th win")
	var n_before: = 0
	for k in shows.size():
		if not shows[k]:
			n_before += 1
	check(n_before == Rules.DAILY_FULL_SHOW, "label shows from win #%d (got %d)" % [Rules.DAILY_FULL_SHOW + 1, n_before])
	var paid_after: = 0
	for k in range(Rules.DAILY_FULL, paid.size()):
		paid_after += paid[k]
	check(paid_after == 0 and paid[0] > 0, "no Path crystals after %d wins a day" % Rules.DAILY_FULL)
	State.day_override = "d3"
	check(bool(State.daily().full) and int(State.daily().n) == 0, "a new day resets the counter")
	# assist after 2 fails, never on Peaks / Legendary, independent of spending
	fresh()
	State.on_win(0, 3)
	State.on_win(1, 3)
	var lv: = 2
	check(not State.on_fail(lv).offer_assist, "no offer after 1 fail")
	var f2: = State.on_fail(lv)
	check(f2.offer_assist, "offer after 2 fails")
	var a_rich: = State.offer_assist(lv)
	State.S().gems = 999999
	State.S()["moon"] = 5000
	State.S()["spent_rub"] = 99999
	State.S()["purchases"] = [{"sku": "pack_1190"}]
	var a_spent: = State.offer_assist(lv)
	State.S().gems = 0
	State.S().erase("moon")
	State.S().erase("spent_rub")
	State.S().erase("purchases")
	check(a_rich == a_spent and State.offer_assist(lv) == a_rich, "assist does not depend on spending")
	State.accept_assist(lv)
	var cfg: = State.play_cfg(lv)
	check(bool(cfg.assist), "accepted: the assist deal is built")
	var sim: = Sim.new()
	Gen.load_into(sim, cfg)
	check(sim.replay(cfg.cert).is_empty(), "assist deal verifies")
	var w: = State.on_win(lv, 2)
	check(State.stars(lv) == 2 and not State.assisted(lv), "assist keeps the stars, clears after the win")
	State.on_fail(3)
	State.on_fail(3)
	State.decline_assist(3)
	check(not State.offer_assist(3), "«Нет, сам(а)» resets the offer")
	# chests: chapter chest after the boss, star chest at 25★, each claimed once, no shards
	fresh()
	for i in 10:
		if not Gen.is_peak(i):
			State.on_win(i, 3)
	check(State.chest_state(0, "chapter") == "ready", "chapter chest ready after the boss")
	var c1: = State.claim_chest(0, "chapter")
	check(int(c1.get("gems", 0)) == 20 and int(c1.get("coins", 0)) == 100 and not c1.has("shards"), "chapter chest 20 + 100 coins")
	check(State.claim_chest(0, "chapter").is_empty(), "chapter chest once")
	var cs: = State.chapter_stars(0)
	check(State.chest_state(0, "star") == ("ready" if cs >= 25 else "locked"), "star chest follows 25★ (%d)" % cs)
	fresh()
	for i in 9:
		State.on_win(i, 2)
	check(State.chest_state(0, "star") == "locked" and State.chest_state(0, "chapter") == "locked", "chests locked before the boss / 25★")
	var sc: = State.on_win(9, 3)
	check("chapter" in sc.chests, "win result lists the ready chest")
	State.S().stars["2"] = 3
	State.S().stars["3"] = 3
	State.S().stars["4"] = 3
	State.S().stars["5"] = 3
	State.S().stars["6"] = 3
	State.S().stars["7"] = 3
	State.S().stars["8"] = 3
	var c2: = State.claim_chest(0, "star")
	check(int(c2.get("petals", 0)) == 10 and int(c2.get("gems", 0)) == 40, "star chest 40 + 10 Petals")


func _peaks() -> void:
	_sec = "peaks"
	fresh()
	var p: = -1
	for i in State.released_total():
		if Gen.is_peak(i):
			p = i
			break
	check(p >= 0, "arc 1–2 have Peaks")
	if p < 0:
		return
	for i in range(0, State.boss_of(p)):
		if not Gen.is_peak(i):
			State.on_win(i, 3)
	check(State.state_of(p) == "locked", "Peak locked before the boss")
	State.on_win(State.boss_of(p), 2)
	check(State.state_of(p) == "open", "Peak opens after the chapter boss")
	check(not State.offer_assist(p), "no assist on a Peak")
	State.on_fail(p)
	State.on_fail(p)
	State.on_fail(p)
	check(not State.offer_assist(p) and int(State.peak_rec(p).tries) == 3, "3 Peak fails: tries counted, no assist")
	var cfg1: = State.play_cfg(p)
	State.on_fail(p)
	var cfg2: = State.play_cfg(p)
	check(int(cfg1.seed) == int(cfg2.seed) and bool(cfg1.no_paid_help), "same deal on retry, no paid help")
	var g0: = int(State.S().gems)
	var r: = State.on_win(p, 2, 61000)
	check(r.summit and int(r.summits) == 1, "first Peak win = summit 1")
	check(int(State.S().gems) - g0 == 30, "Peak first win 30 crystals")
	var r2: = State.on_win(p, 3, 50000)
	check(not r2.summit and State.summits() == 1 and int(r2.gems) == 0, "a Peak replay: no summit, no crystals")
	check(int(State.peak_rec(p).best_ms) == 50000, "best time kept")
	# 10 summits → «Восходящая» I
	var peaks: = []
	for i in State.released_total():
		if Gen.is_peak(i):
			peaks.append(i)
	var steps: = []
	for q in peaks:
		var rr: = State.on_win(q, 1)
		if int(rr.frame_step) > 0:
			steps.append([State.summits(), int(rr.frame_step)])
	check(steps.size() >= 1 and steps[0] == [10, 1], "frame step I at 10 summits (%s)" % str(steps))
	check("frame_rising_1" in State.st().cos, "frame registered for V10ProfileCos")


func _legend() -> void:
	_sec = "legend"
	fresh()
	var L: = 99
	check(State.is_legend(L), "1-100 is Legendary")
	for i in 99:
		if not Gen.is_peak(i):
			State.on_win(i, 3)
	check(State.state_of(L) == "current", "Legendary reachable")
	for k in 4:
		State.on_fail(L)
	check(not State.legend_bypass_ready(L), "no bypass after 4 fails")
	var f5: = State.on_fail(L)
	check(f5.bypass and not f5.offer_assist, "bypass after exactly 5 fails, never assist")
	var t0: = int(State.S().get("tickets", 0))
	var b: = State.bypass_legend(L)
	check(State.unlocked() >= 101 and State.state_of(100) in ["current", "open"], "bypass opens arc 2")
	check(State.state_of(L) == "bypass" and not ("laurel_arc1" in State.st().cos), "bypass: no laurel, crown empty")
	check(int(State.S().get("tickets", 0)) == t0 + 1, "arc end ticket on reaching the end")
	var w: = State.on_win(L, 1)
	check(w.laurel and "laurel_arc1" in State.st().cos, "a real Legendary win gives the laurel")
	check(int(State.S().get("tickets", 0)) == t0 + 1, "arc end ticket only once")
	check(int(w.gems) == 150, "Legendary first win 150")


# ------------------------------------------------------------------ boosters

func _boosters() -> void:
	_sec = "boosters"
	fresh()
	check(Boost.flame() == 0, "flame starts at 0")
	for k in 4:
		Boost.on_win("", "normal")
	check(Boost.flame() == 3, "flame caps at 3")
	Boost.on_fail("", "normal")
	check(Boost.flame() == 2, "a fail takes one step (3→2)")
	Boost.on_fail("peak", "hard", true)
	Boost.on_fail("", "very_hard")
	Boost.on_fail("pagoda", "normal")
	check(Boost.flame() == 2, "honest tables do not touch the flame")
	for m in ["peak", "legend", "pagoda", "wander", "ranked", "palm"]:
		check(not Boost.can_use(m, "normal"), "no boosters in %s" % m)
	check(not Boost.can_use("", "very_hard") and not Boost.can_use("", "legendary"), "no boosters on Очень сложный / Легендарный")
	check(Boost.can_use("", "hard") and Boost.can_use("", "easy"), "boosters on ordinary Path levels")
	check(Boost.free_at_start() == ["lantern", "wind"], "flame 2 → Фонарик + Ветер free")
	var i: = 3
	var sel: = Boost.initial_selection(i)
	check(sel.has("lantern") and sel.has("wind") and not sel.has("scroll"), "card starts with the free ones on")
	check(Boost.toggle(sel, "scroll", i) == "buy", "empty stock asks to buy")
	State.S().gems = 100
	check(Boost.buy("scroll") and int(State.S().gems) == 40 and Boost.stock("scroll") == 1, "buy: −60 crystals, +1 stock")
	check(not Boost.buy("scroll") and int(State.S().gems) == 40, "cannot buy without crystals")
	check(Boost.toggle(sel, "scroll", i) == "stock", "stock booster switches on")
	var applied: = Boost.commit(sel, i)
	check(applied.size() == 3 and Boost.stock("scroll") == 0, "commit: 3 boosters, stock used, free ones kept")
	check(applied.size() <= Rules.BOOST_MAX, "max 3 per level")
	var peak_i: = 7
	for q in 100:
		if Gen.is_peak(q):
			peak_i = q
			break
	check(Boost.initial_selection(peak_i).is_empty() and Boost.toggle({}, "lantern", peak_i) == "deny", "Peak: circles deny")
	# Фонарик on the payload: no flip-backs, no secret tiles, still solvable
	var lv_i: = 75
	var cfg: = Gen.build(lv_i)
	var had: = (cfg.v10.ice as PackedByteArray).count(1) + (cfg.v10.secret as PackedByteArray).count(1)
	Boost.lantern_payload(cfg)
	var sim: = Sim.new()
	Gen.load_into(sim, cfg)
	check((cfg.v10.ice as PackedByteArray).count(0) == int(cfg.v10.n) and (cfg.v10.secret as PackedByteArray).count(0) == int(cfg.v10.n), "Фонарик clears ice/secret (had %d)" % had)
	check(sim.replay(cfg.cert).is_empty(), "Фонарик board still solvable")
	var c2: = Boost.apply_cfg({}, ["scroll"])
	check(int(c2.get("extra_hints", 0)) == 3, "Свиток +3 hints")


func _wind() -> void:
	_sec = "wind"
	fresh()
	var n: = 0
	var two: = 0
	var one: = 0
	var bad: = 0
	var sim: = Sim.new()
	for i in range(0, 200, 3):
		var cfg: = Gen.build(i)
		var pairs: = Boost.wind_pairs(cfg)
		n += 1
		if pairs.size() == 2:
			two += 1
		if pairs.size() >= 1:
			one += 1
		if not Boost.verify_with(sim, cfg, pairs).is_empty():
			bad += 1
		for pr in pairs:
			for t in pr:
				if int(cfg.v10.shard[t]) != 0 or _is_special(cfg, t):
					bad += 1
	check(bad == 0, "wind pairs keep every board solvable and plain (%d bad)" % bad)
	check(two >= int(n * 0.75), "2 wind pairs on ≥75%% of levels (%d/%d)" % [two, n])
	check(one >= int(n * 0.95), "≥1 wind pair on ≥95%% of levels (%d/%d)" % [one, n])
	# the real board: the quiet removal does not grow the combo, the pairs leave, chains count them
	var BoardScript: Script = load("res://scripts/v10/levels/level_board.gd")
	var cfgb: = Gen.build(42)
	Boost.apply_cfg(cfgb, ["wind", "lantern"])
	var b = BoardScript.new()
	b.look = G.skin_look()
	add_child(b)
	b.setup(cfgb)
	b.apply_specials(cfgb.v10_plan)
	var alive0: = 0
	for t in b.tiles:
		if t.alive:
			alive0 += 1
	var combo0: int = b.combo
	var got_match: = [0]
	b.matched.connect(func(_a, _b, _c, _d): got_match[0] += 1)
	Boost.apply_board(b, cfgb)
	var alive1: = 0
	var ice_left: = 0
	for t in b.tiles:
		if t.alive:
			alive1 += 1
			if t.ice > 0:
				ice_left += 1
	check(b.v10_used, "payload board")
	check(alive0 - alive1 == 2 * (cfgb.v10_wind as Array).size() and (cfgb.v10_wind as Array).size() == 2, "Ветер: 2 pairs left the board")
	check(b.combo == combo0 and got_match[0] == 0, "Ветер: no combo, no match signal")
	check(ice_left == 0, "Фонарик: no flip-backs on the board")
	b.queue_free()


func _is_special(cfg: Dictionary, t: int) -> bool:
	for e in cfg.v10.spec:
		if int(e[0]) == t or int(e[1]) == t:
			return true
	return false


# ------------------------------------------------------------------ jam spot

func _jam() -> void:
	_sec = "jam"
	var tried: = 0
	var found: = 0
	var sane: = 0
	for i in range(40, 200, 7):
		var cfg: = Gen.build(i)
		var takes: = Jam.demo_fail_log(cfg, i)
		var sim: = Sim.new()
		var curve: = Jam.tray_curve(sim, cfg, takes)
		if curve.is_empty() or curve[curve.size() - 1] < 4:
			continue
		tried += 1
		var j: = Jam.find(cfg, takes)
		if j.is_empty():
			continue
		found += 1
		var in_log: = false
		for k in takes.size():
			if takes[k] == int(j.tile) and k == int(j.step):
				in_log = true
		if in_log and int(j.player_tray) > int(j.ref_tray) and str(j.text).length() > 10:
			sane += 1
	check(tried >= 10, "enough failing logs (%d)" % tried)
	check(found >= int(tried * 0.8), "jam spot found on ≥80%% of fails (%d/%d)" % [found, tried])
	check(sane == found, "jam spot is the player's take, tray above the reference (%d/%d)" % [sane, found])
	check(Jam.find(Gen.build(10), Gen.build(10).cert).is_empty(), "no jam on the reference order itself")


# ------------------------------------------------------------------ UI trees

func _walk(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_walk(c, out)


func _has_gem_price(root: Node) -> bool:
	var gem: = V8Art.cur("gem")
	var all: = []
	_walk(root, all)
	for x in all:
		if x is TextureRect and (x as TextureRect).texture == gem:
			# a gem inside a button or a booster slot is a price
			var p: Node = x.get_parent()
			while p and p != root:
				if p is JButton or str(p.name).begins_with("Boost_"):
					return true
				p = p.get_parent()
	return false


func _labels(root: Node) -> String:
	var all: = []
	_walk(root, all)
	var s: = ""
	for x in all:
		if x is Label:
			s += (x as Label).text + "\n"
	return s


func _ui() -> void:
	_sec = "ui"
	var sz: = Vector2(720, 1280)
	var m: = StubMain.new(sz)
	add_child(m)
	var S: = fresh()
	for i in 76:
		if not Gen.is_peak(i) or i < 40:
			State.on_win(i, 1 + i % 3)
	Boost.st().flame = 2
	var map = Control.new()
	map.set_script(PathMap)
	map.size = sz
	m.add_child(map)
	m.move_child(m.overlay, -1)
	map.build(m, {})
	await get_tree().process_frame
	var ms_cold: = float(map.get_meta("build_ms"))
	# second build (textures cached, as on every visit after the first): the spec's <40 ms
	map.queue_free()
	await get_tree().process_frame
	map = Control.new()
	map.set_script(PathMap)
	map.size = sz
	m.add_child(map)
	m.move_child(m.overlay, -1)
	map.build(m, {})
	await get_tree().process_frame
	var ms: = float(map.get_meta("build_ms"))
	print("PATH map build cold %.1f ms, warm %.1f ms" % [ms_cold, ms])
	print("PATH map build %.1f ms (headless), live chapters %d, nodes %d" % [ms, map.sections.size(), map.nodes.size()])
	check(map.sections.size() <= 5 and map.sections.size() >= 1, "virtualised: ≤5 chapters live (%d)" % map.sections.size())
	check(map.nodes.size() <= 50, "≤50 nodes live (%d)" % map.nodes.size())
	# the spec's <40 ms is for a rendered build with cached textures (the xvfb runner measures it: «PATH map build»
	# of the second build); the headless dummy renderer is several times slower, so it only gets a sanity bound
	var lim: = 40.0 if DisplayServer.get_name() != "headless" else 250.0
	check(ms < lim, "map builds in <%d ms warm (%.1f ms, %s)" % [int(lim), ms, DisplayServer.get_name()])
	check(map.nodes.has(State.current()), "current node is built")
	# scroll to the top and back: sections swap, nothing leaks
	map.scroll = 0.0
	map._apply_scroll()
	await get_tree().process_frame
	check(map.sections.has(9) and map.sections.size() <= 5, "scrolling builds the top chapters")
	map.scroll_to_level(State.current(), false)
	# ordinary card: three booster circles, free ones on
	var c: Control = Card.open(m, map, State.current())
	await get_tree().process_frame
	check(c != null and c.find_child("Boosters", true, false) != null, "card has the booster row")
	var nb: = 0
	for k in ["lantern", "wind", "scroll"]:
		if c.find_child("Boost_" + k, true, false):
			nb += 1
	check(nb == 3, "three booster circles")
	check(c.find_child("PlayBtn", true, false) != null, "card has «Играть»")
	var sheet: Control = c.find_child("Sheet", true, false)
	var pb: Control = c.find_child("PlayBtn", true, false)
	check(sheet != null and pb != null and sheet.size.y - (pb.position.y + pb.size.y) <= 40.0 and sheet.size.y + 18.0 <= sz.y, "«Играть» at the bottom edge of the bottom sheet")
	c.queue_free()
	# Peak card: honest, no gem price anywhere in the boosters
	var p: = -1
	for i in 100:
		if Gen.is_peak(i) and State.state_of(i) == "open":
			p = i
			break
	check(p >= 0, "an open Peak in the fixture")
	if p >= 0:
		var pc: Control = Card.open(m, map, p)
		await get_tree().process_frame
		check(not _has_gem_price(pc), "Peak card: no crystal price on boosters")
		check(pc.find_child("HonestHint", true, false) != null, "Peak card: «Здесь только честная игра»")
		check("не продаётся" in _labels(pc), "Peak card: «Здесь не продаётся ни один бустер»")
		pc.queue_free()
		# Peak fail window: only Retry / ToMap / ShowJam, no price
		var cfg: = State.play_cfg(p)
		var res: = State.on_fail(p)
		var jam: = Jam.find(cfg, Jam.demo_fail_log(cfg, 5))
		var fw: Control = Dlg.fail_window(m, p, res, jam, Callable(), Callable())
		await get_tree().process_frame
		var all: = []
		_walk(fw, all)
		var btns: = []
		for x in all:
			if x is JButton:
				btns.append(str(x.name))
		btns.sort()
		check(not _has_gem_price(fw), "Peak fail window: no crystal price")
		var allowed: = ["Retry", "ShowJam", "ToMap"]
		var extra: = btns.filter(func(b): return not (b in allowed))
		check(extra.is_empty(), "Peak fail window buttons: %s" % str(btns))
		check(fw.find_child("JamBlock", true, false) != null or jam.is_empty(), "jam block shown when found")
		fw.queue_free()
	# intro card on a new mechanic
	var intro_i: = 30
	State.st().seen_mech = []
	var ic: Control = Card.open(m, map, intro_i)
	await get_tree().process_frame
	check(ic.find_child("IntroBlock", true, false) != null, "new mechanic: hostess line + tiles")
	ic.queue_free()
	# daily label threshold in the card
	State.st().daily_full = {"day": State.day_key(), "n": 9}
	var d9: Control = Card.open(m, map, State.current())
	await get_tree().process_frame
	check(d9.find_child("DailyFull", true, false) == null, "9 wins: no daily label")
	d9.queue_free()
	State.st().daily_full = {"day": State.day_key(), "n": 10}
	var d10: Control = Card.open(m, map, State.current())
	await get_tree().process_frame
	check(d10.find_child("DailyFull", true, false) != null, "10 wins: «Полная награда сегодня: 10/15»")
	d10.queue_free()
	# arcs sheet: 10 covers, unreleased = silhouette, no timers
	var ar: Control = Dlg.arcs_sheet(m, map)
	await get_tree().process_frame
	var cards: = 0
	var txt: = _labels(ar)
	for k in Gen.WORLDS:
		if ar.find_child("Arc%d" % (k + 1), true, false):
			cards += 1
	check(cards == 10, "arcs sheet: 10 arcs")
	check(txt.count("Арка выходит с обновлением") == Gen.WORLDS - Rules.ARCS_RELEASED, "unreleased arcs say «выходит с обновлением»")
	var timer_re: = RegEx.create_from_string("\\d+\\s*(ч|мин|сек|дн)|\\d+:\\d\\d")
	check(timer_re.search(txt) == null, "no countdown in the arcs sheet")
	ar.queue_free()
	# assist dialog: hostess bust + two answers
	State.st().fails[str(State.current())] = 2
	var asd: Control = Dlg.assist(m, State.current(), Callable(), Callable())
	await get_tree().process_frame
	check(asd.find_child("HostBust", true, false) != null and asd.find_child("Yes", true, false) != null and asd.find_child("No", true, false) != null, "assist: bust, «Да, давай», «Нет, сам(а)»")
	check("переложу стол" in _labels(asd), "assist line")
	asd.queue_free()
	map.queue_free()
	m.queue_free()
	await get_tree().process_frame
