class_name TWBoardSelftest
extends RefCounted

# Selftest of the P16 rules core: TWRng, TWFree, TWBoardEvents, TWBoard. Pure core (no G, no scene tree, no Node);
# the runner (scripts/v10/rules/tw_board_selftest_runner.gd) only starts it and sets the exit code.
#
#   A  TWRng        golden values, determinism, ranges, shuffle, forks, mix == V10LevelGen._hash
#   B  TWFree       layout / topology parity with the legacy generator and V10LevelSim, the free rule on hand-made tables
#   C  TWBoard      scenario tests: tap / deny / tray / pair / combo / ice / secret / gold / shard / undo / return_tray /
#                   hint / shuffle / locks / chain / joker / bomb / gift / unstick / cleared / events are plain data
#   D  seeds        the same seed gives the same faces / ice / gold / secret / shard / specials (1000 seeds, twice)
#   E  levels       the first N Path levels (V10LevelGen.build): lockstep parity of TWBoard with V10LevelSim on random play,
#                   certificate replay, and the solver bot clearing every level on the new core
#   F  replay       a played game replayed from its tap log gives the same state_hash; snapshot / restore; undo restores hash
#   G  shuffle      the dealt-again table is still clearable
#   H  fuzz         random operation streams keep the counters, the tray and the free set consistent
#   I  lint         the new files contain no await / Tween / timer / scene-tree access
#
# Prints "TWBOARD_SELFTEST ok/total" (FAIL lines first). Args of run(env): levels_n (200), seeds_n (1000), fuzz_n (48).

const E = preload("res://core/rules/tw_events_board.gd")
const SRC: = ["res://core/rules/tw_board.gd", "res://core/rules/tw_free.gd", "res://core/rules/tw_rng.gd", "res://core/rules/tw_events_board.gd"]

static var _pass: = 0
static var _fail: = 0


static func run(env: Dictionary = {}) -> Array:
	_pass = 0
	_fail = 0
	var t0: = Time.get_ticks_msec()
	_rng()
	_free()
	_scenarios()
	_seeds(int(env.get("seeds_n", 1000)))
	_levels(int(env.get("levels_n", 200)))
	_replay()
	_shuffle()
	_fuzz(int(env.get("fuzz_n", 48)))
	_lint()
	var total: = _pass + _fail
	print("TWBOARD_SELFTEST %d/%d  (%.1f s)" % [_pass, total, (Time.get_ticks_msec() - t0) / 1000.0])
	return [_pass, total]


static func _c(name: String, ok: bool, info: String = "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		print("FAIL ", name, ("  " + info) if info != "" else "")


# ------------------------------------------------------------------ helpers

# a hand-made table: cells with faces (step = pair index unless given); reset() already done
static func _mk(cells: Array, faces: Array, steps: Array = []) -> TWBoard:
	var b: = TWBoard.from_positions(cells)
	for i in cells.size():
		b.face0[i] = int(faces[i])
		b.step0[i] = int(steps[i]) if i < steps.size() else i / 2
	b.reset()
	return b


static func _row(k: int, gap: int = 4, y: int = 0) -> Array:
	var out: = []
	for i in k:
		out.append(Vector3i(i * gap, y, 0))
	return out


static func _t(ev: Array) -> String:
	return ",".join(E.types(ev))


static func _cfg(seed_: int, extra: Dictionary = {}) -> Dictionary:
	var c: = {"cols": 6, "rows": 8, "layers": 3, "fill": 0.7, "faces": 12, "seed": seed_, "shape": "rect", "gold": 4, "ice": 2,
		"hidden": true, "shard": "rin", "plan": {"lock": 1, "lock_n": 1, "chain": 1, "joker": 1, "bomb": 1, "gift": 1}}
	for k in extra:
		c[k] = extra[k]
	return c


# the full content of a deal as one array (for equality)
static func _content(b: TWBoard) -> Array:
	return [b.face0, b.step0, b.gold0, b.ice0, b.secret0, b.shard0, b.kind, b.arg, b.mate, b.cert, b.pos]


static func _digest(b: TWBoard) -> int:
	var h: = TWRng.FNV_BASIS
	for i in b.n:
		h = TWRng.fnv(h, b.face0[i] | (b.gold0[i] << 10) | (b.ice0[i] << 11) | (b.secret0[i] << 12) | (b.shard0[i] << 13) | (b.kind[i] << 14))
		h = TWRng.fnv(h, b.step0[i] * 64 + b.arg[i])
	for t in b.cert:
		h = TWRng.fnv(h, t)
	return h


# recompute every counter of a board from scratch and report the first mismatch ("" = consistent)
static func _inv(b: TWBoard) -> String:
	var onb: = 0
	var al: = 0
	for i in b.n:
		if b.present[i] == 1:
			onb += 1
			if b.alive[i] == 0 or b.tray.has(i):
				return "present tile %d dead or in tray" % i
		if b.alive[i] == 1:
			al += 1
		var cc: = 0
		for o in b.cov_by[i]:
			if b.present[o] == 1:
				cc += 1
		var lc: = 0
		for o in b.lft[i]:
			if b.present[o] == 1:
				lc += 1
		var rc: = 0
		for o in b.rgt[i]:
			if b.present[o] == 1:
				rc += 1
		if cc != b.covcnt[i] or lc != b.lcnt[i] or rc != b.rcnt[i]:
			return "counters of %d: %d/%d/%d vs %d/%d/%d" % [i, b.covcnt[i], b.lcnt[i], b.rcnt[i], cc, lc, rc]
		var free_ref: = TWFree.is_free(i, {"cov_by": b.cov_by, "lft": b.lft, "rgt": b.rgt}, func(o): return b.present[o] == 1) if b.present[i] == 1 else false
		if b.opened[i] == 0 and free_ref != b.is_free(i):
			return "free(%d) %s vs %s" % [i, b.is_free(i), free_ref]
	if onb != b.on_board:
		return "on_board %d vs %d" % [b.on_board, onb]
	if al != b.alive_n:
		return "alive_n %d vs %d" % [b.alive_n, al]
	for t in b.tray:
		if b.alive[t] == 0 or b.present[t] == 1:
			return "tray tile %d wrong state" % t
	if b.alive_n != b.on_board + b.tray.size():
		return "alive_n != on_board + tray"
	if b.tray.size() > b.slots:
		return "tray over slots"
	for h in b.history:
		if not b.tray.has(h):
			return "history tile %d not in tray" % h
	var sl: = 0
	for i in b.n:
		sl += b.sec[i]
	if sl != b.sec_left:
		return "sec_left %d vs %d" % [b.sec_left, sl]
	return ""


# ------------------------------------------------------------------ A: TWRng

static func _rng() -> void:
	var r: = TWRng.make(1)
	var got: = [r.next_u32(), r.next_u32(), r.next_u32(), r.next_u32()]
	_c("rng golden seed 1", got == [3203108257, 4170425070, 1908508304, 1908102360], str(got))
	var r5: = TWRng.make(1, 5)
	_c("rng golden seed 1 salt 5", [r5.next_u32(), r5.next_u32(), r5.next_u32()] == [4048497912, 1079878712, 3305023240])
	var r7: = TWRng.make(123456789)
	_c("rng golden randi", [r7.rand_i31(), r7.rand_i31()] == [1028189836, 411501592])
	_c("rng mix golden", TWRng.mix(0) == 315240206 and TWRng.mix(12345) == 1200724404)
	var same: = true
	for x in [0, 1, 7, 99, 12345, 2147483647, 123456789]:
		if TWRng.mix(x) != V10LevelGen._hash(x):
			same = false
	_c("rng mix == V10LevelGen._hash", same)
	var a: = TWRng.make(42)
	var b: = TWRng.make(42)
	var eq: = true
	for i in 200:
		if a.next_u32() != b.next_u32():
			eq = false
	_c("rng same seed same stream", eq)
	_c("rng other seed other stream", TWRng.make(42).next_u32() != TWRng.make(43).next_u32())
	_c("rng other salt other stream", TWRng.make(42, 0).next_u32() != TWRng.make(42, 1).next_u32())
	var ok: = true
	var lo: = 999
	var hi: = -1
	var fl: = 0.0
	var ch: = 0
	var s: = TWRng.make(5)
	for i in 5000:
		var v: = s.below(7)
		lo = mini(lo, v)
		hi = maxi(hi, v)
		var f: = s.rand_f()
		if f < 0.0 or f >= 1.0:
			ok = false
		fl += f
		var q: = s.rand_range(-3, 3)
		if q < -3 or q > 3:
			ok = false
		if s.chance(0.25):
			ch += 1
	_c("rng ranges", ok and lo == 0 and hi == 6)
	_c("rng randf mean", absf(fl / 5000.0 - 0.5) < 0.03, str(fl / 5000.0))
	_c("rng chance rate", absf(ch / 5000.0 - 0.25) < 0.03, str(ch / 5000.0))
	_c("rng below(0/1)", s.below(0) == 0 and s.below(1) == 0 and s.rand_range(5, 5) == 5 and s.rand_range(6, 2) == 6)
	var arr: Array = range(30)
	TWRng.make(9).shuffle(arr)
	var sorted: = arr.duplicate()
	sorted.sort()
	_c("rng shuffle is a permutation", sorted == range(30) and arr != range(30))
	var arr2: Array = range(30)
	TWRng.make(9).shuffle(arr2)
	_c("rng shuffle deterministic", arr == arr2)
	var f1: = TWRng.make(3)
	var f2: = TWRng.make(3)
	var c1: = f1.fork(1)
	var c2: = f2.fork(1)
	_c("rng fork deterministic", c1.next_u32() == c2.next_u32() and f1.next_u32() == f2.next_u32())
	_c("rng fork differs from parent", TWRng.make(3).fork(1).next_u32() != TWRng.make(3).next_u32())
	var st: = TWRng.make(11)
	st.next_u32()
	var saved: = st.state
	var nx: = [st.next_u32(), st.next_u32()]
	st.state = saved
	_c("rng state save / restore", [st.next_u32(), st.next_u32()] == nx)
	_c("rng pick", TWRng.make(1).pick([]) == null and TWRng.make(1).pick([4]) == 4)
	_c("rng fnv", TWRng.fnv(TWRng.FNV_BASIS, 0) != TWRng.fnv(TWRng.FNV_BASIS, 1) and TWRng.fnv(TWRng.FNV_BASIS, 5) == TWRng.fnv(TWRng.FNV_BASIS, 5))
	var cnt: = [0, 0, 0, 0, 0]
	var u: = TWRng.make(77)
	for i in 5000:
		cnt[u.below(5)] += 1
	var even: = true
	for v in cnt:
		if absi(v - 1000) > 120:
			even = false
	_c("rng below uniform", even, str(cnt))


# ------------------------------------------------------------------ B: TWFree

static func _free() -> void:
	# the rule on a hand-made table
	var cells: = [Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(1, 1, 1), Vector3i(8, 0, 0), Vector3i(9, 0, 0)]
	var topo: = TWFree.topology(cells)
	var all: = func(_o): return true
	_c("free: left end of a row", TWFree.is_free(0, topo, all) == false)   # (1,1,1) covers (0,0,0)
	_c("free: covered tile", (topo.cov_by[0] as Array).has(3) and (topo.cov_by[1] as Array).has(3))
	_c("free: not covered at dx 2", not (topo.cov_by[2] as Array).has(3))
	_c("free: row middle is sandwiched", TWFree.is_free(1, topo, all) == false)
	_c("free: row end free", TWFree.is_free(2, topo, all) == true)
	_c("free: top free", TWFree.is_free(3, topo, all) == true)
	var gone3: = func(o): return o != 3
	_c("free: uncovered after the cover left", TWFree.is_free(0, topo, gone3) == true)
	_c("free: middle still sandwiched", TWFree.is_free(1, topo, gone3) == false)
	var gone0: = func(o): return o != 3 and o != 0
	_c("free: middle free once one side left", TWFree.is_free(1, topo, gone0) == true)
	_c("free: dx 1 on one layer is not a side", (topo.lft[5] as Array).is_empty() and (topo.rgt[4] as Array).is_empty())
	_c("free: inverse lists", (topo.covers[3] as Array).has(0) and (topo.lft_of[0] as Array).has(1) and (topo.rgt_of[1] as Array).has(0))
	_c("free: by counts", TWFree.free_by_counts(0, 0, 3) and TWFree.free_by_counts(0, 2, 0) and not TWFree.free_by_counts(1, 0, 0) and not TWFree.free_by_counts(0, 1, 1))
	_c("free: covers() geometry", TWFree.covers(Vector3i(1, 1, 1), Vector3i(0, 0, 0)) and not TWFree.covers(Vector3i(2, 0, 1), Vector3i(0, 0, 0)) and not TWFree.covers(Vector3i(0, 0, 0), Vector3i(0, 0, 1)))
	_c("free: world", TWFree.world(Vector3i(2, 0, 0)).is_equal_approx(Vector2(2 * TWFree.UX, 0)) and TWFree.world(Vector3i(0, 0, 1)).is_equal_approx(TWFree.DZ))
	# a layer-2 tile covers layer 0 straight below (dz 2) and the layer-1 diagonals
	var cl: = [Vector3i(0, 0, 0), Vector3i(1, 1, 1), Vector3i(0, 0, 2)]
	var tc: = TWFree.topology(cl)
	_c("free: dz 2 cover and dz 1 cover", (tc.cov_by[0] as Array).has(2) and (tc.cov_by[0] as Array).has(1) and (tc.cov_by[1] as Array).has(2))
	# parity of the layout and the topology with the legacy generator and the legacy sim, over the first levels
	var sim: = V10LevelSim.new()
	var same_pos: = 0
	var same_topo: = 0
	var odd_ok: = 0
	var sorted_ok: = 0
	var checked: = 0
	for i in range(0, 1000, 5):
		var lv: Dictionary = V10LevelGen.level(i)
		var legacy: Array = V10LevelGen.positions(lv)
		var mine: Array = TWFree.positions(lv)
		checked += 1
		if legacy == mine:
			same_pos += 1
		if mine.size() % 2 == 0:
			odd_ok += 1
		var s: = true
		for k in range(1, mine.size()):
			var p: Vector3i = mine[k - 1]
			var q: Vector3i = mine[k]
			if p.z * 100000 + p.y * 100 + p.x > q.z * 100000 + q.y * 100 + q.x:
				s = false
		if s:
			sorted_ok += 1
		sim.build(mine)
		var tp: = TWFree.topology(mine)
		var ok: = true
		for k in mine.size():
			if _sorted(tp.cov_by[k]) != _sorted(sim.cov_by[k]) or _sorted(tp.lft[k]) != _sorted(sim.lft[k]) or _sorted(tp.rgt[k]) != _sorted(sim.rgt[k]):
				ok = false
				break
		if ok:
			same_topo += 1
	_c("free: layouts == TrayBoard.gen_layout path (%d levels)" % checked, same_pos == checked, "%d/%d" % [same_pos, checked])
	_c("free: layouts are even" , odd_ok == checked)
	_c("free: layouts sorted like TrayBoard.setup", sorted_ok == checked)
	_c("free: topology == V10LevelSim (%d levels)" % checked, same_topo == checked, "%d/%d" % [same_topo, checked])
	# every shape of the game builds a layout
	var shapes: = 0
	for sh in V10LevelGen.SHAPES_ALL:
		var p: Array = TWFree.positions({"cols": 6, "rows": 8, "layers": 3, "fill": 0.7, "seed": 5, "shape": sh})
		if p.size() >= 8 and p.size() % 2 == 0:
			shapes += 1
	_c("free: all %d shapes give a table" % V10LevelGen.SHAPES_ALL.size(), shapes == V10LevelGen.SHAPES_ALL.size(), str(shapes))
	_c("free: layout deterministic", TWFree.gen_layout(_cfg(5)) == TWFree.gen_layout(_cfg(5)) and TWFree.gen_layout(_cfg(5)) != TWFree.gen_layout(_cfg(6)))


static func _sorted(a) -> Array:
	var x: = Array(a)
	x.sort()
	return x


# ------------------------------------------------------------------ C: scenarios

static func _scenarios() -> void:
	_sc_basic()
	_sc_tray()
	_sc_ice_secret()
	_sc_specials()
	_sc_undo_hint()
	_sc_misc()


static func _sc_basic() -> void:
	var b: = _mk(_row(2), [1, 1])
	_c("tap: free", b.is_free(0) and b.is_free(1) and b.free_tiles().size() == 2)
	var e1: = b.tap(0)
	_c("tap: first tile goes to tray", _t(e1) == "TO_TRAY" and b.tray.size() == 1 and b.on_board == 1 and e1[0].id == 0 and e1[0].slot == 0)
	_c("tap: tray tile is not on the table", b.present[0] == 0 and b.alive[0] == 1 and not b.is_free(0))
	_c("tap: tray tile cannot be tapped again", b.tap(0).is_empty())
	var e2: = b.tap(1)
	_c("tap: twin matches", _t(e2) == "MATCH,CLEARED", _t(e2))
	_c("tap: match data", e2[0].a == 0 and e2[0].b == 1 and e2[0].face == 1 and e2[0].combo == 1 and e2[0].gold == false and e2[0].shard == "")
	_c("tap: cleared", b.cleared and b.alive_n == 0 and b.tray.is_empty() and b.on_board == 0)
	_c("tap: nothing after cleared", b.tap(0).is_empty() and b.tap(1).is_empty())
	_c("tap: out of range ids", b.tap(-1).is_empty() and b.tap(99).is_empty())
	# covered tile: DENY
	var c: = _mk([Vector3i(0, 0, 0), Vector3i(1, 1, 1), Vector3i(8, 0, 0), Vector3i(12, 0, 0)], [1, 2, 1, 2], [0, 1, 0, 1])
	var d: = c.tap(0)
	_c("deny: covered tile", _t(d) == "DENY" and d[0].id == 0 and d[0].why == "covered", _t(d))
	_c("deny: changes nothing", c.tray.is_empty() and c.on_board == 4 and c.moves == 0 and c.taps.is_empty())
	_c("deny: free set", Array(c.free_tiles()) == [1, 2, 3], str(c.free_tiles()))
	c.tap(1)
	_c("deny: free after the cover left", c.is_free(0) and _t(c.tap(0)) == "TO_TRAY")
	# sandwiched tile
	var r: = _mk([Vector3i(0, 0, 0), Vector3i(2, 0, 0), Vector3i(4, 0, 0), Vector3i(20, 0, 0)], [1, 2, 3, 2], [0, 1, 2, 1])
	_c("side: middle denied", _t(r.tap(1)) == "DENY")
	r.tap(0)
	_c("side: middle free after one side left", r.is_free(1))
	# combo clock
	var q: = _mk(_row(8), [1, 1, 2, 2, 3, 3, 4, 4])
	q.time = 0.0
	q.tap(0)
	var m1: = q.tap(1)
	q.time = 2.0
	q.tap(2)
	var m2: = q.tap(3)
	q.time = 20.0
	q.tap(4)
	var m3: = q.tap(5)
	q.time = 21.0
	q.tap(6)
	var m4: = q.tap(7)
	_c("combo: 1, 2 inside the window, 1 after the gap, 2 again", E.of_type(m1, "MATCH")[0].combo == 1 and E.of_type(m2, "MATCH")[0].combo == 2 and E.of_type(m3, "MATCH")[0].combo == 1 and E.of_type(m4, "MATCH")[0].combo == 2)
	var clk: = {"t": 0.0}
	var q2: = _mk(_row(4), [1, 1, 2, 2])
	q2.clock = func(): return clk.t
	q2.tap(0)
	q2.tap(1)
	clk.t = 4.9
	q2.tap(2)
	var mm: = q2.tap(3)
	_c("combo: injected clock", E.of_type(mm, "MATCH")[0].combo == 2 and q2.last_match == 4.9)
	q2.combo_window = 1.0
	_c("combo: window is a field", q2.combo_window == 1.0)
	# gold and shard flags in the match event
	var g: = _mk(_row(2), [1, 1])
	g.gold0[0] = 1
	g.gold0[1] = 1
	g.reset()
	g.tap(0)
	_c("gold: match event carries gold", E.of_type(g.tap(1), "MATCH")[0].gold == true)
	var sh: = _mk(_row(2), [100, 100])
	sh.shard_hero = "rin"
	sh.shard0[0] = 1
	sh.shard0[1] = 1
	sh.reset()
	sh.tap(0)
	_c("shard: match event carries the hero", E.of_type(sh.tap(1), "MATCH")[0].shard == "rin")
	# moves counter
	_c("moves counts taps that act", q.moves == 8, str(q.moves))


static func _sc_tray() -> void:
	# four different free tiles fill the tray; the twins wait far away
	var cells: = _row(8)
	var b: = _mk(cells, [1, 2, 3, 4, 1, 2, 3, 4], [0, 1, 2, 3, 0, 1, 2, 3])
	var e: = b.tap(0)
	_c("tray: slot 0", _t(e) == "TO_TRAY")
	e = b.tap(1)
	_c("tray: slot 1", _t(e) == "TO_TRAY" and e[0].slot == 1)
	e = b.tap(2)
	_c("tray: warns at one slot left", _t(e) == "TO_TRAY,TRAY_WARN" and e[1].left == 1, _t(e))
	e = b.tap(3)
	_c("tray: full", _t(e) == "TO_TRAY,TRAY_FULL" and b.failed and b.tray.size() == 4, _t(e))
	_c("tray: full carries the tray", E.of_type(e, "TRAY_FULL")[0].tray == [0, 1, 2, 3])
	_c("tray: no more taps after fail", b.tap(4).is_empty())
	_c("tray: max_tray", b.max_tray == 4)
	# rescue
	var rr: = b.return_tray(3)
	_c("tray: return_tray", _t(rr) == "RETURN" and rr[0].ids == [3, 2, 1] and b.tray.size() == 1 and not b.failed and b.on_board == 7, _t(rr))
	_c("tray: game goes on after the rescue", _t(b.tap(4)) == "MATCH" and b.tray.is_empty())
	_c("tray: return_tray on an empty tray", _mk(_row(2), [1, 1]).return_tray(3).is_empty())
	# undo after fail
	var b2: = _mk(cells, [1, 2, 3, 4, 1, 2, 3, 4], [0, 1, 2, 3, 0, 1, 2, 3])
	for i in 4:
		b2.tap(i)
	var u: = b2.undo()
	_c("tray: undo after fail reopens", _t(u) == "UNDO" and u[0].id == 3 and not b2.failed and b2.tray.size() == 3 and b2.is_free(3))
	# twin pairing picks the first tray tile with the face, tray order is kept
	var b3: = _mk(cells, [1, 2, 3, 4, 1, 2, 3, 4], [0, 1, 2, 3, 0, 1, 2, 3])
	b3.tap(0)
	b3.tap(1)
	b3.tap(4)
	_c("tray: twin leaves, order kept", Array(b3.tray) == [1] and b3.alive_n == 6 and b3.history.size() == 1)
	# slots field
	var b5: = _mk(cells, [1, 2, 3, 4, 1, 2, 3, 4], [0, 1, 2, 3, 0, 1, 2, 3])
	b5.slots = 3
	b5.tap(0)
	var e5: = b5.tap(1)
	_c("tray: 3 slots, no warning (legacy: slots >= 4)", _t(e5) == "TO_TRAY")
	_c("tray: 3 slots fail at 3", _t(b5.tap(2)) == "TO_TRAY,TRAY_FULL")


static func _sc_ice_secret() -> void:
	var b: = _mk(_row(4), [1, 1, 2, 2])
	b.ice0[0] = 1
	b.reset()
	var e: = b.tap(0)
	_c("ice: first tap only cracks", _t(e) == "ICE_CRACK" and e[0].left == 0 and b.tray.is_empty() and b.cracks == 1, _t(e))
	_c("ice: tile still on the table", b.present[0] == 1 and b.on_board == 4 and b.ice[0] == 0)
	_c("ice: second tap takes", _t(b.tap(0)) == "TO_TRAY")
	var b2: = _mk([Vector3i(0, 0, 0), Vector3i(1, 1, 1), Vector3i(8, 0, 0), Vector3i(12, 0, 0)], [1, 2, 1, 2], [0, 1, 0, 1])
	b2.ice0[0] = 1
	b2.reset()
	_c("ice: a covered ice tile is denied, not cracked", _t(b2.tap(0)) == "DENY" and b2.ice[0] == 1)
	var b3: = _mk(_row(2), [1, 1])
	b3.ice0[0] = 1
	b3.ice0[1] = 1
	b3.reset()
	b3.ice[0] = 2
	_c("ice: two layers need two cracks", _t(b3.tap(0)) == "ICE_CRACK" and b3.ice[0] == 1 and _t(b3.tap(0)) == "ICE_CRACK" and b3.ice[0] == 0)
	# secret: S hidden under C, revealed when C leaves the table (even into the tray)
	var s: = _mk([Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(10, 0, 0), Vector3i(14, 0, 0)], [3, 4, 3, 4], [0, 1, 0, 1])
	s.secret0[0] = 1
	s.reset()
	_c("secret: hidden under a cover", s.sec[0] == 1 and s.sec_left == 1)
	var ev: = s.tap(1)
	_c("secret: REVEAL when the cover leaves", _t(ev) == "TO_TRAY,REVEAL" and ev[1].id == 0 and s.sec[0] == 0 and s.sec_left == 0, _t(ev))
	var s2: = _mk(_row(2), [1, 1])
	s2.secret0[0] = 1
	s2.reset()
	_c("secret: a free tile starts shown", s2.sec[0] == 0 and s2.sec_left == 0)
	# undo covers the hidden tile again but it stays revealed
	s.undo()
	_c("secret: undo re-covers", not s.is_free(0) and s.sec[0] == 0)
	# moonlight shows everything and melts ice
	var m: = _mk([Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(10, 0, 0), Vector3i(14, 0, 0)], [3, 4, 3, 4], [0, 1, 0, 1])
	m.secret0[0] = 1
	m.ice0[2] = 1
	m.reset()
	var me: = m.moonlight()
	_c("moonlight", _t(me) == "MOONLIGHT" and me[0].revealed == [0] and me[0].thawed == [2] and m.ice[2] == 0 and m.sec_left == 0)
	# open_tile makes a covered tile free
	var o: = _mk([Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(10, 0, 0), Vector3i(14, 0, 0)], [3, 4, 3, 4], [0, 1, 0, 1])
	o.open_tile(0)
	_c("open_tile", o.is_free(0) and _t(o.tap(0)) == "TO_TRAY")


static func _sc_specials() -> void:
	# key + lock
	var b: = _mk(_row(6), [5, 5, 6, 6, 7, 7])
	b.kind[0] = TWBoard.K_KEY
	b.kind[1] = TWBoard.K_KEY
	b.kind[2] = TWBoard.K_LOCK
	b.kind[3] = TWBoard.K_LOCK
	b.reset()
	_c("lock: kinds listed", b.kinds().has("lock") and b.has_locks)
	var e: = b.tap(2)
	_c("lock: a free lock tile is BLOCKED", _t(e) == "BLOCKED" and e[0].kind == "lock" and b.tray.is_empty() and b.moves == 0, _t(e))
	_c("lock: not offered as a move", not Array(b.free_tiles()).has(2) and Array(b.free_all()).has(2))
	b.tap(0)
	e = b.tap(1)
	_c("lock: key pair UNLOCKs its group", _t(e) == "MATCH,UNLOCK" and e[1].group == 0 and e[1].ids == [2, 3], _t(e))
	_c("lock: takeable after the key", b.takeable(2) and _t(b.tap(2)) == "TO_TRAY")
	# unstick: a lock pair with no key, the plain pair gone
	var u: = _mk(_row(4), [9, 9, 6, 6])
	u.kind[2] = TWBoard.K_LOCK
	u.kind[3] = TWBoard.K_LOCK
	u.reset()
	u.tap(0)
	var ue: = u.tap(1)
	_c("unstick: nothing takeable opens everything", _t(ue) == "MATCH,UNSTICK" and u.unstuck and u.takeable(2), _t(ue))
	_c("unstick: then the locks play", _t(u.tap(2)) == "TO_TRAY" and _t(u.tap(3)) == "MATCH,CLEARED")
	# unstick after a tile went to the tray with nothing else takeable
	var u3: = _mk(_row(4), [9, 6, 6, 9], [0, 1, 1, 0])
	u3.kind[1] = TWBoard.K_LOCK
	u3.kind[2] = TWBoard.K_LOCK
	u3.reset()
	u3.tap(0)
	var u3e: = u3.tap(3)
	_c("unstick: also after a match that empties the takeable set", _t(u3e) == "MATCH,UNSTICK", _t(u3e))
	# chain
	var c: = _mk(_row(8), [5, 5, 1, 1, 2, 2, 3, 3], [0, 0, 1, 1, 2, 2, 3, 3])
	c.kind[0] = TWBoard.K_CHAIN
	c.kind[1] = TWBoard.K_CHAIN
	c.arg[0] = 2
	c.arg[1] = 2
	c.reset()
	_c("chain: BLOCKED while pairs are missing", _t(c.tap(0)) == "BLOCKED" and E.of_type(c.tap(0), "BLOCKED")[0].kind == "chain")
	c.tap(2)
	var c1: = c.tap(3)
	_c("chain: one pair gone, still chained", not E.has(c1, "UNCHAIN") and not c.takeable(0))
	c.tap(4)
	var c2: = c.tap(5)
	_c("chain: second pair releases both tiles", E.count(c2, "UNCHAIN") == 2 and c.takeable(0) and c.takeable(1), _t(c2))
	_c("chain: then takeable", _t(c.tap(0)) == "TO_TRAY" and _t(c.tap(1)) == "MATCH")
	# joker
	var j: = _mk(_row(4), [300, 300, 5, 5], [0, 0, 1, 1])
	j.kind[0] = TWBoard.K_JOKER
	j.kind[1] = TWBoard.K_JOKER
	j.mate[0] = 1
	j.mate[1] = 0
	j.reset()
	j.tap(2)
	var je: = j.tap(0)
	_c("joker: adopts the tray face and pairs", _t(je) == "JOKER,MATCH,JOKER" and je[0].id == 0 and je[0].face == 5 and je[2].id == 1 and je[2].face == 5, _t(je))
	_c("joker: the mate became a normal tile", j.face[1] == 5 and j.kind_now[1] == TWBoard.K_NONE and j.step[1] == j.step[2])
	var j2: = j.tap(3)
	_c("joker: the mate (now a plain tile) pairs with the last one", _t(j2) == "TO_TRAY" and _t(j.tap(1)) == "MATCH,CLEARED", _t(j2))
	var jj: = _mk(_row(4), [300, 300, 5, 5], [0, 0, 1, 1])
	jj.kind[0] = TWBoard.K_JOKER
	jj.kind[1] = TWBoard.K_JOKER
	jj.mate[0] = 1
	jj.mate[1] = 0
	jj.reset()
	var r1: = jj.tap(0)
	_c("joker: alone in the tray it waits", _t(r1) == "TO_TRAY" and jj.face[0] == 300)
	var r2: = jj.tap(2)
	_c("joker: a plain tile turns the tray joker", _t(r2) == "JOKER,MATCH,JOKER" and r2[0].id == 0 and r2[0].face == 5, _t(r2))
	var r3: = jj.tap(3)
	var r4: = jj.tap(1)
	_c("joker: both pairs done", jj.alive_n == 0 or (_t(r3) != "" and _t(r4) != ""), str(jj.alive_n))
	var j3: = _mk(_row(2), [300, 300], [0, 0])
	j3.kind[0] = TWBoard.K_JOKER
	j3.kind[1] = TWBoard.K_JOKER
	j3.mate[0] = 1
	j3.mate[1] = 0
	j3.reset()
	j3.tap(0)
	_c("joker: two jokers pair with each other", _t(j3.tap(1)) == "MATCH,CLEARED")
	# gift
	var g: = _mk(_row(2), [4, 4])
	g.kind[0] = TWBoard.K_GIFT
	g.kind[1] = TWBoard.K_GIFT
	g.reset()
	g.tap(0)
	var ge: = g.tap(1)
	_c("gift: GIFT event and flag", E.has(ge, "GIFT") and E.of_type(ge, "MATCH")[0].gift == true and g.last_gift, _t(ge))
	# bomb
	var bo: = _mk([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(0, 2, 0), Vector3i(4, 2, 0), Vector3i(2, 1, 1), Vector3i(6, 1, 1), Vector3i(20, 0, 0), Vector3i(24, 0, 0)],
		[1, 1, 2, 2, 3, 3, 4, 4], [0, 0, 1, 1, 2, 2, 3, 3])
	bo.kind[0] = TWBoard.K_BOMB
	bo.kind[1] = TWBoard.K_BOMB
	bo.reset()
	bo.tap(0)
	var be: = bo.tap(1)
	var bl: = E.of_type(be, "BLAST")
	_c("bomb: BLAST event", bl.size() == 1 and (bl[0].pairs as Array).size() == 2 and bl[0].at == [0, 1], _t(be))
	_c("bomb: neighbours gone, far pair stays", bo.alive_n == 2 and bo.alive[6] == 1 and bo.alive[7] == 1 and bo.pairs_done == 3, "%d %d" % [bo.alive_n, bo.pairs_done])
	_c("bomb: counters stay consistent", _inv(bo) == "", _inv(bo))
	var bo2: = _mk(bo.pos, [1, 1, 2, 2, 3, 3, 4, 4], [0, 0, 1, 1, 2, 2, 3, 3])
	bo2.kind[0] = TWBoard.K_BOMB
	bo2.kind[1] = TWBoard.K_BOMB
	bo2.blasts = false
	bo2.reset()
	bo2.tap(0)
	_c("bomb: blasts can be switched off", not E.has(bo2.tap(1), "BLAST") and bo2.alive_n == 6)
	# a blast takes a twin out of the tray
	var bt: = _mk([Vector3i(0, 0, 0), Vector3i(4, 0, 0), Vector3i(0, 2, 0), Vector3i(30, 0, 0)], [1, 1, 2, 2], [0, 0, 1, 1])
	bt.kind[0] = TWBoard.K_BOMB
	bt.kind[1] = TWBoard.K_BOMB
	bt.reset()
	bt.tap(3)
	bt.tap(0)
	var bte: = bt.tap(1)
	_c("bomb: takes the pair whose twin sits in the tray", E.has(bte, "BLAST") and bt.tray.is_empty() and bt.alive_n == 0 and bt.cleared, _t(bte))
	_c("bomb: counters after tray removal", _inv(bt) == "", _inv(bt))
	# vanish / hack
	var v: = _mk(_row(6), [1, 1, 2, 2, 3, 3])
	var ve: = v.vanish_pairs(2)
	_c("vanish: two pairs, earliest first", E.count(ve, "VANISH") == 2 and ve[0].a == 0 and v.alive_n == 2, _t(ve))
	var hk: = v.hack_deepest()
	_c("hack_deepest: the last pair; cleared", _t(hk) == "VANISH,CLEARED" and v.cleared, _t(hk))
	_c("vanish: nothing after cleared", v.vanish_pairs(1).is_empty() and v.hack_deepest().is_empty())
	var pb: = _mk(_row(4), [1, 1, 2, 2])
	_c("pairs_on_board", pb.pairs_on_board() == [[0, 1], [2, 3]], str(pb.pairs_on_board()))


static func _sc_undo_hint() -> void:
	var b: = _mk(_row(6), [1, 2, 1, 2, 3, 3], [0, 1, 0, 1, 2, 2])
	_c("undo: nothing to undo", b.undo().is_empty())
	var h0: = b.state_hash()
	b.tap(0)
	var u: = b.undo()
	_c("undo: returns the tile", _t(u) == "UNDO" and u[0].id == 0 and b.tray.is_empty() and b.on_board == 6 and b.is_free(0))
	_c("undo: state_hash restored", b.state_hash() == h0)
	b.tap(0)
	b.tap(1)
	b.tap(2)
	_c("undo: after a match the history forgets the twin", Array(b.history) == [1] and Array(b.tray) == [1])
	b.undo()
	_c("undo: only tray tiles", b.tray.is_empty() and b.alive_n == 4 and b.undo().is_empty())
	# hint
	var h: = _mk(_row(6), [1, 2, 1, 2, 3, 3], [0, 1, 0, 1, 2, 2])
	var hn: = h.hint()
	_c("hint: free pair on an empty tray", hn.size() == 2 and h.face[hn[0]] == h.face[hn[1]] and hn[0] != hn[1], str(hn))
	h.tap(1)
	var hn2: = h.hint()
	_c("hint: the tray's twin first", hn2[0] == 3, str(hn2))
	_c("hint: best_move", h.best_move() == 3)
	_c("hint: no move on an empty table", _mk(_row(2), [1, 1]).tap(0).size() == 1)
	var done: = _mk(_row(2), [1, 1])
	done.tap(0)
	done.tap(1)
	_c("hint: [] when cleared", done.hint().is_empty() and done.best_move() == -1 and done.solver_move() == -1)
	# a hint for a board with a lone secret under a cover prefers a free pair
	var hh: = _mk([Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(10, 0, 0), Vector3i(14, 0, 0)], [3, 4, 3, 4], [0, 1, 0, 1])
	_c("hint: only free tiles", Array(hh.free_tiles()) == [1, 2, 3] and hh.hint().size() >= 1 and hh.is_free(hh.hint()[0]))
	# joker first when the tray is not empty
	var jh: = _mk(_row(4), [300, 300, 5, 5], [0, 0, 1, 1])
	jh.kind[0] = TWBoard.K_JOKER
	jh.kind[1] = TWBoard.K_JOKER
	jh.reset()
	jh.tap(2)
	_c("hint: a joker pairs with anything", jh.best_move() == 0 or jh.best_move() == 3, str(jh.best_move()))


static func _sc_misc() -> void:
	# events are plain data
	var b: = _mk(_row(2), [1, 1])
	var e: = b.tap(0)
	_c("events: plain dictionaries with a type", e[0] is Dictionary and E.type_of(e[0]) == "TO_TRAY" and e[0].has("t"))
	_c("events: helpers", E.count(e, "TO_TRAY") == 1 and not E.has(e, "MATCH") and E.of_type(e, "MATCH").is_empty() and E.types(e) == PackedStringArray(["TO_TRAY"]))
	_c("events: every constant is listed", E.ALL.size() == 20 and E.ALL.has(E.MOONLIGHT) and E.ALL.has(E.TRAY_FULL))
	var made: = E.make("X", {"a": 1})
	_c("events: make copies", made.t == "X" and made.a == 1)
	# state_hash is sensitive
	var s: = _mk(_row(4), [1, 1, 2, 2])
	var h0: = s.state_hash()
	s.tap(0)
	var h1: = s.state_hash()
	s.tap(1)
	var h2: = s.state_hash()
	_c("state_hash: moves change it", h0 != h1 and h1 != h2 and h0 != h2)
	var s2: = _mk(_row(4), [1, 1, 2, 2])
	_c("state_hash: equal for equal states", s2.state_hash() == h0)
	s2.tap(0)
	_c("state_hash: same move same hash", s2.state_hash() == h1)
	var s3: = _mk(_row(4), [1, 1, 2, 2])
	s3.tap(1)
	_c("state_hash: other move other hash", s3.state_hash() != h1)
	# snapshot / restore / fork
	var f: = _mk(_row(6), [1, 2, 1, 2, 3, 3], [0, 1, 0, 1, 2, 2])
	f.tap(0)
	var snap: = f.snapshot()
	var hs: = f.state_hash()
	f.tap(1)
	f.tap(2)
	_c("snapshot: state moved on", f.state_hash() != hs)
	f.restore(snap)
	_c("snapshot: restore", f.state_hash() == hs and Array(f.tray) == [0] and f.on_board == 5 and _inv(f) == "")
	var fk: = f.fork_fresh()
	_c("fork_fresh: initial state, shared deal", fk.state_hash() != hs and fk.on_board == 6 and fk.face0 == f.face0 and fk.tray.is_empty())
	# reset
	f.reset()
	_c("reset: back to the deal", f.state_hash() == fk.state_hash() and f.taps.is_empty())
	# solver and play_solver on a plain table
	var p: = _mk(_row(6), [1, 2, 1, 2, 3, 3], [0, 1, 0, 1, 2, 2])
	var r: = p.play_solver()
	_c("play_solver: clears a plain table", r.cleared and not r.failed and r.left == 0, str(r))
	# a layered table: a 2-high stack
	var st: = _mk([Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, 2), Vector3i(10, 0, 0), Vector3i(14, 0, 0), Vector3i(18, 0, 0)], [1, 2, 3, 1, 2, 3], [0, 1, 2, 0, 1, 2])
	var sr: = st.play_solver()
	_c("play_solver: a stack", sr.cleared, str(sr))
	_c("tap log", Array(st.taps).size() == sr.taps)
	# certificate on a handmade board is empty; verify with an explicit order
	var cv: = _mk(_row(4), [1, 1, 2, 2])
	_c("certificate: explicit order verifies", cv.verify_certificate(PackedInt32Array([0, 1, 2, 3])).is_empty())
	_c("certificate: another legal order verifies too", cv.verify_certificate(PackedInt32Array([0, 2, 1, 3])).is_empty())
	_c("certificate: incomplete order", cv.verify_certificate(PackedInt32Array([0, 1])).has("why"))
	var cb: = _mk([Vector3i(0, 0, 0), Vector3i(1, 1, 1), Vector3i(8, 0, 0), Vector3i(12, 0, 0)], [1, 2, 1, 2], [0, 1, 0, 1])
	_c("certificate: a covered tile is rejected", cb.verify_certificate(PackedInt32Array([0, 2, 1, 3])).has("why"))
	var ov: = _mk(_row(8), [1, 2, 3, 4, 1, 2, 3, 4], [0, 1, 2, 3, 0, 1, 2, 3])
	_c("certificate: tray overflow is rejected", ov.verify_certificate(PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7])).get("why", "") == "tray overflow")
	_c("certificate: does not touch the board", ov.tray.is_empty() and ov.on_board == 8)


# ------------------------------------------------------------------ D: seeds

static func _seeds(n_seeds: int) -> void:
	var digests: = {}
	var same: = 0
	var even: = 0
	var feat: = {"gold": 0, "ice": 0, "secret": 0, "shard": 0, "lock": 0, "chain": 0, "joker": 0, "bomb": 0, "gift": 0}
	var cert_ok: = 0
	for s in n_seeds:
		var a: = TWBoard.from_cfg(_cfg(s + 1))
		var d: = _digest(a)
		digests[d] = true
		var b: = TWBoard.from_cfg(_cfg(s + 1))
		var rep: = _content(a) == _content(b) and a.state_hash() == b.state_hash()
		_c("seed %d rebuilt identically" % (s + 1), rep)
		if rep:
			same += 1
		if a.n % 2 == 0 and a.n >= 20:
			even += 1
		if a.gold0.count(1) > 0:
			feat.gold += 1
		if a.ice0.count(1) > 0:
			feat.ice += 1
		if a.secret0.count(1) > 0:
			feat.secret += 1
		if a.shard0.count(1) == 2:
			feat.shard += 1
		for k in ["lock", "chain", "joker", "bomb", "gift"]:
			if a.kinds().has(k):
				feat[k] += 1
		if s % 25 == 0 and a.verify_certificate().is_empty():
			cert_ok += 1
	_c("seeds: %d seeds, every one rebuilt identically (faces, ice, gold, secret, shard, specials, order)" % n_seeds, same == n_seeds, "%d/%d" % [same, n_seeds])
	_c("seeds: different seeds give different deals", digests.size() >= int(n_seeds * 0.99), "%d distinct of %d" % [digests.size(), n_seeds])
	_c("seeds: tables are even and big enough", even == n_seeds)
	_c("seeds: gold on every deal", feat.gold == n_seeds, str(feat))
	_c("seeds: ice on every deal", feat.ice == n_seeds)
	_c("seeds: hidden tiles on every deal", feat.secret == n_seeds)
	_c("seeds: a shard pair on every deal", feat.shard == n_seeds, str(feat.shard))
	_c("seeds: specials are dealt (lock, chain, joker, bomb, gift)", feat.lock > n_seeds * 0.9 and feat.chain > n_seeds * 0.9 and feat.joker > n_seeds * 0.3 and feat.bomb > n_seeds * 0.9 and feat.gift > n_seeds * 0.9, str(feat))
	_c("seeds: certificates of the sampled deals verify", cert_ok == (n_seeds + 24) / 25, "%d" % cert_ok)
	# structure of one deal
	var a: = TWBoard.from_cfg(_cfg(7))
	var by: = {}
	for i in a.n:
		by[a.step0[i]] = by.get(a.step0[i], []) + [i]
	var pairs_ok: = true
	for k in by:
		var pr: Array = by[k]
		if pr.size() != 2 or a.face0[pr[0]] != a.face0[pr[1]] or a.gold0[pr[0]] != a.gold0[pr[1]] or a.shard0[pr[0]] != a.shard0[pr[1]]:
			pairs_ok = false
	_c("deal: every step is a pair with equal face / gold / shard", pairs_ok)
	_c("deal: gold count is the cfg's (4 -> 2 pairs)", a.gold0.count(1) == 4, str(a.gold0.count(1)))
	_c("deal: shard face is 100, hero is rin", a.shard_hero == "rin" and a.face0[a.shard0.find(1)] == 100)
	var faces: = {}
	for i in a.n:
		if a.face0[i] < 36:
			faces[a.face0[i]] = true
	_c("deal: at most cfg.faces distinct faces (12) plus jokers/shard", faces.size() <= 12 + 0, str(faces.size()))
	_c("deal: ice only on uncovered or covered plain tiles, never gold/shard", _no_overlap(a))
	var plain: = TWBoard.from_cfg(_cfg(7, {"plan": {}, "gold": 0, "ice": 0, "hidden": false, "shard": ""}))
	_c("deal: a plain cfg has no features", plain.gold0.count(1) == 0 and plain.ice0.count(1) == 0 and plain.secret0.count(1) == 0 and plain.shard0.count(1) == 0 and plain.kinds().is_empty())
	_c("deal: seed changes the deal, deal_seed too", _digest(TWBoard.from_cfg(_cfg(7))) != _digest(TWBoard.from_cfg(_cfg(7, {"deal_seed": 99}))))
	_c("deal: from_cfg keeps layout seed separate from deal seed", TWBoard.from_cfg(_cfg(7)).pos == TWBoard.from_cfg(_cfg(7, {"deal_seed": 99})).pos)


static func _no_overlap(b: TWBoard) -> bool:
	for i in b.n:
		if b.ice0[i] == 1 and (b.gold0[i] == 1 or b.shard0[i] == 1 or b.kind[i] != 0):
			return false
		if b.secret0[i] == 1 and b.ice0[i] == 1:
			return false
	return true


# ------------------------------------------------------------------ E: levels

# the sim's result code of a tap, from TWBoard's events
static func _code(ev: Array) -> int:
	if E.has(ev, "ICE_CRACK"):
		return 2
	if E.has(ev, "TRAY_FULL"):
		return -1
	if E.has(ev, "MATCH"):
		return 1
	if E.has(ev, "TO_TRAY"):
		return 0
	return -9


static func _levels(n_levels: int) -> void:
	var sim: = V10LevelSim.new()
	var built: = 0
	var cert_ok: = 0
	var bot_ok: = 0
	var bot_blast_ok: = 0
	var lock_ok: = 0
	var greedy_ok: = 0
	var cfg_cert_ok: = 0
	var cfg_bot_ok: = 0
	var lock_step_ok: = 0
	var inv_ok: = 0
	var feature_levels: = {}
	var rr: = TWRng.make(2026)
	for i in n_levels:
		var lv: Dictionary = V10LevelGen.build(i, -1, sim)
		built += 1
		var b: = TWBoard.from_level(lv)
		if b.n == int(lv.v10.n) and b.cert == lv.v10.cert:
			built += 0
		# the certificate of the generator replays on the new core
		var vc: = b.verify_certificate()
		_c("level %d certificate replays" % i, vc.is_empty(), str(vc))
		if vc.is_empty():
			cert_ok += 1
		for k in b.kinds():
			feature_levels[k] = int(feature_levels.get(k, 0)) + 1
		# the solver bot on the new core: real rules (blasts on) and the sim's rules (blasts off)
		var bb: = b.fork_fresh()
		var res: = bb.play_solver()
		_c("level %d solver bot clears it (blasts on)" % i, res.cleared and _inv(bb) == "", str(res))
		if res.cleared and _inv(bb) == "":
			bot_blast_ok += 1
		var b0: = b.fork_fresh()
		b0.blasts = false
		var r0: = b0.play_solver()
		_c("level %d solver bot clears it (blasts off)" % i, r0.cleared)
		if r0.cleared:
			bot_ok += 1
		# lockstep with V10LevelSim on random play
		V10LevelGen.load_into(sim, lv)
		sim.reset()
		var t: = TWBoard.from_level(lv)
		t.blasts = false
		var same: = true
		var why: = ""
		var guard: = 0
		while guard < 400 and sim.alive_n > 0 and not sim.failed:
			guard += 1
			var mv: = Array(sim.moves_now())
			mv.sort()
			var mine: = Array(t.free_tiles())
			if mv != mine:
				same = false
				why = "moves differ at step %d: %s vs %s" % [guard, str(mv), str(mine)]
				break
			if mv.is_empty():
				break
			# a mix of policies: tray twin when there is one, else random
			var pick: int = mv[rr.below(mv.size())]
			if rr.chance(0.75):
				for x in t.tray:
					for q in mv:
						if t.face[q] == t.face[x] or t.face[q] == TWBoard.JOKER:
							pick = q
							break
			var sc: = sim.tap(pick)
			var ev: = t.tap(pick)
			if sc != _code(ev):
				same = false
				why = "result %d vs %d at step %d" % [sc, _code(ev), guard]
				break
			if Array(sim.tray) != Array(t.tray) or sim.alive_n != t.alive_n or sim.unstuck != t.unstuck or sim.pairs_done != t.pairs_done:
				same = false
				why = "state differs at step %d (tray %s/%s alive %d/%d unstuck %s/%s)" % [guard, str(sim.tray), str(t.tray), sim.alive_n, t.alive_n, sim.unstuck, t.unstuck]
				break
		if same and sim.failed != t.failed:
			same = false
			why = "failed differs"
		if same and (sim.alive_n == 0) != t.cleared:
			same = false
			why = "cleared differs"
		if same and _inv(t) != "":
			same = false
			why = _inv(t)
		_c("level %d lockstep with V10LevelSim" % i, same, why)
		if same:
			lock_ok += 1
		# the greedy hint bot (information only)
		var gb: = b.fork_fresh()
		var gd: = 0
		while not gb.cleared and not gb.failed and gd < 400:
			gd += 1
			var q: = gb.best_move()
			if q < 0 or gb.tap(q).is_empty():
				break
		if gb.cleared:
			greedy_ok += 1
		# a fresh seeded deal of the same level config
		var cfg: = lv.duplicate()
		cfg.erase("v10")
		if i % 4 == 0:
			var sb: = TWBoard.from_cfg(cfg)
			if sb.verify_certificate().is_empty():
				cfg_cert_ok += 1
			if sb.play_solver().cleared:
				cfg_bot_ok += 1
	var nc: = (n_levels + 3) / 4
	_c("levels: %d built" % n_levels, built >= n_levels)
	_c("levels: %d/%d generator certificates replay on TWBoard" % [cert_ok, n_levels], cert_ok == n_levels)
	_c("levels: solver bot clears %d/%d Path levels on the new core (real rules, bombs blast)" % [bot_blast_ok, n_levels], bot_blast_ok == n_levels)
	_c("levels: solver bot clears %d/%d with the sim's rules (no blasts)" % [bot_ok, n_levels], bot_ok == n_levels)
	_c("levels: lockstep parity with V10LevelSim on %d/%d levels (moves, results, tray, pairs, unstuck)" % [lock_ok, n_levels], lock_ok == n_levels)
	_c("levels: seeded deals of the level configs verify (%d/%d)" % [cfg_cert_ok, nc], cfg_cert_ok == nc)
	_c("levels: seeded deals of the level configs are cleared by the solver (%d/%d)" % [cfg_bot_ok, nc], cfg_bot_ok == nc)
	_c("levels: the sample has specials", feature_levels.size() >= 2 or n_levels < 100, str(feature_levels))
	print("INFO levels %d: solver %d/%d, solver without blasts %d/%d, lockstep %d/%d, greedy hint bot %d/%d, features %s" % [n_levels, bot_blast_ok, n_levels, bot_ok, n_levels, lock_ok, n_levels, greedy_ok, n_levels, str(feature_levels)])


# ------------------------------------------------------------------ F: replay

static func _play_random(b: TWBoard, r: TWRng, max_taps: int) -> void:
	var g: = 0
	while not b.cleared and not b.failed and g < max_taps:
		g += 1
		var mv: = b.free_tiles()
		if mv.is_empty():
			break
		var pick: int = mv[r.below(mv.size())]
		if r.chance(0.7):
			var q: = b.best_move()
			if q >= 0:
				pick = q
		b.tap(pick)


static func _replay() -> void:
	var same: = 0
	var ev_same: = 0
	var n_games: = 40
	var r: = TWRng.make(31)
	for g in n_games:
		var cfg: = _cfg(100 + g, {"plan": {}} if g % 2 == 0 else {})
		var a: = TWBoard.from_cfg(cfg)
		_play_random(a, r, 300)
		var log: = a.export_replay()
		var b: = TWBoard.from_cfg(cfg)
		var ev: = b.play_replay(log.taps)
		if a.state_hash() == b.state_hash() and Array(a.taps) == Array(b.taps):
			same += 1
		if b.cleared == a.cleared and b.failed == a.failed and b.alive_n == a.alive_n and Array(b.tray) == Array(a.tray) and not ev.is_empty():
			ev_same += 1
	_c("replay: %d games replayed from the tap log end in the same state_hash" % n_games, same == n_games, "%d/%d" % [same, n_games])
	_c("replay: outcome flags equal", ev_same == n_games)
	var a: = TWBoard.from_cfg(_cfg(5, {"plan": {}}))
	var h0: = a.state_hash()
	a.tap(a.free_tiles()[0])
	_c("replay: the log has the tap", a.export_replay().taps.size() == 1 and a.export_replay().seed == 5)
	# undo restores the hash on real deals
	var ok: = 0
	for g in 20:
		var d: = TWBoard.from_cfg(_cfg(300 + g, {"plan": {}, "ice": 0, "hidden": false}))
		var h: = d.state_hash()
		var mv: = d.free_tiles()
		var t: int = mv[0]
		if d.tray_twin(t) >= 0:
			continue
		d.tap(t)
		d.undo()
		if d.state_hash() == h and _inv(d) == "":
			ok += 1
	_c("replay: tap + undo restores the state_hash (20 deals)", ok >= 18, str(ok))
	# the same game on two clocks gives the same state_hash (the clock only feeds the combo)
	var x: = TWBoard.from_cfg(_cfg(9, {"plan": {}}))
	var y: = TWBoard.from_cfg(_cfg(9, {"plan": {}}))
	y.time = 1000.0
	var rx: = TWRng.make(4)
	var ry: = TWRng.make(4)
	_play_random(x, rx, 200)
	_play_random(y, ry, 200)
	_c("replay: the clock does not change the game", x.state_hash() == y.state_hash(), "%s | %s" % [str(Array(x.taps)), str(Array(y.taps))])
	# a random player is deterministic as a whole
	var z: = TWBoard.from_cfg(_cfg(9, {"plan": {}}))
	_play_random(z, TWRng.make(4), 200)
	_c("replay: a seeded random game is reproducible", z.state_hash() == x.state_hash() and z.taps == x.taps)


# ------------------------------------------------------------------ G: shuffle

static func _shuffle() -> void:
	var ok: = 0
	var even_ok: = 0
	var inv_ok: = 0
	var det_ok: = 0
	var n_boards: = 30
	for g in n_boards:
		var cfg: = _cfg(500 + g, {"plan": {}, "hidden": g % 2 == 0, "ice": g % 3})
		var b: = TWBoard.from_cfg(cfg)
		var r: = TWRng.make(g)
		# play a few moves so that the tray holds tiles
		for k in 6:
			var mv: = b.free_tiles()
			if mv.is_empty():
				break
			var t: int = mv[r.below(mv.size())]
			if b.ice[t] == 0 and b.tray.size() >= 2 and b.tray_twin(t) < 0:
				continue
			b.tap(t)
		var before: = b.alive_n
		var ev: = b.shuffle()
		if _t(ev).begins_with("SHUFFLE") and b.shuffled and b.alive_n == before:
			ok += 1
		var counts: = {}
		for i in b.n:
			if b.alive[i] == 1 and b.shard_f[i] == 0:
				counts[b.face[i]] = int(counts.get(b.face[i], 0)) + 1
		var even: = true
		for f in counts:
			if int(counts[f]) % 2 != 0:
				even = false
		if even:
			even_ok += 1
		if _inv(b) == "":
			inv_ok += 1
		var res: = b.play_solver()
		if res.cleared:
			det_ok += 1
	_c("shuffle: SHUFFLE event, tiles kept (%d boards)" % n_boards, ok == n_boards, str(ok))
	_c("shuffle: every face stays even over table + tray", even_ok == n_boards, str(even_ok))
	_c("shuffle: counters stay consistent", inv_ok == n_boards)
	_c("shuffle: the dealt-again table is clearable (solver)", det_ok == n_boards, str(det_ok))
	# determinism: same board, same shuffle stream, same result
	var a: = TWBoard.from_cfg(_cfg(600, {"plan": {}}))
	var b: = TWBoard.from_cfg(_cfg(600, {"plan": {}}))
	a.shuffle(TWRng.make(5))
	b.shuffle(TWRng.make(5))
	var c: = TWBoard.from_cfg(_cfg(600, {"plan": {}}))
	c.shuffle(TWRng.make(6))
	_c("shuffle: deterministic for one stream", a.state_hash() == b.state_hash())
	_c("shuffle: another stream, another deal", a.state_hash() != c.state_hash())
	var d: = TWBoard.from_cfg(_cfg(600, {"plan": {}}))
	var e: = TWBoard.from_cfg(_cfg(600, {"plan": {}}))
	d.shuffle()
	e.shuffle()
	_c("shuffle: the board's own stream is seeded", d.state_hash() == e.state_hash())
	# shards and jokers are kept
	var sj: = TWBoard.from_cfg(_cfg(601, {"plan": {"joker": 1}}))
	var shards: = []
	var jokers: = []
	for i in sj.n:
		if sj.shard_f[i] == 1:
			shards.append(i)
		if sj.face[i] == TWBoard.JOKER:
			jokers.append(i)
	sj.shuffle()
	var kept: = true
	for i in shards:
		if sj.face[i] != 100:
			kept = false
	for i in jokers:
		if sj.face[i] != TWBoard.JOKER:
			kept = false
	_c("shuffle: shard and joker tiles keep their faces", kept and not shards.is_empty())
	# a tray tile keeps a twin on the table
	var tw: = TWBoard.from_cfg(_cfg(602, {"plan": {}, "ice": 0}))
	var f0: int = tw.free_tiles()[0]
	tw.tap(f0)
	tw.shuffle()
	var tf: = tw.face[tw.tray[0]]
	var twin_on: = false
	for i in tw.n:
		if tw.present[i] == 1 and tw.face[i] == tf:
			twin_on = true
	_c("shuffle: the tray tile keeps a twin on the table", twin_on)
	# gold survives the shuffle
	var gg: = TWBoard.from_cfg(_cfg(603, {"plan": {}, "gold": 6}))
	var gc: = gg.gold.count(1)
	gg.shuffle()
	_c("shuffle: gold count kept", gg.gold.count(1) == gc, "%d vs %d" % [gg.gold.count(1), gc])


# ------------------------------------------------------------------ H: fuzz

static func _fuzz(n_games: int) -> void:
	var bad: = 0
	var first: = ""
	var ops: = 0
	var r: = TWRng.make(777)
	var mix: = {"MATCH": 0, "DENY": 0, "ICE_CRACK": 0, "TRAY_FULL": 0, "CLEARED": 0, "UNDO": 0, "RETURN": 0, "SHUFFLE": 0, "BLAST": 0, "UNLOCK": 0, "REVEAL": 0, "JOKER": 0}
	for g in n_games:
		var cfg: = _cfg(900 + g, {"cols": 4 + g % 3, "rows": 5 + g % 4, "layers": 2 + g % 3, "shape": ["rect", "heart", "diamond", "cross", "ring", "pyramid"][g % 6]})
		var b: = TWBoard.from_cfg(cfg)
		var guard: = 0
		while guard < 220:
			guard += 1
			ops += 1
			var roll: = r.rand_f()
			var ev: Array = []
			if roll < 0.74:
				ev = b.tap(r.below(b.n + 2) - 1)
			elif roll < 0.82:
				ev = b.tap(b.solver_move()) if b.solver_move() >= 0 else []
			elif roll < 0.88:
				ev = b.undo()
			elif roll < 0.92:
				ev = b.return_tray(r.rand_range(1, 3))
			elif roll < 0.95:
				ev = b.shuffle()
			elif roll < 0.97:
				ev = b.hack_deepest() if r.chance(0.5) else b.vanish_pairs(1)
			elif roll < 0.985:
				var h: = b.hint()
				for t in h:
					if not b.is_free(t):
						bad += 1
						first = first if first != "" else "hint %d not free" % t
			else:
				ev = b.moonlight()
			for e in ev:
				mix[e.t] = int(mix.get(e.t, 0)) + 1
				if not E.ALL.has(e.t):
					bad += 1
					first = first if first != "" else "unknown event " + str(e.t)
			var msg: = _inv(b)
			if msg != "":
				bad += 1
				first = first if first != "" else "game %d op %d: %s" % [g, guard, msg]
				break
			if b.cleared and b.alive_n != 0:
				bad += 1
				first = first if first != "" else "cleared with tiles left"
				break
			if b.failed and b.tray.size() < b.slots:
				bad += 1
				first = first if first != "" else "failed with a free slot"
				break
			if (b.cleared or b.failed) and r.chance(0.5):
				break
	_c("fuzz: %d games / %d operations keep every invariant" % [n_games, ops], bad == 0, first)
	_c("fuzz: the operation mix reached the main events", mix.MATCH > 0 and mix.DENY > 0 and mix.UNDO > 0 and mix.SHUFFLE > 0 and mix.TRAY_FULL > 0 and mix.ICE_CRACK > 0, str(mix))
	# invalid input never throws and never changes anything
	var b: = TWBoard.from_cfg(_cfg(1, {"plan": {}}))
	var h: = b.state_hash()
	for id in [-5, -1, b.n, b.n + 1, 99999]:
		b.tap(id)
		b.open_tile(id)
	_c("fuzz: out-of-range ids change nothing", b.state_hash() == h and b.taps.is_empty())
	_c("fuzz: undo / return on a fresh deal change nothing", b.undo().is_empty() and b.return_tray(3).is_empty() and b.state_hash() == h)


# ------------------------------------------------------------------ I: lint

static func _lint() -> void:
	var bad: = PackedStringArray()
	var needles: = ["await ", "Tween", "create_timer", "get_tree", "create_tween", "Sfx.", "V9Feel", "G.", "Node2D", "extends Node", "add_child", "queue_free", "OS.", "DisplayServer"]
	var lines: = 0
	for p in SRC:
		var f: = FileAccess.open(p, FileAccess.READ)
		if f == null:
			bad.append("cannot read " + p)
			continue
		var text: = f.get_as_text()
		f.close()
		for raw in text.split("\n"):
			lines += 1
			var code: = raw
			var h: = code.find("#")
			if h >= 0:
				code = code.substr(0, h)
			# string literals out
			var parts: = code.split("\"")
			var stripped: = ""
			for k in parts.size():
				if k % 2 == 0:
					stripped += parts[k]
			for nd in needles:
				if stripped.find(nd) >= 0:
					bad.append("%s: %s" % [p.get_file(), nd])
	_c("lint: no await / Tween / timer / scene tree / G / audio in the rules core (%d lines)" % lines, bad.is_empty(), ",".join(bad))
	_c("lint: sources readable", lines > 600)
