class_name TWParityLegacy
extends RefCounted

# P17 (WP5), the SHELL side of the TWBoard parity proof: everything that needs the real legacy TrayBoard (a Node2D with tweens,
# timers and the unseeded _assign). core/ must not touch it (CORE_PURITY), so the oracle lives here:
#
#   record_all(host, n, dir)   plays n games on the REAL TrayBoard (tap / undo / return_tray / shuffle_board / auto_pairs /
#                              hack_deepest / moonlight / best_move), writes the deal (layout, faces, ice, gold, secret, shard)
#                              and the journal (every operation + the state the legacy showed after it) into
#                              tests/fixtures/replays/corpus_NN.json. Run it with scripts/v10/rules/parity_record.tscn.
#   fuzz(host, n_moves)        the same operations on a live TrayBoard in lockstep with a TWBoard built from the legacy deal:
#                              after EVERY operation the free set (legacy is_free == TWBoard counters == TWFree.is_free), the
#                              tray, the counters and the result must be identical.
#
# Timing: the legacy resolves a match 0.24 s + 0.2 s after the tap and a full tray after 0.45 s (Tween / await). The journal is
# driven under Engine.time_scale and every operation waits until nothing is pending / flipping, so what is compared is the RULE
# (legality, tray, outcome), never an animation race. The combo clock is virtual: RecBoard.now() returns a value the recorder sets
# before each tap (quarter-second grid, so the 5 s window boundary is hit exactly and the JSON round trip is exact).

const CORPUS_DIR: = "res://tests/fixtures/replays/"
const SHAPES: = ["rect", "rect", "rect", "heart", "diamond", "butterfly", "cross", "ring", "pyramid", "towers", "hourglass", "arch",
	"flower", "crown", "bowl", "lantern", "frame", "chevron", "star", "torii", "islands", "moon", "fan", "pagoda", "gem", "wings"]
const UPPERS: = ["", "", "peak", "walls", "checker", "rows", "ring"]
const MODES: = ["greedy", "random", "solver", "chaos", "careful"]
const TIME_SCALE: = 60.0


class RecBoard extends TrayBoard:
	var vclock: = 0.0
	var idx: = {}
	var n_denied: = 0
	var last_free: Array = []

	func now() -> float:
		return vclock


# ------------------------------------------------------------------ configs

static func _shard_heroes() -> Array:
	var out: = []
	for i in range(0, 1000, 25):
		var h: = str(TWLevels.at(i).get("shard", ""))
		if h != "" and not out.has(h):
			out.append(h)
	return out


# the board config of game number gi (deterministic): 60% a real Path level of the 1000, 40% a synthetic config that stresses shapes,
# upper patterns, gold / ice / hidden / shard counts, slots and sizes
static func make_cfg(gi: int, heroes: Array) -> Dictionary:
	var rg: = RandomNumberGenerator.new()
	rg.seed = 424200 + gi * 7919
	var cfg: = {}
	var slots: int = [3, 4, 4, 4, 4, 5, 6][rg.randi() % 7]
	var code: = ""
	if rg.randf() < 0.6:
		var li: = (gi * 127 + 13 + rg.randi() % 40) % TWLevels.count()
		var lv: Dictionary = TWLevels.at(li)
		for k in ["cols", "rows", "layers", "fill", "shape", "upper", "seed", "faces", "shard", "gold", "ice", "hidden"]:
			if lv.has(k):
				cfg[k] = lv[k]
		code = str(lv.get("code", "L%d" % li))
	else:
		cfg = {
			"cols": rg.randi_range(3, 7), "rows": rg.randi_range(3, 9), "layers": rg.randi_range(1, 5),
			"fill": snappedf(rg.randf_range(0.4, 0.92), 0.01), "shape": SHAPES[rg.randi() % SHAPES.size()],
			"upper": UPPERS[rg.randi() % UPPERS.size()], "faces": rg.randi_range(3, 16), "gold": rg.randi_range(0, 3) * 2,
			"ice": rg.randi_range(0, 8), "hidden": rg.randf() < 0.35, "seed": rg.randi() % 100000,
			"shard": heroes[rg.randi() % heroes.size()] if (rg.randf() < 0.3 and not heroes.is_empty()) else "",
		}
		code = "S%d" % gi
	# a table of at least a few pairs, whatever the shape does to a small grid
	var tries: = 0
	while TWFree.gen_layout(cfg).size() < 8 and tries < 20:
		cfg.seed = int(cfg.get("seed", 1)) + 1
		cfg.cols = int(cfg.cols) + (1 if tries % 2 == 0 else 0)
		cfg.rows = int(cfg.rows) + (1 if tries % 2 == 1 else 0)
		tries += 1
	cfg["slots"] = slots
	cfg["code"] = code
	return cfg


# ------------------------------------------------------------------ the legacy board, headless

static func open_board(host: Node, cfg: Dictionary) -> RecBoard:
	var b: = RecBoard.new()
	host.add_child(b)
	b.slots = int(cfg.get("slots", 4))
	var sp: Array[Vector2] = []
	for i in 8:
		sp.append(Vector2(100 + 90 * i, 900))
	b.slot_pos = sp
	b.slot_size = 80.0
	b.setup(cfg)
	b.input_on = true
	for i in b.tiles.size():
		b.idx[b.tiles[i]] = i
	b.denied.connect( func(_t): b.n_denied += 1)
	return b


static func close_board(host: Node, b: RecBoard) -> void:
	host.remove_child(b)
	b.queue_free()


# wait until no tile is pending (a match settling) or flipping (an ice / secret tile turning)
static func settle(b: RecBoard) -> void:
	var guard: = 0
	Engine.time_scale = TIME_SCALE
	while guard < 600:
		var busy: = false
		for t in b.tiles:
			if t.pending or t.flipping:
				busy = true
				break
		if not busy:
			break
		await b.get_tree().process_frame
		# the hit-stop of V6FX resets Engine.time_scale to 1.0 after a match: keep the fast clock
		Engine.time_scale = TIME_SCALE
		guard += 1



# the deal as the legacy made it (the corpus fixture of a game, without the journal)
static func capture_deal(b: RecBoard, cfg: Dictionary, gi: int) -> Dictionary:
	var pos: = []
	var face: = []
	var step: = []
	var gold: = []
	var ice: = []
	var sec: = []
	var shard: = []
	for t in b.tiles:
		pos.append_array([t.gx, t.gy, t.gz])
		face.append(t.face)
		step.append(t.step)
		gold.append(1 if t.gold else 0)
		ice.append(t.ice)
		sec.append(1 if t.secret else 0)
		shard.append(1 if t.shard != "" else 0)
	var keep: = {}
	for k in ["cols", "rows", "layers", "fill", "shape", "upper", "seed", "faces", "shard", "gold", "ice", "hidden"]:
		if cfg.has(k):
			keep[k] = cfg[k]
	var g: = {"g": gi, "code": str(cfg.get("code", "")), "slots": b.slots, "cfg": keep, "shard_hero": str(cfg.get("shard", "")),
		"n": b.tiles.size(), "pos": pos, "face": face, "step": step, "gold": gold, "ice": ice, "sec": sec, "shard": shard}
	var st: = state(b)
	g["free0"] = [st[5], st[6]]
	return g


static func state(b: RecBoard) -> Array:
	var fr: = []
	for t in b.free_tiles():
		fr.append(b.idx[t])
	b.last_free = fr
	var tr: = []
	for t in b.tray:
		tr.append(b.idx[t])
	return [b.board_count(), b.tray.size(), b.combo, b.cracks, b.max_tray, fr.size(), TWParitySelftest.fhash(fr), tr]


static func hint_class(b: RecBoard, t: Tile) -> int:
	if t == null:
		return 0
	for x in b.tray:
		if x.face == t.face:
			return 1
	for o in b.free_tiles():
		if o != t and o.face == t.face:
			return 2
	return 3


static func cleared(b: RecBoard) -> bool:
	return b.board_count() == 0 and b.tray.is_empty() and b.tiles.all( func(t): return not t.alive)


# ------------------------------------------------------------------ one operation on the real TrayBoard

# `op` is the journal entry (["t", id, vt], ["u"], ["r", 3], ["s", {}], ["v", k, []], ["h", []], ["m"], ["i", -1]); the recorded
# data is written into it. Returns the expectation [res, board, tray_n, combo, cracks, max_tray, free_n, free_hash, [tray ids]].
static func exec(b: RecBoard, op: Array) -> Array:
	var res: = 0
	match op[0]:
		"t":
			b.vclock = float(op[2])
			var t: Tile = b.tiles[int(op[1])]
			var den0: = b.n_denied
			var cr0: = b.cracks
			var was_on: = b.on_board(t)
			b.tap(t)
			if b.n_denied > den0:
				res = TWParitySelftest.K_DENY
			elif not was_on:
				res = TWParitySelftest.K_IGNORED
			elif b.cracks > cr0:
				res = TWParitySelftest.K_CRACK
			elif b.tray.has(t):
				res = TWParitySelftest.K_FULL if b.tray.size() >= b.slots else TWParitySelftest.K_TRAY
			elif not t.alive:
				res = TWParitySelftest.K_MATCH
			else:
				res = -1   # the legacy did something the kinds do not know: the replay will flag it
			if res == TWParitySelftest.K_FULL:
				await b.failed
		"u":
			res = 1 if b.undo() else 0
		"r":
			var before: = b.tray.size()
			b.return_tray(int(op[1]))
			res = before - b.tray.size()
		"s":
			b.shuffle_board()
			var rec: Dictionary = op[1]
			var f: = []
			var s: = []
			var g: = []
			for t in b.tiles:
				f.append(t.face)
				s.append(t.step)
				g.append(1 if t.gold else 0)
			rec["face"] = f
			rec["step"] = s
			rec["gold"] = g
		"v":
			var picks: Array = op[2]
			for q in int(op[1]):
				var ps: = b._pairs_on_board()
				if ps.is_empty():
					break
				b._vanish_pair(ps[0][0], ps[0][1])
				picks.append([b.idx[ps[0][0]], b.idx[ps[0][1]]])
			res = picks.size()
		"h":
			var alive0: = []
			for t in b.tiles:
				if b.on_board(t):
					alive0.append(t)
			b.hack_deepest()
			var pick: Array = op[1]
			for t in alive0:
				if not t.alive:
					pick.append(b.idx[t])
			res = pick.size() / 2
		"m":
			b.moonlight()
		"i":
			var t: Tile = b.best_move()
			op[1] = b.idx[t] if t != null else -1
			res = hint_class(b, t)
	await settle(b)
	var st: = state(b)
	return [res, st[0], st[1], st[2], st[3], st[4], st[5], st[6], st[7]]


# ------------------------------------------------------------------ the player: which operation next

static func pick_op(b: RecBoard, mode: String, rg: RandomNumberGenerator, vt: float) -> Array:
	var fr: Array = b.free_tiles()
	var r: = rg.randf()
	if mode == "chaos" or mode == "careful":
		var p_other: = 0.30 if mode == "chaos" else 0.10
		if r < p_other:
			var q: = rg.randf()
			if q < 0.30:
				return ["u"]
			if q < 0.42:
				return ["r", rg.randi_range(1, 3)]
			if q < 0.54:
				return ["s", {}]
			if q < 0.68:
				return ["v", rg.randi_range(1, 3), []]
			if q < 0.78:
				return ["h", []]
			if q < 0.86:
				return ["m"]
			return ["i", -1]
	elif mode == "solver" and r < 0.03:
		return ["u"]
	# a tap that must be denied / ignored
	if rg.randf() < 0.05:
		var off: = []
		var cov: = []
		for i in b.tiles.size():
			var t: Tile = b.tiles[i]
			if not b.on_board(t):
				off.append(i)
			elif not b.is_free(t):
				cov.append(i)
		if rg.randf() < 0.7 and not cov.is_empty():
			return ["t", cov[rg.randi() % cov.size()], vt]
		if not off.is_empty():
			return ["t", off[rg.randi() % off.size()], vt]
	if fr.is_empty():
		return ["i", -1]
	var pick: Tile = null
	match mode:
		"random":
			pick = fr[rg.randi() % fr.size()]
		"solver":
			pick = b.solver_move()
		"chaos":
			pick = fr[rg.randi() % fr.size()]
			for x in b.tray:
				for t in fr:
					if t.face == x.face and rg.randf() < 0.4:
						pick = t
		_:
			# greedy: a tray twin first, then a tile with a free twin, else any
			var want: = []
			for t in fr:
				for x in b.tray:
					if x.face == t.face:
						want.append(t)
						break
			if want.is_empty():
				for t in fr:
					for o in fr:
						if o != t and o.face == t.face:
							want.append(t)
							break
			pick = (want[rg.randi() % want.size()] if not want.is_empty() and rg.randf() < 0.92 else fr[rg.randi() % fr.size()])
	if pick == null:
		pick = fr[rg.randi() % fr.size()]
	return ["t", b.idx[pick], vt]


static func next_time(rg: RandomNumberGenerator, vt: float) -> float:
	var r: = rg.randf()
	if r < 0.65:
		return vt + rg.randi_range(2, 12) * 0.25
	if r < 0.85:
		return vt + [4.75, 5.0, 5.0, 5.25][rg.randi() % 4]
	return vt + rg.randi_range(24, 32) * 0.25


# ------------------------------------------------------------------ the corpus

static func play_game(host: Node, gi: int, heroes: Array) -> Dictionary:
	var rg: = RandomNumberGenerator.new()
	rg.seed = 31337 + gi
	seed(777000 + gi)   # the legacy _assign / reassign_faces use the engine RNG: seeded so the recording itself is reproducible
	var mode: String = MODES[rg.randi() % MODES.size()]
	var cfg: = make_cfg(gi, heroes)
	var b: = open_board(host, cfg)
	var g: = capture_deal(b, cfg, gi)
	g["mode"] = mode
	var ops: = []
	var exp: = []
	var vt: = 0.0
	var rescues: = 2
	var end: = "open"
	var guard: = 0
	while guard < 500:
		guard += 1
		var op: = []
		if b.tray.size() >= b.slots:
			# the tray is full: a rescue (return_tray / undo) or the game is lost
			if rescues > 0 and rg.randf() < 0.65:
				rescues -= 1
				op = ["r", 3] if rg.randf() < 0.6 else ["u"]
			else:
				end = "failed"
				break
		else:
			vt = next_time(rg, vt)
			op = pick_op(b, mode, rg, vt)
			if op[0] == "t":
				op[2] = vt
		var ex: Array = await exec(b, op)
		ops.append(op)
		exp.append(ex)
		if cleared(b):
			end = "cleared"
			break
		if b.free_tiles().is_empty() and b.tray.size() < b.slots:
			# nothing left to take (a stuck table, e.g. orphans after a legacy shuffle): the game stops here
			end = "open"
			break
	if end == "open" and b.tray.size() >= b.slots:
		end = "failed"
	g["ops"] = ops
	g["exp"] = exp
	g["end"] = end
	close_board(host, b)
	return g


static func record_all(host: Node, n_games: int, dir: String, per_file: int = 50) -> Dictionary:
	var heroes: = _shard_heroes()
	var old_scale: = Engine.time_scale
	Engine.time_scale = TIME_SCALE
	var summary: = {"games": 0, "ops": 0, "cleared": 0, "failed": 0, "open": 0, "bytes": 0}
	var batch: = []
	var file_no: = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var t0: = Time.get_ticks_msec()
	for gi in n_games:
		var g: Dictionary = await play_game(host, gi, heroes)
		batch.append(g)
		summary.games += 1
		summary.ops += g.ops.size()
		summary[g.end] = int(summary.get(g.end, 0)) + 1
		if batch.size() >= per_file or gi == n_games - 1:
			var txt: = JSON.stringify({"v": 1, "games": batch})
			var fa: = FileAccess.open("%scorpus_%02d.json" % [dir, file_no], FileAccess.WRITE)
			fa.store_string(txt)
			fa.close()
			summary.bytes += txt.length()
			file_no += 1
			batch = []
		if gi % 5 == 4 or gi < 3:
			print("RECORD %d/%d games, %d ops, %.0f s" % [gi + 1, n_games, summary.ops, (Time.get_ticks_msec() - t0) / 1000.0])
	Engine.time_scale = old_scale
	return summary


# ------------------------------------------------------------------ the live fuzz: lockstep with TWBoard

# n_moves operations on live TrayBoards (several boards, a fresh one when a game ends); one check per position
static func fuzz(host: Node, n_moves: int) -> Dictionary:
	var heroes: = _shard_heroes()
	var old_scale: = Engine.time_scale
	Engine.time_scale = TIME_SCALE
	var S: = TWParitySelftest
	var moves: = 0
	var boards: = 0
	var tiles_checked: = 0
	var free_mismatch: = 0
	var gi: = 100000
	var r: = S.new_result()
	var t0: = Time.get_ticks_msec()
	while moves < n_moves:
		gi += 1
		boards += 1
		var rg: = RandomNumberGenerator.new()
		rg.seed = 99991 + gi
		seed(555000 + gi)
		var mode: String = MODES[rg.randi() % MODES.size()]
		var cfg: = make_cfg(gi, heroes)
		var b: = open_board(host, cfg)
		var g: = capture_deal(b, cfg, gi)
		var tb: = TWBoard.from_level(S.level_of(g))
		var topo: = TWFree.topology(tb.pos)
		var present: = func(o: int) -> bool: return tb.present[o] == 1
		var vt: = 0.0
		var rescues: = 2
		var guard: = 0
		while guard < 400 and moves < n_moves:
			guard += 1
			var op: = []
			if b.tray.size() >= b.slots:
				if rescues > 0 and rg.randf() < 0.8:
					rescues -= 1
					op = ["r", 3]
				else:
					break
			else:
				vt = next_time(rg, vt)
				op = pick_op(b, mode, rg, vt)
			var ex: Array = await exec(b, op)
			var bad_before: int = r.bad.size()
			S.apply_op(tb, op, ex, guard, r)
			moves += 1
			# the free rule, three ways: the legacy is_free, the TWBoard counters, TWFree.is_free on the present set
			var ok: bool = r.bad.size() == bad_before
			var legacy_free: Array = b.last_free
			var mine: = Array(tb.free_tiles())
			if legacy_free != mine:
				ok = false
			for i in tb.n:
				if tb.present[i] == 1:
					tiles_checked += 1
					var lf: bool = b.is_free(b.tiles[i])
					if lf != tb.is_free(i) or lf != TWFree.is_free(i, topo, present):
						free_mismatch += 1
						ok = false
			S.check("fuzz position %d (%s, %s): free set, tray, counters equal" % [moves, str(cfg.code), op[0]], ok,
				"%s | free legacy %s vs TWBoard %s" % ["; ".join(r.bad.slice(maxi(0, bad_before), mini(r.bad.size(), bad_before + 2))), str(legacy_free.slice(0, 12)), str(mine.slice(0, 12))])
			if cleared(b) or tb.cleared:
				break
		close_board(host, b)
	Engine.time_scale = old_scale
	var out: = {"moves": moves, "boards": boards, "tiles_checked": tiles_checked, "free_mismatch": free_mismatch,
		"ops_bad": r.bad.size(), "taps": r.taps, "kinds": r.kinds, "pair_ties": r.pair_ties, "shuffles": r.shuffles,
		"secs": snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1)}
	print("INFO fuzz  %s" % str(out))
	return out
