extends Node

# Selftest of the tower track (V10Mods, Пагода Луны, Странствие, tables, play adapter).
# Standalone runner scene (does not touch main.gd):
#   flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game res://scripts/v10/tower/tower_selftest.tscn -- --tower_selftest=1
# Flags (any of them; --tower_selftest=1 runs all but the matrix generation):
#   --mods_selftest=1      engine: heat, hooks, plus rules, hidden goddesses, matrix coverage, max heat
#   --tower_solve=1        every floor / board of seeded runs is solvable (model + the real TrayBoard deal)
#   --pagoda_selftest=1    migration, heat ×, miles once, weekly offering <= 60, restore, cosmetics, no paid help
#   --journey_selftest=1   week seeds, Monday 04:00 MSK, hearts, attempts at start, rewards once, budget
#   --tower_tables=1       weekly tables: monotonic AI, labels, size
#   --tower_rules=1        the play adapter on a live TrayBoard (ops applied, solvability kept)
#   --tower_bots=1         bot targets: Pagoda expert heat 0 floor >= 10 in >= 60%; Journey expert 5/5 >= 35%, casual 10–25%
#   --mods_matrix=1        recompute data/mods_matrix.json offline (expert bot on every pair of curse levels)
#   --bot_runs=N           runs per bot measurement (default 40)
# Output: "TOWER_SELFTEST ok/total" (+ per-module lines), exit code 0 when all pass.

const U: = preload("res://scripts/v10/tower/tower_util.gd")
const D: = preload("res://scripts/v10/tower/mods_data.gd")
const M: = preload("res://scripts/v10/tower/mods.gd")
const SIM: = preload("res://scripts/v10/tower/sim.gd")
const P: = preload("res://scripts/v10/tower/pagoda.gd")
const J: = preload("res://scripts/v10/tower/journey.gd")
const TB: = preload("res://scripts/v10/tower/tower_board.gd")
const TR: = preload("res://scripts/v10/tower/tower_rules.gd")

const FOUNDERS: = ["mc", "rin", "hana", "yue", "nova"]
# V10Lint.BANNED (spec §2.7) + the red lines of docs/HEROINES.md, for every text of this module
const BANNED: = ["скуча", "одна,", "обещал", "пропал", "забыл", "почему ты", "бросил", "вернись", "₽", "скидк", "успей",
	"последн", "только сегодня", "купи", "баннер", "акци", "цена", "школ", "учител", "ученик", "пересдач", "парта"]

var ok: = 0
var total: = 0
var mod_ok: = {}
var mod_total: = {}
var cur: = ""
var fails: = []
var args: = {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv: = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var all: bool = args.get("tower_selftest", "0") == "1"
	var t0: = Time.get_ticks_msec()
	P._test_S = {}
	J._test_S = {}
	TB._test_profile_id = "selftest"
	if args.get("mods_matrix", "0") == "1":
		await _make_matrix()
	if all or args.has("mods_selftest"):
		_mods()
	if all or args.has("tower_solve"):
		await _solve()
	if all or args.has("pagoda_selftest"):
		_pagoda()
	if all or args.has("journey_selftest"):
		_journey()
	if all or args.has("tower_tables"):
		_tables()
	if all or args.has("tower_rules"):
		await _rules()
	if all or args.has("tower_bots"):
		await _bots()
	if args.has("journey_sweep"):
		await _sweep()
	for m in mod_total:
		print("  %-8s %d/%d" % [m, int(mod_ok.get(m, 0)), int(mod_total[m])])
	for f in fails.slice(0, 40):
		print("  FAIL ", f)
	print("TOWER_SELFTEST %d/%d (%.1f s)" % [ok, total, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(0 if ok == total and total > 0 else 1)

func check(cond: bool, what: String) -> void:
	total += 1
	mod_total[cur] = int(mod_total.get(cur, 0)) + 1
	if cond:
		ok += 1
		mod_ok[cur] = int(mod_ok.get(cur, 0)) + 1
	else:
		fails.append("[%s] %s" % [cur, what])

func st(mode: String, curses: = {}, bless: = {}, owned: = ["mc"], released: = FOUNDERS) -> Dictionary:
	return {"mode": mode, "curses": curses, "forced": {}, "bless": bless, "owned": owned, "released": released, "lives": 3}

# ---------------------------------------------------------------- engine

func _mods() -> void:
	cur = "mods"
	check(M.heat_max() == 34, "heat max 34 (got %d)" % M.heat_max())
	check(M.heat({"shroud": 2, "hourglass": 1, "narrow": 1}) == 4 + 2 + 3, "heat is the sum of the chosen levels")
	check(absf(M.mult(12) - 2.2) < 0.001 and P.heat_text(12) == "Жар 12 · очки ×2,2", "heat 12 -> ×2,2: " + P.heat_text(12))
	var base: = M.resolve(st("pagoda"))
	check(int(base.slots) == 4 and int(base.lives) == 3 and int(base.heat) == 0, "base rules")
	# every curse level changes what it promises
	var promise: = {"shroud": "shroud", "hourglass": "time_per_tile", "greedy": "greedy", "narrow": "slots", "one_lamp": "lives",
		"no_ult": "ult_off", "no_undo": "undo_off", "no_hint": "hint_off", "no_shuffle": "shuffle_off", "fog": "fog", "guards": "guards"}
	for id in D.CURSE_ORDER:
		for lvl in range(1, (D.CURSES[id].levels as Array).size() + 1):
			var r: = M.resolve(st("pagoda", {id: lvl}))
			var k: String = promise[id]
			check(str(r[k]) != str(base[k]), "curse %s:%d changes %s" % [id, lvl, k])
			check(int(r.heat) == M.curse_heat(id, lvl), "curse %s:%d heat" % [id, lvl])
	check(int(M.resolve(st("pagoda", {"narrow": 1})).slots) == 3, "narrow -> 3 slots")
	check(int(M.resolve(st("pagoda", {"one_lamp": 1})).lives) == 1 and int(M.resolve(st("pagoda", {"one_lamp": 1})).lives_max) == 1, "one lamp")
	# every blessing changes the rules (or the run lives)
	for id in D.BLESS_ORDER:
		var s: = st("pagoda", {}, {}, [], U.ROSTER)
		s.lives = 2
		var before: = M.resolve(s)
		M.take_blessing(s, id)
		var after: = M.resolve(s)
		check(str(after) != str(before) or int(s.lives) != 2, "blessing %s changes the rules" % id)
	# plus: only own goddess and only in personal modes
	check(M.bless_plus("lamp", st("pagoda", {}, {}, ["mc"])), "plus: own goddess in the Pagoda")
	check(not M.bless_plus("cup", st("pagoda", {}, {}, ["mc"])), "no plus: not owned")
	check(not M.bless_plus("lamp", st("journey", {}, {}, ["mc"])), "no plus in the Journey (normalized)")
	check(int(M.resolve(st("pagoda", {}, {"tips": 1}, ["mc"])).hint) == 3 and int(M.resolve(st("pagoda", {}, {"tips": 1}, ["rin"])).hint) == 2, "plus effect is stronger")
	check(bool(M.resolve(st("journey")).normalized) and not bool(M.resolve(st("pagoda")).normalized), "journey normalized flag")
	# goddesses not in the build are hidden
	var hidden_seen: = false
	var new_seen: = false
	for sd in 200:
		var r: = U.rng(sd, "t")
		for id in M.offer_blessings(st("pagoda", {}, {}, ["mc"], FOUNDERS), r):
			if not String(D.BLESS[id].hero) in FOUNDERS:
				hidden_seen = true
		for id in M.offer_blessings(st("pagoda", {}, {}, ["mc"], U.ROSTER), U.rng(sd, "t")):
			if not String(D.BLESS[id].hero) in FOUNDERS:
				new_seen = true
	check(not hidden_seen, "blessings of unreleased goddesses never offered")
	check(new_seen, "blessings of released new goddesses are offered")
	var o1: = M.offer_blessings(st("pagoda"), U.rng(5, "x"))
	var o2: = M.offer_blessings(st("pagoda"), U.rng(5, "x"))
	check(o1 == o2 and o1.size() == 3, "offer is seeded and 1 of 3")
	# with own goddess in the Pagoda one card is hers
	var own_ok: = true
	for sd in 50:
		var o: = M.offer_blessings(st("pagoda", {}, {}, ["nova"]), U.rng(sd, "own"))
		if o.filter(func(i): return String(D.BLESS[i].hero) == "nova").is_empty():
			own_ok = false
	check(own_ok, "pagoda offer always has one card of the own goddess")
	# hooks
	var ops: = M.on_start(M.resolve(st("pagoda", {"shroud": 2, "fog": 1}, {"warmup": 1, "lasso": 1, "mirage": 1, "foxluck": 1, "overclock": 1}, [], U.ROSTER)),
		{"seed": 3}, SIM.deal(_cfg(5, 6, 3, 12, 11)).describe())
	var kinds: = ops.map(func(o): return String(o.op))
	for k in ["auto_pairs", "open", "shroud", "fog", "peek", "hint", "ult_charge"]:
		check(k in kinds, "on_start emits %s" % k)
	var rp: = M.resolve(st("pagoda", {"fog": 1}, {"sugar": 1, "thunder": 1}, [], U.ROSTER))
	check(M.on_pair(rp, 4).map(func(o): return o.op).has("ult_charge"), "on_pair: every 4th pair charges the ult")
	check(M.on_pair(rp, 12).map(func(o): return o.op).has("auto_pairs"), "on_pair: every 12th pair takes one more")
	check(M.on_pair(rp, 6).map(func(o): return o.op).has("fog_lift"), "on_pair: fog lifts after 6 pairs")
	check(not M.on_pair(M.resolve(st("pagoda", {"no_ult": 1}, {"sugar": 1}, [], U.ROSTER)), 4).map(func(o): return o.op).has("ult_charge"), "no_ult blocks charges")
	var fl: = {}
	var rs: = M.resolve(st("pagoda", {}, {"smoke": 1}, [], U.ROSTER))
	check(not M.on_overflow(rs, fl).lose_life and M.on_overflow(rs, fl).lose_life, "shield forgives one overflow per floor")
	check(int(M.on_overflow(M.resolve(st("pagoda", {}, {"onsen": 1}, [], U.ROSTER)), {}).return_n) == 99, "onsen returns the whole tray")
	check(M.floor_time(M.resolve(st("pagoda", {"hourglass": 2})), 60) == 120, "hourglass II: 2 s per tile")
	check(M.floor_time(M.resolve(st("pagoda", {"hourglass": 2}, {"river": 1}, [], U.ROSTER)), 60) == 140, "river adds 20 s")
	check(M.floor_time(base, 60) == 0, "no clock without the hourglass")
	var hp: = M.helps(M.resolve(st("pagoda", {"no_hint": 1}, {"tips": 1})), {"hint": 1, "undo": 1})
	check(int(hp.hint) == 0 and int(hp.undo) == 1, "a curse turns a help off even with blessings")
	# cfg hook
	var c0: = _cfg(5, 6, 3, 10, 21)
	var cg: = M.on_cfg(c0, M.resolve(st("pagoda", {"greedy": 3})))
	check(int(cg.faces) > int(c0.faces) and float(cg.fill) > float(c0.fill), "greedy: more kinds, fuller table")
	var ice0: = _count(SIM.deal(c0).ice)
	var ice8: = _count(SIM.deal(M.on_cfg(c0, M.resolve(st("pagoda", {"guards": 2})))).ice)
	check(ice8 >= ice0 + 7 and ice8 <= ice0 + 9, "guards II: 8 more ice (%d -> %d)" % [ice0, ice8])
	check(bool(M.on_cfg(c0, M.resolve(st("pagoda", {"shroud": 1}))).hidden), "shroud I: cfg.hidden")
	check(not bool(M.on_cfg(c0.merged({"hidden": true}, true), M.resolve(st("pagoda", {}, {"clear": 1}))).hidden), "clear: no secret tiles")
	# matrix
	var mx: = M.matrix()
	check(int(mx.get("version", 0)) >= 1, "mods_matrix.json loaded")
	var keys: = []
	for id in D.CURSE_ORDER:
		for lvl in range(1, (D.CURSES[id].levels as Array).size() + 1):
			keys.append("%s:%d" % [id, lvl])
	var missing: = 0
	var rates: Dictionary = mx.get("rates", {})
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			if String(keys[i]).split(":")[0] == String(keys[j]).split(":")[0]:
				continue
			if not rates.has("%s|%s" % [keys[i], keys[j]]):
				missing += 1
	check(missing == 0, "matrix covers every pair of curse levels (missing %d)" % missing)
	var mh: = M.max_valid_heat()
	check(mh >= 32, "heat 32 reachable under the matrix (max %d)" % mh)
	for pr in mx.get("forbid", []):
		var c: = {}
		c[String(pr[0]).split(":")[0]] = int(String(pr[0]).split(":")[1])
		c[String(pr[1]).split(":")[0]] = int(String(pr[1]).split(":")[1])
		check(not M.validate(c).ok and M.validate(c).reason == D.SAFE_TEXT, "forbidden pair is grey: %s" % str(pr))
	check(M.validate({}).ok and not M.validate({"narrow": 2}).ok, "validate: levels in range")
	# a forbidden pair covers the higher levels too and turns the card grey
	var real_mx: = M.matrix()
	M.set_matrix({"version": 9, "forbid": [["narrow:1", "fog:1"]]})
	check(not M.validate({"narrow": 1, "fog": 2}).ok and M.validate({"narrow": 1, "shroud": 2}).ok, "forbidden pair extends upward only")
	check(not M.can_set({"fog": 1}, "narrow", 1) and M.can_set({"fog": 1}, "narrow", 0), "can_set: grey card for a forbidden pick")
	check(M.max_valid_heat() == 34 - 3, "max heat search respects the matrix (%d)" % M.max_valid_heat())
	M.set_matrix(real_mx)
	# texts
	cur = "texts"
	var texts: = []
	for id in D.BLESS:
		texts.append_array([D.BLESS[id].name, D.BLESS[id].desc, D.BLESS[id].plus])
	for id in D.CURSES:
		texts.append(D.CURSES[id].name)
		for L in D.CURSES[id].levels:
			texts.append(L.desc)
	for th in J.THEMES:
		texts.append_array([th.name, th.line])
	for h in J.BOSS:
		texts.append_array([J.BOSS[h].name, J.BOSS[h].line])
	for c in P.COS:
		texts.append(c.name)
	var bad: = []
	var re: = RegEx.create_from_string("\\d\\s*%")
	for t in texts:
		var low: = String(t).to_lower()
		for w in BANNED:
			if w in low:
				bad.append("%s ~ %s" % [t, w])
		if re.search(String(t)):
			bad.append("%s ~ digits with %%" % t)
	check(bad.is_empty(), "texts clean: %s" % str(bad))

func _count(a) -> int:
	var n: = 0
	for x in a:
		n += int(x)
	return n

func _cfg(cols: int, rows: int, layers: int, faces: int, sd: int, shape: = "rect") -> Dictionary:
	return {"shape": shape, "cols": cols, "rows": rows, "layers": layers, "fill": 0.7, "faces": faces, "seed": sd, "gold": 2, "ice": 0, "hidden": false}

# ---------------------------------------------------------------- solvability

func _sets() -> Array:
	var mh: = _max_set()
	return [
		{"name": "heat0", "curses": {}, "bless": {}},
		{"name": "mid", "curses": {"shroud": 1, "greedy": 2, "guards": 1, "fog": 1}, "bless": {"warmup": 1, "lasso": 1}},
		{"name": "max", "curses": mh, "bless": {"cup": 1, "clear": 0}},
		{"name": "bless", "curses": {"greedy": 3, "guards": 2}, "bless": {"warmup": 2, "lasso": 1, "pearl": 1, "thunder": 1}},
	]

func _max_set() -> Dictionary:
	# the greedy top: every curse at its top level that the matrix still allows
	var c: = {}
	for id in D.CURSE_ORDER:
		for lvl in range((D.CURSES[id].levels as Array).size(), 0, -1):
			var c2: = c.duplicate()
			c2[id] = lvl
			if M.validate(c2).ok:
				c = c2
				break
	return c

func _solve() -> void:
	cur = "solve"
	var bad: = []
	var n: = 0
	for s in _sets():
		for sd in [11, 222, 3333]:
			var run: = {"mode": "pagoda", "floor": 1, "lives": 3, "partner": "mc", "seed": sd, "curses": s.curses, "forced": {},
				"bless": s.bless, "owned": ["mc"], "released": U.ROSTER, "offer": []}
			for f in range(1, 61):
				run.floor = f
				var cfg: = P.floor_cfg(run)
				var b: = SIM.deal(cfg)
				n += 1
				if not SIM.step_order_ok(b):
					bad.append("pagoda %s seed %d floor %d" % [s.name, sd, f])
					continue
				# the start ops (pairs taken, tiles opened) keep the step order
				var rules: = M.resolve(run)
				for op in M.on_start(rules, cfg, b.describe()):
					if op.op == "auto_pairs":
						for k in int(op.n):
							SIM._auto_pair(b)
					elif op.op == "open":
						for i in op.tiles:
							b.opened[int(i)] = 1
				if not SIM.step_order_ok(b):
					bad.append("pagoda %s seed %d floor %d after start ops" % [s.name, sd, f])
	check(bad.is_empty(), "%d pagoda floors solvable in step order: %s" % [n, str(bad.slice(0, 5))])
	var badj: = []
	for w in range(2900, 2916):
		for b in J.BOARDS:
			var run: = {"mode": "journey", "week": w, "board": b, "hearts": 3, "bless": {}, "curses": {"greedy": 1, "guards": 1}, "extra_eff": [J.theme(w).eff], "released": FOUNDERS, "owned": ["mc"]}
			var c: = J.board_cfg(run)
			if not SIM.step_order_ok(SIM.deal(c)):
				badj.append("journey w%d b%d" % [w, b])
	check(badj.is_empty(), "journey boards of 16 weeks solvable: %s" % str(badj))
	# the real TrayBoard deal: same layout, same free rule, step order clears it
	var mism: = []
	var real: = 0
	var cfgs: = []
	for f in range(1, 31):
		for s in [_sets()[0], _sets()[1]]:
			cfgs.append(P.floor_cfg({"mode": "pagoda", "floor": f, "lives": 3, "partner": "mc", "seed": 77 + f, "curses": s.curses, "forced": {}, "bless": s.bless, "owned": ["mc"], "released": FOUNDERS}))
	for w in [2900, 2903]:
		for b in J.BOARDS:
			cfgs.append(J.board_cfg_for(w, b, {}))
	for f in cfgs.size():
		if true:
			var cfg: Dictionary = cfgs[f]
			var tb: = TrayBoard.new()
			add_child(tb)
			seed(int(cfg.seed))
			tb.setup(cfg)
			randomize()
			var sb: = SIM.from_tray(tb, cfg)
			real += 1
			if sb == null:
				mism.append("layout f%d" % f)
			else:
				var same_free: = true
				for i in tb.tiles.size():
					var t: Tile = tb.tiles[i]
					var j: = sb.pos.find(Vector3i(t.gx, t.gy, t.gz))
					if tb.is_free(t) != sb.free_i(j):
						same_free = false
				if not same_free:
					mism.append("free rule f%d" % f)
				if not SIM.step_order_ok(sb):
					mism.append("real deal not solvable f%d" % f)
			tb.queue_free()
		if f % 10 == 0:
			await get_tree().process_frame
	check(mism.is_empty(), "%d real TrayBoard deals: same layout, same free rule, solvable: %s" % [real, str(mism.slice(0, 5))])
	# determinism of the seeded deal
	var c1: = P.floor_cfg({"mode": "pagoda", "floor": 7, "lives": 3, "partner": "mc", "seed": 5, "curses": {"greedy": 2}, "forced": {}, "bless": {}, "owned": [], "released": FOUNDERS})
	var d1: = SIM.deal(c1)
	var d2: = SIM.deal(c1)
	check(d1.face == d2.face and d1.step == d2.step, "seeded deal is deterministic")

# ---------------------------------------------------------------- Pagoda

func _pagoda() -> void:
	cur = "pagoda"
	U.fake_now = U.week_start(2900) + 3600 * 30
	P._test_S = {"v6_modes": {"climb_best": 12, "climb_miles": [5, 10], "climb_runs": 4}, "rp": 0}
	var d: = P.st()
	check(int(d.best.get("0", 0)) == 12, "migration: climb_best -> heat 0 record")
	check(5 in d.miles and 10 in d.miles and not 15 in d.miles, "migration: old miles counted, no new ones")
	check(int(d.best_score) == P.floor_score(12, 0), "migration: best score on the ×100 scale (%d)" % int(d.best_score))
	var snap: = JSON.stringify(d)
	P.st()
	check(JSON.stringify(P.st()) == snap, "migration is idempotent")
	check(P.is_open(), "a 0.9 climber keeps the Pagoda open")
	P._test_S = {"rp": 0}
	check(not P.is_open(), "closed below Золото I")
	P._test_S = {"rp": 0, "v10_peak_first": true}
	check(P.is_open(), "open after the first Пик")
	# a run: miles once, offering <= 60, chest, forced curse, lamps
	P._test_S = {"rp": 0}
	var run: = P.new_run("mc", {"shroud": 1, "greedy": 2, "no_hint": 1, "guards": 1}, 1234)
	run["owned"] = ["mc"]
	run["released"] = FOUNDERS
	check(P.heat_chosen(run) == 2 + 2 + 1 + 2, "chosen heat")
	check(P.has_run() and P.current_run() == run, "the run is stored in the save")
	var gems: = 0
	var petals: = 0
	var coins: = 0
	var forced_seen: = []
	for f in range(1, 21):
		var res: = P.floor_clear(run, {"secs": 60})
		gems += int(res.reward.get("gems", 0))
		petals += int(res.reward.get("petals", 0))
		coins += int(res.reward.get("coins", 0))
		if not res.forced.is_empty():
			forced_seen.append(res.forced)
		if not run.offer.is_empty():
			P.pick_blessing(run, run.offer[0])
	check(gems == 50 + 75 + 100 + 125 + 60, "miles 5..20 + offering 60 (got %d)" % gems)
	check(petals == 5, "guard petals once per run")
	check(coins == (20 + 25) + (20 + 50) + (20 + 75) + (20 + 100), "guard coins 20 + 5 × floor")
	check(forced_seen.size() == 2, "a forced curse on floors 10 and 20 (%d)" % forced_seen.size())
	check(M.heat(M.all_curses(run)) > P.heat_chosen(run), "forced curses heat up the tower, not the chosen heat")
	# JSON round trip of the save (resume after leaving between floors)
	var saved = JSON.parse_string(JSON.stringify(P._test_S))
	var run2: Dictionary = saved.v10_pagoda.run
	run2["owned"] = ["mc"]
	run2["released"] = FOUNDERS
	var c_a: = P.floor_cfg(run)
	var c_b: = P.floor_cfg(run2)
	check(int(c_a.seed) == int(c_b.seed) and int(c_a.faces) == int(c_b.faces) and str(M.resolve(run)) == str(M.resolve(run2)), "run restored from the save gives the same floor")
	var end: = P.end_run(run)
	check(int(end.floors) == 20 and int(end.score) == int(round(20 * M.mult(7) * 100)), "score = floors × (1 + 0.1 × heat) (×100)")
	check(not P.has_run(), "the run is cleared at the end")
	# second run: no miles again, offering already paid this week
	var run3: = P.new_run("mc", {}, 99)
	run3["owned"] = []
	run3["released"] = FOUNDERS
	var g2: = 0
	for f in range(1, 21):
		g2 += int(P.floor_clear(run3, {}).reward.get("gems", 0))
	check(g2 == 0, "miles once, offering <= 60 a week (second run paid %d)" % g2)
	U.fake_now = U.week_start(2901) + 7200
	var run4: = P.new_run("mc", {}, 98)
	run4["owned"] = []
	run4["released"] = FOUNDERS
	var g3: = 0
	for f in range(1, 21):
		g3 += int(P.floor_clear(run4, {}).reward.get("gems", 0))
	check(g3 == 60, "a new week pays the offering again (%d)" % g3)
	# cosmetics: both conditions
	for case in [[{"shroud": 2, "hourglass": 2}, 9, false], [{"shroud": 2, "greedy": 2}, 10, false], [{"shroud": 2, "hourglass": 2}, 10, true]]:
		P._test_S = {"rp": 0}
		var r: = P.new_run("mc", case[0], 7)
		r["owned"] = []
		r["released"] = FOUNDERS
		for f in int(case[1]):
			P.floor_clear(r, {})
		check(("frame_moon_heat" in P.st().cos) == bool(case[2]), "cosmetic «Лунный жар» heat %d floor %d -> %s" % [M.heat(case[0]), case[1], case[2]])
	check(P.COS.size() == 3 and int(P.COS[2].heat) == 32, "three heat cosmetics, the top at 32")
	# lives
	P._test_S = {"rp": 0}
	var rl: = P.new_run("mc", {}, 5)
	rl["owned"] = []
	rl["released"] = FOUNDERS
	var fl: = {}
	P.on_overflow(rl, fl)
	check(int(rl.lives) == 2, "an overflow puts out a lantern")
	rl.floor = 5
	P.floor_clear(rl, {})
	check(int(rl.lives) == 3, "the guard chest gives a lantern back")
	var r1: = P.new_run("mc", {"one_lamp": 1}, 5)
	check(int(r1.lives) == 1 and bool(P.on_overflow(r1, {}).run_over), "one lamp: the first overflow ends the run")
	check(P.new_run("mc", {"narrow": 2}).has("error"), "an invalid scroll is refused")
	# no paid help
	check(not P.PAID_HELP and not J.PAID_HELP, "no paid help flags")
	var srcs: = ""
	for p in ["pagoda.gd", "journey.gd", "tower_rules.gd", "mods.gd"]:
		srcs += FileAccess.get_file_as_string("res://scripts/v10/tower/" + p)
	check(not ("_v8_pay" in srcs or "gems -=" in srcs or "\"price\"" in srcs or "continue_paid" in srcs), "no paid help in the code")
	U.fake_now = 0

# ---------------------------------------------------------------- Journey

func _journey() -> void:
	cur = "journey"
	# Monday 04:00 MSK = Monday 01:00 UTC
	var w: = 2900
	var t_edge: = U.week_start(w)
	check(U.week_id(t_edge - 1) == w - 1 and U.week_id(t_edge) == w, "the week turns on Monday 04:00 MSK")
	var dd: = Time.get_datetime_dict_from_unix_time(t_edge + U.MSK_OFFSET)
	check(int(dd.weekday) == 1 and int(dd.hour) == 4 and int(dd.minute) == 0, "week start is Monday 04:00 MSK (%s)" % str(dd))
	check(U.week_refresh_text(w).ends_with("04:00 МСК") and U.week_refresh_text(w).begins_with("пн"), "refresh text: " + U.week_refresh_text(w))
	check(not U.show_countdown(w, t_edge + 3600) and U.show_countdown(w, U.week_end(w) - 3600), "countdown only in the last 48 h")
	# one week = one set of tables, for every attempt
	var a: = J.board_cfg_for(w, 2, {})
	var b: = J.board_cfg_for(w, 2, {})
	var c: = J.board_cfg_for(w + 1, 2, {})
	check(int(a.seed) == int(b.seed) and str(a.shape) == str(b.shape), "same week, same tables")
	check(int(a.seed) != int(c.seed), "next week, new tables")
	U.fake_now = t_edge + 5000
	J._test_S = {"rp": 0}
	var info: = J.week_info()
	check(int(info.attempts_left) == 2 and String(info.afisha).begins_with("Странствие · Неделя") and "МСК" in String(info.afisha), "afisha line: " + String(info.afisha))
	var r1: = J.start("mc")
	r1["released"] = FOUNDERS
	r1["owned"] = ["mc"]
	check(J.attempts_left() == 1, "the attempt is spent at the start")
	var cfg1: = J.board_cfg(r1)
	J.st().run = {}
	var r2: = J.start("mc")
	r2["released"] = FOUNDERS
	r2["owned"] = ["mc"]
	check(J.attempts_left() == 0 and J.start("mc").has("error"), "two attempts a week, leaving does not refund")
	check(int(J.board_cfg(r2).seed) == int(cfg1.seed), "both attempts play the same first table")
	var pr: = J.start("mc", true)
	check(not pr.has("error") and bool(pr.practice), "practice is always open")
	check(J.current_run() == r2 and not bool(J.current_run().practice), "practice never replaces the saved attempt")
	J.finish(pr)
	check(J.current_run() == r2, "finishing practice keeps the saved attempt")
	check(bool(J.board_rules(r2).normalized) and not M.bless_plus("lamp", r2), "journey is normalized: no plus")
	# hearts: overflow = −1 heart and the same table
	var fl: = {}
	var o1: = J.on_overflow(r2, fl)
	check(int(r2.hearts) == 2 and bool(o1.restart) and int(r2.board) == 0, "overflow: −1 heart, same table")
	J.on_overflow(r2, {})
	var o3: = J.on_overflow(r2, {})
	check(bool(o3.run_over) and not bool(o3.restart), "three hearts lost: the run is over")
	# boss board: two tricks
	var rb: = {"mode": "journey", "week": w, "board": 4, "hearts": 3, "bless": {}, "curses": {}, "extra_eff": [], "released": FOUNDERS}
	var tr: = []
	for p in range(1, 41):
		tr.append_array(J.boss_tricks(rb, p, 40))
	check(tr.size() == 2, "the boss plays her trick twice (%d)" % tr.size())
	check(J.boss_tricks({"board": 2, "week": w}, 30, 40).is_empty(), "no tricks before the boss")
	check(J.board_cfg_for(w, 4, {}).has("boss_trick"), "boss board carries the trick")
	# rewards: best attempt, once per week
	J._test_S = {"rp": 0}
	var ra: = J.start("mc")
	ra["released"] = FOUNDERS
	ra["owned"] = ["mc"]
	for k in 3:
		J.board_clear(ra, {"secs": 100, "max_combo": 5})
	J.on_overflow(ra, {})
	J.on_overflow(ra, {})
	J.on_overflow(ra, {})
	var f1: = J.finish(ra)
	check(int(f1.boards) == 3 and int(f1.reward.get("gems", 0)) == 60 + (20 if int(f1.tier) == 0 else 0), "3 boards pay 60 (+ tier): %s" % str(f1))
	var rb2: = J.start("mc")
	rb2["released"] = FOUNDERS
	rb2["owned"] = ["mc"]
	var took_curse: = false
	for k in 5:
		var res: = J.board_clear(rb2, {"secs": 80, "max_combo": 12})
		if not res.done:
			if not rb2.offer.is_empty():
				J.pick_blessing(rb2, rb2.offer[0])
			if not rb2.curse_offer.is_empty() and k < 3:
				took_curse = J.take_curse(rb2, rb2.curse_offer[0]) or took_curse
	check(took_curse and float(J.curse_mult(rb2)) > 1.0, "optional curse: +15% score")
	var f2: = J.finish(rb2)
	var owed: = J.rewards_for(5, int(f2.score))
	check(int(f2.reward.get("tickets", 0)) == 1 and int(f2.reward.get("petals", 0)) == 15 and int(f2.reward.get("pass_xp", 0)) == 100, "5/5: ticket, 15 petals, 100 XP")
	check(int(f2.reward.get("gems", 0)) == int(owed.get("gems", 0)) - int(f1.reward.get("gems", 0)), "a better attempt pays only the difference")
	var claimed: Dictionary = J.st().claimed.duplicate()
	J.st().attempts = 0
	var rc: = J.start("mc")
	rc["released"] = FOUNDERS
	for k in 5:
		J.board_clear(rc, {"secs": 80, "max_combo": 12})
	var f3: = J.finish(rc)
	check(f3.reward.is_empty() and J.st().claimed == claimed, "rewards once per week_id")
	var pr2: = J.start("mc", true)
	for k in 5:
		J.board_clear(pr2, {"secs": 10, "max_combo": 15})
	check(J.finish(pr2).reward.is_empty(), "practice pays nothing")
	U.fake_now = U.week_start(w + 1) + 10
	check(J.attempts_left() == 2 and J.st().claimed.is_empty(), "a new week: attempts and claims start over")
	var bud: = J.week_budget()
	check(int(bud.gems) <= 160 and int(bud.tickets) == 1, "week budget <= 160 gems + 1 ticket (%s)" % str(bud))
	check(J.tier_of(3999) == -1 and J.tier_of(4000) == 0 and J.tier_of(7000) == 1 and J.tier_of(10000) == 2, "tiers 4000 / 7000 / 10000")
	U.fake_now = 0

# ---------------------------------------------------------------- tables

func _tables() -> void:
	cur = "tables"
	var w: = 2900
	var t1: = U.week_start(w) + 86400
	var t2: = U.week_start(w) + 86400 * 4
	var t3: = U.week_end(w) - 60
	var mono: = true
	var grew: = 0
	for id in TB.group_ids(w, 2):
		var a: = int(TB.ai_week(id, w, t1).floors)
		var b: = int(TB.ai_week(id, w, t2).floors)
		var c: = int(TB.ai_week(id, w, t3).floors)
		if b < a or c < b:
			mono = false
		if c > a:
			grew += 1
	check(mono, "AI weekly results never go down")
	check(grew > 5, "the table moves during the week (%d grew)" % grew)
	check(TB.group_ids(w, 2) == TB.group_ids(w, 2) and TB.group_ids(w, 2).size() == 29, "group fixed for the week, 29 + me")
	var rows: = TB.pagoda_week(t3, {"pid": -1, "name": "Ты", "score": 1500, "floors": 10, "heat": 5, "me": true, "ai_label": ""})
	check(rows.filter(func(r): return r.me).size() == 1 and rows.size() <= 30, "my row is in the table")
	check(rows.all(func(r): return String(r.ai_label) == ""), "population rows carry no label (owner decision, SIM_LABEL=false)")
	var hr: = TB.heroine_records(t3, true)
	check(hr.size() == 20 and hr.all(func(r): return String(r.ai_label) == TB.HEROINE_LABEL), "20 goddess records, labelled «соперницы-героини (ИИ)»")
	check(TB.heroine_records(t3).size() == U.released().size(), "only released goddesses are shown")
	var jr: = TB.journey_week(w, 8000, t3)
	check(jr.filter(func(r): return not r.me).all(func(r): return String(r.ai_label) == TB.HEROINE_LABEL), "journey table: goddesses labelled")
	check(jr.filter(func(r): return r.me).size() == 1, "journey table has my row")

# ---------------------------------------------------------------- play adapter on a live board

class FakePlay extends Node:
	var board: TrayBoard
	var partner: = "mc"
	var hint_n: = 2
	var undo_n: = 2
	var shuffle_n: = 1
	var gold_mult: = 5
	var skill_charge: = 0
	var SKILL_NEED: = 8
	var ready_calls: = 0
	func _skill_ready() -> void:
		ready_calls += 1

func _rules() -> void:
	cur = "rules"
	P._test_S = {"rp": 0}
	var run: = P.new_run("mc", {"shroud": 2, "fog": 2, "no_hint": 1}, 4242)
	run["owned"] = ["mc", "nova"]
	run["released"] = U.ROSTER
	run.bless = {"warmup": 1, "lasso": 1, "overclock": 1, "sugar": 1}
	run.floor = 6
	var x = TR.for_run(run)
	var cfg: Dictionary = x.hook_cfg()
	var play: = FakePlay.new()
	add_child(play)
	var tb: = V6SpecialBoard.new()
	play.board = tb
	play.add_child(tb)
	tb.slots = x.slot_count(4)
	seed(int(cfg.seed))
	tb.setup(cfg)
	randomize()
	var n0: = tb.tiles.size()
	var ops: Array = x.hook_start(play)
	check(play.hint_n == 0 and play.undo_n >= 1, "helps set from the run (no_hint curse)")
	check(play.skill_charge >= 8 and play.ready_calls >= 1, "overclock plus: ult ready at the start")
	check(x.veils.size() > 0, "fog veils placed (%d)" % x.veils.size())
	var secret_nonfree: = tb.tiles.filter(func(t): return not tb.is_free(t) and t.secret).size()
	check(secret_nonfree > 0, "shroud II: tiles face down")
	check(tb.opened.size() >= 1, "lasso opened a covered tile")
	await get_tree().create_timer(0.8).timeout
	check(tb.tiles.filter(func(t): return t.alive).size() == n0 - 2, "warmup took one pair (%d -> %d)" % [n0, tb.tiles.filter(func(t): return t.alive).size()])
	# still solvable after the start ops: clear in step order on the real board
	var by: = {}
	for t in tb.tiles:
		if t.alive:
			by[t.step] = by.get(t.step, []) + [t]
	var ks: = by.keys()
	ks.sort()
	var okk: = true
	for k in ks:
		var g: Array = by[k]
		var a: Tile = g[0]
		var c: Tile = g[1] if g.size() > 1 else g[0]
		if not tb.is_free(a):
			a = c
			c = g[0]
		if not tb.is_free(a):
			okk = false
		a.alive = false
		if not tb.is_free(c):
			okk = false
		c.alive = false
	check(okk, "the live table still clears in step order after the start ops")
	for p in 10:
		x.hook_pair(play)
	check(x.veils.is_empty(), "fog II lifts after 10 pairs")
	check(not x.help_ok("hint") and x.help_ok("undo") and not x.paid_help(), "help gates")
	# hourglass
	var rh: = P.new_run("mc", {"hourglass": 3}, 1)
	rh["released"] = FOUNDERS
	rh["owned"] = []
	var xh = TR.for_run(rh)
	xh.hook_cfg()
	var play2: = FakePlay.new()
	add_child(play2)
	var tb2: = TrayBoard.new()
	play2.board = tb2
	play2.add_child(tb2)
	tb2.setup(xh.cfg)
	xh.hook_start(play2)
	check(int(xh.clock_full) == int(ceil(tb2.tiles.size() * 1.5)), "hourglass III: 1.5 s per tile")
	var fired: = ""
	for i in 400:
		var e: String = xh.tick(1.0)
		if e != "":
			fired = e
			break
	check(fired == "timeout" and int(xh.on_timeout().lives) == 2 and xh.clock > 0.0, "time out: a lantern, the clock refills")
	# journey adapter: overflow restarts
	J._test_S = {"rp": 0}
	U.fake_now = U.week_start(2900) + 100
	var rj: = J.start("mc")
	rj["released"] = FOUNDERS
	var xj = TR.for_run(rj)
	var cj: Dictionary = xj.hook_cfg()
	check(bool(cj.normalized) and bool(cj.seed_locked), "journey cfg normalized and seed-locked")
	check(bool(xj.hook_overflow(play).restart), "journey overflow restarts the table")
	U.fake_now = 0
	await get_tree().create_timer(1.0).timeout
	play.queue_free()
	play2.queue_free()

# ---------------------------------------------------------------- bots

func _bot_bless(run: Dictionary) -> void:
	if run.offer.is_empty():
		return
	for pref in ["cup", "smoke", "onsen", "lamp", "feather", "warmup", "clear", "pearl", "lasso", "thunder", "trail", "river"]:
		if pref in run.offer:
			if run.mode == "pagoda":
				P.pick_blessing(run, pref)
			else:
				J.pick_blessing(run, pref)
			return
	if run.mode == "pagoda":
		P.pick_blessing(run, run.offer[0])
	else:
		J.pick_blessing(run, run.offer[0])

func pagoda_bot(skill: String, curses: Dictionary, sd: int, cap: = 15) -> int:
	P._test_S = {"rp": 0}
	var run: = P.new_run("mc", curses, sd)
	run["owned"] = ["mc"]
	run["released"] = FOUNDERS
	var r: = U.rng(sd, "bot")
	while int(run.floor) <= cap:
		var cfg: = P.floor_cfg(run)
		var b: = SIM.deal(cfg)
		var res: = SIM.play(b, M.resolve(run), skill, r, {"lives": int(run.lives)})
		run.lives = int(res.lives)
		if not res.cleared:
			break
		P.floor_clear(run, res)
		_bot_bless(run)
	return int(run.get("cleared", 0))

func journey_bot(skill: String, w: int, sd: int) -> Dictionary:
	J._test_S = {"rp": 0}
	U.fake_now = U.week_start(w) + 100
	var run: = J.start("mc", true)
	run["released"] = FOUNDERS
	run["owned"] = ["mc"]
	var r: = U.rng(sd, "jbot")
	var guard: = 0
	while int(run.board) < J.BOARDS and int(run.hearts) > 0 and guard < 30:
		guard += 1
		var cfg: = J.board_cfg(run)
		var b: = SIM.deal(cfg)
		var rules: = J.board_rules(run)
		var res: = SIM.play(b, rules, skill, r, {"lives": int(run.hearts), "stop_on_overflow": true})
		if res.cleared:
			J.board_clear(run, res)
			_bot_bless(run)
		else:
			run.hearts = int(run.hearts) - 1
	U.fake_now = 0
	return {"boards": int(run.board), "score": J.total(run)}

func _bots() -> void:
	cur = "bots"
	var n: = int(args.get("bot_runs", "100"))
	var t0: = Time.get_ticks_msec()
	var hit: = 0
	var floors: = []
	for i in n:
		var f: = pagoda_bot("expert", {}, 1000 + i)
		floors.append(f)
		if f >= 10:
			hit += 1
		if i % 5 == 4:
			await get_tree().process_frame
	floors.sort()
	print("  bots: pagoda expert heat 0: floor>=10 %d/%d, median floor %d (%.1f s)" % [hit, n, floors[n / 2], (Time.get_ticks_msec() - t0) / 1000.0])
	check(float(hit) / n >= 0.6, "pagoda expert heat 0 reaches floor 10 in >= 60%% (%d/%d)" % [hit, n])
	var hot: = []
	for i in mini(n, 20):
		hot.append(pagoda_bot("expert", {"shroud": 1, "greedy": 2, "hourglass": 1, "guards": 1}, 3000 + i))
	hot.sort()
	print("  bots: pagoda expert heat 8: median floor %d" % hot[hot.size() / 2])
	var full_e: = 0
	var full_c: = 0
	var sc_e: = []
	for i in n:
		var w: = 2900 + (i % 8)
		var e: = journey_bot("expert", w, 500 + i)
		var c: = journey_bot("casual", w, 900 + i)
		if int(e.boards) >= 5:
			full_e += 1
			sc_e.append(int(e.score))
		if int(c.boards) >= 5:
			full_c += 1
		if i % 5 == 4:
			await get_tree().process_frame
	sc_e.sort()
	print("  bots: journey 5/5 expert %d/%d, casual %d/%d; expert 5/5 median score %d" % [full_e, n, full_c, n, sc_e[sc_e.size() / 2] if not sc_e.is_empty() else 0])
	check(float(full_e) / n >= 0.35, "journey expert 5/5 >= 35%% (%d/%d)" % [full_e, n])
	var fc: = float(full_c) / n
	check(fc >= 0.10 and fc <= 0.25, "journey casual 5/5 in 10–25%% (%d/%d)" % [full_c, n])

# tuning aid: journey difficulty presets × bots (prints a table, no checks)
const SWEEP: = [
	{"faces": 19, "layers": 2, "target": 30, "hidden_from": 0, "ice_from": 0, "fill": 0.13, "size": 1},
	{"faces": 19, "layers": 2, "target": 32, "hidden_from": 0, "ice_from": 0, "fill": 0.13, "size": 1},
	{"faces": 19, "layers": 2, "target": 28, "hidden_from": 0, "ice_from": 0, "fill": 0.135, "size": 1},
	{"faces": 20, "layers": 2, "target": 29, "hidden_from": 0, "ice_from": 0, "fill": 0.135, "size": 1},
]

func _sweep() -> void:
	var n: = int(args.get("sweep_runs", "100"))
	for preset in SWEEP:
		J.tune = preset
		var e5: = 0
		var c5: = 0
		var eb: = 0
		var cb: = 0
		for i in n:
			var w: = 2900 + (i % 8)
			var e: = journey_bot("expert", w, 500 + i)
			var c: = journey_bot("casual", w, 900 + i)
			e5 += 1 if int(e.boards) >= 5 else 0
			c5 += 1 if int(c.boards) >= 5 else 0
			eb += int(e.boards)
			cb += int(c.boards)
		print("SWEEP %s expert5 %d/%d casual5 %d/%d avg boards e %.1f c %.1f" % [str(preset), e5, n, c5, n, float(eb) / n, float(cb) / n])
		await get_tree().process_frame
	J.tune = J.TUNED.duplicate()

# ---------------------------------------------------------------- matrix (offline)

func _make_matrix() -> void:
	cur = "matrix"
	var keys: = []
	for id in D.CURSE_ORDER:
		for lvl in range(1, (D.CURSES[id].levels as Array).size() + 1):
			keys.append([id, lvl])
	var floors_ref: = [10, 18, 26]
	var seeds: = int(args.get("matrix_seeds", "8"))
	var raw: = {}
	var t0: = Time.get_ticks_msec()
	var single: = {}
	var base: = _floor_rate({}, floors_ref, seeds)
	for k in keys:
		single["%s:%d" % k] = snappedf(_floor_rate({k[0]: k[1]}, floors_ref, seeds), 0.01)
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			if keys[i][0] == keys[j][0]:
				continue
			var c: = {}
			c[keys[i][0]] = keys[i][1]
			c[keys[j][0]] = keys[j][1]
			raw["%s:%d|%s:%d" % [keys[i][0], keys[i][1], keys[j][0], keys[j][1]]] = _floor_rate(c, floors_ref, seeds)
		await get_tree().process_frame
	# smoothing: a lower level is never harder than a higher one (rate(i, j) = max over levels >= i, >= j);
	# removes sampling noise so the forbidden set is monotone
	var rates: = {}
	var forbid: = []
	for key in raw:
		var ab: = String(key).split("|")
		var a: = ab[0].split(":")
		var b: = ab[1].split(":")
		var best: float = raw[key]
		for key2 in raw:
			var ab2: = String(key2).split("|")
			var a2: = ab2[0].split(":")
			var b2: = ab2[1].split(":")
			if a2[0] == a[0] and b2[0] == b[0] and int(a2[1]) >= int(a[1]) and int(b2[1]) >= int(b[1]):
				best = maxf(best, float(raw[key2]))
		rates[key] = snappedf(best, 0.01)
		if best < MATRIX_MIN:
			forbid.append([ab[0], ab[1]])
	# keep only the minimal forbidden pairs (validate() extends a pair upward by itself)
	var minimal: = []
	for pr in forbid:
		var dominated: = false
		for q in forbid:
			if q == pr:
				continue
			var pa: = String(pr[0]).split(":")
			var pb: = String(pr[1]).split(":")
			var qa: = String(q[0]).split(":")
			var qb: = String(q[1]).split(":")
			if qa[0] == pa[0] and qb[0] == pb[0] and int(qa[1]) <= int(pa[1]) and int(qb[1]) <= int(pb[1]):
				dominated = true
		if not dominated:
			minimal.append(pr)
	var out: = {"version": 2, "rule": "expert bot, floors %s × %d seeds, clean clear (no lantern lost) of one floor; rates smoothed to be monotone in the levels; a pair is forbidden when its clear rate < %.2f" % [str(floors_ref), seeds, MATRIX_MIN],
		"base": snappedf(base, 0.01), "single": single, "rates": rates, "forbid": minimal}
	M.set_matrix(out)
	var mh: = M.max_valid_heat()
	out["max_heat"] = mh
	var f: = FileAccess.open(M.MATRIX_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("MODS_MATRIX base %.2f pairs %d forbidden %d max heat %d (%.1f s)" % [base, rates.size(), minimal.size(), mh, (Time.get_ticks_msec() - t0) / 1000.0])

const MATRIX_MIN: = 0.34

func _floor_rate(curses: Dictionary, floors_ref: Array, seeds: int) -> float:
	var won: = 0
	var n: = 0
	for f in floors_ref:
		for s in seeds:
			var run: = {"mode": "pagoda", "floor": f, "lives": 3, "partner": "mc", "seed": 4000 + s * 31 + f, "curses": curses,
				"forced": {}, "bless": {}, "owned": [], "released": FOUNDERS}
			var rules: = M.resolve(run)
			var res: = SIM.play(SIM.deal(P.floor_cfg(run)), rules, "expert", U.rng(s * 7 + f, "mx"), {"lives": int(rules.lives)})
			n += 1
			# a clean clear: no lantern lost (losses add up over a tower, a pair that eats lanterns is cruel)
			if res.cleared and int(res.overflows) == 0 and int(res.timeouts) == 0:
				won += 1
	return float(won) / float(n)
