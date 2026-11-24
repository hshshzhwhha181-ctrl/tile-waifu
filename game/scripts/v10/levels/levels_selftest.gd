extends Node

# 0.10 levels selftest / bake runner (standalone scene, does not touch main.gd).
#
#   godot --headless --path game res://scripts/v10/levels/levels_selftest.tscn -- --levels_selftest=1
#   ... -- --levels_selftest=1 --levels_n=200          (first N levels only, quick)
#   ... -- --levels_bake=1                               (bot picks the seed salt per level -> data/v10/levels/levels_bake.json)
#   ... -- --levels_selftest=1 --levels_json=/tmp/x.json (also dump per-level metrics)
#
# Prints «LEVELS SELFTEST OK ...» or «LEVELS SELFTEST FAIL ...» and quits with 0 / 1.

const Gen = preload("res://scripts/v10/levels/level_gen.gd")
const Sim = preload("res://scripts/v10/levels/level_sim.gd")

const R_REG: = 40
const R_NOV: = 8
const R_EXP: = 8
const R_RND: = 16
const SOLVE_BUDGET: = 600
const BAKE_TRIES: = 12
const BAKE_MARGIN: = 0.04   # the bake wants the bot's rate this far inside the band (selection bias + noise)
const CHECK_TOL: = 0.05     # the selftest re-measures with fresh bot seeds: 40 playouts => sigma ~0.08 at p=0.5

var args: = {}
var fails: = []


func _ready() -> void :
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	await get_tree().process_frame
	var code: = 0
	if args.has("levels_bake"):
		code = _bake()
	else:
		code = _selftest()
	get_tree().quit(code)


func _n() -> int:
	return clampi(int(args.get("levels_n", str(Gen.TOTAL))), 1, Gen.TOTAL)


# ---------------------------------------------------------------- metrics for one built level

func _metrics(sim, lv: Dictionary, reps: Array) -> Dictionary:
	Gen.load_into(sim, lv)
	var rng: = RandomNumberGenerator.new()
	rng.seed = Gen._hash(int(lv.v10_id) * 101 + 9)
	var out: = {"n": sim.n, "ice": 0, "spec": (lv.v10.spec as Array).size()}
	for t in sim.n:
		out.ice += int(sim.ice0[t])
	var names: = ["rnd", "nov", "reg", "exp"]
	var bsum: = 0
	var bn: = 0
	var holds: = 0
	var hold_runs: = 0
	var maxt: = 0
	for prof in 4:
		var r: int = reps[prof]
		if r <= 0:
			continue
		var wins: = 0
		for _k in r:
			var res: Dictionary = sim.playout(rng, prof)
			if res.win:
				wins += 1
			if prof == 2:
				bsum += int(res.bsum)
				bn += int(res.bn)
				holds += int(res.holds)
				hold_runs += 1
				maxt = maxi(maxt, int(res.maxt))
		out[names[prof]] = float(wins) / r
	out["moves"] = sim.n + out.ice
	out["branch"] = float(bsum) / maxf(1.0, bn)
	out["holds"] = float(holds) / maxf(1.0, hold_runs)
	out["dead"] = 1.0 - float(out.get("rnd", 1.0))
	out["exposed"] = int((lv.get("gen_stats", {}) as Dictionary).get("exposed", 0))
	return out


func _in_band(tier: String, win: float, tol: float = 0.0) -> bool:
	var b: Array = Gen.BANDS[tier]
	var lo: = float(b[0])
	var hi: = float(b[1])
	if tol < 0.0:
		# inner band (bake): shrink, but never above a pass rate of 1.0
		lo -= tol
		hi = hi + tol if hi < 0.999 else hi
		return win >= lo - 0.001 and win <= hi + 0.001
	return win >= lo - tol - 0.001 and win <= hi + tol + 0.001


# the board's auto-player (V10LevelBoard.solver_move, used by playtest/fuzz): the tray tile's own twin,
# else the next certificate tile still on the board
func _cert_policy(sim, lv: Dictionary) -> bool:
	Gen.load_into(sim, lv)
	sim.reset()
	var cert: PackedInt32Array = lv.v10.cert
	var ci: = 0
	var guard: int = sim.n * 3 + 5
	while sim.alive_n > 0 and guard > 0:
		guard -= 1
		var mv: PackedInt32Array = sim.moves_now()
		var pick: = -1
		var step: PackedInt32Array = lv.v10.step
		for x in sim.tray:
			for t in mv:
				if sim.face[t] == sim.face[x] and step[t] == step[x]:
					pick = t
					break
			if pick >= 0:
				break
		if pick < 0:
			while ci < cert.size() and sim.present[cert[ci]] == 0:
				ci += 1
			if ci >= cert.size() or not mv.has(cert[ci]):
				return false
			pick = cert[ci]
		if sim.tap(pick) < 0:
			return false
	return sim.alive_n == 0


func _board_play(lv: Dictionary) -> Dictionary:
	var BoardScript: Script = load("res://scripts/v10/levels/level_board.gd")
	var b = BoardScript.new()
	b.look = G.skin_look()
	add_child(b)
	b.setup(lv)
	if not b.v10_used:
		b.queue_free()
		return {"ok": false, "why": "payload not used"}
	b.apply_specials(lv.v10_plan)
	var want: = (lv.v10.spec as Array).size() * 2
	if b.spec.size() != want:
		b.queue_free()
		return {"ok": false, "why": "specials %d != %d" % [b.spec.size(), want]}
	for k in b.tiles.size():
		var t: Tile = b.tiles[k]
		if t.face != V6SpecialBoard.JOKER and t.shard == "" and t.face != int(lv.v10.face[k]):
			b.queue_free()
			return {"ok": false, "why": "face %d differs" % k}
	var ok: = true
	var why: = ""
	var guard: = 0
	while b.board_count() > 0 and guard < 3000:
		guard += 1
		var t: Tile = b.solver_move()
		if t == null:
			ok = false
			why = "no move with %d left" % b.board_count()
			break
		if not b.is_free(t) or not b.takeable(t):
			ok = false
			why = "auto-player picked a blocked tile"
			break
		if t.ice > 0:
			t.ice -= 1
			continue
		if t.face == V6SpecialBoard.JOKER:
			for x in b.tray:
				if x.face != V6SpecialBoard.JOKER:
					t.face = x.face
					break
		elif not b.tray.any( func(x): return x.face == t.face):
			for x in b.tray:
				if x.face == V6SpecialBoard.JOKER:
					x.face = t.face
					break
		var twin: Tile = null
		for x in b.tray:
			if x.face == t.face:
				twin = x
				break
		if twin:
			b.tray.erase(twin)
			twin.alive = false
			t.alive = false
			b._pair_gone(twin, t, true)
		else:
			b.tray.append(t)
			if b.tray.size() >= TrayBoard.SLOTS:
				ok = false
				why = "tray full"
				break
	var left: int = b.board_count()
	b.queue_free()
	return {"ok": ok and left == 0, "why": why if why != "" else "%d left" % left}


func _digest(lv: Dictionary) -> int:
	var b: Dictionary = lv.v10
	var s: = "%s|%s|%s|%s|%s|%s|%s|%s" % [lv.shape, lv.layers, lv.seed, b.pos, b.face, b.ice, b.spec, lv.cert]
	return s.hash()


# ---------------------------------------------------------------- selftest

func _selftest() -> int:
	var N: = _n()
	var sim = Sim.new()
	var ok_all: = true
	# 1) speed: level() and build() for every level
	var t0: = Time.get_ticks_usec()
	for i in N:
		Gen.level(i)
	var t_level: = (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	var built: = []
	var dig1: = PackedInt64Array()
	for i in N:
		var lv: = Gen.build(i, -1, sim)
		built.append(lv)
	var t_build: = (Time.get_ticks_usec() - t0) / 1000.0
	for lv in built:
		dig1.append(_digest(lv))
	print("LEVELS gen: level() x%d %.0f ms, build() x%d %.0f ms (limit 5000 ms for 1000)" % [N, t_level, N, t_build])
	if t_build * 1000.0 / N > 5000.0:
		_fail("build too slow: %.0f ms per 1000" % (t_build * 1000.0 / N))
	# 2) determinism: a second, fresh pass gives the same boards
	var sim2 = Sim.new()
	var mism: = 0
	for i in N:
		if _digest(Gen.build(i, -1, sim2)) != dig1[i]:
			mism += 1
	if mism > 0:
		_fail("non-deterministic boards: %d" % mism)
	print("LEVELS determinism: %d/%d identical on rebuild" % [N - mism, N])

	# 2b) the sim's fast topology equals TrayBoard's brute-force rules (cover: higher z, |dx|<2, |dy|<2;
	#     sides: same z, dx = ±2, |dy|<2) on a sample of boards
	var topo_bad: = 0
	for i in range(0, N, maxi(1, N / 60)):
		var lv: Dictionary = built[i]
		Gen.load_into(sim, lv)
		for a in sim.n:
			var cov: = []
			var l: = []
			var r: = []
			for o in sim.n:
				if o == a:
					continue
				var dx: int = sim.px[o] - sim.px[a]
				var dy: int = sim.py[o] - sim.py[a]
				if sim.pz[o] > sim.pz[a] and absi(dx) < 2 and absi(dy) < 2:
					cov.append(o)
				if sim.pz[o] == sim.pz[a] and absi(dy) < 2:
					if dx == -2:
						l.append(o)
					elif dx == 2:
						r.append(o)
			var c2: Array = (sim.cov_by[a] as Array).duplicate()
			cov.sort()
			c2.sort()
			var l2: Array = (sim.lft[a] as Array).duplicate()
			var r2: Array = (sim.rgt[a] as Array).duplicate()
			l.sort()
			r.sort()
			l2.sort()
			r2.sort()
			if cov != c2 or l != l2 or r != r2:
				topo_bad += 1
	if topo_bad > 0:
		_fail("sim topology differs from TrayBoard rules on %d tiles" % topo_bad)
	print("LEVELS topology: fast cover/side lists match the brute-force rules (%d mismatches)" % topo_bad)

	# 3) structure checks + certificate replay + game auto-player + independent solver
	var cert_ok: = 0
	var step_ok: = 0
	var solve_ok: = 0
	var solve_nodes: = 0
	var t_ver: = Time.get_ticks_usec()
	for i in N:
		var lv: Dictionary = built[i]
		var b: Dictionary = lv.v10
		var n: int = b.n
		if n % 2 != 0 or n < 12:
			_fail("%s: bad tile count %d" % [lv.code, n])
		# every face appears an even number of times
		var cnt: = {}
		for t in n:
			var f: int = b.face[t]
			cnt[f] = int(cnt.get(f, 0)) + 1
		for f in cnt:
			if int(cnt[f]) % 2 != 0:
				_fail("%s: face %d appears %d times" % [lv.code, f, cnt[f]])
		Gen.load_into(sim, lv)
		var r: Dictionary = sim.replay(lv.cert)
		if r.is_empty():
			cert_ok += 1
		else:
			_fail("%s: certificate fails: %s at %d" % [lv.code, r.why, r.at])
		if _cert_policy(sim, lv):
			step_ok += 1
		else:
			_fail("%s: board auto-player (tray pair, else next certificate tile) fails" % lv.code)
		var s: Dictionary = sim.solve(SOLVE_BUDGET)
		if s.ok:
			solve_ok += 1
			# the solver's own order must replay too
			var r2: Dictionary = sim.replay(s.order)
			if not r2.is_empty():
				_fail("%s: solver order does not replay: %s" % [lv.code, r2.why])
		solve_nodes += int(s.nodes)
	print("LEVELS verify: certificate %d/%d, game auto-player %d/%d, blind DFS solver (no certificate, %d nodes) %d/%d, avg nodes %.0f, %.1f s"
		% [cert_ok, N, step_ok, N, SOLVE_BUDGET, solve_ok, N, float(solve_nodes) / N, (Time.get_ticks_usec() - t_ver) / 1e6])

	# 3b) the real board: V10LevelBoard takes the payload, and the board's own auto-player clears it with the
	#     V6SpecialBoard rules (same loop as v06 spec_selftest)
	var b_ok: = 0
	var b_n: = 0
	var t_b: = Time.get_ticks_usec()
	for i in range(0, N, 7):
		b_n += 1
		var r3: = _board_play(built[i])
		if r3.ok:
			b_ok += 1
		else:
			_fail("%s: real board: %s" % [built[i].code, r3.why])
	print("LEVELS real board (V10LevelBoard, payload + specials + auto-player): %d/%d cleared, %.1f s" % [b_ok, b_n, (Time.get_ticks_usec() - t_b) / 1e6])

	# 3c) «облегчённая раздача» (assist deal after two fails): verified the same way, and easier than the level
	var as_ok: = 0
	var as_n: = 0
	var as_easier: = 0
	var as_cmp: = 0
	var as_sum_a: = 0.0
	var as_sum_b: = 0.0
	for i in range(0, N, 3):
		var la: = Gen.build(i, -1, sim, true)
		as_n += 1
		Gen.load_into(sim, la)
		if sim.replay(la.cert).is_empty() and _cert_policy(sim, la):
			as_ok += 1
		else:
			_fail("%s: assist deal does not verify" % la.code)
		if Gen.TIERS.find(str(la.tier)) >= Gen.TIERS.find("hard"):
			as_cmp += 1
			var ma: = _metrics(sim, la, [0, 0, R_REG, 0])
			var mb: = _metrics(sim, built[i], [0, 0, R_REG, 0])
			as_sum_a += float(ma.reg)
			as_sum_b += float(mb.reg)
			if float(ma.reg) >= float(mb.reg):
				as_easier += 1
	print("LEVELS assist deals: %d/%d verified; on %d hard+ levels the assist deal is not harder in %d, pass rate %.2f -> %.2f"
		% [as_ok, as_n, as_cmp, as_easier, as_sum_b / maxf(1, as_cmp), as_sum_a / maxf(1, as_cmp)])
	if as_cmp > 0 and float(as_easier) / as_cmp < 0.85:
		_fail("assist deals are not easier (%d/%d)" % [as_easier, as_cmp])

	# 4) difficulty bots
	var t_bot: = Time.get_ticks_usec()
	var mets: = []
	for i in N:
		mets.append(_metrics(sim, built[i], [R_RND, R_NOV, R_REG, R_EXP]))
	print("LEVELS bots: %d levels x %d playouts in %.1f s" % [N, R_RND + R_NOV + R_REG + R_EXP, (Time.get_ticks_usec() - t_bot) / 1e6])

	_report(built, mets)
	_curve_checks(built, mets)
	_schedule_checks(N)

	if args.has("levels_json"):
		var rows: = []
		for i in N:
			var lv: Dictionary = built[i]
			var m: Dictionary = mets[i]
			rows.append({"i": i, "code": lv.code, "tier": lv.tier, "boss": lv.boss, "peak": lv.peak, "shape": lv.shape, "layers": lv.layers,
				"faces": lv.faces, "mechs": lv.mechs, "salt": lv.v10_salt, "m": m})
		var f: = FileAccess.open(args.levels_json, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(rows))
			f.close()

	if fails.is_empty():
		print("LEVELS SELFTEST OK %d levels: certificate %d/%d solvable" % [N, cert_ok, N])
		return 0
	for e in fails.slice(0, 40):
		printerr("  - ", e)
	print("LEVELS SELFTEST FAIL %d problems" % fails.size())
	return 1


func _fail(s: String) -> void :
	fails.append(s)


func _report(built: Array, mets: Array) -> void :
	var N: = built.size()
	# per world
	print("LEVELS per world (regular-bot pass rate; dead = random-policy dead-end rate; branch = free tiles at a hold):")
	print("  world                 tiles  moves  branch  holds  dead   novice  regular  expert   hard/vh/leg/boss")
	for w in Gen.WORLDS:
		var a: = w * Gen.PER_WORLD
		var b: = mini(N, a + Gen.PER_WORLD)
		if a >= N:
			break
		var s: = {"n": 0.0, "moves": 0.0, "branch": 0.0, "holds": 0.0, "dead": 0.0, "nov": 0.0, "reg": 0.0, "exp": 0.0}
		var cnt: = {"hard": 0, "very_hard": 0, "legendary": 0, "boss": 0}
		for i in range(a, b):
			for k in s:
				s[k] += float(mets[i][k])
			var t: String = built[i].tier
			if cnt.has(t):
				cnt[t] += 1
			if built[i].boss:
				cnt.boss += 1
		var c: = float(b - a)
		print("  %-20s %6.1f %6.1f %7.2f %6.1f %5.2f   %5.2f   %5.2f    %5.2f    %d/%d/%d/%d" % [Gen.WORLD[w].name, s.n / c, s.moves / c,
			s.branch / c, s.holds / c, s.dead / c, s.nov / c, s.reg / c, s.exp / c, cnt.hard, cnt.very_hard, cnt.legendary, cnt.boss])
	print("LEVELS per tier:")
	print("  tier        count  tiles  regular  band          in-band(±%.2f)  min" % CHECK_TOL + "    max    dead   expert novice holds exposed")
	for t in Gen.TIERS:
		var xs: = []
		var dead: = 0.0
		var ex: = 0.0
		var tiles: = 0.0
		var inb: = 0
		var nov: = 0.0
		var hol: = 0.0
		var expo: = 0.0
		for i in N:
			if built[i].tier == t:
				nov += float(mets[i].nov)
				hol += float(mets[i].holds)
				expo += float(mets[i].exposed)
				xs.append(float(mets[i].reg))
				dead += float(mets[i].dead)
				ex += float(mets[i].exp)
				tiles += float(mets[i].n)
				if _in_band(t, float(mets[i].reg), CHECK_TOL):
					inb += 1
		if xs.is_empty():
			continue
		var mean: = 0.0
		for x in xs:
			mean += x
		mean /= xs.size()
		var band: Array = Gen.BANDS[t]
		var c: = float(xs.size())
		print("  %-10s %6d %6.1f  %6.2f   %.2f-%.2f    %5.1f%%  %5.2f  %5.2f  %5.2f  %5.2f  %5.2f %5.1f %5.1f" % [t, xs.size(), tiles / c, mean, band[0], band[1],
			100.0 * inb / c, xs.min(), xs.max(), dead / c, ex / c, nov / c, hol / c, expo / c])


func _tier_mean(built: Array, mets: Array, t: String) -> float:
	var s: = 0.0
	var c: = 0
	for i in built.size():
		if built[i].tier == t:
			s += float(mets[i].reg)
			c += 1
	return s / c if c > 0 else -1.0


func _curve_checks(built: Array, mets: Array) -> void :
	var N: = built.size()
	# tiers are ordered by pass rate
	var prev: = 2.0
	var prev_t: = ""
	for t in Gen.TIERS:
		var m: = _tier_mean(built, mets, t)
		if m < 0.0:
			continue
		if m >= prev:
			_fail("curve: tier %s mean %.2f is not below %s %.2f" % [t, m, prev_t, prev])
		prev = m
		prev_t = t
	# band adherence per tier (the bake run tightens this; the raw generator must already be close)
	var need: = 0.85 if args.has("levels_strict") or FileAccess.file_exists(Gen.BAKE_PATH) else 0.45
	for t in Gen.TIERS:
		var c: = 0
		var inb: = 0
		for i in N:
			if built[i].tier == t:
				c += 1
				if _in_band(t, float(mets[i].reg), CHECK_TOL):
					inb += 1
		if c >= 5 and float(inb) / c < need:
			_fail("curve: tier %s only %.0f%% in band ±%.2f (need %.0f%%)" % [t, 100.0 * inb / c, CHECK_TOL, need * 100.0])
	# sawtooth: in every full chapter the peak/boss is harder than the breathers
	var bad_ch: = 0
	var chapters: = 0
	for ch in N / Gen.CHAPTER:
		var a: = ch * Gen.CHAPTER
		var calm: = (float(mets[a].reg) + float(mets[a + 4].reg) + float(mets[a + 8].reg)) / 3.0
		var spike: = minf(float(mets[a + 7].reg), float(mets[a + 9].reg))
		chapters += 1
		if spike >= calm:
			bad_ch += 1
	print("LEVELS sawtooth: %d/%d chapters have the peak/boss below their breathers" % [chapters - bad_ch, chapters])
	if chapters > 0 and float(bad_ch) / chapters > 0.1:
		_fail("curve: %d chapters without a spike" % bad_ch)
	# every arc is at least as hard as the one before (same tier mix), and the last clearly harder than the first
	var wm: = []
	for w in N / Gen.PER_WORLD:
		var sm: = 0.0
		var cn: = 0
		for i in range(w * Gen.PER_WORLD, (w + 1) * Gen.PER_WORLD):
			if built[i].tier != "tutorial":
				sm += float(mets[i].reg)
				cn += 1
		wm.append(sm / maxf(1.0, cn))
	for w in range(1, wm.size()):
		if float(wm[w]) > float(wm[w - 1]) + 0.04:
			_fail("curve: arc %d (%.2f) is easier than arc %d (%.2f)" % [w + 1, wm[w], w, wm[w - 1]])
	if wm.size() >= 5 and float(wm[wm.size() - 1]) > float(wm[0]) - 0.03:
		_fail("curve: no ramp across arcs (%.2f -> %.2f)" % [wm[0], wm[wm.size() - 1]])
	print("LEVELS arcs (regular pass rate, tutorial excluded): %s" % ", ".join(wm.map(func(x): return "%.2f" % x)))
	# very hard levels really exist and are really hard
	var vh: = _tier_mean(built, mets, "very_hard")
	var lg: = _tier_mean(built, mets, "legendary")
	if N >= 300 and (vh < 0.0 or vh > 0.40):
		_fail("curve: very hard mean %.2f > 0.40" % vh)
	if N >= 300 and (lg < 0.0 or lg > 0.25):
		_fail("curve: legendary mean %.2f > 0.25" % lg)


func _schedule_checks(N: int) -> void :
	var seen: = {}
	var last_new: = -100
	for i in N:
		var lv: = Gen.level(i)
		if lv.boss != (i % 10 == 9):
			_fail("%s: boss flag" % lv.code)
		if i % 100 == 99 and lv.tier != "legendary":
			_fail("%s: arc finale must be legendary" % lv.code)
		for m in lv.mechs:
			if not seen.has(m):
				seen[m] = i
				if lv.intro != m:
					_fail("%s: mechanic %s first appears without its intro" % [lv.code, m])
				if i - last_new < 15:
					_fail("%s: new mechanic %s only %d levels after the previous" % [lv.code, m, i - last_new])
				last_new = i
		for k in ["hero", "shard"]:
			if not G.HEROES.has(str(lv[k])):
				_fail("%s: %s %s has no art in this build" % [lv.code, k, lv[k]])
		if str(lv.boss_hero) != "" and not G.HEROES.has(str(lv.boss_hero)):
			_fail("%s: boss heroine %s has no art in this build" % [lv.code, lv.boss_hero])
		if lv.intro != "" and Gen.TIERS.find(lv.tier) > Gen.TIERS.find("normal"):
			_fail("%s: intro level is %s" % [lv.code, lv.tier])
	print("LEVELS schedule: mechanics introduced %s" % str(seen))


# ---------------------------------------------------------------- bake

func _bake() -> int:
	var N: = _n()
	var sim = Sim.new()
	Gen.set_bake({})
	var salts: = []
	var metrics: = []
	var t0: = Time.get_ticks_usec()
	var hit: = 0
	for i in N:
		var tier: = Gen.tier_of(i)
		var mid: = Gen.target_rate(i)
		var best_s: = 0
		var best_d: = 9.0
		var best_m: = {}
		for s in BAKE_TRIES:
			var lv: = Gen.build(i, s, sim)
			var m: = _metrics(sim, lv, [0, 0, R_REG, 0])
			var d: = absf(float(m.reg) - mid)
			if _in_band(tier, float(m.reg), -BAKE_MARGIN):
				d -= 1.0
			if d < best_d:
				best_d = d
				best_s = s
				best_m = m
			if _in_band(tier, float(m.reg), -BAKE_MARGIN) and absf(float(m.reg) - mid) <= 0.08:
				break
		if _in_band(tier, float(best_m.reg)):
			hit += 1
		salts.append(best_s)
		metrics.append({"tier": tier, "reg": snappedf(float(best_m.reg), 0.01), "n": best_m.n})
		if i % 100 == 99:
			print("LEVELS bake %d/%d, in band %d, %.1f s" % [i + 1, N, hit, (Time.get_ticks_usec() - t0) / 1e6])
	for i in range(N, Gen.TOTAL):
		salts.append(0)
	var out: = {"version": Gen.VERSION, "note": "salt per level chosen by the regular bot (levels_selftest --levels_bake)", "salt": salts, "metrics": metrics}
	var path: = ProjectSettings.globalize_path(Gen.BAKE_PATH)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("LEVELS BAKE FAIL cannot write %s" % path)
		return 1
	f.store_string(JSON.stringify(out))
	f.close()
	print("LEVELS BAKE OK %d levels, %d in band, wrote %s" % [N, hit, path])
	return 0
